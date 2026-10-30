-- CHECK E110 — kuch persist nahi karta (selftest rollback). Har row ok = true.
select item, ok from (
select 'E110 founder_host_events maujood, RLS on, anon/authenticated ko access nahi' as item,
       to_regclass('public.founder_host_events') is not null and (select relrowsecurity from pg_class where oid = 'public.founder_host_events'::regclass)
       and not has_table_privilege('anon','public.founder_host_events','select') and not has_table_privilege('authenticated','public.founder_host_events','select') as ok, 1 as ord
union all select 'E110 RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_host_record(text,text,text,boolean,boolean,text,text)','public.founder_host_proof()','public.founder_host_prune(interval)']) f), 2
union all select 'E110 append-only triggers chalu',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_host_events') and tgname in ('founder_host_events_no_upd_del','founder_host_events_no_trunc') and tgenabled = 'O') = 2, 3
union all select 'E110 proof/record par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_host_proof()'), to_regprocedure('public.founder_host_record(text,text,text,boolean,boolean,text,text)'))), 4
union all select 'E110 behaviour selftest (khali, awam-host warn, founder-host ok, append-only, validation, no-PII, prune, rollback)',
       coalesce((select public.founder_host_selftest() like 'E110 selftest OK%' or public.founder_host_selftest() like 'E110 selftest SKIP%'), false), 5
union all select 'E110 proof() jawab deta hai (asli DB)', coalesce((select public.founder_host_proof() ? 'ready_to_enforce'), false), 6
union all select 'E110 audit chain saaf', public.founder_audit_verify(1) is null, 7
) t order by ord;
