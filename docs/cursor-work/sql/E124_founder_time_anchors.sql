-- E124 — G5c: ACCOUNT-FREE OUTSIDE TIME ANCHORS for the signed checkpoints (founder order 2 Nov 07:05: "advance codes, sql 800 lines, magic founder account pe nazar aye").
-- Problem G5b left open: the audit-log key lives on the SAME server, so a signed checkpoint proves "the audit-log key said so", not "this existed by then".
--   An outside clock fixes that. Two independent, free, account-free routes (nobody signs up for anything; founder rule G5-D):
--     RFC 3161  : a public Time-Stamp Authority signs (digest, genTime). Fast (seconds). A forged past would need that TSA's key.
--     OpenTimestamps : public calendars aggregate the digest into a Bitcoin transaction. Slow (hours), but nobody can backdate a Bitcoin block.
--   The anchored object is the EXACT published signed note: digest = sha256(note text). SQL computes it itself (Rust cannot lie about it).
-- Honest labels (the UI says "time-anchored", NEVER "witnessed"): an RFC 3161 token proves "the TSA's key signed this digest at genTime" (its CMS signature is checked by Rust and by the browser kernel;
--   the TSA's own certificate chain to a public root is NOT validated, instead the signer certificate is pinned per provider, trust-on-first-use, and a change is flagged).
--   An OpenTimestamps "pending" proof is NOT yet a time claim; only a Bitcoin attestation is.
-- Levels per checkpoint: none < ots-pending < tsa < bitcoin < strong (tsa AND bitcoin). "Time-anchored" = tsa, bitcoin or strong.
-- What this file adds (additive, idempotent; nothing is deleted or changed; needs E107, E120, E122, E123):
--   1) founder_anchor_providers  : public calendars + TSAs, enable/disable through an AUDITED door; defaults inserted (no accounts, no keys).
--   2) founder_anchor_policy     : singleton knobs (how long a seal may stay un-anchored, backoff, attempts, clock skew).
--   3) founder_anchor_jobs       : the work queue (mutable, doors only): one job per (signed checkpoint, provider), lease + exponential backoff + dead letter.
--   4) founder_anchor_evidence   : APPEND-ONLY, hash-chained proof versions. Triggers: digest must be sha256 of the stored signed note; the token must contain the digest; time plausibility
--                                  (genTime not before the note, not in the future, never going backwards per provider); Bitcoin block time sanity; signer pin per provider.
--   5) founder_anchor_events     : APPEND-ONLY, hash-chained log of everything that happened (submitted, token ok, upgraded, failed, verified).
--   6) doors (service_role only): enqueue, next (lease), record_tsa, record_ots, fail, provider_set, pulse, get, verify, level; 7) selftest (rolls back) + CHECK_E124.

do $$ begin
  if to_regclass('public.founder_audit_signed_checkpoints') is null then raise exception 'E124: run E123 first (signed checkpoints missing)'; end if;
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null then raise exception 'E124: run E102 first'; end if;
end $$;

-- 1) providers -------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  create table if not exists public.founder_anchor_providers (
    id            integer generated always as identity primary key,
    kind          text    not null check (kind in ('rfc3161', 'ots')),
    name          text    not null unique check (name ~ '^[a-z0-9][a-z0-9._-]{2,60}$'),
    url           text    not null check (url ~ '^https?://[A-Za-z0-9.-]{3,120}(:[0-9]{2,5})?(/[A-Za-z0-9._~/-]{0,100})?$'),
    enabled       boolean not null default true,
    timeout_ms    integer not null default 20000 check (timeout_ms between 2000 and 60000),
    min_gap_secs  integer not null default 60 check (min_gap_secs between 0 and 86400),         -- be polite to a free public service
    note          text    not null default '' check (length(note) <= 300),
    created_ms    bigint  not null default (extract(epoch from clock_timestamp()) * 1000)::bigint,
    signer_pin    text    check (signer_pin is null or signer_pin ~ '^[0-9a-f]{64}$')            -- sha256 of the TSA signer certificate's public key (TOFU, rfc3161 only)
  );
  alter table public.founder_anchor_providers enable row level security;
  revoke all on public.founder_anchor_providers from public, anon, authenticated;
  grant select, insert, update on public.founder_anchor_providers to service_role;
  revoke delete, truncate, references, trigger on public.founder_anchor_providers from service_role;
end $$;

-- public, free, account-free services. Editing this list later = the audited provider_set door (enable/disable) or a new SQL edit; nothing here needs a key.
insert into public.founder_anchor_providers (kind, name, url, note) values
  ('rfc3161', 'freetsa',          'https://freetsa.org/tsr',                       'FreeTSA.org, free public TSA'),
  ('rfc3161', 'digicert-tsa',     'http://timestamp.digicert.com',                 'DigiCert public timestamp service'),
  ('rfc3161', 'sectigo-tsa',      'http://timestamp.sectigo.com',                  'Sectigo public timestamp service'),
  ('ots',     'ots-alice',        'https://alice.btc.calendar.opentimestamps.org', 'OpenTimestamps calendar (Peter Todd)'),
  ('ots',     'ots-bob',          'https://bob.btc.calendar.opentimestamps.org',   'OpenTimestamps calendar (Peter Todd)'),
  ('ots',     'ots-finney',       'https://finney.calendar.eternitywall.com',      'OpenTimestamps calendar (Eternity Wall)')
on conflict (name) do nothing;

-- 2) policy ----------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  create table if not exists public.founder_anchor_policy (
    id                     boolean primary key default true check (id),
    backlog_cap            integer not null default 50   check (backlog_cap between 1 and 500),      -- only the newest N signed checkpoints are queued (first run must not flood public services)
    warn_secs              integer not null default 900   check (warn_secs between 60 and 604800),   -- newest signed checkpoint without a time claim for this long = warn
    fail_secs              integer not null default 14400 check (fail_secs between 120 and 2592000), -- ... fail
    ots_pending_warn_secs  integer not null default 172800 check (ots_pending_warn_secs between 3600 and 2592000),  -- Bitcoin normally takes hours; two days pending = warn
    ots_poll_secs          integer not null default 1800  check (ots_poll_secs between 300 and 86400),             -- how often an OTS proof is asked to upgrade
    max_attempts           integer not null default 8     check (max_attempts between 1 and 50),
    backoff_base_secs      integer not null default 30    check (backoff_base_secs between 5 and 3600),
    lease_secs             integer not null default 120   check (lease_secs between 30 and 900),
    skew_secs              integer not null default 120   check (skew_secs between 5 and 3600),       -- clock difference tolerated between this server and a TSA
    btc_time_slack_secs    integer not null default 7200  check (btc_time_slack_secs between 600 and 86400),  -- Bitcoin block timestamps may be ~2 h off
    constraint founder_anchor_policy_order check (fail_secs > warn_secs)
  );
  insert into public.founder_anchor_policy (id) values (true) on conflict do nothing;
  alter table public.founder_anchor_policy enable row level security;
  revoke all on public.founder_anchor_policy from public, anon, authenticated;
  grant select on public.founder_anchor_policy to service_role;
end $$;

-- 3) jobs (the queue) ------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  create table if not exists public.founder_anchor_jobs (
    id            bigint generated always as identity primary key,
    cp_id         bigint  not null check (cp_id >= 1),
    provider_id   integer not null references public.founder_anchor_providers (id),
    state         text    not null default 'queued' check (state in ('queued', 'pending', 'done', 'dead')),   -- pending = OTS proof exists, waiting for Bitcoin
    attempts      integer not null default 0 check (attempts >= 0),
    next_try_ms   bigint  not null default 0,
    last_error    text    check (last_error is null or length(last_error) <= 400),
    created_ms    bigint  not null default (extract(epoch from clock_timestamp()) * 1000)::bigint,
    updated_ms    bigint  not null default (extract(epoch from clock_timestamp()) * 1000)::bigint,
    unique (cp_id, provider_id)
  );
  create index if not exists founder_anchor_jobs_due on public.founder_anchor_jobs (state, next_try_ms) where state in ('queued', 'pending');
  alter table public.founder_anchor_jobs enable row level security;
  revoke all on public.founder_anchor_jobs from public, anon, authenticated;
  grant select, insert, update on public.founder_anchor_jobs to service_role;
  revoke delete, truncate, references, trigger on public.founder_anchor_jobs from service_role;
end $$;

-- 4) evidence (append-only, hash-chained) ---------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  create table if not exists public.founder_anchor_evidence (
    id              bigint generated always as identity primary key,
    job_id          bigint  not null references public.founder_anchor_jobs (id),
    cp_id           bigint  not null,
    provider_id     integer not null references public.founder_anchor_providers (id),
    version         integer not null check (version >= 1),
    stage           text    not null check (stage in ('tsa_token', 'ots_pending', 'ots_bitcoin')),
    digest_hex      text    not null check (digest_hex ~ '^[0-9a-f]{64}$'),
    evidence        bytea   not null check (octet_length(evidence) between 20 and 200000),
    evidence_sha256 text    not null check (evidence_sha256 ~ '^[0-9a-f]{64}$'),
    parsed          jsonb   not null,        -- tsa_token: gen_time_ms, serial, nonce, signer_pin, tsa_name ; ots_pending: commit_hex, calendar ; ots_bitcoin: commit_hex, btc_height, btc_time_ms
    recorded_ms     bigint  not null,
    prev_hash       text    not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash            text    not null unique check (hash ~ '^[0-9a-f]{64}$'),
    unique (job_id, version)
  );
  create index if not exists founder_anchor_evidence_cp on public.founder_anchor_evidence (cp_id, stage);
  alter table public.founder_anchor_evidence enable row level security;
  revoke all on public.founder_anchor_evidence from public, anon, authenticated;
  grant select, insert on public.founder_anchor_evidence to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_anchor_evidence from service_role;
end $$;

create or replace function public._fm_anchor_hash(p_prev text, p_job bigint, p_cp bigint, p_stage text, p_digest text, p_ev_sha text, p_ms bigint, p_version integer) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_job || '|' || p_cp || '|' || p_stage || '|' || p_digest || '|' || p_ev_sha || '|' || p_ms || '|' || p_version, 'UTF8'), 'sha256'), 'hex')
$$;

-- the signed note's digest, computed HERE (never taken from the caller)
create or replace function public._fm_anchor_digest(p_cp bigint) returns text
language sql stable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(note, 'UTF8'), 'sha256'), 'hex') from public.founder_audit_signed_checkpoints where cp_id = p_cp
$$;

-- 5) events (append-only, hash-chained) ------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:ddl', 0));
  create table if not exists public.founder_anchor_events (
    id          bigint generated always as identity primary key,
    ts_ms       bigint  not null,
    event       text    not null check (event in ('enqueued', 'submitted', 'tsa_ok', 'ots_pending', 'ots_bitcoin', 'failed', 'dead', 'signer_changed', 'signer_accepted', 'provider_set', 'verified')),
    cp_id       bigint,
    provider_id integer,
    detail      text    not null default '' check (length(detail) <= 400),
    prev_hash   text    not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash        text    not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_anchor_events_ts on public.founder_anchor_events (ts_ms desc);
  alter table public.founder_anchor_events enable row level security;
  revoke all on public.founder_anchor_events from public, anon, authenticated;
  grant select, insert on public.founder_anchor_events to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_anchor_events from service_role;
end $$;

create or replace function public._fm_anchor_event_guard() returns trigger language plpgsql as $$
declare v_prev text;
begin
  if tg_op <> 'INSERT' then raise exception 'founder_anchor_events is append-only (% blocked)', tg_op using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:events', 0));
  select hash into v_prev from public.founder_anchor_events order by id desc limit 1;
  new.prev_hash := coalesce(v_prev, repeat('0', 64));
  new.ts_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  new.hash := encode(extensions.digest(convert_to(new.prev_hash || '|' || new.ts_ms || '|' || new.event || '|' || coalesce(new.cp_id::text, '') || '|' || coalesce(new.provider_id::text, '') || '|' || new.detail, 'UTF8'), 'sha256'), 'hex');
  return new;
end $$;
drop trigger if exists founder_anchor_events_guard on public.founder_anchor_events;
create trigger founder_anchor_events_guard before insert or update or delete on public.founder_anchor_events for each row execute function public._fm_anchor_event_guard();
drop trigger if exists founder_anchor_events_guard_trunc on public.founder_anchor_events;
create trigger founder_anchor_events_guard_trunc before truncate on public.founder_anchor_events for each statement execute function public._fm_anchor_event_guard();

create or replace function public._fm_anchor_ev(p_event text, p_cp bigint, p_provider integer, p_detail text) returns void
language sql set search_path = pg_catalog, public as $$
  insert into public.founder_anchor_events (event, cp_id, provider_id, detail, ts_ms, prev_hash, hash) values (p_event, p_cp, p_provider, left(coalesce(p_detail, ''), 400), 1, repeat('0', 64), repeat('0', 64))
$$;

-- jobs: identity fields frozen, 'done' is terminal, no delete
create or replace function public._fm_anchor_job_guard() returns trigger language plpgsql as $$
begin
  if tg_op in ('DELETE', 'TRUNCATE') then raise exception 'founder_anchor_jobs: jobs are never deleted' using errcode = '42501'; end if;
  if tg_op = 'UPDATE' then
    if new.id <> old.id or new.cp_id <> old.cp_id or new.provider_id <> old.provider_id or new.created_ms <> old.created_ms then raise exception 'founder_anchor_jobs: identity fields are frozen' using errcode = '42501'; end if;
    if old.state = 'done' and new.state <> 'done' then raise exception 'founder_anchor_jobs: a finished job does not reopen' using errcode = '42501'; end if;
    if old.state = 'dead' and new.state not in ('dead', 'queued') then raise exception 'founder_anchor_jobs: a dead job can only be re-queued' using errcode = '42501'; end if;
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists founder_anchor_jobs_guard on public.founder_anchor_jobs;
create trigger founder_anchor_jobs_guard before update or delete on public.founder_anchor_jobs for each row execute function public._fm_anchor_job_guard();
drop trigger if exists founder_anchor_jobs_guard_trunc on public.founder_anchor_jobs;
create trigger founder_anchor_jobs_guard_trunc before truncate on public.founder_anchor_jobs for each statement execute function public._fm_anchor_job_guard();

-- evidence: the judge of every proof that enters. Digest is recomputed from the stored signed note; the token must contain it; times must be plausible; the chain is filled here.
create or replace function public._fm_anchor_evidence_guard() returns trigger language plpgsql as $$
declare j public.founder_anchor_jobs%rowtype; pr public.founder_anchor_providers%rowtype; pol public.founder_anchor_policy%rowtype;
        v_sig_ms bigint; v_dig text; v_prev text; v_ver integer; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_gen bigint; v_last_gen bigint; v_btc_ms bigint;
begin
  if tg_op <> 'INSERT' then raise exception 'founder_anchor_evidence is append-only (% blocked)', tg_op using errcode = '42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:evidence', 0));
  select * into pol from public.founder_anchor_policy where id;
  select * into j from public.founder_anchor_jobs where id = new.job_id;
  if not found then raise exception 'E124: no such job' using errcode = '23503'; end if;
  select * into pr from public.founder_anchor_providers where id = j.provider_id;
  if new.cp_id <> j.cp_id or new.provider_id <> j.provider_id then raise exception 'E124: evidence does not belong to this job' using errcode = '22023'; end if;
  if (pr.kind = 'rfc3161') <> (new.stage = 'tsa_token') then raise exception 'E124: stage % does not fit a % provider', new.stage, pr.kind using errcode = '22023'; end if;
  select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = new.cp_id;
  if v_sig_ms is null then raise exception 'E124: that seal has no signed note' using errcode = '23503'; end if;
  v_dig := public._fm_anchor_digest(new.cp_id);
  if new.digest_hex <> v_dig then raise exception 'E124: the digest is not sha256 of the stored signed note' using errcode = '22023'; end if;
  if new.evidence_sha256 <> encode(extensions.digest(new.evidence, 'sha256'), 'hex') then raise exception 'E124: evidence_sha256 does not match the evidence bytes' using errcode = '22023'; end if;
  if abs(new.recorded_ms - v_now) > 60000 then raise exception 'E124: recorded_ms must be now' using errcode = '22023'; end if;
  select coalesce(max(version), 0) + 1 into v_ver from public.founder_anchor_evidence where job_id = new.job_id;
  if new.version <> v_ver then raise exception 'E124: version must be % (got %)', v_ver, new.version using errcode = '22023'; end if;
  if jsonb_typeof(new.parsed) <> 'object' then raise exception 'E124: parsed must be an object' using errcode = '22023'; end if;

  if new.stage = 'tsa_token' then
    if jsonb_typeof(new.parsed -> 'gen_time_ms') <> 'number' or (new.parsed ->> 'signer_pin') !~ '^[0-9a-f]{64}$' or coalesce(new.parsed ->> 'serial', '') !~ '^[0-9a-f]{2,80}$' then
      raise exception 'E124: a TSA token needs gen_time_ms, serial (hex) and signer_pin' using errcode = '22023'; end if;
    if position(decode(v_dig, 'hex') in new.evidence) = 0 then raise exception 'E124: the token does not contain the digest it claims to stamp' using errcode = '22023'; end if;
    v_gen := (new.parsed ->> 'gen_time_ms')::bigint;
    if v_gen < v_sig_ms - pol.skew_secs * 1000 then raise exception 'E124: the TSA time (%) is BEFORE the note was signed (%): impossible', v_gen, v_sig_ms using errcode = '22023'; end if;
    if v_gen > new.recorded_ms + pol.skew_secs * 1000 then raise exception 'E124: the TSA time is in the future' using errcode = '22023'; end if;
    -- a provider's clock never goes backwards across checkpoints
    select max((e.parsed ->> 'gen_time_ms')::bigint) into v_last_gen from public.founder_anchor_evidence e where e.provider_id = new.provider_id and e.stage = 'tsa_token' and e.cp_id < new.cp_id;
    if v_last_gen is not null and v_gen < v_last_gen - pol.skew_secs * 1000 then raise exception 'E124: time went backwards for this TSA (% < %)', v_gen, v_last_gen using errcode = '22023'; end if;
  elsif new.stage = 'ots_pending' then
    if (new.parsed ->> 'commit_hex') !~ '^[0-9a-f]{64}$' or coalesce(new.parsed ->> 'calendar', '') = '' then raise exception 'E124: a pending proof needs commit_hex and calendar' using errcode = '22023'; end if;
  else
    if (new.parsed ->> 'commit_hex') !~ '^[0-9a-f]{64}$' or jsonb_typeof(new.parsed -> 'btc_height') <> 'number' or (new.parsed ->> 'btc_height')::bigint not between 1 and 20000000 then
      raise exception 'E124: a Bitcoin proof needs commit_hex and a sane btc_height' using errcode = '22023'; end if;
    if new.parsed ? 'btc_time_ms' then
      v_btc_ms := (new.parsed ->> 'btc_time_ms')::bigint;
      if v_btc_ms < v_sig_ms - pol.btc_time_slack_secs * 1000 then raise exception 'E124: the Bitcoin block time (%) is before the note was signed (%)', v_btc_ms, v_sig_ms using errcode = '22023'; end if;
      if v_btc_ms > new.recorded_ms + pol.btc_time_slack_secs * 1000 then raise exception 'E124: the Bitcoin block time is in the future' using errcode = '22023'; end if;
    end if;
  end if;
  select hash into v_prev from public.founder_anchor_evidence order by id desc limit 1;
  new.prev_hash := coalesce(v_prev, repeat('0', 64));
  new.hash := public._fm_anchor_hash(new.prev_hash, new.job_id, new.cp_id, new.stage, new.digest_hex, new.evidence_sha256, new.recorded_ms, new.version);
  return new;
end $$;
drop trigger if exists founder_anchor_evidence_guard on public.founder_anchor_evidence;
create trigger founder_anchor_evidence_guard before insert or update or delete on public.founder_anchor_evidence for each row execute function public._fm_anchor_evidence_guard();
drop trigger if exists founder_anchor_evidence_guard_trunc on public.founder_anchor_evidence;
create trigger founder_anchor_evidence_guard_trunc before truncate on public.founder_anchor_evidence for each statement execute function public._fm_anchor_evidence_guard();

-- 6) doors -----------------------------------------------------------------------------------------------------------------------------
-- level of one checkpoint: none < ots-pending < tsa < bitcoin < strong. Only tsa / bitcoin / strong are a TIME claim.
create or replace function public.founder_anchor_level(p_cp bigint) returns text
language sql stable security definer set search_path = pg_catalog, public as $$
  select case when t and b then 'strong' when b then 'bitcoin' when t then 'tsa' when o then 'ots-pending' else 'none' end
  from (select exists (select 1 from public.founder_anchor_evidence where cp_id = p_cp and stage = 'tsa_token') as t,
               exists (select 1 from public.founder_anchor_evidence where cp_id = p_cp and stage = 'ots_bitcoin') as b,
               exists (select 1 from public.founder_anchor_evidence where cp_id = p_cp and stage = 'ots_pending') as o) x
$$;

-- queue a job per (newest signed checkpoints x enabled providers). Safe to call every tick. No audit row (an audit row would make a seal, which would need a signature, which would need anchors...).
create or replace function public.founder_anchor_enqueue() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare pol public.founder_anchor_policy%rowtype; r record; v_n integer := 0;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:enqueue', 0));
  select * into pol from public.founder_anchor_policy where id;
  for r in
    with ins as (
      insert into public.founder_anchor_jobs (cp_id, provider_id)
      select s.cp_id, p.id from (select cp_id from public.founder_audit_signed_checkpoints order by cp_id desc limit pol.backlog_cap) s
        cross join public.founder_anchor_providers p where p.enabled
      on conflict (cp_id, provider_id) do nothing returning cp_id, provider_id)
    select cp_id, provider_id from ins loop
    perform public._fm_anchor_ev('enqueued', r.cp_id, r.provider_id, 'job queued');
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('queued', v_n);
end $$;

-- hand out due jobs and LEASE them (next_try moves ahead by lease_secs, so two ticks never work the same job). Everything Rust needs is in the answer.
create or replace function public.founder_anchor_next(p_limit integer default 6) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare pol public.founder_anchor_policy%rowtype; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_out jsonb;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_anchor:next', 0));
  select * into pol from public.founder_anchor_policy where id;
  with due as (
    select j.id from public.founder_anchor_jobs j join public.founder_anchor_providers p on p.id = j.provider_id
    where p.enabled and j.state in ('queued', 'pending') and j.next_try_ms <= v_now
    order by j.next_try_ms, j.id limit greatest(1, least(coalesce(p_limit, 6), 30)) for update of j skip locked),
  lease as (
    update public.founder_anchor_jobs j set next_try_ms = v_now + pol.lease_secs * 1000, updated_ms = v_now from due where j.id = due.id returning j.*)
  select coalesce(jsonb_agg(jsonb_build_object(
      'job_id', l.id, 'cp_id', l.cp_id, 'state', l.state, 'attempts', l.attempts, 'kind', p.kind, 'provider', p.name, 'url', p.url, 'timeout_ms', p.timeout_ms, 'min_gap_secs', p.min_gap_secs,
      'digest_hex', public._fm_anchor_digest(l.cp_id), 'signer_pin', p.signer_pin,
      'pending_hex', (select encode(e.evidence, 'hex') from public.founder_anchor_evidence e where e.job_id = l.id and e.stage = 'ots_pending' order by e.version desc limit 1),
      'commit_hex', (select e.parsed ->> 'commit_hex' from public.founder_anchor_evidence e where e.job_id = l.id and e.stage = 'ots_pending' order by e.version desc limit 1)
    ) order by l.next_try_ms, l.id), '[]'::jsonb)
  into v_out from lease l join public.founder_anchor_providers p on p.id = l.provider_id;
  return v_out;
end $$;

-- a verified RFC 3161 token (Rust parsed it and checked the CMS signature; the browser kernel checks it again). Signer pin: first sight is remembered, a different signer is FLAGGED, never silently accepted.
create or replace function public.founder_anchor_record_tsa(p_job bigint, p_evidence_hex text, p_parsed jsonb) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare j public.founder_anchor_jobs%rowtype; pr public.founder_anchor_providers%rowtype; v_ev bytea; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_changed boolean := false; v_ver integer; v_parsed jsonb;
begin
  select * into j from public.founder_anchor_jobs where id = p_job for update;
  if not found then raise exception 'E124: no such job' using errcode = '23503'; end if;
  select * into pr from public.founder_anchor_providers where id = j.provider_id;
  if pr.kind <> 'rfc3161' then raise exception 'E124: not a TSA job' using errcode = '22023'; end if;
  if j.state = 'done' then return jsonb_build_object('recorded', false, 'reason', 'job already done'); end if;
  if (p_evidence_hex !~ '^[0-9a-f]+$' or length(p_evidence_hex) % 2 <> 0 or length(p_evidence_hex) not between 40 and 400000) then raise exception 'E124: evidence must be lowercase hex' using errcode = '22023'; end if;
  v_ev := decode(p_evidence_hex, 'hex');
  if pr.signer_pin is not null and pr.signer_pin <> (p_parsed ->> 'signer_pin') then v_changed := true; end if;
  v_parsed := p_parsed || jsonb_build_object('signer_changed', v_changed);
  select coalesce(max(version), 0) + 1 into v_ver from public.founder_anchor_evidence where job_id = p_job;
  insert into public.founder_anchor_evidence (job_id, cp_id, provider_id, version, stage, digest_hex, evidence, evidence_sha256, parsed, recorded_ms, prev_hash, hash)
    values (p_job, j.cp_id, j.provider_id, v_ver, 'tsa_token', public._fm_anchor_digest(j.cp_id), v_ev, encode(extensions.digest(v_ev, 'sha256'), 'hex'), v_parsed, v_ms, repeat('0', 64), repeat('0', 64));
  if pr.signer_pin is null then update public.founder_anchor_providers set signer_pin = p_parsed ->> 'signer_pin' where id = pr.id; end if;
  update public.founder_anchor_jobs set state = 'done', last_error = null, updated_ms = v_ms where id = p_job;
  perform public._fm_anchor_ev('tsa_ok', j.cp_id, j.provider_id, 'TSA time ' || (p_parsed ->> 'gen_time_ms') || ' signer ' || left(p_parsed ->> 'signer_pin', 12));
  if v_changed then perform public._fm_anchor_ev('signer_changed', j.cp_id, j.provider_id, 'signer certificate key differs from the pinned one: ' || left(p_parsed ->> 'signer_pin', 12)); end if;
  return jsonb_build_object('recorded', true, 'signer_changed', v_changed, 'version', v_ver);
end $$;

-- an OpenTimestamps proof: 'ots_pending' (calendar accepted it, not in Bitcoin yet) or 'ots_bitcoin' (upgraded: a Bitcoin block attests the commitment)
create or replace function public.founder_anchor_record_ots(p_job bigint, p_stage text, p_evidence_hex text, p_parsed jsonb) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare j public.founder_anchor_jobs%rowtype; pr public.founder_anchor_providers%rowtype; pol public.founder_anchor_policy%rowtype; v_ev bytea; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_ver integer;
begin
  if p_stage not in ('ots_pending', 'ots_bitcoin') then raise exception 'E124: stage must be ots_pending or ots_bitcoin' using errcode = '22023'; end if;
  select * into j from public.founder_anchor_jobs where id = p_job for update;
  if not found then raise exception 'E124: no such job' using errcode = '23503'; end if;
  select * into pr from public.founder_anchor_providers where id = j.provider_id;
  select * into pol from public.founder_anchor_policy where id;
  if pr.kind <> 'ots' then raise exception 'E124: not an OpenTimestamps job' using errcode = '22023'; end if;
  if j.state = 'done' then return jsonb_build_object('recorded', false, 'reason', 'job already done'); end if;
  if p_stage = 'ots_pending' and exists (select 1 from public.founder_anchor_evidence where job_id = p_job and stage = 'ots_pending') then return jsonb_build_object('recorded', false, 'reason', 'pending proof already stored'); end if;
  if (p_evidence_hex !~ '^[0-9a-f]+$' or length(p_evidence_hex) % 2 <> 0 or length(p_evidence_hex) not between 40 and 400000) then raise exception 'E124: evidence must be lowercase hex' using errcode = '22023'; end if;
  v_ev := decode(p_evidence_hex, 'hex');
  select coalesce(max(version), 0) + 1 into v_ver from public.founder_anchor_evidence where job_id = p_job;
  insert into public.founder_anchor_evidence (job_id, cp_id, provider_id, version, stage, digest_hex, evidence, evidence_sha256, parsed, recorded_ms, prev_hash, hash)
    values (p_job, j.cp_id, j.provider_id, v_ver, p_stage, public._fm_anchor_digest(j.cp_id), v_ev, encode(extensions.digest(v_ev, 'sha256'), 'hex'), p_parsed, v_ms, repeat('0', 64), repeat('0', 64));
  if p_stage = 'ots_bitcoin' then
    update public.founder_anchor_jobs set state = 'done', last_error = null, updated_ms = v_ms where id = p_job;
    perform public._fm_anchor_ev('ots_bitcoin', j.cp_id, j.provider_id, 'Bitcoin block ' || (p_parsed ->> 'btc_height'));
  else
    update public.founder_anchor_jobs set state = 'pending', last_error = null, attempts = 0, next_try_ms = v_ms + pol.ots_poll_secs * 1000, updated_ms = v_ms where id = p_job;
    perform public._fm_anchor_ev('ots_pending', j.cp_id, j.provider_id, 'accepted by ' || coalesce(p_parsed ->> 'calendar', '?'));
  end if;
  return jsonb_build_object('recorded', true, 'stage', p_stage, 'version', v_ver);
end $$;

-- a failed try: exponential backoff (base * 2^(attempts-1), capped at 6 h), dead letter after max_attempts. A pending OTS job that only failed to UPGRADE keeps its proof and goes on polling.
create or replace function public.founder_anchor_fail(p_job bigint, p_error text, p_retryable boolean default true) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare j public.founder_anchor_jobs%rowtype; pol public.founder_anchor_policy%rowtype; v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_att integer; v_wait bigint; v_dead boolean; v_err text;
begin
  select * into j from public.founder_anchor_jobs where id = p_job for update;
  if not found then raise exception 'E124: no such job' using errcode = '23503'; end if;
  if j.state in ('done', 'dead') then return jsonb_build_object('recorded', false, 'reason', 'job is ' || j.state); end if;
  select * into pol from public.founder_anchor_policy where id;
  v_err := left(regexp_replace(coalesce(p_error, 'unknown error'), '[\x01-\x1f\x7f]', ' ', 'g'), 400);
  v_att := j.attempts + 1;
  v_dead := (not coalesce(p_retryable, true)) or (j.state = 'queued' and v_att >= pol.max_attempts);
  if j.state = 'pending' then v_dead := false; end if;
  v_wait := least(21600, pol.backoff_base_secs * (2 ^ least(v_att - 1, 12))::bigint) * 1000;
  if j.state = 'pending' then v_wait := pol.ots_poll_secs * 1000; end if;
  update public.founder_anchor_jobs set attempts = case when j.state = 'pending' then j.attempts else v_att end, last_error = v_err, state = case when v_dead then 'dead' else j.state end,
    next_try_ms = v_ms + v_wait, updated_ms = v_ms where id = p_job;
  perform public._fm_anchor_ev(case when v_dead then 'dead' else 'failed' end, j.cp_id, j.provider_id, v_err);
  return jsonb_build_object('recorded', true, 'dead', v_dead, 'attempts', v_att, 'retry_in_s', v_wait / 1000);
end $$;

-- founder-only, audited: switch a provider on/off
create or replace function public.founder_anchor_provider_set(p_actor uuid, p_name text, p_enabled boolean, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pr public.founder_anchor_providers%rowtype;
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E124: actor is not a founder' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 then raise exception 'E124: reason needs 8 characters' using errcode = '22023'; end if;
  select * into pr from public.founder_anchor_providers where name = p_name for update;
  if not found then raise exception 'E124: no such provider' using errcode = '23503'; end if;
  update public.founder_anchor_providers set enabled = p_enabled where id = pr.id;
  perform public._fm_anchor_ev('provider_set', null, pr.id, (case when p_enabled then 'enabled ' else 'disabled ' end) || p_name);
  perform public.founder_audit_append(p_actor, 'anchor.provider', 'provider:' || p_name, btrim(p_reason), jsonb_build_object('enabled', p_enabled));
  return jsonb_build_object('name', p_name, 'enabled', p_enabled);
end $$;

-- founder-only, audited: accept a TSA's NEW signer certificate key (after a flagged change), e.g. when the TSA renewed its certificate
create or replace function public.founder_anchor_signer_accept(p_actor uuid, p_name text, p_pin text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pr public.founder_anchor_providers%rowtype;
begin
  if p_actor is null or not exists (select 1 from public.founder_accounts where user_id = p_actor) then raise exception 'E124: actor is not a founder' using errcode = '42501'; end if;
  if length(btrim(coalesce(p_reason, ''))) < 8 or p_pin !~ '^[0-9a-f]{64}$' then raise exception 'E124: need a reason and a 64-hex pin' using errcode = '22023'; end if;
  select * into pr from public.founder_anchor_providers where name = p_name and kind = 'rfc3161' for update;
  if not found then raise exception 'E124: no such TSA' using errcode = '23503'; end if;
  update public.founder_anchor_providers set signer_pin = p_pin where id = pr.id;
  perform public._fm_anchor_ev('signer_accepted', null, pr.id, 'pin now ' || left(p_pin, 12));
  perform public.founder_audit_append(p_actor, 'anchor.signer', 'provider:' || p_name, btrim(p_reason), jsonb_build_object('pin', p_pin));
  return jsonb_build_object('name', p_name, 'pin', p_pin);
end $$;

-- the Dashboard question: "are my checkpoints anchored to the outside world, and how well?"  Cheap enough for a 5 s poll.
create or replace function public.founder_anchor_pulse() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare pol public.founder_anchor_policy%rowtype; v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint; v_head bigint; v_head_ms bigint; v_lvl text; v_age bigint;
        v_level text := 'ok'; v_why text := 'the newest signed checkpoint carries a time claim'; v_enabled integer; v_dead bigint; v_changed boolean; v_oldest_un bigint; v_first_ms bigint; v_ots_old bigint; v_provs jsonb;
begin
  select * into pol from public.founder_anchor_policy where id;
  select count(*) into v_enabled from public.founder_anchor_providers where enabled;
  select cp_id, signed_ms into v_head, v_head_ms from public.founder_audit_signed_checkpoints order by cp_id desc limit 1;
  select count(*) into v_dead from public.founder_anchor_jobs j where j.state = 'dead' and j.cp_id > coalesce(v_head, 0) - 10;
  -- any TSA whose signer changed after the last time the founder accepted a signer for it
  select exists (select 1 from public.founder_anchor_evidence e where e.stage = 'tsa_token' and (e.parsed ->> 'signer_changed')::boolean
                   and e.recorded_ms > coalesce((select max(ev.ts_ms) from public.founder_anchor_events ev where ev.event = 'signer_accepted' and ev.provider_id = e.provider_id), 0)
                   and e.cp_id > coalesce(v_head, 0) - 20) into v_changed;
  select min(s.signed_ms) into v_oldest_un from public.founder_audit_signed_checkpoints s
    where s.cp_id > coalesce(v_head, 0) - 10 and public.founder_anchor_level(s.cp_id) in ('none', 'ots-pending');
  select min(e.recorded_ms) into v_ots_old from public.founder_anchor_evidence e
    where e.stage = 'ots_pending' and not exists (select 1 from public.founder_anchor_evidence b where b.job_id = e.job_id and b.stage = 'ots_bitcoin');
  if v_head is null then v_level := 'off'; v_why := 'no signed checkpoint yet';
  elsif v_enabled = 0 then v_level := 'off'; v_why := 'every time-anchor provider is switched off';
  else
    v_lvl := public.founder_anchor_level(v_head);
    v_age := greatest(0, (v_now - v_head_ms) / 1000);
    if v_lvl in ('none', 'ots-pending') then
      v_why := case when v_lvl = 'none' then 'the newest signed checkpoint has no outside time claim yet' else 'only a pending OpenTimestamps proof so far: not yet a time claim' end;
      if v_age >= pol.fail_secs then v_level := 'fail'; elsif v_age >= pol.warn_secs then v_level := 'warn'; else v_level := 'ok'; v_why := v_why || ' (still within the grace period)'; end if;
    end if;
    if v_level = 'ok' and v_changed then v_level := 'warn'; v_why := 'a time-stamp authority is signing with a different certificate key than the pinned one'; end if;
    if v_level = 'ok' and v_dead > 0 then v_level := 'warn'; v_why := v_dead || ' anchoring job(s) gave up'; end if;
    if v_level = 'ok' and v_ots_old is not null and (v_now - v_ots_old) / 1000 > pol.ots_pending_warn_secs and v_lvl not in ('bitcoin', 'strong') then v_level := 'warn'; v_why := 'an OpenTimestamps proof has been pending for more than ' || (pol.ots_pending_warn_secs / 3600) || ' h'; end if;
  end if;
  select min(least(coalesce((e.parsed ->> 'gen_time_ms')::bigint, 9e18::bigint), coalesce((e.parsed ->> 'btc_time_ms')::bigint, 9e18::bigint))) into v_first_ms
    from public.founder_anchor_evidence e where e.cp_id = v_head and e.stage in ('tsa_token', 'ots_bitcoin');
  if v_first_ms >= 9e18::bigint then v_first_ms := null; end if;
  select coalesce(jsonb_agg(jsonb_build_object('name', p.name, 'kind', p.kind, 'enabled', p.enabled,
      'done', (select count(*) from public.founder_anchor_jobs j where j.provider_id = p.id and j.state = 'done'),
      'pending', (select count(*) from public.founder_anchor_jobs j where j.provider_id = p.id and j.state in ('queued', 'pending')),
      'dead', (select count(*) from public.founder_anchor_jobs j where j.provider_id = p.id and j.state = 'dead'),
      'last_ok_ms', (select max(e.recorded_ms) from public.founder_anchor_evidence e where e.provider_id = p.id),
      'last_error', (select j.last_error from public.founder_anchor_jobs j where j.provider_id = p.id and j.last_error is not null order by j.updated_ms desc limit 1),
      'signer_pin', left(p.signer_pin, 16)) order by p.kind, p.name), '[]'::jsonb) into v_provs from public.founder_anchor_providers p;
  return jsonb_build_object('level', v_level, 'why', v_why, 'head_cp', v_head, 'head_level', v_lvl,
    'time_anchored', v_lvl in ('tsa', 'bitcoin', 'strong'), 'strong', v_lvl = 'strong', 'anchored_not_later_than_ms', v_first_ms,
    'head_signed_ms', v_head_ms, 'head_age_s', v_age, 'oldest_unanchored_signed_ms', v_oldest_un, 'dead', v_dead, 'enabled_providers', v_enabled,
    'bitcoin_confirmed', (select count(distinct cp_id) from public.founder_anchor_evidence where stage = 'ots_bitcoin'),
    'tsa_stamped', (select count(distinct cp_id) from public.founder_anchor_evidence where stage = 'tsa_token'),
    'providers', v_provs, 'policy', jsonb_build_object('warn_secs', pol.warn_secs, 'fail_secs', pol.fail_secs), 'now_ms', v_now);
end $$;

-- everything the BROWSER needs to check a checkpoint's anchors itself (the kernel recomputes digest + commitment chain + TSA token binding)
create or replace function public.founder_anchor_get(p_cp bigint default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_cp bigint := p_cp; s public.founder_audit_signed_checkpoints%rowtype;
begin
  if v_cp is null then
    select cp_id into v_cp from public.founder_anchor_evidence where stage in ('tsa_token', 'ots_bitcoin') order by cp_id desc limit 1;
    if v_cp is null then select max(cp_id) into v_cp from public.founder_audit_signed_checkpoints; end if;
  end if;
  select * into s from public.founder_audit_signed_checkpoints where cp_id = v_cp;
  if not found then return jsonb_build_object('found', false); end if;
  return jsonb_build_object('found', true, 'cp_id', s.cp_id, 'signed_ms', s.signed_ms, 'note', s.note, 'digest_hex', public._fm_anchor_digest(s.cp_id), 'level', public.founder_anchor_level(s.cp_id),
    'evidence', (select coalesce(jsonb_agg(jsonb_build_object('job_id', x.job_id, 'provider', p.name, 'kind', p.kind, 'stage', x.stage, 'version', x.version,
                      'evidence_hex', encode(x.evidence, 'hex'), 'parsed', x.parsed, 'recorded_ms', x.recorded_ms) order by p.kind, p.name), '[]'::jsonb)
                 from (select distinct on (job_id) * from public.founder_anchor_evidence where cp_id = s.cp_id order by job_id, version desc) x join public.founder_anchor_providers p on p.id = x.provider_id));
end $$;

-- re-check what is STORED: digests re-derived from the signed notes, evidence hashes, both hash chains (last 500 rows each), and the time rules once more.
create or replace function public.founder_anchor_verify(p_last integer default 500) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; pol public.founder_anchor_policy%rowtype; v_probs jsonb := '[]'::jsonb; v_n integer := 0; v_prev text; v_first boolean := true; v_sig_ms bigint; v_h text;
begin
  select * into pol from public.founder_anchor_policy where id;
  for r in select e.*, p.kind from (select * from public.founder_anchor_evidence order by id desc limit greatest(1, least(coalesce(p_last, 500), 2000))) e join public.founder_anchor_providers p on p.id = e.provider_id order by e.id loop
    v_n := v_n + 1;
    if not v_first and r.prev_hash <> v_prev then v_probs := v_probs || jsonb_build_array(jsonb_build_object('evidence_id', r.id, 'problem', 'the evidence chain is broken here')); end if;
    v_first := false;
    v_h := public._fm_anchor_hash(r.prev_hash, r.job_id, r.cp_id, r.stage, r.digest_hex, r.evidence_sha256, r.recorded_ms, r.version);
    if v_h <> r.hash then v_probs := v_probs || jsonb_build_array(jsonb_build_object('evidence_id', r.id, 'problem', 'the stored hash does not match the row')); end if;
    v_prev := r.hash;
    if r.digest_hex <> coalesce(public._fm_anchor_digest(r.cp_id), '') then v_probs := v_probs || jsonb_build_array(jsonb_build_object('evidence_id', r.id, 'problem', 'the digest is no longer the sha256 of the signed note')); end if;
    if r.evidence_sha256 <> encode(extensions.digest(r.evidence, 'sha256'), 'hex') then v_probs := v_probs || jsonb_build_array(jsonb_build_object('evidence_id', r.id, 'problem', 'the evidence bytes changed')); end if;
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = r.cp_id;
    if r.stage = 'tsa_token' and ((r.parsed ->> 'gen_time_ms')::bigint < v_sig_ms - pol.skew_secs * 1000 or position(decode(r.digest_hex, 'hex') in r.evidence) = 0) then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('evidence_id', r.id, 'problem', 'the TSA token is older than the note or does not contain the digest')); end if;
  end loop;
  v_prev := null; v_first := true;
  for r in select * from (select * from public.founder_anchor_events order by id desc limit greatest(1, least(coalesce(p_last, 500), 2000))) q order by id loop
    if not v_first and r.prev_hash <> v_prev then v_probs := v_probs || jsonb_build_array(jsonb_build_object('event_id', r.id, 'problem', 'the event chain is broken here')); end if;
    v_first := false; v_prev := r.hash;
    if r.hash <> encode(extensions.digest(convert_to(r.prev_hash || '|' || r.ts_ms || '|' || r.event || '|' || coalesce(r.cp_id::text, '') || '|' || coalesce(r.provider_id::text, '') || '|' || r.detail, 'UTF8'), 'sha256'), 'hex') then
      v_probs := v_probs || jsonb_build_array(jsonb_build_object('event_id', r.id, 'problem', 'an event hash does not match its row')); end if;
  end loop;
  return jsonb_build_object('checked_evidence', v_n, 'ok', jsonb_array_length(v_probs) = 0, 'problems', v_probs);
end $$;

-- 7) selftest (everything inside a block that ends in ROLLBACK) -------------------------------------------------------------------------
create or replace function public.founder_anchor_e124_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '90s' as $$
declare r text := ''; v_uid uuid; j jsonb; v_cp jsonb; v_name text := 'selftest.example/anchor-log'; v_pub text := repeat('ab', 32); v_kid text; v_key_id bigint; v_body text; v_note text; v_raw text; v_cpid bigint; v_sig_ms bigint;
        v_dig text; v_jobs jsonb; v_tsa1 bigint; v_tsa2 bigint; v_ots1 bigint; v_ots2 bigint; v_ots3 bigint; v_ev text; b_jobs bigint; b_evi bigint; b_evt bigint; b_aud bigint; b_prov text; x jsonb; i integer;
        v_pin_a text := repeat('a', 64); v_pin_b text := repeat('b', 64);
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E124 selftest SKIP (no founder account yet)'; end if;
  select count(*) into b_jobs from public.founder_anchor_jobs; select count(*) into b_evi from public.founder_anchor_evidence; select count(*) into b_evt from public.founder_anchor_events;
  select count(*) into b_aud from public.founder_audit; select md5(string_agg(id || ':' || enabled || ':' || coalesce(signer_pin, ''), ',' order by id)) into b_prov from public.founder_anchor_providers;
  begin
    -- a signed checkpoint to anchor (fake audit-log key; SQL does not check Ed25519, the E123 judge checks the note's shape)
    update public.founder_audit_log_keys set status = 'retired', retired_ms = greatest(created_ms, (extract(epoch from clock_timestamp()) * 1000)::bigint) where status = 'active';
    v_kid := substr(encode(extensions.digest(convert_to(v_name, 'UTF8') || '\x0a01'::bytea || decode(v_pub, 'hex'), 'sha256'), 'hex'), 1, 8);
    perform public.founder_audit_log_key_register(v_uid, v_name, v_pub, v_kid);
    select id into v_key_id from public.founder_audit_log_keys where status = 'active';
    perform public.founder_audit_append(v_uid, 'e124.selftest', 'row-1', 'selftest entry for an anchor', '{}'::jsonb);
    perform public.founder_audit_checkpoint(v_uid, 'selftest seal for the anchor test');
    v_cp := (public.founder_audit_signed_cp_pending(50)) -> -1;
    v_cpid := (v_cp ->> 'cp_id')::bigint;
    v_body := v_name || E'\n' || (v_cp ->> 'size') || E'\n' || encode(decode(v_cp ->> 'root', 'hex'), 'base64') || E'\n';
    v_raw := replace(encode(decode(v_kid, 'hex') || decode(repeat('11', 64), 'hex'), 'base64'), E'\n', '');
    v_note := v_body || E'\n' || E'— ' || v_name || ' ' || v_raw || E'\n';
    perform public.founder_audit_signed_cp_add(v_cpid, v_key_id, v_note);
    select signed_ms into v_sig_ms from public.founder_audit_signed_checkpoints where cp_id = v_cpid;
    v_dig := encode(extensions.digest(convert_to(v_note, 'UTF8'), 'sha256'), 'hex');
    if public._fm_anchor_digest(v_cpid) <> v_dig then raise exception 'SQL digest of the note is wrong'; end if;
    if public.founder_anchor_level(v_cpid) <> 'none' then raise exception 'a fresh checkpoint must have level none'; end if;
    r := r || 'setup OK; ';

    -- queue + lease
    j := public.founder_anchor_enqueue();
    if (j ->> 'queued')::int < 6 then raise exception 'enqueue made fewer jobs than providers: %', j; end if;
    if (public.founder_anchor_enqueue() ->> 'queued')::int <> 0 then raise exception 'enqueue is not idempotent'; end if;
    update public.founder_anchor_jobs set next_try_ms = 0 where cp_id = v_cpid;
    select id into v_tsa1 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'freetsa');
    select id into v_tsa2 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'digicert-tsa');
    select id into v_ots1 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-alice');
    select id into v_ots2 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-bob');
    select id into v_ots3 from public.founder_anchor_jobs where cp_id = v_cpid and provider_id = (select id from public.founder_anchor_providers where name = 'ots-finney');
    v_jobs := public.founder_anchor_next(30);
    if not exists (select 1 from jsonb_array_elements(v_jobs) e where (e ->> 'job_id')::bigint = v_tsa1 and e ->> 'digest_hex' = v_dig and e ->> 'kind' = 'rfc3161') then raise exception 'next did not hand out the TSA job with the right digest: %', v_jobs; end if;
    if jsonb_array_length(public.founder_anchor_next(30)) <> 0 and exists (select 1 from jsonb_array_elements(public.founder_anchor_next(30)) e where (e ->> 'job_id')::bigint = v_tsa1) then raise exception 'a leased job was handed out twice'; end if;
    r := r || 'queue + lease OK; ';

    -- RFC 3161 rules
    v_ev := encode('\x3082'::bytea || decode(v_dig, 'hex') || '\x0102030405'::bytea, 'hex');             -- stand-in token that CONTAINS the digest (real parsing/signature check is Rust + kernel)
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, encode(decode(repeat('42', 40), 'hex'), 'hex'), jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a token that does not contain the digest was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms - 600000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA time BEFORE the note was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 86400000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA time in the future was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'zz', 'signer_pin', v_pin_a)::text)) then raise exception 'a bad serial was accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_tsa(%s, %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)::text)) then raise exception 'a TSA token was accepted on an OpenTimestamps job'; end if;
    j := public.founder_anchor_record_tsa(v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a));
    if not (j ->> 'recorded')::boolean or (j ->> 'signer_changed')::boolean then raise exception 'a good token was refused or flagged: %', j; end if;
    if (select signer_pin from public.founder_anchor_providers where name = 'freetsa') <> v_pin_a then raise exception 'first-sight signer pin was not remembered'; end if;
    if (public.founder_anchor_record_tsa(v_tsa1, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 1000, 'serial', 'aa01', 'signer_pin', v_pin_a)) ->> 'recorded')::boolean then raise exception 'a finished job accepted a second token'; end if;
    if public.founder_anchor_level(v_cpid) <> 'tsa' then raise exception 'level after a TSA token must be tsa'; end if;
    -- signer change is flagged, not silent
    update public.founder_anchor_providers set signer_pin = v_pin_a where name = 'digicert-tsa';
    j := public.founder_anchor_record_tsa(v_tsa2, v_ev, jsonb_build_object('gen_time_ms', v_sig_ms + 2000, 'serial', 'bb02', 'signer_pin', v_pin_b));
    if not (j ->> 'signer_changed')::boolean then raise exception 'a changed TSA signer was not flagged'; end if;
    if (public.founder_anchor_pulse() ->> 'level') <> 'warn' then raise exception 'a changed TSA signer must make the pulse warn: %', public.founder_anchor_pulse(); end if;
    j := public.founder_anchor_signer_accept(v_uid, 'digicert-tsa', v_pin_b, 'selftest accepts the renewed signer');
    if (public.founder_anchor_pulse() ->> 'level') <> 'ok' then raise exception 'accepting the signer must clear the warning: %', public.founder_anchor_pulse(); end if;
    r := r || 'RFC3161 rules + signer pin OK; ';

    -- OpenTimestamps: pending, then Bitcoin
    if (public.founder_anchor_pulse() ->> 'time_anchored')::boolean is not true then raise exception 'tsa level must read as time-anchored'; end if;
    j := public.founder_anchor_record_ots(v_ots1, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'calendar', 'https://alice.btc.calendar.opentimestamps.org'));
    if not (j ->> 'recorded')::boolean or (select state from public.founder_anchor_jobs where id = v_ots1) <> 'pending' then raise exception 'pending proof not recorded: %', j; end if;
    if (public.founder_anchor_record_ots(v_ots1, 'ots_pending', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'calendar', 'x')) ->> 'recorded')::boolean then raise exception 'a second pending proof was stored'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_bitcoin', %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 0)::text)) then raise exception 'height 0 accepted'; end if;
    if not public._fs_fails(format($q$select public.founder_anchor_record_ots(%s, 'ots_bitcoin', %L, %L::jsonb)$q$, v_ots1, v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms - 86400000)::text)) then raise exception 'a Bitcoin block from before the note was accepted'; end if;
    j := public.founder_anchor_record_ots(v_ots1, 'ots_bitcoin', v_ev, jsonb_build_object('commit_hex', repeat('c', 64), 'btc_height', 800000, 'btc_time_ms', v_sig_ms + 3600000));
    if not (j ->> 'recorded')::boolean or (select state from public.founder_anchor_jobs where id = v_ots1) <> 'done' then raise exception 'bitcoin proof not recorded: %', j; end if;
    if public.founder_anchor_level(v_cpid) <> 'strong' then raise exception 'tsa + bitcoin must be strong, got %', public.founder_anchor_level(v_cpid); end if;
    x := public.founder_anchor_pulse();
    if not (x ->> 'strong')::boolean or (x ->> 'head_cp')::bigint <> v_cpid or (x -> 'providers') is null or jsonb_array_length(x -> 'providers') < 6 then raise exception 'pulse is wrong: %', x; end if;
    r := r || 'OpenTimestamps pending -> bitcoin + strong OK; ';

    -- failure handling: backoff, retry, dead letter
    j := public.founder_anchor_fail(v_ots2, 'calendar said 503', true);
    if (j ->> 'dead')::boolean or (j ->> 'retry_in_s')::int < 30 then raise exception 'first failure should back off: %', j; end if;
    j := public.founder_anchor_fail(v_ots2, 'calendar said 503', true);
    if (j ->> 'retry_in_s')::int < 60 then raise exception 'backoff must double: %', j; end if;
    j := public.founder_anchor_fail(v_ots3, 'bad reply: not an OpenTimestamps proof', false);
    if not (j ->> 'dead')::boolean or (select state from public.founder_anchor_jobs where id = v_ots3) <> 'dead' then raise exception 'a non-retryable failure must be dead: %', j; end if;
    if (public.founder_anchor_fail(v_ots3, 'again', true) ->> 'recorded')::boolean then raise exception 'a dead job accepted a failure'; end if;
    for i in 1 .. 12 loop perform public.founder_anchor_fail(v_ots2, 'still down', true); end loop;
    if (select state from public.founder_anchor_jobs where id = v_ots2) <> 'dead' then raise exception 'max_attempts did not kill the job'; end if;
    if (public.founder_anchor_pulse() ->> 'dead')::int < 2 then raise exception 'pulse does not count dead jobs'; end if;
    r := r || 'backoff + dead letter OK; ';

    -- guards
    if not public._fs_fails(format($q$update public.founder_anchor_jobs set state = 'queued' where id = %s$q$, v_tsa1)) then raise exception 'a finished job was reopened'; end if;
    if not public._fs_fails($q$delete from public.founder_anchor_jobs$q$) or not public._fs_fails($q$update public.founder_anchor_jobs set cp_id = cp_id + 1$q$) then raise exception 'jobs were deleted or re-pointed'; end if;
    if not public._fs_fails($q$update public.founder_anchor_evidence set evidence = '\x00'::bytea$q$) or not public._fs_fails($q$delete from public.founder_anchor_evidence$q$) or not public._fs_fails($q$truncate public.founder_anchor_evidence$q$) then raise exception 'evidence was changed'; end if;
    if not public._fs_fails($q$update public.founder_anchor_events set detail = 'x'$q$) or not public._fs_fails($q$delete from public.founder_anchor_events$q$) or not public._fs_fails($q$truncate public.founder_anchor_events$q$) then raise exception 'events were changed'; end if;
    if not public._fs_fails(format($q$insert into public.founder_anchor_evidence (job_id, cp_id, provider_id, version, stage, digest_hex, evidence, evidence_sha256, parsed, recorded_ms, prev_hash, hash)
        select %s, cp_id, provider_id, 9, 'tsa_token', %L, '\x00112233445566778899aabbccddeeff00112233'::bytea, repeat('0', 64), '{}'::jsonb, 1, repeat('0', 64), repeat('0', 64) from public.founder_anchor_jobs where id = %s$q$, v_tsa1, repeat('0', 64), v_tsa1)) then raise exception 'a forged digest went in'; end if;
    r := r || 'immutability + forged-digest OK; ';

    -- provider switch (audited) + verify + get
    j := public.founder_anchor_provider_set(v_uid, 'ots-bob', false, 'selftest switches a provider off');
    if (select enabled from public.founder_anchor_providers where name = 'ots-bob') then raise exception 'provider_set did not switch it off'; end if;
    if (select count(*) from public.founder_audit where action = 'anchor.provider') < 1 then raise exception 'provider_set was not audited'; end if;
    j := public.founder_anchor_verify(500);
    if not (j ->> 'ok')::boolean then raise exception 'verify failed on a good state: %', j; end if;
    j := public.founder_anchor_get(v_cpid);
    if not (j ->> 'found')::boolean or j ->> 'digest_hex' <> v_dig or j ->> 'level' <> 'strong' or jsonb_array_length(j -> 'evidence') < 3 or j ->> 'note' <> v_note then raise exception 'get is wrong: %', left(j::text, 300); end if;
    r := r || 'provider_set + verify + get OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E124 selftest FAIL: %', sqlerrm; end if;
  end;
  if (select count(*) from public.founder_anchor_jobs) <> b_jobs or (select count(*) from public.founder_anchor_evidence) <> b_evi or (select count(*) from public.founder_anchor_events) <> b_evt
     or (select count(*) from public.founder_audit) <> b_aud
     or (select md5(string_agg(id || ':' || enabled || ':' || coalesce(signer_pin, ''), ',' order by id)) from public.founder_anchor_providers) <> b_prov then raise exception 'E124 selftest left rows behind'; end if;
  return 'E124 selftest OK — ' || r || 'rollback clean';
end $$;

do $$ declare f text; begin
  foreach f in array array['public._fm_anchor_hash(text,bigint,bigint,text,text,text,bigint,integer)', 'public._fm_anchor_digest(bigint)', 'public._fm_anchor_event_guard()', 'public._fm_anchor_ev(text,bigint,integer,text)',
    'public._fm_anchor_job_guard()', 'public._fm_anchor_evidence_guard()', 'public.founder_anchor_level(bigint)', 'public.founder_anchor_enqueue()', 'public.founder_anchor_next(integer)',
    'public.founder_anchor_record_tsa(bigint,text,jsonb)', 'public.founder_anchor_record_ots(bigint,text,text,jsonb)', 'public.founder_anchor_fail(bigint,text,boolean)',
    'public.founder_anchor_provider_set(uuid,text,boolean,text)', 'public.founder_anchor_signer_accept(uuid,text,text,text)', 'public.founder_anchor_pulse()', 'public.founder_anchor_get(bigint)',
    'public.founder_anchor_verify(integer)', 'public.founder_anchor_e124_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

do $$ begin raise notice '%', public.founder_anchor_e124_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E124_founder_time_anchors CHECK_E124  (after fetch). Needs E102 + E107 + E120 + E122 + E123.
-- Undo (nothing else depends on it): drop the founder_anchor_* tables and functions; audit rows 'anchor.*' stay (the ledger never forgets).
