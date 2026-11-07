-- CHECK E145 — reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E145 vault.panic_lock is registered as tier 3 and built' as item,
       exists (select 1 from public.founder_action_tiers where action = 'vault.panic_lock' and tier = 3 and built) as ok, 1 as ord
union all select 'E145 the T3 door is open to service_role only; the raw panic is closed to service_role, anon and authenticated',
       has_function_privilege('service_role', 'public.founder_vault_panic_run(uuid,uuid,uuid,text)', 'execute')
       and not has_function_privilege('anon', 'public.founder_vault_panic_run(uuid,uuid,uuid,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_vault_panic_run(uuid,uuid,uuid,text)', 'execute')
       and not has_function_privilege('service_role', 'public.founder_vault_lease_panic(uuid,uuid)', 'execute')
       and not has_function_privilege('anon', 'public.founder_vault_lease_panic(uuid,uuid)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_vault_lease_panic(uuid,uuid)', 'execute'), 2
union all select 'E145 behaviour selftest (unapproved / wrong nonce / wrong device / other action refused, single use, others locked, halves shredded, audit, chains)',
       coalesce((select public.founder_vault_panic_selftest() like 'E145 selftest PASS%' or public.founder_vault_panic_selftest() like 'E145 selftest SKIP%'), false), 3
union all select 'E145 the E143 and E144 selftests still pass and the lease chain re-checks clean',
       coalesce((select public.founder_vault_lease_selftest() like 'E143 selftest PASS%' or public.founder_vault_lease_selftest() like 'E143 selftest SKIP%'), false)
       and coalesce((select public.founder_vault_lease_keysplit_selftest() like 'E144 selftest PASS%' or public.founder_vault_lease_keysplit_selftest() like 'E144 selftest SKIP%'), false)
       and coalesce((public.founder_vault_lease_verify(1000) ->> 'ok')::boolean, false), 4
) t order by ord;
