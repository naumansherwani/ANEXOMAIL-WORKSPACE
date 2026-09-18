-- =============================================================================
-- E13 — separate Personal Polar products + payment guard
-- Supabase #4 SQL Editor — Personal Polar IDs banne ke BAAD placeholders replace
-- karke poori file paste → Run. Idempotent. Phase 43/60–65 NO TOUCH.
-- =============================================================================
set search_path = public, extensions;

alter table public.billing_price_book
  add column if not exists required_account_kind text;

alter table public.billing_price_book
  drop constraint if exists billing_price_book_required_account_kind_check;
alter table public.billing_price_book
  add constraint billing_price_book_required_account_kind_check
  check (required_account_kind is null or required_account_kind in ('personal','business'));

insert into public.billing_price_book
  (product_key,kind,plan,band,billing_cycle,amount_gbp,per_seat,annual_rule,
   polar_listed,active,required_account_kind,polar_product_id)
values
  ('POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY','plan','basic',null,'monthly',17,false,null,true,true,'personal','REPLACE_PERSONAL_BASIC_MONTHLY_ID'),
  ('POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY','plan','basic',null,'yearly',187,false,'one-month-free',true,true,'personal','REPLACE_PERSONAL_BASIC_YEARLY_ID'),
  ('POLAR_PRODUCT_PLAN_PERSONAL_PRO_MONTHLY','plan','pro',null,'monthly',83,false,null,true,true,'personal','REPLACE_PERSONAL_PRO_MONTHLY_ID'),
  ('POLAR_PRODUCT_PLAN_PERSONAL_PRO_YEARLY','plan','pro',null,'yearly',913,false,'one-month-free',true,true,'personal','REPLACE_PERSONAL_PRO_YEARLY_ID'),
  ('POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY','plan','business_pro',null,'monthly',1850,false,null,true,true,'personal','REPLACE_PERSONAL_PREMIUM_MONTHLY_ID'),
  ('POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY','plan','business_pro',null,'yearly',18500,false,'two-months-free',true,true,'personal','REPLACE_PERSONAL_PREMIUM_YEARLY_ID')
on conflict (product_key) do update set
  kind=excluded.kind,
  plan=excluded.plan,
  band=excluded.band,
  billing_cycle=excluded.billing_cycle,
  amount_gbp=excluded.amount_gbp,
  per_seat=excluded.per_seat,
  annual_rule=excluded.annual_rule,
  polar_listed=excluded.polar_listed,
  active=excluded.active,
  required_account_kind=excluded.required_account_kind,
  polar_product_id=excluded.polar_product_id,
  polar_id_updated_at=now(),
  updated_at=now();

create or replace function public.billing_personal_product_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  required_kind text;
  actual_kind text;
  expected_product_id text;
begin
  -- SIRF Personal products. Business/koi bhi doosra product_key untouched.
  if new.product_key is null
     or new.product_key not like 'POLAR_PRODUCT_PLAN_PERSONAL_%' then
    return new;
  end if;

  select pb.required_account_kind, pb.polar_product_id
    into required_kind, expected_product_id
  from public.billing_price_book pb
  where pb.product_key = new.product_key and pb.active;

  if required_kind is null then
    return new;
  end if;

  if new.user_id is null then
    raise exception 'personal_product_requires_authenticated_user';
  end if;

  select lower(nullif(btrim(p.preferences->>'workspace_kind'), ''))
    into actual_kind
  from public.account_profiles p
  where p.user_id = new.user_id;

  if actual_kind is distinct from required_kind then
    raise exception 'product_not_available_for_account_kind';
  end if;

  if expected_product_id is null
     or expected_product_id = ''
     or expected_product_id like 'REPLACE_%' then
    raise exception 'personal_polar_product_id_missing';
  end if;

  if new.product_id is distinct from expected_product_id then
    raise exception 'personal_polar_product_id_mismatch';
  end if;

  return new;
end;
$$;

revoke execute on function public.billing_personal_product_guard() from public, anon, authenticated;
grant execute on function public.billing_personal_product_guard() to service_role;

drop trigger if exists billing_personal_product_guard_trg on public.billing_intents;
create trigger billing_personal_product_guard_trg
before insert or update of user_id, product_key, product_id
on public.billing_intents
for each row execute function public.billing_personal_product_guard();

update public.personal_polar_map
set personal_name = case polar_sku
      when 'basic' then 'Personal Basic'
      when 'pro' then 'Personal Pro+'
      when 'business_pro' then 'Personal Premium'
    end,
    polar_price_gbp = case polar_sku
      when 'basic' then 17
      when 'pro' then 83
      when 'business_pro' then 1850
    end,
    note = case polar_sku
      when 'basic' then 'Separate Personal Basic product. Chat/full CRM nahi.'
      when 'pro' then 'Separate Personal Pro+ product. Business Pro power; Org nahi.'
      when 'business_pro' then 'Separate Personal Premium product. Org nahi.'
    end
where polar_sku in ('basic','pro','business_pro');

select product_key, plan, billing_cycle, amount_gbp, required_account_kind,
       case
          when polar_product_id is null or polar_product_id = '' or polar_product_id like 'REPLACE_%'
            then 'MISSING_ID'
          else 'READY'
       end as polar_id_status
from public.billing_price_book
where product_key like 'POLAR_PRODUCT_PLAN_PERSONAL_%'
order by amount_gbp;