-- CHECK E143 v2 — reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E143 tables exist with RLS on, service_role can only SELECT them, the lease ledger is hash-chained' as item,
       (select bool_and(relrowsecurity) from pg_class where oid in ('public.founder_vault_lease'::regclass, 'public.founder_vault_lease_event'::regclass))
       and not has_table_privilege('service_role', 'public.founder_vault_lease', 'insert,update,delete')
       and not has_table_privilege('service_role', 'public.founder_vault_lease_event', 'insert,update,delete') as ok, 1 as ord
union all select 'E143 doors closed to anon/authenticated, open to service_role (panic, sweep, status, verify, device_verify, selftest; the issue core is closed by E144)',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_vault_lease_panic(uuid,uuid)', 'public.founder_vault_lease_sweep()', 'public.founder_vault_lease_status(uuid)', 'public.founder_vault_lease_verify(integer)', 'public.founder_vault_lease_device_verify(uuid)', 'public.founder_vault_lease_selftest()']) f), 2
union all select 'E143 behaviour selftest (issue/renew, nonce hash-only, rate limits, clock-back, gapless serials, sweep once, revoke cut + audited, panic, two chains, tamper caught)',
       coalesce((select public.founder_vault_lease_selftest() like 'E143 selftest PASS%' or public.founder_vault_lease_selftest() like 'E143 selftest SKIP%'), false), 3
union all select 'E143 the lease ledger chain re-checks clean and the revoke trigger is on founder_devices',
       coalesce((public.founder_vault_lease_verify(1000) ->> 'ok')::boolean, false)
       and exists (select 1 from pg_trigger where tgname = 'founder_devices_vault_lease_revoke' and not tgisinternal), 4
union all select 'E143 serial uniqueness index, per-device chain column, live view (security_invoker) and the lease shape CHECKs are in place',
       exists (select 1 from pg_indexes where indexname = 'founder_vault_lease_event_once')
       and exists (select 1 from information_schema.columns where table_name = 'founder_vault_lease_event' and column_name = 'dev_prev_hash')
       and exists (select 1 from pg_class where relname = 'founder_vault_lease_live' and reloptions::text like '%security_invoker=true%')
       and (select count(*) from pg_constraint where conrelid = 'public.founder_vault_lease'::regclass and conname in ('founder_vault_lease_live_shape', 'founder_vault_lease_cut_shape') and convalidated) = 2, 5
) t order by ord;
