-- ============================================================
-- ANEXOMAIL — PHASE 46: PRICING v5 (FOUNDER LOCKED)  [v2 fix]
-- Column naam `product_key` hai (env_key nahi). Idempotent + self-healing.
--
--   Basic        £23/user/mo   -> £253/yr    (1 month free)
--   Pro          £46/user/mo   -> £506/yr    (1 month free)
--   Business     £97/user/mo   -> £970/yr    (2 months free)
--   Business Pro £2,850/co/mo  -> £28,500/yr (2 months free)
--   Priority Support £790/mo
--   Move-In: 1-5 £568 · 6-15 £1,670 · 16-29 £2,210 · 30+ £3,350
-- Polar product IDs same rehte hain.
-- ============================================================

begin;

-- 1) Price book refresh (upsert — row missing ho to ban jaye)
do $$
begin
  if to_regclass('public.billing_price_book') is null then
    raise notice 'billing_price_book missing — pehle sql/phase43_annual_billing_lock.sql chalao';
    return;
  end if;

  insert into public.billing_price_book
    (product_key, kind, plan, band, billing_cycle, amount_gbp, per_seat, annual_rule, polar_listed)
  values
    ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY','plan','basic',null,'monthly',23,true,null,true),
    ('POLAR_PRODUCT_PLAN_BASIC_YEARLY','plan','basic',null,'yearly',253,true,'one-month-free',true),
    ('POLAR_PRODUCT_PLAN_PRO_MONTHLY','plan','pro',null,'monthly',46,true,null,true),
    ('POLAR_PRODUCT_PLAN_PRO_YEARLY','plan','pro',null,'yearly',506,true,'one-month-free',true),
    ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY','plan','business',null,'monthly',97,true,null,true),
    ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY','plan','business',null,'yearly',970,true,'two-months-free',true),
    ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY','plan','business_pro',null,'monthly',2850,false,null,true),
    ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY','plan','business_pro',null,'yearly',28500,false,'two-months-free',true),
    ('POLAR_PRODUCT_PRIORITY_SUPPORT','support',null,null,'monthly',790,false,null,true),
    ('POLAR_PRODUCT_MOVEIN_1_5','movein',null,'1-5',null,568,false,null,true),
    ('POLAR_PRODUCT_MOVEIN_6_15','movein',null,'6-15',null,1670,false,null,true),
    ('POLAR_PRODUCT_MOVEIN_16_29','movein',null,'16-29',null,2210,false,null,true),
    ('POLAR_PRODUCT_MOVEIN_30PLUS','movein',null,'30plus',null,3350,false,null,true)
  on conflict (product_key) do update
    set amount_gbp  = excluded.amount_gbp,
        kind        = excluded.kind,
        plan        = excluded.plan,
        band        = excluded.band,
        billing_cycle = excluded.billing_cycle,
        per_seat    = excluded.per_seat,
        annual_rule = excluded.annual_rule,
        active      = true,
        updated_at  = now();
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
do $$
begin
  if to_regclass('public.movein_deals') is not null then
    alter table public.movein_deals alter column price_gbp set default 568;
  end if;
end $$;

commit;

-- verify
-- select product_key, amount_gbp from public.billing_price_book order by product_key;
-- select public.movein_price_for('30plus');
