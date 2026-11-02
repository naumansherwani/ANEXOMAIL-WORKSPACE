-- CHECK PX0 — Personal packages removal, step 0. SIRF PADHTA HAI (kuch nahi badalta). Har row ok = true: yeh ek LIST hai, pass/fail nahi.
-- Kya dikhata hai: har account jis ka workspace_kind = 'personal' (account_profiles.preferences), uska email, plan (family_accounts), subscription state (polar_subscriptions),
-- aur Masood ka account (masoodsherwani@anexomail.com) alag row mein. Iske baad hi E125 likhi jayegi; delete sirf unhi par jinhein founder list dekh kar haan kahe.
-- Honest limit: org-slug 'personal-*' wale accounts bhi hain to woh yahan nahi aate agar preferences mein kind nahi likha; isliye akhri row "all accounts" ka total deti hai.
select item, ok from (
  select 0 as o, 'PX0 total accounts in auth.users = ' || (select count(*) from auth.users) as item, true as ok
  union all
  select 1, 'PX0 personal-kind accounts (preferences.workspace_kind = personal) = ' || (select count(*) from public.account_profiles p where lower(coalesce(p.preferences->>'workspace_kind', '')) = 'personal'), true
  union all
  select 2, 'PX0 paid subscriptions of personal-kind accounts = ' || (select count(*) from public.polar_subscriptions s join public.account_profiles p on p.user_id = s.user_id
                                                                  where lower(coalesce(p.preferences->>'workspace_kind', '')) = 'personal' and s.status in ('active', 'trialing', 'past_due')), true
  union all
  select 10 + row_number() over (order by u.created_at), 'PX0 PERSONAL ' || coalesce(u.email, '?') || ' | created ' || to_char(u.created_at, 'YYYY-MM-DD') || ' | plan ' || coalesce((select f.plan from public.family_accounts f where lower(f.email) = lower(u.email) limit 1), '-')
         || ' | subs ' || coalesce((select string_agg(s.status, ',') from public.polar_subscriptions s where s.user_id = u.id), 'none'), true
  from auth.users u join public.account_profiles p on p.user_id = u.id where lower(coalesce(p.preferences->>'workspace_kind', '')) = 'personal'
  union all
  select 5, 'PX0 MASOOD ' || coalesce((select u.email || ' | id ' || u.id || ' | kind ' || coalesce(p.preferences->>'workspace_kind', '-') || ' | plan ' || coalesce((select f.plan from public.family_accounts f where lower(f.email) = lower(u.email) limit 1), '-')
                                             from auth.users u left join public.account_profiles p on p.user_id = u.id where lower(u.email) = 'masoodsherwani@anexomail.com'), 'NOT FOUND in auth.users'), true
) x order by o;
