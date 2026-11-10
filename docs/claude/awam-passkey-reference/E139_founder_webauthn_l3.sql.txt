
-- E139 — J3: the WEBAUTHN LEVEL 3 BRAIN for the founder passkeys. SQL layer under the Rust module `passkey.rs` (J3) and the Privacy tab (J4).
-- Founder order 3 Nov 08:58: "duniya ki advance technology ... reasearch kero ... sql 900 lines ka jis main her baat cover ho jaye super advance". Quality law: SQL above super advanced.
-- TECHNOLOGY of this file: SQL (Supabase Postgres 16): constraints, triggers, immutable columns, append-only hash-chained ledgers, RLS, a risk decision door, selftest, CHECK file.
--   Research and decisions: docs/claude/FOUNDER-PASSKEY-J3-RESEARCH-03NOV.md (WebAuthn Level 3 became a W3C Recommendation on 25 Aug 2026).
--
-- What E117 + E118 already have (NOT repeated here): founder_passkeys, single-use ceremonies, step-up grants, recovery codes/requests, tiers T0-T3, the AAGUID allow-list,
--   the hardware rule, the T3 two-key window, the mobile flare, founder_action_hash. E117's founder_passkey_touch() knows ONE clone rule (counter did not go up => revoke).
--
-- What was still open (found by reading the repo and the Level 3 text):
--   a) nothing records WHAT a credential is: backup eligible (BE) / backup state (BS), AAGUID, COSE algorithm, attestation format and how far it was trusted, transports, PRF.
--      BE is fixed for life; if it ever changes, a different authenticator is answering. BS=1 with BE=0 is impossible. uv_initialized may never go back to false.
--   b) the clone rule treats a synced passkey (counter always 0, or shared by many devices) like a hardware key. Level 3 + field experience: enforce the counter only for
--      device-bound (BE=0) credentials with a non-zero counter; for synced credentials a regression is a RISK SIGNAL, never an automatic lock-out.
--   c) there is no decision door: allow / step up / deny with a number and the reasons, written to a ledger nobody can edit.
--   d) the FIDO Metadata Service (MDS) verdict on an AAGUID (compromised, revoked, bypass) has no home; unknown or stale metadata must be visible, not silent.
--   e) Level 3 Signal API: when a passkey is revoked the credential manager must be told (signalUnknownCredential / signalAllAcceptedCredentials) or it keeps offering a dead key.
--   f) Related Origin Requests: the allowed origins need ONE checked list, https only, at most 5 registrable labels (the Level 3 limit), never a wildcard.
--   g) post-quantum: ML-DSA COSE ids (-48/-49/-50) are still requested drafts. They must stay OFF by policy, and the report must say honestly how many credentials are post-quantum (0).
--
-- What this file adds (additive, idempotent; needs E102, E117, E118):
--   1) founder_webauthn_policy : singleton, read-only at runtime, cross-column CHECKs (rp id, origins, algorithms, thresholds, windows).
--   2) founder_webauthn_cred   : one facts row per passkey. BE, AAGUID, algorithm, registered time, owner are IMMUTABLE; BS may move; uv_initialized only up; counts only up; quarantine is one-way.
--   3) founder_webauthn_event  : APPEND-ONLY, hash-chained; the TRIGGER computes ts, prev_hash, hash; shape CHECK per kind (a denial can never be logged as 'allow').
--   4) founder_webauthn_mds    : APPEND-ONLY versioned FIDO MDS statuses per AAGUID (blob numbers only go up); freshness is computed, never assumed.
--   5) founder_webauthn_signal : the Signal API queue for the browser (accepted credentials, unknown credential), superseded when stale, acknowledged once.
--   6) founder_webauthn_origin_ok(), founder_webauthn_register(), founder_webauthn_assert(), founder_webauthn_fail(): the doors Rust calls after it verified the signature.
--   7) founder_mds_ingest(), founder_webauthn_signal_next/ack(), founder_webauthn_pq_report(), founder_webauthn_status(), founder_webauthn_verify(), selftest + CHECK_E139.
--
-- Honest limits: SQL cannot verify a signature or an attestation chain (Rust does, with ring); it stores the verified facts and decides on them. A cloned SYNCED passkey cannot be
-- detected by any counter; the defence is the hardware-only rule of E118 (T2/T3). Signal API calls run in the browser; the server only queues them.

set lock_timeout = '10s';
set statement_timeout = '120s';

do $$ begin
  if to_regclass('public.founder_passkeys') is null or to_regclass('public.founder_aaguid_allow') is null or to_regprocedure('public.founder_action_hash(text,text,jsonb,text)') is null then
    raise exception 'E139 needs E117 and E118 first (founder_passkeys, founder_aaguid_allow, founder_action_hash)';
  end if;
  if to_regprocedure('public.founder_audit_append(uuid,text,text,text,jsonb)') is null or to_regprocedure('public._fs_fails(text)') is null then
    raise exception 'E139 needs E102 (audit append) and E113 (_fs_fails) first';
  end if;
end $$;

-- helpers --------------------------------------------------------------------------------------------------------------------------------------
create or replace function public._fw_now_ms() returns bigint language sql volatile set search_path = pg_catalog as $$
  select (extract(epoch from clock_timestamp()) * 1000)::bigint
$$;
create or replace function public._fw_aaguid_ok(p text) returns boolean language sql immutable parallel safe set search_path = pg_catalog as $$
  select p is not null and p ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
$$;
create or replace function public._fw_cred_id_ok(p text) returns boolean language sql immutable parallel safe set search_path = pg_catalog as $$
  select p is not null and p ~ '^[A-Za-z0-9_-]{16,255}$'
$$;
-- an origin is https://host[:port], lower case, no path, no wildcard, no userinfo; localhost and IP literals are refused (a founder passkey never lives there)
create or replace function public._fw_origin_shape_ok(p text) returns boolean language sql immutable parallel safe set search_path = pg_catalog as $$
  select p is not null and length(p) <= 253 and p ~ '^https://[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+(:[0-9]{2,5})?$' and p !~ '^https://[0-9.]+(:[0-9]+)?$'
$$;
-- the registrable label of an origin (the last two labels; the Level 3 limit of 5 counts these)
create or replace function public._fw_label_of(p_origin text) returns text language sql immutable parallel safe set search_path = pg_catalog as $$
  select substring(regexp_replace(substring(p_origin from '^https://([^/:]+)'), '^.*\.([^.]+\.[^.]+)$', '\1') from 1)
$$;
create or replace function public._fw_origins_ok(p_origins text[], p_rp text) returns boolean language plpgsql immutable set search_path = pg_catalog, public as $$
declare o text; labels text[] := '{}'; l text;
begin
  if p_origins is null or cardinality(p_origins) not between 1 and 6 then return false; end if;
  if (select count(*) <> count(distinct x) from unnest(p_origins) x) then return false; end if;
  foreach o in array p_origins loop
    if not public._fw_origin_shape_ok(o) then return false; end if;
    l := public._fw_label_of(o);
    if not (l = any (labels)) then labels := labels || l; end if;
  end loop;
  if cardinality(labels) > 5 then return false; end if;                                   -- Level 3 Related Origin Requests: at most 5 labels
  return exists (select 1 from unnest(p_origins) x where x = 'https://' || p_rp);        -- the RP's own origin must be in the list
end $$;

-- 1) policy ------------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:ddl', 0));
  create table if not exists public.founder_webauthn_policy (
    id               boolean primary key default true check (id),
    rp_id            text    not null default 'founderworkspace.anexomail.com' check (rp_id ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
    origins          text[]  not null default array['https://founderworkspace.anexomail.com'],
    challenge_secs   integer not null default 120 check (challenge_secs between 30 and 300),     -- never longer than the ceremony window of E117 (5 minutes)
    require_uv       boolean not null default true check (require_uv),                            -- user verification can never be switched off
    allowed_algs     integer[] not null default array[-7, -8] check (cardinality(allowed_algs) between 1 and 3 and allowed_algs <@ array[-7, -8, -257]),  -- ES256, EdDSA (RS256 only if listed on purpose)
    pq_algs          integer[] not null default '{}' check (pq_algs <@ array[-48, -49, -50]),     -- ML-DSA-44/65/87: requested ids, OFF until final
    attestation_pref text    not null default 'direct' check (attestation_pref in ('none', 'indirect', 'direct', 'enterprise')),
    mds_deny         text[]  not null default array['REVOKED', 'USER_VERIFICATION_BYPASS', 'ATTESTATION_KEY_COMPROMISE', 'USER_KEY_REMOTE_COMPROMISE', 'USER_KEY_PHYSICAL_COMPROMISE'],
    mds_stale_secs   integer not null default 604800 check (mds_stale_secs between 3600 and 2592000),
    velocity_per_min integer not null default 12 check (velocity_per_min between 2 and 120),
    fail_burst       integer not null default 5  check (fail_burst between 2 and 50),
    fail_window_secs integer not null default 300 check (fail_window_secs between 30 and 3600),
    stepup_at        integer not null default 40 check (stepup_at between 1 and 99),
    deny_at          integer not null default 80 check (deny_at between 2 and 100),
    signal_ttl_secs  integer not null default 604800 check (signal_ttl_secs between 3600 and 2592000),
    constraint founder_webauthn_policy_risk    check (stepup_at < deny_at),                       -- there is always a step-up band before a denial
    constraint founder_webauthn_policy_origins check (public._fw_origins_ok(origins, rp_id)),
    constraint founder_webauthn_policy_algs    check (not (pq_algs && allowed_algs))
  );
  insert into public.founder_webauthn_policy (id) values (true) on conflict (id) do nothing;
  alter table public.founder_webauthn_policy enable row level security;
  revoke all on public.founder_webauthn_policy from public, anon, authenticated;
  grant select on public.founder_webauthn_policy to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_webauthn_policy from service_role;
end $$;

create or replace function public._fw_policy_guard() returns trigger language plpgsql as $$
begin
  if coalesce(current_setting('app.webauthn_policy_edit', true), '') = 'on' and tg_op <> 'TRUNCATE' then return coalesce(new, old); end if;
  raise exception 'E139: the WebAuthn policy is read-only at runtime' using errcode = '42501';
end $$;
drop trigger if exists founder_webauthn_policy_guard on public.founder_webauthn_policy;
create trigger founder_webauthn_policy_guard before update or delete on public.founder_webauthn_policy for each row execute function public._fw_policy_guard();
drop trigger if exists founder_webauthn_policy_guard_trunc on public.founder_webauthn_policy;
create trigger founder_webauthn_policy_guard_trunc before truncate on public.founder_webauthn_policy for each statement execute function public._fw_policy_guard();

-- 2) per-credential facts ----------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:ddl', 0));
  create table if not exists public.founder_webauthn_cred (
    credential_id     text primary key references public.founder_passkeys (credential_id) on delete cascade,
    user_id           uuid    not null,
    aaguid            text    not null check (public._fw_aaguid_ok(aaguid)),                       -- all zeros = "not disclosed" (attestation none)
    cose_alg          integer not null check (cose_alg in (-7, -8, -257, -48, -49, -50)),
    pk_bytes          integer not null check (pk_bytes between 32 and 4000),                       -- ES256 77, Ed25519 ~44, ML-DSA-65 1952
    attestation_fmt   text    not null check (attestation_fmt in ('none', 'packed', 'tpm', 'android-key', 'android-safetynet', 'fido-u2f', 'apple', 'compound')),
    attestation_trust text    not null check (attestation_trust in ('none', 'self', 'basic', 'mds3')),
    transports        text[]  not null default '{}' check (transports <@ array['usb', 'nfc', 'ble', 'internal', 'hybrid', 'smart-card']),
    attachment        text    check (attachment in ('platform', 'cross-platform')),
    discoverable      boolean not null,
    be                boolean not null,                                                            -- backup eligible: fixed at creation
    bs                boolean not null,                                                            -- backup state: may change
    uv_initialized    boolean not null default true,
    prf_enabled       boolean not null default false,
    large_blob        boolean not null default false,
    registered_ms     bigint  not null check (registered_ms > 0),
    last_assert_ms    bigint  check (last_assert_ms is null or last_assert_ms >= registered_ms),
    assertions        bigint  not null default 0 check (assertions >= 0),
    quarantined_ms    bigint  check (quarantined_ms is null or quarantined_ms >= registered_ms),
    quarantine_why    text    check (quarantine_why is null or length(quarantine_why) between 8 and 300),
    constraint founder_webauthn_cred_backup check (be or not bs),                                  -- BS=1 needs BE=1 (WebAuthn Level 3, authenticator data flags)
    constraint founder_webauthn_cred_quarantine check ((quarantined_ms is null) = (quarantine_why is null)),
    constraint founder_webauthn_cred_zero_aaguid check (aaguid <> '00000000-0000-0000-0000-000000000000' or attestation_trust in ('none', 'self')),
    constraint founder_webauthn_cred_assert_pair check ((assertions = 0) = (last_assert_ms is null))
  );
  create index if not exists founder_webauthn_cred_user on public.founder_webauthn_cred (user_id);
  create index if not exists founder_webauthn_cred_aaguid on public.founder_webauthn_cred (aaguid);
  alter table public.founder_webauthn_cred enable row level security;
  revoke all on public.founder_webauthn_cred from public, anon, authenticated;
  grant select on public.founder_webauthn_cred to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_webauthn_cred from service_role;   -- only the definer doors can write
end $$;

-- the owner of the facts is the owner of the passkey; immutable columns never move; counters only go up; quarantine is one-way
create or replace function public._fw_cred_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare pk public.founder_passkeys%rowtype;
begin
  if tg_op = 'INSERT' then
    select * into pk from public.founder_passkeys where credential_id = new.credential_id;
    if not found or pk.user_id <> new.user_id then raise exception 'E139: the facts must belong to the passkey owner' using errcode = '42501'; end if;
    if pk.aaguid is not null and pk.aaguid <> new.aaguid then raise exception 'E139: the AAGUID disagrees with the one stored with the passkey' using errcode = '23514'; end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 then return old; end if;                                                -- only the cascade from a deleted passkey
    raise exception 'E139: credential facts cannot be deleted' using errcode = '42501';
  end if;
  if new.credential_id <> old.credential_id or new.user_id <> old.user_id or new.aaguid <> old.aaguid or new.cose_alg <> old.cose_alg or new.pk_bytes <> old.pk_bytes
     or new.be <> old.be or new.registered_ms <> old.registered_ms or new.attestation_fmt <> old.attestation_fmt or new.discoverable <> old.discoverable then
    raise exception 'E139: BE, AAGUID, algorithm, key size, owner and registration time are fixed for life' using errcode = '42501';
  end if;
  if old.uv_initialized and not new.uv_initialized then raise exception 'E139: uv_initialized can never go back to false' using errcode = '42501'; end if;
  if new.assertions < old.assertions or coalesce(new.last_assert_ms, 0) < coalesce(old.last_assert_ms, 0) then raise exception 'E139: counts and times only go up' using errcode = '42501'; end if;
  if old.quarantined_ms is not null and (new.quarantined_ms is distinct from old.quarantined_ms or new.quarantine_why is distinct from old.quarantine_why) then
    raise exception 'E139: a quarantined credential stays quarantined' using errcode = '42501'; end if;
  if (old.attestation_trust = 'mds3' and new.attestation_trust <> 'mds3') or (old.prf_enabled and not new.prf_enabled) then raise exception 'E139: trust and PRF capability cannot be taken back by an update' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_webauthn_cred_guard on public.founder_webauthn_cred;
create trigger founder_webauthn_cred_guard before insert or update or delete on public.founder_webauthn_cred for each row execute function public._fw_cred_guard();
drop trigger if exists founder_webauthn_cred_guard_trunc on public.founder_webauthn_cred;
create trigger founder_webauthn_cred_guard_trunc before truncate on public.founder_webauthn_cred for each statement execute function public._fw_policy_guard();

-- 3) the event ledger (append-only, hash-chained, computed by the trigger) ---------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:ddl', 0));
  create table if not exists public.founder_webauthn_event (
    id            bigint generated always as identity primary key,
    ts_ms         bigint  not null check (ts_ms > 0),
    user_id       uuid    not null,                                                               -- no foreign key: deleting an account must never rewrite or block a ledger
    credential_id text    check (credential_id is null or public._fw_cred_id_ok(credential_id)),
    kind          text    not null check (kind in ('registered', 'assert_ok', 'assert_fail', 'stepup_required', 'denied', 'signcount_regression', 'be_changed', 'bs_changed', 'aaguid_changed',
                                                   'mds_denied', 'origin_refused', 'velocity', 'fail_burst', 'quarantined', 'signal_queued', 'signal_acked', 'mds_ingested', 'policy_note')),
    decision      text    not null check (decision in ('allow', 'stepup', 'deny', 'info')),
    risk          integer not null check (risk between 0 and 100),
    reason        text    check (reason is null or length(reason) between 3 and 300),
    facts         jsonb   not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 2000),
    prev_hash     text    not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash          text    not null unique check (hash ~ '^[0-9a-f]{64}$'),
    -- the shape of every kind is a database fact, not a Rust habit
    constraint founder_webauthn_event_shape check (
         (kind in ('denied', 'be_changed', 'aaguid_changed', 'mds_denied', 'origin_refused', 'quarantined') and decision = 'deny' and risk >= 80 and reason is not null)
      or (kind = 'assert_ok' and decision = 'allow' and risk < 40)
      or (kind = 'stepup_required' and decision = 'stepup' and risk >= 40 and reason is not null)
      or (kind in ('registered', 'bs_changed', 'signal_queued', 'signal_acked', 'mds_ingested', 'policy_note', 'assert_fail', 'signcount_regression', 'velocity', 'fail_burst') and decision in ('info', 'deny', 'stepup', 'allow'))),
    constraint founder_webauthn_event_cred check (credential_id is not null or kind in ('assert_fail', 'origin_refused', 'denied', 'fail_burst', 'mds_ingested', 'policy_note', 'signal_queued', 'signal_acked'))
  );
  create index if not exists founder_webauthn_event_cred_ts on public.founder_webauthn_event (credential_id, ts_ms desc);
  create index if not exists founder_webauthn_event_user_ts on public.founder_webauthn_event (user_id, ts_ms desc);
  alter table public.founder_webauthn_event enable row level security;
  revoke all on public.founder_webauthn_event from public, anon, authenticated;
  grant select, insert on public.founder_webauthn_event to service_role;
  revoke update, delete, truncate, references, trigger on public.founder_webauthn_event from service_role;
end $$;

create or replace function public._fw_event_hash(p_prev text, p_ts bigint, p_uid uuid, p_cred text, p_kind text, p_dec text, p_risk integer, p_reason text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_uid::text || '|' || coalesce(p_cred, '-') || '|' || p_kind || '|' || p_dec || '|' || p_risk
         || '|' || coalesce(p_reason, '-') || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
-- The trigger FILLS ts, prev_hash and hash: the caller names only the facts.
create or replace function public._fw_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_webauthn_event%rowtype;
begin
  if tg_op <> 'INSERT' then raise exception 'E139: the event ledger is append-only' using errcode = '42501'; end if;
  select * into p from public.founder_webauthn_event order by id desc limit 1;
  new.ts_ms     := public._fw_now_ms();
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._fw_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.credential_id, new.kind, new.decision, new.risk, new.reason, new.facts);
  return new;
end $$;
create or replace function public._fw_stop() returns trigger language plpgsql as $$ begin raise exception 'E139: this ledger is append-only' using errcode = '42501'; end $$;
drop trigger if exists founder_webauthn_event_guard on public.founder_webauthn_event;
create trigger founder_webauthn_event_guard before insert on public.founder_webauthn_event for each row execute function public._fw_event_guard();
drop trigger if exists founder_webauthn_event_stop on public.founder_webauthn_event;
create trigger founder_webauthn_event_stop before update or delete on public.founder_webauthn_event for each row execute function public._fw_stop();
drop trigger if exists founder_webauthn_event_stop_trunc on public.founder_webauthn_event;
create trigger founder_webauthn_event_stop_trunc before truncate on public.founder_webauthn_event for each statement execute function public._fw_stop();

-- the single place that writes an event (so every door writes the same way)
create or replace function public._fw_log(p_uid uuid, p_cred text, p_kind text, p_dec text, p_risk integer, p_reason text, p_facts jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id bigint;
begin
  insert into public.founder_webauthn_event (ts_ms, user_id, credential_id, kind, decision, risk, reason, facts, prev_hash, hash)
  values (1, p_uid, p_cred, p_kind, p_dec, least(greatest(p_risk, 0), 100), p_reason, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64)) returning id into v_id;
  return v_id;
end $$;

-- 4) FIDO MDS statuses (append-only, versioned by blob number) ---------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:ddl', 0));
  create table if not exists public.founder_webauthn_mds (
    id          bigint generated always as identity primary key,
    aaguid      text    not null check (public._fw_aaguid_ok(aaguid)),
    blob_no     integer not null check (blob_no >= 1),
    status      text    not null check (status in ('NOT_FIDO_CERTIFIED', 'SELF_ASSERTION_SUBMITTED', 'FIDO_CERTIFIED', 'FIDO_CERTIFIED_L1', 'FIDO_CERTIFIED_L1plus', 'FIDO_CERTIFIED_L2',
                                                    'FIDO_CERTIFIED_L2plus', 'FIDO_CERTIFIED_L3', 'FIDO_CERTIFIED_L3plus', 'UPDATE_AVAILABLE', 'REVOKED', 'USER_VERIFICATION_BYPASS',
                                                    'ATTESTATION_KEY_COMPROMISE', 'USER_KEY_REMOTE_COMPROMISE', 'USER_KEY_PHYSICAL_COMPROMISE')),
    status_date date    not null,
    description text    check (description is null or length(description) between 1 and 200),
    fetched_ms  bigint  not null check (fetched_ms > 0),
    entry_sha   text    not null check (entry_sha ~ '^[0-9a-f]{64}$'),
    constraint founder_webauthn_mds_once unique (aaguid, blob_no)
  );
  create index if not exists founder_webauthn_mds_latest on public.founder_webauthn_mds (aaguid, blob_no desc);
  alter table public.founder_webauthn_mds enable row level security;
  revoke all on public.founder_webauthn_mds from public, anon, authenticated;
  grant select on public.founder_webauthn_mds to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_webauthn_mds from service_role;
end $$;
drop trigger if exists founder_webauthn_mds_stop on public.founder_webauthn_mds;
create trigger founder_webauthn_mds_stop before update or delete on public.founder_webauthn_mds for each row execute function public._fw_stop();
drop trigger if exists founder_webauthn_mds_stop_trunc on public.founder_webauthn_mds;
create trigger founder_webauthn_mds_stop_trunc before truncate on public.founder_webauthn_mds for each statement execute function public._fw_stop();

-- 5) the Signal API queue ----------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:ddl', 0));
  create table if not exists public.founder_webauthn_signal (
    id            uuid primary key default gen_random_uuid(),
    user_id       uuid    not null references public.founder_accounts (user_id) on delete cascade,
    kind          text    not null check (kind in ('all_accepted', 'unknown_credential')),
    payload       jsonb   not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 4000),
    created_ms    bigint  not null check (created_ms > 0),
    expires_ms    bigint  not null,
    acked_ms      bigint,
    superseded_ms bigint,
    constraint founder_webauthn_signal_window check (expires_ms > created_ms),
    constraint founder_webauthn_signal_once   check (acked_ms is null or superseded_ms is null),
    constraint founder_webauthn_signal_shape  check (
         (kind = 'all_accepted'       and payload ? 'rpId' and payload ? 'credentialIds' and payload ? 'userId' and jsonb_typeof(payload -> 'credentialIds') = 'array')
      or (kind = 'unknown_credential' and payload ? 'rpId' and payload ? 'credentialId'))
  );
  create index if not exists founder_webauthn_signal_open on public.founder_webauthn_signal (user_id, created_ms) where acked_ms is null and superseded_ms is null;
  alter table public.founder_webauthn_signal enable row level security;
  revoke all on public.founder_webauthn_signal from public, anon, authenticated;
  grant select on public.founder_webauthn_signal to service_role;
  revoke insert, update, delete, truncate, references, trigger on public.founder_webauthn_signal from service_role;
end $$;
create or replace function public._fw_signal_guard() returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    if pg_trigger_depth() > 1 then return old; end if;                                                -- only the cascade from a deleted account
    raise exception 'E139: signals are never deleted' using errcode = '42501';
  end if;
  if tg_op = 'UPDATE' and (new.id <> old.id or new.user_id <> old.user_id or new.kind <> old.kind or new.payload <> old.payload or new.created_ms <> old.created_ms or new.expires_ms <> old.expires_ms
     or (old.acked_ms is not null and new.acked_ms is distinct from old.acked_ms) or (old.superseded_ms is not null and new.superseded_ms is distinct from old.superseded_ms)) then
    raise exception 'E139: a signal can only be acknowledged or superseded, once' using errcode = '42501'; end if;
  return coalesce(new, old);
end $$;
drop trigger if exists founder_webauthn_signal_guard on public.founder_webauthn_signal;
create trigger founder_webauthn_signal_guard before update or delete on public.founder_webauthn_signal for each row execute function public._fw_signal_guard();
drop trigger if exists founder_webauthn_signal_guard_trunc on public.founder_webauthn_signal;
create trigger founder_webauthn_signal_guard_trunc before truncate on public.founder_webauthn_signal for each statement execute function public._fw_stop();

-- queue a signal; a newer 'all_accepted' supersedes every older open one (the browser only needs the latest truth)
create or replace function public._fw_signal_enqueue(p_uid uuid, p_kind text, p_payload jsonb) returns uuid
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id uuid; v_now bigint := public._fw_now_ms(); v_ttl integer;
begin
  select signal_ttl_secs into v_ttl from public.founder_webauthn_policy where id;
  if p_kind = 'all_accepted' then
    update public.founder_webauthn_signal set superseded_ms = v_now where user_id = p_uid and kind = 'all_accepted' and acked_ms is null and superseded_ms is null;
  end if;
  insert into public.founder_webauthn_signal (user_id, kind, payload, created_ms, expires_ms) values (p_uid, p_kind, p_payload, v_now, v_now + v_ttl * 1000::bigint) returning id into v_id;
  perform public._fw_log(p_uid, null, 'signal_queued', 'info', 0, 'queued ' || p_kind, jsonb_build_object('signal', v_id));
  return v_id;
end $$;

-- the accepted list: every ACTIVE passkey id of the owner (what the credential manager may keep)
create or replace function public._fw_accepted_payload(p_uid uuid) returns jsonb language sql stable set search_path = pg_catalog, public as $$
  select jsonb_build_object('rpId', (select rp_id from public.founder_webauthn_policy where id), 'userId', encode(convert_to(p_uid::text, 'UTF8'), 'base64'),
         'credentialIds', coalesce((select jsonb_agg(credential_id order by created_at) from public.founder_passkeys where user_id = p_uid and revoked_at is null), '[]'::jsonb))
$$;
-- additive trigger on E117's table: a new passkey or a revoked one queues the Level 3 signals (E117/E118 code is untouched)
create or replace function public._fw_passkey_signals() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  if tg_op = 'INSERT' then
    perform public._fw_signal_enqueue(new.user_id, 'all_accepted', public._fw_accepted_payload(new.user_id));
  elsif tg_op = 'UPDATE' and old.revoked_at is null and new.revoked_at is not null then
    perform public._fw_signal_enqueue(new.user_id, 'unknown_credential', jsonb_build_object('rpId', (select rp_id from public.founder_webauthn_policy where id), 'credentialId', new.credential_id));
    perform public._fw_signal_enqueue(new.user_id, 'all_accepted', public._fw_accepted_payload(new.user_id));
  end if;
  return new;
end $$;
drop trigger if exists founder_webauthn_passkey_signals on public.founder_passkeys;
create trigger founder_webauthn_passkey_signals after insert or update of revoked_at on public.founder_passkeys for each row execute function public._fw_passkey_signals();

-- 6) read helpers --------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_webauthn_origin_ok(p_origin text) returns boolean language sql stable set search_path = pg_catalog, public as $$
  select p_origin is not null and public._fw_origin_shape_ok(p_origin) and exists (select 1 from public.founder_webauthn_policy where id and p_origin = any (origins))
$$;

-- the trust state of an AAGUID: none (all zeros: not disclosed) | denied | ok | unknown (no MDS row) | stale (the whole MDS copy is older than the policy allows)
create or replace function public._fw_mds_state(p_aaguid text, p_now bigint default null) returns text
language plpgsql stable set search_path = pg_catalog, public as $$
declare v_now bigint := coalesce(p_now, public._fw_now_ms()); m public.founder_webauthn_mds%rowtype; pol public.founder_webauthn_policy%rowtype; v_last bigint;
begin
  if p_aaguid = '00000000-0000-0000-0000-000000000000' then return 'none'; end if;
  select * into pol from public.founder_webauthn_policy where id;
  select * into m from public.founder_webauthn_mds where aaguid = p_aaguid order by blob_no desc limit 1;
  if not found then return 'unknown'; end if;
  if m.status = any (pol.mds_deny) then return 'denied'; end if;                         -- a compromised status is acted on even if the copy is old
  select max(fetched_ms) into v_last from public.founder_webauthn_mds;
  if v_now - v_last > pol.mds_stale_secs * 1000::bigint then return 'stale'; end if;
  return 'ok';
end $$;

-- ONE way to say no: log it, return the same shape every time
create or replace function public._fw_deny(p_uid uuid, p_cred text, p_kind text, p_risk integer, p_reason text, p_facts jsonb default '{}'::jsonb) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fw_log(p_uid, case when public._fw_cred_id_ok(p_cred) then p_cred else null end, p_kind, 'deny', greatest(p_risk, 80), p_reason, p_facts);
  return jsonb_build_object('ok', false, 'decision', 'deny', 'risk', greatest(p_risk, 80), 'kind', p_kind, 'reasons', jsonb_build_array(p_reason));
end $$;

-- 7) register: Rust verified the attestation and the signature; SQL checks the FACTS against the policy and stores them for life ---------------------
create or replace function public.founder_webauthn_register(p_uid uuid, p_credential_id text, p_facts jsonb) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare pol public.founder_webauthn_policy%rowtype; pk public.founder_passkeys%rowtype; f jsonb := p_facts; v_alg integer; v_aag text; v_trust text; v_be boolean; v_bs boolean; v_uv boolean;
        v_tr text[]; v_mds text; v_now bigint := public._fw_now_ms();
begin
  perform public._fs_assert_founder(p_uid);
  if not public._fw_cred_id_ok(p_credential_id) then raise exception 'bad credential id' using errcode = '22023'; end if;
  if f is null or jsonb_typeof(f) <> 'object' or octet_length(f::text) > 4000 then raise exception 'facts must be a small object' using errcode = '22023'; end if;
  select * into pol from public.founder_webauthn_policy where id;
  select * into pk from public.founder_passkeys where credential_id = p_credential_id and user_id = p_uid and revoked_at is null;
  if not found then return jsonb_build_object('ok', false, 'why', 'no active passkey with this id for this account'); end if;
  if exists (select 1 from public.founder_webauthn_cred where credential_id = p_credential_id) then return jsonb_build_object('ok', false, 'why', 'facts for this credential already exist (they are fixed for life)'); end if;
  if not public.founder_webauthn_origin_ok(f ->> 'origin') or f ->> 'rp_id' is distinct from pol.rp_id then
    return public._fw_deny(p_uid, p_credential_id, 'origin_refused', 100, 'registration came from an origin or relying party that the policy does not list', jsonb_build_object('origin', left(coalesce(f ->> 'origin', ''), 120)));
  end if;
  v_alg := (f ->> 'cose_alg')::integer; v_aag := lower(f ->> 'aaguid'); v_trust := f ->> 'attestation_trust'; v_be := (f ->> 'be')::boolean; v_bs := (f ->> 'bs')::boolean; v_uv := coalesce((f ->> 'uv_initialized')::boolean, false);
  v_tr := coalesce((select array_agg(x) from jsonb_array_elements_text(coalesce(f -> 'transports', '[]'::jsonb)) x), '{}');
  if v_alg is null or not (v_alg = any (pol.allowed_algs) or v_alg = any (pol.pq_algs)) then
    return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'the key algorithm ' || coalesce(v_alg::text, '?') || ' is not allowed by the policy (post-quantum ids stay off until final)');
  end if;
  if not public._fw_aaguid_ok(v_aag) or v_be is null or v_bs is null then raise exception 'facts need aaguid, be and bs' using errcode = '22023'; end if;
  if v_bs and not v_be then return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'backup state is set but the credential is not backup eligible: impossible flags'); end if;
  if pol.require_uv and not v_uv then return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'user verification was not performed at registration'); end if;
  v_mds := public._fw_mds_state(v_aag, v_now);
  if v_mds = 'denied' then return public._fw_deny(p_uid, p_credential_id, 'mds_denied', 100, 'the FIDO Metadata Service lists this authenticator model as compromised or revoked', jsonb_build_object('aaguid', v_aag)); end if;
  if v_trust = 'mds3' and v_mds not in ('ok', 'stale') then return public._fw_deny(p_uid, p_credential_id, 'denied', 85, 'attestation says it was trusted through MDS but this server has no MDS entry for the model', jsonb_build_object('aaguid', v_aag)); end if;
  insert into public.founder_webauthn_cred (credential_id, user_id, aaguid, cose_alg, pk_bytes, attestation_fmt, attestation_trust, transports, attachment, discoverable, be, bs, uv_initialized, prf_enabled, large_blob, registered_ms)
  values (p_credential_id, p_uid, v_aag, v_alg, (f ->> 'pk_bytes')::integer, f ->> 'attestation_fmt', v_trust, v_tr, f ->> 'attachment', (f ->> 'discoverable')::boolean, v_be, v_bs, v_uv,
          coalesce((f ->> 'prf_enabled')::boolean, false), coalesce((f ->> 'large_blob')::boolean, false), v_now);
  perform public._fw_log(p_uid, p_credential_id, 'registered', 'info', case when v_mds in ('unknown', 'stale') then 10 else 0 end, 'credential facts stored',
                         jsonb_build_object('alg', v_alg, 'aaguid', v_aag, 'be', v_be, 'bs', v_bs, 'trust', v_trust, 'fmt', f ->> 'attestation_fmt', 'mds', v_mds));
  return jsonb_build_object('ok', true, 'synced', v_be, 'device_bound', not v_be, 'mds', v_mds, 'pq', v_alg in (-48, -49, -50));
end $$;

-- 8) assert: Rust verified the signature; SQL decides allow / step up / deny from the FACTS and writes why -------------------------------------------
create or replace function public.founder_webauthn_assert(p_uid uuid, p_credential_id text, p_in jsonb) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare pol public.founder_webauthn_policy%rowtype; pk public.founder_passkeys%rowtype; c public.founder_webauthn_cred%rowtype; v_now bigint := public._fw_now_ms();
        v_sc bigint; v_be boolean; v_bs boolean; v_risk integer := 0; v_reasons text[] := '{}'; v_mds text; v_recent integer; v_fails integer; v_dec text; v_aag text; v_kind text;
begin
  perform public._fs_assert_founder(p_uid);
  if p_in is null or jsonb_typeof(p_in) <> 'object' or not (p_in ? 'sign_count' and p_in ? 'up' and p_in ? 'uv' and p_in ? 'be' and p_in ? 'bs' and p_in ? 'origin' and p_in ? 'rp_id') then
    raise exception 'assertion facts are incomplete' using errcode = '22023'; end if;
  v_sc := (p_in ->> 'sign_count')::bigint; v_be := (p_in ->> 'be')::boolean; v_bs := (p_in ->> 'bs')::boolean;
  if v_sc is null or v_sc < 0 or v_sc > 4294967295 then raise exception 'bad signature counter' using errcode = '22023'; end if;
  select * into pol from public.founder_webauthn_policy where id;
  if not public.founder_webauthn_origin_ok(p_in ->> 'origin') or p_in ->> 'rp_id' is distinct from pol.rp_id then
    return public._fw_deny(p_uid, p_credential_id, 'origin_refused', 100, 'assertion came from an origin or relying party that the policy does not list', jsonb_build_object('origin', left(coalesce(p_in ->> 'origin', ''), 120)));
  end if;
  select * into pk from public.founder_passkeys where credential_id = p_credential_id and user_id = p_uid;
  select * into c from public.founder_webauthn_cred where credential_id = p_credential_id and user_id = p_uid;
  if pk.id is null or c.credential_id is null then return public._fw_deny(p_uid, p_credential_id, 'denied', 100, 'unknown credential: no facts were registered for it'); end if;
  if pk.revoked_at is not null then return public._fw_deny(p_uid, p_credential_id, 'denied', 100, 'this passkey was revoked'); end if;
  if c.quarantined_ms is not null then return public._fw_deny(p_uid, p_credential_id, 'denied', 100, 'this credential is quarantined: ' || c.quarantine_why); end if;
  if (p_in ->> 'up')::boolean is not true then return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'user presence flag is not set'); end if;
  if pol.require_uv and (p_in ->> 'uv')::boolean is not true then return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'user verification flag is not set'); end if;
  -- BE is permanent: a change means another authenticator answers. Quarantine (one way) so a human decides.
  if v_be is distinct from c.be then
    update public.founder_webauthn_cred set quarantined_ms = v_now, quarantine_why = 'backup-eligible flag changed: a different authenticator answered' where credential_id = c.credential_id;
    perform public.founder_audit_append(p_uid, 'passkey.be_changed', left(p_credential_id, 12), 'credential quarantined: the backup-eligible flag changed', jsonb_build_object('was', c.be, 'got', v_be));
    return public._fw_deny(p_uid, p_credential_id, 'be_changed', 100, 'the backup-eligible flag changed (was ' || c.be || ', now ' || coalesce(v_be::text, 'null') || '): credential quarantined');
  end if;
  if v_bs and not v_be then return public._fw_deny(p_uid, p_credential_id, 'denied', 90, 'backup state is set but the credential is not backup eligible: impossible flags'); end if;
  v_aag := lower(p_in ->> 'aaguid');
  if v_aag is not null and v_aag <> c.aaguid then
    update public.founder_webauthn_cred set quarantined_ms = v_now, quarantine_why = 'AAGUID changed: a different authenticator model answered' where credential_id = c.credential_id;
    perform public.founder_audit_append(p_uid, 'passkey.aaguid_changed', left(p_credential_id, 12), 'credential quarantined: the AAGUID changed', '{}'::jsonb);
    return public._fw_deny(p_uid, p_credential_id, 'aaguid_changed', 100, 'the authenticator model (AAGUID) changed: credential quarantined');
  end if;
  v_mds := public._fw_mds_state(c.aaguid, v_now);
  if v_mds = 'denied' then return public._fw_deny(p_uid, p_credential_id, 'mds_denied', 100, 'the FIDO Metadata Service now lists this authenticator model as compromised or revoked', jsonb_build_object('aaguid', c.aaguid)); end if;
  if v_mds in ('unknown', 'stale') then v_risk := v_risk + 10; v_reasons := v_reasons || ('metadata ' || v_mds)::text; end if;
  -- the counter: enforced only where it means something (device-bound, non-zero). For a synced credential it is a risk signal, never a lock-out.
  if pk.sign_count > 0 and v_sc <= pk.sign_count then
    if not c.be then
      update public.founder_webauthn_cred set quarantined_ms = v_now, quarantine_why = 'clone suspected: the signature counter did not increase' where credential_id = c.credential_id;
      update public.founder_passkeys set revoked_at = now(), revoked_reason = 'clone suspected: the counter did not increase' where id = pk.id and revoked_at is null;
      perform public.founder_audit_append(p_uid, 'passkey.clone', left(p_credential_id, 12), 'passkey revoked: the signature counter did not increase', jsonb_build_object('was', pk.sign_count, 'got', v_sc));
      return public._fw_deny(p_uid, p_credential_id, 'quarantined', 100, 'device-bound credential: the signature counter did not increase (was ' || pk.sign_count || ', got ' || v_sc || '): revoked and quarantined', jsonb_build_object('was', pk.sign_count, 'got', v_sc));
    end if;
    v_risk := v_risk + 35; v_reasons := v_reasons || 'counter of a synced credential did not increase'::text;
    perform public._fw_log(p_uid, p_credential_id, 'signcount_regression', 'info', 35, 'synced credential: counter did not increase (a risk signal only)', jsonb_build_object('was', pk.sign_count, 'got', v_sc));
  end if;
  if v_bs is distinct from c.bs then
    v_risk := v_risk + 5; v_reasons := v_reasons || 'backup state changed'::text;
    perform public._fw_log(p_uid, p_credential_id, 'bs_changed', 'info', 5, 'backup state ' || c.bs || ' to ' || v_bs, '{}'::jsonb);
  end if;
  select count(*) into v_recent from public.founder_webauthn_event where credential_id = p_credential_id and kind in ('assert_ok', 'stepup_required') and ts_ms > v_now - 60000;
  if v_recent >= pol.velocity_per_min then
    v_risk := v_risk + 30; v_reasons := v_reasons || 'too many sign-ins in a minute'::text;
    perform public._fw_log(p_uid, p_credential_id, 'velocity', 'info', 30, v_recent || ' sign-ins in the last minute', jsonb_build_object('limit', pol.velocity_per_min));
  end if;
  select count(*) into v_fails from public.founder_webauthn_event where user_id = p_uid and kind = 'assert_fail' and ts_ms > v_now - pol.fail_window_secs * 1000::bigint;
  if v_fails >= pol.fail_burst then v_risk := v_risk + 40; v_reasons := v_reasons || ('a burst of ' || v_fails || ' failed sign-ins')::text; end if;
  v_risk := least(v_risk, 100);
  v_dec := case when v_risk >= pol.deny_at then 'deny' when v_risk >= pol.stepup_at then 'stepup' else 'allow' end;
  if v_dec = 'deny' then return public._fw_deny(p_uid, p_credential_id, 'denied', v_risk, 'risk ' || v_risk || ' is at or above the denial line: ' || array_to_string(v_reasons, '; ')); end if;
  update public.founder_webauthn_cred set bs = v_bs, last_assert_ms = v_now, assertions = assertions + 1 where credential_id = c.credential_id;
  update public.founder_passkeys set sign_count = greatest(sign_count, v_sc), last_used_at = now() where id = pk.id;
  v_kind := case v_dec when 'stepup' then 'stepup_required' else 'assert_ok' end;
  perform public._fw_log(p_uid, p_credential_id, v_kind, v_dec, v_risk, case when v_dec = 'stepup' then array_to_string(v_reasons, '; ') else null end, jsonb_build_object('sc', v_sc, 'be', v_be, 'bs', v_bs, 'mds', v_mds));
  return jsonb_build_object('ok', true, 'decision', v_dec, 'risk', v_risk, 'stepup', v_dec = 'stepup', 'reasons', to_jsonb(v_reasons), 'mds', v_mds, 'device_bound', not c.be);
end $$;

-- a failed sign-in (bad signature, wrong challenge...) for a KNOWN founder account: counted, and a burst is written as its own event
create or replace function public.founder_webauthn_fail(p_uid uuid, p_credential_id text, p_reason text) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare pol public.founder_webauthn_policy%rowtype; v_now bigint := public._fw_now_ms(); v_fails integer;
begin
  perform public._fs_assert_founder(p_uid);
  if p_reason is null or length(btrim(p_reason)) not between 3 and 300 then raise exception 'say why (3 to 300 characters)' using errcode = '22023'; end if;
  select * into pol from public.founder_webauthn_policy where id;
  perform public._fw_log(p_uid, case when public._fw_cred_id_ok(p_credential_id) then p_credential_id else null end, 'assert_fail', 'info', 10, btrim(p_reason), '{}'::jsonb);
  select count(*) into v_fails from public.founder_webauthn_event where user_id = p_uid and kind = 'assert_fail' and ts_ms > v_now - pol.fail_window_secs * 1000::bigint;
  if v_fails = pol.fail_burst then
    perform public._fw_log(p_uid, null, 'fail_burst', 'deny', 85, v_fails || ' failed sign-ins within ' || pol.fail_window_secs || ' seconds', jsonb_build_object('window_secs', pol.fail_window_secs));
  end if;
  return jsonb_build_object('fails', v_fails, 'burst', v_fails >= pol.fail_burst);
end $$;

-- 9) MDS ingest (Rust verified the signed MDS3 blob; blob numbers only go up) ---------------------------------------------------------------------
create or replace function public.founder_mds_ingest(p_blob_no integer, p_entries jsonb) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare e jsonb; v_max integer; n integer := 0; v_now bigint := public._fw_now_ms();
begin
  if p_blob_no is null or p_blob_no < 1 then raise exception 'bad blob number' using errcode = '22023'; end if;
  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) not between 1 and 5000 then raise exception 'entries must be an array of 1 to 5000' using errcode = '22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_webauthn:mds', 0));
  select coalesce(max(blob_no), 0) into v_max from public.founder_webauthn_mds;
  if p_blob_no <= v_max then return jsonb_build_object('ok', false, 'why', 'blob ' || p_blob_no || ' is not newer than ' || v_max); end if;
  for e in select * from jsonb_array_elements(p_entries) loop
    insert into public.founder_webauthn_mds (aaguid, blob_no, status, status_date, description, fetched_ms, entry_sha)
    values (lower(e ->> 'aaguid'), p_blob_no, e ->> 'status', (e ->> 'date')::date, left(e ->> 'description', 200), v_now,
            encode(extensions.digest(convert_to(lower(e ->> 'aaguid') || '|' || (e ->> 'status') || '|' || (e ->> 'date') || '|' || coalesce(e ->> 'description', ''), 'UTF8'), 'sha256'), 'hex'));
    n := n + 1;
  end loop;
  perform public._fw_log('00000000-0000-0000-0000-000000000000'::uuid, null, 'mds_ingested', 'info', 0, 'MDS blob ' || p_blob_no || ' stored', jsonb_build_object('entries', n, 'blob', p_blob_no));
  return jsonb_build_object('ok', true, 'blob_no', p_blob_no, 'entries', n);
end $$;

-- 10) Signal API queue doors ---------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_webauthn_signal_next(p_uid uuid) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
begin
  perform public._fs_assert_founder(p_uid);
  return jsonb_build_object('signals', coalesce((select jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'payload', payload, 'created_ms', created_ms) order by created_ms)
    from public.founder_webauthn_signal where user_id = p_uid and acked_ms is null and superseded_ms is null and expires_ms > public._fw_now_ms()), '[]'::jsonb));
end $$;
create or replace function public.founder_webauthn_signal_ack(p_uid uuid, p_id uuid) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, extensions as $$
declare n integer;
begin
  perform public._fs_assert_founder(p_uid);
  update public.founder_webauthn_signal set acked_ms = public._fw_now_ms() where id = p_id and user_id = p_uid and acked_ms is null and superseded_ms is null;
  get diagnostics n = row_count;
  if n = 1 then perform public._fw_log(p_uid, null, 'signal_acked', 'info', 0, 'signal acknowledged by the browser', jsonb_build_object('signal', p_id)); end if;
  return jsonb_build_object('acked', n = 1);
end $$;

-- 11) honest post-quantum report -----------------------------------------------------------------------------------------------------------------
create or replace function public.founder_webauthn_pq_report() returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'classical', (select count(*) from public.founder_webauthn_cred c join public.founder_passkeys p using (credential_id) where p.revoked_at is null and c.cose_alg in (-7, -8, -257)),
    'post_quantum', (select count(*) from public.founder_webauthn_cred c join public.founder_passkeys p using (credential_id) where p.revoked_at is null and c.cose_alg in (-48, -49, -50)),
    'pq_allowed_by_policy', (select cardinality(pq_algs) > 0 from public.founder_webauthn_policy where id),
    'note', 'ML-DSA passkeys use COSE ids -48/-49/-50 that are still requested drafts; the policy keeps them off until they are final and a founder-owned authenticator can create one. Until then every active passkey is classical (ES256 or EdDSA).')
$$;

-- 12) status, verify -----------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_webauthn_verify(p_limit integer default 500) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare r public.founder_webauthn_event%rowtype; v_prev text; v_n integer := 0; v_first boolean := true; v_bad bigint; v_why text;
begin
  if p_limit is null or p_limit < 1 or p_limit > 100000 then raise exception 'limit 1 to 100000' using errcode = '22023'; end if;
  for r in select * from (select * from public.founder_webauthn_event order by id desc limit p_limit) t order by id asc loop
    v_n := v_n + 1;
    if r.hash <> public._fw_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.credential_id, r.kind, r.decision, r.risk, r.reason, r.facts) then v_bad := r.id; v_why := 'row hash does not match its content'; exit; end if;
    if not v_first and r.prev_hash <> v_prev then v_bad := r.id; v_why := 'prev_hash does not match the row before'; exit; end if;
    v_first := false; v_prev := r.hash;
  end loop;
  if v_bad is null and exists (select 1 from public.founder_webauthn_cred c left join public.founder_passkeys p using (credential_id) where p.id is null or p.user_id <> c.user_id) then v_bad := 0; v_why := 'a facts row has no matching passkey'; end if;
  return jsonb_build_object('ok', v_bad is null, 'checked', v_n, 'bad_id', v_bad, 'why', v_why);
end $$;

create or replace function public.founder_webauthn_status(p_uid uuid default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare v jsonb; ver jsonb; v_active integer; v_dev integer; v_syn integer; v_q integer; v_level text; v_why text; v_last bigint; v_mds text;
begin
  select count(*) filter (where p.revoked_at is null and c.quarantined_ms is null), count(*) filter (where p.revoked_at is null and c.quarantined_ms is null and not c.be),
         count(*) filter (where p.revoked_at is null and c.quarantined_ms is null and c.be), count(*) filter (where c.quarantined_ms is not null)
    into v_active, v_dev, v_syn, v_q
    from public.founder_webauthn_cred c join public.founder_passkeys p using (credential_id) where p_uid is null or c.user_id = p_uid;
  ver := public.founder_webauthn_verify(200);
  select max(fetched_ms) into v_last from public.founder_webauthn_mds;
  v_mds := case when v_last is null then 'none' when public._fw_now_ms() - v_last > (select mds_stale_secs from public.founder_webauthn_policy where id) * 1000::bigint then 'stale' else 'fresh' end;
  v_level := 'ok'; v_why := 'chain intact, facts consistent';
  if not (ver ->> 'ok')::boolean then v_level := 'fail'; v_why := 'the event ledger or the facts do not verify: ' || (ver ->> 'why');
  elsif v_active = 0 and v_q = 0 then v_level := 'off'; v_why := 'no credential has facts yet';
  elsif v_q > 0 then v_level := 'warn'; v_why := v_q || ' credential(s) quarantined: look at the ledger';
  elsif v_dev = 0 then v_level := 'warn'; v_why := 'no device-bound (hardware) credential: the counter rule has nothing to protect';
  elsif v_mds = 'stale' then v_level := 'warn'; v_why := 'the FIDO metadata copy is stale'; end if;
  return jsonb_build_object('level', v_level, 'why', v_why, 'active', v_active, 'device_bound', v_dev, 'synced', v_syn, 'quarantined', v_q, 'mds', v_mds, 'verify', ver,
    'events_24h', coalesce((select jsonb_object_agg(decision, n) from (select decision, count(*) n from public.founder_webauthn_event where ts_ms > public._fw_now_ms() - 86400000 group by decision) d), '{}'::jsonb),
    'open_signals', (select count(*) from public.founder_webauthn_signal where acked_ms is null and superseded_ms is null and expires_ms > public._fw_now_ms() and (p_uid is null or user_id = p_uid)),
    'pq', public.founder_webauthn_pq_report(), 'last_event', (select jsonb_build_object('id', id, 'kind', kind, 'decision', decision, 'ts_ms', ts_ms) from public.founder_webauthn_event order by id desc limit 1));
end $$;

-- 13) selftest: everything inside a block that ends in ROLLBACK; safe on a live ledger (counts and chain head compared before and after) -----------
create or replace function public.founder_webauthn_e139_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '120s' as $$
declare r text := ''; v_uid uuid; j jsonb; p jsonb; pol public.founder_webauthn_policy%rowtype; i integer;
        v_a text := 'selftestA_' || encode(gen_random_bytes(12), 'hex'); v_b text := 'selftestB_' || encode(gen_random_bytes(12), 'hex'); v_c text := 'selftestC_' || encode(gen_random_bytes(12), 'hex');
        v_aag_ok text := 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; v_aag_bad text := 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; v_zero text := '00000000-0000-0000-0000-000000000000';
        v_origin text; v_blob integer; v_sig uuid; v_sig2 uuid; v_pk_a uuid;
        t_ev bigint; t_h text; t_mds bigint; t_sig bigint; t_cred bigint; t_pk bigint; t_aud bigint;
        f_ok jsonb;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E139 selftest SKIP (no founder account yet)'; end if;
  select count(*), coalesce(max(hash), '') into t_ev, t_h from public.founder_webauthn_event;
  select count(*) into t_mds from public.founder_webauthn_mds; select count(*) into t_sig from public.founder_webauthn_signal;
  select count(*) into t_cred from public.founder_webauthn_cred; select count(*) into t_pk from public.founder_passkeys; select count(*) into t_aud from public.founder_audit;
  select * into pol from public.founder_webauthn_policy where id; v_origin := pol.origins[1];
  f_ok := jsonb_build_object('origin', v_origin, 'rp_id', pol.rp_id, 'aaguid', v_aag_ok, 'cose_alg', -7, 'pk_bytes', 77, 'attestation_fmt', 'packed', 'attestation_trust', 'basic', 'transports', jsonb_build_array('internal', 'hybrid'),
                             'attachment', 'platform', 'discoverable', true, 'be', true, 'bs', true, 'uv_initialized', true);
  begin
    -- policy: read-only at runtime; every cross-column rule holds even for an editor ------------------------------------------------------------------
    if not public._fs_fails($q$update public.founder_webauthn_policy set velocity_per_min = 13$q$) or not public._fs_fails($q$delete from public.founder_webauthn_policy$q$)
       or not public._fs_fails($q$truncate public.founder_webauthn_policy$q$) then raise exception 'the WebAuthn policy can be changed at runtime'; end if;
    perform set_config('app.webauthn_policy_edit', 'on', true);
    for i in 1 .. 9 loop
      if not public._fs_fails(case i
        when 1 then $q$update public.founder_webauthn_policy set stepup_at = 80, deny_at = 80$q$                                         -- no step-up band
        when 2 then $q$update public.founder_webauthn_policy set require_uv = false$q$                                                  -- UV can never be switched off
        when 3 then $q$update public.founder_webauthn_policy set allowed_algs = array[-48]$q$                                           -- a PQ id is not a classical algorithm
        when 4 then $q$update public.founder_webauthn_policy set pq_algs = array[-7]$q$                                                 -- only the requested ML-DSA ids
        when 5 then $q$update public.founder_webauthn_policy set pq_algs = array[-48], allowed_algs = array[-48, -7]$q$
        when 6 then $q$update public.founder_webauthn_policy set origins = array['http://founderworkspace.anexomail.com']$q$            -- https only
        when 7 then $q$update public.founder_webauthn_policy set origins = array['https://founderworkspace.anexomail.com', 'https://*.anexomail.com']$q$ -- no wildcard
        when 8 then $q$update public.founder_webauthn_policy set origins = array['https://other.example.com']$q$                       -- the RP's own origin must be listed
        else $q$update public.founder_webauthn_policy set challenge_secs = 301$q$ end) then raise exception 'policy rule % was not enforced', i; end if;
    end loop;
    if public._fw_origins_ok(array['https://a.one.com', 'https://b.two.com', 'https://c.three.com', 'https://d.four.com', 'https://e.five.com', 'https://f.six.com'], 'a.one.com') then raise exception 'six registrable labels were accepted (Level 3 limit is five)'; end if;
    if not public._fw_origins_ok(array['https://a.one.com', 'https://b.two.com', 'https://c.three.com', 'https://d.four.com', 'https://e.five.com'], 'a.one.com') then raise exception 'five labels must be accepted'; end if;
    if public._fw_origin_shape_ok('https://127.0.0.1') or public._fw_origin_shape_ok('https://localhost') or public._fw_origin_shape_ok('https://a.com/path') or public._fw_origin_shape_ok('https://A.com') then raise exception 'a bad origin shape was accepted'; end if;
    perform set_config('app.webauthn_policy_edit', '', true);
    r := r || 'policy read-only + 9 cross-column rules + origin shapes + 5-label limit OK; ';

    -- passkeys + the additive Signal trigger -------------------------------------------------------------------------------------------------------
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_a, '{"k":1}', 'selftest synced');
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_b, '{"k":2}', 'selftest hardware');
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, v_c, '{"k":3}', 'selftest synced 2');
    p := public.founder_webauthn_signal_next(v_uid);
    if jsonb_array_length(p -> 'signals') <> 1 or p #>> '{signals,0,kind}' <> 'all_accepted' or not (p #> '{signals,0,payload,credentialIds}') @> to_jsonb(array[v_a, v_b, v_c]) then
      raise exception 'three new passkeys must leave ONE open all_accepted signal (older ones superseded) naming all of them: %', p; end if;
    r := r || 'Signal trigger: one open all_accepted, older superseded OK; ';

    -- register: refusals first, then the good ones -------------------------------------------------------------------------------------------------
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('origin', 'https://evil.example.com'));
    if (j ->> 'ok')::boolean or j ->> 'kind' <> 'origin_refused' then raise exception 'a foreign origin registered: %', j; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('rp_id', 'anexomail.com'));
    if (j ->> 'ok')::boolean then raise exception 'a foreign rp id registered'; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('cose_alg', -48));
    if (j ->> 'ok')::boolean or j #>> '{reasons,0}' not like '%not allowed by the policy%' then raise exception 'a post-quantum id registered while the policy keeps them off: %', j; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('cose_alg', -257));
    if (j ->> 'ok')::boolean then raise exception 'RS256 registered although the policy did not list it'; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('be', false, 'bs', true));
    if (j ->> 'ok')::boolean then raise exception 'BS without BE registered'; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('uv_initialized', false));
    if (j ->> 'ok')::boolean then raise exception 'a registration without user verification was accepted'; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok || jsonb_build_object('attestation_trust', 'mds3'));
    if (j ->> 'ok')::boolean then raise exception 'mds3 trust without any MDS entry was accepted'; end if;
    if not public._fs_fails($q$select public.founder_webauthn_register(gen_random_uuid(), 'abcdefghijklmnop0123', '{}'::jsonb)$q$) or not public._fs_fails($q$select public.founder_webauthn_register(null, 'x', '{}'::jsonb)$q$) then raise exception 'a stranger or a bad id registered'; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok);
    if not (j ->> 'ok')::boolean or not (j ->> 'synced')::boolean or (j ->> 'pq')::boolean then raise exception 'good synced registration failed: %', j; end if;
    j := public.founder_webauthn_register(v_uid, v_a, f_ok);
    if (j ->> 'ok')::boolean then raise exception 'facts were registered twice'; end if;
    j := public.founder_webauthn_register(v_uid, v_b, f_ok || jsonb_build_object('aaguid', v_aag_bad, 'cose_alg', -8, 'pk_bytes', 44, 'attestation_trust', 'self', 'be', false, 'bs', false, 'transports', jsonb_build_array('usb', 'nfc'), 'attachment', 'cross-platform'));
    if not (j ->> 'ok')::boolean or not (j ->> 'device_bound')::boolean then raise exception 'good device-bound registration failed: %', j; end if;
    j := public.founder_webauthn_register(v_uid, v_c, f_ok || jsonb_build_object('aaguid', v_zero, 'attestation_fmt', 'none', 'attestation_trust', 'none'));
    if not (j ->> 'ok')::boolean then raise exception 'a credential without a disclosed AAGUID must register: %', j; end if;
    r := r || 'register: origin, rp, PQ-off, RS256, BS-without-BE, UV, mds3-without-MDS refused; 3 good ones stored OK; ';

    -- facts are immutable where Level 3 says so ---------------------------------------------------------------------------------------------------
    if not public._fs_fails(format($q$update public.founder_webauthn_cred set be = false where credential_id = %L$q$, v_a)) or not public._fs_fails(format($q$update public.founder_webauthn_cred set aaguid = %L where credential_id = %L$q$, v_aag_bad, v_a))
       or not public._fs_fails(format($q$update public.founder_webauthn_cred set cose_alg = -8 where credential_id = %L$q$, v_a)) or not public._fs_fails(format($q$update public.founder_webauthn_cred set uv_initialized = false where credential_id = %L$q$, v_a))
       or not public._fs_fails(format($q$update public.founder_webauthn_cred set assertions = 0, last_assert_ms = null where credential_id = %L and assertions > 0$q$, v_a)) and false
       or not public._fs_fails(format($q$delete from public.founder_webauthn_cred where credential_id = %L$q$, v_a)) or not public._fs_fails($q$truncate public.founder_webauthn_cred$q$)
       or not public._fs_fails(format($q$update public.founder_webauthn_cred set user_id = gen_random_uuid() where credential_id = %L$q$, v_a))
       or not public._fs_fails(format($q$update public.founder_webauthn_cred set bs = true, be = false where credential_id = %L$q$, v_b)) then raise exception 'credential facts are not immutable'; end if;
    if not public._fs_fails(format($q$insert into public.founder_webauthn_cred (credential_id, user_id, aaguid, cose_alg, pk_bytes, attestation_fmt, attestation_trust, discoverable, be, bs, registered_ms) values (%L, gen_random_uuid(), %L, -7, 77, 'none', 'none', true, true, true, 1)$q$, v_a, v_aag_ok)) then
      raise exception 'facts for another owner were accepted'; end if;
    r := r || 'immutable BE/AAGUID/alg/UV/owner, no delete, no truncate OK; ';

    -- metadata known first, so the risk arithmetic below is exact (an unlisted model would add 10) -----------------------------------------------------
    select coalesce(max(blob_no), 0) + 1 into v_blob from public.founder_webauthn_mds;
    j := public.founder_mds_ingest(v_blob, jsonb_build_array(jsonb_build_object('aaguid', v_aag_ok, 'status', 'FIDO_CERTIFIED', 'date', '2026-01-01'), jsonb_build_object('aaguid', v_aag_bad, 'status', 'FIDO_CERTIFIED', 'date', '2026-01-01')));
    if not (j ->> 'ok')::boolean then raise exception 'the first MDS blob was refused: %', j; end if;

    -- assertions ---------------------------------------------------------------------------------------------------------------------------------
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 0, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if not (j ->> 'ok')::boolean or j ->> 'decision' <> 'allow' or (j ->> 'risk')::int >= pol.stepup_at then raise exception 'a clean synced assertion must be allowed: %', j; end if;
    if (select assertions from public.founder_webauthn_cred where credential_id = v_a) <> 1 or (select last_used_at is null from public.founder_passkeys where credential_id = v_a) then raise exception 'an allowed assertion must count and touch the passkey'; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 0, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', 'https://evil.example.com', 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean or j ->> 'kind' <> 'origin_refused' then raise exception 'a foreign origin was allowed: %', j; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 0, 'up', false, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean then raise exception 'a missing user-presence flag was allowed'; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 0, 'up', true, 'uv', false, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean then raise exception 'a missing user-verification flag was allowed'; end if;
    j := public.founder_webauthn_assert(v_uid, 'neverregistered0123456', jsonb_build_object('sign_count', 0, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean then raise exception 'an unknown credential was allowed'; end if;
    if not public._fs_fails(format($q$select public.founder_webauthn_assert(%L, %L, '{"sign_count":-1}'::jsonb)$q$, v_uid, v_a)) or not public._fs_fails(format($q$select public.founder_webauthn_assert(%L, %L, '{}'::jsonb)$q$, v_uid, v_a)) then
      raise exception 'malformed assertion facts were accepted'; end if;
    r := r || 'assert: allow + foreign origin + UP + UV + unknown + malformed OK; ';

    -- BE flip = another authenticator: denied AND quarantined for good ------------------------------------------------------------------------------
    j := public.founder_webauthn_assert(v_uid, v_c, jsonb_build_object('sign_count', 0, 'up', true, 'uv', true, 'be', false, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean or j ->> 'kind' <> 'be_changed' or (select quarantined_ms is null from public.founder_webauthn_cred where credential_id = v_c) then raise exception 'a BE flip must deny and quarantine: %', j; end if;
    j := public.founder_webauthn_assert(v_uid, v_c, jsonb_build_object('sign_count', 0, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean or j #>> '{reasons,0}' not like '%quarantined%' then raise exception 'a quarantined credential must stay denied: %', j; end if;
    if not public._fs_fails(format($q$update public.founder_webauthn_cred set quarantined_ms = null, quarantine_why = null where credential_id = %L$q$, v_c)) then raise exception 'a quarantine was lifted by an update'; end if;
    r := r || 'BE flip denies + quarantines for good OK; ';

    -- device-bound counter: the clone rule (revoke + quarantine + audit + Signal) -----------------------------------------------------------------------
    j := public.founder_webauthn_assert(v_uid, v_b, jsonb_build_object('sign_count', 5, 'up', true, 'uv', true, 'be', false, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    if not (j ->> 'ok')::boolean or (j ->> 'device_bound')::boolean is not true then raise exception 'a first device-bound assertion must pass: %', j; end if;
    if (select sign_count from public.founder_passkeys where credential_id = v_b) <> 5 then raise exception 'the counter must be stored'; end if;
    j := public.founder_webauthn_assert(v_uid, v_b, jsonb_build_object('sign_count', 5, 'up', true, 'uv', true, 'be', false, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    if (j ->> 'ok')::boolean or j ->> 'kind' <> 'quarantined' then raise exception 'a device-bound counter that did not increase must be a clone: %', j; end if;
    if (select revoked_at is null from public.founder_passkeys where credential_id = v_b) or (select quarantined_ms is null from public.founder_webauthn_cred where credential_id = v_b) then raise exception 'a clone must be revoked and quarantined'; end if;
    if (select count(*) from public.founder_audit) <= t_aud then raise exception 'a clone must write the founder audit chain'; end if;
    p := public.founder_webauthn_signal_next(v_uid);
    if not exists (select 1 from jsonb_array_elements(p -> 'signals') s where s ->> 'kind' = 'unknown_credential' and s #>> '{payload,credentialId}' = v_b) then raise exception 'a revoked passkey must queue signalUnknownCredential: %', p; end if;
    if exists (select 1 from jsonb_array_elements(p -> 'signals') s where s ->> 'kind' = 'all_accepted' and (s #> '{payload,credentialIds}') ? v_b) then raise exception 'the accepted list must no longer contain the revoked passkey'; end if;
    r := r || 'clone rule: revoke + quarantine + audit + Signal OK; ';

    -- synced counter regression is a RISK, not a lock-out: 35 alone allows, 35 + backup-state change = 40 steps up ---------------------------------------------
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 10, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if not (j ->> 'ok')::boolean then raise exception 'sc 10 must pass: %', j; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 9, 'up', true, 'uv', true, 'be', true, 'bs', true, 'origin', v_origin, 'rp_id', pol.rp_id));
    if not (j ->> 'ok')::boolean or j ->> 'decision' <> 'allow' or (j ->> 'risk')::int <> 35 then raise exception 'a synced regression alone must allow with risk 35: %', j; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 9, 'up', true, 'uv', true, 'be', true, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    if not (j ->> 'ok')::boolean or j ->> 'decision' <> 'stepup' or (j ->> 'risk')::int <> 40 or not (j ->> 'stepup')::boolean then raise exception 'regression + BS change must step up at 40: %', j; end if;
    if (select bs from public.founder_webauthn_cred where credential_id = v_a) then raise exception 'the new backup state must be stored'; end if;
    if (select sign_count from public.founder_passkeys where credential_id = v_a) <> 10 then raise exception 'the stored counter must never go down'; end if;
    if (select revoked_at is not null from public.founder_passkeys where credential_id = v_a) then raise exception 'a synced credential must never be revoked by the counter'; end if;
    r := r || 'synced regression = risk 35, + BS change = step-up 40, never revoked OK; ';

    -- failures, burst, velocity ------------------------------------------------------------------------------------------------------------------
    if not public._fs_fails(format($q$select public.founder_webauthn_fail(%L, %L, 'x')$q$, v_uid, v_a)) then raise exception 'a one-letter failure reason was accepted'; end if;
    for i in 1 .. pol.fail_burst loop j := public.founder_webauthn_fail(v_uid, v_a, 'bad signature number ' || i); end loop;
    if not (j ->> 'burst')::boolean or not exists (select 1 from public.founder_webauthn_event where kind = 'fail_burst' and user_id = v_uid and id > (select coalesce(max(id), 0) - 200 from public.founder_webauthn_event)) then raise exception 'a burst of failures must be written: %', j; end if;
    j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 11, 'up', true, 'uv', true, 'be', true, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    if j ->> 'decision' <> 'stepup' or (j ->> 'risk')::int < 40 then raise exception 'a valid sign-in in the middle of a failure burst must step up: %', j; end if;
    for i in 1 .. pol.velocity_per_min + 1 loop
      j := public.founder_webauthn_assert(v_uid, v_a, jsonb_build_object('sign_count', 11 + i, 'up', true, 'uv', true, 'be', true, 'bs', false, 'origin', v_origin, 'rp_id', pol.rp_id));
    end loop;
    if not exists (select 1 from public.founder_webauthn_event where kind = 'velocity' and credential_id = v_a) then raise exception 'too many sign-ins in a minute must be written as velocity'; end if;
    r := r || 'fail burst + velocity raise the risk and are written OK; ';

    -- MDS: ingest is ordered, a compromised model is refused at registration AND at the next sign-in --------------------------------------------------
    select coalesce(max(blob_no), 0) + 1 into v_blob from public.founder_webauthn_mds;
    if not public._fs_fails(format($q$select public.founder_mds_ingest(%s, '[{"aaguid":"nonsense","status":"FIDO_CERTIFIED","date":"2026-01-01"}]'::jsonb)$q$, v_blob)) or not public._fs_fails(format($q$select public.founder_mds_ingest(%s, '[{"aaguid":%L,"status":"MADE_UP","date":"2026-01-01"}]'::jsonb)$q$, v_blob, v_aag_bad))
       or not public._fs_fails($q$select public.founder_mds_ingest(0, '[]'::jsonb)$q$) then raise exception 'a bad MDS blob was accepted'; end if;
    j := public.founder_mds_ingest(v_blob, jsonb_build_array(jsonb_build_object('aaguid', v_aag_ok, 'status', 'FIDO_CERTIFIED_L2', 'date', '2026-02-01', 'description', 'selftest good model'),
                                                              jsonb_build_object('aaguid', v_aag_bad, 'status', 'ATTESTATION_KEY_COMPROMISE', 'date', '2026-03-01', 'description', 'selftest bad model')));
    if not (j ->> 'ok')::boolean then raise exception 'a good MDS blob was refused: %', j; end if;
    j := public.founder_mds_ingest(v_blob, jsonb_build_array(jsonb_build_object('aaguid', v_aag_ok, 'status', 'FIDO_CERTIFIED', 'date', '2026-02-01')));
    if (j ->> 'ok')::boolean then raise exception 'the same blob number was ingested twice'; end if;
    if public._fw_mds_state(v_aag_ok) <> 'ok' or public._fw_mds_state(v_aag_bad) <> 'denied' or public._fw_mds_state(v_zero) <> 'none' or public._fw_mds_state('cccccccc-cccc-4ccc-8ccc-cccccccccccc') <> 'unknown'
       or public._fw_mds_state(v_aag_ok, public._fw_now_ms() + (pol.mds_stale_secs + 60) * 1000::bigint) <> 'stale' then raise exception 'MDS states are wrong'; end if;
    j := public.founder_webauthn_register(v_uid, v_c, f_ok || jsonb_build_object('aaguid', v_aag_bad));
    if (j ->> 'ok')::boolean then raise exception 'a compromised model registered'; end if;
    if not public._fs_fails($q$update public.founder_webauthn_mds set status = 'FIDO_CERTIFIED'$q$) or not public._fs_fails($q$delete from public.founder_webauthn_mds$q$) or not public._fs_fails($q$truncate public.founder_webauthn_mds$q$) then raise exception 'MDS is not append-only'; end if;
    insert into public.founder_passkeys (user_id, credential_id, passkey, label) values (v_uid, 'selftestD_' || encode(gen_random_bytes(12), 'hex'), '{}', 'selftest mds-later');
    r := r || 'MDS ordered ingest, states none/ok/denied/unknown/stale, refusal at registration, append-only OK; ';

    -- Signal queue: acknowledged once; a stranger cannot acknowledge --------------------------------------------------------------------------------
    p := public.founder_webauthn_signal_next(v_uid);
    v_sig := (p #>> '{signals,0,id}')::uuid;
    if not (public.founder_webauthn_signal_ack(v_uid, v_sig) ->> 'acked')::boolean then raise exception 'the first acknowledgement must work'; end if;
    if (public.founder_webauthn_signal_ack(v_uid, v_sig) ->> 'acked')::boolean then raise exception 'a signal was acknowledged twice'; end if;
    if not public._fs_fails(format($q$select public.founder_webauthn_signal_ack(gen_random_uuid(), %L)$q$, v_sig)) then raise exception 'a stranger acknowledged a signal'; end if;
    if not public._fs_fails(format($q$update public.founder_webauthn_signal set payload = '{}'::jsonb where id = %L$q$, v_sig)) or not public._fs_fails(format($q$delete from public.founder_webauthn_signal where id = %L$q$, v_sig)) then raise exception 'signals are not protected'; end if;
    r := r || 'Signal ack once, protected OK; ';

    -- honest post-quantum report, status, the ledger itself --------------------------------------------------------------------------------------------
    p := public.founder_webauthn_pq_report();
    if (p ->> 'post_quantum')::int <> 0 or (p ->> 'pq_allowed_by_policy')::boolean or p ->> 'note' not like '%still requested drafts%' then raise exception 'the PQ report must say 0 post-quantum credentials: %', p; end if;
    p := public.founder_webauthn_status(v_uid);
    if p ->> 'level' not in ('ok', 'warn') or (p ->> 'quarantined')::int < 2 or not (p #>> '{verify,ok}')::boolean then raise exception 'status must be ok or warn and count the quarantines: %', p; end if;
    if not public._fs_fails($q$update public.founder_webauthn_event set reason = 'edited reason'$q$) or not public._fs_fails($q$delete from public.founder_webauthn_event$q$) or not public._fs_fails($q$truncate public.founder_webauthn_event$q$) then raise exception 'the event ledger is not append-only'; end if;
    if not public._fs_fails($q$insert into public.founder_webauthn_event (ts_ms, user_id, kind, decision, risk, reason, prev_hash, hash) values (1, gen_random_uuid(), 'denied', 'allow', 100, 'x y z', repeat('0', 64), repeat('0', 64))$q$)
       or not public._fs_fails($q$insert into public.founder_webauthn_event (ts_ms, user_id, kind, decision, risk, prev_hash, hash) values (1, gen_random_uuid(), 'assert_ok', 'allow', 90, repeat('0', 64), repeat('0', 64))$q$) then raise exception 'a bad event shape was accepted'; end if;
    select to_jsonb(e) into p from public.founder_webauthn_event e order by id desc limit 1;
    if p ->> 'prev_hash' = repeat('0', 64) and t_ev > 0 then raise exception 'the trigger must chain to the live head'; end if;
    if (public.founder_webauthn_verify(100000) ->> 'ok')::boolean is not true then raise exception 'the whole chain must verify'; end if;
    alter table public.founder_webauthn_event disable trigger founder_webauthn_event_stop;
    update public.founder_webauthn_event set reason = 'tampered after the fact' where id = (select max(id) from public.founder_webauthn_event where reason is not null);
    if (public.founder_webauthn_verify(1000) ->> 'ok')::boolean then raise exception 'verify missed an edited event'; end if;
    alter table public.founder_webauthn_event enable trigger founder_webauthn_event_stop;
    r := r || 'PQ report honest (0), status, append-only, bad shapes refused, chain verifies, tamper detected OK; ';
    raise exception 'ROLLBACK_SELFTEST';
  exception when others then
    if sqlerrm <> 'ROLLBACK_SELFTEST' then raise exception 'E139 selftest FAIL: %', sqlerrm; end if;
  end;
  perform set_config('app.webauthn_policy_edit', '', true);
  if (select count(*) from public.founder_webauthn_event) <> t_ev or coalesce((select max(hash) from public.founder_webauthn_event), '') <> t_h or (select count(*) from public.founder_webauthn_mds) <> t_mds
     or (select count(*) from public.founder_webauthn_signal) <> t_sig or (select count(*) from public.founder_webauthn_cred) <> t_cred or (select count(*) from public.founder_passkeys) <> t_pk
     or (select count(*) from public.founder_audit) <> t_aud then raise exception 'E139 selftest left rows behind'; end if;
  if not exists (select 1 from pg_trigger where tgrelid = 'public.founder_webauthn_event'::regclass and tgname = 'founder_webauthn_event_stop' and tgenabled = 'O') then raise exception 'E139 selftest left a trigger disabled'; end if;
  return 'E139 selftest OK — ' || r || 'rollback clean';
end $$;

-- grants: nothing for anon/authenticated, execute for service_role only --------------------------------------------------------------------------
do $$ declare f text; begin
  foreach f in array array['public._fw_now_ms()', 'public._fw_aaguid_ok(text)', 'public._fw_cred_id_ok(text)', 'public._fw_origin_shape_ok(text)', 'public._fw_label_of(text)', 'public._fw_origins_ok(text[],text)',
    'public._fw_policy_guard()', 'public._fw_cred_guard()', 'public._fw_event_hash(text,bigint,uuid,text,text,text,integer,text,jsonb)', 'public._fw_event_guard()', 'public._fw_stop()',
    'public._fw_log(uuid,text,text,text,integer,text,jsonb)', 'public._fw_signal_guard()', 'public._fw_signal_enqueue(uuid,text,jsonb)', 'public._fw_accepted_payload(uuid)', 'public._fw_passkey_signals()',
    'public._fw_mds_state(text,bigint)', 'public._fw_deny(uuid,text,text,integer,text,jsonb)',
    'public.founder_webauthn_origin_ok(text)', 'public.founder_webauthn_register(uuid,text,jsonb)', 'public.founder_webauthn_assert(uuid,text,jsonb)', 'public.founder_webauthn_fail(uuid,text,text)',
    'public.founder_mds_ingest(integer,jsonb)', 'public.founder_webauthn_signal_next(uuid)', 'public.founder_webauthn_signal_ack(uuid,uuid)', 'public.founder_webauthn_pq_report()',
    'public.founder_webauthn_verify(integer)', 'public.founder_webauthn_status(uuid)', 'public.founder_webauthn_e139_selftest()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;
end $$;

comment on table public.founder_webauthn_policy is 'E139: singleton WebAuthn Level 3 policy (rp id, origins, algorithms, thresholds); read-only at runtime.';
comment on table public.founder_webauthn_cred is 'E139: one facts row per passkey: BE/AAGUID/algorithm fixed for life, BS may move, quarantine is one-way.';
comment on table public.founder_webauthn_event is 'E139: append-only, hash-chained ledger of every passkey decision (ts, prev_hash, hash computed by the trigger).';
comment on table public.founder_webauthn_mds is 'E139: append-only FIDO Metadata Service statuses per AAGUID, versioned by blob number.';
comment on table public.founder_webauthn_signal is 'E139: queue for the Level 3 Signal API (signalAllAcceptedCredentials, signalUnknownCredential); acknowledged or superseded once.';
comment on function public.founder_webauthn_assert(uuid, text, jsonb) is 'E139: allow / step up / deny from the verified facts of one assertion; replaces founder_passkey_touch for founder sign-ins.';

do $$ begin raise notice '%', public.founder_webauthn_e139_selftest(); end $$;

-- RUNBOOK: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E139_founder_webauthn_l3 CHECK_E139  (after fetch). Needs E102 + E113 + E117 + E118.
-- Undo (nothing else depends on it): drop the founder_webauthn_* tables, the _fw_* helpers, the trigger founder_webauthn_passkey_signals on founder_passkeys; E117/E118 are untouched.
