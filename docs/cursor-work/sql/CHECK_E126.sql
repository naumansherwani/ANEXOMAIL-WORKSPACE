-- CHECK E126 — sirf padhta hai.
select item, ok from (
  select 1 as o, 'E126 basic.test@ and alikhan@ are gone from auth.users' as item,
         not exists (select 1 from auth.users where lower(email) in ('basic.test@anexomail.com', 'alikhan@anexomail.com')) as ok
  union all
  select 2, 'E126 no organisation Basic Test workspace / Personal mail is left',
         not exists (select 1 from public.organisations where slug in ('basic-test-741231d3b735', 'personal-99efa3ee5622'))
  union all
  select 3, 'E126 masoodsherwani@anexomail.com still exists',
         exists (select 1 from auth.users where lower(email) = 'masoodsherwani@anexomail.com')
  union all
  select 4, 'E126 Masood workspace_kind = business',
         exists (select 1 from public.account_profiles p join auth.users u on u.id = p.user_id where lower(u.email) = 'masoodsherwani@anexomail.com' and p.preferences->>'workspace_kind' = 'business')
  union all
  select 5, 'E126 Masood plan = pro',
         exists (select 1 from public.family_accounts f where lower(f.email) = 'masoodsherwani@anexomail.com' and f.plan = 'pro')
  union all
  select 6, 'E126 no personal-kind account is left',
         not exists (select 1 from public.account_profiles where lower(coalesce(preferences->>'workspace_kind', '')) = 'personal')
  union all
  select 7, 'E126 total accounts now = ' || (select count(*) from auth.users) || ' (was 18, minus 2 = 16)',
         (select count(*) from auth.users) >= 16
) x order by o;
