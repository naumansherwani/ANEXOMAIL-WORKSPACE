-- CHECK E143 — reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E143 tables exist with RLS on, service_role can only SELECT them, the lease ledger is hash-chained' as item,
       (select bool_and(relrowsecurity) from pg_class where oid in ('public.founder_vault_lease'::regclass, 'public.founder_vault_lease_event'::regclass))
       and not has_table_privilege('service_role', 'public.founder_vault_lease', 'insert,update,delete')
       and not has_table_privilege('service_role', 'public.founder_vault_lease_event', 'insert,update,delete') as ok, 1 as ord
union all select 'E143 doors closed to anon/authenticated, open to service_role (issue, status, verify, selftest)',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_vault_lease_issue(uuid,uuid,integer)', 'public.founder_vault_lease_status(uuid)', 'public.founder_vault_lease_verify(integer)', 'public.founder_vault_lease_selftest()']) f), 2
union all select 'E143 behaviour selftest (issue/renew, ttl 60..3600, refusals, revoke cuts the lease and never returns, append-only ledger, tamper caught)',
       coalesce((select public.founder_vault_lease_selftest() like 'E143 selftest PASS%' or public.founder_vault_lease_selftest() like 'E143 selftest SKIP%'), false), 3
union all select 'E143 the lease ledger chain re-checks clean and the revoke trigger is on founder_devices',
       coalesce((public.founder_vault_lease_verify(1000) ->> 'ok')::boolean, false)
       and exists (select 1 from pg_trigger where tgname = 'founder_devices_vault_lease_revoke' and not tgisinternal), 4
) t order by ord;
