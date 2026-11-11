
-- E160 (11 Nov 2026 19:00 PKT, founder: "Device & sessions 100%") - a device key that was ROTATED through the authenticated registration path is not a theft.
-- PROOF (his CHECK_DRIFT_NOW v3): bindings replaced 17:25 / 17:47 / 18:10 (events 'registered' replaced:true), live sessions kept the old key fp, so
--   (a) every exchange of an older session = 'device_key_changed' drift (E156 founder_session_check), and
--   (b) every NEW session was scored 'spoof' 80/100 'device_key_changed' at sign-in (E155 _sess_spoof compared with the previous session of the device).
-- RULE (kept strict): a different key is still an alarm unless the presented key IS an active/known binding of THIS device that was registered AFTER the session being compared began.
--   A key that existed before that session, or no binding at all, stays drift/spoof. Registration itself is already a hash-chained event (founder_dbsc_events 'registered').
-- Nothing is dropped, no row is rewritten. The two E155/E156 functions are patched in place by exact-text replacement that RAISES if the text is not found (never a silent no-op).
-- 1) _sess_key_rotated  2) patched _sess_spoof + founder_session_check  3) posture160  4) selftest160 (rolled back)  5) CHECK_E160.sql

do $$ begin
  if to_regclass('public.founder_dbsc_sessions') is null or to_regclass('public.founder_session_registry') is null
     or to_regprocedure('public._sess_spoof(uuid,text,text,text,text,text)') is null or to_regprocedure('public.founder_session_check(text,text,text,text,boolean,text,text,text,text)') is null then
    raise exception 'E160 needs E149, E155 and E156 first'; end if;
end $$;

create or replace function public._sess_key_rotated(p_uid uuid, p_device text, p_key_fp text, p_since timestamptz default null) returns boolean
language sql stable security definer set search_path = pg_catalog, public as $$
  select p_key_fp is not null and exists (
    select 1 from public.founder_dbsc_sessions b
     where b.user_id = p_uid and b.device_hash = p_device
       and encode(sha256(convert_to(b.pub, 'UTF8')), 'hex') = p_key_fp
       and b.created_at > coalesce(p_since, (select max(r.created_at) from public.founder_session_registry r
                                              where r.user_id = p_uid and r.device_hash = p_device and r.key_fp is not null and r.key_fp <> p_key_fp), '-infinity'::timestamptz))
$$;
revoke all on function public._sess_key_rotated(uuid, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public._sess_key_rotated(uuid, text, text, timestamptz) to service_role;

do $$
declare d text; n text;
begin
  select pg_get_functiondef('public._sess_spoof(uuid,text,text,text,text,text)'::regprocedure) into d;
  if position('_sess_key_rotated' in d) = 0 then
    n := replace(d, 'if v_had_key and p_key_fp is not null and p_key_fp <> v_prior then', 'if v_had_key and p_key_fp is not null and p_key_fp <> v_prior and not public._sess_key_rotated(p_uid, p_device, p_key_fp) then');
    if n = d then raise exception 'E160: the E155 _sess_spoof text was not found (already changed?)'; end if;
    execute n;
  end if;
  select pg_get_functiondef('public.founder_session_check(text,text,text,text,boolean,text,text,text,text)'::regprocedure) into d;
  if position('_sess_key_rotated' in d) = 0 then
    n := replace(d, 'if p_key_fp is not null and r.key_fp is not null and p_key_fp <> r.key_fp then', 'if p_key_fp is not null and r.key_fp is not null and p_key_fp <> r.key_fp and not public._sess_key_rotated(r.user_id, r.device_hash, p_key_fp, r.created_at) then');
    if n = d then raise exception 'E160: the E156 founder_session_check text was not found (already changed?)'; end if;
    execute n;
  end if;
end $$;

create or replace function public.founder_session_posture160() returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'helper_exists', to_regprocedure('public._sess_key_rotated(uuid,text,text,timestamptz)') is not null,
    'spoof_uses_it', position('_sess_key_rotated' in pg_get_functiondef('public._sess_spoof(uuid,text,text,text,text,text)'::regprocedure)) > 0,
    'check_uses_it', position('_sess_key_rotated' in pg_get_functiondef('public.founder_session_check(text,text,text,text,boolean,text,text,text,text)'::regprocedure)) > 0,
    'check_still_flags_other_keys', pg_get_functiondef('public.founder_session_check(text,text,text,text,boolean,text,text,text,text)'::regprocedure) like '%''device_key_changed''%',
    'service_role_only', not has_function_privilege('anon', 'public._sess_key_rotated(uuid,text,text,timestamptz)', 'execute'))
$$;
revoke all on function public.founder_session_posture160() from public, anon, authenticated;
grant execute on function public.founder_session_posture160() to service_role;

create or replace function public.founder_session_selftest160() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '20s' as $$
declare v_msg text := 'E160 selftest FAIL: unknown'; v_uid uuid := gen_random_uuid(); v_dev text := repeat('c', 64); v_pub text := '04' || repeat('ab', 64); v_fp text;
begin
  begin
    v_fp := encode(sha256(convert_to(v_pub, 'UTF8')), 'hex');
    insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, source) values ('e160selftest0000001', v_uid, v_dev, v_pub, 'dbsc');
    if not public._sess_key_rotated(v_uid, v_dev, v_fp, now() - interval '1 hour') then raise exception 'a key registered after the session began is not seen as rotated'; end if;
    if public._sess_key_rotated(v_uid, v_dev, v_fp, now() + interval '1 hour') then raise exception 'a key that existed BEFORE the session counted as rotated'; end if;
    if public._sess_key_rotated(v_uid, v_dev, repeat('d', 64), now() - interval '1 hour') then raise exception 'an unknown key counted as rotated'; end if;
    if public._sess_key_rotated(v_uid, repeat('e', 64), v_fp, now() - interval '1 hour') then raise exception 'another device key counted as rotated'; end if;
    if public._sess_key_rotated(v_uid, v_dev, null, null) then raise exception 'a null key counted as rotated'; end if;
    if (select count(*) from jsonb_each_text(public.founder_session_posture160()) where value::boolean is not true) <> 0 then raise exception 'posture160 not all true: %', public.founder_session_posture160(); end if;
    v_msg := 'E160 selftest PASS';
    raise exception using errcode = 'P0160', message = v_msg;
  exception
    when sqlstate 'P0160' then return v_msg;
    when others then return 'E160 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_session_selftest160() from public, anon, authenticated;
grant execute on function public.founder_session_selftest160() to service_role;
