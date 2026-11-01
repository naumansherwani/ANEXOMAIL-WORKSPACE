-- CHECK E111 — kuch persist nahi karta (selftest rollback). Har row ok = true.
select item, ok from (
select 'E111 tables maujood + RLS on + anon/authenticated ko access nahi' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select'))
          from unnest(array['public.founder_channels','public.founder_channel_transitions','public.founder_channel_events','public.founder_live_sessions','public.founder_live_tick_minutes','public.founder_live_slo_rules']) t) as ok, 1 as ord
union all select 'E111 RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_channel_set(uuid,text,text,text,text,text)','public.founder_channel_verify(bigint)','public.founder_channels_list()','public.founder_channels_pending()',
                            'public.founder_live_session_open(text)','public.founder_live_session_close(bigint,text,integer)','public.founder_live_tick_report(boolean,integer)',
                            'public.founder_live_reliability(integer)','public.founder_live_tick_health(integer)','public.founder_live_snapshot_v2()','public.founder_live_prune_v2(interval,interval)',
                            'public.founder_live_gauge()','public.founder_channel_history(text,integer,bigint)','public.founder_channels_sync_signal()','public.founder_channels_selftest()','public.founder_live_daily(integer)','public.founder_channel_stats()']) f), 2
union all select 'E111 channel history append-only triggers chalu',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_channel_events') and tgname in ('founder_channel_events_no_upd_del','founder_channel_events_no_trunc') and tgenabled = 'O') = 2, 3
union all select 'E111 security definer RPC par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_channel_set(uuid,text,text,text,text,text)'), to_regprocedure('public.founder_live_snapshot_v2()'),
                                     to_regprocedure('public.founder_live_tick_report(boolean,integer)'), to_regprocedure('public.founder_live_reliability(integer)'))), 4
union all select 'E111 seed channels (glitch, support, company_mail) maujood',
       (select count(*) from public.founder_channels where key in ('glitch','support','company_mail')) = 3, 5
union all select 'E111 channel history chain saaf',
       public.founder_channel_verify(1) is null, 6
union all select 'E111 behaviour selftest (state machine, chain, tamper, rate limit, sessions, ticks, SLO, snapshot_v2, prune, rollback)',
       coalesce((select public.founder_channels_selftest() like 'E111 selftest OK%' or public.founder_channels_selftest() like 'E111 selftest SKIP%'), false), 7
union all select 'E111 snapshot_v2 jawab deta hai (asli DB) aur v1 ke upar naye keys',
       coalesce((select public.founder_live_snapshot_v2() ? 'pending_channels' and public.founder_live_snapshot_v2() ? 'tick_health'), false), 8
union all select 'E111 audit chain saaf (E102)', public.founder_audit_verify(1) is null, 9
) t order by ord;
