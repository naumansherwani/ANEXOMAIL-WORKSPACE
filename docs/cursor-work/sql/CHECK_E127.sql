-- CHECK E127 — sirf padhta hai.
select item, ok from (
  select 1 as o, 'E127 account_profiles.country_iso2 exists' as item,
         exists (select 1 from information_schema.columns where table_schema='public' and table_name='account_profiles' and column_name='country_iso2') as ok
  union all select 2, 'E127 account_phones exists with RLS on',
         coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.account_phones')), false)
  union all select 3, 'E127 anon/authenticated have no privileges on account_phones',
         not exists (select 1 from information_schema.role_table_grants where table_schema='public' and table_name='account_phones' and grantee in ('anon','authenticated'))
  union all select 4, 'E127 same number allowed on two accounts, refused twice on one (unique is (user_id, e164))',
         exists (select 1 from pg_indexes where schemaname='public' and tablename='account_phones' and indexdef ilike '%unique%(user_id, e164)%')
  union all select 5, 'E127 limit trigger (max 5) and one-primary index exist',
         exists (select 1 from pg_trigger where tgrelid = to_regclass('public.account_phones') and tgname='account_phones_limit_trg')
         and exists (select 1 from pg_indexes where schemaname='public' and indexname='account_phones_one_primary_uq')
) x order by o;
