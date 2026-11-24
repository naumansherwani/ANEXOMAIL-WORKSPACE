-- CP3 CHECK (phase 1m-5 B6): every row must be true
select 'cp.deliverability exists, SECURITY DEFINER, fixed search_path' as what,
  exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'cp' and p.proname = 'deliverability' and p.prosecdef and p.proconfig::text like '%search_path=pg_catalog, pg_temp%') as ok
union all select 'cp_lookup can execute it', has_function_privilege('cp_lookup', 'cp.deliverability()', 'execute')
union all select 'PUBLIC cannot execute it', not has_function_privilege('public', 'cp.deliverability()', 'execute')
union all select 'cp_lookup has no table right on org_domains', not has_table_privilege('cp_lookup', 'public.org_domains', 'select')
union all select 'cp.census and cp.lookup are still there and closed', has_function_privilege('cp_lookup', 'cp.census(jsonb)', 'execute') and has_function_privilege('cp_lookup', 'cp.lookup(text)', 'execute') and not has_function_privilege('public', 'cp.census(jsonb)', 'execute')
union all select 'the answer has 6 registered signals', jsonb_array_length(cp.deliverability()->'signals') = 6
union all select 'verified plus pending equals the domains', (cp.deliverability()->'status'->>'verified')::int + (cp.deliverability()->'status'->>'pending')::int = (cp.deliverability()->>'domains')::int
union all select 'the answer holds no domain, company id, token or e-mail', cp.deliverability()::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|token|selector)'
union all select 'the function has a 5 s statement timeout, a 1 s lock timeout and a comment', exists (select 1 from pg_proc p where p.pronamespace = 'cp'::regnamespace and p.proname = 'deliverability' and p.proconfig::text like '%statement_timeout=5s%' and p.proconfig::text like '%lock_timeout=1s%' and obj_description(p.oid, 'pg_proc') is not null);
