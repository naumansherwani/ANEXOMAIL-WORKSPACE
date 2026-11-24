-- AD22 CHECK (phase 1m-4 B9): every row must be true
select 'cp.census exists, SECURITY DEFINER, fixed search_path' as what,
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'cp' and p.proname = 'census' and p.prosecdef and p.proconfig::text like '%search_path=pg_catalog, pg_temp%') as ok
union all select 'cp_lookup can execute it', has_function_privilege('cp_lookup', 'cp.census(jsonb)', 'execute')
union all select 'PUBLIC cannot execute it', not has_function_privilege('public', 'cp.census(jsonb)', 'execute')
union all select 'cp_lookup has no table right on the billing and storage tables', not has_table_privilege('cp_lookup', 'public.billing_intents', 'select') and not has_table_privilege('cp_lookup', 'public.admin_storage_snapshots', 'select')
union all select 'cp.lookup is still there and still closed', has_function_privilege('cp_lookup', 'cp.lookup(text)', 'execute') and not has_function_privilege('public', 'cp.lookup(text)', 'execute')
union all select 'bad limits give null', cp.census('{"evil":1}'::jsonb) is null and cp.census('[]'::jsonb) is null
union all select 'the census has 8 registered signals and a 12-month line', jsonb_array_length(cp.census('{}'::jsonb)->'signals') = 8 and jsonb_array_length(cp.census('{}'::jsonb)->'growth_12m') = 12
union all select 'the census holds no company id, e-mail or money word', cp.census('{}'::jsonb)::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|amount|price|currency|invoice)';
