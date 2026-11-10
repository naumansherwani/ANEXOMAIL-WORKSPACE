
-- E157 - D2b-5: changing the session policy (location lock, spoof action, caps, idle/absolute limits) needs a FRESH passkey touch that signs the EXACT change.
-- Plan: docs/claude/G-MIX-D2B5-PLAN-11NOV.md (loopholes P1-P14). Builds on E117/E118 (step-up grants, action hash) and E156 (policy_set_v2). Nothing is dropped.
--   1) action `session.policy` = tier 2 in founder_action_tiers
--   2) founder_session_policy_digest(...)  ONE implementation of the canonical params + hash, plus a DRY RUN of the real change (rolled back) so the user is told "refused" BEFORE a touch
--   3) founder_session_policy_apply(...)   set_v2 FIRST, grant consume SECOND, one transaction: a bad grant rolls the change back, a bad shape never burns a grant
--   4) rate limit 5 changes/hour, no-op refused, session must be LIVE for this founder, service_role only
--   5) posture157 + selftest157 (rolled back) + CHECK_E157.sql
-- Prerequisites are checked, not assumed.
do $$ begin
  if to_regclass('public.founder_action_tiers') is null or to_regclass('public.founder_session_registry') is null
     or to_regprocedure('public.founder_session_policy_set_v2(uuid,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text)') is null
     or to_regprocedure('public._fp_consume_action(uuid,uuid,uuid,text,text,jsonb,text)') is null then
    raise exception 'E157 needs E118 and E156 first';
  end if;
end $$;

insert into public.founder_action_tiers (action, tier, label, built) values ('session.policy', 2, 'Change the sessions and location-lock policy', true)
on conflict (action) do update set tier = excluded.tier, label = excluded.label, built = excluded.built;

-- 2) canonical params: every value a short plain string; countries sorted so the same set always hashes the same
create or replace function public._sess_pol_params(p_sid_hash text, p_geo_mode text, p_countries text[], p_spoof_action text, p_stale_after_s integer, p_max_live integer,
  p_fail_limit integer, p_flap_limit integer, p_flap_action text, p_idle_s integer, p_absolute_s integer, p_current_country text, p_reason text) returns jsonb
language sql immutable set search_path = pg_catalog, public as $$
  select jsonb_build_object('sid', p_sid_hash, 'geo', p_geo_mode,
    'countries', coalesce((select string_agg(c, ',' order by c collate "C") from (select distinct c from unnest(coalesce(p_countries, '{}'::text[])) c) q), ''),
    'spoof', p_spoof_action, 'stale', p_stale_after_s::text, 'maxlive', p_max_live::text, 'faillimit', p_fail_limit::text, 'flaplimit', p_flap_limit::text,
    'flapact', p_flap_action, 'idle', p_idle_s::text, 'absolute', p_absolute_s::text, 'cc', coalesce(p_current_country, ''), 'reason', btrim(coalesce(p_reason, '')))
$$;

-- the real change, run and ROLLED BACK: returns the verdict set_v2 would give, plus no_change / rate / session checks
create or replace function public._sess_pol_dry(p_uid uuid, p_sid_hash text, p_geo_mode text, p_countries text[], p_spoof_action text, p_stale_after_s integer, p_max_live integer,
  p_fail_limit integer, p_flap_limit integer, p_flap_action text, p_idle_s integer, p_absolute_s integer, p_current_country text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare j jsonb; v_cur jsonb; v_new jsonb;
begin
  if p_sid_hash is null or not public._sess_h64(p_sid_hash)
     or not exists (select 1 from public.founder_session_registry where sid_hash = p_sid_hash and user_id = p_uid and revoked_at is null) then
    return jsonb_build_object('ok', false, 'error', 'session_not_live'); end if;
  if (select count(*) from public.founder_session_ledger where user_id = p_uid and kind = 'policy_changed' and ts_ms > (extract(epoch from now() - interval '1 hour') * 1000)::bigint) >= 5 then
    return jsonb_build_object('ok', false, 'error', 'too_many_changes'); end if;
  v_cur := public._sess_pol(p_uid);
  begin
    j := public.founder_session_policy_set_v2(p_uid, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason);
    if (j ->> 'ok') = 'true' then v_new := j -> 'policy'; end if;
    raise exception 'dry' using errcode = 'D2B5X';        -- undo whatever set_v2 wrote (policy row, ledger row, advisory lock)
  exception when sqlstate 'D2B5X' then null;
  end;
  if (j ->> 'ok') is distinct from 'true' then return coalesce(j, jsonb_build_object('ok', false, 'error', 'shape')); end if;
  if v_new = v_cur then return jsonb_build_object('ok', false, 'error', 'no_change'); end if;
  return jsonb_build_object('ok', true, 'current', v_cur, 'next', v_new);
end $$;

create or replace function public.founder_session_policy_digest(p_uid uuid, p_sid_hash text, p_geo_mode text, p_countries text[], p_spoof_action text, p_stale_after_s integer, p_max_live integer,
  p_fail_limit integer, p_flap_limit integer, p_flap_action text, p_idle_s integer, p_absolute_s integer, p_current_country text, p_reason text, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_dry jsonb; v_params jsonb;
begin
  perform public._fs_assert_founder(p_uid);
  v_dry := public._sess_pol_dry(p_uid, p_sid_hash, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason);
  if (v_dry ->> 'ok') <> 'true' then return v_dry; end if;
  v_params := public._sess_pol_params(p_sid_hash, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason);
  return jsonb_build_object('ok', true, 'action', 'session.policy', 'target', 'policy', 'params', v_params,
                            'hash', public.founder_action_hash('session.policy', 'policy', v_params, p_nonce), 'current', v_dry -> 'current', 'next', v_dry -> 'next');
end $$;

-- 3) the ONE door that applies it
create or replace function public.founder_session_policy_apply(p_uid uuid, p_device uuid, p_sid_hash text, p_grant uuid, p_nonce text, p_geo_mode text, p_countries text[], p_spoof_action text,
  p_stale_after_s integer, p_max_live integer, p_fail_limit integer, p_flap_limit integer, p_flap_action text, p_idle_s integer, p_absolute_s integer, p_current_country text, p_reason text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '8s' as $$
declare v_dry jsonb; j jsonb;
begin
  perform public._fp_assert_device(p_uid, p_device);
  perform pg_advisory_xact_lock(hashtextextended('founder_session:apply:' || p_uid::text, 0));        -- two applies for one founder never interleave
  v_dry := public._sess_pol_dry(p_uid, p_sid_hash, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason);
  if (v_dry ->> 'ok') <> 'true' then raise exception 'policy refused: %', v_dry ->> 'error' using errcode = '22023'; end if;     -- nothing consumed
  j := public.founder_session_policy_set_v2(p_uid, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason);
  if (j ->> 'ok') <> 'true' then raise exception 'policy refused: %', j ->> 'error' using errcode = '22023'; end if;
  perform public._fp_consume_action(p_uid, p_device, p_grant, 'session.policy', 'policy',
    public._sess_pol_params(p_sid_hash, p_geo_mode, p_countries, p_spoof_action, p_stale_after_s, p_max_live, p_fail_limit, p_flap_limit, p_flap_action, p_idle_s, p_absolute_s, p_current_country, p_reason), p_nonce);
  return jsonb_build_object('ok', true, 'policy', j -> 'policy', 'was', v_dry -> 'current');
end $$;

revoke all on function public._sess_pol_params(text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text),
  public._sess_pol_dry(uuid, text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text),
  public.founder_session_policy_digest(uuid, text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text, text),
  public.founder_session_policy_apply(uuid, uuid, text, uuid, text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text) from public, anon, authenticated, service_role;
grant execute on function public.founder_session_policy_digest(uuid, text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text, text),
  public.founder_session_policy_apply(uuid, uuid, text, uuid, text, text, text[], text, integer, integer, integer, integer, text, integer, integer, text, text) to service_role;

-- 5) posture + selftest
create or replace function public.founder_session_posture157() returns jsonb
language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare d text; v_oid oid; v_sr boolean := true; v_open boolean := false; v_def boolean := true; v_pin boolean := true;
begin
  foreach d in array array['public.founder_session_policy_digest(uuid,text,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text,text)',
    'public.founder_session_policy_apply(uuid,uuid,text,uuid,text,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text)'] loop
    v_oid := to_regprocedure(d);
    if v_oid is null then v_sr := false; v_def := false; v_pin := false; continue; end if;
    if not has_function_privilege('service_role', v_oid, 'execute') then v_sr := false; end if;
    if has_function_privilege('anon', v_oid, 'execute') or has_function_privilege('authenticated', v_oid, 'execute') then v_open := true; end if;
    if not (select p.prosecdef from pg_proc p where p.oid = v_oid) then v_def := false; end if;
    if not coalesce((select p.proconfig::text like '%search_path=%' from pg_proc p where p.oid = v_oid), false) then v_pin := false; end if;
  end loop;
  return jsonb_build_object('doors_service_role_only', v_sr and not v_open, 'doors_definer', v_def, 'doors_search_path_pinned', v_pin,
    'action_registered_t2', exists (select 1 from public.founder_action_tiers where action = 'session.policy' and tier = 2 and built),
    'helpers_closed', not has_function_privilege('service_role', 'public._sess_pol_dry(uuid,text,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text)', 'execute')
                      and not has_function_privilege('service_role', 'public._sess_pol_params(text,text,text[],text,integer,integer,integer,integer,text,integer,integer,text,text)', 'execute'));
end $$;

create or replace function public.founder_session_selftest157() returns text
language plpgsql security definer set search_path = pg_catalog, public, extensions set statement_timeout = '60s' as $$
declare
  v_msg text := 'E157 selftest FAIL: unknown'; u uuid; d uuid; j jsonb; g uuid; n text; h1 text; i integer; v_before jsonb; v_hw boolean;
  A1 constant text := 'SSSSSSSSSSSSSSSSSSSS1';
  s1 text := encode(extensions.digest('e157-s1', 'sha256'), 'hex'); s2 text := encode(extensions.digest('e157-s2', 'sha256'), 'hex');
  dh text := encode(extensions.digest('e157-d', 'sha256'), 'hex'); nh text := encode(extensions.digest('e157-n', 'sha256'), 'hex');
begin
  select user_id into u from public.founder_accounts order by user_id limit 1;
  if u is null then return 'E157 selftest SKIP: no founder account yet'; end if;
  begin
    select t2_hardware_only into v_hw from public.founder_protocol where id;
    update public.founder_protocol set t2_hardware_only = false where id;
    update public.founder_passkeys set revoked_at = now(), revoked_reason = 'selftest clean slate' where user_id = u and revoked_at is null;
    insert into public.founder_devices (user_id, label, ua_hash, approved_at) values (u, 'selftest e157', encode(extensions.digest('e157-dev', 'sha256'), 'hex'), now()) returning id into d;
    perform public.founder_passkey_add(u, d, A1, '{"c":"e157"}'::jsonb, 'E157 key', null);
    insert into public.founder_session_registry (sid_hash, user_id, device_hash, net_hash, method) values (s1, u, dh, nh, 'passkey');
    insert into public.founder_session_registry (sid_hash, user_id, device_hash, net_hash, method, revoked_at, revoke_reason) values (s2, u, dh, nh, 'passkey', now(), 'selftest');
    perform public.founder_session_policy_set_v2(u, 'off', '{}', 'alert', 900, 20, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest baseline policy');
    v_before := public._sess_pol(u);

    -- digest: dry run refuses bad shape / lock-out / dead session / no-op BEFORE any touch, and changes nothing
    n := 'n157aaaaaaaaaaaa01';
    if public.founder_session_policy_digest(u, s1, 'enforce', array['US'], 'alert', 900, 20, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest lockout check', n) ->> 'error' <> 'would_lock_you_out' then raise exception 'P4: lock-out reached the touch'; end if;
    if public.founder_session_policy_digest(u, s2, 'off', '{}', 'alert', 900, 15, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest dead session', n) ->> 'error' <> 'session_not_live' then raise exception 'P3/P11: a dead session got a digest'; end if;
    if public.founder_session_policy_digest(u, s1, 'off', '{}', 'alert', 900, 20, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest no change here', n) ->> 'error' <> 'no_change' then raise exception 'P9: a no-op got a digest'; end if;
    if public.founder_session_policy_digest(u, s1, 'off', '{}', 'alert', 900, 15, 10, 4, 'alert', 86400, 604800, 'PK', 'x', n) ->> 'error' <> 'shape' then raise exception 'P7: a short reason got a digest'; end if;
    if public._sess_pol(u) <> v_before then raise exception 'a dry run changed the policy'; end if;

    -- a good digest: hash equals an independent computation over the same canonical params
    j := public.founder_session_policy_digest(u, s1, 'observe', array['US','PK'], 'alert', 900, 15, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest observe mode', n);
    if (j ->> 'ok') <> 'true' or j #>> '{params,countries}' <> 'PK,US' then raise exception 'digest: %', left(j::text, 200); end if;
    h1 := public.founder_action_hash('session.policy', 'policy', j -> 'params', n);
    if h1 <> j ->> 'hash' then raise exception 'the digest hash is not the action hash'; end if;
    if public._sess_pol(u) <> v_before then raise exception 'a digest changed the policy'; end if;

    -- a grant for THAT digest applies it once
    g := (public.founder_stepup_issue(u, d, A1, 'session.policy', 'policy', j -> 'params', n) ->> 'grant')::uuid;
    -- P2 payload swap: same grant, one field changed -> refused, policy unchanged, grant NOT burnt
    if not public._fs_fails(format($q$select public.founder_session_policy_apply(%L,%L,%L,%L,%L,'observe',array['PK','US'],'alert',900,16,10,4,'alert',86400,604800,'PK','selftest observe mode')$q$, u, d, s1, g, n)) then raise exception 'P2: a swapped payload was accepted'; end if;
    if public._sess_pol(u) <> v_before then raise exception 'P2: the swapped payload changed the policy'; end if;
    -- wrong session
    if not public._fs_fails(format($q$select public.founder_session_policy_apply(%L,%L,%L,%L,%L,'observe',array['PK','US'],'alert',900,15,10,4,'alert',86400,604800,'PK','selftest observe mode')$q$, u, d, s2, g, n)) then raise exception 'P3: another session was accepted'; end if;
    j := public.founder_session_policy_apply(u, d, s1, g, n, 'observe', array['PK','US'], 'alert', 900, 15, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest observe mode');
    if (j ->> 'ok') <> 'true' or public._sess_pol(u) ->> 'geo_mode' <> 'observe' or (public._sess_pol(u) ->> 'max_live')::int <> 15 then raise exception 'the good grant did not apply: %', left(j::text, 200); end if;
    -- P1 replay
    if not public._fs_fails(format($q$select public.founder_session_policy_apply(%L,%L,%L,%L,%L,'observe',array['PK','US'],'alert',900,15,10,4,'alert',86400,604800,'PK','selftest observe mode')$q$, u, d, s1, g, n)) then raise exception 'P1: a grant was replayed'; end if;
    -- a grant for another action never works here
    n := 'n157aaaaaaaaaaaa02';
    g := (public.founder_stepup_issue(u, d, A1, 'recovery.codes', 'new batch', '{}'::jsonb, n) ->> 'grant')::uuid;
    if not public._fs_fails(format($q$select public.founder_session_policy_apply(%L,%L,%L,%L,%L,'observe',array['PK','US'],'alert',900,14,10,4,'alert',86400,604800,'PK','selftest other grant')$q$, u, d, s1, g, n)) then raise exception 'a grant for another action worked'; end if;
    -- P5 hardware-only: a platform key cannot even get the grant
    update public.founder_protocol set t2_hardware_only = true where id;
    if not public._fs_fails(format($q$select public.founder_stepup_issue(%L,%L,%L,'session.policy','policy','{}'::jsonb,'n157aaaaaaaaaaaa03')$q$, u, d, A1)) then raise exception 'P5: a platform key got a T2 grant under hardware-only'; end if;
    update public.founder_protocol set t2_hardware_only = false where id;

    -- P8 rate limit: 5 changes per hour in total (baseline + first apply + these three), the sixth is refused before a touch
    for i in 2..4 loop
      n := 'n157bbbbbbbbbbbb' || lpad(i::text, 2, '0');
      j := public.founder_session_policy_digest(u, s1, 'observe', array['PK','US'], 'alert', 900, 15 - i, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest rate limit ' || i, n);
      if (j ->> 'ok') <> 'true' then raise exception 'change % was refused: %', i, left(j::text, 200); end if;
      g := (public.founder_stepup_issue(u, d, A1, 'session.policy', 'policy', j -> 'params', n) ->> 'grant')::uuid;
      perform public.founder_session_policy_apply(u, d, s1, g, n, 'observe', array['PK','US'], 'alert', 900, 15 - i, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest rate limit ' || i);
    end loop;
    if public.founder_session_policy_digest(u, s1, 'observe', array['PK','US'], 'alert', 900, 9, 10, 4, 'alert', 86400, 604800, 'PK', 'selftest sixth change', 'n157cccccccccccc01') ->> 'error' <> 'too_many_changes' then raise exception 'P8: the sixth change in an hour was allowed'; end if;
    -- the ledger kept every change
    if (select count(*) from public.founder_session_ledger where user_id = u and kind = 'policy_changed' and facts ->> 'reason' like 'selftest%') < 5 then raise exception 'the ledger lacks the policy changes'; end if;
    if (public.founder_session_posture157() ->> 'doors_service_role_only')::boolean is not true or (public.founder_session_posture157() ->> 'action_registered_t2')::boolean is not true then raise exception 'posture157 wrong'; end if;

    v_msg := 'E157 selftest PASS (dry run, lock-out, dead session, no-op, short reason, hash = action hash, payload swap, wrong session, replay, other-action grant, hardware-only, rate limit, ledger)';
    raise exception 'e157_rollback' using errcode = 'P0001';
  exception when others then
    if sqlerrm = 'e157_rollback' then null; else v_msg := 'E157 selftest FAIL: ' || sqlerrm; end if;
  end;
  return v_msg;
end $$;

revoke all on function public.founder_session_posture157(), public.founder_session_selftest157() from public, anon, authenticated;
grant execute on function public.founder_session_posture157(), public.founder_session_selftest157() to service_role;
