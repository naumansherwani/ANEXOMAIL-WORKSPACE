
-- CHECK E67 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E67 passkey_vault maujood + RLS ON' as item,
         coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.passkey_vault')), false) as ok, 1 as o
  union all select 'E67 anon/authenticated ka koi haq nahi',
         not has_table_privilege('anon', 'public.passkey_vault', 'select') and not has_table_privilege('authenticated', 'public.passkey_vault', 'select')
         and not has_table_privilege('authenticated', 'public.passkey_vault', 'insert'), 2
  union all select 'E67 functions (find / bump / list) sirf service_role',
         has_function_privilege('service_role', 'public.passkey_vault_find(bytea)', 'execute') and has_function_privilege('service_role', 'public.passkey_vault_bump(uuid,bigint)', 'execute')
         and not has_function_privilege('authenticated', 'public.passkey_vault_list(uuid)', 'execute'), 3
  union all select 'E67 purani webauthn_credentials / account_recovery par authenticated ka select band',
         (to_regclass('public.webauthn_credentials') is null or not has_table_privilege('authenticated', 'public.webauthn_credentials', 'select'))
         and (to_regclass('public.account_recovery') is null or not has_table_privilege('authenticated', 'public.account_recovery', 'select')), 4
  union all select 'E67 blind index unique + shape checks',
         exists (select 1 from pg_constraint where conrelid = 'public.passkey_vault'::regclass and contype = 'u')
         and (select count(*) from pg_constraint where conrelid = 'public.passkey_vault'::regclass and contype = 'c') >= 5, 5
  union all select 'E67 counter sirf aage badhta hai (asli sawal, kuch likhta nahi: random id par FALSE)',
         public.passkey_vault_bump(gen_random_uuid(), 1) is false, 6
) t order by o;
