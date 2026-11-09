
-- CHECK E149 (K7 DBSC) — read-only except the selftest, which rolls back (nothing persists). Every row ok = true.
select item, ok from (
select 'E149 three tables exist, RLS on, anon/authenticated have no access' as item,
       (select bool_and(c.relrowsecurity and not has_table_privilege('anon', c.oid, 'select') and not has_table_privilege('authenticated', c.oid, 'select') and not has_table_privilege('service_role', c.oid, 'insert') and not has_table_privilege('service_role', c.oid, 'update') and not has_table_privilege('service_role', c.oid, 'delete'))
          from pg_class c where c.oid in (to_regclass('public.founder_dbsc_sessions'), to_regclass('public.founder_dbsc_jti'), to_regclass('public.founder_dbsc_events'))) as ok, 1 as ord
union all select 'E149 all 10 RPCs exist, only service_role may run them',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_dbsc_register(uuid,text,text,text,text)', 'public.founder_dbsc_get(text)', 'public.founder_dbsc_refreshed(text,text)', 'public.founder_dbsc_device_state(uuid,text)',
            'public.founder_dbsc_event(uuid,text,text,jsonb)', 'public.founder_dbsc_revoke(uuid,text,text)', 'public.founder_dbsc_verify(integer)', 'public.founder_dbsc_report(uuid)', 'public.founder_dbsc_selftest()', 'public.founder_dbsc_devices(uuid)']) f), 2
union all select 'E149 security definer RPCs have search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where proname in ('founder_dbsc_register', 'founder_dbsc_get', 'founder_dbsc_refreshed', 'founder_dbsc_device_state', 'founder_dbsc_event', 'founder_dbsc_revoke', 'founder_dbsc_verify', 'founder_dbsc_report', 'founder_dbsc_selftest', 'founder_dbsc_devices') and pronamespace = 'public'::regnamespace), 3
union all select 'E149 guard triggers present: session frozen core, jti replay cache, event append-only chain, device-revoke cascade',
       (select count(*) = 8 from pg_trigger where not tgisinternal and tgname in ('founder_dbsc_sessions_guard', 'founder_dbsc_sessions_stop_trunc', 'founder_dbsc_jti_guard', 'founder_dbsc_jti_stop_trunc', 'founder_dbsc_events_guard', 'founder_dbsc_events_stop', 'founder_dbsc_events_stop_trunc', 'founder_dbsc_device_revoked_trg')), 4
union all select 'E149 one ACTIVE session per device (unique partial index) and a 65-byte P-256 key CHECK',
       exists (select 1 from pg_indexes where indexname = 'founder_dbsc_sessions_one_active') and exists (select 1 from pg_constraint where conrelid = 'public.founder_dbsc_sessions'::regclass and pg_get_constraintdef(oid) like '%04[0-9a-f]{128}%'), 5
union all select 'E149 behaviour selftest (register, replay, shape, refresh, replace, frozen core, append-only, trigger revoke, report) rolled back',
       public.founder_dbsc_selftest() like 'E149 selftest OK%', 6
union all select 'E149 event hash chain verifies on the real data (' || (public.founder_dbsc_verify(1000) ->> 'checked') || ' rows checked)',
       (public.founder_dbsc_verify(1000) ->> 'ok') = 'true', 7
union all select 'E149 report answers on the real data (no invented numbers): ' || (public.founder_dbsc_report(null) ->> 'verdict') || ', bound sessions ' || (public.founder_dbsc_report(null) ->> 'sessions_active'),
       public.founder_dbsc_report(null) ? 'verdict' and (public.founder_dbsc_report(null) ->> 'verdict') <> 'chain_broken', 8
) t order by ord;
