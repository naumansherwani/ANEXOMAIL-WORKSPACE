-- ============================================================================
-- ANEXOMAIL — Phase 37: MOVE-IN OPERATIONS & REVENUE COCKPIT
-- "Money machine" phase. £500–£3,000 one-off Managed Move-In ka poora
-- financial + technical operation, sirf SQL ki authority pe.
--
-- Falsafa (Phase 36 ke UPAR baithta hai, naya billing truth NAHI banata):
--   POLAR (messenger) -> billing_intents/entitlement_state (Phase 36 truth)
--   -> movein_deals (operations truth) -> ledger / DNS proof / cutover / evidence
--
-- 12 engines:
--   1  Deal state machine (legal transitions DB decide karti hai)
--   2  Per-mailbox migration ledger (handover evidence)
--   3  Capacity guard + waitlist (2/month, advisory lock se race-proof)
--   4  DNS green proof engine (MX/SPF/DKIM/DMARC, pre + post cutover)
--   5  Cutover runbook + arm/execute gates
--   6  Rollback control (first-class rollback points)
--   7  50/50 cash clock (deposit + final, Polar intents se linked)
--   8  Payment gates (deposit se pehle migration start nahi)
--   9  Customer evidence vault (structured bundle)
--   10 Exception engine (WARNING/BLOCKED/FAILED/... , cutover readiness)
--   11 Deterministic health score (no AI, sirf known facts)
--   12 Founder + customer cockpit views
--
-- Idempotent + self-healing. Grants pehle, phir RLS.
-- ============================================================================

begin;

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- 0) enums (self-healing: values add hote hain, drop nahi)
-- ---------------------------------------------------------------------------
do $$
begin
  if not exists (select 1 from pg_type where typname = 'movein_state') then
    create type public.movein_state as enum (
      'LEAD','QUALIFIED','SCOPE_REQUESTED','SCOPE_CONFIRMED','WRITTEN_PLAN_SENT',
      'PLAN_ACCEPTED','DEPOSIT_INVOICED','DEPOSIT_PAID_50','MIGRATION_PREP',
      'PRECHECK_COMPLETE','DATA_COPY','DATA_VERIFIED','CUTOVER_SCHEDULED',
      'CUTOVER_READY','CUTOVER_EXECUTED','POST_CUTOVER_VERIFIED',
      'FINAL_50_INVOICED','FINAL_50_PAID','HANDOVER_COMPLETE','CLOSED',
      'ON_HOLD','CANCELLED'
    );
  end if;
  if not exists (select 1 from pg_type where typname = 'movein_result') then
    create type public.movein_result as enum (
      'PENDING','IN_PROGRESS','VERIFIED','WARNING','BLOCKED','FAILED',
      'RETRY_REQUIRED','CUSTOMER_ACTION_REQUIRED','ROLLBACK_REQUIRED','SKIPPED'
    );
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) DEALS — operations truth (ek move-in = ek deal)
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='movein_deals')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='movein_deals' and column_name='state') then
    execute 'alter table public.movein_deals rename to movein_deals_legacy_' || extract(epoch from now())::bigint;
  end if;
end $$;

create table if not exists public.movein_deals (
  id                uuid primary key default gen_random_uuid(),
  reference         text unique,                       -- MOVE-IN-2026-001
  user_id           uuid,                              -- customer (portal access)
  owner_id          uuid,                              -- founder/operator
  company           text not null,
  contact_name      text,
  contact_email     text not null,
  domain            text,
  source_provider   text,                              -- gmail | outlook | zoho | imap | other
  mailbox_count     int  not null default 1,
  band              text,                              -- 1-5 | 6-15 | 16-29 | 30plus
  price_gbp         numeric(12,2) not null default 500,
  deposit_gbp       numeric(12,2),
  final_gbp         numeric(12,2),
  state             public.movein_state not null default 'LEAD',
  scheduled_month   date,                              -- capacity slot month (1st of month)
  cutover_window_start timestamptz,
  cutover_window_end   timestamptz,
  cutover_armed_at  timestamptz,
  cutover_executed_at timestamptz,
  waitlisted        boolean not null default false,
  deposit_intent_id uuid,                              -- Phase 36 billing_intents.id
  final_intent_id   uuid,
  deposit_paid_at   timestamptz,
  final_paid_at     timestamptz,
  health_score      int not null default 0,
  closed_at         timestamptz,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists movein_deals_state_idx on public.movein_deals (state, created_at desc);
create index if not exists movein_deals_user_idx  on public.movein_deals (user_id, created_at desc);
create index if not exists movein_deals_month_idx on public.movein_deals (scheduled_month) where waitlisted = false;

-- locked band price ladder (source of truth for £)
create or replace function public.movein_band_for(p_mailboxes int)
returns text language sql immutable as $$
  select case
    when coalesce(p_mailboxes,1) <= 5  then '1-5'
    when p_mailboxes <= 15 then '6-15'
    when p_mailboxes <= 29 then '16-29'
    else '30plus' end
$$;

create or replace function public.movein_price_for(p_band text)
returns numeric language sql immutable as $$
  select case p_band
    when '1-5'    then 500
    when '6-15'   then 1500
    when '16-29'  then 2000
    when '30plus' then 3000
    else 500 end::numeric
$$;

-- reference generator: MOVE-IN-YYYY-NNN
create or replace function public.movein_next_reference()
returns text language plpgsql as $$
declare n int;
begin
  select count(*) + 1 into n from public.movein_deals
   where date_part('year', created_at) = date_part('year', now());
  return 'MOVE-IN-' || to_char(now(), 'YYYY') || '-' || lpad(n::text, 3, '0');
end $$;

-- ---------------------------------------------------------------------------
-- 2) AUDIT LEDGER — who/what/when/before/after/why/evidence
-- ---------------------------------------------------------------------------
create table if not exists public.movein_audit (
  id          bigserial primary key,
  deal_id     uuid not null references public.movein_deals(id) on delete cascade,
  actor       text not null default 'system',
  actor_id    uuid,
  action      text not null,
  from_state  public.movein_state,
  to_state    public.movein_state,
  reason      text,
  evidence    text,
  payment_state text,
  payload     jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);
create index if not exists movein_audit_deal_idx on public.movein_audit (deal_id, created_at desc);

create or replace function public.movein_audit_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'movein_audit is append-only';
end $$;
drop trigger if exists movein_audit_no_change on public.movein_audit;
create trigger movein_audit_no_change before update or delete on public.movein_audit
for each row execute function public.movein_audit_immutable();

-- ---------------------------------------------------------------------------
-- 3) STATE MACHINE — legal transitions + payment gates
-- ---------------------------------------------------------------------------
create table if not exists public.movein_transitions (
  from_state public.movein_state not null,
  to_state   public.movein_state not null,
  gate       text,                -- deposit_paid | final_paid | cutover_ready | data_verified | dns_green | null
  primary key (from_state, to_state)
);

insert into public.movein_transitions (from_state, to_state, gate) values
  ('LEAD','QUALIFIED',null),
  ('QUALIFIED','SCOPE_REQUESTED',null),
  ('SCOPE_REQUESTED','SCOPE_CONFIRMED',null),
  ('SCOPE_CONFIRMED','WRITTEN_PLAN_SENT',null),
  ('WRITTEN_PLAN_SENT','PLAN_ACCEPTED',null),
  ('PLAN_ACCEPTED','DEPOSIT_INVOICED',null),
  ('DEPOSIT_INVOICED','DEPOSIT_PAID_50','deposit_paid'),
  ('DEPOSIT_PAID_50','MIGRATION_PREP','deposit_paid'),
  ('MIGRATION_PREP','PRECHECK_COMPLETE','deposit_paid'),
  ('PRECHECK_COMPLETE','DATA_COPY','deposit_paid'),
  ('DATA_COPY','DATA_VERIFIED','data_verified'),
  ('DATA_VERIFIED','CUTOVER_SCHEDULED',null),
  ('CUTOVER_SCHEDULED','CUTOVER_READY','cutover_ready'),
  ('CUTOVER_READY','CUTOVER_EXECUTED','cutover_armed'),
  ('CUTOVER_EXECUTED','POST_CUTOVER_VERIFIED','dns_green'),
  ('POST_CUTOVER_VERIFIED','FINAL_50_INVOICED',null),
  ('FINAL_50_INVOICED','FINAL_50_PAID','final_paid'),
  ('FINAL_50_PAID','HANDOVER_COMPLETE','final_paid'),
  ('HANDOVER_COMPLETE','CLOSED',null),
  -- honest escape hatches (koi silent jump nahi)
  ('DATA_COPY','ON_HOLD',null),
  ('DATA_VERIFIED','ON_HOLD',null),
  ('CUTOVER_SCHEDULED','ON_HOLD',null),
  ('CUTOVER_READY','ON_HOLD',null),
  ('MIGRATION_PREP','ON_HOLD',null),
  ('ON_HOLD','MIGRATION_PREP','deposit_paid'),
  ('ON_HOLD','CUTOVER_SCHEDULED',null),
  ('LEAD','CANCELLED',null),
  ('QUALIFIED','CANCELLED',null),
  ('SCOPE_REQUESTED','CANCELLED',null),
  ('SCOPE_CONFIRMED','CANCELLED',null),
  ('WRITTEN_PLAN_SENT','CANCELLED',null),
  ('PLAN_ACCEPTED','CANCELLED',null),
  ('DEPOSIT_INVOICED','CANCELLED',null),
  ('ON_HOLD','CANCELLED',null)
on conflict (from_state, to_state) do update set gate = excluded.gate;
