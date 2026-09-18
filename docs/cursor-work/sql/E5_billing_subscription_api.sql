-- =============================================================================
-- E5 — Billing subscription + invoices API
-- Supabase #4 → SQL Editor → poori file paste → Run. Idempotent.
--
-- DESIGN (locked):
--   polar_billing_state(_user uuid) [Phase 50, no-touch] returns:
--     { "plan": "<product_key>",   ← NOTE: key is "plan", value is product_key
--       "status": "active|past_due|grace|canceled|revoked|none",
--       "seats": N,
--       "current_period_end": "...",
--       "grace_until": "...",
--       ... }
--
--   entitlement_state.plan [Phase 36] = clean plan_id: basic|pro|business|business_pro
--
-- PERSONAL vs BUSINESS distinction:
--   account_profiles.preferences->>'workspace_kind'  [Phase 65]
--   = 'personal' | 'business'
--
-- Display model (BILLING only — feature gates are plan-surface.ts, not here):
--   personal + basic         → Personal Basic    £23
--   personal + pro           → Personal Pro      £46
--   personal + business      → Personal Pro      £46  (same power, diff Polar SKU)
--   personal + business_pro  → Personal Premium  £2,850
--   business + business      → Business          £97
--   business + business_pro  → Business Pro      £2,850
--
-- SECURITY: both RPCs check auth.uid() = p_user_id (or service_role).
-- BILLING vs GATES: E5 returns display data. Entitlement/feature logic stays
--                   in plan-surface.ts (no hard-coded gates here).
--
-- Chain (no-touch preserved):
--   Polar webhook → Rust :3400 PM2 → polar_subscriptions → Supabase
--     → polar_billing_state() [Phase 50]
--       → get_billing_subscription() [this file]
--         → Rust :3200 billing.subscription (PRIMARY)
--           → Bun /api/billing/subscription (FALLBACK)
--             → useSubscription() → billing page
--
-- Fail rule: isi file ko theek likho. E5b/_fix/_v2 banned.
-- Phase 50 / 51 / polar-payment / plans.ts — no-touch.
-- =============================================================================

set search_path = public, extensions;

-- ---------------------------------------------------------------------------
-- SELF-HEAL: agar workspace_invoices exist karta hai lekin polar_order_id
-- nahi hai — rename to legacy, phir fresh table banta hai (Phase 50 pattern)
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
-- 1) WORKSPACE_INVOICES
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
-- 1b) Backfill from polar_webhook_inbox
--     Only order.paid events → paid invoice rows (never order.created)
--     DISTINCT ON with ORDER BY received_at desc = latest event per order wins
-- ---------------------------------------------------------------------------
insert into public.workspace_invoices
  (user_id, polar_order_id, number, status, subtotal, tax, total, currency,
   period_start, period_end, issued_at, paid_at, pdf_url, payload)
select distinct on ((wi.payload -> 'data' ->> 'id'))
  -- ORDER BY inside DISTINCT ON: latest event wins per order id
  ps.user_id,
  wi.payload -> 'data' ->> 'id'                                          as polar_order_id,
  coalesce(
    wi.payload -> 'data' ->> 'number',
    'ORD-' || to_char(wi.received_at, 'YYYYMMDD')
  )                                                                       as number,
  'paid'                                                                  as status,
  coalesce((wi.payload->'data'->>'subtotal_amount')::numeric / 100, 0)   as subtotal,
  coalesce((wi.payload->'data'->>'tax_amount')::numeric    / 100, 0)     as tax,
  coalesce((wi.payload->'data'->>'total_amount')::numeric  / 100, 0)     as total,
  coalesce(upper(wi.payload->'data'->>'currency'), 'GBP')                as currency,
  null::timestamptz                                                       as period_start,
  null::timestamptz                                                       as period_end,
  wi.received_at                                                          as issued_at,
  wi.received_at                                                          as paid_at,
  wi.payload->'data'->>'invoice_pdf_url'                                  as pdf_url,
  coalesce(wi.payload->'data', '{}'::jsonb)                               as payload
from public.polar_webhook_inbox wi
join public.polar_subscriptions ps on (
     (wi.payload->'data'->>'subscription_id')       = ps.polar_subscription_id
  or (wi.payload->'data'->'subscription'->>'id')    = ps.polar_subscription_id
)
where wi.event_type = 'order.paid'  -- only confirmed paid orders → paid invoices
  and ps.user_id is not null
  and (wi.payload->'data'->>'id') is not null
order by (wi.payload->'data'->>'id'), wi.received_at desc  -- deterministic: latest event per order
on conflict (polar_order_id) do nothing;

-- ---------------------------------------------------------------------------
-- 2) get_billing_subscription
--
-- SECURITY: caller must be the same user or service_role.
-- DISPLAY: returns kind-aware plan display (Personal Basic / Pro / Premium
--          vs Business / Business Pro). Feature gates stay in plan-surface.ts.
-- ---------------------------------------------------------------------------
create or replace function public.get_billing_subscription(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw          jsonb;
  -- polar_billing_state() returns key 'plan' whose value is the product_key
  -- e.g. "POLAR_PRODUCT_PLAN_PRO_MONTHLY" — NOT a clean plan_id.
  product_key_raw text;
  plan_id      text;   -- clean: basic | pro | business | business_pro
  kind         text;   -- personal | business (from account_profiles)
  intv         text;   -- month | year
  price        integer;
  storage      integer;
  display_name text;
  st           text;
  seats        integer;
  renews_at    timestamptz;
  cancel_at    timestamptz;
begin
  -- ── SECURITY: only own row or service_role ────────────────────────────────
  if auth.uid() is distinct from p_user_id
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if p_user_id is null then return null; end if;

  -- ── Step 1: account_kind — personal vs business [Phase 65] ───────────────
  select lower(nullif(btrim(coalesce(
    p.preferences->>'workspace_kind',
    ''
  )), ''))
  into kind
  from public.account_profiles p
  where p.user_id = p_user_id;

  -- ── Step 2: canonical plan_id from entitlement_state [Phase 36] ──────────
  select lower(nullif(btrim(es.plan), ''))
  into plan_id
  from public.entitlement_state es
  where es.user_id = p_user_id
  limit 1;

  -- ── Step 3: polar_billing_state() — Phase 50, no-touch ───────────────────
  --    Returns: { "plan": "<product_key_string>", "status": ..., "seats": ... }
  --    NOTE: key is literally "plan" even though value is a product_key.
  raw := public.polar_billing_state(p_user_id);
  product_key_raw := lower(coalesce(raw ->> 'plan', ''));
  st              := coalesce(raw ->> 'status', 'none');
  seats           := coalesce((raw ->> 'seats')::integer, 1);
  renews_at       := (raw ->> 'current_period_end')::timestamptz;

  -- ── Step 4: parse product_key → plan_id (fallback if entitlement empty) ───
  if plan_id is null or plan_id = '' then
    plan_id := case
      when product_key_raw ilike '%business_pro%'
        or product_key_raw ilike '%businesspro%'  then 'business_pro'
      when product_key_raw ilike '%business%'     then 'business'
      when product_key_raw ilike '%pro%'          then 'pro'
      when product_key_raw ilike '%basic%'        then 'basic'
      else null
    end;
  end if;

  -- ── Step 5: default kind from plan if still unknown ──────────────────────
  if kind is null or kind = '' then
    kind := case
      when plan_id in ('basic', 'pro') then 'personal'
      when plan_id in ('business', 'business_pro') then 'business'
      else 'personal'
    end;
  end if;

  -- ── Step 6: billing interval from product_key ────────────────────────────
  intv := case when product_key_raw ilike '%yearly%' then 'year' else 'month' end;

  -- ── Step 7: kind-aware display name + price + storage ────────────────────
  --    Billing display only. Feature power is plan-surface.ts featurePlan().
  --    Personal Pro = same POWER as Business Pro, but kind stays personal.
  if kind = 'personal' then
    case plan_id
      when 'basic' then
        display_name := 'Personal Basic';
        price        := 23;
        storage      := 5;
      when 'pro' then
        display_name := 'Personal Pro';
        price        := 46;
        storage      := 10;
      when 'business' then
        -- Personal account on Business SKU → treated as Personal Pro
        display_name := 'Personal Pro';
        price        := 46;
        storage      := 10;
      when 'business_pro' then
        display_name := 'Personal Premium';
        price        := 2850;
        storage      := null;  -- 1TB pooled
      else
        display_name := 'Personal Basic';
        price        := 23;
        storage      := 5;
    end case;
  else
    -- business kind
    case plan_id
      when 'business' then
        display_name := 'Business';
        price        := 97;
        storage      := 25;
      when 'business_pro' then
        display_name := 'Business Pro';
        price        := 2850;
        storage      := null;  -- 1TB pooled
      else
        -- basic/pro on a business account (should not happen, but handle safely)
        display_name := 'Business';
        price        := 97;
        storage      := 25;
    end case;
  end if;

  -- ── Step 8: map Rust :3400 status → UI state ─────────────────────────────
  st := case st
    when 'active'   then 'active'
    when 'past_due' then 'past_due'
    when 'grace'    then 'past_due'
    when 'canceled' then 'cancelled'
    when 'revoked'  then 'cancelled'
    else 'none'
  end;

  cancel_at := case when st = 'cancelled' then renews_at else null end;

  -- No subscription at all
  if plan_id is null then
    return jsonb_build_object(
      'plan',                   null,
      'kind',                   coalesce(kind, 'personal'),
      'display_name',           null,
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
    'kind',                   kind,
    'display_name',           display_name,
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
-- 3) get_billing_invoices
--
-- SECURITY: caller must be the same user or service_role.
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
  -- ── SECURITY ───────────────────────────────────────────────────────────────
  if auth.uid() is distinct from p_user_id
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;

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
-- Proof queries
-- ---------------------------------------------------------------------------
-- select get_billing_subscription(auth.uid());
-- select get_billing_invoices(auth.uid());
-- select count(*), status from workspace_invoices group by status;
