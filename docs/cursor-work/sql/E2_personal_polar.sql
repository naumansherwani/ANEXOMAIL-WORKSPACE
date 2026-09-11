-- =============================================================================
-- E2 — personal Polar map (Personal users only)
-- Supabase #4 SQL Editor — poori file paste → Run. Idempotent.
--
-- Polar webhook / plans.ts / landing NO TOUCH. Personal Polar SKU nahi.
-- Landing cards: Basic £23 · Pro £46 · Business £97 · Business Pro £2,850.
-- Yeh table SIRF Personal kind ke liye: Polar SKU → Personal Basic / Pro / Premium.
-- Business £97 is table mein nahi (company card).
-- Fail = isi file ko theek likho. phase65 / E2b naam banned.
-- =============================================================================
set search_path = public, extensions;

create table if not exists public.personal_polar_map (
  polar_sku text primary key,
  personal_name text not null,
  power_plan text not null,
  polar_price_gbp numeric not null,
  note text
);

insert into public.personal_polar_map (polar_sku, personal_name, power_plan, polar_price_gbp, note)
values
  (
    'basic',
    'Personal Basic',
    'basic',
    23,
    'Landing Basic card. Mail People Calendar Work. Chat/full CRM nahi.'
  ),
  (
    'pro',
    'Personal Pro',
    'business_pro',
    46,
    'Landing Pro card. Power = Business Pro. Org nahi.'
  ),
  (
    'business_pro',
    'Personal Premium',
    'business_pro',
    2850,
    'Landing Business Pro card + kind personal. Same Polar SKU. Org nahi.'
  )
on conflict (polar_sku) do update
set
  personal_name = excluded.personal_name,
  power_plan = excluded.power_plan,
  polar_price_gbp = excluded.polar_price_gbp,
  note = excluded.note;

create or replace function public.personal_name_for_polar(_plan text)
returns text
language sql
stable
as $$
  select m.personal_name
  from public.personal_polar_map m
  where m.polar_sku = replace(lower(coalesce(nullif(btrim(_plan), ''), '')), '-', '_')
  limit 1;
$$;

create or replace function public.personal_workspace_label(_user_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  kind text;
  billed text := 'basic';
  email text;
begin
  if _user_id is null then return null; end if;

  select lower(nullif(btrim(p.preferences->>'workspace_kind'), ''))
    into kind
  from public.account_profiles p
  where p.user_id = _user_id;

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
  if billed = 'businesspro' then billed := 'business_pro'; end if;

  if kind is null then
    if billed in ('basic', 'pro') then
      kind := 'personal';
    else
      return null;
    end if;
  end if;

  if kind <> 'personal' then
    return null;
  end if;

  return public.personal_name_for_polar(billed);
end;
$$;

grant execute on function public.personal_name_for_polar(text) to authenticated, service_role;
grant execute on function public.personal_workspace_label(uuid) to authenticated, service_role;
grant select on public.personal_polar_map to authenticated, anon, service_role;

-- Proof — Personal rows only. Business £97 yahan nahi.
select polar_sku, personal_name, polar_price_gbp
from public.personal_polar_map
order by polar_price_gbp;
