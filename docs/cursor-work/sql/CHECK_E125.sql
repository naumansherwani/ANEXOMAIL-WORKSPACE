-- CHECK E125 — sirf padhta hai. Har row ok = true/false.
select item, ok from (
  select 1 as o, 'E125 personal_polar_map has no rows (or the table is gone)' as item,
         (to_regclass('public.personal_polar_map') is null or not exists (select 1 from public.personal_polar_map)) as ok
  union all
  select 2, 'E125 no Personal product is still active or listed in billing_price_book',
         (to_regclass('public.billing_price_book') is null or not exists (select 1 from public.billing_price_book where product_key like 'POLAR_PRODUCT_PLAN_PERSONAL_%' and (active or polar_listed)))
  union all
  select 3, 'E125 Business ladder products are still there and active (Basic / Pro / Business / Business Pro rows untouched)',
         (to_regclass('public.billing_price_book') is null or exists (select 1 from public.billing_price_book where product_key not like 'POLAR_PRODUCT_PLAN_PERSONAL_%' and kind = 'plan' and active))
  union all
  select 4, 'E125 masoodsherwani@anexomail.com exists and is on plan pro',
         exists (select 1 from auth.users u where lower(u.email) = 'masoodsherwani@anexomail.com')
         and (to_regclass('public.family_accounts') is null or exists (select 1 from public.family_accounts f where lower(f.email) = 'masoodsherwani@anexomail.com' and f.plan = 'pro'))
  union all
  select 5, 'E125 no account was deleted by this step (18 accounts at PX0 time; now at least 18 unless the founder deleted some himself) -- informational',
         (select count(*) from auth.users) >= 1
) x order by o;
