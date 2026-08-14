-- ANEXOMAIL — Phase 44: POLAR PRODUCT IDs v2 (LOCKED 14 Aug 2026)
-- Supabase #4 SQL Editor mein poora block chalao. Idempotent.
--
-- Purane plan/support Polar products retire ho gaye. Move-In (one-time) IDs wahi hain.
-- Asli checkout ID backend .env se aata hai; yeh table sirf TRUTH/audit record hai.

alter table public.billing_price_book
  add column if not exists polar_product_id text,
  add column if not exists polar_id_updated_at timestamptz;

update public.billing_price_book set polar_product_id = v.pid, polar_id_updated_at = now()
from (values
  ('POLAR_PRODUCT_MOVEIN_1_5','fdcdabc2-9e50-4e4b-91d4-45e4128ef829'),
  ('POLAR_PRODUCT_MOVEIN_6_15','a9d1bec3-0d5f-4b9b-ae1c-993efde66da2'),
  ('POLAR_PRODUCT_MOVEIN_16_29','c7b502c5-ff75-4138-b34d-25d94878fe79'),
  ('POLAR_PRODUCT_MOVEIN_30PLUS','f3ff5002-b55f-45b5-b0b9-d80c1f33d3c8'),
  ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY','5e1c7b50-fee5-4214-873c-ad9f350476d9'),
  ('POLAR_PRODUCT_PLAN_BASIC_YEARLY','d3642ce7-a750-484c-940f-eb39039ed9c2'),
  ('POLAR_PRODUCT_PLAN_PRO_MONTHLY','df1aa320-346f-451b-a16a-e737c0703e12'),
  ('POLAR_PRODUCT_PLAN_PRO_YEARLY','7d87a72e-6be6-4aa2-86d6-5eca3d448956'),
  ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY','b12be1b1-a02d-4701-9475-08e796d99b69'),
  ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY','7a1d5445-92c5-4472-81a3-4820b8579854'),
  ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY','3a1e1699-59c0-4334-8be0-d4b08a1202d1'),
  ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY','80bca014-b832-474e-bd3e-084a04453de0'),
  ('POLAR_PRODUCT_PRIORITY_SUPPORT','8f6d7c8e-1722-421f-b28c-2a031f63731d')
) as v(key,pid)
where public.billing_price_book.product_key = v.key;

-- AI plans Polar par nahi: ID hamesha null
update public.billing_price_book set polar_product_id = null
where kind = 'ai_plan';

-- Radar: koi Polar-listed row bina ID reh gayi?
create or replace view public.billing_polar_id_gaps as
select product_key, kind, plan, billing_cycle, amount_gbp
from public.billing_price_book
where active and polar_listed and coalesce(polar_product_id,'') = '';

grant select on public.billing_polar_id_gaps to service_role;

-- Report
select product_key, billing_cycle, amount_gbp, polar_product_id
from public.billing_price_book
where polar_listed
order by kind, plan nulls first, billing_cycle;
