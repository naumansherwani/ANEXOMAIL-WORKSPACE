
-- ==============================================================================================================================
-- E155 (D1, 10 Nov 2026) - FOUNDER: Devices & Sessions SOVEREIGN COMMAND CENTER (the database half; Rust = D2, UI = D3).
-- His order 20:15 / 21:23: "super advanced SQL" for his 8 device-and-session features. What this file really gives, honestly worded:
--   1) founder_session_registry  one row per live founder session: device-key fingerprint, how the browser CLAIMS to be (user-agent family) against what it
--      PROVES (client-hints family), a spoof score + reasons, protocol (quic | h2 | h1), kernel version, country, integrity counters, revoke state.
--      Core columns are FROZEN by trigger; counters only grow; a revoked session never comes back.
--   2) founder_session_ledger    append-only SHA-256 HASH CHAIN (advisory-locked; update / delete / truncate refused for everyone, service_role too):
--      which session, when, from which network HASH (never an address), on which protocol and micro-kernel version, and every policy change.
--   3) founder_session_policy    per founder: location boundary lock (off | observe | enforce, allowed countries), what to do on a spoof (alert | block),
--      when integrity counts as stale. EVERY change is written into the chain. Lock-out guard: enforce is refused if it would lock the founder out right now.
--   4) doors (service_role only, SECURITY DEFINER, search_path pinned): register, touch, revoke, revoke_others, board, ledger_page, ledger_verify, policy_set,
--      geo_check, tick. The one-click nuke is ONE call: registry row revoked + ledger row + the device-bound key (E149) revoked, in one transaction.
--   5) founder_session_posture155() reads the posture from the catalogs; founder_session_selftest155() is a rolled-back behaviour test; CHECK_E155.sql is ONE select.
-- HONEST LIMITS (written into the answers, never hidden): a browser cannot reveal a hardware serial, so "hardware identity" = the device-bound key fingerprint;
-- a VPN inside an allowed country passes the location lock; "integrity verified" means the last REAL verification time, not a claim about every second.
-- PRIVACY (Rule 69 / FC18): hashes, key fingerprints, ids, counts, times and two-letter country codes only. No address, no user-agent string, no email.
-- Needs E102 + E149 + E150 + E151 first. Idempotent: safe to run twice. Nothing existing is changed or deleted.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_session:ddl155', 0));
  if to_regclass('public.founder_accounts') is null or to_regclass('public.founder_devices') is null then raise exception 'E102 pehle chalao' using errcode = '55000'; end if;
  if to_regclass('public.founder_dbsc_sessions') is null then raise exception 'E149 pehle chalao' using errcode = '55000'; end if;
  if to_regclass('public.founder_signin_events') is null then raise exception 'E151 pehle chalao' using errcode = '55000'; end if;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 0) small pure helpers (immutable, no table access)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._sess_h64(p text) returns boolean language sql immutable set search_path = pg_catalog as $$ select p is not null and p ~ '^[0-9a-f]{64}$' $$;
create or replace function public._sess_family(p text) returns boolean language sql immutable set search_path = pg_catalog as $$
  select p is not null and p in ('chrome', 'edge', 'firefox', 'safari', 'opera', 'samsung', 'other', 'unknown') $$;
create or replace function public._sess_kernel_ok(p text) returns boolean language sql immutable set search_path = pg_catalog as $$ select p is not null and p ~ '^[A-Za-z0-9._+-]{1,40}$' $$;
create or replace function public._sess_countries_ok(p text[]) returns boolean language sql immutable set search_path = pg_catalog as $$
  select p is not null and coalesce(cardinality(p), 0) between 0 and 60 and not exists (select 1 from unnest(p) c where c is null or c !~ '^[A-Z]{2}$')
         and coalesce(cardinality(p), 0) = (select count(distinct c) from unnest(p) c) $$;
-- the badge the screen shows for the path, derived from the protocol the SERVER measured (the browser is never asked)
create or replace function public._sess_path_badge(p text) returns text language sql immutable set search_path = pg_catalog as $$
  select case p when 'quic' then 'HTTP/3 QUIC (WebTransport)' when 'h2' then 'HTTP/2 over TCP' when 'h1' then 'HTTP/1.1 over TCP' else 'protocol not measured' end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 1) tables
-- ------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  perform pg_advisory_xact_lock(hashtextextended('founder_session:ddl155', 1));

  create table if not exists public.founder_session_registry (
    sid_hash         text        primary key check (public._sess_h64(sid_hash)),                    -- SHA-256 of the session id (Rust hashes it; the id itself is never stored)
    user_id          uuid        not null references public.founder_accounts (user_id) on delete restrict,
    device_hash      text        not null check (public._sess_h64(device_hash)),
    net_hash         text        not null check (public._sess_h64(net_hash)),                       -- network seen at the LAST touch (HMAC of the address, never the address)
    method           text        not null check (method in ('password', 'passkey', 'magic_link')),
    protocol         text        not null default 'unknown' check (protocol in ('quic', 'h2', 'h1', 'unknown')),
    kernel_version   text        not null default 'unknown' check (public._sess_kernel_ok(kernel_version)),
    key_source       text        not null default 'none' check (key_source in ('dbsc', 'webcrypto', 'none')),
    key_fp           text        check (key_fp is null or public._sess_h64(key_fp)),                -- SHA-256 of the device PUBLIC key
    ua_family        text        not null default 'unknown' check (public._sess_family(ua_family)), -- what the browser CLAIMS (user-agent)
    hint_family      text        not null default 'unknown' check (public._sess_family(hint_family)), -- what it PROVES (client hints / engine features)
    spoof_score      integer     not null default 0 check (spoof_score between 0 and 100),
    spoof_level      text        not null default 'ok' check (spoof_level in ('ok', 'suspect', 'spoof')),
    spoof_reasons    text[]      not null default '{}' check (cardinality(spoof_reasons) <= 8),
    country          text        check (country is null or country ~ '^[A-Z]{2}$'),
    geo_state        text        not null default 'off' check (geo_state in ('off', 'allowed', 'observed_outside', 'unknown_country')),
    created_at       timestamptz not null default now(),
    last_seen_at     timestamptz not null default now(),
    last_ledger_at   timestamptz not null default now(),
    last_verified_at timestamptz,
    verified_ok      bigint      not null default 0 check (verified_ok >= 0),
    verified_fail    bigint      not null default 0 check (verified_fail >= 0),
    last_fail_at     timestamptz,
    revoked_at       timestamptz,
    revoke_reason    text        check (revoke_reason is null or revoke_reason in ('founder_nuke', 'founder_nuke_others', 'integrity_fail', 'replaced', 'expired', 'selftest')),
    check ((revoked_at is null) = (revoke_reason is null)),
    check (last_seen_at >= created_at),
    check ((spoof_level = 'ok' and spoof_score < 30) or (spoof_level = 'suspect' and spoof_score between 30 and 59) or (spoof_level = 'spoof' and spoof_score >= 60))
  );
  create index if not exists founder_session_registry_user_live on public.founder_session_registry (user_id, last_seen_at desc) where revoked_at is null;
  create index if not exists founder_session_registry_user_all  on public.founder_session_registry (user_id, created_at desc);
  create index if not exists founder_session_registry_device    on public.founder_session_registry (user_id, device_hash, created_at desc);

  create table if not exists public.founder_session_policy (
    user_id        uuid        primary key references public.founder_accounts (user_id) on delete restrict,
    geo_mode       text        not null default 'off' check (geo_mode in ('off', 'observe', 'enforce')),
    countries      text[]      not null default '{}' check (public._sess_countries_ok(countries)),
    spoof_action   text        not null default 'alert' check (spoof_action in ('alert', 'block')),
    stale_after_s  integer     not null default 900 check (stale_after_s between 30 and 86400),
    updated_at     timestamptz not null default now(),
    check (geo_mode <> 'enforce' or cardinality(countries) >= 1)                                    -- enforcing an empty list would lock every new device out for ever
  );

  create table if not exists public.founder_session_ledger (
    id             bigint generated always as identity primary key,
    ts_ms          bigint      not null check (ts_ms > 0),
    user_id        uuid        not null,                                                            -- no foreign key: deleting an account must never rewrite a ledger
    sid_hash       text        check (sid_hash is null or public._sess_h64(sid_hash)),
    kind           text        not null check (kind in ('registered', 'seen', 'protocol_changed', 'kernel_changed', 'net_changed', 'spoof_alert', 'spoof_blocked', 'geo_observed',
                                                       'geo_refused', 'integrity_fail', 'revoked', 'nuke_others', 'policy_changed', 'expired')),
    net_hash       text        check (net_hash is null or public._sess_h64(net_hash)),
    kernel_version text        check (kernel_version is null or public._sess_kernel_ok(kernel_version)),
    protocol       text        check (protocol is null or protocol in ('quic', 'h2', 'h1', 'unknown')),
    country        text        check (country is null or country ~ '^[A-Z]{2}$'),
    facts          jsonb       not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 700),
    prev_hash      text        not null check (public._sess_h64(prev_hash)),
    hash           text        not null unique check (public._sess_h64(hash))
  );
  create index if not exists founder_session_ledger_user on public.founder_session_ledger (user_id, id desc);
  create index if not exists founder_session_ledger_sid  on public.founder_session_ledger (sid_hash, id desc) where sid_hash is not null;

  alter table public.founder_session_registry enable row level security;
  alter table public.founder_session_policy   enable row level security;
  alter table public.founder_session_ledger   enable row level security;
  -- nobody writes these tables directly, not even service_role: every write goes through a SECURITY DEFINER door below
  revoke all on public.founder_session_registry, public.founder_session_policy, public.founder_session_ledger from public, anon, authenticated, service_role;
  grant select on public.founder_session_registry, public.founder_session_policy, public.founder_session_ledger to service_role;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 2) guards: frozen columns, forward-only counters, append-only ledger with its chain
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._sess_stop() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E155: this ledger is append-only, nothing is changed or deleted' using errcode = '42501'; end $$;

create or replace function public._sess_registry_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E155: a session record is never deleted, it is revoked' using errcode = '42501'; end if;
  if (new.sid_hash, new.user_id, new.device_hash, new.method, new.key_source, new.key_fp, new.ua_family, new.hint_family, new.created_at)
     is distinct from (old.sid_hash, old.user_id, old.device_hash, old.method, old.key_source, old.key_fp, old.ua_family, old.hint_family, old.created_at) then
    raise exception 'E155: the identity of a session is frozen' using errcode = '42501'; end if;
  if old.revoked_at is not null then raise exception 'E155: a revoked session never comes back' using errcode = '42501'; end if;
  if new.last_seen_at < old.last_seen_at or new.verified_ok < old.verified_ok or new.verified_fail < old.verified_fail then
    raise exception 'E155: times and counters only move forward' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_session_registry_guard on public.founder_session_registry;
create trigger founder_session_registry_guard before update or delete on public.founder_session_registry for each row execute function public._sess_registry_guard();
drop trigger if exists founder_session_registry_stop_trunc on public.founder_session_registry;
create trigger founder_session_registry_stop_trunc before truncate on public.founder_session_registry for each statement execute function public._sess_stop();

create or replace function public._sess_policy_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E155: a policy is changed through founder_session_policy_set, never deleted' using errcode = '42501'; end if;
  if new.user_id <> old.user_id then raise exception 'E155: the owner of a policy is frozen' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_session_policy_guard on public.founder_session_policy;
create trigger founder_session_policy_guard before update or delete on public.founder_session_policy for each row execute function public._sess_policy_guard();
drop trigger if exists founder_session_policy_stop_trunc on public.founder_session_policy;
create trigger founder_session_policy_stop_trunc before truncate on public.founder_session_policy for each statement execute function public._sess_stop();

create or replace function public._sess_event_hash(p_prev text, p_ts bigint, p_uid uuid, p_sid text, p_kind text, p_net text, p_kernel text, p_proto text, p_country text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || coalesce(p_uid::text, '-') || '|' || coalesce(p_sid, '-') || '|' || p_kind || '|' || coalesce(p_net, '-') || '|'
         || coalesce(p_kernel, '-') || '|' || coalesce(p_proto, '-') || '|' || coalesce(p_country, '-') || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex') $$;

create or replace function public._sess_ledger_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_session_ledger%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_session:chain', 0));
  select * into p from public.founder_session_ledger order by id desc limit 1;
  new.ts_ms     := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._sess_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.sid_hash, new.kind, new.net_hash, new.kernel_version, new.protocol, new.country, new.facts);
  return new;
end $$;
drop trigger if exists founder_session_ledger_guard on public.founder_session_ledger;
create trigger founder_session_ledger_guard before insert on public.founder_session_ledger for each row execute function public._sess_ledger_guard();
drop trigger if exists founder_session_ledger_stop on public.founder_session_ledger;
create trigger founder_session_ledger_stop before update or delete on public.founder_session_ledger for each row execute function public._sess_stop();
drop trigger if exists founder_session_ledger_stop_trunc on public.founder_session_ledger;
create trigger founder_session_ledger_stop_trunc before truncate on public.founder_session_ledger for each statement execute function public._sess_stop();

-- internal logger: one place writes the chain
create or replace function public._sess_log(p_uid uuid, p_sid text, p_kind text, p_net text, p_kernel text, p_proto text, p_country text, p_facts jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id bigint;
begin
  insert into public.founder_session_ledger (ts_ms, user_id, sid_hash, kind, net_hash, kernel_version, protocol, country, facts, prev_hash, hash)
  values (1, p_uid, p_sid, p_kind, p_net, p_kernel, p_proto, p_country, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64)) returning id into v_id;
  return v_id;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 3) spoof reading and location decision (pure reads, deterministic, no side effect)
-- ------------------------------------------------------------------------------------------------------------------------------
-- Score 0..100 from facts the database already holds. >= 60 = 'spoof', 30..59 = 'suspect'. The reasons are plain words for the screen.
create or replace function public._sess_spoof(p_uid uuid, p_device text, p_key_source text, p_key_fp text, p_ua text, p_hint text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_score integer := 0; v_reasons text[] := '{}'; v_prior text; v_had_key boolean;
begin
  -- 1 the browser says one thing, its engine proves another (a changed user-agent string cannot change the engine behind it)
  if p_ua not in ('unknown', 'other') and p_hint not in ('unknown', 'other') and p_ua <> p_hint then
    v_score := v_score + 60; v_reasons := array_append(v_reasons, 'claims_one_browser_proves_another'); end if;
  -- 2 the same device now presents a DIFFERENT key than the one it registered before (someone moved the session to another machine)
  select key_fp into v_prior from public.founder_session_registry where user_id = p_uid and device_hash = p_device and key_fp is not null order by created_at desc limit 1;
  v_had_key := v_prior is not null;
  if v_had_key and p_key_fp is not null and p_key_fp <> v_prior then v_score := v_score + 80; v_reasons := array_append(v_reasons, 'device_key_changed'); end if;
  if v_had_key and p_key_fp is null then v_score := v_score + 40; v_reasons := array_append(v_reasons, 'device_key_missing_on_keyed_device'); end if;
  -- 3 no device-bound key at all is weaker, not an attack
  if p_key_source = 'none' then v_score := v_score + 10; v_reasons := array_append(v_reasons, 'no_device_key'); end if;
  v_score := least(v_score, 100);
  return jsonb_build_object('score', v_score, 'level', case when v_score >= 60 then 'spoof' when v_score >= 30 then 'suspect' else 'ok' end, 'reasons', to_jsonb(v_reasons));
end $$;

-- Location boundary lock. A device that was admitted before is "known"; a refused registration never creates a row, so any row means admitted.
create or replace function public.founder_session_geo_check(p_uid uuid, p_country text, p_device_hash text) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare v_pol public.founder_session_policy%rowtype; v_known boolean; v_in boolean;
begin
  if p_country is not null and p_country !~ '^[A-Z]{2}$' then return jsonb_build_object('decision', 'deny', 'state', 'unknown_country', 'mode', 'enforce', 'known_device', false, 'why', 'shape'); end if;
  select * into v_pol from public.founder_session_policy where user_id = p_uid;
  if not found or v_pol.geo_mode = 'off' then return jsonb_build_object('decision', 'allow', 'state', 'off', 'mode', 'off', 'known_device', null); end if;
  v_known := p_device_hash is not null and exists (select 1 from public.founder_session_registry where user_id = p_uid and device_hash = p_device_hash);
  if p_country is null then
    return jsonb_build_object('decision', case when v_pol.geo_mode = 'enforce' and not v_known then 'deny' else 'allow' end, 'state', 'unknown_country', 'mode', v_pol.geo_mode, 'known_device', v_known,
                              'why', 'country_not_resolved'); end if;
  v_in := p_country = any (v_pol.countries);
  if v_in then return jsonb_build_object('decision', 'allow', 'state', 'allowed', 'mode', v_pol.geo_mode, 'known_device', v_known); end if;
  return jsonb_build_object('decision', case when v_pol.geo_mode = 'enforce' and not v_known then 'deny' else 'allow' end, 'state', 'observed_outside', 'mode', v_pol.geo_mode,
                            'known_device', v_known, 'why', 'outside_allowed_countries');
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 4) doors
-- ------------------------------------------------------------------------------------------------------------------------------
-- register: called by Rust at sign-in RELEASE with what the SERVER measured. Idempotent per session id.
create or replace function public.founder_session_register(p_uid uuid, p_sid_hash text, p_device_hash text, p_net_hash text, p_method text, p_protocol text, p_kernel text,
                                                          p_key_source text, p_key_fp text, p_ua_family text, p_hint_family text, p_country text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_geo jsonb; v_sp jsonb; v_pol public.founder_session_policy%rowtype; v_state text; v_existing public.founder_session_registry%rowtype;
begin
  if p_uid is null or not public._sess_h64(p_sid_hash) or not public._sess_h64(p_device_hash) or not public._sess_h64(p_net_hash)
     or p_method is null or p_method not in ('password', 'passkey', 'magic_link') or coalesce(p_protocol, '') not in ('quic', 'h2', 'h1', 'unknown')
     or not public._sess_kernel_ok(p_kernel) or coalesce(p_key_source, '') not in ('dbsc', 'webcrypto', 'none')
     or (p_key_source = 'none' and p_key_fp is not null) or (p_key_source <> 'none' and not public._sess_h64(p_key_fp))
     or not public._sess_family(p_ua_family) or not public._sess_family(p_hint_family) or (p_country is not null and p_country !~ '^[A-Z]{2}$') then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', false, 'error', 'not_a_founder'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_session:reg:' || p_uid::text, 0));
  select * into v_existing from public.founder_session_registry where sid_hash = p_sid_hash;
  if found then
    if v_existing.user_id <> p_uid then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
    return jsonb_build_object('ok', true, 'decision', case when v_existing.revoked_at is null then 'allow' else 'deny' end, 'existing', true, 'spoof', jsonb_build_object('level', v_existing.spoof_level, 'score', v_existing.spoof_score));
  end if;

  v_geo := public.founder_session_geo_check(p_uid, p_country, p_device_hash);
  if v_geo ->> 'decision' = 'deny' then
    perform public._sess_log(p_uid, p_sid_hash, 'geo_refused', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('why', v_geo ->> 'why', 'mode', v_geo ->> 'mode', 'method', p_method));
    return jsonb_build_object('ok', true, 'decision', 'deny', 'reason', 'location', 'geo', v_geo);
  end if;

  v_sp := public._sess_spoof(p_uid, p_device_hash, p_key_source, p_key_fp, p_ua_family, p_hint_family);
  select * into v_pol from public.founder_session_policy where user_id = p_uid;
  if v_sp ->> 'level' = 'spoof' and found and v_pol.spoof_action = 'block' then
    perform public._sess_log(p_uid, p_sid_hash, 'spoof_blocked', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('score', (v_sp ->> 'score')::integer, 'reasons', v_sp -> 'reasons'));
    return jsonb_build_object('ok', true, 'decision', 'deny', 'reason', 'spoof', 'spoof', v_sp);
  end if;

  v_state := coalesce(v_geo ->> 'state', 'off');
  insert into public.founder_session_registry (sid_hash, user_id, device_hash, net_hash, method, protocol, kernel_version, key_source, key_fp, ua_family, hint_family,
                                               spoof_score, spoof_level, spoof_reasons, country, geo_state)
  values (p_sid_hash, p_uid, p_device_hash, p_net_hash, p_method, p_protocol, p_kernel, p_key_source, p_key_fp, p_ua_family, p_hint_family,
          (v_sp ->> 'score')::integer, v_sp ->> 'level', coalesce(array(select jsonb_array_elements_text(v_sp -> 'reasons')), '{}'), p_country, v_state);
  perform public._sess_log(p_uid, p_sid_hash, 'registered', p_net_hash, p_kernel, p_protocol, p_country,
                           jsonb_build_object('method', p_method, 'key_source', p_key_source, 'key', left(coalesce(p_key_fp, ''), 16), 'ua', p_ua_family, 'hint', p_hint_family));
  if v_sp ->> 'level' <> 'ok' then
    perform public._sess_log(p_uid, p_sid_hash, 'spoof_alert', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('score', (v_sp ->> 'score')::integer, 'level', v_sp ->> 'level', 'reasons', v_sp -> 'reasons'));
  end if;
  if v_state = 'observed_outside' then
    perform public._sess_log(p_uid, p_sid_hash, 'geo_observed', p_net_hash, p_kernel, p_protocol, p_country, jsonb_build_object('mode', v_geo ->> 'mode', 'known_device', (v_geo ->> 'known_device')::boolean));
  end if;
  return jsonb_build_object('ok', true, 'decision', 'allow', 'existing', false, 'spoof', v_sp, 'geo', v_geo);
end $$;

-- touch: cheap, called when Rust has verified (or failed to verify) a request of this session. Tells Rust at once if the session was revoked.
create or replace function public.founder_session_touch(p_sid_hash text, p_net_hash text, p_protocol text, p_kernel text, p_verified boolean) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare r public.founder_session_registry%rowtype; v_logged boolean := false;
begin
  if not public._sess_h64(p_sid_hash) or not public._sess_h64(p_net_hash) or coalesce(p_protocol, '') not in ('quic', 'h2', 'h1', 'unknown') or not public._sess_kernel_ok(p_kernel) or p_verified is null then
    return jsonb_build_object('ok', false, 'state', 'shape'); end if;
  select * into r from public.founder_session_registry where sid_hash = p_sid_hash for update;
  if not found then return jsonb_build_object('ok', false, 'state', 'unknown'); end if;
  if r.revoked_at is not null then return jsonb_build_object('ok', false, 'state', 'revoked'); end if;
  if r.protocol <> p_protocol and p_protocol <> 'unknown' then
    perform public._sess_log(r.user_id, r.sid_hash, 'protocol_changed', p_net_hash, p_kernel, p_protocol, r.country, jsonb_build_object('from', r.protocol, 'to', p_protocol)); v_logged := true; end if;
  if r.kernel_version <> p_kernel and p_kernel <> 'unknown' then
    perform public._sess_log(r.user_id, r.sid_hash, 'kernel_changed', p_net_hash, p_kernel, p_protocol, r.country, jsonb_build_object('from', r.kernel_version, 'to', p_kernel)); v_logged := true; end if;
  if r.net_hash <> p_net_hash then
    perform public._sess_log(r.user_id, r.sid_hash, 'net_changed', p_net_hash, p_kernel, p_protocol, r.country,
                             jsonb_build_object('known_net', exists (select 1 from public.founder_signin_nets n where n.user_id = r.user_id and n.net_hash = p_net_hash))); v_logged := true; end if;
  if not p_verified and (r.last_fail_at is null or r.last_fail_at < now() - interval '60 seconds') then
    perform public._sess_log(r.user_id, r.sid_hash, 'integrity_fail', p_net_hash, p_kernel, p_protocol, r.country, jsonb_build_object('fails_so_far', r.verified_fail + 1)); v_logged := true; end if;
  if not v_logged and r.last_ledger_at < now() - interval '5 minutes' then
    perform public._sess_log(r.user_id, r.sid_hash, 'seen', p_net_hash, p_kernel, p_protocol, r.country, '{}'::jsonb); v_logged := true; end if;
  update public.founder_session_registry set
         net_hash = p_net_hash, protocol = case when p_protocol = 'unknown' then protocol else p_protocol end, kernel_version = case when p_kernel = 'unknown' then kernel_version else p_kernel end,
         last_seen_at = greatest(now(), last_seen_at), last_ledger_at = case when v_logged then now() else last_ledger_at end,
         last_verified_at = case when p_verified then now() else last_verified_at end, verified_ok = verified_ok + (case when p_verified then 1 else 0 end),
         verified_fail = verified_fail + (case when p_verified then 0 else 1 end), last_fail_at = case when p_verified then last_fail_at else now() end
   where sid_hash = p_sid_hash;
  return jsonb_build_object('ok', true, 'state', 'live');
end $$;

-- the one-click nuke: registry row revoked, ledger row written, the device-bound key of that device revoked, all in one transaction (ms, not minutes)
create or replace function public.founder_session_revoke(p_uid uuid, p_sid_hash text, p_reason text default 'founder_nuke') returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare v_t0 timestamptz := clock_timestamp(); r record; v_reason text := case when p_reason in ('founder_nuke', 'integrity_fail') then p_reason else 'founder_nuke' end;
begin
  if p_uid is null or not public._sess_h64(p_sid_hash) then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  update public.founder_session_registry set revoked_at = now(), revoke_reason = v_reason
   where sid_hash = p_sid_hash and user_id = p_uid and revoked_at is null
  returning device_hash, net_hash, kernel_version, protocol, country into r;
  if not found then return jsonb_build_object('ok', false, 'revoked', 0, 'error', 'not_live'); end if;
  perform public._sess_log(p_uid, p_sid_hash, 'revoked', r.net_hash, r.kernel_version, r.protocol, r.country, jsonb_build_object('reason', v_reason));
  if to_regprocedure('public.founder_dbsc_revoke(uuid,text,text)') is not null then perform public.founder_dbsc_revoke(p_uid, r.device_hash, 'founder_revoked'); end if;
  return jsonb_build_object('ok', true, 'revoked', 1, 'ms', round(extract(epoch from clock_timestamp() - v_t0) * 1000, 2));
end $$;

create or replace function public.founder_session_revoke_others(p_uid uuid, p_keep_sid_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_t0 timestamptz := clock_timestamp(); r record; v_n integer := 0;
begin
  if p_uid is null or not public._sess_h64(p_keep_sid_hash) then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  for r in update public.founder_session_registry set revoked_at = now(), revoke_reason = 'founder_nuke_others'
            where user_id = p_uid and sid_hash <> p_keep_sid_hash and revoked_at is null
        returning sid_hash, device_hash, net_hash, kernel_version, protocol, country loop
    perform public._sess_log(p_uid, r.sid_hash, 'revoked', r.net_hash, r.kernel_version, r.protocol, r.country, jsonb_build_object('reason', 'founder_nuke_others'));
    if to_regprocedure('public.founder_dbsc_revoke(uuid,text,text)') is not null and not exists
       (select 1 from public.founder_session_registry k where k.user_id = p_uid and k.sid_hash = p_keep_sid_hash and k.device_hash = r.device_hash) then
      perform public.founder_dbsc_revoke(p_uid, r.device_hash, 'founder_revoked'); end if;
    v_n := v_n + 1;
  end loop;
  perform public._sess_log(p_uid, p_keep_sid_hash, 'nuke_others', null, null, null, null, jsonb_build_object('count', v_n));
  return jsonb_build_object('ok', true, 'revoked', v_n, 'ms', round(extract(epoch from clock_timestamp() - v_t0) * 1000, 2));
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 5) the screen's data: sessions board, ledger page, chain verify
-- ------------------------------------------------------------------------------------------------------------------------------
-- integrity word for one session: never (nothing verified yet) | failed (the latest check failed) | stale (older than the policy) | verified
create or replace function public._sess_integrity(p_last_ok timestamptz, p_last_fail timestamptz, p_stale_s integer) returns text
language sql stable set search_path = pg_catalog as $$
  select case when p_last_fail is not null and (p_last_ok is null or p_last_fail >= p_last_ok) then 'failed'
              when p_last_ok is null then 'never'
              when p_last_ok < now() - make_interval(secs => p_stale_s) then 'stale'
              else 'verified' end $$;

create or replace function public.founder_sessions_board(p_uid uuid, p_current_sid_hash text default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '10s' as $$
declare v_pol public.founder_session_policy%rowtype; v_stale integer; v_rows jsonb; v_live integer; v_spoof integer; v_chain jsonb;
begin
  if p_uid is null then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into v_pol from public.founder_session_policy where user_id = p_uid;
  v_stale := coalesce(v_pol.stale_after_s, 900);
  select coalesce(jsonb_agg(x order by (x ->> 'live')::boolean desc, x ->> 'last_seen_at' desc), '[]'::jsonb) into v_rows from (
    select jsonb_build_object(
      'sid', left(r.sid_hash, 12), 'sid_hash', r.sid_hash, 'current', (p_current_sid_hash is not null and r.sid_hash = p_current_sid_hash),
      'live', r.revoked_at is null, 'method', r.method,
      'device', left(r.device_hash, 12), 'key_source', r.key_source, 'key_fp', left(coalesce(r.key_fp, ''), 16),
      'claimed_browser', r.ua_family, 'proven_browser', r.hint_family,
      'spoof', jsonb_build_object('level', r.spoof_level, 'score', r.spoof_score, 'reasons', to_jsonb(r.spoof_reasons)),
      'protocol', r.protocol, 'path_badge', public._sess_path_badge(r.protocol), 'kernel', r.kernel_version,
      'integrity', jsonb_build_object('state', public._sess_integrity(r.last_verified_at, r.last_fail_at, v_stale), 'last_verified_at', r.last_verified_at, 'ok', r.verified_ok, 'fail', r.verified_fail),
      'country', r.country, 'geo_state', r.geo_state, 'created_at', r.created_at, 'last_seen_at', r.last_seen_at,
      'age_s', greatest(0, extract(epoch from now() - r.created_at))::bigint,
      'revoked_at', r.revoked_at, 'revoke_reason', r.revoke_reason) as x
    from public.founder_session_registry r
    where r.user_id = p_uid and (r.revoked_at is null or r.revoked_at > now() - interval '7 days')
    order by (r.revoked_at is null) desc, r.last_seen_at desc limit 60) q;
  select count(*) filter (where revoked_at is null), count(*) filter (where revoked_at is null and spoof_level <> 'ok') into v_live, v_spoof from public.founder_session_registry where user_id = p_uid;
  v_chain := public.founder_session_ledger_verify(2000);
  return jsonb_build_object('ok', true, 'sessions', v_rows, 'live', v_live, 'live_with_alert', v_spoof,
    'policy', jsonb_build_object('geo_mode', coalesce(v_pol.geo_mode, 'off'), 'countries', to_jsonb(coalesce(v_pol.countries, '{}'::text[])), 'spoof_action', coalesce(v_pol.spoof_action, 'alert'), 'stale_after_s', v_stale),
    'ledger_chain', v_chain,
    'limits', jsonb_build_array('hardware_identity_is_the_device_key_fingerprint', 'vpn_inside_an_allowed_country_passes_the_location_lock', 'integrity_is_the_last_real_verification_time'));
end $$;

create or replace function public.founder_session_ledger_page(p_uid uuid, p_limit integer default 50, p_before_id bigint default null) returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object('ok', true, 'rows', coalesce(jsonb_agg(jsonb_build_object('id', l.id, 'at_ms', l.ts_ms, 'kind', l.kind, 'sid', left(coalesce(l.sid_hash, ''), 12), 'net', left(coalesce(l.net_hash, ''), 12),
         'kernel', l.kernel_version, 'protocol', l.protocol, 'country', l.country, 'facts', l.facts) order by l.id desc), '[]'::jsonb))
    from (select * from public.founder_session_ledger where user_id = p_uid and (p_before_id is null or id < p_before_id) order by id desc limit least(greatest(coalesce(p_limit, 50), 1), 200)) l
$$;

create or replace function public.founder_session_ledger_verify(p_limit integer default 5000) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare r record; v_prev text := repeat('0', 64); v_n integer := 0; v_first boolean := true;
begin
  for r in select * from public.founder_session_ledger order by id asc limit least(greatest(coalesce(p_limit, 5000), 1), 100000) loop
    if v_first then v_prev := r.prev_hash; v_first := false; end if;
    if r.prev_hash <> v_prev then return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'prev_hash'); end if;
    if r.hash <> public._sess_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.sid_hash, r.kind, r.net_hash, r.kernel_version, r.protocol, r.country, r.facts) then
      return jsonb_build_object('ok', false, 'broken_at', r.id, 'why', 'hash'); end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', true, 'checked', v_n);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 6) policy (location lock, spoof action, stale window): every change goes into the chain; enforce is refused when it would lock him out right now
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_policy_set(p_uid uuid, p_geo_mode text, p_countries text[], p_spoof_action text, p_stale_after_s integer, p_current_country text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old public.founder_session_policy%rowtype; v_c text[];
begin
  if p_uid is null or coalesce(p_geo_mode, '') not in ('off', 'observe', 'enforce') or coalesce(p_spoof_action, '') not in ('alert', 'block')
     or p_stale_after_s is null or p_stale_after_s not between 30 and 86400 or not public._sess_countries_ok(coalesce(p_countries, '{}'::text[]))
     or (p_current_country is not null and p_current_country !~ '^[A-Z]{2}$')
     or p_reason is null or length(btrim(p_reason)) not between 8 and 200 or p_reason ~ '[\x00-\x1f\x7f<>]' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  if not exists (select 1 from public.founder_accounts where user_id = p_uid) then return jsonb_build_object('ok', false, 'error', 'not_a_founder'); end if;
  v_c := coalesce(p_countries, '{}'::text[]);
  if p_geo_mode = 'enforce' then
    if cardinality(v_c) = 0 then return jsonb_build_object('ok', false, 'error', 'enforce_needs_a_country'); end if;
    if p_current_country is null or not (p_current_country = any (v_c)) then return jsonb_build_object('ok', false, 'error', 'would_lock_you_out'); end if;
  end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_session:pol:' || p_uid::text, 0));
  select * into v_old from public.founder_session_policy where user_id = p_uid;
  insert into public.founder_session_policy (user_id, geo_mode, countries, spoof_action, stale_after_s, updated_at)
  values (p_uid, p_geo_mode, v_c, p_spoof_action, p_stale_after_s, now())
  on conflict (user_id) do update set geo_mode = excluded.geo_mode, countries = excluded.countries, spoof_action = excluded.spoof_action, stale_after_s = excluded.stale_after_s, updated_at = now();
  perform public._sess_log(p_uid, null, 'policy_changed', null, null, null, p_current_country,
         jsonb_build_object('geo_mode', p_geo_mode, 'countries', to_jsonb(v_c), 'spoof_action', p_spoof_action, 'stale_after_s', p_stale_after_s,
                            'was', coalesce(v_old.geo_mode, 'off'), 'reason', btrim(p_reason)));
  return jsonb_build_object('ok', true, 'geo_mode', p_geo_mode, 'countries', to_jsonb(v_c), 'spoof_action', p_spoof_action);
end $$;

-- housekeeping: a live session untouched for 30 days is closed as 'expired' (logged). Bounded and cheap.
create or replace function public.founder_session_tick() returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare r record; v_n integer := 0;
begin
  for r in select sid_hash, user_id, net_hash, kernel_version, protocol, country from public.founder_session_registry
            where revoked_at is null and last_seen_at < now() - interval '30 days' order by last_seen_at limit 200 for update skip locked loop
    update public.founder_session_registry set revoked_at = now(), revoke_reason = 'expired' where sid_hash = r.sid_hash;
    perform public._sess_log(r.user_id, r.sid_hash, 'expired', r.net_hash, r.kernel_version, r.protocol, r.country, '{}'::jsonb);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('expired', v_n);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 7) grants: every door is for service_role only
-- ------------------------------------------------------------------------------------------------------------------------------
revoke all on function public._sess_log(uuid, text, text, text, text, text, text, jsonb), public._sess_spoof(uuid, text, text, text, text, text),
  public.founder_session_geo_check(uuid, text, text),
  public.founder_session_register(uuid, text, text, text, text, text, text, text, text, text, text, text), public.founder_session_touch(text, text, text, text, boolean),
  public.founder_session_revoke(uuid, text, text), public.founder_session_revoke_others(uuid, text), public.founder_sessions_board(uuid, text),
  public.founder_session_ledger_page(uuid, integer, bigint), public.founder_session_ledger_verify(integer),
  public.founder_session_policy_set(uuid, text, text[], text, integer, text, text), public.founder_session_tick() from public, anon, authenticated;
grant execute on function public.founder_session_geo_check(uuid, text, text),
  public.founder_session_register(uuid, text, text, text, text, text, text, text, text, text, text, text), public.founder_session_touch(text, text, text, text, boolean),
  public.founder_session_revoke(uuid, text, text), public.founder_session_revoke_others(uuid, text), public.founder_sessions_board(uuid, text),
  public.founder_session_ledger_page(uuid, integer, bigint), public.founder_session_ledger_verify(integer),
  public.founder_session_policy_set(uuid, text, text[], text, integer, text, text), public.founder_session_tick() to service_role;

-- internal helpers: nobody calls them from outside, not even service_role (only the doors above, which run as their owner)
revoke all on function public._sess_log(uuid, text, text, text, text, text, text, jsonb), public._sess_spoof(uuid, text, text, text, text, text) from service_role;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 8) posture, read from the catalogs (the screen's "security posture" list shows exactly these facts, nothing more)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_posture155() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare
  v_doors text[] := array['public.founder_session_geo_check(uuid,text,text)', 'public.founder_session_register(uuid,text,text,text,text,text,text,text,text,text,text,text)',
    'public.founder_session_touch(text,text,text,text,boolean)', 'public.founder_session_revoke(uuid,text,text)', 'public.founder_session_revoke_others(uuid,text)',
    'public.founder_sessions_board(uuid,text)', 'public.founder_session_ledger_page(uuid,integer,bigint)', 'public.founder_session_ledger_verify(integer)',
    'public.founder_session_policy_set(uuid,text,text[],text,integer,text,text)', 'public.founder_session_tick()'];
  d text; v_all_sr boolean := true; v_none_open boolean := true; v_definer boolean := true; v_pinned boolean := true; v_oid oid; v_t text; v_tabs text[] := array['founder_session_registry', 'founder_session_policy', 'founder_session_ledger'];
  v_rls boolean := true; v_closed boolean := true; v_trig integer;
begin
  foreach d in array v_doors loop
    v_oid := to_regprocedure(d);
    if v_oid is null then v_all_sr := false; v_definer := false; v_pinned := false; continue; end if;
    if not has_function_privilege('service_role', v_oid, 'execute') then v_all_sr := false; end if;
    if has_function_privilege('anon', v_oid, 'execute') or has_function_privilege('authenticated', v_oid, 'execute') then v_none_open := false; end if;
    if not (select p.prosecdef from pg_proc p where p.oid = v_oid) then v_definer := false; end if;
    if not coalesce((select p.proconfig::text like '%search_path=%' from pg_proc p where p.oid = v_oid), false) then v_pinned := false; end if;
  end loop;
  foreach v_t in array v_tabs loop
    if not coalesce((select c.relrowsecurity from pg_class c where c.oid = ('public.' || v_t)::regclass), false) then v_rls := false; end if;
    if has_table_privilege('service_role', 'public.' || v_t, 'insert') or has_table_privilege('service_role', 'public.' || v_t, 'update') or has_table_privilege('service_role', 'public.' || v_t, 'delete')
       or has_table_privilege('anon', 'public.' || v_t, 'select') or has_table_privilege('authenticated', 'public.' || v_t, 'select') then v_closed := false; end if;
  end loop;
  select count(*) into v_trig from pg_trigger t where t.tgrelid = 'public.founder_session_ledger'::regclass and not t.tgisinternal
     and t.tgname in ('founder_session_ledger_guard', 'founder_session_ledger_stop', 'founder_session_ledger_stop_trunc');
  return jsonb_build_object(
    'tables_rls_on', v_rls, 'tables_closed_to_direct_writes', v_closed, 'ledger_append_only_triggers', v_trig = 3,
    'doors_service_role_only', v_all_sr and v_none_open, 'doors_definer', v_definer, 'doors_search_path_pinned', v_pinned,
    'internal_helpers_closed', not has_function_privilege('service_role', 'public._sess_log(uuid,text,text,text,text,text,text,jsonb)', 'execute'),
    'ledger_chain_verifies', (public.founder_session_ledger_verify(100000) ->> 'ok')::boolean);
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 9) selftest: a rolled-back end-to-end proof (his real sessions and rows are never touched, nothing persists)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_selftest155() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E155 selftest FAIL: unknown'; v_uid uuid; j jsonb; v_n integer;
  h1 text := encode(extensions.digest('e155-s1', 'sha256'), 'hex'); h2 text := encode(extensions.digest('e155-s2', 'sha256'), 'hex'); h3 text := encode(extensions.digest('e155-s3', 'sha256'), 'hex');
  h4 text := encode(extensions.digest('e155-s4', 'sha256'), 'hex'); h5 text := encode(extensions.digest('e155-s5', 'sha256'), 'hex'); h6 text := encode(extensions.digest('e155-s6', 'sha256'), 'hex');
  dA text := encode(extensions.digest('e155-devA', 'sha256'), 'hex'); dB text := encode(extensions.digest('e155-devB', 'sha256'), 'hex'); dC text := encode(extensions.digest('e155-devC', 'sha256'), 'hex');
  dD text := encode(extensions.digest('e155-devD', 'sha256'), 'hex'); dE text := encode(extensions.digest('e155-devE', 'sha256'), 'hex');
  nA text := encode(extensions.digest('e155-netA', 'sha256'), 'hex'); nB text := encode(extensions.digest('e155-netB', 'sha256'), 'hex');
  k1 text := encode(extensions.digest('e155-key1', 'sha256'), 'hex'); k2 text := encode(extensions.digest('e155-key2', 'sha256'), 'hex');
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E155 selftest SKIP: no founder account yet'; end if;
  begin
    -- shape: malformed input is refused before any table is touched
    if public.founder_session_register(v_uid, 'nope', dA, nA, 'passkey', 'quic', 'k1', 'dbsc', k1, 'chrome', 'chrome', 'PK') ->> 'ok' = 'true' then raise exception 'a malformed session id was accepted'; end if;
    if public.founder_session_register(v_uid, h1, dA, nA, 'passkey', 'quic', 'k1', 'none', k1, 'chrome', 'chrome', 'PK') ->> 'ok' = 'true' then raise exception 'a key fingerprint with no key source was accepted'; end if;
    if public.founder_session_register(gen_random_uuid(), h1, dA, nA, 'passkey', 'quic', 'k1', 'dbsc', k1, 'chrome', 'chrome', 'PK') ->> 'error' <> 'not_a_founder' then raise exception 'a non-founder registered a session'; end if;

    -- 1 device A, honest browser, device key: registered, no alert; protocol badge, kernel, integrity
    j := public.founder_session_register(v_uid, h1, dA, nA, 'passkey', 'quic', 'kernel-1.0', 'dbsc', k1, 'chrome', 'chrome', 'PK');
    if j ->> 'decision' <> 'allow' or j #>> '{spoof,level}' <> 'ok' then raise exception 'an honest session was not simply allowed: %', j; end if;
    if public.founder_session_register(v_uid, h1, dA, nA, 'passkey', 'quic', 'kernel-1.0', 'dbsc', k1, 'chrome', 'chrome', 'PK') ->> 'existing' <> 'true' then raise exception 'registering twice made a second row'; end if;
    j := public.founder_session_touch(h1, nA, 'quic', 'kernel-1.0', true);
    if j ->> 'state' <> 'live' then raise exception 'touch of a live session failed'; end if;
    j := public.founder_sessions_board(v_uid, h1);
    if not exists (select 1 from jsonb_array_elements(j -> 'sessions') s where s ->> 'sid' = left(h1, 12) and (s ->> 'current')::boolean and s -> 'integrity' ->> 'state' = 'verified'
                    and s ->> 'path_badge' = 'HTTP/3 QUIC (WebTransport)') then raise exception 'the board does not show a verified current QUIC session'; end if;

    -- 2 spoof: the browser claims Firefox but proves Chrome
    j := public.founder_session_register(v_uid, h2, dB, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k2, 'firefox', 'chrome', 'PK');
    if j #>> '{spoof,level}' <> 'spoof' or j #>> '{spoof,reasons}' not like '%claims_one_browser_proves_another%' then raise exception 'a claimed-vs-proven browser mismatch was not flagged: %', j; end if;
    if not exists (select 1 from public.founder_session_ledger where sid_hash = h2 and kind = 'spoof_alert') then raise exception 'the spoof alert is not in the ledger'; end if;
    -- the same device A comes back with a DIFFERENT key (a session moved to another machine)
    j := public.founder_session_register(v_uid, h3, dA, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k2, 'chrome', 'chrome', 'PK');
    if j #>> '{spoof,reasons}' not like '%device_key_changed%' or j #>> '{spoof,level}' <> 'spoof' then raise exception 'a changed device key was not flagged: %', j; end if;

    -- 3 integrity: a failed verification is counted, shown as failed, and written once a minute at most
    perform public.founder_session_touch(h1, nA, 'quic', 'kernel-1.0', false);
    perform public.founder_session_touch(h1, nA, 'quic', 'kernel-1.0', false);
    select count(*) into v_n from public.founder_session_ledger where sid_hash = h1 and kind = 'integrity_fail';
    if v_n <> 1 then raise exception 'integrity failures were written % times in a minute, not once', v_n; end if;
    if (select verified_fail from public.founder_session_registry where sid_hash = h1) <> 2 then raise exception 'integrity failures are not all counted'; end if;
    if not exists (select 1 from jsonb_array_elements(public.founder_sessions_board(v_uid, h1) -> 'sessions') s where s ->> 'sid' = left(h1, 12) and s -> 'integrity' ->> 'state' = 'failed') then raise exception 'a failed check is not shown as failed'; end if;
    -- protocol, kernel and network changes are written
    perform public.founder_session_touch(h1, nB, 'h2', 'kernel-1.1', true);
    if (select count(*) from public.founder_session_ledger where sid_hash = h1 and kind in ('protocol_changed', 'kernel_changed', 'net_changed')) <> 3 then raise exception 'protocol / kernel / network changes were not all written'; end if;

    -- 4 location lock: refused enforce that would lock him out; observe lets a stranger country in but writes it; enforce refuses a NEW device, never a known one
    if public.founder_session_policy_set(v_uid, 'enforce', array['PK'], 'alert', 900, 'US', 'selftest lockout guard') ->> 'error' <> 'would_lock_you_out' then raise exception 'enforce that locks the founder out was accepted'; end if;
    if public.founder_session_policy_set(v_uid, 'enforce', '{}', 'alert', 900, 'PK', 'selftest empty list') ->> 'error' <> 'enforce_needs_a_country' then raise exception 'enforce with no country was accepted'; end if;
    if public.founder_session_policy_set(v_uid, 'observe', array['PK', 'PK'], 'alert', 900, 'PK', 'selftest duplicate') ->> 'error' <> 'shape' then raise exception 'a duplicate country list was accepted'; end if;
    if public.founder_session_policy_set(v_uid, 'observe', array['PK'], 'alert', 900, 'PK', 'x') ->> 'error' <> 'shape' then raise exception 'a reason shorter than 8 characters was accepted'; end if;
    j := public.founder_session_register(v_uid, h4, dC, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k1, 'chrome', 'chrome', 'US');
    if j ->> 'decision' <> 'allow' then raise exception 'policy off must allow'; end if;
    if public.founder_session_policy_set(v_uid, 'observe', array['PK'], 'alert', 900, 'PK', 'selftest observe mode') ->> 'ok' <> 'true' then raise exception 'observe could not be set'; end if;
    j := public.founder_session_register(v_uid, h5, dD, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k1, 'chrome', 'chrome', 'US');
    if j ->> 'decision' <> 'allow' or j #>> '{geo,state}' <> 'observed_outside' or not exists (select 1 from public.founder_session_ledger where sid_hash = h5 and kind = 'geo_observed') then raise exception 'observe did not allow-and-write: %', j; end if;
    if public.founder_session_policy_set(v_uid, 'enforce', array['PK'], 'alert', 900, 'PK', 'selftest enforce mode') ->> 'ok' <> 'true' then raise exception 'enforce could not be set from inside the country'; end if;
    j := public.founder_session_register(v_uid, h6, dE, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k1, 'chrome', 'chrome', 'US');
    if j ->> 'decision' <> 'deny' or j ->> 'reason' <> 'location' or exists (select 1 from public.founder_session_registry where sid_hash = h6) or not exists (select 1 from public.founder_session_ledger where sid_hash = h6 and kind = 'geo_refused') then
      raise exception 'enforce did not refuse a NEW device outside the country (and write it): %', j; end if;
    j := public.founder_session_register(v_uid, encode(extensions.digest('e155-s7', 'sha256'), 'hex'), dE, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k1, 'chrome', 'chrome', null);
    if j ->> 'decision' <> 'deny' then raise exception 'enforce let a NEW device with an unresolved country in'; end if;
    j := public.founder_session_register(v_uid, encode(extensions.digest('e155-s8', 'sha256'), 'hex'), dA, nA, 'password', 'h2', 'kernel-1.0', 'dbsc', k1, 'chrome', 'chrome', 'US');
    if j ->> 'decision' <> 'allow' then raise exception 'enforce refused a KNOWN device (it must only refuse new ones): %', j; end if;
    -- spoof action block
    if public.founder_session_policy_set(v_uid, 'off', '{}', 'block', 900, null, 'selftest spoof block') ->> 'ok' <> 'true' then raise exception 'spoof block could not be set'; end if;
    j := public.founder_session_register(v_uid, encode(extensions.digest('e155-s9', 'sha256'), 'hex'), dB, nA, 'password', 'h2', 'kernel-1.0', 'webcrypto', k2, 'firefox', 'chrome', 'PK');
    if j ->> 'decision' <> 'deny' or j ->> 'reason' <> 'spoof' then raise exception 'spoof_action block did not refuse a spoof: %', j; end if;

    -- 5 the nuke: one call, the session is dead for touch at once, the ledger has it, a revoked session never comes back
    j := public.founder_session_revoke(v_uid, h1);
    if j ->> 'ok' <> 'true' or (j ->> 'ms')::numeric > 1000 then raise exception 'revoke failed or took more than a second: %', j; end if;
    if public.founder_session_touch(h1, nA, 'quic', 'kernel-1.0', true) ->> 'state' <> 'revoked' then raise exception 'a revoked session could still be touched'; end if;
    if not exists (select 1 from public.founder_session_ledger where sid_hash = h1 and kind = 'revoked') then raise exception 'the revoke is not in the ledger'; end if;
    begin update public.founder_session_registry set revoked_at = null, revoke_reason = null where sid_hash = h1; raise exception 'a revoked session was brought back';
    exception when insufficient_privilege then null; end;
    j := public.founder_session_revoke_others(v_uid, h2);
    if j ->> 'ok' <> 'true' or exists (select 1 from public.founder_session_registry where user_id = v_uid and revoked_at is null and sid_hash <> h2) or (select revoked_at from public.founder_session_registry where sid_hash = h2) is not null then
      raise exception 'revoke_others did not keep exactly the chosen session: %', j; end if;

    -- 6 the ledger: append-only for everyone, the chain verifies, and a forged row is caught
    begin update public.founder_session_ledger set kind = 'seen' where sid_hash = h2; raise exception 'the ledger accepted an update';
    exception when insufficient_privilege then null; end;
    begin delete from public.founder_session_ledger where sid_hash = h2; raise exception 'the ledger accepted a delete';
    exception when insufficient_privilege then null; end;
    begin truncate public.founder_session_ledger; raise exception 'the ledger accepted a truncate';
    exception when insufficient_privilege then null; end;
    if public.founder_session_ledger_verify(100000) ->> 'ok' <> 'true' then raise exception 'the chain does not verify'; end if;
    if jsonb_array_length(public.founder_session_ledger_page(v_uid, 5, null) -> 'rows') <> 5 then raise exception 'the ledger page does not return rows'; end if;
    if (public.founder_session_posture155() ->> 'tables_closed_to_direct_writes')::boolean is not true or (public.founder_session_posture155() ->> 'ledger_append_only_triggers')::boolean is not true then raise exception 'the posture reading is wrong'; end if;

    v_msg := 'E155 selftest PASS (shape, spoof flag, device-key change, integrity counters, protocol/kernel/network changes, location lock observe+enforce+lockout guard, spoof block, instant nuke, append-only chain)';
    raise exception 'e155_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e155_rollback' then null; else v_msg := 'E155 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_session_posture155(), public.founder_session_selftest155() from public, anon, authenticated;
grant execute on function public.founder_session_posture155(), public.founder_session_selftest155() to service_role;
comment on table public.founder_session_registry is 'E155: one row per founder session. Written only by the founder_session_* doors. Identity frozen, counters forward only, revoked never returns.';
comment on table public.founder_session_ledger   is 'E155: append-only SHA-256 hash chain of session events. Never changed, never deleted.';
comment on table public.founder_session_policy   is 'E155: location boundary lock + spoof action + stale window per founder; every change is in the chain.';
