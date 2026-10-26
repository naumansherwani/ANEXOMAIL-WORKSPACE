
-- CHECK E89 — sirf padhta hai. Har row ok = true (last column ok, sql-run.sh ' | f' dhoondta hai).
select item, ok from (
select 'E89 10 analytics functions maujood' as item,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname in ('analytics_rate','analytics_waiting','analytics_response_debt','analytics_thread_economics',
               'analytics_deep_work','analytics_attention_leaks','analytics_promise_sla','analytics_forecast','analytics_team','founder_analytics_overview')) = 10 as ok, 1 as n
union all select 'functions SECURITY DEFINER + search_path pinned',
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
         where n.nspname = 'public' and p.proname like 'analytics\_%' and p.prosecdef
           and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')) >= 9, 2
union all select 'anon/authenticated EXECUTE nahi (sirf service_role)',
       not has_function_privilege('anon', 'public.analytics_response_debt(uuid,text[])', 'execute')
       and not has_function_privilege('authenticated', 'public.analytics_response_debt(uuid,text[])', 'execute')
       and has_function_privilege('service_role', 'public.analytics_response_debt(uuid,text[])', 'execute'), 3
union all select 'analytics tables par RLS on',
       (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
         where n.nspname = 'public' and c.relname like 'analytics\_%' and c.relkind = 'r' and c.relrowsecurity) >= 6, 4
union all select 'khali address par debt = 0 (functions chalte hain)',
       (public.analytics_response_debt((select id from auth.users limit 1), array['nobody@example.invalid'])->>'waiting_threads')::int = 0
       or not exists (select 1 from auth.users), 5
) q order by n;
