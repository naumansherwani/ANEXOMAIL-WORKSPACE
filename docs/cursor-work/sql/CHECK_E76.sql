
-- CHECK E76 — test account registry (sirf padhta hai). Har row ok = true.
select item, ok from (
  select 'E76 table test_accounts + RLS ON + anon/authenticated ko haq nahi' as item,
         exists (select 1 from pg_class where relname = 'test_accounts' and relnamespace = 'public'::regnamespace and relrowsecurity)
         and not has_table_privilege('anon', 'public.test_accounts', 'select')
         and not has_table_privilege('authenticated', 'public.test_accounts', 'select') as ok, 1 as o
  union all select 'E76 is_registered_test_account: execute sirf service_role',
         has_function_privilege('service_role', 'public.is_registered_test_account(text)', 'execute')
         and not has_function_privilege('anon', 'public.is_registered_test_account(text)', 'execute')
         and not has_function_privilege('authenticated', 'public.is_registered_test_account(text)', 'execute'), 2
  union all select 'E76 ghalat/khali email registry mein nahi (fail-closed)',
         not public.is_registered_test_account('real.user.test@anexomail.com') and not public.is_registered_test_account(null) and not public.is_registered_test_account(''), 3
  union all select 'E76 registry mein sirf test-pattern wale (koi asli naam nahi)',
         not exists (select 1 from public.test_accounts where email !~ '(^|[._-])test@'), 4
) t order by o;
