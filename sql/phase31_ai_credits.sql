-- ANEXOMAIL — Phase 31: AI Credit Engine (Supabase #4)
-- FOUNDER LOCK (4 hard rules):
--   1. Supabase = source of truth
--   2. Ledger = immutable financial history (never update/delete, only reverse)
--   3. Backend/RPC = only place allowed to change credits
--   4. Frontend = display/approval only
-- Idempotent + self-healing. Grants pehle, phir RLS.

create extension if not exists pgcrypto;

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_credit_wallets')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_credit_wallets' and column_name='topup_credits') then
    execute format('alter table public.ai_credit_wallets rename to ai_credit_wallets_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_credit_ledger')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_credit_ledger' and column_name='idempotency_key') then
    execute format('alter table public.ai_credit_ledger rename to ai_credit_ledger_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_actions')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_actions' and column_name='reserved_credits') then
    execute format('alter table public.ai_actions rename to ai_actions_legacy_%s', ts);
  end if;
end $$;

-- ─── 1. WALLET ────────────────────────────────────────────────
create table if not exists public.ai_credit_wallets (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  owner_id uuid references auth.users(id) on delete cascade,
  plan_id text,
  subscription_credits numeric(14,3) not null default 0,
  topup_credits numeric(14,3) not null default 0,
  complimentary_credits numeric(14,3) not null default 0,
  reserved_credits numeric(14,3) not null default 0,
  total_balance numeric(14,3) generated always as
    (subscription_credits + topup_credits + complimentary_credits - reserved_credits) stored,
  currency text not null default 'GBP',
  cycle_started_at timestamptz not null default now(),
  renews_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (workspace_id)
);

-- ─── 2. IMMUTABLE LEDGER ──────────────────────────────────────
create table if not exists public.ai_credit_ledger (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  action_id uuid,
  credit_type text not null check (credit_type in ('subscription','topup','complimentary','reserved')),
  entry_type text not null check (entry_type in
    ('plan_allocation','topup_purchase','complimentary_grant','reservation','release','charge','refund','expiry','reversal','correction')),
  amount numeric(14,3) not null,
  balance_before numeric(14,3) not null default 0,
  balance_after numeric(14,3) not null default 0,
  reason text,
  model text,
  estimated_credits numeric(14,3),
  actual_credits numeric(14,3),
  idempotency_key text unique,
  created_at timestamptz not null default now()
);
create index if not exists ai_credit_ledger_ws_idx on public.ai_credit_ledger (workspace_id, created_at desc);

-- Ledger immutable: no update, no delete (reverse entry banao)
create or replace function public.ai_ledger_immutable() returns trigger
language plpgsql as $$ begin
  raise exception 'ai_credit_ledger is immutable — create a reversal entry instead';
end $$;
drop trigger if exists ai_ledger_no_update on public.ai_credit_ledger;
create trigger ai_ledger_no_update before update or delete on public.ai_credit_ledger
  for each row execute function public.ai_ledger_immutable();

-- ─── 3. TOP-UP PRODUCTS (locked) ──────────────────────────────
create table if not exists public.ai_credit_topup_products (
  id text primary key,
  price numeric(12,2) not null,
  credits integer not null,
  price_per_credit numeric(12,4) not null,
  currency text not null default 'GBP',
  public_visible boolean not null default true,
  active boolean not null default true,
  sort_order integer not null default 0
);

insert into public.ai_credit_topup_products (id, price, credits, price_per_credit, public_visible, sort_order) values
  ('tu_15',     15.00,    40, 0.3750, true,  1),
  ('tu_30',     30.00,    75, 0.4000, true,  2),
  ('tu_60',     60.00,   170, 0.3530, true,  3),
  ('tu_120',   120.00,   360, 0.3330, true,  4),
  ('tu_250',   250.00,   800, 0.3130, true,  5),
  ('tu_500',   500.00,  1800, 0.2780, true,  6),
  ('tu_1000', 1000.00,  4000, 0.2500, true,  7),
  ('tu_2000', 2000.00,  9000, 0.2220, true,  8),
  ('tu_5000', 5000.00, 21000, 0.2380, false, 9)
on conflict (id) do update set
  price = excluded.price, credits = excluded.credits,
  price_per_credit = excluded.price_per_credit,
  public_visible = excluded.public_visible,
  sort_order = excluded.sort_order, active = true;

-- ─── 4. SUBSCRIPTION PLANS (locked) ───────────────────────────
create table if not exists public.ai_credit_plans (
  id text primary key,
  name text not null,
  price numeric(12,2) not null,
  monthly_credits integer not null,
  currency text not null default 'GBP',
  active boolean not null default true,
  sort_order integer not null default 0
);

insert into public.ai_credit_plans (id, name, price, monthly_credits, sort_order) values
  ('ai',            'ANEXOMAIL AI',            135.00,   400, 1),
  ('ai_pro',        'ANEXOMAIL AI Pro',        300.00,  1200, 2),
  ('ai_business',   'ANEXOMAIL AI Business',  1000.00,  5000, 3),
  ('ai_executive',  'ANEXOMAIL AI Executive', 2000.00, 10000, 4)
on conflict (id) do update set
  name = excluded.name, price = excluded.price,
  monthly_credits = excluded.monthly_credits, active = true;

-- ─── 5. AI ACTIONS (pre-flight -> reserve -> settle) ──────────
create table if not exists public.ai_actions (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  user_id uuid references auth.users(id) on delete set null,
  action_type text not null,
  model text,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  estimated_credits_min numeric(14,3),
  estimated_credits_max numeric(14,3),
  reserved_credits numeric(14,3) not null default 0,
  actual_credits numeric(14,3),
  -- internal economics (customer billing se ALAG)
  provider_cost numeric(14,6) not null default 0,
  infrastructure_cost numeric(14,6) not null default 0,
  status text not null default 'estimated' check (status in
    ('estimated','approved','reserved','processing','completed','failed','cancelled','refunded')),
  approved_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  latency_ms integer,
  created_at timestamptz not null default now()
);
create index if not exists ai_actions_ws_idx on public.ai_actions (workspace_id, created_at desc);

-- ─── 6. COMPLIMENTARY GRANTS (Day 1 + Day 2, once per cycle) ──
create table if not exists public.ai_credit_grants (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  cycle_started_at timestamptz not null,
  grant_day smallint not null check (grant_day in (1,2)),
  credits numeric(14,3) not null default 5,
  created_at timestamptz not null default now(),
  unique (workspace_id, cycle_started_at, grant_day)
);

-- ─── 7. CREDIT ENGINE RPCs (only writer of balances) ──────────
create or replace function public.ai_credits_reserve(
  _workspace_id uuid, _action_id uuid, _credits numeric, _idem text
) returns numeric
language plpgsql security definer set search_path = public as $$
declare w public.ai_credit_wallets; before numeric;
begin
  if exists (select 1 from public.ai_credit_ledger where idempotency_key = _idem) then
    return (select total_balance from public.ai_credit_wallets where workspace_id = _workspace_id);
  end if;
  select * into w from public.ai_credit_wallets where workspace_id = _workspace_id for update;
  if w.id is null then raise exception 'wallet not found'; end if;
  before := w.total_balance;
  if before < _credits then raise exception 'insufficient_credits'; end if;

  update public.ai_credit_wallets
     set reserved_credits = reserved_credits + _credits, updated_at = now()
   where id = w.id;
  update public.ai_actions
     set reserved_credits = _credits, status = 'reserved', approved_at = now()
   where id = _action_id;

  insert into public.ai_credit_ledger
    (workspace_id, action_id, credit_type, entry_type, amount, balance_before, balance_after, reason, idempotency_key)
  values (_workspace_id, _action_id, 'reserved', 'reservation', -_credits, before, before - _credits,
          'pre-flight reservation', _idem);

  return before - _credits;
end $$;

create or replace function public.ai_credits_settle(
  _workspace_id uuid, _action_id uuid, _actual numeric, _model text,
  _provider_cost numeric default 0, _idem text default null
) returns numeric
language plpgsql security definer set search_path = public as $$
declare w public.ai_credit_wallets; res numeric; before numeric; take numeric; from_comp numeric; from_top numeric; from_sub numeric;
begin
  if _idem is not null and exists (select 1 from public.ai_credit_ledger where idempotency_key = _idem) then
    return (select total_balance from public.ai_credit_wallets where workspace_id = _workspace_id);
  end if;
  select * into w from public.ai_credit_wallets where workspace_id = _workspace_id for update;
  select reserved_credits into res from public.ai_actions where id = _action_id;
  res := coalesce(res, 0);
  before := w.total_balance;
  take := least(greatest(_actual, 0), res + w.subscription_credits + w.topup_credits + w.complimentary_credits);

  -- spend order: complimentary -> subscription -> topup
  from_comp := least(w.complimentary_credits, take);
  from_sub  := least(w.subscription_credits, take - from_comp);
  from_top  := take - from_comp - from_sub;

  update public.ai_credit_wallets set
    reserved_credits = greatest(reserved_credits - res, 0),
    complimentary_credits = complimentary_credits - from_comp,
    subscription_credits  = subscription_credits  - from_sub,
    topup_credits         = topup_credits         - from_top,
    updated_at = now()
  where id = w.id;

  update public.ai_actions set
    actual_credits = take, model = coalesce(_model, model), provider_cost = _provider_cost,
    status = 'completed', completed_at = now()
  where id = _action_id;

  insert into public.ai_credit_ledger
    (workspace_id, action_id, credit_type, entry_type, amount, balance_before, balance_after,
     reason, model, estimated_credits, actual_credits, idempotency_key)
  values (_workspace_id, _action_id, 'subscription', 'charge', -take, before,
          (select total_balance from public.ai_credit_wallets where id = w.id),
          'ai action settled', _model, res, take, _idem);

  return (select total_balance from public.ai_credit_wallets where id = w.id);
end $$;

create or replace function public.ai_credits_release(
  _workspace_id uuid, _action_id uuid, _reason text default 'provider failure'
) returns numeric
language plpgsql security definer set search_path = public as $$
declare w public.ai_credit_wallets; res numeric; before numeric;
begin
  select * into w from public.ai_credit_wallets where workspace_id = _workspace_id for update;
  select reserved_credits into res from public.ai_actions where id = _action_id;
  res := coalesce(res, 0);
  before := w.total_balance;
  update public.ai_credit_wallets
     set reserved_credits = greatest(reserved_credits - res, 0), updated_at = now()
   where id = w.id;
  update public.ai_actions set status = 'failed', completed_at = now() where id = _action_id;
  insert into public.ai_credit_ledger
    (workspace_id, action_id, credit_type, entry_type, amount, balance_before, balance_after, reason)
  values (_workspace_id, _action_id, 'reserved', 'release', res, before, before + res, _reason);
  return before + res;
end $$;

create or replace function public.ai_credits_topup(
  _workspace_id uuid, _product_id text, _idem text
) returns numeric
language plpgsql security definer set search_path = public as $$
declare p public.ai_credit_topup_products; w public.ai_credit_wallets; before numeric;
begin
  if exists (select 1 from public.ai_credit_ledger where idempotency_key = _idem) then
    return (select total_balance from public.ai_credit_wallets where workspace_id = _workspace_id);
  end if;
  select * into p from public.ai_credit_topup_products where id = _product_id and active;
  if p.id is null then raise exception 'unknown_topup_product'; end if;
  select * into w from public.ai_credit_wallets where workspace_id = _workspace_id for update;
  before := w.total_balance;
  update public.ai_credit_wallets
     set topup_credits = topup_credits + p.credits, updated_at = now() where id = w.id;
  insert into public.ai_credit_ledger
    (workspace_id, credit_type, entry_type, amount, balance_before, balance_after, reason, idempotency_key)
  values (_workspace_id, 'topup', 'topup_purchase', p.credits, before, before + p.credits,
          format('top-up %s (%s credits)', p.id, p.credits), _idem);
  return before + p.credits;
end $$;

create or replace function public.ai_credits_complimentary(
  _workspace_id uuid, _day smallint
) returns numeric
language plpgsql security definer set search_path = public as $$
declare w public.ai_credit_wallets; before numeric;
begin
  select * into w from public.ai_credit_wallets where workspace_id = _workspace_id for update;
  if w.id is null then raise exception 'wallet not found'; end if;
  begin
    insert into public.ai_credit_grants (workspace_id, cycle_started_at, grant_day, credits)
    values (_workspace_id, w.cycle_started_at, _day, 5);
  exception when unique_violation then
    return w.total_balance; -- already granted this cycle
  end;
  before := w.total_balance;
  update public.ai_credit_wallets
     set complimentary_credits = complimentary_credits + 5, updated_at = now() where id = w.id;
  insert into public.ai_credit_ledger
    (workspace_id, credit_type, entry_type, amount, balance_before, balance_after, reason)
  values (_workspace_id, 'complimentary', 'complimentary_grant', 5, before, before + 5,
          format('complimentary day %s', _day));
  return before + 5;
end $$;

-- ─── GRANTS ───────────────────────────────────────────────────
grant select on public.ai_credit_wallets to authenticated;
grant select on public.ai_credit_ledger to authenticated;
grant select on public.ai_actions to authenticated;
grant select on public.ai_credit_grants to authenticated;
grant select on public.ai_credit_plans to authenticated, anon;
grant select on public.ai_credit_topup_products to authenticated, anon;
grant all on public.ai_credit_wallets to service_role;
grant all on public.ai_credit_ledger to service_role;
grant all on public.ai_actions to service_role;
grant all on public.ai_credit_grants to service_role;
grant all on public.ai_credit_plans to service_role;
grant all on public.ai_credit_topup_products to service_role;

-- ─── RLS (read-only for users; writes sirf service_role/RPC) ──
alter table public.ai_credit_wallets enable row level security;
alter table public.ai_credit_ledger enable row level security;
alter table public.ai_actions enable row level security;
alter table public.ai_credit_grants enable row level security;
alter table public.ai_credit_plans enable row level security;
alter table public.ai_credit_topup_products enable row level security;

drop policy if exists read_own on public.ai_credit_wallets;
create policy read_own on public.ai_credit_wallets for select to authenticated
  using (owner_id = auth.uid());

drop policy if exists read_own on public.ai_credit_ledger;
create policy read_own on public.ai_credit_ledger for select to authenticated
  using (user_id = auth.uid() or workspace_id in
    (select workspace_id from public.ai_credit_wallets where owner_id = auth.uid()));

drop policy if exists read_own on public.ai_actions;
create policy read_own on public.ai_actions for select to authenticated
  using (user_id = auth.uid() or workspace_id in
    (select workspace_id from public.ai_credit_wallets where owner_id = auth.uid()));

drop policy if exists read_own on public.ai_credit_grants;
create policy read_own on public.ai_credit_grants for select to authenticated
  using (workspace_id in (select workspace_id from public.ai_credit_wallets where owner_id = auth.uid()));

drop policy if exists read_plans on public.ai_credit_plans;
create policy read_plans on public.ai_credit_plans for select to authenticated, anon using (active);

drop policy if exists read_products on public.ai_credit_topup_products;
create policy read_products on public.ai_credit_topup_products for select to authenticated, anon
  using (active and public_visible);
