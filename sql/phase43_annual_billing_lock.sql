-- ============================================================================
-- ANEXOMAIL — Phase 43: ANNUAL BILLING LOCK
-- Exact yearly truth + server-side amount/product/currency validation.
-- Run after phase36_state_sync.sql. Idempotent and additive.
-- ============================================================================

begin;

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
declare v_id uuid;
begin
  if p_currency <> 'GBP' then raise exception 'billing_currency_must_be_gbp'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'billing_amount_required'; end if;
  if p_billing_cycle is not null and p_billing_cycle not in ('monthly','yearly') then
    raise exception 'invalid_billing_cycle';
  end if;

  select id into v_id from public.billing_intents
   where user_id = p_user and state = 'open'
     and coalesce(product_id,'') = coalesce(p_product_id,'')
     and coalesce(billing_cycle,'') = coalesce(p_billing_cycle,'')
     and created_at > now() - interval '30 minutes'
   order by created_at desc limit 1;
  if v_id is not null then return v_id; end if;

  insert into public.billing_intents
    (user_id,kind,plan,band,product_key,product_id,seats,amount_expected,currency,billing_cycle)
  values
    (p_user,coalesce(p_kind,'plan'),p_plan,p_band,p_product_key,p_product_id,
     greatest(1,coalesce(p_seats,1)),p_amount,'GBP',p_billing_cycle)
  returning id into v_id;

  insert into public.billing_state_log (user_id,intent_id,from_state,to_state,reason,source,payload)
  values (p_user,v_id,null,'open','intent opened before checkout','app',
          jsonb_build_object('product_key',p_product_key,'billing_cycle',p_billing_cycle,
                             'amount_expected',p_amount,'currency','GBP'));
  return v_id;
end;
$$;

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

  if upper(coalesce(p_currency,'')) <> upper(r.currency) then
    raise exception 'payment_currency_mismatch';
  end if;
  if p_product_id is not null and p_product_id <> r.product_id then
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

create or replace function public.billing_sync_claim(p_limit int default 25)
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

-- Retire old AI catalog rows and make the locked v4 plans authoritative.
update public.ai_credit_plans set active=false;
insert into public.ai_credit_plans (id,name,price,monthly_credits,currency,active,sort_order) values
  ('ai_pro','AI Pro',400,1200,'GBP',true,1),
  ('ai_business','AI Business',1500,5000,'GBP',true,2),
  ('ai_executive','AI Executive',4000,10000,'GBP',true,3)
on conflict (id) do update set name=excluded.name,price=excluded.price,
  monthly_credits=excluded.monthly_credits,currency='GBP',active=true,sort_order=excluded.sort_order;

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

commit;