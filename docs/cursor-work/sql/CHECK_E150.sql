
-- CHECK E150 (K7b device key for every browser) — read-only except the selftest, which rolls back (nothing persists). Every row ok = true.
select item, ok from (
select 'E150 source column NOT NULL + CHECK (dbsc | webcrypto) and the guard freezes it' as item,
       (select is_nullable = 'NO' from information_schema.columns where table_schema = 'public' and table_name = 'founder_dbsc_sessions' and column_name = 'source')
       and exists (select 1 from pg_constraint where conrelid = 'public.founder_dbsc_sessions'::regclass and conname = 'founder_dbsc_sessions_source_ck')
       and pg_get_functiondef('public._dbsc_session_guard()'::regprocedure) like '%new.source <> old.source%' as ok, 1 as ord
union all select 'E150 register door + selftest exist, only service_role may run them',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_dbsc_register_src(uuid,text,text,text,text,text)', 'public.founder_devicekey_selftest()']) f), 2
union all select 'E150 security definer functions have search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where proname in ('founder_dbsc_register_src', 'founder_devicekey_selftest') and pronamespace = 'public'::regnamespace), 3
union all select 'E150 device state returns source + key, report returns by_source',
       pg_get_functiondef('public.founder_dbsc_device_state(uuid,text)'::regprocedure) like '%''source'', source%' and public.founder_dbsc_report(null) ? 'by_source', 4
union all select 'E150 E149 still intact (its selftest passes, 5-argument register door untouched)',
       public.founder_dbsc_selftest() like 'E149 selftest OK%' and to_regprocedure('public.founder_dbsc_register(uuid,text,text,text,text)') is not null, 5
union all select 'E150 behaviour selftest (webcrypto register, key in state, refusals, dbsc outranks webcrypto, source frozen, by_source) rolled back',
       public.founder_devicekey_selftest() like 'E150 selftest OK%', 6
union all select 'E150 chain still verifies on the real data (' || (public.founder_dbsc_verify(1000) ->> 'checked') || ' rows checked), bound by source: dbsc '
         || (public.founder_dbsc_report(null) #>> '{by_source,dbsc}') || ', webcrypto ' || (public.founder_dbsc_report(null) #>> '{by_source,webcrypto}'),
       (public.founder_dbsc_verify(1000) ->> 'ok') = 'true', 7
) t order by ord;
