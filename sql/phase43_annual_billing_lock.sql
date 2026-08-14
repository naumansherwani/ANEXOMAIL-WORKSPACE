-- ============================================================================
-- ANEXOMAIL — Phase 43: ANNUAL BILLING LOCK  (v3 — FINAL, run this one)
--
-- SUPABASE = PAYMENT TRUTH. Polar sirf messenger hai.
-- Price ka faisla ab DB ki price book karti hai, code nahi.
--
-- Locked yearly truth:
--   Basic        £20/user/mo   -> £220/yr    (1 month free)
--   Pro          £40/user/mo   -> £440/yr    (1 month free)
--   Business     £85/user/mo   -> £850/yr    (2 months free)
--   Business Pro £2,500/co/mo  -> £25,000/yr (2 months free)
--   AI Pro £400/1,200cr · AI Business £1,500/5,000cr · AI Executive £4,000/10,000cr
--   (AI = backend only, Polar par koi AI product nahi)
--
-- Run after phase36_state_sync.sql. Idempotent + self-healing + additive.
-- Phase 44 Polar IDs are merged into this file. Do NOT run Phase 44 afterwards.
-- ============================================================================

begin;

-- PostgreSQL CREATE OR REPLACE cannot change a function's OUT row type.
-- Drop the exact old signatures first so a partially/previously applied Phase 36/43
-- can always be upgraded safely. Server calls are momentarily protected by this
-- transaction: either this whole migration commits, or the old state remains.
drop function if exists public.billing_sync_claim(integer);
drop function if exists public.billing_intent_open(uuid,text,text,text,text,text,integer,numeric,text);
drop function if exists public.billing_intent_open(uuid,text,text,text,text,text,integer,numeric,text,text);
drop function if exists public.billing_intent_confirm(uuid,text,text,numeric,text);
drop function if exists public.billing_intent_confirm(uuid,text,text,numeric,text,text,text);

alter table public.billing_intents
  add column if not exists billing_cycle text;
alter table public.entitlement_state
  add column if not exists ai_plan text;

update public.billing_intents
   set billing_cycle = case
     when product_key like '%_YEARLY' then 'yearly'
     when kind in ('plan','ai_plan','support') then 'monthly'
     else null
   end
 where billing_cycle is null;

alter table public.billing_intents
  drop constraint if exists billing_intents_billing_cycle_check;
alter table public.billing_intents
  add constraint billing_intents_billing_cycle_check
  check (billing_cycle is null or billing_cycle in ('monthly','yearly')) not valid;

-- ── 1) PRICE BOOK — ek hi authority (Supabase) ─────────────────────────────
do $$
begin
  if to_regclass('public.billing_price_book') is not null and exists (
    select 1
    from (values
      ('product_key'),('kind'),('plan'),('band'),('billing_cycle'),('amount_gbp'),
      ('per_seat'),('annual_rule'),('polar_listed'),('active'),('updated_at')
    ) required(column_name)
    where not exists (
      select 1 from information_schema.columns c
      where c.table_schema='public'
        and c.table_name='billing_price_book'
        and c.column_name=required.column_name
    )
  ) then
    execute format(
      'alter table public.billing_price_book rename to %I',
      'billing_price_book_legacy_' || extract(epoch from clock_timestamp())::bigint
    );
  end if;
end $$;

create table if not exists public.billing_price_book (
  product_key    text primary key,
  kind           text not null check (kind in ('plan','ai_plan','support','movein')),
  plan           text,
  band           text,
  billing_cycle  text check (billing_cycle in ('monthly','yearly')),
  amount_gbp     numeric(12,2) not null check (amount_gbp > 0),
  per_seat       boolean not null default false,
  annual_rule    text check (annual_rule in ('one-month-free','two-months-free')),
  polar_listed   boolean not null default true,
  active         boolean not null default true,
  polar_product_id text,
  polar_id_updated_at timestamptz,
  updated_at     timestamptz not null default now()
);

alter table public.billing_price_book
  add column if not exists polar_product_id text,
  add column if not exists polar_id_updated_at timestamptz;

grant select on public.billing_price_book to authenticated;
grant all    on public.billing_price_book to service_role;
alter table public.billing_price_book enable row level security;
drop policy if exists price_book_read on public.billing_price_book;
create policy price_book_read on public.billing_price_book
  for select to authenticated using (true);

insert into public.billing_price_book
  (product_key,kind,plan,band,billing_cycle,amount_gbp,per_seat,annual_rule,polar_listed) values
  ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY','plan','basic',null,'monthly',20,true,null,true),
  ('POLAR_PRODUCT_PLAN_BASIC_YEARLY','plan','basic',null,'yearly',220,true,'one-month-free',true),
  ('POLAR_PRODUCT_PLAN_PRO_MONTHLY','plan','pro',null,'monthly',40,true,null,true),
  ('POLAR_PRODUCT_PLAN_PRO_YEARLY','plan','pro',null,'yearly',440,true,'one-month-free',true),
  ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY','plan','business',null,'monthly',85,true,null,true),
  ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY','plan','business',null,'yearly',850,true,'two-months-free',true),
  ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY','plan','business_pro',null,'monthly',2500,false,null,true),
  ('POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY','plan','business_pro',null,'yearly',25000,false,'two-months-free',true),
  ('POLAR_PRODUCT_PRIORITY_SUPPORT','support',null,null,'monthly',700,false,null,true),
  ('POLAR_PRODUCT_MOVEIN_1_5','movein',null,'1-5',null,500,false,null,true),
  ('POLAR_PRODUCT_MOVEIN_6_15','movein',null,'6-15',null,1500,false,null,true),
  ('POLAR_PRODUCT_MOVEIN_16_29','movein',null,'16-29',null,2000,false,null,true),
  ('POLAR_PRODUCT_MOVEIN_30PLUS','movein',null,'30plus',null,3000,false,null,true),
  -- AI plans: backend only, Polar par nahi
  ('AI_PLAN_PRO_MONTHLY','ai_plan','ai_pro',null,'monthly',400,false,null,false),
  ('AI_PLAN_PRO_YEARLY','ai_plan','ai_pro',null,'yearly',4000,false,'two-months-free',false),
  ('AI_PLAN_BUSINESS_MONTHLY','ai_plan','ai_business',null,'monthly',1500,false,null,false),
  ('AI_PLAN_BUSINESS_YEARLY','ai_plan','ai_business',null,'yearly',15000,false,'two-months-free',false),
  ('AI_PLAN_EXECUTIVE_MONTHLY','ai_plan','ai_executive',null,'monthly',4000,false,null,false),
  ('AI_PLAN_EXECUTIVE_YEARLY','ai_plan','ai_executive',null,'yearly',40000,false,'two-months-free',false)
on conflict (product_key) do update set
  kind=excluded.kind, plan=excluded.plan, band=excluded.band,
  billing_cycle=excluded.billing_cycle, amount_gbp=excluded.amount_gbp,
  per_seat=excluded.per_seat, annual_rule=excluded.annual_rule,
  polar_listed=excluded.polar_listed, active=true, updated_at=now();

-- ── 1B) POLAR PRODUCT IDs v2 — real IDs locked in payment truth ────────────
update public.billing_price_book pb
set polar_product_id=v.pid, polar_id_updated_at=now()
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
) as v(product_key,pid)
where pb.product_key=v.product_key;

update public.billing_price_book
set polar_product_id=null, polar_id_updated_at=now()
where kind='ai_plan';

create or replace view public.billing_polar_id_gaps as
select product_key,kind,plan,billing_cycle,amount_gbp
from public.billing_price_book
where active and polar_listed and coalesce(polar_product_id,'')='';

grant select on public.billing_polar_id_gaps to service_role;

-- ── 2) INTENT OPEN — amount DB se, client se nahi ──────────────────────────
create or replace function public.billing_intent_open(
  p_user uuid,
  p_kind text,
  p_plan text default null,
  p_band text default null,
  p_product_key text default null,
  p_product_id text default null,
  p_seats int default 1,
  p_amount numeric default null,
  p_currency text default 'GBP',
  p_billing_cycle text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid; pb public.billing_price_book; v_seats int; v_amount numeric; v_cycle text;
begin
  if upper(coalesce(p_currency,'GBP')) <> 'GBP' then raise exception 'billing_currency_must_be_gbp'; end if;
  v_seats := greatest(1, coalesce(p_seats,1));

  select * into pb from public.billing_price_book
   where product_key = p_product_key and active;

  if pb.product_key is not null then
    v_cycle  := pb.billing_cycle;
    v_amount := pb.amount_gbp * (case when pb.per_seat then v_seats else 1 end);
    if p_amount is not null and abs(p_amount - v_amount) > 0.01 then
      raise exception 'price_book_mismatch expected % got %', v_amount, p_amount;
    end if;
  else
    v_cycle  := p_billing_cycle;
    v_amount := p_amount;
  end if;

  if v_amount is null or v_amount <= 0 then raise exception 'billing_amount_required'; end if;
  if v_cycle is not null and v_cycle not in ('monthly','yearly') then raise exception 'invalid_billing_cycle'; end if;

  select id into v_id from public.billing_intents
   where user_id = p_user and state = 'open'
     and coalesce(product_id,'') = coalesce(p_product_id,'')
     and coalesce(billing_cycle,'') = coalesce(v_cycle,'')
     and created_at > now() - interval '30 minutes'
   order by created_at desc limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.billing_intents
    (user_id,kind,plan,band,product_key,product_id,seats,amount_expected,currency,billing_cycle)
  values
    (p_user, coalesce(pb.kind,p_kind,'plan'), coalesce(pb.plan,p_plan), coalesce(pb.band,p_band),
     p_product_key, p_product_id, v_seats, v_amount, 'GBP', v_cycle)
  returning id into v_id;

  insert into public.billing_state_log (user_id,intent_id,from_state,to_state,reason,source,payload)
  values (p_user,v_id,null,'open','intent opened before checkout (price from DB price book)','app',
          jsonb_build_object('product_key',p_product_key,'billing_cycle',v_cycle,
                             'seats',v_seats,'amount_expected',v_amount,'currency','GBP'));
  return v_id;
end;
$$;

-- ── 3) CONFIRM — amount + currency + product must match, idempotent ────────
create or replace function public.billing_intent_confirm(
  p_intent uuid default null,
  p_checkout_id text default null,
  p_order_id text default null,
  p_amount numeric default null,
  p_source text default 'pull',
  p_currency text default 'GBP',
  p_product_id text default null
) returns table (intent_id uuid, state text, already boolean)
language plpgsql security definer set search_path = public as $$
declare r public.billing_intents;
begin
  select * into r from public.billing_intents
   where (p_intent is not null and id = p_intent)
      or (p_checkout_id is not null and polar_checkout_id = p_checkout_id)
   order by created_at desc limit 1 for update;

  if r.id is null then
    insert into public.payment_alerts (severity,kind,message)
    values ('critical','payment_without_intent','paid signal without matching intent');
    return query select null::uuid,'no_intent'::text,false;
    return;
  end if;
  if r.state = 'entitled' then return query select r.id,r.state,true; return; end if;

  if upper(coalesce(p_currency,'GBP')) <> upper(r.currency) then
    raise exception 'payment_currency_mismatch';
  end if;
  if p_product_id is not null and r.product_id is not null and p_product_id <> r.product_id then
    raise exception 'payment_product_mismatch';
  end if;
  p_amount := coalesce(p_amount,r.amount_paid);
  if p_amount is null or abs(p_amount - r.amount_expected) > 0.01 then
    raise exception 'payment_amount_mismatch expected % received %', r.amount_expected, p_amount;
  end if;

  update public.billing_intents set
    state='paid', paid_at=coalesce(paid_at,now()), polar_order_id=coalesce(p_order_id,polar_order_id),
    amount_paid=p_amount, source=p_source, last_error=null, updated_at=now()
  where id=r.id;

  insert into public.billing_state_log (user_id,intent_id,from_state,to_state,reason,source,payload)
  values (r.user_id,r.id,r.state,'paid','validated payment confirmed',p_source,
          jsonb_build_object('amount',p_amount,'currency',p_currency,'product_id',p_product_id));

  perform public.billing_apply_entitlement(r.user_id,r.kind,r.plan,r.band,r.seats,r.id,p_source);
  update public.billing_intents set state='entitled',resolved_at=now(),
    next_sync_at=now()+interval '100 years',updated_at=now() where id=r.id;
  return query select r.id,'entitled'::text,false;
end;
$$;

grant select on public.billing_intents to authenticated;
grant all on public.billing_intents to service_role;
revoke execute on function public.billing_intent_open(uuid,text,text,text,text,text,int,numeric,text,text) from public, anon, authenticated;
revoke execute on function public.billing_intent_confirm(uuid,text,text,numeric,text,text,text) from public, anon, authenticated;
grant execute on function public.billing_intent_open(uuid,text,text,text,text,text,int,numeric,text,text) to service_role;
grant execute on function public.billing_intent_confirm(uuid,text,text,numeric,text,text,text) to service_role;

-- ── 4) SWEEP — cycle bhi return karo ──────────────────────────────────────
-- Exact old signature was dropped at migration start because OUT columns changed.
create function public.billing_sync_claim(p_limit int default 25)
returns table (id uuid,user_id uuid,kind text,plan text,band text,product_id text,
               amount_expected numeric,amount_paid numeric,currency text,billing_cycle text,
               polar_checkout_id text,state text,attempts int,created_at timestamptz)
language sql security definer set search_path=public as $$
  select i.id,i.user_id,i.kind,i.plan,i.band,i.product_id,i.amount_expected,i.amount_paid,
         i.currency,i.billing_cycle,i.polar_checkout_id,i.state,i.attempts,i.created_at
  from public.billing_intents i
  where i.state in ('open','paid','stuck') and i.next_sync_at<=now()
  order by i.created_at asc limit greatest(1,least(p_limit,100));
$$;
revoke execute on function public.billing_sync_claim(int) from public,anon,authenticated;
grant execute on function public.billing_sync_claim(int) to service_role;

-- ── 5) AI plan catalog (locked v4) ────────────────────────────────────────
update public.ai_credit_plans set active=false;
insert into public.ai_credit_plans (id,name,price,monthly_credits,currency,active,sort_order) values
  ('ai_pro','AI Pro',400,1200,'GBP',true,1),
  ('ai_business','AI Business',1500,5000,'GBP',true,2),
  ('ai_executive','AI Executive',4000,10000,'GBP',true,3)
on conflict (id) do update set name=excluded.name,price=excluded.price,
  monthly_credits=excluded.monthly_credits,currency='GBP',active=true,sort_order=excluded.sort_order;

-- ── 6) ENTITLEMENT — yearly = 1 saal, monthly = 1 mahina ──────────────────
create or replace function public.billing_apply_entitlement(
  p_user uuid,p_kind text,p_plan text,p_band text,p_seats int,p_intent uuid,p_source text
) returns void
language plpgsql security definer set search_path=public as $$
declare v_credits int; v_before numeric; v_cycle text; v_active_until timestamptz;
begin
  select billing_cycle into v_cycle from public.billing_intents where id=p_intent;
  v_active_until := case
    when v_cycle='yearly' then now()+interval '1 year'
    when p_kind in ('plan','ai_plan','support') then now()+interval '1 month'
    else null
  end;
  insert into public.entitlement_state
    (user_id,plan,ai_plan,seats,movein_band,support_active,active_until,revision,source_intent,updated_at)
  values (
    p_user,
    case when p_kind='plan' then p_plan end,
    case when p_kind='ai_plan' then p_plan end,
    case when p_kind='plan' then greatest(1,coalesce(p_seats,1)) else 0 end,
    case when p_kind='movein' then p_band end,
    p_kind='support',
    v_active_until,
    1,p_intent,now()
  ) on conflict (user_id) do update set
    plan=coalesce(case when p_kind='plan' then p_plan end,entitlement_state.plan),
    ai_plan=coalesce(case when p_kind='ai_plan' then p_plan end,entitlement_state.ai_plan),
    seats=case when p_kind='plan' then greatest(1,coalesce(p_seats,1)) else entitlement_state.seats end,
    movein_band=coalesce(case when p_kind='movein' then p_band end,entitlement_state.movein_band),
    support_active=entitlement_state.support_active or p_kind='support',
    active_until=coalesce(v_active_until,entitlement_state.active_until),
    revision=entitlement_state.revision+1,source_intent=p_intent,updated_at=now();

  if p_kind='ai_plan' then
    select monthly_credits into v_credits from public.ai_credit_plans where id=p_plan and active;
    if v_credits is null then raise exception 'unknown_ai_plan'; end if;
    select subscription_credits into v_before from public.ai_credit_wallets where owner_id=p_user for update;
    update public.ai_credit_wallets set plan_id=p_plan,subscription_credits=v_credits,
      cycle_started_at=now(),renews_at=now()+interval '1 month',updated_at=now()
    where owner_id=p_user;
    if not found then raise exception 'ai_wallet_missing_for_user'; end if;
    insert into public.ai_credit_ledger
      (workspace_id,user_id,credit_type,entry_type,amount,balance_before,balance_after,reason,idempotency_key)
    select workspace_id,p_user,'subscription','plan_allocation',v_credits,coalesce(v_before,0),v_credits,
           'verified '||p_plan||' subscription payment','billing-intent:'||p_intent
    from public.ai_credit_wallets where owner_id=p_user
    on conflict (idempotency_key) do nothing;
  end if;

  insert into public.billing_state_log (user_id,intent_id,from_state,to_state,reason,source)
  values (p_user,p_intent,'paid','entitled','entitlement applied: '||coalesce(p_kind,'plan'),p_source);
end;
$$;
revoke execute on function public.billing_apply_entitlement(uuid,text,text,text,int,uuid,text) from public,anon,authenticated;
grant execute on function public.billing_apply_entitlement(uuid,text,text,text,int,uuid,text) to service_role;

-- ── 7) Founder radar: price book vs live intents ──────────────────────────
create or replace view public.billing_price_audit as
select i.id as intent_id, i.user_id, i.product_key, i.billing_cycle, i.seats,
       i.amount_expected, i.amount_paid,
       pb.amount_gbp * (case when pb.per_seat then greatest(1,i.seats) else 1 end) as book_amount,
       (i.amount_expected is distinct from
        pb.amount_gbp * (case when pb.per_seat then greatest(1,i.seats) else 1 end)) as mismatch,
       i.state, i.created_at
from public.billing_intents i
left join public.billing_price_book pb on pb.product_key = i.product_key
order by i.created_at desc;

grant select on public.billing_price_audit to service_role;

commit;

-- SUCCESS REPORT: both counts must be zero.
select
  (select count(*) from public.billing_polar_id_gaps) as missing_polar_ids,
  (select count(*) from public.billing_price_audit where mismatch) as price_mismatches;
