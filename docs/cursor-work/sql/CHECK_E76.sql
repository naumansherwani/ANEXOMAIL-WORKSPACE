
-- CHECK E76 v2 — account class wall (sirf padhta hai). Har row ok = true.
select item, ok from (
  select 'E76 test_accounts: RLS ON, anon/authenticated ko koi haq nahi' as item,
         exists (select 1 from pg_class where relname = 'test_accounts' and relnamespace = 'public'::regnamespace and relrowsecurity)
         and not has_table_privilege('anon', 'public.test_accounts', 'select')
         and not has_table_privilege('authenticated', 'public.test_accounts', 'insert') as ok, 1 as o
  union all select 'E76 functions: execute sirf service_role (anon/authenticated nahi)',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array['public.account_class(text)', 'public.is_registered_test_account(text)', 'public.register_test_account(text,text)', 'public.account_mix_report()']) f), 2
  union all select 'E76 triggers maujood (test_accounts + trial_accounts wall)',
         exists (select 1 from pg_trigger where tgname = 'ax_one_class' and tgrelid = 'public.test_accounts'::regclass)
         and exists (select 1 from pg_trigger where tgname = 'ax_trial_handle_wall' and tgrelid = 'public.trial_accounts'::regclass), 3
  union all select 'E76 triggers founder/family par bhi (jahan table hai)',
         (to_regclass('public.founder_accounts') is null or exists (select 1 from pg_trigger where tgname = 'ax_one_class' and tgrelid = 'public.founder_accounts'::regclass))
         and (to_regclass('public.family_accounts') is null or exists (select 1 from pg_trigger where tgname = 'ax_one_class' and tgrelid = 'public.family_accounts'::regclass)), 4
  union all select 'E76 fail-closed: ajnabi/khali/null email = real',
         public.account_class('nobody.test@anexomail.com') = 'real' and public.account_class(null) = 'real' and public.account_class('') = 'real'
         and not public.is_registered_test_account('nobody.test@anexomail.com'), 5
  union all select 'E76 audit: koi mix nahi (account_mix_report khali)',
         not exists (select 1 from public.account_mix_report()), 6
  union all select 'E76 sab functions pinned search_path',
         (select bool_and(coalesce(p.proconfig::text, '') like '%search_path%') from pg_proc p
           where p.pronamespace = 'public'::regnamespace and p.proname in ('account_class', 'register_test_account', '_acct_one_class', '_trial_handle_wall', 'account_mix_report', '_is_test_name', 'is_registered_test_account')), 7
) t order by o;
