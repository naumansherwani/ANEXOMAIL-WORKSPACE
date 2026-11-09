
-- CHECK E148_LIVE — read-only; the selftest rolls back. Every row ok = true.
select item, ok from (
select 'E148_LIVE report function exists, security definer, search_path + statement_timeout pinned' as item,
       (select prosecdef and exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%')
          from pg_proc where oid = to_regprocedure('public.founder_wt_live_report(integer)')) as ok, 1 as ord
union all select 'E148_LIVE selftest function exists, security definer, search_path + statement_timeout pinned',
       (select prosecdef and exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%')
          from pg_proc where oid = to_regprocedure('public.founder_wt_live_selftest()')), 2
union all select 'E148_LIVE only service_role may run them (anon / authenticated / public cannot)',
       has_function_privilege('service_role', 'public.founder_wt_live_report(integer)', 'execute') and has_function_privilege('service_role', 'public.founder_wt_live_selftest()', 'execute')
       and not has_function_privilege('anon', 'public.founder_wt_live_report(integer)', 'execute') and not has_function_privilege('authenticated', 'public.founder_wt_live_report(integer)', 'execute')
       and not has_function_privilege('anon', 'public.founder_wt_live_selftest()', 'execute') and not has_function_privilege('authenticated', 'public.founder_wt_live_selftest()', 'execute'), 3
union all select 'E148_LIVE behaviour selftest (clamps, shape, proven, degraded, quick reopen, orphan) rolled back',
       public.founder_wt_live_selftest() like 'E148_LIVE selftest OK%', 4
union all select 'E148_LIVE report answers on the real data (verdict present, no invented numbers): ' || (public.founder_wt_live_report(2) ->> 'verdict'),
       (public.founder_wt_live_report(2) ->> 'verdict') in ('proven', 'waiting', 'no_sessions', 'degraded'), 5
) t order by ord;
