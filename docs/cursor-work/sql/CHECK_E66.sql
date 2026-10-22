
-- CHECK E66 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E66 chaaron tables maujood + RLS ON' as item,
         (select count(*) from pg_class where oid in (to_regclass('public.identity_vault_policy'), to_regclass('public.identity_signals'), to_regclass('public.identity_bans'), to_regclass('public.identity_vault_audit')) and relrowsecurity) = 4 as ok, 1 as o
  union all select 'E66 anon/authenticated ko tables ka koi haq nahi',
         not has_table_privilege('anon', 'public.identity_bans', 'select') and not has_table_privilege('authenticated', 'public.identity_signals', 'select')
         and not has_table_privilege('authenticated', 'public.identity_vault_audit', 'select'), 2
  union all select 'E66 functions maujood + execute sirf service_role',
         has_function_privilege('service_role', 'public.identity_signup_check(jsonb)', 'execute')
         and has_function_privilege('service_role', 'public.identity_register(uuid,jsonb)', 'execute')
         and has_function_privilege('service_role', 'public.identity_ban_account(uuid,text,boolean,uuid)', 'execute')
         and not has_function_privilege('anon', 'public.identity_ban_account(uuid,text,boolean,uuid)', 'execute')
         and not has_function_privilege('authenticated', 'public.identity_signup_check(jsonb)', 'execute'), 3
  union all select 'E66 policy row: 730 din ban, 2 weak ke baad review, shared device 3',
         exists (select 1 from public.identity_vault_policy where id = 1 and ban_retain_days = 730 and weak_review_threshold = 2 and shared_device_limit = 3), 4
  union all select 'E66 kind: mazboot (device_key/email/recovery/payment) vs kamzor (device_shape/network)',
         public.identity_kind_strong('email') and public.identity_kind_strong('device_key') and public.identity_kind_strong('payment') and public.identity_kind_strong('recovery')
         and not public.identity_kind_strong('device_shape') and not public.identity_kind_strong('network') and public.identity_kind_strong('fingerprint') is null, 5
  union all select 'E66 signals ka shape: sahi hex qubool, ghalat/anjaan kind/khaali mana',
         public.identity_signals_ok('[{"kind":"email","hmac":"0000000000000000000000000000000000000000000000000000000000000000"}]'::jsonb)
         and not public.identity_signals_ok('[{"kind":"email","hmac":"zz"}]'::jsonb) and not public.identity_signals_ok('[{"kind":"fingerprint","hmac":"0000000000000000000000000000000000000000000000000000000000000000"}]'::jsonb)
         and not public.identity_signals_ok('[]'::jsonb) and not public.identity_signals_ok(null), 6
  union all select 'E66 asli sawal: bilkul naye nishan => allow (sirf padhta hai)',
         (public.identity_signup_check('[{"kind":"device_key","hmac":"1111111111111111111111111111111111111111111111111111111111111111"}]'::jsonb) ->> 'decision') = 'allow', 7
  union all select 'E66 retain constraint + unique indexes maujood',
         exists (select 1 from pg_constraint where conname = 'identity_signals_retain_ck') and to_regclass('public.identity_bans_active_uq') is not null and to_regclass('public.identity_signals_uq') is not null, 8
) t order by o;
