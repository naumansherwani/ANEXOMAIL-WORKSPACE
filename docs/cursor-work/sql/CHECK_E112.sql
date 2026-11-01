-- CHECK E112 — kuch persist nahi karta (selftest rollback). Har row ok = true.
select item, ok from (
select 'E112 tables maujood + RLS on + anon/authenticated ko access nahi' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select'))
          from unnest(array['public.founder_reports','public.founder_report_groups','public.founder_report_events','public.founder_report_severity_rules','public.founder_report_sla','public.founder_report_transitions']) t) as ok, 1 as ord
union all select 'E112 RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.report_submit(text,text,text,text,text,text,numeric,text)','public.founder_report_set(uuid,bigint,text,text)','public.founder_group_set(uuid,bigint,text,text)',
                            'public.founder_report_verify(bigint)','public.founder_inbox_list(text,text,integer,integer)','public.founder_inbox_get(bigint)','public.founder_inbox_stats()',
                            'public.founder_inbox_channels()','public.founder_inbox_prune(interval)','public.founder_inbox_sla_watch(integer)','public.founder_inbox_rules()',
                            'public.founder_inbox_week()','public.founder_inbox_search(text,integer)','public.founder_inbox_timeline(bigint)','public.founder_inbox_snapshot()','public.founder_inbox_selftest()']) f), 2
union all select 'E112 history append-only triggers + reports guard chalu',
       (select count(*) from pg_trigger where tgrelid in (to_regclass('public.founder_report_events'), to_regclass('public.founder_reports')) and tgname in ('founder_report_events_no_upd_del','founder_report_events_no_trunc','founder_reports_guard') and tgenabled = 'O') = 3, 3
union all select 'E112 security definer RPC par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.report_submit(text,text,text,text,text,text,numeric,text)'), to_regprocedure('public.founder_report_set(uuid,bigint,text,text)'),
                                     to_regprocedure('public.founder_inbox_list(text,text,integer,integer)'), to_regprocedure('public.founder_inbox_stats()'))), 4
union all select 'E112 rules seed (severity + 4 SLA + transitions)',
       (select count(*) from public.founder_report_sla) = 4 and (select count(*) from public.founder_report_severity_rules) >= 10 and (select count(*) from public.founder_report_transitions) >= 10, 5
union all select 'E112 history chain saaf', public.founder_report_verify(1) is null, 6
union all select 'E112 behaviour selftest (helpers, validation, dedup, severity, SLA, rate limit, chain, tamper, state machine, group_set, regression, list/get privacy, stats, prune)',
       coalesce((select public.founder_inbox_selftest() like 'E112 selftest OK%' or public.founder_inbox_selftest() like 'E112 selftest SKIP%'), false), 7
union all select 'E112 stats jawab deta hai (asli DB)', coalesce((select public.founder_inbox_stats() ? 'level'), false), 8
union all select 'E112 live source user_reports register', exists (select 1 from public.founder_live_sources where key = 'user_reports'), 9
union all select 'E112 audit chain saaf (E102)', public.founder_audit_verify(1) is null, 10
) t order by ord;
