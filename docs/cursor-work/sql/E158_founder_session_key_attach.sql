
-- E158 - K7 WIRE FIX: a founder session that was recorded WITHOUT a device key ('none') can be given its key ONCE, later, when Rust has really verified
-- that key (DBSC cookie or WebCrypto proof) on a later exchange of the SAME session. Before E158 the key of a session was frozen at sign-in, so a browser that
-- bound its key a second after signing in (or re-bound a dropped secure-chip session) stayed "No device key" on the Trust seal for the whole session. Nothing is dropped.
--   1) founder_session_key_attach(p_sid_hash, p_key_source, p_key_fp)  ONE door, service_role only: 'none' -> 'dbsc'|'webcrypto' + fingerprint, exactly once.
--      A session that already holds a key is NEVER changed by this door (a different proven key is 'device_key_changed' drift in founder_session_check, E156, not a swap here).
--   2) the E155 registry guard stays: the identity is frozen, EXCEPT this one transition none -> key (the guard itself allows only that transition, no other key change).
--   3) ledger kind 'key_attached' (hash chain untouched: the trigger of E155 computes the hash of the new row like every other row).
--   4) founder_dbsc_register_src: a dbsc chip session outranks a webcrypto key only while alive (30 min); a stale one (browser stopped refreshing) is replaced
--   5) posture158 + selftest158 (rolled back) + CHECK_E158.sql. Prerequisites are checked, not assumed.
do $$ begin
  if to_regclass('public.founder_session_registry') is null or to_regclass('public.founder_session_ledger') is null
     or to_regprocedure('public._sess_log(uuid,text,text,text,text,text,text,jsonb)') is null or to_regprocedure('public._sess_h64(text)') is null then
    raise exception 'E158 needs E155 + E156 first (founder_session_registry, founder_session_ledger, _sess_log, _sess_h64)'; end if;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 1) the ledger learns one more kind
-- ------------------------------------------------------------------------------------------------------------------------------
do $$ begin
  alter table public.founder_session_ledger drop constraint if exists founder_session_ledger_kind_ck;
  alter table public.founder_session_ledger add constraint founder_session_ledger_kind_ck check (kind in ('registered', 'seen', 'protocol_changed', 'kernel_changed', 'net_changed', 'spoof_alert',
    'spoof_blocked', 'geo_observed', 'geo_refused', 'integrity_fail', 'revoked', 'nuke_others', 'policy_changed', 'expired', 'net_flapping', 'identity_drift', 'geo_moved', 'session_cap', 'anchored',
    'key_attached'));
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 2) the registry guard: identity frozen, except none -> key, once
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public._sess_registry_guard() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare v_key_attach boolean;
begin
  if tg_op = 'DELETE' then raise exception 'E155: a session record is never deleted, it is revoked' using errcode = '42501'; end if;
  -- E158: the ONLY allowed change of the key columns is none/null -> ('dbsc'|'webcrypto', 64-hex fingerprint)
  v_key_attach := old.key_source = 'none' and old.key_fp is null and new.key_source in ('dbsc', 'webcrypto') and public._sess_h64(new.key_fp);
  if (new.sid_hash, new.user_id, new.device_hash, new.method, new.ua_family, new.hint_family, new.created_at)
     is distinct from (old.sid_hash, old.user_id, old.device_hash, old.method, old.ua_family, old.hint_family, old.created_at)
     or ((new.key_source, new.key_fp) is distinct from (old.key_source, old.key_fp) and not v_key_attach) then
    raise exception 'E155: the identity of a session is frozen' using errcode = '42501'; end if;
  if old.revoked_at is not null then raise exception 'E155: a revoked session never comes back' using errcode = '42501'; end if;
  if new.last_seen_at < old.last_seen_at or new.verified_ok < old.verified_ok or new.verified_fail < old.verified_fail then
    raise exception 'E155: times and counters only move forward' using errcode = '42501'; end if;
  return new;
end $$;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 3) the door
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_key_attach(p_sid_hash text, p_key_source text, p_key_fp text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '5s' as $$
declare r public.founder_session_registry%rowtype;
begin
  if not public._sess_h64(p_sid_hash) or coalesce(p_key_source, '') not in ('dbsc', 'webcrypto') or not public._sess_h64(p_key_fp) then
    return jsonb_build_object('ok', false, 'error', 'shape'); end if;
  select * into r from public.founder_session_registry where sid_hash = p_sid_hash for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'unknown'); end if;
  if r.revoked_at is not null then return jsonb_build_object('ok', false, 'error', 'closed'); end if;
  if r.key_source <> 'none' then   -- already keyed: same key = nothing to do, another key = never swapped here (E156 check reports it as drift)
    return jsonb_build_object('ok', true, 'attached', false, 'kept', r.key_source, 'same', r.key_fp = p_key_fp); end if;
  update public.founder_session_registry set key_source = p_key_source, key_fp = p_key_fp where sid_hash = p_sid_hash;
  perform public._sess_log(r.user_id, p_sid_hash, 'key_attached', r.net_hash, r.kernel_version, r.protocol, r.country,
                           jsonb_build_object('key_source', p_key_source, 'key', left(p_key_fp, 16)));
  return jsonb_build_object('ok', true, 'attached', true, 'key_source', p_key_source);
end $$;

revoke all on function public.founder_session_key_attach(text, text, text) from public, anon, authenticated;
grant execute on function public.founder_session_key_attach(text, text, text) to service_role;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 5) E158: the secure chip outranks a software key only while it is ALIVE (refreshed or created in the last 30 minutes); the DBSC cookie lives 10 minutes
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_dbsc_register_src(p_uid uuid, p_device_hash text, p_sid text, p_pub text, p_jti_hash text, p_source text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_old text; v_old_src text; v_live boolean;
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
  select sid, source, coalesce(last_refresh_at, created_at) > now() - interval '30 minutes' into v_old, v_old_src, v_live from public.founder_dbsc_sessions where user_id = p_uid and device_hash = p_device_hash and revoked_at is null;
  if v_old is not null and v_old_src = 'dbsc' and p_source = 'webcrypto' and coalesce(v_live, false) then   -- the secure chip outranks a software key ONLY while it is alive (E158: a chip session the browser stopped refreshing for 30 min is stale and may be replaced)
    return jsonb_build_object('ok', true, 'kept', 'dbsc', 'sid', v_old); end if;
  if v_old is not null then
    update public.founder_dbsc_sessions set revoked_at = now(), revoke_reason = 'replaced' where sid = v_old;
    perform public._dbsc_log(p_uid, v_old, 'revoked', jsonb_build_object('reason', 'replaced', 'by', p_source)); end if;
  insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source) values (p_sid, p_uid, p_device_hash, p_pub, p_source);
  perform public._dbsc_log(p_uid, p_sid, 'registered', jsonb_build_object('replaced', v_old is not null, 'source', p_source));
  return jsonb_build_object('ok', true, 'sid', p_sid, 'replaced', v_old is not null, 'source', p_source);
end $$;
revoke all on function public.founder_dbsc_register_src(uuid, text, text, text, text, text) from public, anon, authenticated;
grant execute on function public.founder_dbsc_register_src(uuid, text, text, text, text, text) to service_role;

-- ------------------------------------------------------------------------------------------------------------------------------
-- 6) posture158 (catalogs) + selftest158 (rolled back)
-- ------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_session_posture158() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public, extensions as $$
declare v_oid oid := to_regprocedure('public.founder_session_key_attach(text,text,text)');
begin
  return jsonb_build_object(
    'door_exists', v_oid is not null,
    'door_service_role_only', v_oid is not null and has_function_privilege('service_role', v_oid, 'execute')
        and not has_function_privilege('anon', v_oid, 'execute') and not has_function_privilege('authenticated', v_oid, 'execute'),
    'door_definer_pinned', v_oid is not null and (select p.prosecdef and p.proconfig::text like '%search_path=%' from pg_proc p where p.oid = v_oid),
    'ledger_kind_key_attached', exists (select 1 from pg_constraint where conrelid = 'public.founder_session_ledger'::regclass and conname = 'founder_session_ledger_kind_ck' and pg_get_constraintdef(oid) like '%key_attached%'),
    'guard_allows_only_none_to_key', (select pg_get_functiondef(p.oid) like '%v_key_attach%' from pg_proc p where p.oid = to_regprocedure('public._sess_registry_guard()')),
    'guard_still_on', exists (select 1 from pg_trigger where tgrelid = 'public.founder_session_registry'::regclass and tgname = 'founder_session_registry_guard'));
end $$;

create or replace function public.founder_session_selftest158() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E158 selftest FAIL: unknown'; v_uid uuid; j jsonb;
  s1 text := encode(extensions.digest('e158-s1', 'sha256'), 'hex'); d1 text := encode(extensions.digest('e158-d1', 'sha256'), 'hex'); n1 text := encode(extensions.digest('e158-n1', 'sha256'), 'hex');
  k1 text := encode(extensions.digest('e158-k1', 'sha256'), 'hex'); k2 text := encode(extensions.digest('e158-k2', 'sha256'), 'hex');
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E158 selftest SKIP: no founder account yet'; end if;
  begin
    if public.founder_session_key_attach('x', 'dbsc', k1) ->> 'error' <> 'shape' then raise exception 'a malformed attach was accepted'; end if;
    if public.founder_session_key_attach(s1, 'dbsc', k1) ->> 'error' <> 'unknown' then raise exception 'an unknown session was accepted'; end if;
    j := public.founder_session_register(v_uid, s1, d1, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    if j ->> 'decision' <> 'allow' then raise exception 'register refused: %', j; end if;
    if public.founder_session_key_attach(s1, 'tpm', k1) ->> 'error' <> 'shape' then raise exception 'an unknown key source was accepted'; end if;
    -- a direct update that swaps anything else is still refused by the guard
    begin
      update public.founder_session_registry set key_source = 'dbsc', key_fp = k1, device_hash = n1 where sid_hash = s1;
      raise exception 'the guard let the device change with the key';
    exception when insufficient_privilege then null; end;
    j := public.founder_session_key_attach(s1, 'webcrypto', k1);
    if j ->> 'attached' <> 'true' then raise exception 'the first attach did not attach: %', j; end if;
    if (select key_source || ':' || key_fp from public.founder_session_registry where sid_hash = s1) <> 'webcrypto:' || k1 then raise exception 'the key is not on the row'; end if;
    if not exists (select 1 from public.founder_session_ledger where sid_hash = s1 and kind = 'key_attached' and facts ->> 'key_source' = 'webcrypto') then raise exception 'key_attached is not in the ledger'; end if;
    j := public.founder_session_key_attach(s1, 'dbsc', k2);
    if j ->> 'attached' <> 'false' or j ->> 'kept' <> 'webcrypto' or j ->> 'same' <> 'false' then raise exception 'a second attach swapped the key: %', j; end if;
    if (select key_fp from public.founder_session_registry where sid_hash = s1) <> k1 then raise exception 'the key was swapped'; end if;
    begin
      update public.founder_session_registry set key_source = 'dbsc', key_fp = k2 where sid_hash = s1;
      raise exception 'the guard let a real key be swapped by a direct update';
    exception when insufficient_privilege then null; end;
    j := public.founder_session_check(s1, n1, 'quic', 'k-1', true, 'chrome', 'chrome', k2, 'PK');
    if j -> 'drift' ->> 0 <> 'device_key_changed' then raise exception 'a different proven key after attach is not drift: %', j; end if;
    perform public.founder_session_revoke(v_uid, s1, 'founder_nuke');
    if public.founder_session_key_attach(s1, 'dbsc', k1) ->> 'error' <> 'closed' then raise exception 'a revoked session accepted a key'; end if;
    if (public.founder_session_ledger_verify_tail(200) ->> 'ok')::boolean is not true then raise exception 'the ledger tail does not verify after key_attached'; end if;
    v_msg := 'E158 selftest PASS';
    raise exception using errcode = 'P0158', message = v_msg;   -- rolls everything back
  exception
    when sqlstate 'P0158' then return v_msg;
    when others then return 'E158 selftest FAIL: ' || sqlerrm;
  end;
end $$;

revoke all on function public.founder_session_posture158(), public.founder_session_selftest158() from public, anon, authenticated;
grant execute on function public.founder_session_posture158(), public.founder_session_selftest158() to service_role;
comment on function public.founder_session_key_attach(text, text, text) is 'E158 (K7 wire fix): gives a keyless founder session its verified device key ONCE (none -> dbsc|webcrypto); never swaps a key; writes key_attached into the session ledger.';
