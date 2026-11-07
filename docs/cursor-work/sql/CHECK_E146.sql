-- CHECK E146 — reads only. 4 checks.
select item, ok from (
select 'E146 the four banned countries (AF +93, IL +972, KP +850, SY +963) are in the list and nobody else' as item,
       (select count(*) = 4 and bool_and((iso2, dial) in (('AF','93'),('IL','972'),('KP','850'),('SY','963'))) from public.founder_banned_countries) as ok, 1 as ord
union all select 'E146 the list is closed: anon and authenticated cannot read or write it, service_role can only read',
       not has_table_privilege('anon', 'public.founder_banned_countries', 'select') and not has_table_privilege('authenticated', 'public.founder_banned_countries', 'select')
       and has_table_privilege('service_role', 'public.founder_banned_countries', 'select') and not has_table_privilege('service_role', 'public.founder_banned_countries', 'insert')
       and not has_table_privilege('service_role', 'public.founder_banned_countries', 'update') and not has_table_privilege('service_role', 'public.founder_banned_countries', 'delete'), 2
union all select 'E146 the alert-number door and the prefix test are open to service_role only',
       has_function_privilege('service_role', 'public.founder_mobile_flare_set(uuid,uuid,text,uuid,text)', 'execute') and not has_function_privilege('anon', 'public.founder_mobile_flare_set(uuid,uuid,text,uuid,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_mobile_flare_set(uuid,uuid,text,uuid,text)', 'execute')
       and has_function_privilege('service_role', 'public.founder_e164_banned(text)', 'execute') and not has_function_privilege('authenticated', 'public.founder_e164_banned(text)', 'execute'), 3
union all select 'E146 behaviour selftest (prefix exact, append-only, banned number refused before the key grant, allowed number reaches the grant check)',
       coalesce((select public.founder_banned_selftest() like 'E146 selftest PASS%'), false), 4
) t order by ord;
