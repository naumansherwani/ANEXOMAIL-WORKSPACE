-- CHECK E148 — nothing persists (selftest rolls back). Every row ok = true.
select item, ok from (
select 'E148 transport column NOT NULL + CHECK + immutable trigger' as item,
       (select is_nullable = 'NO' from information_schema.columns where table_schema = 'public' and table_name = 'founder_live_sessions' and column_name = 'transport')
       and exists (select 1 from pg_constraint where conrelid = 'public.founder_live_sessions'::regclass and conname = 'founder_live_sessions_transport_ck')
       and exists (select 1 from pg_trigger where tgrelid = 'public.founder_live_sessions'::regclass and tgname = 'founder_live_sessions_immutable_trg' and not tgisinternal) as ok, 1 as ord
union all select 'E148 RPCs exist, anon/authenticated cannot execute, service_role can',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_live_session_open_t(text,text)', 'public.founder_wt_report(integer)', 'public.founder_wt_selftest()']) f), 2
union all select 'E148 security definer RPCs have search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_live_session_open_t(text,text)'), to_regprocedure('public.founder_wt_report(integer)'), to_regprocedure('public.founder_wt_selftest()'))), 3
union all select 'E148 table still RLS on, anon/authenticated no access',
       (select relrowsecurity from pg_class where oid = 'public.founder_live_sessions'::regclass) and not has_table_privilege('anon', 'public.founder_live_sessions', 'select') and not has_table_privilege('authenticated', 'public.founder_live_sessions', 'select'), 4
union all select 'E148 behaviour selftest (open, close once, report, bad transport/kind refused, immutable, CHECK) rolled back',
       public.founder_wt_selftest() like 'E148 selftest OK%', 5
union all select 'E148 report answers on the real data (no invented numbers)',
       public.founder_wt_report(24) ? 'by_transport' and public.founder_wt_report(24) ? 'close_reasons', 6
union all select 'E148 E111 one-argument open still exists (the SSE path is untouched)',
       to_regprocedure('public.founder_live_session_open(text)') is not null, 7
) t order by ord;
