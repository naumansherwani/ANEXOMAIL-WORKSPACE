-- =============================================================================
-- E5 — Billing UI → polar_billing_state() connection
-- Supabase SQL Editor → poori file paste → Run. Idempotent.
--
-- Chain (no-touch preserved):
--   Polar webhook → Rust :3400 (PM2, no-touch)
--     → polar_subscriptions + entitlement_state → Supabase
--       → polar_billing_state() [Phase 50, no-touch]
--         → get_billing_subscription() [this file]
--           → Rust :3200 billing.subscription RPC (PRIMARY)
--             → Bun /api/billing/subscription (FALLBACK)
--               → useSubscription() → billing page UI
--
-- Fail rule: isi file ko theek likho. E5b / _fix / _v2 naam banned.
-- phase50 / phase51 / polar-payment / plans.ts — no-touch.
-- =============================================================================

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- SELF-HEAL: agar workspace_invoices exist karta hai magar polar_order_id
-- column nahi hai — rename to legacy, fresh create karo (Phase 50 pattern)
-- ---------------------------------------------------------------------------
do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'workspace_invoices'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'workspace_invoices'
      and column_name  = 'polar_order_id'
  ) then
    execute format(
      'alter table public.workspace_invoices rename to workspace_invoices_legacy_%s', ts
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) WORKSPACE_INVOICES — financial invoice rows from Polar order events
-- ---------------------------------------------------------------------------

create table if not exists public.workspace_invoices (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  polar_order_id  text unique,
  number          text,
  status          text not null default 'paid'
                  check (status in ('paid', 'open', 'void', 'uncollectible')),
  subtotal        numeric(12,2) not null default 0,
  tax             numeric(12,2) not null default 0,
  total           numeric(12,2) not null default 0,
  currency        text not null default 'GBP',
  period_start    timestamptz,
  period_end      timestamptz,
  issued_at       timestamptz not null default now(),
  paid_at         timestamptz,
  pdf_url         text,
  payload         jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);

create index if not exists workspace_invoices_user_issued_idx
  on public.workspace_invoices (user_id, issued_at desc);

alter table public.workspace_invoices enable row level security;

drop policy if exists "workspace_invoices_owner_read" on public.workspace_invoices;
create policy "workspace_invoices_owner_read"
  on public.workspace_invoices for select
  using (auth.uid() = user_id);

drop policy if exists "workspace_invoices_service_all" on public.workspace_invoices;
create policy "workspace_invoices_service_all"
  on public.workspace_invoices for all to service_role
  using (true) with check (true);

-- ---------------------------------------------------------------------------
-- 1b) Backfill from polar_webhook_inbox (order.paid events → invoice rows)
--     on conflict do nothing = safe to re-run
-- ---------------------------------------------------------------------------
insert into public.workspace_invoices
  (user_id, polar_order_id, number, status, subtotal, tax, total, currency,
   period_start, period_end, issued_at, paid_at, pdf_url, payload)
select distinct on ((wi.payload -> 'data' ->> 'id'))
  ps.user_id,
  wi.payload -> 'data' ->> 'id'                                           as polar_order_id,
  coalesce(
    wi.payload -> 'data' ->> 'number',
    'ORD-' || to_char(wi.received_at, 'YYYYMMDD')
  )                                                                        as number,
  'paid'                                                                   as status,
  coalesce(
    (wi.payload -> 'data' ->> 'subtotal_amount')::numeric / 100, 0
  )                                                                        as subtotal,
  coalesce(
    (wi.payload -> 'data' ->> 'tax_amount')::numeric / 100, 0
  )                                                                        as tax,
  coalesce(
    (wi.payload -> 'data' ->> 'total_amount')::numeric / 100, 0
  )                                                                        as total,
  coalesce(
    upper(wi.payload -> 'data' ->> 'currency'), 'GBP'
  )                                                                        as currency,
  null::timestamptz                                                        as period_start,
  null::timestamptz                                                        as period_end,
  wi.received_at                                                           as issued_at,
  wi.received_at                                                           as paid_at,
  wi.payload -> 'data' ->> 'invoice_pdf_url'                              as pdf_url,
  coalesce(wi.payload -> 'data', '{}'::jsonb)                              as payload
from public.polar_webhook_inbox wi
join public.polar_subscriptions ps on (
     (wi.payload -> 'data' ->> 'subscription_id')       = ps.polar_subscription_id
  or (wi.payload -> 'data' -> 'subscription' ->> 'id')  = ps.polar_subscription_id
)
where wi.event_type in ('order.paid', 'order.created')
  and ps.user_id is not null
  and (wi.payload -> 'data' ->> 'id') is not null
on conflict (polar_order_id) do nothing;

-- ---------------------------------------------------------------------------
-- 2) get_billing_subscription — called by Rust :3200 billing.subscription
--    Calls polar_billing_state() [Phase 50, no-touch] internally.
--    Maps product_key → plan_id / price / interval / storage for the UI.
-- ---------------------------------------------------------------------------
create or replace function public.get_billing_subscription(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw        jsonb;
  pk         text;
  plan_id    text;
  intv       text;
  price      integer;
  storage    integer;
  st         text;
  seats      integer;
  renews_at  timestamptz;
  cancel_at  timestamptz;
begin
  if p_user_id is null then return null; end if;

  -- Step 1: polar_billing_state() — Phase 50 function, no-touch
  raw      := public.polar_billing_state(p_user_id);
  pk       := lower(coalesce(raw ->> 'plan', ''));
  st       := coalesce(raw ->> 'status', 'none');
  seats    := coalesce((raw ->> 'seats')::integer, 1);
  renews_at := (raw ->> 'current_period_end')::timestamptz;

  -- Step 2: entitlement_state.plan = 'pro' (clean plan_id, canonical)
  select es.plan into plan_id
  from public.entitlement_state es
  where es.user_id = p_user_id
  limit 1;

  -- Step 3: parse product_key if entitlement_state empty
  if plan_id is null or plan_id = '' then
    plan_id := case
      when pk ilike '%business_pro%' or pk ilike '%businesspro%' then 'business_pro'
      when pk ilike '%business%'                                  then 'business'
      when pk ilike '%pro%'                                       then 'pro'
      when pk ilike '%basic%'                                     then 'basic'
      else null
    end;
  end if;

  -- Step 4: billing interval
  intv := case when pk ilike '%yearly%' then 'year' else 'month' end;

  -- Step 5: monthly list price (GBP)
  price := case plan_id
    when 'basic'        then 23
    when 'pro'          then 46
    when 'business'     then 97
    when 'business_pro' then 2850
    else 0
  end;

  -- Step 6: storage per mailbox (null = 1TB pooled for business_pro)
  storage := case plan_id
    when 'basic'    then 5
    when 'pro'      then 10
    when 'business' then 25
    else null
  end;

  -- Step 7: map Rust :3400 status → UI state
  st := case st
    when 'active'   then 'active'
    when 'past_due' then 'past_due'
    when 'grace'    then 'past_due'
    when 'canceled' then 'cancelled'
    when 'revoked'  then 'cancelled'
    else 'none'
  end;

  -- Step 8: cancel_at
  cancel_at := case
    when st = 'cancelled' then renews_at
    else null
  end;

  -- No subscription at all
  if plan_id is null then
    return jsonb_build_object(
      'plan',                   null,
      'state',                  'none',
      'price_per_seat',         0,
      'currency',               'GBP',
      'interval',               'month',
      'seats',                  0,
      'seats_used',             0,
      'storage_per_mailbox_gb', null,
      'renews_at',              null,
      'cancel_at',              null
    );
  end if;

  return jsonb_build_object(
    'plan',                   plan_id,
    'state',                  st,
    'price_per_seat',         price,
    'currency',               'GBP',
    'interval',               intv,
    'seats',                  seats,
    'seats_used',             1,
    'storage_per_mailbox_gb', storage,
    'renews_at',              renews_at,
    'cancel_at',              cancel_at
  );
end;
$$;

grant execute on function public.get_billing_subscription(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3) get_billing_invoices — called by Rust :3200 billing.invoices
-- ---------------------------------------------------------------------------
create or replace function public.get_billing_invoices(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare rows jsonb;
begin
  if p_user_id is null then
    return jsonb_build_object('invoices', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',           wi.id,
        'number',       coalesce(wi.number, 'INV-' || to_char(wi.issued_at, 'YYYYMMDD')),
        'state',        wi.status,
        'subtotal',     wi.subtotal,
        'tax',          wi.tax,
        'total',        wi.total,
        'currency',     wi.currency,
        'period_start', wi.period_start,
        'period_end',   wi.period_end,
        'issued_at',    wi.issued_at,
        'paid_at',      wi.paid_at,
        'pdf_url',      wi.pdf_url
      )
      order by wi.issued_at desc
    ),
    '[]'::jsonb
  )
  into rows
  from public.workspace_invoices wi
  where wi.user_id = p_user_id;

  return jsonb_build_object('invoices', rows);
end;
$$;

grant execute on function public.get_billing_invoices(uuid)
  to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Proof (paste in SQL editor to verify after run)
-- ---------------------------------------------------------------------------
-- select get_billing_subscription(auth.uid());
-- select get_billing_invoices(auth.uid());
-- select count(*) from workspace_invoices;
