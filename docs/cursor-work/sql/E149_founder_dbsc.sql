
-- ==============================================================================================================================
-- E149 (K7, 9 Nov 2026) — FOUNDER: Device Bound Session Credentials (DBSC) ledger. Founder lane, SQL (advance level, Rule 38).
-- Rust (server/founder/src/dbsc.rs) speaks the Chrome DBSC protocol; THIS file is the memory and the rulebook:
--   1) founder_dbsc_sessions   one row per device-bound session: the browser's TPM-held PUBLIC key (ES256, 65-byte SEC1, hex), never a secret.
--                              Core columns frozen by trigger; revoked_at can only go NULL -> value; refresh_count only goes up.
--   2) founder_dbsc_jti        replay cache: every challenge/jti is accepted ONCE (unique). Only rows older than 1 day may be pruned.
--   3) founder_dbsc_events     append-only SHA-256 HASH CHAIN of what happened (registered / refreshed / revoked / rejects / would_block / blocked),
--                              advisory-locked, update/delete/truncate refused, reject spam capped per session (a stranger cannot flood it).
--   4) RPCs (service_role only, search_path + statement_timeout pinned): register, get, refreshed, device_state, event, revoke, devices, verify, report, selftest.
--   5) a revoked device (founder_devices.revoked_at) ends its bound sessions by TRIGGER, not by Rust remembering to.
-- PRIVACY (Rule 69 / FC18): no cookie value, no token, no IP, no user agent. Only ids, public key, counts, times, reasons.
-- Needs E102 + E104 first (founder_devices). Idempotent: safe to run twice.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:ddl', 0));
  if to_regclass('public.founder_devices') is null then raise exception 'E102/E104 pehle chalao (founder_devices nahi hai)' using errcode = '55000'; end if;

  create table if not exists public.founder_dbsc_sessions (
    sid           text primary key check (sid ~ '^[A-Za-z0-9_-]{16,64}$'),
    user_id       uuid        not null,
    device_hash   text        not null check (device_hash ~ '^[0-9a-f]{64}$'),
    pub           text        not null check (pub ~ '^04[0-9a-f]{128}$'),                       -- ES256 / P-256 uncompressed point: 04 || X || Y
    created_at    timestamptz not null default now(),
    last_refresh_at timestamptz,
    refresh_count integer     not null default 0 check (refresh_count >= 0),
    revoked_at    timestamptz,
    revoke_reason text check (revoke_reason is null or revoke_reason in ('replaced', 'device_revoked', 'founder_revoked', 'lost_key', 'selftest')),
    check ((revoked_at is null) = (revoke_reason is null))
  );
  create unique index if not exists founder_dbsc_sessions_one_active on public.founder_dbsc_sessions (user_id, device_hash) where revoked_at is null;
  create index if not exists founder_dbsc_sessions_created on public.founder_dbsc_sessions (created_at desc);

  create table if not exists public.founder_dbsc_jti (
    jti_hash text primary key check (jti_hash ~ '^[0-9a-f]{64}$'),
    purpose  text not null check (purpose in ('register', 'refresh')),
    seen_at  timestamptz not null default now()
  );
  create index if not exists founder_dbsc_jti_seen on public.founder_dbsc_jti (seen_at);

  create table if not exists public.founder_dbsc_events (
    id        bigint generated always as identity primary key,
    ts_ms     bigint not null check (ts_ms > 0),
    user_id   uuid   not null,                                                    -- no foreign key: deleting an account must never rewrite a ledger
    sid       text,
    kind      text   not null check (kind in ('registered', 'refreshed', 'revoked', 'reject_signature', 'reject_replay', 'reject_challenge', 'reject_key', 'would_block', 'blocked', 'allowed_bound', 'test')),
    facts     jsonb  not null default '{}'::jsonb check (jsonb_typeof(facts) = 'object' and octet_length(facts::text) <= 600),
    prev_hash text   not null check (prev_hash ~ '^[0-9a-f]{64}$'),
    hash      text   not null unique check (hash ~ '^[0-9a-f]{64}$')
  );
  create index if not exists founder_dbsc_events_user on public.founder_dbsc_events (user_id, id desc);
  create index if not exists founder_dbsc_events_sid on public.founder_dbsc_events (sid, kind, ts_ms desc);

  alter table public.founder_dbsc_sessions enable row level security;
  alter table public.founder_dbsc_jti      enable row level security;
  alter table public.founder_dbsc_events   enable row level security;
  revoke all on public.founder_dbsc_sessions, public.founder_dbsc_jti, public.founder_dbsc_events from public, anon, authenticated, service_role;
  grant select on public.founder_dbsc_sessions, public.founder_dbsc_events to service_role;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- guards: frozen core, one-way revoke, append-only chain
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._dbsc_stop() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin raise exception 'E149: this ledger is append-only, nothing is changed or deleted' using errcode = '42501'; end $$;

create or replace function public._dbsc_session_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E149: a DBSC session row is never deleted' using errcode = '42501'; end if;
  if new.sid <> old.sid or new.user_id <> old.user_id or new.device_hash <> old.device_hash or new.pub <> old.pub or new.created_at <> old.created_at then
    raise exception 'E149: the core of a DBSC session (sid, user, device, key, created) is frozen' using errcode = '42501'; end if;
  if old.revoked_at is not null and (new.revoked_at is distinct from old.revoked_at or new.revoke_reason is distinct from old.revoke_reason) then
    raise exception 'E149: a revoked session stays revoked' using errcode = '42501'; end if;
  if old.revoked_at is not null and new.refresh_count <> old.refresh_count then raise exception 'E149: a revoked session cannot refresh' using errcode = '42501'; end if;
  if new.refresh_count < old.refresh_count then raise exception 'E149: refresh_count only goes up' using errcode = '42501'; end if;
  return new;
end $$;
drop trigger if exists founder_dbsc_sessions_guard on public.founder_dbsc_sessions;
create trigger founder_dbsc_sessions_guard before update or delete on public.founder_dbsc_sessions for each row execute function public._dbsc_session_guard();
drop trigger if exists founder_dbsc_sessions_stop_trunc on public.founder_dbsc_sessions;
create trigger founder_dbsc_sessions_stop_trunc before truncate on public.founder_dbsc_sessions for each statement execute function public._dbsc_stop();

-- the replay cache may only lose rows older than one day (a challenge lives 60 s; a day is a wide margin)
create or replace function public._dbsc_jti_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'UPDATE' then raise exception 'E149: a seen challenge is never changed' using errcode = '42501'; end if;
  if tg_op = 'DELETE' and old.seen_at > now() - interval '1 day' then raise exception 'E149: a challenge younger than 1 day is never forgotten' using errcode = '42501'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists founder_dbsc_jti_guard on public.founder_dbsc_jti;
create trigger founder_dbsc_jti_guard before update or delete on public.founder_dbsc_jti for each row execute function public._dbsc_jti_guard();
drop trigger if exists founder_dbsc_jti_stop_trunc on public.founder_dbsc_jti;
create trigger founder_dbsc_jti_stop_trunc before truncate on public.founder_dbsc_jti for each statement execute function public._dbsc_stop();

create or replace function public._dbsc_event_hash(p_prev text, p_ts bigint, p_uid uuid, p_sid text, p_kind text, p_facts jsonb) returns text
language sql immutable set search_path = pg_catalog, public, extensions as $$
  select encode(extensions.digest(convert_to(p_prev || '|' || p_ts || '|' || p_uid::text || '|' || coalesce(p_sid, '-') || '|' || p_kind || '|' || p_facts::text, 'UTF8'), 'sha256'), 'hex')
$$;
create or replace function public._dbsc_event_guard() returns trigger language plpgsql set search_path = pg_catalog, public, extensions as $$
declare p public.founder_dbsc_events%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:chain', 0));
  select * into p from public.founder_dbsc_events order by id desc limit 1;
  new.ts_ms     := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  new.prev_hash := coalesce(p.hash, repeat('0', 64));
  new.hash      := public._dbsc_event_hash(new.prev_hash, new.ts_ms, new.user_id, new.sid, new.kind, new.facts);
  return new;
end $$;
drop trigger if exists founder_dbsc_events_guard on public.founder_dbsc_events;
create trigger founder_dbsc_events_guard before insert on public.founder_dbsc_events for each row execute function public._dbsc_event_guard();
drop trigger if exists founder_dbsc_events_stop on public.founder_dbsc_events;
create trigger founder_dbsc_events_stop before update or delete on public.founder_dbsc_events for each row execute function public._dbsc_stop();
drop trigger if exists founder_dbsc_events_stop_trunc on public.founder_dbsc_events;
create trigger founder_dbsc_events_stop_trunc before truncate on public.founder_dbsc_events for each statement execute function public._dbsc_stop();

-- internal logger. Reject spam is capped (50 per session per hour; unknown sessions are not logged at all by Rust) so a stranger cannot flood the chain.
create or replace function public._dbsc_log(p_uid uuid, p_sid text, p_kind text, p_facts jsonb default '{}'::jsonb) returns bigint
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_id bigint;
begin
  if p_kind like 'reject\_%' and p_sid is not null
     and (select count(*) from public.founder_dbsc_events where sid = p_sid and kind like 'reject\_%' and ts_ms > (extract(epoch from now() - interval '1 hour') * 1000)::bigint) >= 50 then
    return null;
  end if;
  insert into public.founder_dbsc_events (ts_ms, user_id, sid, kind, facts, prev_hash, hash)
  values (1, p_uid, p_sid, p_kind, coalesce(p_facts, '{}'::jsonb), repeat('0', 64), repeat('0', 64)) returning id into v_id;
  return v_id;
end $$;

-- a device that is revoked takes its bound sessions with it (trigger on founder_devices, not memory of the Rust side)
create or replace function public._dbsc_device_revoked() returns trigger language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r record;
begin
  if new.revoked_at is not null and old.revoked_at is null then
    for r in update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'device_revoked'
             where user_id = new.user_id and device_hash = new.ua_hash and revoked_at is null returning sid loop
      perform public._dbsc_log(new.user_id, r.sid, 'revoked', jsonb_build_object('reason', 'device_revoked'));
    end loop;
  end if;
  return new;
end $$;
drop trigger if exists founder_dbsc_device_revoked_trg on public.founder_devices;
create trigger founder_dbsc_device_revoked_trg after update of revoked_at on public.founder_devices for each row execute function public._dbsc_device_revoked();

-- ------------------------------------------------------------------------------------------------------------------------------
-- RPCs
-- ------------------------------------------------------------------------------------------------------------------------------
-- replay cache: true = first time seen (accepted), false = replay. Also prunes expired rows (cheap, bounded).
create or replace function public._dbsc_take_jti(p_jti_hash text, p_purpose text) returns boolean
language plpgsql security definer set search_path = pg_catalog, public as $$
declare v_n integer;
begin
  delete from public.founder_dbsc_jti where jti_hash in (select jti_hash from public.founder_dbsc_jti where seen_at < now() - interval '1 day' limit 200);
  insert into public.founder_dbsc_jti (jti_hash, purpose) values (p_jti_hash, p_purpose) on conflict do nothing;
  get diagnostics v_n = row_count;
  return v_n = 1;
end $$;

-- registration: the browser proved it holds the private key of p_pub (Rust verified the ES256 signature). One active session per device.
create or replace function public.founder_dbsc_register(p_uid uuid, p_device_hash text, p_sid text, p_pub text, p_jti_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old text;
begin
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' or p_pub is null or p_pub !~ '^04[0-9a-f]{128}$' or p_sid is null or p_sid !~ '^[A-Za-z0-9_-]{16,64}$' or p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:dev:' || p_uid::text || p_device_hash, 0));
  if not exists (select 1 from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash and approved_at is not null and revoked_at is null) then
    return jsonb_build_object('ok', false, 'error', 'device_not_approved'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'register') then
    perform public._dbsc_log(p_uid, null, 'reject_replay', jsonb_build_object('purpose', 'register'));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'replaced'
   where user_id = p_uid and device_hash = p_device_hash and revoked_at is null returning sid into v_old;
  if v_old is not null then perform public._dbsc_log(p_uid, v_old, 'revoked', jsonb_build_object('reason', 'replaced')); end if;
  insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub) values (p_sid, p_uid, p_device_hash, p_pub);
  perform public._dbsc_log(p_uid, p_sid, 'registered', jsonb_build_object('replaced', v_old is not null));
  return jsonb_build_object('ok', true, 'sid', p_sid, 'replaced', v_old is not null);
end $$;

-- lookup for refresh: only what Rust needs to check a signature
create or replace function public.founder_dbsc_get(p_sid text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce((select jsonb_build_object('found', true, 'uid', user_id, 'device_hash', device_hash, 'pub', pub, 'revoked', revoked_at is not null)
                     from public.founder_dbsc_sessions where sid = p_sid), jsonb_build_object('found', false))
$$;

-- refresh proof accepted by Rust: consume the challenge once, count it, log it
create or replace function public.founder_dbsc_refreshed(p_sid text, p_jti_hash text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare s public.founder_dbsc_sessions%rowtype;
begin
  if p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into s from public.founder_dbsc_sessions where sid = p_sid for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown'); end if;
  if s.revoked_at is not null then return jsonb_build_object('ok', false, 'error', 'revoked'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'refresh') then
    perform public._dbsc_log(s.user_id, s.sid, 'reject_replay', jsonb_build_object('purpose', 'refresh'));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  update public.founder_dbsc_sessions set refresh_count = refresh_count + 1, last_refresh_at = now() where sid = s.sid;
  perform public._dbsc_log(s.user_id, s.sid, 'refreshed', jsonb_build_object('n', s.refresh_count + 1));
  return jsonb_build_object('ok', true, 'n', s.refresh_count + 1);
end $$;

-- exchange asks: is this device bound? (the only thing the enforce rule needs)
create or replace function public.founder_dbsc_device_state(p_uid uuid, p_device_hash text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce((select jsonb_build_object('bound', true, 'sid', sid, 'since', created_at, 'refreshes', refresh_count, 'last_refresh_at', last_refresh_at)
                     from public.founder_dbsc_sessions where user_id = p_uid and device_hash = p_device_hash and revoked_at is null),
                  jsonb_build_object('bound', false))
$$;

-- Rust records decisions and rejects for KNOWN sessions only (kind list is CHECK-ed on the table)
create or replace function public.founder_dbsc_event(p_uid uuid, p_sid text, p_kind text, p_facts jsonb default '{}'::jsonb) returns boolean
language plpgsql security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
begin
  if p_kind not in ('reject_signature', 'reject_replay', 'reject_challenge', 'reject_key', 'would_block', 'blocked', 'allowed_bound') then return false; end if;
  if p_sid is null or not exists (select 1 from public.founder_dbsc_sessions where sid = p_sid and user_id = p_uid) then return false; end if;
  return public._dbsc_log(p_uid, p_sid, p_kind, coalesce(p_facts, '{}'::jsonb)) is not null;
end $$;

-- the founder (or a passkey-protected step later) ends a device's binding; it never touches the device approval itself
create or replace function public.founder_dbsc_revoke(p_uid uuid, p_device_hash text, p_reason text default 'founder_revoked') returns integer
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare r record; v_n integer := 0; v_reason text := case when p_reason in ('founder_revoked', 'lost_key') then p_reason else 'founder_revoked' end;
begin
  for r in update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = v_reason
           where user_id = p_uid and device_hash = p_device_hash and revoked_at is null returning sid loop
    perform public._dbsc_log(p_uid, r.sid, 'revoked', jsonb_build_object('reason', v_reason)); v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- the founder screen: every approved device of THIS founder and whether it is bound (real rows, nothing invented)
create or replace function public.founder_dbsc_devices(p_uid uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'label', d.label, 'bound', s.sid is not null, 'since', s.created_at,
           'refreshes', coalesce(s.refresh_count, 0), 'last_refresh_at', s.last_refresh_at) order by d.created_at), '[]'::jsonb)
    from public.founder_devices d
    left join public.founder_dbsc_sessions s on s.user_id = d.user_id and s.device_hash = d.ua_hash and s.revoked_at is null
   where d.user_id = p_uid and d.approved_at is not null and d.revoked_at is null
$$;

-- re-check the stored chain (newest p_limit rows, plus the link to the row before them)
create or replace function public.founder_dbsc_verify(p_limit integer default 1000) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '15s' as $$
declare r public.founder_dbsc_events%rowtype; v_prev text; v_n integer := 0; v_bad bigint; v_first bigint;
begin
  select min(id) into v_first from (select id from public.founder_dbsc_events order by id desc limit greatest(least(coalesce(p_limit, 1000), 20000), 1)) s;
  if v_first is null then return jsonb_build_object('ok', true, 'checked', 0); end if;
  select hash into v_prev from public.founder_dbsc_events where id < v_first order by id desc limit 1;
  v_prev := coalesce(v_prev, repeat('0', 64));
  for r in select * from public.founder_dbsc_events where id >= v_first order by id loop
    if r.prev_hash <> v_prev or r.hash <> public._dbsc_event_hash(r.prev_hash, r.ts_ms, r.user_id, r.sid, r.kind, r.facts) then v_bad := r.id; exit; end if;
    v_prev := r.hash; v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ok', v_bad is null, 'checked', v_n, 'broken_at', v_bad);
end $$;

-- one jsonb for the founder screen / CHECK: real counts only. p_uid null = whole system (CHECK), else that founder's own devices.
create or replace function public.founder_dbsc_report(p_uid uuid default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare v_since bigint := (extract(epoch from now() - interval '24 hours') * 1000)::bigint; v_out jsonb;
begin
  select jsonb_build_object(
    'sessions_active', (select count(*) from public.founder_dbsc_sessions where revoked_at is null and (p_uid is null or user_id = p_uid)),
    'sessions_total',  (select count(*) from public.founder_dbsc_sessions where (p_uid is null or user_id = p_uid)),
    'devices_approved', (select count(*) from public.founder_devices where approved_at is not null and revoked_at is null and (p_uid is null or user_id = p_uid)),
    'last_refresh_at', (select max(last_refresh_at) from public.founder_dbsc_sessions where (p_uid is null or user_id = p_uid)),
    'refreshes_24h',   (select count(*) from public.founder_dbsc_events where kind = 'refreshed' and ts_ms > v_since and (p_uid is null or user_id = p_uid)),
    'rejects_24h',     (select count(*) from public.founder_dbsc_events where kind like 'reject\_%' and ts_ms > v_since and (p_uid is null or user_id = p_uid)),
    'would_block_24h', (select count(*) from public.founder_dbsc_events where kind = 'would_block' and ts_ms > v_since and (p_uid is null or user_id = p_uid)),
    'blocked_24h',     (select count(*) from public.founder_dbsc_events where kind = 'blocked' and ts_ms > v_since and (p_uid is null or user_id = p_uid)),
    'chain', public.founder_dbsc_verify(1000)
  ) into v_out;
  v_out := v_out || jsonb_build_object('verdict', case
      when (v_out #>> '{chain,ok}') <> 'true' then 'chain_broken'
      when (v_out ->> 'sessions_active')::int = 0 then 'none_bound'
      when (v_out ->> 'rejects_24h')::int > 0 then 'watch'
      else 'bound' end);
  return v_out;
end $$;

-- behaviour selftest: everything is rolled back by a sentinel exception (nothing persists)
create or replace function public.founder_dbsc_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare
  v_uid uuid; v_dev text := encode(extensions.digest('e149-dev', 'sha256'), 'hex');
  v_pub text := '04' || repeat('ab', 64); v_sid text := 'e149selftestsid0001'; v_sid2 text := 'e149selftestsid0002';
  v_j1 text := encode(extensions.digest('e149-j1', 'sha256'), 'hex'); v_j2 text := encode(extensions.digest('e149-j2', 'sha256'), 'hex'); v_j3 text := encode(extensions.digest('e149-j3', 'sha256'), 'hex');
  v_r jsonb; v_ok boolean; v_msg text := 'E149 selftest FAIL: unknown';
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;   -- founder_devices has a foreign key to the real account
  if v_uid is null then return 'E149 selftest SKIP — no founder account'; end if;
  begin
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (v_uid, 'e149 selftest', v_dev, now());
    -- 1 register ok, replay refused, bad shape refused
    v_r := public.founder_dbsc_register(v_uid, v_dev, v_sid, v_pub, v_j1);
    if v_r ->> 'ok' <> 'true' then raise exception 'register: %', v_r; end if;
    if (public.founder_dbsc_register(v_uid, v_dev, v_sid2, v_pub, v_j1)) ->> 'error' <> 'replay' then raise exception 'replay of a challenge was accepted'; end if;
    if (public.founder_dbsc_register(v_uid, v_dev, 'x', v_pub, v_j2)) ->> 'error' <> 'shape' then raise exception 'bad shape accepted'; end if;
    if (public.founder_dbsc_register(v_uid, repeat('0', 64), v_sid2, v_pub, v_j2)) ->> 'error' <> 'device_not_approved' then raise exception 'unapproved device accepted'; end if;
    -- 2 device state + get
    if (public.founder_dbsc_device_state(v_uid, v_dev)) ->> 'bound' <> 'true' then raise exception 'device not bound after register'; end if;
    if (public.founder_dbsc_get(v_sid)) ->> 'pub' <> v_pub then raise exception 'get returned another key'; end if;
    -- 3 refresh once ok, replay refused, unknown refused
    if (public.founder_dbsc_refreshed(v_sid, v_j2)) ->> 'n' <> '1' then raise exception 'first refresh not counted'; end if;
    if (public.founder_dbsc_refreshed(v_sid, v_j2)) ->> 'error' <> 'replay' then raise exception 'refresh replay accepted'; end if;
    if (public.founder_dbsc_refreshed('nope-nope-nope-nope', v_j3)) ->> 'error' <> 'unknown' then raise exception 'unknown session refreshed'; end if;
    -- 4 second registration replaces the first (one active session per device)
    v_r := public.founder_dbsc_register(v_uid, v_dev, v_sid2, v_pub, v_j3);
    if v_r ->> 'replaced' <> 'true' then raise exception 'second registration did not replace'; end if;
    if (public.founder_dbsc_get(v_sid)) ->> 'revoked' <> 'true' then raise exception 'old session still live'; end if;
    -- 5 frozen core, one-way revoke, no delete
    begin update public.founder_dbsc_sessions set pub = '04' || repeat('cd', 64) where sid = v_sid2; raise exception 'key change allowed'; exception when sqlstate '42501' then null; end;
    begin update public.founder_dbsc_sessions set revoked_at = null, revoke_reason = null where sid = v_sid; raise exception 'un-revoke allowed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_dbsc_sessions where sid = v_sid2; raise exception 'delete allowed'; exception when sqlstate '42501' then null; end;
    begin update public.founder_dbsc_events set kind = 'test' where id = (select max(id) from public.founder_dbsc_events); raise exception 'event update allowed'; exception when sqlstate '42501' then null; end;
    begin delete from public.founder_dbsc_jti where jti_hash = v_j1; raise exception 'young jti deleted'; exception when sqlstate '42501' then null; end;
    -- 6 events: unknown session not logged, known one is, chain verifies
    if public.founder_dbsc_event(v_uid, 'ghost-ghost-ghost-ghost', 'reject_signature', '{}') then raise exception 'unknown session logged'; end if;
    if not public.founder_dbsc_event(v_uid, v_sid2, 'would_block', '{"why":"no cookie"}') then raise exception 'known session not logged'; end if;
    if (public.founder_dbsc_verify(1000)) ->> 'ok' <> 'true' then raise exception 'chain does not verify'; end if;
    -- 7 revoking the device ends its binding by trigger
    update public.founder_devices set revoked_at = now() where user_id = v_uid and ua_hash = v_dev;
    if (public.founder_dbsc_device_state(v_uid, v_dev)) ->> 'bound' <> 'false' then raise exception 'revoked device still bound'; end if;
    -- 8 device list shape + report shape
    if exists (select 1 from jsonb_array_elements(public.founder_dbsc_devices(v_uid)) e where e ->> 'label' = 'e149 selftest') then raise exception 'revoked device still listed'; end if;   -- the founder has other real devices: look only for ours
    v_r := public.founder_dbsc_report(v_uid);
    if not (v_r ? 'verdict' and v_r ? 'chain' and v_r ? 'sessions_active') then raise exception 'report shape'; end if;
    raise exception using errcode = 'P0001', message = 'E149_SELFTEST_OK';
  exception when others then
    if sqlerrm = 'E149_SELFTEST_OK' then v_msg := 'E149 selftest OK (register, replay, shape, device, refresh, replace, frozen core, append-only chain, trigger revoke, report) rolled back';
    else v_msg := 'E149 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public._dbsc_log(uuid, text, text, jsonb), public._dbsc_take_jti(text, text), public.founder_dbsc_register(uuid, text, text, text, text), public.founder_dbsc_get(text),
  public.founder_dbsc_refreshed(text, text), public.founder_dbsc_device_state(uuid, text), public.founder_dbsc_event(uuid, text, text, jsonb), public.founder_dbsc_revoke(uuid, text, text),
  public.founder_dbsc_verify(integer), public.founder_dbsc_report(uuid), public.founder_dbsc_selftest(), public.founder_dbsc_devices(uuid) from public, anon, authenticated;
grant execute on function public.founder_dbsc_register(uuid, text, text, text, text), public.founder_dbsc_get(text), public.founder_dbsc_refreshed(text, text), public.founder_dbsc_device_state(uuid, text),
  public.founder_dbsc_event(uuid, text, text, jsonb), public.founder_dbsc_revoke(uuid, text, text), public.founder_dbsc_verify(integer), public.founder_dbsc_report(uuid), public.founder_dbsc_selftest(), public.founder_dbsc_devices(uuid) to service_role;

select public.founder_dbsc_selftest() as selftest, public.founder_dbsc_report(null) as report;
