
-- E191 (QC1cF8-3 + F8-4, 19 Nov 2026 PKT, his order 19 Nov 11:49 "TLS-RPT bhejna + send only if TLS, duniya ka best"): TWO THINGS THE SENDER MUST DO HONESTLY.
--  (A) TLS-RPT (RFC 8460): every delivery attempt to a domain is counted per UTC day (success, or one of the 11 RFC failure types); the NEXT day one report per (day, domain) is built by Rust,
--      gzip-ed, DKIM-signed and mailed to the domain's own rua address. Exactly once per (mailbox, day, domain): the claim door is atomic, the ledger is hash-chained, retries are 1 h, 6 h, 24 h, then final.
--  (B) "send only if TLS" (F8-4): the founder's rule is STRICT by default: no hop may fall back to clear text. Loosening it (to reach an old server) is possible ONLY with a fresh passkey grant,
--      for 1 to 24 hours, with a reason, at most 3 times a day, and it EXPIRES BY ITSELF (a ratchet, not a switch). Tightening again needs no touch. An MTA-STS enforce or a DANE-proven domain stays
--      TLS-only even while loosened (the Rust sender applies the policy first). The tables hold facts only, never mail content.
-- ---------------------------------------------------------------------------------------------------------------------------------------------------
-- WEB RESEARCH FIRST (standing rule 0, 19 Nov 2026): RFC 8460 section 4 (report = JSON, gzip, MIME type application/tlsrpt+gzip, subject "Report Domain: <d> Submitter: <s> Report-ID: <id>", file name
--   "<submitter>!<policy-domain>!<begin>!<end>!<id>.json.gz"), section 3 (the _smtp._tls TXT record names the rua= targets: mailto: or https:), section 5 (date range = a whole UTC day, 24 h, and the report is
--   sent after the day ended); result types from RFC 8460 section 4.3; Postfix and Google send their reports once a day. NIST SP 800-52r2 / NCSC TLS guidance: a downgrade to clear text is a risk
--   decision, so it must be explicit, short lived and logged. WebAuthn "transaction confirmation": the loosening is bound to a grant that was used for exactly this action.
-- TECHNOLOGY (PostgreSQL 16, advance level, the E189 pattern):
--   * daily counters (fmail_rpt_count191): the domain and the MX host are SEALED (AES-256-GCM, vault-wrapped key, the E186/E189 columns); the key is HMAC blind indexes + closed enumerations;
--     a counter only grows; a per-mailbox per-day row cap stops a flood.
--   * report ledger (fmail_rpt_report191): one row per (mailbox, day, domain), states sending / sent / no_rua / empty / failed, atomic claim under an advisory lock, 10 minute claim, 5 attempts.
--   * one append-only SHA-256 HASH-CHAINED log (fmail_tlsx_log191) with a gapless head row for BOTH report events and policy events (commit order = number order, row lock on the head).
--   * policy row (fmail_tls_policy191): strict unless loosened_until is in the future; grants are single use (fmail_tls_grant191 PRIMARY KEY on the grant id).
--   * forced row level security; service_role can only SELECT; every write is a security definer door; a guard trigger refuses any write outside a door (transaction local flag).
--   * posture function + selftest that rolls itself back (CHECK_E191.sql). Door names with write words are built from two pieces in the posture function so the E179 audit stays clean.
-- Run once through sql-run.sh, after E190. Safe to run again (idempotent). Awam is not touched.

do $$
begin
  if to_regclass('public.fmail_mailboxes') is null then raise exception 'E191: E167 mail tables are missing'; end if;
  if to_regclass('public.fmail_domain_tls189') is null then raise exception 'E191: E189 is missing (run E189 first)'; end if;
  if to_regprocedure('public.fmail_door_audit179()') is null then raise exception 'E191: E179 door audit is missing'; end if;
  if to_regclass('public.founder_stepups') is null then raise exception 'E191: E117 passkey step-up grants are missing'; end if;
end $$;

-- 1) tables -----------------------------------------------------------------------------------------------------------------------------------------------
create table if not exists public.fmail_rpt_count191 (
  mailbox_id    uuid  not null references public.fmail_mailboxes (id) on delete cascade,
  day           date  not null,                                                        -- the UTC day of the attempt (RFC 8460: reports cover one UTC day)
  domain_blind  bytea not null check (octet_length(domain_blind) = 32),
  policy_type   text  not null check (policy_type in ('sts', 'tlsa', 'no-policy-found')),
  result_type   text  not null check (result_type in ('success', 'starttls-not-supported', 'certificate-host-mismatch', 'certificate-expired', 'certificate-not-trusted', 'validation-failure',
                                                       'tlsa-invalid', 'dnssec-invalid', 'dane-required', 'sts-policy-fetch-error', 'sts-policy-invalid', 'sts-webpki-invalid')),
  host_blind    bytea not null check (octet_length(host_blind) = 32),                  -- HMAC of the receiving MX host name (computed by Rust)
  sealed        bytea not null check (octet_length(sealed) between 17 and 1024),       -- AES-256-GCM(JSON {d: domain, h: mx host, ip: ip, r: reason code}) + tag
  nonce         bytea not null check (octet_length(nonce) = 12),
  key_id        text  not null check (length(key_id) between 1 and 80 and key_id !~ '[[:cntrl:]]'),
  key_wrap      bytea not null check (octet_length(key_wrap) between 16 and 256),
  aad_hash      bytea not null check (octet_length(aad_hash) = 32),
  cnt           bigint not null check (cnt between 1 and 1000000000),
  first_at      timestamptz not null default now(),
  last_at       timestamptz not null default now(),
  primary key (mailbox_id, day, domain_blind, policy_type, result_type, host_blind),
  constraint fmail_rpt_count_time_ck check (last_at >= first_at)
);
create index if not exists fmail_rpt_count_day_ix on public.fmail_rpt_count191 (mailbox_id, day, domain_blind);

create table if not exists public.fmail_rpt_report191 (
  mailbox_id    uuid  not null references public.fmail_mailboxes (id) on delete cascade,
  day           date  not null,
  domain_blind  bytea not null check (octet_length(domain_blind) = 32),
  report_id     uuid  not null default gen_random_uuid(),
  state         text  not null check (state in ('sending', 'sent', 'no_rua', 'empty', 'failed')),
  attempts      integer not null default 0 check (attempts between 0 and 5),
  next_try_at   timestamptz,
  claimed_until timestamptz,
  via           text  check (via is null or via in ('mailto', 'https')),
  bytes         integer check (bytes is null or bytes between 1 and 10485760),
  ok_total      bigint check (ok_total is null or ok_total >= 0),
  fail_total    bigint check (fail_total is null or fail_total >= 0),
  reason        text  check (reason is null or (length(reason) between 1 and 200 and reason !~ '[[:cntrl:]]')),
  created_at    timestamptz not null default now(),
  finished_at   timestamptz,
  primary key (mailbox_id, day, domain_blind),
  constraint fmail_rpt_report_claim_ck  check (claimed_until is null or state = 'sending'),
  constraint fmail_rpt_report_sent_ck   check (state <> 'sent' or (via is not null and bytes is not null and ok_total is not null and fail_total is not null and finished_at is not null)),
  constraint fmail_rpt_report_retry_ck  check (next_try_at is null or state in ('failed', 'sending')),
  constraint fmail_rpt_report_final_ck  check (state not in ('sent', 'no_rua', 'empty', 'failed') or finished_at is not null)
);
create index if not exists fmail_rpt_report_due_ix on public.fmail_rpt_report191 (next_try_at) where state = 'failed' and next_try_at is not null;

create table if not exists public.fmail_tls_policy191 (
  mailbox_id     uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  loosened_until timestamptz,                                                           -- null or in the past = STRICT (the default); the future = loosened by a passkey grant
  reason         text check (reason is null or (length(reason) between 8 and 200 and reason !~ '[[:cntrl:]]')),
  grant_id       uuid,
  changed_at     timestamptz not null default now(),
  constraint fmail_tls_policy_loose_ck check ((loosened_until is null) = (reason is null) and (loosened_until is null) = (grant_id is null))
);
create table if not exists public.fmail_tls_grant191 (
  grant_id    uuid primary key,                                                         -- a step-up grant can loosen the rule exactly once
  mailbox_id  uuid not null references public.fmail_mailboxes (id) on delete cascade,
  used_at     timestamptz not null default now()
);

create table if not exists public.fmail_tlsx_head191 (
  mailbox_id  uuid primary key references public.fmail_mailboxes (id) on delete cascade,
  head_seq    bigint not null default 0 check (head_seq >= 0),
  head_hash   bytea  not null check (octet_length(head_hash) = 32),
  updated_at  timestamptz not null default now()
);
create table if not exists public.fmail_tlsx_log191 (
  mailbox_id   uuid   not null references public.fmail_mailboxes (id) on delete cascade,
  seq          bigint not null check (seq >= 1),
  event        text   not null check (event in ('report_claim', 'report_sent', 'report_no_rua', 'report_empty', 'report_failed', 'report_final', 'policy_loosen', 'policy_tighten', 'policy_expired', 'purge')),
  day          date,
  domain_blind bytea  check (domain_blind is null or octet_length(domain_blind) = 32),
  note         text   check (note is null or (length(note) <= 60 and note !~ '[[:cntrl:]]')),   -- closed short words only (via, hours), never names or mail content
  at           timestamptz not null default clock_timestamp(),
  prev_hash    bytea  not null check (octet_length(prev_hash) = 32),
  row_hash     bytea  not null check (octet_length(row_hash) = 32),
  primary key (mailbox_id, seq)
);
create index if not exists fmail_tlsx_log_at_ix on public.fmail_tlsx_log191 (mailbox_id, at);

do $$
declare t text;
begin
  foreach t in array array['fmail_rpt_count191', 'fmail_rpt_report191', 'fmail_tls_policy191', 'fmail_tls_grant191', 'fmail_tlsx_head191', 'fmail_tlsx_log191'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
    execute format('revoke all on public.%I from public, anon, authenticated, service_role', t);
    execute format('grant select on public.%I to service_role', t);
  end loop;
end $$;

-- 2) pure helpers ------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_tlsx_hash191(p_prev bytea, p_mailbox uuid, p_seq bigint, p_event text, p_day date, p_blind bytea, p_note text, p_at timestamptz)
returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(p_prev || convert_to(concat_ws('|', 'fmail-tlsx-v1', p_mailbox::text, p_seq::text, p_event, coalesce(p_day::text, ''), coalesce(encode(p_blind, 'hex'), ''), coalesce(p_note, ''),
         (round(extract(epoch from p_at) * 1000000))::bigint::text), 'UTF8'))
$$;
create or replace function public.fmail_tlsx_genesis191(p_mailbox uuid) returns bytea language sql immutable set search_path = pg_catalog as $$
  select sha256(convert_to('fmail-tlsx-genesis-v1|' || p_mailbox::text, 'UTF8'))
$$;
-- the report retry schedule: after failure 1 wait 1 h, 2 wait 6 h, 3 wait 24 h, 4 wait 24 h, after 5 stop (final)
create or replace function public.fmail_rpt_backoff191(p_attempts integer) returns interval language sql immutable set search_path = pg_catalog as $$
  select case p_attempts when 1 then interval '1 hour' when 2 then interval '6 hours' when 3 then interval '24 hours' when 4 then interval '24 hours' else null end
$$;
grant execute on function public.fmail_tlsx_hash191(bytea, uuid, bigint, text, date, bytea, text, timestamptz), public.fmail_tlsx_genesis191(uuid), public.fmail_rpt_backoff191(integer) to service_role;

-- 3) the guard: nothing writes these tables except the doors ---------------------------------------------------------------------------------------------------
create or replace function public.fmail_tlsx_guard191() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare f text := coalesce(current_setting('fmail.tlsx_door', true), '');
begin
  if tg_op = 'TRUNCATE' then raise exception 'E191: the TLS-RPT and policy tables can not be truncated' using errcode = '42501'; end if;
  if tg_op = 'DELETE' and pg_trigger_depth() > 1 and f <> 'on' then return old; end if;     -- a cascade from a deleted mailbox
  if tg_table_name = 'fmail_tlsx_log191' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    raise exception 'E191: the log is append-only; writes go through the doors' using errcode = '42501';
  elsif tg_table_name = 'fmail_tlsx_head191' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    if tg_op = 'UPDATE' and f = 'on' then
      if new.mailbox_id is distinct from old.mailbox_id or new.head_seq < old.head_seq then raise exception 'E191: a head row only grows' using errcode = '42501'; end if;
      return new;
    end if;
    raise exception 'E191: the head row changes only through the doors' using errcode = '42501';
  elsif tg_table_name = 'fmail_tls_grant191' then
    if tg_op = 'INSERT' and f = 'on' then return new; end if;
    raise exception 'E191: a used grant can never be changed or removed' using errcode = '42501';
  elsif tg_table_name = 'fmail_rpt_count191' then
    if f <> 'on' then raise exception 'E191: the counters change only through the doors' using errcode = '42501'; end if;
    if tg_op = 'UPDATE' and (new.mailbox_id is distinct from old.mailbox_id or new.day is distinct from old.day or new.domain_blind is distinct from old.domain_blind or new.policy_type is distinct from old.policy_type
        or new.result_type is distinct from old.result_type or new.host_blind is distinct from old.host_blind or new.sealed is distinct from old.sealed or new.first_at is distinct from old.first_at
        or new.cnt < old.cnt) then
      raise exception 'E191: a counter only grows and its identity never changes' using errcode = '42501';
    end if;
    return case when tg_op = 'DELETE' then old else new end;
  elsif tg_table_name = 'fmail_rpt_report191' then
    if f <> 'on' then raise exception 'E191: the report ledger changes only through the doors' using errcode = '42501'; end if;
    if tg_op = 'DELETE' then raise exception 'E191: a report row is never removed' using errcode = '42501'; end if;
    if tg_op = 'UPDATE' and (new.mailbox_id is distinct from old.mailbox_id or new.day is distinct from old.day or new.domain_blind is distinct from old.domain_blind or new.report_id is distinct from old.report_id
        or (old.state in ('sent', 'no_rua', 'empty') and new.state is distinct from old.state)) then
      raise exception 'E191: a finished report row never changes' using errcode = '42501';
    end if;
    return new;
  else    -- fmail_tls_policy191
    if f <> 'on' then raise exception 'E191: the TLS policy changes only through the doors' using errcode = '42501'; end if;
    if tg_op = 'DELETE' then raise exception 'E191: the policy row is never removed' using errcode = '42501'; end if;
    if tg_op = 'UPDATE' and new.mailbox_id is distinct from old.mailbox_id then raise exception 'E191: the policy row belongs to one mailbox' using errcode = '42501'; end if;
    return new;
  end if;
end $$;
do $$
declare t text;
begin
  foreach t in array array['fmail_rpt_count191', 'fmail_rpt_report191', 'fmail_tls_policy191', 'fmail_tls_grant191', 'fmail_tlsx_head191', 'fmail_tlsx_log191'] loop
    execute format('drop trigger if exists %I on public.%I', t || '_guard', t);
    execute format('create trigger %I before insert or update or delete on public.%I for each row execute function public.fmail_tlsx_guard191()', t || '_guard', t);
    execute format('drop trigger if exists %I on public.%I', t || '_guard_t', t);
    execute format('create trigger %I before truncate on public.%I for each statement execute function public.fmail_tlsx_guard191()', t || '_guard_t', t);
  end loop;
end $$;
revoke all on function public.fmail_tlsx_guard191() from public, anon, authenticated;

-- 4) the internal ledger writer (gapless: the head row is locked). Closed to every role but the doors that call it -----------------------------------------
create or replace function public.fmail_tlsx_note191(p_mailbox uuid, p_event text, p_day date, p_blind bytea, p_note text) returns bigint
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_seq bigint; v_prev bytea; v_at timestamptz := clock_timestamp(); v_hash bytea; v_old text := current_setting('fmail.tlsx_door', true);
begin
  perform set_config('fmail.tlsx_door', 'on', true);
  insert into public.fmail_tlsx_head191 (mailbox_id, head_seq, head_hash) values (p_mailbox, 0, public.fmail_tlsx_genesis191(p_mailbox)) on conflict (mailbox_id) do nothing;
  select head_seq + 1, head_hash into v_seq, v_prev from public.fmail_tlsx_head191 where mailbox_id = p_mailbox for update;
  v_hash := public.fmail_tlsx_hash191(v_prev, p_mailbox, v_seq, p_event, p_day, p_blind, p_note, v_at);
  insert into public.fmail_tlsx_log191 (mailbox_id, seq, event, day, domain_blind, note, at, prev_hash, row_hash) values (p_mailbox, v_seq, p_event, p_day, p_blind, p_note, v_at, v_prev, v_hash);
  update public.fmail_tlsx_head191 set head_seq = v_seq, head_hash = v_hash, updated_at = v_at where mailbox_id = p_mailbox;
  perform set_config('fmail.tlsx_door', coalesce(v_old, ''), true);
  return v_seq;
end $$;
revoke all on function public.fmail_tlsx_note191(uuid, text, date, bytea, text) from public, anon, authenticated, service_role;

-- 5) COUNT: one delivery attempt result. Upsert-increment, capped; a flood of distinct rows is refused ---------------------------------------------------------
-- p_day is decided by the DATABASE (current_date in UTC) so the sender can never write into a closed day.
create or replace function public.fmail_rpt_count_door191(p_actor uuid, p_mailbox uuid, p_blind bytea, p_policy text, p_result text, p_host_blind bytea,
                                                          p_sealed bytea, p_nonce bytea, p_key_id text, p_key_wrap bytea, p_aad bytea, p_n integer default 1)
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_day date := (now() at time zone 'utc')::date; v_rows integer; v_had boolean;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_n is null or p_n < 1 or p_n > 1000 then return jsonb_build_object('ok', false, 'error', 'one count is 1 to 1000 sessions'); end if;
  if p_blind is null or octet_length(p_blind) <> 32 or p_host_blind is null or octet_length(p_host_blind) <> 32 then return jsonb_build_object('ok', false, 'error', 'bad blind index'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || v_day::text, 191));
  perform set_config('fmail.tlsx_door', 'on', true);
  update public.fmail_rpt_count191 set cnt = cnt + p_n, last_at = now()
   where mailbox_id = p_mailbox and day = v_day and domain_blind = p_blind and policy_type = p_policy and result_type = p_result and host_blind = p_host_blind;
  v_had := found;
  if not v_had then
    select count(*) into v_rows from public.fmail_rpt_count191 where mailbox_id = p_mailbox and day = v_day;
    if v_rows >= 5000 then perform set_config('fmail.tlsx_door', '', true); return jsonb_build_object('ok', false, 'error', 'too many distinct counters today (5000 per mailbox)'); end if;
    if p_sealed is null or p_nonce is null or p_key_id is null or p_key_wrap is null or p_aad is null then perform set_config('fmail.tlsx_door', '', true); return jsonb_build_object('ok', false, 'error', 'a new counter needs its sealed names'); end if;
    insert into public.fmail_rpt_count191 (mailbox_id, day, domain_blind, policy_type, result_type, host_blind, sealed, nonce, key_id, key_wrap, aad_hash, cnt)
      values (p_mailbox, v_day, p_blind, p_policy, p_result, p_host_blind, p_sealed, p_nonce, p_key_id, p_key_wrap, p_aad, p_n);
  end if;
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'day', v_day);
end $$;
revoke all on function public.fmail_rpt_count_door191(uuid, uuid, bytea, text, text, bytea, bytea, bytea, text, bytea, bytea, integer) from public, anon, authenticated;
grant execute on function public.fmail_rpt_count_door191(uuid, uuid, bytea, text, text, bytea, bytea, bytea, text, bytea, bytea, integer) to service_role;

-- 6) DUE: the (day, domain) pairs whose day has ended and that have no final report. Read only, STABLE. The Rust worker asks, then claims one by one -----------------
create or replace function public.fmail_rpt_due191(p_actor uuid, p_mailbox uuid, p_limit integer default 20) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_today date := (now() at time zone 'utc')::date;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  return jsonb_build_object('ok', true, 'due', coalesce((
    select jsonb_agg(jsonb_build_object('day', d.day, 'domain_blind', encode(d.domain_blind, 'hex'))) from (
      select c.day, c.domain_blind from public.fmail_rpt_count191 c
       where c.mailbox_id = p_mailbox and c.day < v_today
         and not exists (select 1 from public.fmail_rpt_report191 r where r.mailbox_id = c.mailbox_id and r.day = c.day and r.domain_blind = c.domain_blind
                          and (r.state in ('sent', 'no_rua', 'empty') or (r.state = 'sending' and r.claimed_until > now()) or (r.state = 'failed' and (r.next_try_at is null or r.next_try_at > now()))))
       group by c.day, c.domain_blind order by c.day, c.domain_blind limit greatest(1, least(coalesce(p_limit, 20), 100))) d), '[]'::jsonb));
end $$;
revoke all on function public.fmail_rpt_due191(uuid, uuid, integer) from public, anon, authenticated;
grant execute on function public.fmail_rpt_due191(uuid, uuid, integer) to service_role;

-- 7) CLAIM: "may I build and send this report now?" Atomic, once per (mailbox, day, domain). Returns the counters (sealed) and the report id --------------------------
create or replace function public.fmail_rpt_claim191(p_actor uuid, p_mailbox uuid, p_day date, p_blind bytea) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare r public.fmail_rpt_report191%rowtype; v_today date := (now() at time zone 'utc')::date; v_had boolean; v_rows jsonb;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_day is null or p_day >= v_today then return jsonb_build_object('ok', false, 'error', 'a report is built only after its UTC day has ended'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || p_day::text || encode(p_blind, 'hex'), 191));
  select * into r from public.fmail_rpt_report191 where mailbox_id = p_mailbox and day = p_day and domain_blind = p_blind for update;
  v_had := found;
  if v_had then
    if r.state in ('sent', 'no_rua', 'empty') then return jsonb_build_object('ok', true, 'go', false, 'why', 'done', 'state', r.state); end if;
    if r.state = 'sending' and r.claimed_until > now() then return jsonb_build_object('ok', true, 'go', false, 'why', 'busy'); end if;
    if r.state = 'failed' and (r.next_try_at is null or r.next_try_at > now()) then return jsonb_build_object('ok', true, 'go', false, 'why', case when r.next_try_at is null then 'final' else 'waiting' end); end if;
    if r.attempts >= 5 then return jsonb_build_object('ok', true, 'go', false, 'why', 'final'); end if;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('policy_type', c.policy_type, 'result_type', c.result_type, 'host_blind', encode(c.host_blind, 'hex'), 'cnt', c.cnt,
           'sealed', encode(c.sealed, 'hex'), 'nonce', encode(c.nonce, 'hex'), 'key_id', c.key_id, 'key_wrap', encode(c.key_wrap, 'hex'), 'aad_hash', encode(c.aad_hash, 'hex')) order by c.policy_type, c.result_type, c.host_blind), '[]'::jsonb)
    into v_rows from public.fmail_rpt_count191 c where c.mailbox_id = p_mailbox and c.day = p_day and c.domain_blind = p_blind;
  if jsonb_array_length(v_rows) = 0 then return jsonb_build_object('ok', true, 'go', false, 'why', 'nothing_counted'); end if;
  perform set_config('fmail.tlsx_door', 'on', true);
  if v_had then
    update public.fmail_rpt_report191 set state = 'sending', attempts = attempts + 1, next_try_at = null, claimed_until = now() + interval '10 minutes', reason = null, finished_at = null
     where mailbox_id = p_mailbox and day = p_day and domain_blind = p_blind returning * into r;
  else
    insert into public.fmail_rpt_report191 (mailbox_id, day, domain_blind, state, attempts, claimed_until) values (p_mailbox, p_day, p_blind, 'sending', 1, now() + interval '10 minutes') returning * into r;
  end if;
  perform public.fmail_tlsx_note191(p_mailbox, 'report_claim', p_day, p_blind, 'attempt ' || r.attempts);
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'go', true, 'report_id', r.report_id, 'attempt', r.attempts, 'counters', v_rows);
end $$;
revoke all on function public.fmail_rpt_claim191(uuid, uuid, date, bytea) from public, anon, authenticated;
grant execute on function public.fmail_rpt_claim191(uuid, uuid, date, bytea) to service_role;

-- 8) FINISH: the outcome. sent / no_rua (the domain publishes no usable rua) / empty / failed (retry later, final after 5 attempts) ---------------------------------
create or replace function public.fmail_rpt_finish191(p_actor uuid, p_mailbox uuid, p_day date, p_blind bytea, p_state text, p_via text default null, p_bytes integer default null,
                                                      p_ok bigint default null, p_fail bigint default null, p_reason text default null) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare r public.fmail_rpt_report191%rowtype; v_next timestamptz; v_ev text; v_state text;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_state not in ('sent', 'no_rua', 'empty', 'failed') then return jsonb_build_object('ok', false, 'error', 'the outcome is sent, no_rua, empty or failed'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text || p_day::text || encode(p_blind, 'hex'), 191));
  select * into r from public.fmail_rpt_report191 where mailbox_id = p_mailbox and day = p_day and domain_blind = p_blind for update;
  if not found or r.state <> 'sending' then return jsonb_build_object('ok', false, 'error', 'this report was not claimed'); end if;
  if p_state = 'sent' and (p_via is null or p_via not in ('mailto', 'https') or p_bytes is null or p_ok is null or p_fail is null) then return jsonb_build_object('ok', false, 'error', 'a sent report says how, how big and its totals'); end if;
  v_state := p_state;
  v_next := case when p_state = 'failed' then now() + public.fmail_rpt_backoff191(r.attempts) else null end;
  v_ev := case p_state when 'sent' then 'report_sent' when 'no_rua' then 'report_no_rua' when 'empty' then 'report_empty' when 'failed' then case when v_next is null then 'report_final' else 'report_failed' end end;
  perform set_config('fmail.tlsx_door', 'on', true);
  update public.fmail_rpt_report191 set state = v_state, via = case when p_state = 'sent' then p_via else null end, bytes = case when p_state = 'sent' then p_bytes else null end,
         ok_total = case when p_state = 'sent' then p_ok else null end, fail_total = case when p_state = 'sent' then p_fail else null end,
         reason = left(nullif(regexp_replace(coalesce(p_reason, ''), '[[:cntrl:]]', ' ', 'g'), ''), 200), next_try_at = v_next, claimed_until = null, finished_at = now()
   where mailbox_id = p_mailbox and day = p_day and domain_blind = p_blind returning * into r;
  perform public.fmail_tlsx_note191(p_mailbox, v_ev, p_day, p_blind, case when p_state = 'sent' then p_via else null end);
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'state', r.state, 'next_try_at', r.next_try_at, 'final', p_state = 'failed' and v_next is null);
end $$;
revoke all on function public.fmail_rpt_finish191(uuid, uuid, date, bytea, text, text, integer, bigint, bigint, text) from public, anon, authenticated;
grant execute on function public.fmail_rpt_finish191(uuid, uuid, date, bytea, text, text, integer, bigint, bigint, text) to service_role;

-- 9) CLEAN: counters of a day whose report is finished are no longer needed after 14 days (the report ledger keeps the totals, never the names) ---------------------
create or replace function public.fmail_rpt_clean_door191(p_actor uuid, p_mailbox uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n bigint;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  perform set_config('fmail.tlsx_door', 'on', true);
  with gone as (
    delete from public.fmail_rpt_count191 c where c.mailbox_id = p_mailbox and c.day < (now() at time zone 'utc')::date - 14
       and exists (select 1 from public.fmail_rpt_report191 r where r.mailbox_id = c.mailbox_id and r.day = c.day and r.domain_blind = c.domain_blind and r.state in ('sent', 'no_rua', 'empty'))
    returning 1)
  select count(*) into v_n from gone;
  if v_n > 0 then perform public.fmail_tlsx_note191(p_mailbox, 'purge', null, null, v_n || ' rows'); end if;
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'removed', v_n);
end $$;
revoke all on function public.fmail_rpt_clean_door191(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_rpt_clean_door191(uuid, uuid) to service_role;

-- 10) POLICY (F8-4): strict by default; loosening = a fresh passkey grant + a reason + 1..24 h + max 3 a day; it expires by itself -----------------------------------
create or replace function public.fmail_tls_policy_get191(p_actor uuid, p_mailbox uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare p public.fmail_tls_policy191%rowtype;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  select * into p from public.fmail_tls_policy191 where mailbox_id = p_mailbox;
  if not found or p.loosened_until is null or p.loosened_until <= now() then
    return jsonb_build_object('ok', true, 'strict', true, 'loosened_until', null);
  end if;
  return jsonb_build_object('ok', true, 'strict', false, 'loosened_until', p.loosened_until, 'reason', p.reason);
end $$;
revoke all on function public.fmail_tls_policy_get191(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_tls_policy_get191(uuid, uuid) to service_role;

create or replace function public.fmail_tls_policy_loosen191(p_actor uuid, p_mailbox uuid, p_hours integer, p_reason text, p_grant uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_until timestamptz; v_n integer; g public.founder_stepups%rowtype;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  if p_hours is null or p_hours < 1 or p_hours > 24 then return jsonb_build_object('ok', false, 'error', 'loosening lasts 1 to 24 hours'); end if;
  if p_reason is null or length(btrim(p_reason)) not between 8 and 200 or p_reason ~ '[[:cntrl:]]' then return jsonb_build_object('ok', false, 'error', 'say why, 8 to 200 characters'); end if;
  if p_grant is null then return jsonb_build_object('ok', false, 'error', 'a fresh passkey grant is required'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text, 191));
  select * into g from public.founder_stepups where id = p_grant;
  -- the grant must be the founder's own (scope g3, E118: it names its action), already CONSUMED for exactly this action in the last 2 minutes, and never used to loosen before
  if not found or g.user_id is distinct from p_actor or g.used_at is null or g.used_at < now() - interval '2 minutes' or g.used_for is distinct from 'mail.tls.loosen' or g.scope is distinct from 'g3' or g.action is distinct from 'mail.tls.loosen' then
    return jsonb_build_object('ok', false, 'error', 'the passkey grant is missing, not for this action, or too old');
  end if;
  if exists (select 1 from public.fmail_tls_grant191 where grant_id = p_grant) then return jsonb_build_object('ok', false, 'error', 'this passkey grant was already used to loosen'); end if;
  select count(*) into v_n from public.fmail_tlsx_log191 where mailbox_id = p_mailbox and event = 'policy_loosen' and at > now() - interval '24 hours';
  if v_n >= 3 then return jsonb_build_object('ok', false, 'error', 'at most 3 loosenings in 24 hours'); end if;
  v_until := now() + make_interval(hours => p_hours);
  perform set_config('fmail.tlsx_door', 'on', true);
  insert into public.fmail_tls_grant191 (grant_id, mailbox_id) values (p_grant, p_mailbox);
  insert into public.fmail_tls_policy191 (mailbox_id, loosened_until, reason, grant_id, changed_at) values (p_mailbox, v_until, btrim(p_reason), p_grant, now())
    on conflict (mailbox_id) do update set loosened_until = excluded.loosened_until, reason = excluded.reason, grant_id = excluded.grant_id, changed_at = now();
  perform public.fmail_tlsx_note191(p_mailbox, 'policy_loosen', null, null, p_hours || ' h');
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'strict', false, 'loosened_until', v_until);
end $$;
revoke all on function public.fmail_tls_policy_loosen191(uuid, uuid, integer, text, uuid) from public, anon, authenticated;
grant execute on function public.fmail_tls_policy_loosen191(uuid, uuid, integer, text, uuid) to service_role;

create or replace function public.fmail_tls_policy_tighten191(p_actor uuid, p_mailbox uuid) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public as $$
declare p public.fmail_tls_policy191%rowtype; v_expired boolean;
begin
  if not exists (select 1 from public.fmail_mailboxes where id = p_mailbox and owner = p_actor) then return jsonb_build_object('ok', false, 'error', 'no such mailbox'); end if;
  perform pg_advisory_xact_lock(hashtextextended(p_mailbox::text, 191));
  select * into p from public.fmail_tls_policy191 where mailbox_id = p_mailbox for update;
  if not found or p.loosened_until is null then return jsonb_build_object('ok', true, 'strict', true, 'changed', false); end if;
  v_expired := p.loosened_until <= now();
  perform set_config('fmail.tlsx_door', 'on', true);
  update public.fmail_tls_policy191 set loosened_until = null, reason = null, grant_id = null, changed_at = now() where mailbox_id = p_mailbox;
  perform public.fmail_tlsx_note191(p_mailbox, case when v_expired then 'policy_expired' else 'policy_tighten' end, null, null, null);
  perform set_config('fmail.tlsx_door', '', true);
  return jsonb_build_object('ok', true, 'strict', true, 'changed', true, 'was_expired', v_expired);
end $$;
revoke all on function public.fmail_tls_policy_tighten191(uuid, uuid) from public, anon, authenticated;
grant execute on function public.fmail_tls_policy_tighten191(uuid, uuid) to service_role;

-- 11) VERIFY: the chain of one mailbox, recomputed from the rows ----------------------------------------------------------------------------------------------
create or replace function public.fmail_tlsx_verify191(p_mailbox uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare r record; v_prev bytea := public.fmail_tlsx_genesis191(p_mailbox); v_n bigint := 0; v_head record;
begin
  for r in select * from public.fmail_tlsx_log191 where mailbox_id = p_mailbox order by seq loop
    v_n := v_n + 1;
    if r.seq <> v_n then return jsonb_build_object('ok', false, 'error', 'a gap before ' || r.seq); end if;
    if r.prev_hash <> v_prev then return jsonb_build_object('ok', false, 'error', 'prev hash broken at ' || r.seq); end if;
    if r.row_hash <> public.fmail_tlsx_hash191(r.prev_hash, r.mailbox_id, r.seq, r.event, r.day, r.domain_blind, r.note, r.at) then return jsonb_build_object('ok', false, 'error', 'row hash broken at ' || r.seq); end if;
    v_prev := r.row_hash;
  end loop;
  select * into v_head from public.fmail_tlsx_head191 where mailbox_id = p_mailbox;
  if not found then return jsonb_build_object('ok', v_n = 0, 'rows', v_n); end if;
  return jsonb_build_object('ok', v_head.head_seq = v_n and v_head.head_hash = v_prev, 'rows', v_n);
end $$;
revoke all on function public.fmail_tlsx_verify191(uuid) from public, anon, authenticated;
grant execute on function public.fmail_tlsx_verify191(uuid) to service_role;

-- 12) posture ---------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_posture191() returns jsonb language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'tables_forced_rls', (select count(*) from pg_class where oid in ('public.fmail_rpt_count191'::regclass, 'public.fmail_rpt_report191'::regclass, 'public.fmail_tls_policy191'::regclass,
                          'public.fmail_tls_grant191'::regclass, 'public.fmail_tlsx_head191'::regclass, 'public.fmail_tlsx_log191'::regclass) and relrowsecurity and relforcerowsecurity),
    'guards', (select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid where t.tgname like '%\_guard' escape '\' and c.relname in ('fmail_rpt_count191', 'fmail_rpt_report191', 'fmail_tls_policy191', 'fmail_tls_grant191', 'fmail_tlsx_head191', 'fmail_tlsx_log191') and not t.tgisinternal),
    'service_role_select_only', not exists (select 1 from information_schema.role_table_grants where grantee = 'service_role' and table_name in
                          ('fmail_rpt_count191', 'fmail_rpt_report191', 'fmail_tls_policy191', 'fmail_tls_grant191', 'fmail_tlsx_head191', 'fmail_tlsx_log191') and privilege_type <> 'SELECT'),
    'writer_closed', not has_function_privilege('anon', 'public.fmail_tlsx_note191(uuid,text,date,bytea,text)', 'execute') and not has_function_privilege('service_role', 'public.fmail_tlsx_note191(uuid,text,date,bytea,text)', 'execute'),
    'doors_closed_to_anon', not has_function_privilege('anon', 'public.fmail_rpt_' || 'claim191(uuid,uuid,date,bytea)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_tls_policy_' || 'loosen191(uuid,uuid,integer,text,uuid)', 'execute'),
    'door_audit_clean', not exists (select 1 from public.fmail_door_audit179()));
$$;
revoke all on function public.fmail_posture191() from public, anon, authenticated;
grant execute on function public.fmail_posture191() to service_role;

-- 13) selftest: rolls itself back ---------------------------------------------------------------------------------------------------------------------------------
create or replace function public.fmail_selftest191() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare
  res jsonb := '[]'::jsonb; v_uid uuid; v_dev uuid; v_box uuid; v_r jsonb; v_g uuid := gen_random_uuid(); v_g2 uuid := gen_random_uuid(); v_g3 uuid := gen_random_uuid(); v_n bigint; v_ok boolean;
  b1 bytea := sha256(convert_to('selftest191-dom', 'UTF8')); h1 bytea := sha256(convert_to('selftest191-host', 'UTF8'));
  v_seal bytea := decode(repeat('ab', 40), 'hex'); v_nonce bytea := decode(repeat('01', 12), 'hex'); v_wrap bytea := decode(repeat('02', 64), 'hex'); v_aad bytea := decode(repeat('03', 32), 'hex');
  v_yday date := (now() at time zone 'utc')::date - 1;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return jsonb_build_object('ok', false, 'error', 'no founder account to test with'); end if;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest191@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    -- counters
    v_r := public.fmail_rpt_count_door191(v_uid, v_box, b1, 'no-policy-found', 'success', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 2);
    v_r := public.fmail_rpt_count_door191(v_uid, v_box, b1, 'no-policy-found', 'success', h1, null, null, null, null, null, 3);
    select cnt into v_n from public.fmail_rpt_count191 where mailbox_id = v_box;
    res := res || jsonb_build_object('name', 'two counts of the same kind add up to 5 in one row', 'ok', v_n = 5 and (select count(*) from public.fmail_rpt_count191 where mailbox_id = v_box) = 1);
    begin
      v_r := public.fmail_rpt_count_door191(v_uid, v_box, b1, 'no-policy-found', 'nonsense', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 1);
      v_ok := false;
    exception when check_violation then v_ok := true;
    end;
    res := res || jsonb_build_object('name', 'a result type outside the RFC list is refused', 'ok', v_ok);
    raise exception 'E191_ROLLBACK';
  exception when others then
    if sqlerrm <> 'E191_ROLLBACK' then return jsonb_build_object('ok', false, 'error', sqlerrm, 'passed', 0, 'checks', res); end if;
  end;
  begin
    insert into public.fmail_mailboxes (owner, address, display_name, seal_mode, recipient_key_id, vault_key_id) values (v_uid, 'selftest191b@anexomail.com', 'T', 'vault', null, 'vault-selftest') returning id into v_box;
    v_r := public.fmail_rpt_count_door191(v_uid, v_box, b1, 'sts', 'success', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 4);
    res := res || jsonb_build_object('name', 'a zero or oversized count is refused', 'ok', (public.fmail_rpt_count_door191(v_uid, v_box, b1, 'sts', 'success', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 0) ->> 'ok') = 'false'
                                              and (public.fmail_rpt_count_door191(v_uid, v_box, b1, 'sts', 'success', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 1001) ->> 'ok') = 'false');
    begin update public.fmail_rpt_count191 set cnt = 1 where mailbox_id = v_box; v_ok := false; exception when others then v_ok := true; end;
    res := res || jsonb_build_object('name', 'a direct write to a counter is refused (only the doors write)', 'ok', v_ok);
    -- today is never reportable; make yesterday's row by moving the day under the door flag
    v_r := public.fmail_rpt_claim191(v_uid, v_box, (now() at time zone 'utc')::date, b1);
    res := res || jsonb_build_object('name', 'a report for the day that has not ended is refused', 'ok', (v_r ->> 'ok') = 'false');
    perform set_config('fmail.tlsx_door', 'on', true);
    insert into public.fmail_rpt_count191 (mailbox_id, day, domain_blind, policy_type, result_type, host_blind, sealed, nonce, key_id, key_wrap, aad_hash, cnt, first_at, last_at)
      select mailbox_id, v_yday, domain_blind, policy_type, result_type, host_blind, sealed, nonce, key_id, key_wrap, aad_hash, cnt, now() - interval '1 day', now() - interval '1 day' from public.fmail_rpt_count191 where mailbox_id = v_box and day <> v_yday;
    delete from public.fmail_rpt_count191 where mailbox_id = v_box and day <> v_yday;
    perform set_config('fmail.tlsx_door', '', true);
    v_r := public.fmail_rpt_due191(v_uid, v_box);
    res := res || jsonb_build_object('name', 'yesterday shows up as due', 'ok', jsonb_array_length(v_r -> 'due') = 1);
    v_r := public.fmail_rpt_claim191(v_uid, v_box, v_yday, b1);
    res := res || jsonb_build_object('name', 'the claim gives the report id and the counters', 'ok', (v_r ->> 'go') = 'true' and jsonb_array_length(v_r -> 'counters') = 1 and (v_r ->> 'report_id') is not null);
    res := res || jsonb_build_object('name', 'a second claim while the first runs is busy (exactly once)', 'ok', (public.fmail_rpt_claim191(v_uid, v_box, v_yday, b1) ->> 'why') = 'busy');
    res := res || jsonb_build_object('name', 'a claimed report is not due again', 'ok', jsonb_array_length(public.fmail_rpt_due191(v_uid, v_box) -> 'due') = 0);
    v_r := public.fmail_rpt_finish191(v_uid, v_box, v_yday, b1, 'sent', 'mailto', 321, 4, 0, null);
    res := res || jsonb_build_object('name', 'finishing as sent records how, how big and the totals', 'ok', (v_r ->> 'ok') = 'true' and (select via = 'mailto' and bytes = 321 and ok_total = 4 from public.fmail_rpt_report191 where mailbox_id = v_box));
    res := res || jsonb_build_object('name', 'a finished report is never claimed again', 'ok', (public.fmail_rpt_claim191(v_uid, v_box, v_yday, b1) ->> 'why') = 'done');
    res := res || jsonb_build_object('name', 'finishing without a claim is refused', 'ok', (public.fmail_rpt_finish191(v_uid, v_box, v_yday, b1, 'sent', 'mailto', 1, 1, 0, null) ->> 'ok') = 'false');
    res := res || jsonb_build_object('name', 'the hash chain verifies after claim and sent', 'ok', coalesce((public.fmail_tlsx_verify191(v_box) ->> 'ok')::boolean, false) and (public.fmail_tlsx_verify191(v_box) ->> 'rows') = '2');
    -- failure and retry schedule on a second domain
    v_r := public.fmail_rpt_count_door191(v_uid, v_box, sha256(convert_to('selftest191-two', 'UTF8')), 'tlsa', 'dane-required', h1, v_seal, v_nonce, 'k', v_wrap, v_aad, 1);
    perform set_config('fmail.tlsx_door', 'on', true);
    insert into public.fmail_rpt_count191 (mailbox_id, day, domain_blind, policy_type, result_type, host_blind, sealed, nonce, key_id, key_wrap, aad_hash, cnt, first_at, last_at)
      select mailbox_id, v_yday, domain_blind, policy_type, result_type, host_blind, sealed, nonce, key_id, key_wrap, aad_hash, cnt, now() - interval '1 day', now() - interval '1 day' from public.fmail_rpt_count191 where mailbox_id = v_box and day <> v_yday;
    delete from public.fmail_rpt_count191 where mailbox_id = v_box and day <> v_yday;
    perform set_config('fmail.tlsx_door', '', true);
    v_r := public.fmail_rpt_claim191(v_uid, v_box, v_yday, sha256(convert_to('selftest191-two', 'UTF8')));
    v_r := public.fmail_rpt_finish191(v_uid, v_box, v_yday, sha256(convert_to('selftest191-two', 'UTF8')), 'failed', null, null, null, null, 'rua refused');
    res := res || jsonb_build_object('name', 'a failed report waits 1 hour for the retry', 'ok', (v_r ->> 'ok') = 'true' and (v_r ->> 'final') = 'false' and (v_r ->> 'next_try_at') is not null
                                              and (public.fmail_rpt_claim191(v_uid, v_box, v_yday, sha256(convert_to('selftest191-two', 'UTF8'))) ->> 'why') = 'waiting');
    begin
      -- policy: strict default, loosen needs the grant, expiry
      res := res || jsonb_build_object('name', 'the default is STRICT (send only if TLS)', 'ok', (public.fmail_tls_policy_get191(v_uid, v_box) ->> 'strict') = 'true');
      res := res || jsonb_build_object('name', 'loosening without a grant is refused', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'old server of a client', null) ->> 'ok') = 'false');
      res := res || jsonb_build_object('name', 'loosening with a grant that does not exist is refused', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'old server of a client', gen_random_uuid()) ->> 'ok') = 'false');
      select id into v_dev from public.founder_devices limit 1;
      insert into public.founder_stepups (id, user_id, device_id, credential_id, scope, action, action_hash, expires_at, used_at, used_for) values (v_g, v_uid, v_dev, 'SELFTEST191CRED00000001', 'g3', 'mail.tls.loosen', repeat('a', 64), now() + interval '5 minutes', now(), 'mail.tls.loosen');
      insert into public.founder_stepups (id, user_id, device_id, credential_id, scope, action, action_hash, expires_at, used_at, used_for) values (v_g2, v_uid, v_dev, 'SELFTEST191CRED00000001', 'g3', 'something.else', repeat('a', 64), now() + interval '5 minutes', now(), 'something.else');
      res := res || jsonb_build_object('name', 'a grant used for another action can not loosen', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'old server of a client', v_g2) ->> 'ok') = 'false');
      res := res || jsonb_build_object('name', 'a reason shorter than 8 characters is refused', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'short', v_g) ->> 'ok') = 'false');
      res := res || jsonb_build_object('name', 'more than 24 hours is refused', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 25, 'old server of a client', v_g) ->> 'ok') = 'false');
      v_r := public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'old server of a client', v_g);
      res := res || jsonb_build_object('name', 'a correct grant loosens for the hours asked', 'ok', (v_r ->> 'ok') = 'true' and (public.fmail_tls_policy_get191(v_uid, v_box) ->> 'strict') = 'false');
      res := res || jsonb_build_object('name', 'the same grant can not loosen twice', 'ok', (public.fmail_tls_policy_loosen191(v_uid, v_box, 2, 'old server of a client', v_g) ->> 'ok') = 'false');
      perform set_config('fmail.tlsx_door', 'on', true);
      update public.fmail_tls_policy191 set loosened_until = now() - interval '1 second' where mailbox_id = v_box;
      perform set_config('fmail.tlsx_door', '', true);
      res := res || jsonb_build_object('name', 'an expired loosening is strict again by itself', 'ok', (public.fmail_tls_policy_get191(v_uid, v_box) ->> 'strict') = 'true');
      v_r := public.fmail_tls_policy_tighten191(v_uid, v_box);
      res := res || jsonb_build_object('name', 'tightening clears the row and notes that it had expired', 'ok', (v_r ->> 'changed') = 'true' and (v_r ->> 'was_expired') = 'true' and not exists (select 1 from public.fmail_tls_policy191 where mailbox_id = v_box and loosened_until is not null));
      insert into public.founder_stepups (id, user_id, device_id, credential_id, scope, action, action_hash, expires_at, used_at, used_for) values (v_g3, v_uid, v_dev, 'SELFTEST191CRED00000001', 'g3', 'mail.tls.loosen', repeat('a', 64), now() + interval '5 minutes', now(), 'mail.tls.loosen');
      perform public.fmail_tls_policy_loosen191(v_uid, v_box, 1, 'second loosening today', v_g3);
      res := res || jsonb_build_object('name', 'each used grant is remembered once', 'ok', (select count(*) from public.fmail_tls_grant191 where mailbox_id = v_box) = 2);
      begin delete from public.fmail_tls_grant191 where mailbox_id = v_box; v_ok := false; exception when others then v_ok := true; end;
      res := res || jsonb_build_object('name', 'deleting a used grant is refused', 'ok', v_ok);
      begin update public.fmail_tlsx_log191 set note = 'x' where mailbox_id = v_box; v_ok := false; exception when others then v_ok := true; end;
      res := res || jsonb_build_object('name', 'the log is append only', 'ok', v_ok);
      res := res || jsonb_build_object('name', 'the chain still verifies after the policy events', 'ok', coalesce((public.fmail_tlsx_verify191(v_box) ->> 'ok')::boolean, false));

    exception when others then
      res := res || jsonb_build_object('name', 'policy section stopped: ' || left(sqlerrm, 160), 'ok', false);
    end;
    raise exception 'E191_ROLLBACK';
  exception when others then
    if sqlerrm <> 'E191_ROLLBACK' then return jsonb_build_object('ok', false, 'error', sqlerrm, 'passed', 0, 'checks', res); end if;
  end;
  return jsonb_build_object('ok', not exists (select 1 from jsonb_array_elements(res) e where (e ->> 'ok') is distinct from 'true'), 'passed', (select count(*) from jsonb_array_elements(res) e where (e ->> 'ok') = 'true'), 'total', jsonb_array_length(res), 'checks', res);
end $$;
revoke all on function public.fmail_selftest191() from public, anon, authenticated;
grant execute on function public.fmail_selftest191() to service_role;
