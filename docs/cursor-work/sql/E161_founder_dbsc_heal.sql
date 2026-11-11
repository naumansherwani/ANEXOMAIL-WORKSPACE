
-- E161 (11 Nov 2026 19:40 PKT, founder: "yeh masla hamesha ke liye solve kero") - the DBSC loop that kept turning his Devices ring orange, closed for good.
-- PROOF (his CHECK_DRIFT_NOW + Chrome): every `reject_challenge` (a 400 on refresh) makes Chrome END its DBSC session for ever (cookie gone), the next exchange shows `would_block no_cookie`,
--   the old rule re-offered a key (binding replaced = churn), the 18:30 fix stopped the re-offer (so the device stayed cookie-less), and every sign-in without the cookie was scored
--   'device_key_missing_on_keyed_device' +40 and 'no_device_key' +10 (his new passkey session: Suspicious 50/100, "No key").
-- WHAT THIS DOES (SQL half; Rust half = dbsc.rs: refresh answers 403 + a fresh challenge instead of 400, and a chip binding that has been silent for 20 minutes IS offered a new registration):
--   1) founder_dbsc_device_state also returns idle_s = seconds since the binding last refreshed (or was made): Rust uses it to tell a LIVE chip binding from a dead one.
--   2) founder_session_key_attach HEALS: when a session that signed in without the key proves a key later, the two reasons the missing key caused (device_key_missing_on_keyed_device 40,
--      no_device_key 10) are removed and score/level recomputed. Every other reason (a different key, a claimed-vs-proved browser) stays. The change is in the hash-chained ledger as 'key_attached'.
-- Nothing is dropped, nothing rewritten but those two spoof columns; exact-text patches that RAISE when the old text is missing.

do $$ begin
  if to_regprocedure('public.founder_dbsc_device_state(uuid,text)') is null or to_regprocedure('public.founder_session_key_attach(text,text,text)') is null then
    raise exception 'E161 needs E150 and E158 first'; end if;
end $$;

do $$
declare d text; n text;
begin
  select pg_get_functiondef('public.founder_dbsc_device_state(uuid,text)'::regprocedure) into d;
  if position('idle_s' in d) = 0 then
    n := replace(d, '''last_refresh_at'', last_refresh_at)', '''last_refresh_at'', last_refresh_at, ''idle_s'', floor(extract(epoch from now() - coalesce(last_refresh_at, created_at)))::bigint)');
    if n = d then raise exception 'E161: the E150 founder_dbsc_device_state text was not found'; end if;
    execute n;
  end if;

  select pg_get_functiondef('public.founder_session_key_attach(text,text,text)'::regprocedure) into d;
  if position('v_rm' in d) = 0 then
    n := replace(d, 'declare r public.founder_session_registry%rowtype;', 'declare r public.founder_session_registry%rowtype; v_rm integer; v_new integer;');
    if n = d then raise exception 'E161: the E158 declare text was not found'; end if;
    d := n;
    n := replace(d, 'update public.founder_session_registry set key_source = p_key_source, key_fp = p_key_fp where sid_hash = p_sid_hash;',
      'v_rm := (case when ''device_key_missing_on_keyed_device'' = any(r.spoof_reasons) then 40 else 0 end) + (case when ''no_device_key'' = any(r.spoof_reasons) then 10 else 0 end);' || chr(10) ||
      '  v_new := greatest(0, r.spoof_score - v_rm);' || chr(10) ||
      '  update public.founder_session_registry set key_source = p_key_source, key_fp = p_key_fp,' || chr(10) ||
      '    spoof_reasons = array_remove(array_remove(r.spoof_reasons, ''device_key_missing_on_keyed_device''), ''no_device_key''), spoof_score = v_new,' || chr(10) ||
      '    spoof_level = case when v_new >= 60 then ''spoof'' when v_new >= 30 then ''suspect'' else ''ok'' end where sid_hash = p_sid_hash;');
    if n = d then raise exception 'E161: the E158 update text was not found'; end if;
    execute n;
  end if;
end $$;

create or replace function public.founder_dbsc_posture161() returns jsonb
language sql stable security definer set search_path = pg_catalog, public as $$
  select jsonb_build_object(
    'state_has_idle', position('idle_s' in pg_get_functiondef('public.founder_dbsc_device_state(uuid,text)'::regprocedure)) > 0,
    'attach_heals', position('v_rm' in pg_get_functiondef('public.founder_session_key_attach(text,text,text)'::regprocedure)) > 0,
    'attach_keeps_other_reasons', pg_get_functiondef('public.founder_session_key_attach(text,text,text)'::regprocedure) like '%array_remove(array_remove(r.spoof_reasons%',
    'attach_service_role_only', not has_function_privilege('anon', 'public.founder_session_key_attach(text,text,text)', 'execute'))
$$;
revoke all on function public.founder_dbsc_posture161() from public, anon, authenticated;
grant execute on function public.founder_dbsc_posture161() to service_role;

create or replace function public.founder_dbsc_selftest161() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '30s' as $$
declare
  v_msg text := 'E161 selftest FAIL: unknown'; v_uid uuid; j jsonb; r public.founder_session_registry%rowtype;
  s1 text := encode(extensions.digest('e161-s1', 'sha256'), 'hex'); s2 text := encode(extensions.digest('e161-s2', 'sha256'), 'hex'); d1 text := encode(extensions.digest('e161-d1', 'sha256'), 'hex');
  n1 text := encode(extensions.digest('e161-n1', 'sha256'), 'hex'); s3 text := encode(extensions.digest('e161-s3', 'sha256'), 'hex'); d2 text := encode(extensions.digest('e161-d2', 'sha256'), 'hex'); k1 text := encode(extensions.digest('e161-k1', 'sha256'), 'hex'); k2 text := encode(extensions.digest('e161-k2', 'sha256'), 'hex');
begin
  select user_id into v_uid from public.founder_accounts order by user_id limit 1;
  if v_uid is null then return 'E161 selftest SKIP: no founder account yet'; end if;
  begin
    -- 1) device_state reports how long the binding has been silent
    insert into public.founder_dbsc_sessions (sid, user_id, device_hash, pub, created_at, source) values ('e161selftest0000001', v_uid, d1, '04' || repeat('ab', 64), now() - interval '2 hours', 'dbsc');
    j := public.founder_dbsc_device_state(v_uid, d1);
    if (j ->> 'idle_s')::bigint < 7100 or (j ->> 'idle_s')::bigint > 7400 then raise exception 'idle_s is not about 2 hours: %', j; end if;
    -- 2) a keyed session, then a sign-in of the same device WITHOUT the key: flagged for the missing key
    j := public.founder_session_register(v_uid, s1, d1, n1, 'passkey', 'quic', 'k-1', 'dbsc', k1, 'chrome', 'chrome', 'PK');
    if j ->> 'decision' <> 'allow' then raise exception 'first register refused: %', j; end if;
    j := public.founder_session_register(v_uid, s2, d1, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'chrome', 'PK');
    select * into r from public.founder_session_registry where sid_hash = s2;
    if not ('device_key_missing_on_keyed_device' = any(r.spoof_reasons)) or r.spoof_score < 40 then raise exception 'the missing key was not flagged: %', r.spoof_reasons; end if;
    -- 3) the key is proved later: the two reasons caused by the missing key go, the score falls, the key is on the row
    j := public.founder_session_key_attach(s2, 'dbsc', k1);
    select * into r from public.founder_session_registry where sid_hash = s2;
    if j ->> 'attached' <> 'true' or r.key_fp <> k1 then raise exception 'attach failed: %', j; end if;
    if r.spoof_reasons && array['device_key_missing_on_keyed_device', 'no_device_key'] or r.spoof_score <> 0 or r.spoof_level <> 'ok' then raise exception 'the session was not healed: % % %', r.spoof_reasons, r.spoof_score, r.spoof_level; end if;
    -- 4) a different key is still an alarm after the attach (E158 rule kept)
    j := public.founder_session_check(s2, n1, 'quic', 'k-1', true, 'chrome', 'chrome', k2, 'PK');
    if j -> 'drift' ->> 0 <> 'device_key_changed' then raise exception 'a different key is no longer drift: %', j; end if;
    -- 5) the claimed-vs-proved browser reason is NOT healed by a key
    j := public.founder_session_register(v_uid, s3, d2, n1, 'passkey', 'quic', 'k-1', 'none', null, 'chrome', 'edge', 'PK');   -- claims Chrome, proves Edge, no key
    select * into r from public.founder_session_registry where sid_hash = s3;
    if not ('claims_one_browser_proves_another' = any(r.spoof_reasons)) or not ('no_device_key' = any(r.spoof_reasons)) then raise exception 'the browser mismatch was not flagged: % %', j, r.spoof_reasons; end if;
    j := public.founder_session_key_attach(s3, 'dbsc', k1);
    select * into r from public.founder_session_registry where sid_hash = s3;
    if r.spoof_reasons <> array['claims_one_browser_proves_another'] or r.spoof_score <> 60 or r.spoof_level <> 'spoof' then raise exception 'the browser mismatch was healed or the score is wrong: % % %', r.spoof_reasons, r.spoof_score, r.spoof_level; end if;
    if (public.founder_session_ledger_verify_tail(200) ->> 'ok')::boolean is not true then raise exception 'the ledger tail does not verify'; end if;
    if (select count(*) from jsonb_each_text(public.founder_dbsc_posture161()) where value::boolean is not true) <> 0 then raise exception 'posture161: %', public.founder_dbsc_posture161(); end if;
    v_msg := 'E161 selftest PASS';
    raise exception using errcode = 'P0161', message = v_msg;
  exception
    when sqlstate 'P0161' then return v_msg;
    when others then return 'E161 selftest FAIL: ' || sqlerrm;
  end;
end $$;
revoke all on function public.founder_dbsc_selftest161() from public, anon, authenticated;
grant execute on function public.founder_dbsc_selftest161() to service_role;
