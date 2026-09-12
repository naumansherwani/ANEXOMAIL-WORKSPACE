-- =============================================================================
-- E5 — Billing UI → polar_billing_state() connection
-- Supabase SQL Editor → poori file paste → Run. Idempotent.
--
-- DESIGN (locked):
--   polar_billing_state(_user uuid) — Phase 50 mein ALREADY hai. No-touch.
--   Woh polar_subscriptions se product_key return karta hai.
--
--   Yeh file SIRF yeh kaam karta hai:
--   1. workspace_invoices table (real invoice rows from polar_webhook_inbox)
--   2. get_billing_subscription(p_user_id) — calls polar_billing_state() INSIDE
--      + maps product_key -> plan_id, price, interval, storage
--   3. get_billing_invoices(p_user_id) — workspace_invoices se
--   4. RLS + grants
--
-- Chain (DO NOT CHANGE):
--   Polar webhook → Rust :3400 (PM2, no-touch)
--     → polar_subscriptions + entitlement_state → Supabase
--       → polar_billing_state() [Phase 50, no-touch]
--         → get_billing_subscription() [this file]
--           → Rust :3200 billing.subscription RPC
--             → Frontend useSubscription() (billing-platform.ts)
--
-- Fail rule: isi file ko theek likho. E5b / _fix / _v2 naam banned.
-- phase50 / phase51 / polar-payment / plans.ts — no-touch.
-- =============================================================================

set search_path = public, extensions;

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
--     Runs once; on conflict do nothing = safe to re-run.
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
     (wi.payload -> 'data' ->> 'subscription_id')        = ps.polar_subscription_id
  or (wi.payload -> 'data' -> 'subscription' ->> 'id')   = ps.polar_subscription_id
  or (wi.payload -> 'data' -> 'metadata' ->> 'polar_subscription_id') = ps.polar_subscription_id
)
where wi.event_type in ('order.paid', 'order.created')
  and ps.user_id is not null
  and (wi.payload -> 'data' ->> 'id') is not null
on conflict (polar_order_id) do nothing;

-- ---------------------------------------------------------------------------
-- 2) get_billing_subscription — /rpc/billing.subscription (Rust :3200)
--
-- Calls polar_billing_state() internally (Phase 50, NO TOUCH to that function).
-- Maps product_key -> plan_id / price / interval / storage for the UI.
--
-- product_key format (from polar_subscriptions, Rust :3400 writes this):
--   POLAR_PRODUCT_PLAN_PRO_MONTHLY
--   POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY
--   etc.
-- ---------------------------------------------------------------------------
create or replace function public.get_billing_subscription(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw        jsonb;         -- polar_billing_state() output
  pk         text;          -- product_key from Phase 50
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

  -- ── Step 1: call polar_billing_state() — Phase 50 function, no-touch ──
  raw := public.polar_billing_state(p_user_id);

  pk     := lower(coalesce(raw ->> 'plan', ''));
  st     := coalesce(raw ->> 'status', 'none');
  seats  := coalesce((raw ->> 'seats')::integer, 1);
  renews_at := (raw ->> 'current_period_end')::timestamptz;

  -- ── Step 2: also try entitlement_state for canonical plan_id ─────────
  -- entitlement_state.plan = 'pro' (clean) — more reliable than product_key parsing
  if plan_id is null or plan_id = '' then
    select es.plan into plan_id
    from public.entitlement_state es
    where es.user_id = p_user_id
    limit 1;
  end if;

  -- ── Step 3: parse product_key if entitlement_state has no plan ────────
  if plan_id is null or plan_id = '' then
    plan_id := case
      when pk ilike '%business_pro%' or pk ilike '%businesspro%' then 'business_pro'
      when pk ilike '%business%'                                  then 'business'
      when pk ilike '%pro%'                                       then 'pro'
      when pk ilike '%basic%'                                     then 'basic'
      else null
    end;
  end if;

  -- ── Step 4: billing interval from product_key ────────────────────────
  intv := case when pk ilike '%yearly%' then 'year' else 'month' end;

  -- ── Step 5: price from plan (GBP per month) ──────────────────────────
  price := case plan_id
    when 'basic'        then 23
    when 'pro'          then 46
    when 'business'     then 97
    when 'business_pro' then 2850
    else 0
  end;

  -- ── Step 6: storage per mailbox (null = pooled) ───────────────────────
  storage := case plan_id
    when 'basic'        then 5
    when 'pro'          then 10
    when 'business'     then 25
    else null  -- business_pro: 1TB pooled
  end;

  -- ── Step 7: cancel_at ─────────────────────────────────────────────────
  cancel_at := case
    when st in ('canceled', 'cancelled', 'revoked') then renews_at
    else null
  end;

  -- ── Step 8: map Rust :3400 status -> UI state ─────────────────────────
  st := case st
    when 'active'   then 'active'
    when 'past_due' then 'past_due'
    when 'grace'    then 'past_due'
    when 'canceled' then 'cancelled'
    when 'revoked'  then 'cancelled'
    when 'none'     then 'none'
    else coalesce(nullif(st, ''), 'none')
  end;

  -- No subscription at all
  if plan_id is null then
    return jsonb_build_object(
      'plan',                  null,
      'state',                 'none',
      'price_per_seat',        0,
      'currency',              'GBP',
      'interval',              'month',
      'seats',                 0,
      'seats_used',            0,
      'storage_per_mailbox_gb', null,
      'renews_at',             null,
      'cancel_at',             null
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
-- 3) get_billing_invoices — /rpc/billing.invoices (Rust :3200)
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
-- 4) Proof queries (run after paste to verify)
-- ---------------------------------------------------------------------------
-- Subscription (replace uuid with real user_id):
--   select get_billing_subscription('00000000-0000-0000-0000-000000000000');
--
-- Invoices:
--   select get_billing_invoices('00000000-0000-0000-0000-000000000000');
--
-- Invoice count per user:
--   select user_id, count(*) from workspace_invoices group by user_id;
--
-- Polar billing state (Phase 50 function, direct):
--   select polar_billing_state('00000000-0000-0000-0000-000000000000');
