
-- CHECK E68 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E68 identity_signup_appeals maujood + RLS ON + anon/authenticated band' as item,
         coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.identity_signup_appeals')), false)
         and not has_table_privilege('anon', 'public.identity_signup_appeals', 'select') and not has_table_privilege('authenticated', 'public.identity_signup_appeals', 'select') as ok, 1 as o
  union all select 'E68 wrappers maujood + execute sirf service_role',
         has_function_privilege('service_role', 'public.identity_signup_check_raw(text,text,text,text,text,text)', 'execute')
         and has_function_privilege('service_role', 'public.identity_register_raw(uuid,text,text,text,text,text,text)', 'execute')
         and has_function_privilege('service_role', 'public.identity_admin_overview(uuid)', 'execute')
         and not has_function_privilege('anon', 'public.identity_register_raw(uuid,text,text,text,text,text,text)', 'execute')
         and not has_function_privilege('authenticated', 'public.identity_signup_appeal_decide(uuid,uuid,text,text)', 'execute'), 2
  union all select 'E68 Block/Release trigger account_integrity par laga',
         exists (select 1 from pg_trigger where tgname = 'identity_integrity_ai' and not tgisinternal) or to_regclass('public.account_integrity') is null, 3
  union all select 'E68 appeal-granted trigger device_ban_appeals par laga',
         exists (select 1 from pg_trigger where tgname = 'identity_appeal_ai' and not tgisinternal) or to_regclass('public.device_ban_appeals') is null, 4
  union all select 'E68 email canon: gmail dots/plus ek hi shakhs',
         public.identity_canon_email('Ali.Khan+a@googlemail.com') = 'alikhan@gmail.com', 5
  union all select 'E68 HMAC: 64 hex, key badle to hash badle',
         public.identity_hmac_hex('email', 'a@b.com', 'k1') ~ '^[0-9a-f]{64}$' and public.identity_hmac_hex('email', 'a@b.com', 'k1') <> public.identity_hmac_hex('email', 'a@b.com', 'k2'), 6
  union all select 'E68 bilkul naya shakhs => allow',
         (public.identity_signup_check_raw('check-e68-nobody@example.invalid', null, null, null, null, 'check') ->> 'decision') = 'allow', 7
  union all select 'E68 functions search_path pinned',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'identity\_%' and p.proconfig is null), 8
) t order by o;
