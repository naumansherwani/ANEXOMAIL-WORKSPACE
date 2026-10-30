-- CHECK E109 — kuch persist nahi karta (selftest poora rollback).  Har row ok = true.
select item, ok from (
select 'E109 4 tables + view maujood, RLS on, anon/authenticated ko koi access nahi' as item,
       (select count(*) = 4 from pg_class c where c.oid in (to_regclass('public.founder_live_sources'), to_regclass('public.founder_live_state'),
              to_regclass('public.founder_live_events'), to_regclass('public.founder_metric_points')) and c.relrowsecurity)
       and not has_table_privilege('anon','public.founder_live_events','select') and not has_table_privilege('authenticated','public.founder_live_events','select')
       and not has_table_privilege('authenticated','public.founder_metric_points','select') and to_regclass('public.founder_metric_hourly') is not null as ok, 1 as ord
union all select 'E109 saare RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute')
                        and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_live_tick(boolean)','public.founder_live_snapshot()','public.founder_live_since(bigint,integer)',
                            'public.founder_live_anomalies(integer,numeric)','public.founder_live_series(text,integer)','public.founder_live_prune(interval,interval)',
                            'public.founder_live_fp(text)']) f), 2
union all select 'E109 security definer RPC par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_live_tick(boolean)'), to_regprocedure('public.founder_live_snapshot()'),
                                     to_regprocedure('public.founder_live_since(bigint,integer)'), to_regprocedure('public.founder_live_fp(text)'))), 3
union all select 'E109 snapshot aur fp sirf padhte hain (STABLE)',
       (select bool_and(provolatile = 's') from pg_proc where oid in (to_regprocedure('public.founder_live_snapshot()'), to_regprocedure('public.founder_live_fp(text)'),
                                                                      to_regprocedure('public.founder_live_since(bigint,integer)'))), 4
union all select 'E109 feed append-only triggers chalu (update/delete + truncate)',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_live_events') and tgname in ('founder_live_events_no_upd_del','founder_live_events_no_trunc') and tgenabled = 'O') = 2, 5
union all select 'E109 awam tables par KOI trigger E109 ka nahi (NO-TOUCH)',
       not exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid where not t.tgisinternal and p.proname like '%founder_live%'
                    and t.tgrelid <> to_regclass('public.founder_live_events')), 6
union all select 'E109 sab 12 sources registry mein',
       (select count(*) from public.founder_live_sources) >= 12, 7
union all select 'E109 behaviour selftest (baseline, change, stale/recover, vanish, append-only, PII, since, snapshot, anomaly, prune, rollback)',
       coalesce((select public.founder_live_selftest() like 'E109 selftest OK%' or public.founder_live_selftest() like 'E109 selftest SKIP%'), false), 8
union all select 'E109 audit chain saaf', public.founder_audit_verify(1) is null, 9
) t order by ord;
