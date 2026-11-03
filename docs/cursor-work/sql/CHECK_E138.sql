
-- CHECK E138 — reads only (the selftest rolls back). 6 checks.
select item, ok from (
select 'E138 policy, lease, tick log and serve log exist, RLS on, closed to anon/authenticated; both logs append-only and policy + lease read-only for service_role' as item,
       (select count(*) = 4 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_portable_tick_policy'::regclass, 'public.founder_portable_lease'::regclass,
                                                                                    'public.founder_portable_tick_log'::regclass, 'public.founder_portable_serve_log'::regclass))
       and not has_table_privilege('anon', 'public.founder_portable_tick_log', 'select') and not has_table_privilege('authenticated', 'public.founder_portable_serve_log', 'select')
       and not has_table_privilege('service_role', 'public.founder_portable_tick_log', 'update') and not has_table_privilege('service_role', 'public.founder_portable_tick_log', 'delete')
       and not has_table_privilege('service_role', 'public.founder_portable_serve_log', 'update') and not has_table_privilege('service_role', 'public.founder_portable_serve_log', 'delete')
       and not has_table_privilege('service_role', 'public.founder_portable_lease', 'update') and not has_table_privilege('service_role', 'public.founder_portable_tick_policy', 'update') as ok, 1 as ord
union all select 'E138 the guard triggers are all present and enabled (tick log, serve log, lease, policy)',
       (select count(*) from pg_trigger where not tgisinternal and tgenabled = 'O' and tgname in ('founder_ptick_log_guard', 'founder_ptick_log_stop', 'founder_ptick_log_stop_trunc',
          'founder_pserve_guard', 'founder_pserve_stop', 'founder_pserve_stop_trunc', 'founder_ptick_lease_guard', 'founder_ptick_lease_guard_trunc', 'founder_ptick_policy_guard', 'founder_ptick_policy_guard_trunc')) = 10, 2
union all select 'E138 doors closed to anon/authenticated, open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_portable_bundle_text()', 'public.founder_portable_lease_take(text,integer)', 'public.founder_portable_tick(text)', 'public.founder_portable_tick_fail(text,text)',
                          'public.founder_portable_serve(uuid)', 'public.founder_portable_tick_pulse(bigint)', 'public.founder_portable_status()', 'public.founder_portable_tick_verify(integer)',
                          'public.founder_portable_e138_selftest()']) f), 3
union all select 'E138 behaviour selftest (policy CHECKs, lease fencing epoch, tick outcomes + heartbeat de-dup, failure chain, stale/fail levels, canonical text + sha, serve throttle, worst level, tamper detection, rollback clean)',
       coalesce((select public.founder_portable_e138_selftest() like 'E138 selftest OK%' or public.founder_portable_e138_selftest() like 'E138 selftest SKIP%'), false), 4
union all select 'E138 stored tick log + serve log chains re-check clean (hash, consec_fail rule, epoch order, lease epoch >= every logged epoch), status answers',
       coalesce((public.founder_portable_tick_verify(500) ->> 'ok')::boolean, false) and (public.founder_portable_status() ? 'level'), 5
union all select 'E138 the audit chain and the E131 selftest are still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_portable_e131_selftest() like 'E131 selftest OK%' or public.founder_portable_e131_selftest() like 'E131 selftest SKIP%'), false), 6
) t order by ord;
