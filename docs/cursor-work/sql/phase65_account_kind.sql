-- =============================================================================
-- Phase 65 — account_kind (Personal | Business) + video for Pro+
-- Supabase #4 SQL Editor — poori file paste → Run. Idempotent.
--
-- Polar / landing NO TOUCH. Wahi 4 SKUs: basic · pro · business · business_pro.
-- Personal vs Business Polar product NAHI — session preference + org slug.
-- Personal Pro (billed `pro`) = Business Pro power, Org nahi.
-- Fail rule: is file ko hi theek likho; phase65b / _fix naam banned.
-- =============================================================================
set search_path = public, extensions;

-- ── 1) Video: founder, Polar Pro+, Business, Business Pro
--     Purana lock founder + business_pro only tha. Personal Pro = full video.
create or replace function public.chat_video_allowed(_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  ok boolean := false;
  billed text := 'basic';
  email text;
begin
  if _user_id is null then return false; end if;

  if to_regclass('public.founder_accounts') is not null then
    execute 'select exists(select 1 from public.founder_accounts where user_id = $1)'
      into ok using _user_id;
    if ok then return true; end if;
  end if;

  select u.email into email from auth.users u where u.id = _user_id;

  if to_regclass('public.family_accounts') is not null and email is not null then
    execute $q$
      select plan from public.family_accounts
      where lower(email) = lower($1)
      limit 1
    $q$ into billed using email;
  end if;

  if (billed is null or btrim(billed) = '')
     and to_regclass('public.trial_accounts') is not null then
    execute 'select plan from public.trial_accounts where user_id = $1 limit 1'
      into billed using _user_id;
  end if;

  if (billed is null or btrim(billed) = '')
     and to_regclass('public.entitlement_state') is not null then
    execute $q$
      select plan from public.entitlement_state
      where user_id = $1
      order by updated_at desc nulls last
      limit 1
    $q$ into billed using _user_id;
  end if;

  billed := replace(lower(coalesce(nullif(btrim(billed), ''), 'basic')), '-', '_');
  if billed in ('pro', 'business', 'business_pro', 'businesspro') then
    return true;
  end if;
  return false;
end;
$$;

grant execute on function public.chat_video_allowed(uuid) to authenticated, service_role;

-- ── 2) Stamp known buyers (real Polar SKUs, not new products)
-- account_profiles.email/legal_name NOT NULL — sirf UPDATE, naya row yahan nahi.
update public.account_profiles p
set
  preferences = coalesce(p.preferences, '{}'::jsonb) || jsonb_build_object('workspace_kind', v.kind),
  onboarded = true,
  updated_at = now()
from auth.users u
join (
  values
    ('masoodsherwani@anexomail.com', 'personal'),
    ('humzasherwani@anexomail.com', 'business'),
    ('raanasherwani@anexomail.com', 'business')
) as v(email, kind) on lower(u.email) = v.email
where p.user_id = u.id;

-- Proof (passwords nahi)
select
  u.email,
  p.preferences->>'workspace_kind' as account_kind,
  f.plan as polar_sku
from auth.users u
left join public.account_profiles p on p.user_id = u.id
left join public.family_accounts f on lower(f.email) = lower(u.email)
where lower(u.email) in (
  'masoodsherwani@anexomail.com',
  'humzasherwani@anexomail.com',
  'raanasherwani@anexomail.com'
)
order by u.email;
