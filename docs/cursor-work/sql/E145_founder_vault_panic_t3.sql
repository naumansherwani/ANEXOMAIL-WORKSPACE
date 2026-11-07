-- E145 — Vault panic lock behind T3 (J8d). Layer: SQL (decisions) — the Rust door and the screen only carry the request.
-- What this adds on top of E118 (T3), E143 (lease ledger + raw panic) and E144 (key split):
--   1) the action `vault.panic_lock` is registered as TIER 3 and built: two DIFFERENT allow-listed hardware keys, the 10-minute delay, the cancel window (all E118, unchanged).
--   2) founder_vault_panic_run(uid, device, request, nonce): the ONLY door to the panic. It consumes the approved T3 request (single use, digest re-checked: action + the kept device + nonce),
--      requires that the request was begun on THIS device, keeps exactly this device, revokes every other approved device (their leases are cut and their key halves shredded for ever by the E143/E144 triggers),
--      then PROVES the result inside the same transaction: no other approved device is left, no other live lease is left. If any proof fails the whole thing rolls back, T3 request included.
--   3) the raw founder_vault_lease_panic(uid, keep) is closed to service_role (like the E144 issue core). A re-run of E143 never reopens it.
--   4) the main audit chain gets one entry that names the T3 request, the kept device and the count.
--   5) selftest (rolls back) + CHECK_E145.sql.
-- Needs E118, E143, E144. Safe to run again.

do $$ begin
  if to_regclass('public.founder_t3_requests') is null or to_regprocedure('public.founder_t3_execute(uuid,uuid,uuid,text,text,jsonb,text)') is null then raise exception 'E145 needs E118 first'; end if;
  if to_regprocedure('public.founder_vault_lease_panic(uuid,uuid)') is null or to_regprocedure('public.founder_vault_lease_grant(uuid,uuid,text,bigint,integer)') is null then raise exception 'E145 needs E143 and E144 first'; end if;
end $$;

-- 1) the action is T3 and built ----------------------------------------------------------------------------------------------------------------------------
insert into public.founder_action_tiers (action, tier, label, built) values ('vault.panic_lock', 3, 'Panic lock: lock every other device''s vault', true)
on conflict (action) do update set tier = 3, label = excluded.label, built = true;

-- 2) the one door ------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_panic_run(p_uid uuid, p_device uuid, p_request uuid, p_nonce text) returns jsonb
language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare r public.founder_t3_requests%rowtype; v_res jsonb; v_left integer; v_live integer;
begin
  perform public._fp_assert_device(p_uid, p_device);
  perform pg_advisory_xact_lock(hashtextextended('founder_vault_panic:' || p_uid::text, 0));
  select * into r from public.founder_t3_requests where id = p_request and user_id = p_uid for update;
  if not found then raise exception 'E145: no such T3 request' using errcode = '42501'; end if;
  if r.action <> 'vault.panic_lock' then raise exception 'E145: this T3 request is for another action' using errcode = '42501'; end if;
  if r.device_id <> p_device then raise exception 'E145: the request was started on another device' using errcode = '42501'; end if;
  -- single use + digest re-check (action, the kept device as target, empty params, nonce); raises if not approved, already used, expired or for something else
  perform public.founder_t3_execute(p_uid, p_device, p_request, 'vault.panic_lock', p_device::text, '{}'::jsonb, p_nonce);
  v_res := public.founder_vault_lease_panic(p_uid, p_device);
  -- proof inside the same transaction: nothing but the kept device may still be approved, and no other lease may still be live
  select count(*) into v_left from public.founder_devices where user_id = p_uid and approved_at is not null and revoked_at is null and id <> p_device;
  select count(*) into v_live from public.founder_vault_lease l where l.user_id = p_uid and l.device_id <> p_device and l.revoked_ms is null and l.expires_ms > public._fh_now_ms();
  if v_left <> 0 or v_live <> 0 then raise exception 'E145: panic did not lock everything (devices left %, live leases left %)', v_left, v_live using errcode = 'XX001'; end if;
  perform public._fh_vl_audit(p_uid, 'vault.panic_t3', p_device::text, 'Panic lock executed through T3; every other device is locked for good', jsonb_build_object('request', p_request, 'locked', v_res -> 'locked', 'kept', p_device));
  return v_res || jsonb_build_object('request', p_request, 'kept', p_device);
end $$;

-- 3) close the raw door (and keep it closed when E143 is run again: E143 grants it only while this function does not exist) --------------------------------------
revoke all on function public.founder_vault_lease_panic(uuid, uuid) from public, anon, authenticated, service_role;
revoke all on function public.founder_vault_panic_run(uuid, uuid, uuid, text) from public, anon, authenticated;
grant execute on function public.founder_vault_panic_run(uuid, uuid, uuid, text) to service_role;

-- 5) selftest: rolls back ------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.founder_vault_panic_selftest() returns text language plpgsql security definer set search_path = pg_catalog, public, extensions as $$
declare v_uid uuid; v_me uuid := gen_random_uuid(); v_a uuid := gen_random_uuid(); v_b uuid := gen_random_uuid(); v_rq uuid := gen_random_uuid(); v_rq2 uuid := gen_random_uuid();
        v_n text := 'e145-nonce-0123456789'; v_h text; v_ok boolean; r text := ''; x jsonb; k text;
begin
  select user_id into v_uid from public.founder_accounts limit 1;
  if v_uid is null then return 'E145 selftest SKIP: founder_accounts is empty'; end if;
  begin
    perform set_config('anexo.vl_min_gap_ms', '0', true);
    insert into public.founder_devices (id, user_id, label, ua_hash, approved_at) values (v_me, v_uid, 'e145 me', repeat('1', 64), now()), (v_a, v_uid, 'e145 a', repeat('2', 64), now()), (v_b, v_uid, 'e145 b', repeat('3', 64), now());
    perform public.founder_vault_lease_issue(v_uid, v_a); perform public.founder_vault_lease_issue(v_uid, v_b);
    v_h := public.founder_action_hash('vault.panic_lock', v_me::text, '{}'::jsonb, v_n);
    -- a request that is not approved cannot run
    insert into public.founder_t3_requests (id, user_id, device_id, action, action_hash, first_credential, ready_at, expires_at) values (v_rq, v_uid, v_me, 'vault.panic_lock', v_h, 'cred-one', now() + interval '10 minutes', now() + interval '40 minutes');
    v_ok := false; begin perform public.founder_vault_panic_run(v_uid, v_me, v_rq, v_n); exception when others then v_ok := true; end; if not v_ok then raise exception 'panic ran without the second key'; end if;
    r := r || 'waiting request refused; ';
    update public.founder_t3_requests set state = 'approved', second_credential = 'cred-two', approved_at = now() where id = v_rq;
    -- wrong nonce / wrong device / wrong action are refused
    v_ok := false; begin perform public.founder_vault_panic_run(v_uid, v_me, v_rq, 'e145-other-nonce-012345'); exception when others then v_ok := true; end; if not v_ok then raise exception 'panic ran with another nonce'; end if;
    v_ok := false; begin perform public.founder_vault_panic_run(v_uid, v_a, v_rq, v_n); exception when others then v_ok := true; end; if not v_ok then raise exception 'panic ran from another device'; end if;
    r := r || 'wrong nonce / wrong device refused; ';
    -- the real run
    x := public.founder_vault_panic_run(v_uid, v_me, v_rq, v_n);
    if not (x ->> 'ok')::boolean or (x ->> 'locked')::int < 2 or (x ->> 'kept')::uuid <> v_me then raise exception 'panic result wrong: %', x; end if;
    if (select count(*) from public.founder_devices where id in (v_a, v_b) and revoked_at is not null) <> 2 or (select revoked_at from public.founder_devices where id = v_me) is not null then raise exception 'wrong devices locked'; end if;
    if (select count(*) from public.founder_vault_lease where device_id in (v_a, v_b) and revoked_ms is null) <> 0 then raise exception 'a lease survived the panic'; end if;
    if (select count(*) from public.founder_vault_lease where device_id in (v_a, v_b) and shred_nonce is not null) <> 0 then raise exception 'a key half survived the panic'; end if;
    r := r || 'panic locked the others, kept this one, shredded their halves; ';
    -- single use
    v_ok := false; begin perform public.founder_vault_panic_run(v_uid, v_me, v_rq, v_n); exception when others then v_ok := true; end; if not v_ok then raise exception 'the same T3 request ran twice'; end if;
    -- a T3 request for another action cannot be used here
    insert into public.founder_t3_requests (id, user_id, device_id, action, action_hash, first_credential, second_credential, state, approved_at, ready_at, expires_at)
      values (v_rq2, v_uid, v_me, 'control.kill_switch', public.founder_action_hash('control.kill_switch', v_me::text, '{}'::jsonb, v_n), 'c1', 'c2', 'approved', now(), now() + interval '10 minutes', now() + interval '40 minutes');
    v_ok := false; begin perform public.founder_vault_panic_run(v_uid, v_me, v_rq2, v_n); exception when others then v_ok := true; end; if not v_ok then raise exception 'another action''s T3 request panicked the vault'; end if;
    r := r || 'single use + other action refused; ';
    -- closed doors, audit, chains
    if has_function_privilege('service_role', 'public.founder_vault_lease_panic(uuid,uuid)', 'execute') then raise exception 'raw panic is open to service_role'; end if;
    if not exists (select 1 from public.founder_audit where action = 'vault.panic_t3' and actor = v_uid) then raise exception 'no audit entry'; end if;
    if not coalesce((public.founder_vault_lease_verify(1000) ->> 'ok')::boolean, false) then raise exception 'lease chain broken after panic'; end if;
    r := r || 'raw door closed, audit entry, chains clean; ';
    raise exception using errcode = 'P0001', message = 'E145 selftest PASS: ' || r;
  exception when others then
    if sqlerrm like 'E145 selftest PASS%' then return sqlerrm; end if;
    return 'E145 selftest FAIL: ' || sqlerrm || ' (after: ' || r || ')';
  end;
end $$;
revoke all on function public.founder_vault_panic_selftest() from public, anon, authenticated;
grant execute on function public.founder_vault_panic_selftest() to service_role;
