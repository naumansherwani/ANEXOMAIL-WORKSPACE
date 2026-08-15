-- ============================================================
-- ANEXOMAIL — PHASE 46: PRICING v5 (FOUNDER LOCKED)
-- Chota, idempotent update. Naya table nahi — sirf price truth.
--
--   Basic        £23/user/mo   -> £253/yr    (1 month free)
--   Pro          £46/user/mo   -> £506/yr    (1 month free)
--   Business     £97/user/mo   -> £970/yr    (2 months free)
--   Business Pro £2,850/co/mo  -> £28,500/yr (2 months free)
--   Priority Support £790/mo
--   Managed Move-In: 1-5 £568 · 6-15 £1,670 · 16-29 £2,210 · 30+ £3,350
--
-- Polar product IDs same rehte hain (dashboard par price update ho chuki hai).
-- ============================================================

begin;

-- 1) Price book (Phase 43) — amounts refresh
do $$
begin
  if to_regclass('public.billing_price_book') is null then
    raise notice 'billing_price_book missing — pehle sql/phase43_annual_billing_lock.sql chalao';
    return;
  end if;

  update public.billing_price_book set amount_gbp = v.amt
  from (values
    ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY',        23::numeric),
    ('POLAR_PRODUCT_PLAN_BASIC_YEARLY',        253::numeric),
    ('POLAR_PRODUCT_PLAN_PRO_MONTHLY',          46::numeric),
    ('POLAR_PRODUCT_PLAN_PRO_YEARLY',          506::numeric),
    ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY',     97::numeric),
    ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY',     970::numeric),
    ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY', 2850::numeric),
    ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY', 28500::numeric),
    ('POLAR_PRODUCT_PRIORITY_SUPPORT',         790::numeric),
    ('POLAR_PRODUCT_MOVEIN_1_5',               568::numeric),
    ('POLAR_PRODUCT_MOVEIN_6_15',             1670::numeric),
    ('POLAR_PRODUCT_MOVEIN_16_29',            2210::numeric),
    ('POLAR_PRODUCT_MOVEIN_30PLUS',           3350::numeric)
  ) as v(env_key, amt)
  where public.billing_price_book.env_key = v.env_key;
end $$;

-- 2) Move-In band ladder (Phase 37 authority)
create or replace function public.movein_price_for(p_band text)
returns numeric language sql immutable as $$
  select case p_band
    when '1-5'    then 568
    when '6-15'   then 1670
    when '16-29'  then 2210
    when '30plus' then 3350
    else 568 end::numeric
$$;

-- 3) Naye deals ka default price
alter table public.movein_deals alter column price_gbp set default 568;

commit;

-- verify
-- select env_key, amount_gbp from public.billing_price_book order by env_key;
-- select public.movein_price_for('30plus');
