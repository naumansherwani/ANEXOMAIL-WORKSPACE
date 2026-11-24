select 'AD21 function exists, security definer' as what, exists (select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='cp' and p.proname='lookup' and p.prosecdef) as ok
union all select 'cp_lookup can execute it', has_function_privilege('cp_lookup','cp.lookup(text)','execute')
union all select 'PUBLIC cannot execute it', not has_function_privilege('public','cp.lookup(text)','execute')
union all select 'cp_lookup has no table right on orgs', not has_table_privilege('cp_lookup','public.orgs','select')
union all select 'cp_lookup has no table right on subscriptions', not has_table_privilege('cp_lookup','public.workspace_subscriptions','select')
union all select 'cp_lookup has no table right on members', not has_table_privilege('cp_lookup','public.org_members','select')
union all select 'garbage company gives null', cp.lookup('x; drop') is null
union all select 'unknown company gives null', cp.lookup('00000000-0000-4000-8000-000000000000') is null;
