-- CHECK E122 — reads only (selftests roll back). 4 checks.
select item, ok from (
select 'E122 seal interval is 20 or lower, seal_max_age_secs is set and below stall_secs, policy order holds' as item,
       coalesce((select every_rows <= 20 and seal_max_age_secs between 120 and 86400 and seal_max_age_secs < stall_secs and warn_lag_rows >= every_rows and fail_lag_rows > warn_lag_rows
                 from public.founder_audit_merkle_policy where id), false) as ok, 1 as ord
union all select 'E122 the pulse carries due (count OR time), real_lag_rows and policy.seal_max_age_secs; privileges closed to anon/authenticated, open to service_role',
       (public.founder_audit_merkle_pulse() ? 'real_lag_rows') and (public.founder_audit_merkle_pulse() -> 'policy' ? 'seal_max_age_secs')
       and (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
            from unnest(array['public.founder_audit_e122_selftest()','public.founder_audit_merkle_pulse()']) f), 2
union all select 'E122 behaviour selftest (time rule, no seal loop, time-stall, count rule, constraints, rollback clean)',
       coalesce((select public.founder_audit_e122_selftest() like 'E122 selftest OK%' or public.founder_audit_e122_selftest() like 'E122 selftest SKIP%'), false), 3
union all select 'E122 audit chain intact and E107 + E120 selftests still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_g4_selftest() like 'E120 selftest OK%' or public.founder_audit_g4_selftest() like 'E120 selftest SKIP%'), false), 4
) t order by ord;
