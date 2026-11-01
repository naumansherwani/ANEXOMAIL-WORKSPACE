-- CHECK E119 — kuch persist nahi karta (selftest rollback). Har row ok = true. 4 checks.
select item, ok from (
select 'E119 founder_tls_checks maujood, RLS on, anon/authenticated ko access nahi, service_role seedha likh nahi sakta' as item,
       to_regclass('public.founder_tls_checks') is not null
       and (select relrowsecurity from pg_class where oid = 'public.founder_tls_checks'::regclass)
       and not has_table_privilege('anon', 'public.founder_tls_checks', 'select') and not has_table_privilege('authenticated', 'public.founder_tls_checks', 'select')
       and not has_table_privilege('service_role', 'public.founder_tls_checks', 'insert') and not has_table_privilege('service_role', 'public.founder_tls_checks', 'update') and not has_table_privilege('service_role', 'public.founder_tls_checks', 'delete') as ok, 1 as ord
union all select 'E119 2 doors (record, posture) maujood, anon/authenticated execute nahi, service_role ke liye khule',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_tls_check_record(text,integer,text,boolean,text,text,text,text,text)','public.founder_tls_posture()']) f), 2
union all select 'E119 database khud jhooti row nahi leta: ok row mein cipher lazmi, fail row mein error lazmi (constraint)',
       exists (select 1 from pg_constraint where conname = 'founder_tls_ok_shape' and conrelid = 'public.founder_tls_checks'::regclass), 3
union all select 'E119 behaviour selftest (validation, verdicts available_not_default / forced_256 / unreachable, latest wins, stale) + purane selftests (E113, E115, E116, E118) green, audit chain saaf',
       coalesce((select public.founder_tls_selftest() like 'E119 selftest OK%'), false)
       and coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest() like 'E115 selftest OK%' or public.founder_settings_s1c_selftest() like 'E115 selftest SKIP%'), false)
       and coalesce((select public.founder_drift_value_selftest() like 'E116 selftest OK%' or public.founder_drift_value_selftest() like 'E116 selftest SKIP%'), false)
       and coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false)
       and public.founder_audit_verify(1) is null, 4
) t order by ord;
