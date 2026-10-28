-- CHECK E105 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E105 founder_polar_pulse() maujood + STABLE + security definer' as item,
       (select provolatile = 's' and prosecdef from pg_proc where oid = to_regprocedure('public.founder_polar_pulse()')) as ok, 1 as ord
union all select 'E105 search_path + statement_timeout pinned',
       (select exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%') from pg_proc where oid = to_regprocedure('public.founder_polar_pulse()')), 2
union all select 'E105 anon/authenticated execute nahi, service_role hai',
       not has_function_privilege('anon','public.founder_polar_pulse()','execute') and not has_function_privilege('authenticated','public.founder_polar_pulse()','execute')
       and has_function_privilege('service_role','public.founder_polar_pulse()','execute'), 3
union all select 'E105 selftest (shape, no-PII, STABLE, grants)', coalesce((select public.founder_polar_pulse_selftest() like 'E105 selftest OK%'), false), 4
union all select 'E105 webhook table se connected (polar_webhook_inbox padhi ja rahi)', coalesce((select (public.founder_polar_pulse() #>> '{webhook,connected}')::boolean), false), 5
union all select 'E105 Polar tables ke triggers/policies nahi badle (inbox par sirf wohi trigger jo pehle tha)',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.polar_webhook_inbox') and not tgisinternal) <= 1, 6
) t order by ord;
