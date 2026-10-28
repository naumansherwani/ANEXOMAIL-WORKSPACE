-- CHECK E106 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E106 founder_polar_rejects() maujood + STABLE + security definer' as item,
       (select provolatile = 's' and prosecdef from pg_proc where oid = to_regprocedure('public.founder_polar_rejects()')) as ok, 1 as ord
union all select 'E106 search_path + statement_timeout pinned',
       (select exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%') from pg_proc where oid = to_regprocedure('public.founder_polar_rejects()')), 2
union all select 'E106 anon/authenticated execute nahi, service_role hai',
       not has_function_privilege('anon','public.founder_polar_rejects()','execute') and not has_function_privilege('authenticated','public.founder_polar_rejects()','execute')
       and has_function_privilege('service_role','public.founder_polar_rejects()','execute'), 3
union all select 'E106 selftest (shape, no raw/header values, STABLE, grants)', coalesce((select public.founder_polar_rejects_selftest() like 'E106 selftest OK%'), false), 4
union all select 'E106 rejects table se connected', coalesce((select (public.founder_polar_rejects() ->> 'connected')::boolean), false), 5
) t order by ord;
