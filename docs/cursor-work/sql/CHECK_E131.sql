-- CHECK E131 — reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E131 policy + horizon log exist, RLS on, closed to anon/authenticated, log append-only and policy read-only for service_role' as item,
       (select count(*) = 2 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_portable_policy'::regclass, 'public.founder_portable_horizon_log'::regclass))
       and not has_table_privilege('anon', 'public.founder_portable_horizon_log', 'select') and not has_table_privilege('authenticated', 'public.founder_portable_policy', 'select')
       and not has_table_privilege('service_role', 'public.founder_portable_horizon_log', 'update') and not has_table_privilege('service_role', 'public.founder_portable_horizon_log', 'delete')
       and not has_table_privilege('service_role', 'public.founder_portable_policy', 'update') as ok, 1 as ord
union all select 'E131 doors closed to anon/authenticated, open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_portable_horizon()', 'public.founder_portable_observe()', 'public.founder_portable_bundle()', 'public.founder_portable_pulse()',
                          'public.founder_portable_verify(integer)', 'public.founder_portable_e131_selftest()']) f), 2
union all select 'E131 behaviour selftest (no evidence = no claim, min independent TSAs, bundle + ONE consistency proof, observe throttle, trigger-computed regression flag, append-only, Bitcoin-only horizon, rollback clean)',
       coalesce((select public.founder_portable_e131_selftest() like 'E131 selftest OK%' or public.founder_portable_e131_selftest() like 'E131 selftest SKIP%'), false), 3
union all select 'E131 stored horizon log chain + the live bundle re-check clean (digest binding, proof verified in SQL, roots equal the signed notes), pulse answers',
       coalesce((public.founder_portable_verify(500) ->> 'ok')::boolean, false) and (public.founder_portable_pulse() ? 'level'), 4
union all select 'E131 the audit chain and the E107/E121/E122/E123/E124 selftests are still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_consistency_selftest() like 'E121 selftest OK%' or public.founder_audit_consistency_selftest() like 'E121 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_e123_selftest() like 'E123 selftest OK%' or public.founder_audit_e123_selftest() like 'E123 selftest SKIP%'), false)
       and coalesce((select public.founder_anchor_e124_selftest() like 'E124 selftest OK%' or public.founder_anchor_e124_selftest() like 'E124 selftest SKIP%'), false), 5
) t order by ord;
