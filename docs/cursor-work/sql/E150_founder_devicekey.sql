
-- ==============================================================================================================================
-- E150 (K7b, 9 Nov 2026) — FOUNDER: a device-bound key for EVERY browser and phone (builds on E149; E149 is not touched, it stays re-runnable).
-- DBSC (E149) is Chromium + secure chip only. K7b: any browser makes a WebCrypto ECDSA P-256 key with extractable=false, registers the PUBLIC key,
-- and signs a proof (same ES256 JWT shape) on every founder-token exchange. This file adds:
--   1) founder_dbsc_sessions.source  ('dbsc' | 'webcrypto'), NOT NULL, CHECK-ed, FROZEN after insert (guard replaced),
--   2) founder_dbsc_register_src(...)  one door for both sources. A secure-chip session (dbsc) OUTRANKS a software key (webcrypto): a webcrypto
--      registration never replaces a live dbsc session ('kept'), a dbsc registration replaces a webcrypto one. One active session per device stays true,
--   3) founder_dbsc_device_state now also returns source + pub (Rust verifies the exchange proof against it),
--   4) founder_dbsc_devices / founder_dbsc_report show the source and a by_source count (real numbers only),
--   5) founder_devicekey_selftest()  behaviour test that rolls back (nothing persists), run by CHECK_E150.sql.
-- PRIVACY (Rule 69 / FC18): public key, ids, counts, times only. Needs E149 first. Idempotent.
-- ==============================================================================================================================
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$
begin
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:ddl', 0));
  if to_regclass('public.founder_dbsc_sessions') is null then raise exception 'E149 pehle chalao (founder_dbsc_sessions nahi hai)' using errcode = '55000'; end if;
  alter table public.founder_dbsc_sessions add column if not exists source text not null default 'dbsc';
  if not exists (select 1 from pg_constraint where conrelid = 'public.founder_dbsc_sessions'::regclass and conname = 'founder_dbsc_sessions_source_ck') then
    alter table public.founder_dbsc_sessions add constraint founder_dbsc_sessions_source_ck check (source in ('dbsc', 'webcrypto'));
  end if;
end $$;

-- E149 guard + the source column frozen too
create or replace function public._dbsc_session_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then raise exception 'E149: a DBSC session row is never deleted' using errcode = '42501'; end if;
  if new.sid <> old.sid or new.user_id <> old.user_id or new.device_hash <> old.device_hash or new.pub <> old.pub or new.created_at <> old.created_at or new.source <> old.source then
    raise exception 'E149: the core of a DBSC session (sid, user, device, key, source, created) is frozen' using errcode = '42501'; end if;
  if old.revoked_at is not null and (new.revoked_at is distinct from old.revoked_at or new.revoke_reason is distinct from old.revoke_reason) then
    raise exception 'E149: a revoked session stays revoked' using errcode = '42501'; end if;
  if old.revoked_at is not null and new.refresh_count <> old.refresh_count then raise exception 'E149: a revoked session cannot refresh' using errcode = '42501'; end if;
  if new.refresh_count < old.refresh_count then raise exception 'E149: refresh_count only goes up' using errcode = '42501'; end if;
  return new;
end $$;

-- one door for both sources
create or replace function public.founder_dbsc_register_src(p_uid uuid, p_device_hash text, p_sid text, p_pub text, p_jti_hash text, p_source text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old text; v_old_src text;
begin
  if p_source is null or p_source not in ('dbsc', 'webcrypto') then return jsonb_build_object('ok', false, 'error', 'source'); end if;
  if p_device_hash is null or p_device_hash !~ '^[0-9a-f]{64}$' or p_pub is null or p_pub !~ '^04[0-9a-f]{128}$' or p_sid is null or p_sid !~ '^[A-Za-z0-9_-]{16,64}$' or p_jti_hash is null or p_jti_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  perform pg_advisory_xact_lock(hashtextextended('founder_dbsc:dev:' || p_uid::text || p_device_hash, 0));
  if not exists (select 1 from public.founder_devices where user_id = p_uid and ua_hash = p_device_hash and approved_at is not null and revoked_at is null) then
    return jsonb_build_object('ok', false, 'error', 'device_not_approved'); end if;
  if not public._dbsc_take_jti(p_jti_hash, 'register') then
    perform public._dbsc_log(p_uid, null, 'reject_replay', jsonb_build_object('purpose', 'register', 'source', p_source));
    return jsonb_build_object('ok', false, 'error', 'replay'); end if;
  select sid, source into v_old, v_old_src from public.founder_dbsc_sessions where user_id = p_uid and device_hash = p_device_hash and revoked_at is null;
  if v_old is not null and v_old_src = 'dbsc' and p_source = 'webcrypto' then   -- the secure chip outranks a software key
    return jsonb_build_object('ok', true, 'kept', 'dbsc', 'sid', v_old); end if;
  if v_old is not null then
    update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'replaced' where sid = v_old;
    perform public._dbsc_log(p_uid, v_old, 'revoked', jsonb_build_object('reason', 'replaced', 'by', p_source)); end if;
  insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source) values (p_sid, p_uid, p_device_hash, p_pub, p_source);
  perform public._dbsc_log(p_uid, p_sid, 'registered', jsonb_build_object('replaced', v_old is not null, 'source', p_source));
  return jsonb_build_object('ok', true, 'sid', p_sid, 'replaced', v_old is not null, 'source', p_source);
end $$;

-- the exchange gate needs the key and the source of the active session
create or replace function public.founder_dbsc_device_state(p_uid uuid, p_device_hash text) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce((select jsonb_build_object('bound', true, 'sid', sid, 'source', source, 'pub', pub, 'since', created_at, 'refreshes', refresh_count, 'last_refresh_at', last_refresh_at)
                     from public.founder_dbsc_sessions where user_id = p_uid and device_hash = p_device_hash and revoked_at is null),
                  jsonb_build_object('bound', false))
$$;

create or replace function public.founder_dbsc_devices(p_uid uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public set statement_timeout = '5s' as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', d.id, 'label', d.label, 'bound', s.sid is not null, 'source', s.source, 'since', s.created_at,
           'refreshes', coalesce(s.refresh_count, 0), 'last_refresh_at', s.last_refresh_at) order by d.created_at), '[]'::jsonb)
    from public.founder_devices d
    left join public.founder_dbsc_sessions s on s.user_id = d.user_id and s.device_hash = d.ua_hash and s.revoked_at is null
   where d.user_id = p_uid and d.approved_at is not null and d.revoked_at is null
$$;

-- E149 report + by_source (kept in one jsonb; verdict logic unchanged)
create or replace function public.founder_dbsc_report(p_uid uuid default null) returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public set statement_timeout = '8s' as $$
declare v_since bigint := (extract(epoch from now() - interval '24 hours') * 1000)::bigint; v_out jsonb;
begin
  select jsonb_build_object(
    'sessions_active', (select count(*) from public.founder_dbsc_sessions where revoked_at is null and (p_uid is null or user_id = p_uid)),
    'sessions_total',  (select count(*) from public.founder_dbsc_sessions where (p_uid is null or user_id = p_uid)),
    'by_source', jsonb_build_object(
        'dbsc',      (select count(*) from public.founder_dbsc_sessions where revoked_at is null and source = 'dbsc' and (p_uid is null or user_id = p_uid)),
        'webcrypto', (select count(*) from public.founder_dbsc_sessions where revoked_at is null and source = 'webcrypto' and (p_uid is null or user_id = p_uid))),
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

-- behaviour selftest: rolled back by a sentinel exception. Uses the founder's REAL account (foreign key) and looks only for its OWN rows.
create or replace function public.founder_devicekey_selftest() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare
  v_uid uuid; v_dev text := encode(extensions.digest('e150-dev', 'sha256'), 'hex'); v_pub text := '04' || repeat('ab', 64);
  v_s1 text := 'e150selftestsid0001'; v_s2 text := 'e150selftestsid0002'; v_s3 text := 'e150selftestsid0003';
  v_j1 text := encode(extensions.digest('e150-j1', 'sha256'), 'hex'); v_j2 text := encode(extensions.digest('e150-j2', 'sha256'), 'hex'); v_j3 text := encode(extensions.digest('e150-j3', 'sha256'), 'hex');
  v_r jsonb; v_msg text := 'E150 selftest FAIL: unknown';
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E150 selftest SKIP — no founder account'; end if;
  begin
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (v_uid, 'e150 selftest', v_dev, now());
    -- 1 webcrypto registers, state shows source + key
    v_r := public.founder_dbsc_register_src(v_uid, v_dev, v_s1, v_pub, v_j1, 'webcrypto');
    if v_r ->> 'source' <> 'webcrypto' then raise exception 'webcrypto register: %', v_r; end if;
    if (public.founder_dbsc_device_state(v_uid, v_dev)) ->> 'source' <> 'webcrypto' or (public.founder_dbsc_device_state(v_uid, v_dev)) ->> 'pub' <> v_pub then raise exception 'state does not show source + key'; end if;
    -- 2 replay + bad source + bad shape refused
    if (public.founder_dbsc_register_src(v_uid, v_dev, v_s2, v_pub, v_j1, 'webcrypto')) ->> 'error' <> 'replay' then raise exception 'replay accepted'; end if;
    if (public.founder_dbsc_register_src(v_uid, v_dev, v_s2, v_pub, v_j2, 'tpm')) ->> 'error' <> 'source' then raise exception 'bad source accepted'; end if;
    if (public.founder_dbsc_register_src(v_uid, v_dev, 'x', v_pub, v_j2, 'dbsc')) ->> 'error' <> 'shape' then raise exception 'bad shape accepted'; end if;
    -- 3 a dbsc registration replaces the webcrypto one
    v_r := public.founder_dbsc_register_src(v_uid, v_dev, v_s2, v_pub, v_j2, 'dbsc');
    if v_r ->> 'replaced' <> 'true' or (public.founder_dbsc_get(v_s1)) ->> 'revoked' <> 'true' then raise exception 'dbsc did not replace webcrypto'; end if;
    -- 4 a webcrypto registration NEVER replaces a live dbsc session
    v_r := public.founder_dbsc_register_src(v_uid, v_dev, v_s3, v_pub, v_j3, 'webcrypto');
    if v_r ->> 'kept' <> 'dbsc' or (public.founder_dbsc_get(v_s2)) ->> 'revoked' <> 'false' or (public.founder_dbsc_get(v_s3)) ->> 'found' <> 'false' then raise exception 'webcrypto replaced a dbsc session: %', v_r; end if;
    -- 5 source is frozen
    begin update public.founder_dbsc_sessions set source = 'webcrypto' where sid = v_s2; raise exception 'source change allowed'; exception when sqlstate '42501' then null; end;
    -- 6 devices list + report show the source (only OUR device is asserted: the founder has other real ones)
    if not exists (select 1 from jsonb_array_elements(public.founder_dbsc_devices(v_uid)) e where e ->> 'label' = 'e150 selftest' and e ->> 'source' = 'dbsc' and (e ->> 'bound')::boolean) then raise exception 'devices list does not show our bound dbsc device'; end if;
    if not (public.founder_dbsc_report(v_uid) ? 'by_source') or (public.founder_dbsc_report(v_uid) #>> '{by_source,dbsc}')::int < 1 then raise exception 'report by_source'; end if;
    if (public.founder_dbsc_verify(1000)) ->> 'ok' <> 'true' then raise exception 'chain does not verify'; end if;
    raise exception using errcode = 'P0001', message = 'E150_SELFTEST_OK';
  exception when others then
    if sqlerrm = 'E150_SELFTEST_OK' then v_msg := 'E150 selftest OK (webcrypto register, key in state, replay/source/shape refused, dbsc outranks webcrypto, source frozen, devices + report by_source) rolled back';
    else v_msg := 'E150 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_dbsc_register_src(uuid, text, text, text, text, text), public.founder_devicekey_selftest() from public, anon, authenticated;
grant execute on function public.founder_dbsc_register_src(uuid, text, text, text, text, text), public.founder_devicekey_selftest() to service_role;

select public.founder_devicekey_selftest() as selftest, public.founder_dbsc_report(null) as report;
