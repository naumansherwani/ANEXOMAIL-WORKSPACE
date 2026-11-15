
-- E175 (Q1d-1a, 16 Nov 2026): DKIM KEY LIFECYCLE, SIGNATURE AUDIT, DNS CONFIRMATION, OUTSIDE-RECEIVER PROOF, POLICY RATCHETS.
-- Why (what E170 leaves open): E170 stores the keys (wrapped, one active per algorithm, revoke-never-delete) and the sender signs with them. It cannot yet answer
--   1. "is the TXT record I published at Namecheap really the one for this key?"   -> E175 dns observations (hash-chained, the match is decided HERE, never trusted from Rust)
--   2. "which key signed which mail, with which headers, and were they over-signed?" -> E175 signature log (hash-chained per mailbox, the over-signing claim is RE-COMPUTED from h=)
--   3. "did an outside receiver (Gmail Show original) really say dkim=pass for my domain?" -> E175 proof rows parsed in SQL from the pasted Authentication-Results header
--   4. "when must the key rotate, and how long must the old DNS record stay published?" -> E175 rotation report (old record must outlive the last signature that can still verify)
--   5. "never send mail whose DKIM would fail"                                          -> E175 send gate + three ONE-WAY switches (policy ratchets) that can only be turned on, never off
-- TECHNOLOGY: SQL (PostgreSQL 16): forced RLS, security-definer doors with a fixed search_path, service_role only, append-only SHA-256 hash chains with a per-chain advisory lock,
--   closed CHECK lists, one-way ratchet trigger, regexp parsing of the receiver header inside the database, selftest that rolls itself back, CHECK_E175.sql (writes nothing).
-- Reuses: E167 fmail_mailboxes / fmail_ledger_append, E169 fmail_b64_169, E170 fmail_dkim_keys + fmail_outbox. Adds NO column to any existing table.
-- Rust connection (next sub-step, not in this file): fmail_out.rs calls fmail_dkim_send_gate175 before it claims a row, fmail_dkim_sign_record175 after every signature,
--   fmail_dkim_dns_record175 from a read-only DNS probe, fmail_dkim_proof175 from the Compose "paste the header" box.
do $$ begin
  if to_regclass('public.fmail_dkim_keys') is null then raise exception 'E175: fmail_dkim_keys missing (run E170 first)'; end if;
  if to_regclass('public.fmail_outbox') is null then raise exception 'E175: fmail_outbox missing (run E167 first)'; end if;
  if to_regprocedure('public.fmail_ledger_append(uuid,uuid,text,text,text,jsonb,boolean)') is null then raise exception 'E175: fmail_ledger_append missing (run E167 first)'; end if;
  if to_regprocedure('public.fmail_b64_169(bytea)') is null then raise exception 'E175: fmail_b64_169 missing (run E169 first)'; end if;
end $$;

-- 1) the closed ledger action list grows by four names (same pattern as E169 / E170 / E173; the list below is the E173 list plus the new names)
do $$
declare c record; v_has boolean := false;
begin
  for c in select conname, pg_get_constraintdef(oid) as d from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%send_queue%' loop
    if c.d like '%dkim_proof%' then v_has := true; else execute format('alter table public.fmail_ledger drop constraint %I', c.conname); end if;
  end loop;
  if not v_has then
    alter table public.fmail_ledger add constraint fmail_ledger_action_ck check (action in (
      'mailbox_add','mailbox_pause','mailbox_lock','mailbox_retire','policy_change','key_rotate','key_import',
      'send_queue','send_schedule','send_start','send_ok','send_fail','send_cancel','send_undo',
      'delete_soft','delete_hard','export_start','export_done','quarantine_in','quarantine_release','attachment_seal','attachment_scan',
      'inbound_reject','panic_lock','inbound_ok','unseal_gated','vault_set','mailbox_seed','dkim_install','dkim_revoke','ledger_checkpoint',
      'dkim_policy','dkim_dns_check','dkim_proof'));
  end if;
end $$;

-- 2) shared helpers -------------------------------------------------------------------------------------------------------------------------------
-- one hash recipe for every chain in this file: sha256 over the unit-separator-joined text fields (null becomes the empty string), lower hex
create or replace function public.fmail_h175(p text[]) returns text language sql immutable parallel safe set search_path = pg_catalog as $$
  select encode(sha256(convert_to(array_to_string(array(select coalesce(x, '') from unnest(p) as x), E'\x1f'), 'UTF8')), 'hex')
$$;
-- these three tables are evidence: nothing is ever updated, deleted or truncated (the sender and the founder can only add rows)
create or replace function public.fmail_dkim_immutable175() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E175: % is append-only (% refused)', tg_table_name, tg_op using errcode = '42501'; end $$;

-- 3) POLICY: one row per mailbox. The three require_* switches are ONE-WAY RATCHETS: on is final (a stolen session cannot quietly weaken the sender). -------
create table if not exists public.fmail_dkim_policy (
  mailbox_id        uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  rotate_days       int  not null default 180 check (rotate_days between 30 and 400),
  overlap_days      int  not null default 14  check (overlap_days between 8 and 60),     -- a revoked key's DNS record stays published this long
  sig_ttl_days      int  not null default 7   check (sig_ttl_days between 1 and 30),     -- the x= expiry the signer may use (E170 signs with 7)
  require_oversign  boolean not null default false,   -- ratchet: refuse a signature log row whose h= does not list From/To/Subject/Date/Message-ID twice
  require_dual      boolean not null default false,   -- ratchet: Ed25519 AND RSA must both have an active key
  require_dns_match boolean not null default false,   -- ratchet: the send gate is shut until every active key's TXT record is confirmed
  updated_at        timestamptz not null default now(),
  constraint fmail_dkim_policy_overlap_ck check (overlap_days > sig_ttl_days)   -- the old record must outlive the last signature that can still verify
);
alter table public.fmail_dkim_policy enable row level security;
alter table public.fmail_dkim_policy force row level security;
revoke all on public.fmail_dkim_policy from public, anon, authenticated;
grant select, insert, update on public.fmail_dkim_policy to service_role;

create or replace function public.fmail_dkim_policy_guard175() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E175: the DKIM policy of a mailbox is never deleted' using errcode = '42501'; end if;
  if new.mailbox_id is distinct from old.mailbox_id then raise exception 'E175: the policy row cannot move to another mailbox' using errcode = '42501'; end if;
  if (old.require_oversign and not new.require_oversign) or (old.require_dual and not new.require_dual) or (old.require_dns_match and not new.require_dns_match) then
    raise exception 'E175: a policy ratchet only turns on, never off' using errcode = '42501'; end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists fmail_dkim_policy_guard on public.fmail_dkim_policy;
create trigger fmail_dkim_policy_guard before update or delete on public.fmail_dkim_policy for each row execute function public.fmail_dkim_policy_guard175();

-- the policy of a mailbox; the default row is created on first use (a plain read by the sender must not need a founder touch)
create or replace function public.fmail_dkim_pol175(p_mailbox uuid) returns public.fmail_dkim_policy
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v public.fmail_dkim_policy%rowtype;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then raise exception 'E175: unknown mailbox' using errcode = '22023'; end if;
  insert into public.fmail_dkim_policy (mailbox_id) values (p_mailbox) on conflict (mailbox_id) do nothing;
  select * into v from public.fmail_dkim_policy where mailbox_id = p_mailbox;
  return v;
end $$;

-- changing the policy needs the founder's passkey touch (same rule as installing a key in E170) and is anchored in the audit tree
create or replace function public.fmail_dkim_policy_set175(p_actor uuid, p_mailbox uuid, p_rotate_days int, p_overlap_days int, p_sig_ttl_days int,
                                                           p_oversign boolean, p_dual boolean, p_dns_match boolean, p_touch_hash text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_old public.fmail_dkim_policy%rowtype; v_new public.fmail_dkim_policy%rowtype; v_led jsonb;
begin
  if p_touch_hash is null or p_touch_hash !~ '^[0-9a-f]{64}$' then raise exception 'E175: changing the DKIM policy needs a passkey touch' using errcode = '42501'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then raise exception 'E175: not your mailbox' using errcode = '42501'; end if;
  v_old := public.fmail_dkim_pol175(p_mailbox);
  update public.fmail_dkim_policy set
      rotate_days = coalesce(p_rotate_days, rotate_days), overlap_days = coalesce(p_overlap_days, overlap_days), sig_ttl_days = coalesce(p_sig_ttl_days, sig_ttl_days),
      require_oversign = coalesce(p_oversign, require_oversign), require_dual = coalesce(p_dual, require_dual), require_dns_match = coalesce(p_dns_match, require_dns_match)
    where mailbox_id = p_mailbox returning * into v_new;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'dkim_policy', p_mailbox::text, 'DKIM policy changed (passkey touched)',
             jsonb_build_object('rotate_days', v_new.rotate_days, 'overlap_days', v_new.overlap_days, 'sig_ttl_days', v_new.sig_ttl_days, 'require_oversign', v_new.require_oversign,
                                'require_dual', v_new.require_dual, 'require_dns_match', v_new.require_dns_match, 'touch', p_touch_hash), true);
  return jsonb_build_object('policy', to_jsonb(v_new) - 'mailbox_id', 'ledger_seq', v_led -> 'seq');
end $$;

-- 4) SELECTORS + ROTATION --------------------------------------------------------------------------------------------------------------------------
-- A fresh dated selector that was never used for this mailbox: e2611a (Ed25519, Nov 2026, first), r2611a (RSA). The DNS name is <selector>._domainkey.<domain>.
create or replace function public.fmail_dkim_selector175(p_mailbox uuid, p_alg text) returns text
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_pre text; v_ym text := to_char(now() at time zone 'utc', 'YYMM'); v_i int; v_s text;
begin
  if p_alg not in ('ed25519-sha256', 'rsa-sha256') then raise exception 'E175: alg must be ed25519-sha256 or rsa-sha256' using errcode = '22023'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox) then raise exception 'E175: unknown mailbox' using errcode = '22023'; end if;
  v_pre := case when p_alg = 'ed25519-sha256' then 'e' else 'r' end;
  for v_i in 0..25 loop
    v_s := v_pre || v_ym || chr(97 + v_i);
    if not exists (select 1 from public.fmail_dkim_keys where mailbox_id = p_mailbox and selector = v_s) then return v_s; end if;
  end loop;
  raise exception 'E175: all 26 selectors of this month are used' using errcode = '53400';
end $$;

-- one row per key: age, when rotation is due, and for a revoked key how long its DNS record must stay (then the founder may delete it at Namecheap)
create or replace function public.fmail_dkim_rotation175(p_mailbox uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_pol public.fmail_dkim_policy%rowtype; v_out jsonb;
begin
  v_pol := public.fmail_dkim_pol175(p_mailbox);
  select coalesce(jsonb_agg(r order by r ->> 'created_at'), '[]'::jsonb) into v_out from (
    select jsonb_build_object(
      'key_id', k.id, 'selector', k.selector, 'alg', k.alg, 'status', k.status, 'created_at', k.created_at,
      'age_days', floor(extract(epoch from (now() - k.created_at)) / 86400)::int,
      'due_in_days', case when k.status = 'active' then v_pol.rotate_days - floor(extract(epoch from (now() - k.created_at)) / 86400)::int end,
      'state', case when k.status = 'revoked' then 'retired'
                    when v_pol.rotate_days - floor(extract(epoch from (now() - k.created_at)) / 86400)::int > 14 then 'ok'
                    when v_pol.rotate_days - floor(extract(epoch from (now() - k.created_at)) / 86400)::int >= 1 then 'soon'
                    when v_pol.rotate_days - floor(extract(epoch from (now() - k.created_at)) / 86400)::int >= -14 then 'due' else 'overdue' end,
      'dns_keep_until', case when k.status = 'revoked' then k.revoked_at + make_interval(days => v_pol.overlap_days) end,
      'dns_removable', case when k.status = 'revoked' then now() >= k.revoked_at + make_interval(days => v_pol.overlap_days) end) as r
    from public.fmail_dkim_keys k where k.mailbox_id = p_mailbox) t;
  return v_out;
end $$;

-- 5) DNS CONFIRMATION: what the world's DNS answered for the key's TXT record. The VERDICT IS DECIDED HERE by comparing with the stored public key. --------
create table if not exists public.fmail_dkim_dns_obs (
  id            bigint generated always as identity primary key,
  key_id        uuid not null references public.fmail_dkim_keys (id) on delete restrict,
  mailbox_id    uuid not null references public.fmail_mailboxes (id) on delete restrict,
  seq           int  not null check (seq >= 1),
  observed_ms   bigint not null,
  result        text not null check (result in ('match', 'absent', 'mismatch', 'empty_p', 'lookup_error')),
  expected_hash text not null check (expected_hash ~ '^[0-9a-f]{64}$'),
  observed_hash text check (observed_hash is null or observed_hash ~ '^[0-9a-f]{64}$'),
  resolver      text not null check (length(resolver) between 1 and 80 and resolver !~ '[[:cntrl:]]'),
  dnssec        text not null check (dnssec in ('secure', 'insecure', 'bogus', 'unknown')),
  prev_hash     text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash      text not null check (row_hash ~ '^[0-9a-f]{64}$'),
  unique (key_id, seq)
);
create index if not exists fmail_dkim_dns_obs_key_idx on public.fmail_dkim_dns_obs (key_id, seq desc);
create or replace function public.fmail_dkim_dns_hash175(p_prev text, p_key uuid, p_seq int, p_ms bigint, p_result text, p_exp text, p_obs text, p_resolver text, p_dnssec text) returns text
language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select public.fmail_h175(array[p_prev, p_key::text, p_seq::text, p_ms::text, p_result, p_exp, p_obs, p_resolver, p_dnssec])
$$;

-- p_observed = the p= value the resolver returned (base64, quotes and spaces allowed), null = no TXT record at that name, '' = record present with an empty p= (key withdrawn)
create or replace function public.fmail_dkim_dns_record175(p_actor uuid, p_key uuid, p_observed text, p_lookup_ok boolean, p_resolver text, p_dnssec text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  k public.fmail_dkim_keys%rowtype; v_exp text; v_obs text; v_res text; v_prev text; v_seq int; v_last text; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_eh text; v_oh text; v_hash text; v_changed boolean; v_led jsonb;
begin
  select * into k from public.fmail_dkim_keys where id = p_key;
  if not found then raise exception 'E175: no such DKIM key' using errcode = '23503'; end if;
  if not exists (select 1 from public.fmail_mailboxes where id = k.mailbox_id and owner = p_actor) then raise exception 'E175: not your mailbox' using errcode = '42501'; end if;
  v_exp := public.fmail_b64_169(k.public_key);
  v_obs := case when p_observed is null then null else regexp_replace(p_observed, '[\s"]', '', 'g') end;
  v_res := case when not coalesce(p_lookup_ok, false) then 'lookup_error' when v_obs is null then 'absent' when v_obs = '' then 'empty_p' when v_obs = v_exp then 'match' else 'mismatch' end;
  v_eh := encode(sha256(convert_to(v_exp, 'UTF8')), 'hex');
  v_oh := case when v_obs is null or v_obs = '' then null else encode(sha256(convert_to(v_obs, 'UTF8')), 'hex') end;
  perform pg_advisory_xact_lock(hashtext('fmail_dkim_dns:' || p_key::text));
  select row_hash, seq, result into v_prev, v_seq, v_last from public.fmail_dkim_dns_obs where key_id = p_key order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64)); v_seq := coalesce(v_seq, 0) + 1;
  v_hash := public.fmail_dkim_dns_hash175(v_prev, p_key, v_seq, v_ms, v_res, v_eh, v_oh, p_resolver, p_dnssec);
  insert into public.fmail_dkim_dns_obs (key_id, mailbox_id, seq, observed_ms, result, expected_hash, observed_hash, resolver, dnssec, prev_hash, row_hash)
    values (p_key, k.mailbox_id, v_seq, v_ms, v_res, v_eh, v_oh, p_resolver, p_dnssec, v_prev, v_hash);
  -- the founder ledger gets a row only when "is the record confirmed" flips (a probe every hour must not flood it)
  v_changed := (v_last = 'match') is distinct from (v_res = 'match');
  if v_changed and (v_last is not null or v_res = 'match') then
    v_led := public.fmail_ledger_append(p_actor, k.mailbox_id, 'dkim_dns_check', p_key::text, 'DKIM DNS record ' || case when v_res = 'match' then 'confirmed' else 'no longer matches' end,
               jsonb_build_object('selector', k.selector, 'alg', k.alg, 'result', v_res, 'dnssec', p_dnssec, 'obs_seq', v_seq), false);
  end if;
  return jsonb_build_object('result', v_res, 'seq', v_seq, 'changed', v_changed, 'ledger_seq', v_led -> 'seq');
end $$;

-- 6) SIGNATURE LOG: one row per (outbox row, key). Per-mailbox hash chain. The over-signing fact is RE-COMPUTED from the h= list the signer reports. ------
create table if not exists public.fmail_dkim_sign_log (
  id          bigint generated always as identity primary key,
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete restrict,
  seq         int  not null check (seq >= 1),
  outbox_id   uuid not null,
  key_id      uuid not null references public.fmail_dkim_keys (id) on delete restrict,
  alg         text not null check (alg in ('ed25519-sha256', 'rsa-sha256')),
  selector    text not null check (selector ~ '^[a-z0-9][a-z0-9-]{0,62}$'),
  oversigned  boolean not null,
  h_count     smallint not null check (h_count between 1 and 60),
  h_hash      text not null check (h_hash ~ '^[0-9a-f]{64}$'),
  bh          text not null check (bh ~ '^[A-Za-z0-9+/]{43}=$'),
  sig_hash    text not null check (sig_hash ~ '^[0-9a-f]{64}$'),
  t_unix      bigint not null check (t_unix > 1700000000),
  x_unix      bigint not null,
  ts_ms       bigint not null,
  prev_hash   text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash    text not null check (row_hash ~ '^[0-9a-f]{64}$'),
  unique (mailbox_id, seq), unique (outbox_id, key_id),
  check (x_unix > t_unix)
);
create index if not exists fmail_dkim_sign_log_ts_brin on public.fmail_dkim_sign_log using brin (ts_ms);
create or replace function public.fmail_dkim_sign_hash175(p_prev text, p_mb uuid, p_seq int, p_ob uuid, p_key uuid, p_over boolean, p_hc int, p_hh text, p_bh text, p_sig text, p_t bigint, p_x bigint, p_ms bigint) returns text
language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select public.fmail_h175(array[p_prev, p_mb::text, p_seq::text, p_ob::text, p_key::text, p_over::text, p_hc::text, p_hh, p_bh, p_sig, p_t::text, p_x::text, p_ms::text])
$$;
-- the five headers an attacker would love to duplicate after signing: each must be listed at least twice in h= (once real, once for "must stay absent")
create or replace function public.fmail_dkim_oversigned175(p_h text) returns boolean language sql immutable parallel safe set search_path = pg_catalog as $$
  select bool_and(c >= 2) from (select count(*) filter (where n = w) as c from unnest(array['from', 'to', 'subject', 'date', 'message-id']) w,
         unnest(string_to_array(lower(p_h), ':')) n group by w) t
$$;

create or replace function public.fmail_dkim_sign_record175(p_outbox uuid, p_key uuid, p_h text, p_bh text, p_sig_hash text, p_t bigint, p_x bigint)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  o public.fmail_outbox%rowtype; k public.fmail_dkim_keys%rowtype; pol public.fmail_dkim_policy%rowtype; v_over boolean; v_hc int; v_prev text; v_seq int; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_hash text; v_hh text; v_ex int;
begin
  select * into o from public.fmail_outbox where id = p_outbox;
  if not found then raise exception 'E175: no such outbox row' using errcode = '23503'; end if;
  select * into k from public.fmail_dkim_keys where id = p_key;
  if not found or k.mailbox_id <> o.mailbox_id then raise exception 'E175: the key does not belong to this mailbox' using errcode = '23503'; end if;
  if k.status <> 'active' then raise exception 'E175: a revoked key cannot sign' using errcode = '55000'; end if;
  if p_h is null or p_h !~ '^[a-z][a-z0-9-]*(:[a-z][a-z0-9-]*)*$' or length(p_h) > 600 then raise exception 'E175: h= must be lower-case header names joined by colons' using errcode = '22023'; end if;
  v_hc := cardinality(string_to_array(p_h, ':'));
  if 'from' <> all (string_to_array(p_h, ':')) is not false and not ('from' = any (string_to_array(p_h, ':'))) then raise exception 'E175: From must be signed' using errcode = '22023'; end if;
  pol := public.fmail_dkim_pol175(o.mailbox_id);
  v_over := coalesce(public.fmail_dkim_oversigned175(p_h), false);
  if pol.require_oversign and not v_over then raise exception 'E175: policy requires over-signing From, To, Subject, Date and Message-ID' using errcode = '55000'; end if;
  if p_x - p_t > pol.sig_ttl_days * 86400 then raise exception 'E175: signature lifetime exceeds the policy (% days)', pol.sig_ttl_days using errcode = '22023'; end if;
  if p_x - p_t < 3600 then raise exception 'E175: a signature must live at least one hour' using errcode = '22023'; end if;
  v_hh := encode(sha256(convert_to(p_h, 'UTF8')), 'hex');
  perform pg_advisory_xact_lock(hashtext('fmail_dkim_sign:' || o.mailbox_id::text));
  -- a retry of the same (outbox, key) is not a second signature: answer with the first one
  select seq into v_ex from public.fmail_dkim_sign_log where outbox_id = p_outbox and key_id = p_key;
  if v_ex is not null then return jsonb_build_object('seq', v_ex, 'oversigned', v_over, 'duplicate', true); end if;
  select row_hash, seq into v_prev, v_seq from public.fmail_dkim_sign_log where mailbox_id = o.mailbox_id order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64)); v_seq := coalesce(v_seq, 0) + 1;
  v_hash := public.fmail_dkim_sign_hash175(v_prev, o.mailbox_id, v_seq, p_outbox, p_key, v_over, v_hc, v_hh, p_bh, p_sig_hash, p_t, p_x, v_ms);
  insert into public.fmail_dkim_sign_log (mailbox_id, seq, outbox_id, key_id, alg, selector, oversigned, h_count, h_hash, bh, sig_hash, t_unix, x_unix, ts_ms, prev_hash, row_hash)
    values (o.mailbox_id, v_seq, p_outbox, p_key, k.alg, k.selector, v_over, v_hc, v_hh, p_bh, p_sig_hash, p_t, p_x, v_ms, v_prev, v_hash);
  return jsonb_build_object('seq', v_seq, 'oversigned', v_over, 'duplicate', false);
end $$;

-- 7) OUTSIDE-RECEIVER PROOF (Q1d-1b): the founder pastes the Authentication-Results header from "Show original"; SQL parses it, keeps only parsed facts + its hash ---
create table if not exists public.fmail_dkim_proof (
  id          bigint generated always as identity primary key,
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete restrict,
  seq         int  not null check (seq >= 1),
  recorded_ms bigint not null,
  receiver    text not null check (receiver in ('gmail', 'outlook', 'yahoo', 'icloud', 'other')),
  verdict     text not null check (verdict in ('pass', 'fail', 'neutral', 'none', 'policy', 'temperror', 'permerror')),
  domain      text not null check (domain ~ '^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$'),
  selector    text check (selector is null or selector ~ '^[a-z0-9][a-z0-9-]{0,62}$'),
  key_id      uuid references public.fmail_dkim_keys (id) on delete restrict,
  aligned     boolean not null,                         -- the signing domain is the mailbox's own domain (DMARC alignment of the DKIM leg)
  auth_hash   text not null check (auth_hash ~ '^[0-9a-f]{64}$'),   -- sha256 of the whole pasted header (the paste itself is never stored)
  prev_hash   text not null check (prev_hash ~ '^[0-9a-f]{64}$'),
  row_hash    text not null check (row_hash ~ '^[0-9a-f]{64}$'),
  unique (mailbox_id, seq)
);
create or replace function public.fmail_dkim_proof_hash175(p_prev text, p_mb uuid, p_seq int, p_ms bigint, p_recv text, p_verdict text, p_dom text, p_sel text, p_key uuid, p_al boolean, p_auth text) returns text
language sql immutable parallel safe set search_path = pg_catalog, public as $$
  select public.fmail_h175(array[p_prev, p_mb::text, p_seq::text, p_ms::text, p_recv, p_verdict, p_dom, p_sel, p_key::text, p_al::text, p_auth])
$$;

create or replace function public.fmail_dkim_proof175(p_actor uuid, p_mailbox uuid, p_receiver text, p_authres text)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  b public.fmail_mailboxes%rowtype; v_txt text; seg text; v_verdict text; v_dom text; v_sel text; v_key uuid; v_al boolean; v_prev text; v_seq int; v_hash text; v_ah text;
  v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_out jsonb := '[]'::jsonb; v_my text; v_led jsonb;
begin
  select * into b from public.fmail_mailboxes where id = p_mailbox and owner = p_actor;
  if not found then raise exception 'E175: not your mailbox' using errcode = '42501'; end if;
  if p_receiver not in ('gmail', 'outlook', 'yahoo', 'icloud', 'other') then raise exception 'E175: unknown receiver' using errcode = '22023'; end if;
  if p_authres is null or length(p_authres) not between 20 and 6000 then raise exception 'E175: paste the whole Authentication-Results header (20 to 6000 characters)' using errcode = '22023'; end if;
  v_txt := regexp_replace(lower(p_authres), '\s+', ' ', 'g');
  v_ah := encode(sha256(convert_to(v_txt, 'UTF8')), 'hex');
  v_my := lower(split_part(b.address, '@', 2));
  perform pg_advisory_xact_lock(hashtext('fmail_dkim_proof:' || p_mailbox::text));
  select row_hash, seq into v_prev, v_seq from public.fmail_dkim_proof where mailbox_id = p_mailbox order by seq desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64)); v_seq := coalesce(v_seq, 0);
  for seg in select trim(x) from regexp_split_to_table(v_txt, ';') as x loop
    continue when seg !~ '^dkim=(pass|fail|neutral|none|policy|temperror|permerror)\M';
    v_verdict := substring(seg from '^dkim=([a-z]+)');
    v_dom := coalesce(substring(seg from 'header\.d=([a-z0-9.-]+)'), substring(seg from 'header\.i=(?:[^@ ;]*@)?([a-z0-9.-]+)'));
    v_sel := substring(seg from 'header\.s=([a-z0-9-]+)');
    continue when v_dom is null;
    v_key := null;
    if v_sel is not null then select id into v_key from public.fmail_dkim_keys where mailbox_id = p_mailbox and selector = v_sel order by created_at desc limit 1; end if;
    v_al := (v_dom = v_my);
    v_seq := v_seq + 1;
    v_hash := public.fmail_dkim_proof_hash175(v_prev, p_mailbox, v_seq, v_ms, p_receiver, v_verdict, v_dom, v_sel, v_key, v_al, v_ah);
    insert into public.fmail_dkim_proof (mailbox_id, seq, recorded_ms, receiver, verdict, domain, selector, key_id, aligned, auth_hash, prev_hash, row_hash)
      values (p_mailbox, v_seq, v_ms, p_receiver, v_verdict, v_dom, v_sel, v_key, v_al, v_ah, v_prev, v_hash);
    v_prev := v_hash;
    v_out := v_out || jsonb_build_object('seq', v_seq, 'verdict', v_verdict, 'domain', v_dom, 'selector', v_sel, 'key_known', v_key is not null, 'aligned', v_al);
  end loop;
  if jsonb_array_length(v_out) = 0 then raise exception 'E175: no dkim= result with a signing domain was found in what you pasted' using errcode = '22023'; end if;
  v_led := public.fmail_ledger_append(p_actor, p_mailbox, 'dkim_proof', v_ah, 'DKIM outside-receiver proof recorded (' || p_receiver || ')',
             jsonb_build_object('receiver', p_receiver, 'results', v_out), true);
  return jsonb_build_object('results', v_out, 'ledger_seq', v_led -> 'seq');
end $$;

-- 8) HEALTH + SEND GATE: one read the Compose panel and the sender use. "blockers" are ENFORCED by policy; "warnings" are advice. -------------------------------
create or replace function public.fmail_dkim_health175(p_mailbox uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  pol public.fmail_dkim_policy%rowtype; v_keys jsonb; v_rot jsonb; v_block text[] := '{}'; v_warn text[] := '{}'; r record; v_ed int := 0; v_rsa int := 0; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_over24 int; v_n24 int; v_proof text;
begin
  pol := public.fmail_dkim_pol175(p_mailbox);
  v_rot := public.fmail_dkim_rotation175(p_mailbox);
  select coalesce(jsonb_agg(jsonb_build_object(
      'key_id', k.id, 'selector', k.selector, 'alg', k.alg, 'status', k.status,
      'dns', (select jsonb_build_object('result', d.result, 'dnssec', d.dnssec, 'age_s', ((v_ms - d.observed_ms) / 1000)) from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1),
      'signed_24h', (select count(*) from public.fmail_dkim_sign_log s where s.key_id = k.id and s.ts_ms > v_ms - 86400000),
      'last_proof', (select p.verdict from public.fmail_dkim_proof p where p.key_id = k.id order by p.seq desc limit 1)) order by k.created_at), '[]'::jsonb)
    into v_keys from public.fmail_dkim_keys k where k.mailbox_id = p_mailbox and k.status = 'active';
  for r in select k.id, k.selector, k.alg, (select d.result from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1) as dns,
                  (select d.dnssec from public.fmail_dkim_dns_obs d where d.key_id = k.id order by d.seq desc limit 1) as dnssec,
                  (select p.verdict from public.fmail_dkim_proof p where p.key_id = k.id order by p.seq desc limit 1) as proof
             from public.fmail_dkim_keys k where k.mailbox_id = p_mailbox and k.status = 'active' loop
    if r.alg = 'ed25519-sha256' then v_ed := v_ed + 1; else v_rsa := v_rsa + 1; end if;
    if r.dns is distinct from 'match' then
      if pol.require_dns_match then v_block := v_block || ('the DNS record for ' || r.selector || ' is not confirmed'); else v_warn := v_warn || ('the DNS record for ' || r.selector || ' is not confirmed yet'); end if;
    end if;
    if r.dnssec = 'bogus' then v_block := v_block || ('the DNSSEC answer for ' || r.selector || ' is bogus'); end if;
    if r.proof is distinct from 'pass' then v_warn := v_warn || ('no outside receiver has passed ' || r.selector || ' yet'); end if;
  end loop;
  if v_ed + v_rsa = 0 then v_block := v_block || 'there is no active DKIM key'; end if;
  if pol.require_dual and (v_ed = 0 or v_rsa = 0) then v_block := v_block || 'policy needs both an Ed25519 and an RSA key'; end if;
  for r in select e ->> 'selector' as sel, e ->> 'state' as st from jsonb_array_elements(v_rot) e where e ->> 'status' = 'active' and e ->> 'state' in ('due', 'overdue') loop
    v_warn := v_warn || ('key ' || r.sel || ' should rotate (' || r.st || ')');
  end loop;
  select count(*) filter (where oversigned), count(*) into v_over24, v_n24 from public.fmail_dkim_sign_log where mailbox_id = p_mailbox and ts_ms > v_ms - 86400000;
  if v_n24 > 0 and v_over24 < v_n24 and not pol.require_oversign then v_warn := v_warn || ((v_n24 - v_over24)::text || ' signature(s) in 24 h were not over-signed'); end if;
  return jsonb_build_object('policy', to_jsonb(pol) - 'mailbox_id', 'keys', v_keys, 'rotation', v_rot, 'blockers', to_jsonb(v_block), 'warnings', to_jsonb(v_warn),
                            'send_ready', cardinality(v_block) = 0, 'signed_24h', v_n24, 'oversigned_24h', v_over24);
end $$;

create or replace function public.fmail_dkim_send_gate175(p_mailbox uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('ok', (h ->> 'send_ready')::boolean, 'reasons', h -> 'blockers') from (select public.fmail_dkim_health175(p_mailbox) as h) x
$$;

-- 9) CHAIN VERIFY: recompute every row hash of the three chains; broken must be 0 ---------------------------------------------------------------------------
create or replace function public.fmail_dkim_chain_verify175() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_n int := 0; v_bad int := 0; r record; v_prev text;
begin
  v_prev := null;
  for r in select * from public.fmail_dkim_dns_obs order by key_id, seq loop
    v_n := v_n + 1;
    if v_prev is distinct from r.key_id::text then v_prev := null; end if;
    if r.row_hash is distinct from public.fmail_dkim_dns_hash175(r.prev_hash, r.key_id, r.seq, r.observed_ms, r.result, r.expected_hash, r.observed_hash, r.resolver, r.dnssec)
       or (r.seq = 1 and r.prev_hash <> repeat('0', 64))
       or (r.seq > 1 and r.prev_hash is distinct from (select x.row_hash from public.fmail_dkim_dns_obs x where x.key_id = r.key_id and x.seq = r.seq - 1)) then v_bad := v_bad + 1; end if;
  end loop;
  for r in select * from public.fmail_dkim_sign_log order by mailbox_id, seq loop
    v_n := v_n + 1;
    if r.row_hash is distinct from public.fmail_dkim_sign_hash175(r.prev_hash, r.mailbox_id, r.seq, r.outbox_id, r.key_id, r.oversigned, r.h_count, r.h_hash, r.bh, r.sig_hash, r.t_unix, r.x_unix, r.ts_ms)
       or (r.seq = 1 and r.prev_hash <> repeat('0', 64))
       or (r.seq > 1 and r.prev_hash is distinct from (select x.row_hash from public.fmail_dkim_sign_log x where x.mailbox_id = r.mailbox_id and x.seq = r.seq - 1)) then v_bad := v_bad + 1; end if;
  end loop;
  for r in select * from public.fmail_dkim_proof order by mailbox_id, seq loop
    v_n := v_n + 1;
    if r.row_hash is distinct from public.fmail_dkim_proof_hash175(r.prev_hash, r.mailbox_id, r.seq, r.recorded_ms, r.receiver, r.verdict, r.domain, r.selector, r.key_id, r.aligned, r.auth_hash)
       or (r.seq = 1 and r.prev_hash <> repeat('0', 64))
       or (r.seq > 1 and r.prev_hash is distinct from (select x.row_hash from public.fmail_dkim_proof x where x.mailbox_id = r.mailbox_id and x.seq = r.seq - 1)) then v_bad := v_bad + 1; end if;
  end loop;
  return jsonb_build_object('checked', v_n, 'broken', v_bad);
end $$;

-- 10) LOCK IT DOWN: evidence tables append-only, RLS forced, nothing for anon / authenticated, service_role may only read and add ----------------------------
do $$
declare t text;
begin
  foreach t in array array['fmail_dkim_dns_obs', 'fmail_dkim_sign_log', 'fmail_dkim_proof'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated', t);
    execute format('grant select, insert on public.%I to service_role', t);
    execute format('drop trigger if exists %I on public.%I', t || '_row_imm', t);
    execute format('create trigger %I before update or delete on public.%I for each row execute function public.fmail_dkim_immutable175()', t || '_row_imm', t);
    execute format('drop trigger if exists %I on public.%I', t || '_trunc_imm', t);
    execute format('create trigger %I before truncate on public.%I for each statement execute function public.fmail_dkim_immutable175()', t || '_trunc_imm', t);
  end loop;
end $$;
do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p where p.pronamespace = 'public'::regnamespace
           and p.proname in ('fmail_dkim_pol175', 'fmail_dkim_policy_set175', 'fmail_dkim_selector175', 'fmail_dkim_rotation175', 'fmail_dkim_dns_record175', 'fmail_dkim_sign_record175',
                             'fmail_dkim_proof175', 'fmail_dkim_health175', 'fmail_dkim_send_gate175', 'fmail_dkim_chain_verify175', 'fmail_h175', 'fmail_dkim_oversigned175',
                             'fmail_dkim_dns_hash175', 'fmail_dkim_sign_hash175', 'fmail_dkim_proof_hash175', 'fmail_dkim_policy_guard175', 'fmail_dkim_immutable175') loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
    execute format('grant execute on function %s to service_role', f.sig);
  end loop;
end $$;

-- 11) SELFTEST (rolls itself back): 28 checks on real rows ------------------------------------------------------------------------------------------------
create or replace function public.fmail_dkim_selftest175() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_box uuid; v_t text := repeat('a', 64); v_ok boolean; v_r jsonb; v_k1 uuid; v_k2 uuid; v_k3 uuid; v_ob uuid; v_n int; v_pub bytea := decode(repeat('06', 32), 'hex');
  v_sealed bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
  v_mid bytea := decode(repeat('04', 32), 'hex'); v_rc text[] := array[repeat('05', 32)]; v_sel text; v_b64 text; v_bh text := repeat('A', 43) || '=';
  v_plain text := 'from:to:subject:date:message-id:mime-version'; v_over text := 'from:from:to:to:subject:subject:date:date:message-id:message-id:mime-version';
  v_now bigint := extract(epoch from now())::bigint; v_pass int := 0; v_fail int := 0; ev jsonb;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E175 selftest: no founder account to test with'; end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest175@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- policy
    v_r := to_jsonb(public.fmail_dkim_pol175(v_box));
    res := res || jsonb_build_object('name', 'default policy row: 180 d rotate, 14 d overlap, 7 d ttl, all ratchets off', 'ok', (v_r ->> 'rotate_days') = '180' and (v_r ->> 'overlap_days') = '14' and (v_r ->> 'sig_ttl_days') = '7' and not (v_r ->> 'require_oversign')::boolean and not (v_r ->> 'require_dual')::boolean and not (v_r ->> 'require_dns_match')::boolean);
    begin perform public.fmail_dkim_policy_set175(v_uid, v_box, null, null, null, true, null, null, null); v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a policy change without a touch is refused', 'ok', v_ok);
    begin perform public.fmail_dkim_policy_set175(v_uid, v_box, null, 5, 7, null, null, null, v_t); v_ok := false; exception when sqlstate '23514' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'overlap shorter than the signature life is refused (CHECK)', 'ok', v_ok);
    -- selectors + keys
    v_sel := public.fmail_dkim_selector175(v_box, 'ed25519-sha256');
    res := res || jsonb_build_object('name', 'first selector is dated e<YYMM>a', 'ok', v_sel = 'e' || to_char(now() at time zone 'utc', 'YYMM') || 'a');
    perform public.fmail_dkim_install170(v_uid, v_box, v_sel, 'ed25519-sha256', v_pub, v_wrap, v_nonce, v_t);
    select id into v_k1 from public.fmail_dkim_keys where mailbox_id = v_box and selector = v_sel;
    res := res || jsonb_build_object('name', 'the next selector skips a used one (b)', 'ok', public.fmail_dkim_selector175(v_box, 'ed25519-sha256') = 'e' || to_char(now() at time zone 'utc', 'YYMM') || 'b');
    -- DNS observations
    v_b64 := public.fmail_b64_169(v_pub);
    v_r := public.fmail_dkim_dns_record175(v_uid, v_k1, null, true, 'selftest-resolver', 'unknown');
    res := res || jsonb_build_object('name', 'no TXT record answers absent', 'ok', v_r ->> 'result' = 'absent' and (v_r ->> 'seq') = '1');
    v_r := public.fmail_dkim_dns_record175(v_uid, v_k1, 'AAAA', true, 'selftest-resolver', 'unknown');
    res := res || jsonb_build_object('name', 'a different p= answers mismatch', 'ok', v_r ->> 'result' = 'mismatch');
    v_r := public.fmail_dkim_dns_record175(v_uid, v_k1, '"' || substr(v_b64, 1, 10) || '" "' || substr(v_b64, 11) || '"', true, 'selftest-resolver', 'secure');
    res := res || jsonb_build_object('name', 'the real p= (quoted, split in two strings) answers match and is ledgered', 'ok', v_r ->> 'result' = 'match' and (v_r ->> 'changed')::boolean and (v_r ->> 'ledger_seq') is not null);
    v_r := public.fmail_dkim_dns_record175(v_uid, v_k1, v_b64, true, 'selftest-resolver', 'secure');
    res := res || jsonb_build_object('name', 'a repeated match writes an observation but no second ledger row', 'ok', v_r ->> 'result' = 'match' and not (v_r ->> 'changed')::boolean and (v_r ->> 'ledger_seq') is null and (v_r ->> 'seq') = '4');
    begin perform public.fmail_dkim_dns_record175(v_uid, gen_random_uuid(), null, true, 'r', 'unknown'); v_ok := false; exception when sqlstate '23503' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'an unknown key is refused', 'ok', v_ok);
    -- an outbox row to sign for (compose needs an active key: installed above)
    v_r := public.fmail_compose_send170(v_uid, v_box, v_sealed, v_sealed, v_nonce, v_nonce, 'k-selftest', v_wrap, v_aad, v_mid, null, null, 100, 0, v_rc, null, v_t, null);
    v_ob := (v_r ->> 'outbox_id')::uuid;
    v_r := public.fmail_dkim_sign_record175(v_ob, v_k1, v_plain, v_bh, repeat('c', 64), v_now, v_now + 7 * 86400);
    res := res || jsonb_build_object('name', 'a plain h= list is logged and computed as NOT over-signed', 'ok', (v_r ->> 'seq') = '1' and not (v_r ->> 'oversigned')::boolean);
    v_r := public.fmail_dkim_sign_record175(v_ob, v_k1, v_plain, v_bh, repeat('c', 64), v_now, v_now + 7 * 86400);
    res := res || jsonb_build_object('name', 'the same (outbox, key) answers the first row, no duplicate', 'ok', (v_r ->> 'duplicate')::boolean and (select count(*) from public.fmail_dkim_sign_log where outbox_id = v_ob) = 1);
    perform public.fmail_dkim_policy_set175(v_uid, v_box, null, null, null, true, null, null, v_t);
    begin perform public.fmail_dkim_sign_record175(v_ob, v_k1, v_plain, v_bh, repeat('d', 64), v_now, v_now + 7 * 86400); v_ok := false; exception when sqlstate '23505' then v_ok := false; when sqlstate '55000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'with the ratchet on, a signature that is not over-signed is refused', 'ok', v_ok);
    begin update public.fmail_dkim_policy set require_oversign = false where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the ratchet cannot be turned off, not even by a direct UPDATE', 'ok', v_ok);
    begin perform public.fmail_dkim_sign_record175(v_ob, v_k1, v_over, v_bh, repeat('e', 64), v_now, v_now + 30 * 86400); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a signature that lives longer than the policy ttl is refused', 'ok', v_ok);
    begin perform public.fmail_dkim_sign_record175(v_ob, v_k1, v_over, v_bh, repeat('e', 64), v_now, v_now + 600); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a signature that lives under an hour is refused', 'ok', v_ok);
    -- rotation: a second key of the same algorithm revokes the first, whose record must stay published for the overlap
    perform public.fmail_dkim_install170(v_uid, v_box, public.fmail_dkim_selector175(v_box, 'ed25519-sha256'), 'ed25519-sha256', decode(repeat('07', 32), 'hex'), v_wrap, v_nonce, v_t);
    select id into v_k2 from public.fmail_dkim_keys where mailbox_id = v_box and status = 'active' and alg = 'ed25519-sha256';
    begin perform public.fmail_dkim_sign_record175(v_ob, v_k1, v_over, v_bh, repeat('f', 64), v_now, v_now + 7 * 86400); v_ok := false; exception when sqlstate '55000' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a revoked key cannot sign', 'ok', v_ok);
    v_r := public.fmail_dkim_sign_record175(v_ob, v_k2, v_over, v_bh, repeat('f', 64), v_now, v_now + 7 * 86400);
    res := res || jsonb_build_object('name', 'a fully over-signed list is computed as over-signed and accepted under the ratchet', 'ok', (v_r ->> 'oversigned')::boolean and (v_r ->> 'seq') = '2');
    res := res || jsonb_build_object('name', 'rotation report: the old key is retired and its DNS record is kept 14 days', 'ok',
      exists (select 1 from jsonb_array_elements(public.fmail_dkim_rotation175(v_box)) e where e ->> 'key_id' = v_k1::text and e ->> 'state' = 'retired' and not (e ->> 'dns_removable')::boolean and e ->> 'dns_keep_until' is not null)
      and exists (select 1 from jsonb_array_elements(public.fmail_dkim_rotation175(v_box)) e where e ->> 'key_id' = v_k2::text and e ->> 'state' = 'ok'));
    -- proof parsing
    v_r := public.fmail_dkim_proof175(v_uid, v_box, 'gmail', E'mx.google.com;\n       dkim=pass header.i=@anexomail.com header.s=' || (select selector from public.fmail_dkim_keys where id = v_k2) || ' header.b=abcdEFGH;\n       spf=pass smtp.mailfrom=anexomail.com');
    res := res || jsonb_build_object('name', 'a Gmail header: one dkim=pass, key known, aligned, folded lines accepted', 'ok', jsonb_array_length(v_r -> 'results') = 1 and v_r #>> '{results,0,verdict}' = 'pass' and (v_r #>> '{results,0,key_known}')::boolean and (v_r #>> '{results,0,aligned}')::boolean);
    v_r := public.fmail_dkim_proof175(v_uid, v_box, 'outlook', 'spf=pass (sender ip is 1.2.3.4) smtp.mailfrom=anexomail.com; dkim=pass (signature was verified) header.d=anexomail.com;dkim=fail header.d=other.example header.s=zz; dmarc=pass action=none');
    res := res || jsonb_build_object('name', 'an Outlook header with two dkim results: both parsed, the foreign domain is not aligned', 'ok', jsonb_array_length(v_r -> 'results') = 2 and (v_r #>> '{results,0,aligned}')::boolean and not (v_r #>> '{results,1,aligned}')::boolean);
    begin perform public.fmail_dkim_proof175(v_uid, v_box, 'gmail', 'spf=pass smtp.mailfrom=anexomail.com; dmarc=pass action=none header.from=anexomail.com'); v_ok := false; exception when sqlstate '22023' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a header without any dkim= result is refused', 'ok', v_ok);
    -- health + gate
    perform public.fmail_dkim_policy_set175(v_uid, v_box, null, null, null, null, null, true, v_t);
    v_r := public.fmail_dkim_send_gate175(v_box);
    res := res || jsonb_build_object('name', 'gate shut while the active key has no DNS match (reason names the selector)', 'ok', not (v_r ->> 'ok')::boolean and (v_r -> 'reasons' ->> 0) like 'the DNS record for e%');
    perform public.fmail_dkim_dns_record175(v_uid, v_k2, public.fmail_b64_169(decode(repeat('07', 32), 'hex')), true, 'selftest-resolver', 'secure');
    v_r := public.fmail_dkim_send_gate175(v_box);
    res := res || jsonb_build_object('name', 'gate opens once the DNS record is confirmed', 'ok', (v_r ->> 'ok')::boolean);
    -- chains
    res := res || jsonb_build_object('name', 'all three hash chains verify, nothing broken', 'ok', (public.fmail_dkim_chain_verify175() ->> 'broken') = '0' and (public.fmail_dkim_chain_verify175() ->> 'checked')::int >= 8);
    begin update public.fmail_dkim_sign_log set oversigned = false where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the signature log refuses an UPDATE', 'ok', v_ok);
    begin delete from public.fmail_dkim_proof where mailbox_id = v_box; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the proof table refuses a DELETE', 'ok', v_ok);
    res := res || jsonb_build_object('name', 'main ledger chain still verifies', 'ok', public.fmail_ledger_verify(1) >= 1);
    raise exception 'E175_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E175_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E175_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return 'E175 selftest: ERROR ' || sqlerrm || ' (' || sqlstate || ') after ' || jsonb_array_length(res) || ' checks'; end if;
  end;
  for ev in select * from jsonb_array_elements(res) loop if (ev ->> 'ok')::boolean then v_pass := v_pass + 1; else v_fail := v_fail + 1; end if; end loop;
  if v_fail > 0 then return 'E175 selftest: ' || v_pass || ' ok, ' || v_fail || ' failed: ' || (select string_agg(x ->> 'name', ' | ') from jsonb_array_elements(res) x where (x ->> 'ok')::boolean is not true); end if;
  return 'E175 selftest: ' || v_pass || ' ok, 0 failed';
end $$;
revoke all on function public.fmail_dkim_selftest175() from public, anon, authenticated;
grant execute on function public.fmail_dkim_selftest175() to service_role;

select public.fmail_dkim_selftest175() as e175_selftest;
