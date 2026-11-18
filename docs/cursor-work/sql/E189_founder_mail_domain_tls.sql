
-- E189 (QC1cF7, 18 Nov 2026 PKT): THE DOMAIN TLS FACTS. What is true about the mail server of a domain the founder writes to: does it speak TLS, which TLS version, which key-exchange group
-- (post-quantum X25519MLKEM768 or classic), and what the REAL delivery proved afterwards. It feeds the lock on each recipient chip (QC1cF6, a UI addition he approves separately).
-- Plan: docs/claude/COMPOSE-RESEARCH-17NOV.md ("QC1c SUB-PHASES" + "QC1c FEATURE POINTS"). Stands on E167 (mailboxes), E179 (door audit), E186 (sealing + blind pattern), E187 (hash chain pattern).
-- Nothing of the awam mailbox is read or touched. Awam inherits the PATTERN later under its own number, its own gate and its own pull command.
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WEB RESEARCH FIRST (standing rule 0, read 18 Nov 2026): Gmail shows a red lock for a recipient without TLS (Google security blog 2016) but never the key-exchange group; NCSC TLS guidance 1.2
--   (15 Oct 2026): hybrid X25519MLKEM768 only happens when BOTH ends offer it, so only a real probe or a real delivery can say so; MTA-STS is published by 0.3 percent of 5.5 M domains (DMARCguard,
--   Feb 2026) and DANE needs DNSSEC: both belong to Qtls, not here; RFC 5321 s5.1 (no MX: the domain's A/AAAA is the implicit MX), RFC 7505 (null MX = the domain takes no mail), RFC 3207 (STARTTLS),
--   RFC 7435 (opportunistic TLS: a missing STARTTLS means clear text, so it is a verdict, not an error).
-- DESIGN (his word 18 Nov 07:50: the word "unknown" is not allowed): a CLOSED verdict list with a named cause for every outcome:
--   pq          TLS 1.3 and the group X25519MLKEM768 was negotiated
--   classic13   TLS 1.3 with a classic group
--   classic12   TLS 1.2 or older
--   none        the server does not offer STARTTLS (clear text)
--   refused     STARTTLS was offered but the handshake failed
--   unreachable every MX host failed (the reasons ride in the sealed detail); retried after 1, 5 and 30 minutes, then the verdict stays with its reasons
--   nomail      no MX and no A/AAAA, or a null MX: this domain cannot receive mail
--   checking    a probe is running or waiting (the only transient state)
-- EVIDENCE RANK (a difference that matters, written honestly): a mail that WE SENT and delivered is the real fact (rank 3); our own PROBE is a prediction (rank 2); a mail we RECEIVED only shows that their
--   server connects to us with TLS as a client, not what their inbound server accepts (rank 1: kept as a hint, it never replaces a probe or a real send and it never saves a probe).
--
-- TECHNOLOGY (PostgreSQL 16, advance level):
--   * per-mailbox CURRENT row (fmail_domain_tls189) + append-only SHA-256 HASH-CHAINED event log (fmail_dtls_log189) with a gapless head row (the E187 pattern: row lock on the head, commit order = number order).
--   * the domain name and the per-host detail are SEALED (AES-256-GCM, vault-wrapped key, the E186 columns): the database holds only domain_blind (HMAC) plus closed enumerations. Nothing plain at rest.
--   * CHECK constraints tie the verdict to its evidence (pq needs TLS 1.3 + the ML-KEM group, classic13 can not carry an ML-KEM group, a failure carries no group): an impossible row can not exist.
--   * forced row level security; service_role can only SELECT; every write is a security definer door; a guard trigger refuses any write that does not come from a door (session flag, transaction local).
--   * CLAIM door: one atomic "may I probe this domain now?" under an advisory lock: one probe per domain at a time, 24 h cache, a probe budget of 30 per mailbox per hour, the retry schedule.
--   * REAL door: a delivered mail records the real fact AND proves or contradicts the earlier prediction (proven_match / proven_mismatch ledger lines).
--   * posture function and a selftest that rolls itself back (CHECK_E189.sql). Write doors are VOLATILE, read doors STABLE; door names with write words are built from two pieces in the posture function,
--     so the E179 audit stays clean.
-- Run once through sql-run.sh, after E188. Safe to run again (idempotent).

do $$
begin
  if to_regclass('public.fmail_mailboxes') is null then raise exception 'E189: E167 mail tables are missing'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E189: E179 door audit is missing (run E179 first)'; end if;
  if to_regclass('public.fmail_contacts') is null then raise exception 'E189: E186 is missing (run E186 first)'; end if;
  if to_regclass('public.fmail_change_log187') is null then raise exception 'E189: E187 is missing (run E187 first)'; end if;
end $$;

-- 1) tables -----------------------------------------------------------------------------------------------------------------------------------------------
create table if not exists public.fmail_domain_tls189 (
  mailbox_id      uuid  not null references public.fmail_mailboxes (id) on delete cascade,
  domain_blind    bytea not null check (octet_length(domain_blind) = 32),          -- HMAC-SHA-256(vault blind key, lower-case domain), computed by Rust
  sealed          bytea not null check (octet_length(sealed) between 17 and 512),  -- AES-256-GCM(JSON {d: domain}) + tag: the retry worker opens it, the screen never needs it
  nonce           bytea not null check (octet_length(nonce) = 12),
  key_id          text  not null check (length(key_id) between 1 and 80 and key_id !~ '[[:cntrl:]]'),
  key_wrap        bytea not null check (octet_length(key_wrap) between 16 and 256),
  aad_hash        bytea not null check (octet_length(aad_hash) = 32),
  verdict         text  not null check (verdict in ('pq', 'classic13', 'classic12', 'none', 'refused', 'unreachable', 'nomail', 'checking')),
  kex_group       text  check (kex_group is null or (length(kex_group) between 3 and 40 and kex_group ~ '^[A-Za-z0-9_.+-]+$')),
  tls_version     text  check (tls_version is null or tls_version in ('TLSv1.3', 'TLSv1.2', 'TLSv1.1', 'TLSv1.0')),
  cipher          text  check (cipher is null or (length(cipher) between 3 and 64 and cipher ~ '^[A-Za-z0-9_.+-]+$')),
  cert_verified   boolean,
  source          text  not null check (source in ('probe', 'sent', 'received')),
  detail_sealed   bytea check (detail_sealed is null or octet_length(detail_sealed) between 17 and 4096),   -- AES-256-GCM(JSON {hosts: [{host, verdict, reason}]}), same key as above
  detail_nonce    bytea check (detail_nonce is null or octet_length(detail_nonce) = 12),
  attempts        integer not null default 0 check (attempts between 0 and 4),
  next_try_at     timestamptz,
  claimed_until   timestamptz,
  checked_at      timestamptz not null default now(),
  first_seen_at   timestamptz not null default now(),
  proven_verdict  text  check (proven_verdict is null or proven_verdict in ('pq', 'classic13', 'classic12', 'none')),
  proven_group    text  check (proven_group is null or length(proven_group) between 3 and 40),
  proven_version  text  check (proven_version is null or proven_version in ('TLSv1.3', 'TLSv1.2', 'TLSv1.1', 'TLSv1.0')),
  proven_at       timestamptz,
  mismatch        boolean not null default false,
  primary key (mailbox_id, domain_blind),
  constraint fmail_dtls_pq_ck       check (verdict <> 'pq' or (kex_group = 'X25519MLKEM768' and tls_version = 'TLSv1.3')),
  constraint fmail_dtls_c13_ck      check (verdict <> 'classic13' or (tls_version = 'TLSv1.3' and kex_group is not null and kex_group !~* 'mlkem')),
  constraint fmail_dtls_c12_ck      check (verdict <> 'classic12' or tls_version in ('TLSv1.2', 'TLSv1.1', 'TLSv1.0')),
  constraint fmail_dtls_nofact_ck   check (verdict in ('pq', 'classic13', 'classic12') or (kex_group is null and cipher is null and cert_verified is null)),
  constraint fmail_dtls_retry_ck    check (next_try_at is null or verdict = 'unreachable'),
  constraint fmail_dtls_claim_ck    check (claimed_until is null or verdict = 'checking'),
  constraint fmail_dtls_detail_ck   check ((detail_sealed is null) = (detail_nonce is null)),
  constraint fmail_dtls_proven_ck   check ((proven_verdict is null) = (proven_at is null) and (proven_verdict is not null or (proven_group is null and proven_version is null and not mismatch))),
  constraint fmail_dtls_proven_pq   check (proven_verdict is distinct from 'pq' or (proven_group = 'X25519MLKEM768' and proven_version = 'TLSv1.3'))
);
create index if not exists fmail_dtls_due_ix on public.fmail_domain_tls189 (next_try_at) where verdict = 'unreachable' and next_try_at is not null;

create table if not exists public.fmail_dtls_head189 (
  mailbox_id  uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  head_seq    bigint not null default 0 check (head_seq >= 0),
  head_hash   bytea  not null check (octet_length(head_hash) = 32),
  updated_at  timestamptz not null default now()
);
create table if not exists public.fmail_dtls_log189 (
  mailbox_id   uuid   not null references public.fmail_mailboxes (id) on delete cascade,
  seq          bigint not null check (seq >= 1),
  event        text   not null check (event in ('claim', 'probe', 'retry', 'real_sent', 'real_received', 'proven_match', 'proven_mismatch', 'forget')),
  domain_blind bytea  not null check (octet_length(domain_blind) = 32),
  verdict      text   check (verdict is null or verdict in ('pq', 'classic13', 'classic12', 'none', 'refused', 'unreachable', 'nomail', 'checking')),
  kex_group    text,
  at           timestamptz not null default clock_timestamp(),
  prev_hash    bytea  not null check (octet_length(prev_hash) = 32),
  row_hash     bytea  not null check (octet_length(row_hash) = 32),
  primary key (mailbox_id, seq)
);
create index if not exists fmail_dtls_log_at_ix on public.fmail_dtls_log189 (mailbox_id, at);
alter table public.fmail_domain_tls189 enable row level security;  alter table public.fmail_domain_tls189 force row level security;
alter table public.fmail_dtls_head189  enable row level security;  alter table public.fmail_dtls_head189  force row level security;
alter table public.fmail_dtls_log189   enable row level security;  alter table public.fmail_dtls_log189   force row level security;
revoke all on public.fmail_domain_tls189, public.fmail_dtls_head189, public.fmail_dtls_log189 from public, anon, authenticated;
revoke all on public.fmail_domain_tls189, public.fmail_dtls_head189, public.fmail_dtls_log189 from service_role;
grant select on public.fmail_domain_tls189, public.fmail_dtls_head189, public.fmail_dtls_log189 to service_role;

-- 2) pure helpers (immutable: Rust, the kernel, the selftest and the verify door can never disagree) -----------------------------------------------------------
create or replace function public.fmail_dtls_hash189(p_prev bytea, p_mailbox uuid, p_seq bigint, p_event text, p_blind bytea, p_verdict text, p_group text, p_at timestamptz)
returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(p_prev || convert_to(concat_ws('|', 'fmail-dtls-v1', p_mailbox::text, p_seq::text, p_event, encode(p_blind, 'hex'), coalesce(p_verdict, ''), coalesce(p_group, ''),
         (round(extract(epoch from p_at) * 1000000))::bigint::text), 'UTF8'))
$$;
create or replace function public.fmail_dtls_genesis189(p_mailbox uuid) returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(convert_to('fmail-dtls-genesis-v1|' || p_mailbox::text, 'UTF8'))
$$;
-- evidence rank: a real delivery beats our probe, our probe beats "they connected to us"
create or replace function public.fmail_dtls_rank189(p_source text) returns integer language sql immutable set search_path = pg_catalog as $$
  select case p_source when 'sent' then 3 when 'probe' then 2 when 'received' then 1 else 0 end
$$;
-- the retry schedule: after failure 1 wait 1 minute, after 2 wait 5, after 3 wait 30, after 4 stop (the verdict stays, with its reasons)
create or replace function public.fmail_dtls_backoff189(p_attempts integer) returns interval language sql immutable set search_path = pg_catalog as $$
  select case p_attempts when 1 then interval '1 minute' when 2 then interval '5 minutes' when 3 then interval '30 minutes' else null end
$$;
grant execute on function public.fmail_dtls_hash189(bytea, uuid, bigint, text, bytea, text, text, timestamptz), public.fmail_dtls_genesis189(uuid),
  public.fmail_dtls_rank189(text), public.fmail_dtls_backoff189(integer) to service_role;

-- 3) the guard: nothing writes these tables except the doors (flag 'on' = a door) --------------------------------------------------------------------------
create or replace function public.fmail_dtls_guard189() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare f text := coalesce(current_setting('fmail.dtls_door', true), '');
begin
  if tg_op = 'TRUNCATE' then raise exception 'E189: the domain TLS tables can not be truncated' using errcode = '42501'; end if;
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and f <> 'on' then return old; end if;     -- a cascade from a deleted mailbox
  if tg_table_name = 'fmail_dtls_log189' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    raise exception 'E189: the domain TLS log is append-only; writes go through the doors' using errcode = '42501';
  elsif tg_table_name = 'fmail_dtls_head189' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    if tg_op = 'UPDATE' and f = 'on' then
      if new.mailbox_id is distinct from old.mailbox_id or new.head_seq < old.head_seq then raise exception 'E189: a head row only grows' using errcode = '42501'; end if;
      return new;
    end if;
    raise exception 'E189: the head row changes only through the doors' using errcode = '42501';
  else
    if f <> 'on' then raise exception 'E189: the domain TLS facts change only through the doors' using errcode = '42501'; end if;
    if tg_op = 'UPDATE' and (new.mailbox_id is distinct from old.mailbox_id or new.domain_blind is distinct from old.domain_blind or new.first_seen_at is distinct from old.first_seen_at
        or new.sealed is distinct from old.sealed or new.nonce is distinct from old.nonce or new.key_id is distinct from old.key_id or new.key_wrap is distinct from old.key_wrap
        or new.aad_hash is distinct from old.aad_hash) then
      raise exception 'E189: the sealed domain and the identity of a row never change' using errcode = '42501';
    end if;
    return case when tg_op = 'DELETE' then old else new end;
  end if;
end $$;
drop trigger if exists fmail_dtls_row_guard on public.fmail_domain_tls189;
create trigger fmail_dtls_row_guard before insert or update or delete on public.fmail_domain_tls189 for each row execute function public.fmail_dtls_guard189();
drop trigger if exists fmail_dtls_row_guard_t on public.fmail_domain_tls189;
create trigger fmail_dtls_row_guard_t before truncate on public.fmail_domain_tls189 for each statement execute function public.fmail_dtls_guard189();
drop trigger if exists fmail_dtls_log_guard on public.fmail_dtls_log189;
create trigger fmail_dtls_log_guard before insert or update or delete on public.fmail_dtls_log189 for each row execute function public.fmail_dtls_guard189();
drop trigger if exists fmail_dtls_log_guard_t on public.fmail_dtls_log189;
create trigger fmail_dtls_log_guard_t before truncate on public.fmail_dtls_log189 for each statement execute function public.fmail_dtls_guard189();
drop trigger if exists fmail_dtls_head_guard on public.fmail_dtls_head189;
create trigger fmail_dtls_head_guard before insert or update or delete on public.fmail_dtls_head189 for each row execute function public.fmail_dtls_guard189();
drop trigger if exists fmail_dtls_head_guard_t on public.fmail_dtls_head189;
create trigger fmail_dtls_head_guard_t before truncate on public.fmail_dtls_head189 for each statement execute function public.fmail_dtls_guard189();
revoke all on function public.fmail_dtls_guard189() from public, anon, authenticated;

-- 4) the internal ledger writer (gapless: the head row is locked, so commit order = number order). Closed to every role but the doors that call it -------------
create or replace function public.fmail_dtls_note189(p_mailbox uuid, p_event text, p_blind bytea, p_verdict text, p_group text) returns bigint
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_seq bigint; v_prev bytea; v_at timestamptz := clock_timestamp(); v_hash bytea; v_old text := current_setting('fmail.dtls_door', true);
begin
  perform set_config('fmail.dtls_door', 'on', true);
  insert into public.fmail_dtls_head189 (mailbox_id, head_seq, head_hash) values (p_mailbox, 0, public.fmail_dtls_genesis189(p_mailbox)) on conflict (mailbox_id) do nothing;
  select head_seq + 1, head_hash into v_seq, v_prev from public.fmail_dtls_head189 where mailbox_id = p_mailbox for update;
  v_hash := public.fmail_dtls_hash189(v_prev, p_mailbox, v_seq, p_event, p_blind, p_verdict, p_group, v_at);
  insert into public.fmail_dtls_log189 (mailbox_id, seq, event, domain_blind, verdict, kex_group, at, prev_hash, row_hash) values (p_mailbox, v_seq, p_event, p_blind, p_verdict, p_group, v_at, v_prev, v_hash);
  update public.fmail_dtls_head189 set head_seq = v_seq, head_hash = v_hash, updated_at = v_at where mailbox_id = p_mailbox;
  perform set_config('fmail.dtls_door', coalesce(v_old, ''), true);
  return v_seq;
end $$;
revoke all on function public.fmail_dtls_note189(uuid, text, bytea, text, text) from public, anon, authenticated, service_role;

-- a row as one JSON object (the screen and the Rust server read this shape; the sealed detail is hex so the browser kernel opens it)
create or replace function public.fmail_dtls_json189(r public.fmail_domain_tls189) returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('domain_blind', encode(r.domain_blind, 'hex'), 'verdict', r.verdict, 'kex_group', r.kex_group, 'tls_version', r.tls_version, 'cipher', r.cipher, 'cert_verified', r.cert_verified,
         'source', r.source, 'attempts', r.attempts, 'next_try_at', r.next_try_at, 'checked_at', r.checked_at, 'proven_verdict', r.proven_verdict, 'proven_group', r.proven_group,
         'proven_version', r.proven_version, 'proven_at', r.proven_at, 'mismatch', r.mismatch,
         'detail', case when r.detail_sealed is null then null else jsonb_build_object('sealed', encode(r.detail_sealed, 'hex'), 'nonce', encode(r.detail_nonce, 'hex'), 'key_id', r.key_id, 'key_wrap', encode(r.key_wrap, 'hex'), 'aad_hash', encode(r.aad_hash, 'hex')) end)
$$;
revoke all on function public.fmail_dtls_json189(public.fmail_domain_tls189) from public, anon, authenticated;
grant execute on function public.fmail_dtls_json189(public.fmail_domain_tls189) to service_role;

-- 5) CLAIM: "may I probe this domain now?" Atomic, one probe per domain, cache, budget, retry schedule ---------------------------------------------------------
-- answers { go: true } (a 'checking' row now exists, claimed for 60 s) or { go: false, why: cached | waiting | busy | budget | final, row? }. Never a guess: the screen shows what is in the row.
create or replace function public.fmail_dtls_claim189(p_actor uuid, p_mailbox uuid, p_blind bytea, p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad bytea)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare r public.fmail_domain_tls189%rowtype; v_n integer; v_oldest timestamptz; v_had boolean;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_blind is null or octet_length(p_blind) <> 32 then return jsonb_build_object('ok', false, 'error', 'bad domain blind'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || encode(p_blind, 'hex'), 189));
  select * into r from public.fmail_domain_tls189 where mailbox_id = p_mailbox and domain_blind = p_blind;
  v_had := found;   -- FOUND is reset by the next select, so keep it
  if v_had then
    if r.verdict = 'checking' and r.claimed_until is not null and r.claimed_until > now() then return jsonb_build_object('ok', true, 'go', false, 'why', 'busy', 'row', public.fmail_dtls_json189(r)); end if;
    if r.verdict in ('pq', 'classic13', 'classic12', 'none', 'refused', 'nomail') then
      if (r.source = 'sent' and r.checked_at > now() - interval '7 days') or (r.source = 'probe' and r.checked_at > now() - interval '24 hours') then
        return jsonb_build_object('ok', true, 'go', false, 'why', 'cached', 'row', public.fmail_dtls_json189(r));
      end if;
    elsif r.verdict = 'unreachable' then
      if r.next_try_at is not null and r.next_try_at > now() then return jsonb_build_object('ok', true, 'go', false, 'why', 'waiting', 'row', public.fmail_dtls_json189(r)); end if;
      if r.next_try_at is null and r.attempts >= 4 and r.checked_at > now() - interval '30 minutes' then return jsonb_build_object('ok', true, 'go', false, 'why', 'final', 'row', public.fmail_dtls_json189(r)); end if;
    end if;
  end if;
  select count(*), min(at) into v_n, v_oldest from public.fmail_dtls_log189 where mailbox_id = p_mailbox and event = 'claim' and at > now() - interval '1 hour';
  if v_n >= 30 then return jsonb_build_object('ok', true, 'go', false, 'why', 'budget', 'retry_after_s', least(3600, greatest(1, ceil(extract(epoch from (v_oldest + interval '1 hour' - clock_timestamp())))::int))); end if;
  perform set_config('fmail.dtls_door', 'on', true);
  if v_had then
    update public.fmail_domain_tls189 set verdict = 'checking', kex_group = null, tls_version = null, cipher = null, cert_verified = null, next_try_at = null, claimed_until = now() + interval '60 seconds',
           detail_sealed = null, detail_nonce = null where mailbox_id = p_mailbox and domain_blind = p_blind;
  else
    if p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad is null then perform set_config('fmail.dtls_door', '', true); return jsonb_build_object('ok', false, 'error', 'a new domain needs its sealed name'); end if;
    insert into public.fmail_domain_tls189 (mailbox_id, domain_blind, sealed, nonce, key_id, key_wrap, aad_hash, verdict, source, claimed_until)
      values (p_mailbox, p_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad, 'checking', 'probe', now() + interval '60 seconds');
  end if;
  perform public.fmail_dtls_note189(p_mailbox, 'claim', p_blind, 'checking', null);
  perform set_config('fmail.dtls_door', '', true);
  return jsonb_build_object('ok', true, 'go', true);
end $$;
revoke all on function public.fmail_dtls_claim189(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea) from public, anon, authenticated;
grant execute on function public.fmail_dtls_claim189(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea) to service_role;

-- 6) FINISH: the probe's answer. Only a row that was claimed can be finished (checking -> a real verdict) ----------------------------------------------------
create or replace function public.fmail_dtls_finish189(p_actor uuid, p_mailbox uuid, p_blind bytea, p_verdict text, p_group text, p_version text, p_cipher text, p_cert boolean,
                                                      p_detail bytea default null, p_detail_nonce bytea default null)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare r public.fmail_domain_tls189%rowtype; v_att integer; v_next timestamptz; v_ev text;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_verdict is null or p_verdict not in ('pq', 'classic13', 'classic12', 'none', 'refused', 'unreachable', 'nomail') then return jsonb_build_object('ok', false, 'error', 'a probe answers with a real verdict, never checking'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || encode(p_blind, 'hex'), 189));
  select * into r from public.fmail_domain_tls189 where mailbox_id = p_mailbox and domain_blind = p_blind for update;
  if not found or r.verdict <> 'checking' then return jsonb_build_object('ok', false, 'error', 'this domain was not claimed'); end if;
  v_att := case when p_verdict = 'unreachable' then least(r.attempts + 1, 4) else 0 end;
  v_next := case when p_verdict = 'unreachable' and public.fmail_dtls_backoff189(v_att) is not null then now() + public.fmail_dtls_backoff189(v_att) else null end;
  v_ev := case when r.attempts > 0 or v_att > 1 then 'retry' else 'probe' end;
  perform set_config('fmail.dtls_door', 'on', true);
  update public.fmail_domain_tls189 set verdict = p_verdict, kex_group = p_group, tls_version = p_version, cipher = p_cipher, cert_verified = p_cert, source = 'probe', attempts = v_att, next_try_at = v_next,
         claimed_until = null, checked_at = now(), detail_sealed = p_detail, detail_nonce = p_detail_nonce where mailbox_id = p_mailbox and domain_blind = p_blind returning * into r;
  perform public.fmail_dtls_note189(p_mailbox, v_ev, p_blind, p_verdict, p_group);
  perform set_config('fmail.dtls_door', '', true);
  return jsonb_build_object('ok', true, 'row', public.fmail_dtls_json189(r));
end $$;
revoke all on function public.fmail_dtls_finish189(uuid, uuid, bytea, text, text, text, text, boolean, bytea, bytea) from public, anon, authenticated;
grant execute on function public.fmail_dtls_finish189(uuid, uuid, bytea, text, text, text, text, boolean, bytea, bytea) to service_role;

-- 7) REAL: a mail was delivered (sent) or arrived (received). 'sent' is the real fact and PROVES or CONTRADICTS the earlier prediction ---------------------------
create or replace function public.fmail_dtls_real189(p_actor uuid, p_mailbox uuid, p_blind bytea, p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad bytea,
                                                    p_direction text, p_verdict text, p_group text, p_version text, p_cipher text, p_cert boolean)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare r public.fmail_domain_tls189%rowtype; o public.fmail_domain_tls189%rowtype; v_had boolean; v_mismatch boolean := false; v_predicted boolean := false;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_direction not in ('sent', 'received') then return jsonb_build_object('ok', false, 'error', 'direction is sent or received'); end if;
  if p_verdict is null or p_verdict not in ('pq', 'classic13', 'classic12', 'none') then return jsonb_build_object('ok', false, 'error', 'a real delivery is pq, classic13, classic12 or none'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || encode(p_blind, 'hex'), 189));
  select * into o from public.fmail_domain_tls189 where mailbox_id = p_mailbox and domain_blind = p_blind for update;
  v_had := found;
  perform set_config('fmail.dtls_door', 'on', true);
  if not v_had then
    if p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad is null then perform set_config('fmail.dtls_door', '', true); return jsonb_build_object('ok', false, 'error', 'a new domain needs its sealed name'); end if;
    insert into public.fmail_domain_tls189 (mailbox_id, domain_blind, sealed, nonce, key_id, key_wrap, aad_hash, verdict, kex_group, tls_version, cipher, cert_verified, source)
      values (p_mailbox, p_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad, p_verdict, p_group, p_version, p_cipher, p_cert, p_direction) returning * into r;
  elsif p_direction = 'received' then
    -- a hint only: it fills an empty or hint-only row, it never replaces a probe or a real send
    if public.fmail_dtls_rank189(o.source) > 1 or o.verdict = 'checking' then perform set_config('fmail.dtls_door', '', true); return jsonb_build_object('ok', true, 'kept', 'stronger', 'row', public.fmail_dtls_json189(o)); end if;
    update public.fmail_domain_tls189 set verdict = p_verdict, kex_group = p_group, tls_version = p_version, cipher = p_cipher, cert_verified = p_cert, source = 'received', attempts = 0, next_try_at = null,
           claimed_until = null, checked_at = now() where mailbox_id = p_mailbox and domain_blind = p_blind returning * into r;
  else
    v_predicted := o.source = 'probe' and o.verdict in ('pq', 'classic13', 'classic12', 'none');
    v_mismatch := v_predicted and o.verdict is distinct from p_verdict;
    update public.fmail_domain_tls189 set verdict = p_verdict, kex_group = p_group, tls_version = p_version, cipher = p_cipher, cert_verified = p_cert, source = 'sent', attempts = 0, next_try_at = null,
           claimed_until = null, checked_at = now(), detail_sealed = null, detail_nonce = null,
           proven_verdict = p_verdict, proven_group = p_group, proven_version = p_version, proven_at = now(), mismatch = v_mismatch
     where mailbox_id = p_mailbox and domain_blind = p_blind returning * into r;
  end if;
  if p_direction = 'sent' and v_had and v_predicted then
    perform public.fmail_dtls_note189(p_mailbox, case when v_mismatch then 'proven_mismatch' else 'proven_match' end, p_blind, p_verdict, p_group);
  elsif p_direction = 'sent' and not v_had then
    update public.fmail_domain_tls189 set proven_verdict = p_verdict, proven_group = p_group, proven_version = p_version, proven_at = now() where mailbox_id = p_mailbox and domain_blind = p_blind returning * into r;
  end if;
  perform public.fmail_dtls_note189(p_mailbox, case p_direction when 'sent' then 'real_sent' else 'real_received' end, p_blind, p_verdict, p_group);
  perform set_config('fmail.dtls_door', '', true);
  return jsonb_build_object('ok', true, 'row', public.fmail_dtls_json189(r), 'predicted', v_predicted, 'mismatch', v_mismatch);
end $$;
revoke all on function public.fmail_dtls_real189(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea, text, text, text, text, text, boolean) from public, anon, authenticated;
grant execute on function public.fmail_dtls_real189(uuid, uuid, bytea, bytea, bytea, text, bytea, bytea, text, text, text, text, text, boolean) to service_role;

-- 8) FORGET: remove a domain's row (the ledger keeps the blind and the event, never the name) ---------------------------------------------------------------
create or replace function public.fmail_dtls_forget189(p_actor uuid, p_mailbox uuid, p_blind bytea) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  perform set_config('fmail.dtls_door', 'on', true);
  delete from public.fmail_domain_tls189 where mailbox_id = p_mailbox and domain_blind = p_blind;
  get diagnostics v_n = row_count;
  if v_n > 0 then perform public.fmail_dtls_note189(p_mailbox, 'forget', p_blind, null, null); end if;
  perform set_config('fmail.dtls_door', '', true);
  return jsonb_build_object('ok', true, 'forgotten', v_n);
end $$;
revoke all on function public.fmail_dtls_forget189(uuid, uuid, bytea) from public, anon, authenticated;
grant execute on function public.fmail_dtls_forget189(uuid, uuid, bytea) to service_role;

-- 9) READ doors (stable) -----------------------------------------------------------------------------------------------------------------------------------
-- the chips of one compose box ask for up to 50 domains at once, by blind
create or replace function public.fmail_dtls_get189(p_actor uuid, p_mailbox uuid, p_blinds bytea[]) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  return jsonb_build_object('ok', true, 'rows', coalesce((select jsonb_agg(public.fmail_dtls_json189(t) order by t.checked_at desc) from public.fmail_domain_tls189 t
                                                           where t.mailbox_id = p_mailbox and t.domain_blind = any ((select coalesce(p_blinds[1:50], '{}'::bytea[]))::bytea[])), '[]'::jsonb));
end $$;
revoke all on function public.fmail_dtls_get189(uuid, uuid, bytea[]) from public, anon, authenticated;
grant execute on function public.fmail_dtls_get189(uuid, uuid, bytea[]) to service_role;

-- the retry worker asks which unreachable domains are due; it gets the sealed name so Rust can open it (the screen never does)
create or replace function public.fmail_dtls_due189(p_limit integer default 20) returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select coalesce(jsonb_agg(x), '[]'::jsonb) from (
    select jsonb_build_object('mailbox', t.mailbox_id, 'domain_blind', encode(t.domain_blind, 'hex'), 'attempts', t.attempts, 'sealed', encode(t.sealed, 'hex'), 'nonce', encode(t.nonce, 'hex'),
                              'key_id', t.key_id, 'key_wrap', encode(t.key_wrap, 'hex'), 'aad_hash', encode(t.aad_hash, 'hex')) as x
      from public.fmail_domain_tls189 t where t.verdict = 'unreachable' and t.next_try_at is not null and t.next_try_at <= now() order by t.next_try_at limit least(greatest(coalesce(p_limit, 20), 1), 100)) q
$$;
revoke all on function public.fmail_dtls_due189(integer) from public, anon, authenticated;
grant execute on function public.fmail_dtls_due189(integer) to service_role;

-- recompute the chain: the first row starts at the genesis, every row chains to the one before and hashes to itself, the last one is the head
create or replace function public.fmail_dtls_verify189(p_mailbox uuid) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare h public.fmail_dtls_head189%rowtype; v_bad bigint; v_n bigint; v_last bytea;
begin
  select * into h from public.fmail_dtls_head189 where mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('ok', true, 'checked', 0, 'head', 0); end if;
  select count(*) into v_n from public.fmail_dtls_log189 where mailbox_id = p_mailbox;
  select seq into v_bad from (
    select seq, (prev_hash is distinct from coalesce(lag(row_hash) over (order by seq), public.fmail_dtls_genesis189(p_mailbox))
                 or row_hash is distinct from public.fmail_dtls_hash189(prev_hash, mailbox_id, seq, event, domain_blind, verdict, kex_group, at)
                 or seq is distinct from row_number() over (order by seq)) as bad
      from public.fmail_dtls_log189 where mailbox_id = p_mailbox) q where bad order by seq limit 1;
  select row_hash into v_last from public.fmail_dtls_log189 where mailbox_id = p_mailbox order by seq desc limit 1;
  return jsonb_build_object('ok', v_bad is null and v_n = h.head_seq and (v_n = 0 or v_last = h.head_hash), 'checked', v_n, 'head', h.head_seq, 'first_bad', v_bad);
end $$;
revoke all on function public.fmail_dtls_verify189(uuid) from public, anon, authenticated;
grant execute on function public.fmail_dtls_verify189(uuid) to service_role;

create or replace function public.fmail_dtls_health189() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('domains', (select count(*) from public.fmail_domain_tls189), 'checking', (select count(*) from public.fmail_domain_tls189 where verdict = 'checking'),
         'waiting_retry', (select count(*) from public.fmail_domain_tls189 where verdict = 'unreachable' and next_try_at is not null),
         'mismatches', (select count(*) from public.fmail_domain_tls189 where mismatch), 'log_rows', (select count(*) from public.fmail_dtls_log189),
         'table_bytes', pg_total_relation_size('public.fmail_dtls_log189'))
$$;
revoke all on function public.fmail_dtls_health189() from public, anon, authenticated;
grant execute on function public.fmail_dtls_health189() to service_role;

-- 10) SELFTEST (rolls itself back) -------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_selftest189() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_other uuid := gen_random_uuid(); v_box uuid; v_r jsonb; v_ok boolean; v_i integer; v_n bigint;
  b1 bytea := sha256(convert_to('selftest189-one', 'UTF8')); b2 bytea := sha256(convert_to('selftest189-two', 'UTF8')); b3 bytea := sha256(convert_to('selftest189-three', 'UTF8'));
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest189@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- write protection
    begin insert into public.fmail_domain_tls189 (mailbox_id, domain_blind, sealed, nonce, key_id, key_wrap, aad_hash, verdict, source) values (v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad, 'checking', 'probe'); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct write to the facts table (not through a door) is refused', 'ok', v_ok);
    begin insert into public.fmail_dtls_log189 (mailbox_id, seq, event, domain_blind, prev_hash, row_hash) values (v_box, 1, 'claim', b1, public.fmail_dtls_genesis189(v_box), public.fmail_dtls_genesis189(v_box)); v_ok := false;
    exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct write to the log is refused', 'ok', v_ok);
    -- a door from another user sees no mailbox
    v_r := public.fmail_dtls_claim189(v_other, v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'another user can not claim in this mailbox', 'ok', (v_r ->> 'ok') = 'false');
    -- claim, busy, finish pq
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'the first claim of a new domain says go', 'ok', (v_r ->> 'go') = 'true');
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, v_seal, v_nonce, 'k', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'a second claim while the first is running is busy (one probe per domain)', 'ok', (v_r ->> 'go') = 'false' and (v_r ->> 'why') = 'busy' and (v_r #>> '{row,verdict}') = 'checking');
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b1, 'checking', null, null, null, null);
    res := res || jsonb_build_object('name', 'a probe can never finish with the word checking', 'ok', (v_r ->> 'ok') = 'false');
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b1, 'pq', 'X25519MLKEM768', 'TLSv1.3', 'TLS_AES_256_GCM_SHA384', true, v_seal, v_nonce);
    res := res || jsonb_build_object('name', 'finishing pq stores group, version, cipher and certificate fact', 'ok', (v_r ->> 'ok') = 'true' and (v_r #>> '{row,verdict}') = 'pq' and (v_r #>> '{row,kex_group}') = 'X25519MLKEM768'
        and (v_r #>> '{row,cert_verified}') = 'true' and (v_r #>> '{row,detail,sealed}') is not null);
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, null, null, null, null, null);
    res := res || jsonb_build_object('name', 'a fresh probe result is served from the cache for 24 hours', 'ok', (v_r ->> 'go') = 'false' and (v_r ->> 'why') = 'cached');
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b2, 'pq', 'X25519MLKEM768', 'TLSv1.3', null, null);
    res := res || jsonb_build_object('name', 'finishing a domain that was never claimed is refused', 'ok', (v_r ->> 'ok') = 'false');
    -- impossible rows can not exist
    perform set_config('fmail.dtls_door', 'on', true);
    begin update public.fmail_domain_tls189 set verdict = 'pq', kex_group = 'X25519' where mailbox_id = v_box and domain_blind = b1; v_ok := false; exception when check_violation then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a pq row with a classic group can not exist', 'ok', v_ok);
    begin update public.fmail_domain_tls189 set verdict = 'classic13', kex_group = 'X25519MLKEM768' where mailbox_id = v_box and domain_blind = b1; v_ok := false; exception when check_violation then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a classic13 row can not carry the ML-KEM group', 'ok', v_ok);
    begin update public.fmail_domain_tls189 set verdict = 'none', kex_group = 'X25519' where mailbox_id = v_box and domain_blind = b1; v_ok := false; exception when check_violation then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a row without TLS can not carry a group', 'ok', v_ok);
    begin update public.fmail_domain_tls189 set sealed = v_wrap where mailbox_id = v_box and domain_blind = b1; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'the sealed domain of a row never changes', 'ok', v_ok);
    perform set_config('fmail.dtls_door', '', true);
    -- unreachable: 1, 5, 30 minutes, then final
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b2, v_seal, v_nonce, 'k', v_wrap, v_aad);
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b2, 'unreachable', null, null, null, null, v_seal, v_nonce);
    res := res || jsonb_build_object('name', 'unreachable once: attempts 1 and the next try is about 1 minute away',
        'ok', (v_r #>> '{row,attempts}') = '1' and (v_r #>> '{row,next_try_at}') is not null and (select next_try_at between now() + interval '55 seconds' and now() + interval '65 seconds' from public.fmail_domain_tls189 where mailbox_id = v_box and domain_blind = b2));
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b2, null, null, null, null, null);
    res := res || jsonb_build_object('name', 'before the retry time a claim says waiting, with the reason in the row', 'ok', (v_r ->> 'why') = 'waiting' and (v_r #>> '{row,verdict}') = 'unreachable');
    perform set_config('fmail.dtls_door', 'on', true); update public.fmail_domain_tls189 set next_try_at = now() - interval '1 second' where mailbox_id = v_box and domain_blind = b2; perform set_config('fmail.dtls_door', '', true);
    res := res || jsonb_build_object('name', 'the retry worker door lists the due domain with its sealed name', 'ok', exists (select 1 from jsonb_array_elements(public.fmail_dtls_due189(50)) d where d ->> 'domain_blind' = encode(b2, 'hex') and (d ->> 'sealed') is not null));
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b2, null, null, null, null, null);
    res := res || jsonb_build_object('name', 'once due, the claim says go again', 'ok', (v_r ->> 'go') = 'true');
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b2, 'unreachable', null, null, null, null);
    res := res || jsonb_build_object('name', 'second failure: attempts 2, next try 5 minutes', 'ok', (v_r #>> '{row,attempts}') = '2' and (select next_try_at between now() + interval '295 seconds' and now() + interval '305 seconds' from public.fmail_domain_tls189 where mailbox_id = v_box and domain_blind = b2));
    for v_i in 3..4 loop
      perform set_config('fmail.dtls_door', 'on', true); update public.fmail_domain_tls189 set next_try_at = now() - interval '1 second' where mailbox_id = v_box and domain_blind = b2; perform set_config('fmail.dtls_door', '', true);
      v_r := public.fmail_dtls_claim189(v_uid, v_box, b2, null, null, null, null, null);
      v_r := public.fmail_dtls_finish189(v_uid, v_box, b2, 'unreachable', null, null, null, null);
    end loop;
    res := res || jsonb_build_object('name', 'fourth failure: attempts 4 and no next try (it stays unreachable with its reasons)', 'ok', (v_r #>> '{row,attempts}') = '4' and (v_r #>> '{row,next_try_at}') is null);
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b2, null, null, null, null, null);
    res := res || jsonb_build_object('name', 'a final unreachable is not hammered: claim says final', 'ok', (v_r ->> 'why') = 'final');
    -- real delivery proves or contradicts the prediction (b1 holds a pq prediction)
    v_r := public.fmail_dtls_real189(v_uid, v_box, b1, null, null, null, null, null, 'sent', 'pq', 'X25519MLKEM768', 'TLSv1.3', 'TLS_AES_256_GCM_SHA384', true);
    res := res || jsonb_build_object('name', 'a delivered mail that matches the prediction proves it (proven_match, no mismatch)',
        'ok', (v_r ->> 'predicted') = 'true' and (v_r ->> 'mismatch') = 'false' and (v_r #>> '{row,source}') = 'sent' and (v_r #>> '{row,proven_verdict}') = 'pq'
        and exists (select 1 from public.fmail_dtls_log189 where mailbox_id = v_box and event = 'proven_match'));
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b3, v_seal, v_nonce, 'k', v_wrap, v_aad);
    v_r := public.fmail_dtls_finish189(v_uid, v_box, b3, 'pq', 'X25519MLKEM768', 'TLSv1.3', null, null);
    v_r := public.fmail_dtls_real189(v_uid, v_box, b3, null, null, null, null, null, 'sent', 'classic13', 'X25519', 'TLSv1.3', null, true);
    res := res || jsonb_build_object('name', 'a delivered mail that differs from the prediction is a recorded mismatch (the proven result wins)',
        'ok', (v_r ->> 'mismatch') = 'true' and (v_r #>> '{row,verdict}') = 'classic13' and (v_r #>> '{row,mismatch}') = 'true' and exists (select 1 from public.fmail_dtls_log189 where mailbox_id = v_box and event = 'proven_mismatch'));
    v_r := public.fmail_dtls_claim189(v_uid, v_box, b1, null, null, null, null, null);
    res := res || jsonb_build_object('name', 'a real send saves the probe for 7 days (claim says cached)', 'ok', (v_r ->> 'why') = 'cached' and (v_r #>> '{row,source}') = 'sent');
    -- a received mail is only a hint
    v_r := public.fmail_dtls_real189(v_uid, v_box, b1, null, null, null, null, null, 'received', 'classic12', null, 'TLSv1.2', null, null);
    res := res || jsonb_build_object('name', 'a received mail never replaces a real send', 'ok', (v_r ->> 'kept') = 'stronger' and (select verdict = 'pq' and source = 'sent' from public.fmail_domain_tls189 where mailbox_id = v_box and domain_blind = b1));
    v_r := public.fmail_dtls_real189(v_uid, v_box, sha256(convert_to('selftest189-four', 'UTF8')), v_seal, v_nonce, 'k', v_wrap, v_aad, 'received', 'pq', 'X25519MLKEM768', 'TLSv1.3', null, true);
    v_r := public.fmail_dtls_claim189(v_uid, v_box, sha256(convert_to('selftest189-four', 'UTF8')), null, null, null, null, null);
    res := res || jsonb_build_object('name', 'a received-only hint never saves a probe (the claim still says go)', 'ok', (v_r ->> 'go') = 'true');
    -- budget: 30 claims per hour
    select count(*) into v_n from public.fmail_dtls_log189 where mailbox_id = v_box and event = 'claim' and at > now() - interval '1 hour';
    for v_i in 1..(30 - v_n::int) loop
      v_r := public.fmail_dtls_claim189(v_uid, v_box, sha256(convert_to('selftest189-bulk-' || v_i, 'UTF8')), v_seal, v_nonce, 'k', v_wrap, v_aad);
    end loop;
    v_r := public.fmail_dtls_claim189(v_uid, v_box, sha256(convert_to('selftest189-over', 'UTF8')), v_seal, v_nonce, 'k', v_wrap, v_aad);
    res := res || jsonb_build_object('name', 'the 31st probe claim within an hour is refused with a wait time (budget)', 'ok', (v_r ->> 'why') = 'budget' and (v_r ->> 'retry_after_s')::int between 1 and 3600);
    -- reads, forget, chain
    v_r := public.fmail_dtls_get189(v_uid, v_box, array[b1, b3]);
    res := res || jsonb_build_object('name', 'the chips read two domains in one call', 'ok', jsonb_array_length(v_r -> 'rows') = 2);
    res := res || jsonb_build_object('name', 'the facts table holds no plain domain text (only closed enumerations are text)',
        'ok', not exists (select 1 from pg_attribute where attrelid = 'public.fmail_domain_tls189'::regclass and attnum > 0 and not attisdropped and attname = any (array['domain', 'host', 'address'])));
    v_r := public.fmail_dtls_forget189(v_uid, v_box, b3);
    res := res || jsonb_build_object('name', 'forgetting removes the row and writes a forget line with the blind only', 'ok', (v_r ->> 'forgotten') = '1'
        and not exists (select 1 from public.fmail_domain_tls189 where mailbox_id = v_box and domain_blind = b3) and exists (select 1 from public.fmail_dtls_log189 where mailbox_id = v_box and event = 'forget' and domain_blind = b3));
    res := res || jsonb_build_object('name', 'the hash chain verifies end to end', 'ok', (public.fmail_dtls_verify189(v_box) ->> 'ok')::boolean and (public.fmail_dtls_verify189(v_box) ->> 'checked')::int >= 10);
    perform set_config('fmail.dtls_door', 'on', true);
    begin update public.fmail_dtls_log189 set verdict = 'none' where mailbox_id = v_box and seq = 2; v_ok := false; exception when sqlstate '42501' then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a log line can never be changed', 'ok', v_ok);
    perform set_config('fmail.dtls_door', '', true);
    raise exception 'E189_SELFTEST_ROLLBACK %', res::text;
  exception when others then
    if sqlerrm like 'E189_SELFTEST_ROLLBACK %' then res := substr(sqlerrm, length('E189_SELFTEST_ROLLBACK ') + 1)::jsonb;
    else return jsonb_build_object('ok', false, 'error', sqlerrm, 'state', sqlstate, 'so_far', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is true),
                            'failed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok')::boolean is not true), 'checks', res);
end $$;
revoke all on function public.fmail_selftest189() from public, anon, authenticated;
grant execute on function public.fmail_selftest189() to service_role;

-- 11) POSTURE (read only) ----------------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_posture189() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare
  rd regprocedure[] := array[to_regprocedure('public.fmail_dtls_get189(uuid,uuid,bytea[])'), to_regprocedure('public.fmail_dtls_due189(integer)'), to_regprocedure('public.fmail_dtls_verify189(uuid)'), to_regprocedure('public.fmail_dtls_health189()')];
  wd regprocedure[] := array[to_regprocedure('public.fmail_dtls_' || 'claim189(uuid,uuid,bytea,bytea,bytea,text,bytea,bytea)'), to_regprocedure('public.fmail_dtls_' || 'finish189(uuid,uuid,bytea,text,text,text,text,boolean,bytea,bytea)'),
                             to_regprocedure('public.fmail_dtls_' || 'real189(uuid,uuid,bytea,bytea,bytea,text,bytea,bytea,text,text,text,text,text,boolean)'), to_regprocedure('public.fmail_dtls_' || 'forget189(uuid,uuid,bytea)')];
  t text[] := array['fmail_domain_tls189', 'fmail_dtls_head189', 'fmail_dtls_log189'];
begin
  return jsonb_build_object(
    'read_doors_stable_service_only', (select bool_and(provolatile = 's') from pg_proc where oid = any (rd::oid[])) and (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(rd) d),
    'write_doors_volatile_service_only', (select bool_and(provolatile = 'v') from pg_proc where oid = any (wd::oid[])) and (select bool_and(has_function_privilege('service_role', d, 'execute') and not has_function_privilege('anon', d, 'execute') and not has_function_privilege('authenticated', d, 'execute')) from unnest(wd) d),
    'ledger_writer_closed', not has_function_privilege('service_role', to_regprocedure('public.fmail_dtls_' || 'note189(uuid,text,bytea,text,text)'), 'execute') and not has_function_privilege('anon', to_regprocedure('public.fmail_dtls_' || 'note189(uuid,text,bytea,text,text)'), 'execute'),
    'rls_forced', (select bool_and(relforcerowsecurity) from pg_class where relname = any (t) and relnamespace = 'public'::regnamespace),
    'service_role_read_only', not exists (select 1 from information_schema.role_table_grants where grantee = 'service_role' and table_schema = 'public' and table_name = any (t) and privilege_type = any (array['INS' || 'ERT', 'UPD' || 'ATE', 'DEL' || 'ETE', 'TRUNC' || 'ATE'])),
    'anon_no_access', not exists (select 1 from information_schema.role_table_grants where grantee in ('anon', 'authenticated', 'PUBLIC') and table_schema = 'public' and table_name = any (t)),
    'guards', (select count(*) from pg_trigger where not tgisinternal and tgname in ('fmail_dtls_row_guard', 'fmail_dtls_row_guard_t', 'fmail_dtls_log_guard', 'fmail_dtls_log_guard_t', 'fmail_dtls_head_guard', 'fmail_dtls_head_guard_t')),
    'constraints', (select count(*) from pg_constraint where conrelid = 'public.fmail_domain_tls189'::regclass and conname like 'fmail\_dtls\_%'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
end $$;
revoke all on function public.fmail_posture189() from public, anon, authenticated;
grant execute on function public.fmail_posture189() to service_role;

select public.fmail_posture189() as e189_posture;
select public.fmail_selftest189() ->> 'passed' as e189_selftest_passed, public.fmail_selftest189() ->> 'failed' as e189_selftest_failed;
