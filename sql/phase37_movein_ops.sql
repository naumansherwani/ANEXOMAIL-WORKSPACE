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

-- ---------------------------------------------------------------------------
-- 4) PER-MAILBOX MIGRATION LEDGER — customer handover evidence
-- ---------------------------------------------------------------------------
create table if not exists public.movein_mailboxes (
  id                 uuid primary key default gen_random_uuid(),
  deal_id            uuid not null references public.movein_deals(id) on delete cascade,
  address            text not null,
  destination        text,
  source_provider    text,
  size_mb            numeric(14,2),
  messages_source    int  not null default 0,
  messages_copied    int  not null default 0,
  messages_verified  int  not null default 0,
  folders_found      int  not null default 0,
  contacts_count     int  not null default 0,
  calendar_events    int  not null default 0,
  aliases_count      int  not null default 0,
  signatures_count   int  not null default 0,
  source_credentials text not null default 'PENDING',   -- PENDING | OK | INVALID
  destination_status text not null default 'PENDING',    -- PENDING | CREATED | READY
  result             public.movein_result not null default 'PENDING',
  exceptions         int not null default 0,
  operator           text,
  verified_at        timestamptz,
  last_checked_at    timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (deal_id, address)
);
create index if not exists movein_mailboxes_deal_idx on public.movein_mailboxes (deal_id, address);

create or replace view public.movein_mailbox_gaps as
  select m.deal_id, d.reference, m.address,
         m.messages_source, m.messages_copied, m.messages_verified,
         greatest(m.messages_source - m.messages_verified, 0) as missing,
         m.result
    from public.movein_mailboxes m
    join public.movein_deals d on d.id = m.deal_id
   where m.messages_verified < m.messages_source or m.result <> 'VERIFIED';

-- ---------------------------------------------------------------------------
-- 5) CAPACITY GUARD + WAITLIST (2 move-ins / month, DB enforced)
-- ---------------------------------------------------------------------------
create table if not exists public.movein_capacity (
  month       date primary key,                -- 1st of month
  slots_total int not null default 2,
  notes       text,
  created_at  timestamptz not null default now()
);

create table if not exists public.movein_waitlist (
  id         uuid primary key default gen_random_uuid(),
  deal_id    uuid not null references public.movein_deals(id) on delete cascade,
  month      date not null,
  position   int  not null,
  released_at timestamptz,
  created_at timestamptz not null default now(),
  unique (deal_id, month)
);

create or replace view public.movein_capacity_state as
  select c.month,
         c.slots_total,
         (select count(*) from public.movein_deals d
           where d.scheduled_month = c.month and d.waitlisted = false
             and d.state not in ('CANCELLED')) as slots_booked,
         greatest(c.slots_total - (select count(*) from public.movein_deals d
           where d.scheduled_month = c.month and d.waitlisted = false
             and d.state not in ('CANCELLED')), 0) as slots_free,
         (select count(*) from public.movein_waitlist w
           where w.month = c.month and w.released_at is null) as waitlisted
    from public.movein_capacity c;

-- transactional booking: 10 concurrent clicks -> maximum 2 booked
create or replace function public.movein_book_slot(p_deal uuid, p_month date)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_month date := date_trunc('month', p_month)::date;
        v_total int; v_used int; v_pos int;
begin
  perform pg_advisory_xact_lock(hashtext('movein_capacity:' || v_month::text));
  insert into public.movein_capacity (month) values (v_month) on conflict (month) do nothing;
  select slots_total into v_total from public.movein_capacity where month = v_month;
  select count(*) into v_used from public.movein_deals
   where scheduled_month = v_month and waitlisted = false and state <> 'CANCELLED' and id <> p_deal;

  if v_used < v_total then
    update public.movein_deals
       set scheduled_month = v_month, waitlisted = false, updated_at = now()
     where id = p_deal;
    delete from public.movein_waitlist where deal_id = p_deal and month = v_month;
    insert into public.movein_audit (deal_id, actor, action, reason, payload)
      values (p_deal, 'system', 'capacity_booked', 'slot reserved', jsonb_build_object('month', v_month));
    return jsonb_build_object('booked', true, 'month', v_month, 'slots_used', v_used + 1, 'slots_total', v_total);
  end if;

  select coalesce(max(position), 0) + 1 into v_pos from public.movein_waitlist
   where month = v_month and released_at is null;
  insert into public.movein_waitlist (deal_id, month, position)
    values (p_deal, v_month, v_pos)
    on conflict (deal_id, month) do update set position = excluded.position;
  update public.movein_deals set scheduled_month = v_month, waitlisted = true, updated_at = now()
   where id = p_deal;
  insert into public.movein_audit (deal_id, actor, action, reason, payload)
    values (p_deal, 'system', 'waitlisted', 'month at capacity', jsonb_build_object('month', v_month, 'position', v_pos));
  return jsonb_build_object('booked', false, 'waitlisted', true, 'position', v_pos, 'month', v_month, 'slots_total', v_total);
end $$;

-- ---------------------------------------------------------------------------
-- 6) DNS GREEN PROOF ENGINE (pre + post cutover, evidence trail)
-- ---------------------------------------------------------------------------
create table if not exists public.movein_dns_checks (
  id             uuid primary key default gen_random_uuid(),
  deal_id        uuid not null references public.movein_deals(id) on delete cascade,
  verification_id text not null default encode(gen_random_bytes(8), 'hex'),
  phase          text not null default 'PRE',        -- PRE | POST
  domain         text not null,
  record         text not null,                       -- MX | SPF | DKIM | DMARC
  hostname       text,
  resolver       text,
  expected       text,
  observed       text,
  result         public.movein_result not null default 'PENDING',
  reason         text,
  checked_at     timestamptz not null default now()
);
create index if not exists movein_dns_deal_idx on public.movein_dns_checks (deal_id, phase, checked_at desc);

create or replace view public.movein_dns_proof as
  select deal_id, phase, record,
         (array_agg(result order by checked_at desc))[1]     as result,
         (array_agg(observed order by checked_at desc))[1]   as observed,
         (array_agg(resolver order by checked_at desc))[1]   as resolver,
         (array_agg(verification_id order by checked_at desc))[1] as verification_id,
         max(checked_at) as checked_at
    from public.movein_dns_checks
   group by deal_id, phase, record;

create or replace function public.movein_dns_green(p_deal uuid, p_phase text default 'POST')
returns boolean language sql stable as $$
  select coalesce(count(*) filter (where result = 'VERIFIED') = 4, false)
    from public.movein_dns_proof
   where deal_id = p_deal and phase = p_phase
     and record in ('MX','SPF','DKIM','DMARC')
$$;

-- ---------------------------------------------------------------------------
-- 8) EXCEPTION ENGINE
-- ---------------------------------------------------------------------------
create table if not exists public.movein_exceptions (
  id          uuid primary key default gen_random_uuid(),
  deal_id     uuid not null references public.movein_deals(id) on delete cascade,
  scope       text not null default 'general',       -- mailbox | dns | payment | cutover | general
  ref         text,                                   -- address / record / intent
  severity    public.movein_result not null default 'WARNING',
  reason      text not null,
  required_action text,
  blocks_cutover boolean not null default false,
  resolved_at timestamptz,
  resolved_by text,
  created_at  timestamptz not null default now()
);
create index if not exists movein_exceptions_open_idx on public.movein_exceptions (deal_id, resolved_at);

-- ---------------------------------------------------------------------------
-- 7) CUTOVER RUNBOOK + GATES
-- ---------------------------------------------------------------------------
create table if not exists public.movein_runbook (
  id         uuid primary key default gen_random_uuid(),
  deal_id    uuid not null references public.movein_deals(id) on delete cascade,
  step_key   text not null,
  label      text not null,
  position   int  not null default 0,
  required   boolean not null default true,
  result     public.movein_result not null default 'PENDING',
  evidence   text,
  operator   text,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (deal_id, step_key)
);

create or replace function public.movein_seed_runbook(p_deal uuid)
returns int language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  insert into public.movein_runbook (deal_id, step_key, label, position)
  select p_deal, s.k, s.l, s.p from (values
    ('mailboxes_created','All mailboxes created', 1),
    ('data_copy_complete','Source data copy complete', 2),
    ('counts_verified','Message counts verified', 3),
    ('dns_prepared','DNS records prepared', 4),
    ('mx_ttl','MX TTL checked and lowered', 5),
    ('spf_verified','SPF verified', 6),
    ('dkim_verified','DKIM verified', 7),
    ('dmarc_verified','DMARC verified', 8),
    ('test_mailbox','Test mailbox working', 9),
    ('test_inbound','Test inbound delivery', 10),
    ('test_outbound','Test outbound delivery', 11),
    ('rollback_point','Rollback point recorded', 12),
    ('customer_approval','Customer approval recorded', 13)
  ) as s(k,l,p)
  on conflict (deal_id, step_key) do nothing;
  select count(*) into v_n from public.movein_runbook where deal_id = p_deal;
  return v_n;
end $$;

create or replace function public.movein_cutover_ready(p_deal uuid)
returns boolean language sql stable as $$
  select coalesce(
    (select count(*) = 0 from public.movein_runbook
      where deal_id = p_deal and required and result <> 'VERIFIED'), false)
   and coalesce((select count(*) > 0 from public.movein_runbook where deal_id = p_deal), false)
   and public.movein_dns_green(p_deal, 'PRE')
   and coalesce((select count(*) = 0 from public.movein_exceptions
      where deal_id = p_deal and resolved_at is null
        and severity in ('BLOCKED','FAILED','ROLLBACK_REQUIRED','CUSTOMER_ACTION_REQUIRED')), true)
$$;

-- ---------------------------------------------------------------------------
-- 9) ROLLBACK CONTROL (first-class object)
-- ---------------------------------------------------------------------------
create table if not exists public.movein_rollback_points (
  id                 uuid primary key default gen_random_uuid(),
  deal_id            uuid not null references public.movein_deals(id) on delete cascade,
  label              text not null default 'pre-cutover',
  operator           text,
  source_state       jsonb not null default '{}'::jsonb,
  destination_state  jsonb not null default '{}'::jsonb,
  dns_state          jsonb not null default '{}'::jsonb,
  verification_state jsonb not null default '{}'::jsonb,
  available          boolean not null default true,
  used_at            timestamptz,
  created_at         timestamptz not null default now()
);
create index if not exists movein_rollback_deal_idx on public.movein_rollback_points (deal_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 10) CASH CLOCK — 50/50 payments, Phase 36 intents se linked
-- ---------------------------------------------------------------------------
create table if not exists public.movein_payments (
  id          uuid primary key default gen_random_uuid(),
  deal_id     uuid not null references public.movein_deals(id) on delete cascade,
  leg         text not null check (leg in ('deposit','final')),
  amount_gbp  numeric(12,2) not null,
  intent_id   uuid,                                   -- billing_intents.id (Phase 36)
  state       text not null default 'due' check (state in ('due','invoiced','paid','void')),
  due_at      timestamptz,
  invoiced_at timestamptz,
  paid_at     timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (deal_id, leg)
);
create index if not exists movein_payments_state_idx on public.movein_payments (state, due_at);

create or replace function public.movein_sync_payments(p_deal uuid)
returns void language plpgsql security definer set search_path = public as $$
declare d record; v_dep numeric; v_fin numeric;
begin
  select * into d from public.movein_deals where id = p_deal;
  if d is null then return; end if;
  v_dep := coalesce(d.deposit_gbp, round(d.price_gbp / 2, 2));
  v_fin := coalesce(d.final_gbp, d.price_gbp - v_dep);

  insert into public.movein_payments (deal_id, leg, amount_gbp)
    values (p_deal, 'deposit', v_dep)
    on conflict (deal_id, leg) do update set amount_gbp = excluded.amount_gbp, updated_at = now();
  insert into public.movein_payments (deal_id, leg, amount_gbp)
    values (p_deal, 'final', v_fin)
    on conflict (deal_id, leg) do update set amount_gbp = excluded.amount_gbp, updated_at = now();

  -- Phase 36 truth: intent paid ho to leg paid (idempotent)
  update public.movein_payments p
     set state = 'paid', paid_at = coalesce(p.paid_at, i.paid_at, now()), updated_at = now()
    from public.billing_intents i
   where p.deal_id = p_deal and p.intent_id = i.id
     and i.state in ('paid','entitled') and p.state <> 'paid';

  update public.movein_deals set
      deposit_gbp = v_dep,
      final_gbp   = v_fin,
      deposit_paid_at = (select paid_at from public.movein_payments where deal_id = p_deal and leg='deposit' and state='paid'),
      final_paid_at   = (select paid_at from public.movein_payments where deal_id = p_deal and leg='final'   and state='paid'),
      updated_at = now()
   where id = p_deal;
end $$;

-- link a Phase 36 intent to a payment leg (webhook/sweep dono se safe)
create or replace function public.movein_attach_intent(p_deal uuid, p_leg text, p_intent uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.movein_payments
     set intent_id = p_intent, state = case when state = 'due' then 'invoiced' else state end,
         invoiced_at = coalesce(invoiced_at, now()), updated_at = now()
   where deal_id = p_deal and leg = p_leg;
  if p_leg = 'deposit' then
    update public.movein_deals set deposit_intent_id = p_intent, updated_at = now() where id = p_deal;
  else
    update public.movein_deals set final_intent_id = p_intent, updated_at = now() where id = p_deal;
  end if;
  insert into public.movein_audit (deal_id, actor, action, reason, evidence, payload)
    values (p_deal, 'system', 'payment_invoiced', p_leg || ' invoice issued', p_intent::text,
            jsonb_build_object('leg', p_leg, 'intent_id', p_intent));
  perform public.movein_sync_payments(p_deal);
end $$;

create or replace function public.movein_leg_paid(p_deal uuid, p_leg text)
returns boolean language sql stable as $$
  select coalesce((select state = 'paid' from public.movein_payments
                    where deal_id = p_deal and leg = p_leg), false)
$$;

-- ---------------------------------------------------------------------------
-- 11) DETERMINISTIC HEALTH SCORE (no AI — sirf known facts)
-- ---------------------------------------------------------------------------
create or replace function public.movein_health(p_deal uuid)
returns jsonb language plpgsql stable as $$
declare
  v_mb_total int; v_mb_ok int; v_msg_src bigint; v_msg_ver bigint;
  v_dns int; v_run_total int; v_run_ok int;
  v_mailbox numeric := 0; v_data numeric := 0; v_dnsp numeric := 0;
  v_pay numeric := 0; v_cut numeric := 0; v_overall numeric := 0;
begin
  select count(*), count(*) filter (where result = 'VERIFIED'),
         coalesce(sum(messages_source),0), coalesce(sum(messages_verified),0)
    into v_mb_total, v_mb_ok, v_msg_src, v_msg_ver
    from public.movein_mailboxes where deal_id = p_deal;

  select count(*) filter (where result = 'VERIFIED') into v_dns
    from public.movein_dns_proof where deal_id = p_deal and phase = 'PRE'
      and record in ('MX','SPF','DKIM','DMARC');

  select count(*) filter (where required), count(*) filter (where required and result = 'VERIFIED')
    into v_run_total, v_run_ok from public.movein_runbook where deal_id = p_deal;

  v_mailbox := case when v_mb_total = 0 then 0 else round(100.0 * v_mb_ok / v_mb_total, 0) end;
  v_data    := case when v_msg_src = 0 then 0 else round(100.0 * least(v_msg_ver, v_msg_src) / v_msg_src, 0) end;
  v_dnsp    := round(100.0 * least(v_dns,4) / 4, 0);
  v_pay     := (case when public.movein_leg_paid(p_deal,'deposit') then 50 else 0 end)
             + (case when public.movein_leg_paid(p_deal,'final')   then 50 else 0 end);
  v_cut     := case when v_run_total = 0 then 0 else round(100.0 * v_run_ok / v_run_total, 0) end;
  v_overall := round((v_mailbox + v_data + v_dnsp + v_pay + v_cut) / 5.0, 0);

  update public.movein_deals set health_score = v_overall::int, updated_at = now() where id = p_deal;

  return jsonb_build_object(
    'mailbox_verification', v_mailbox,
    'data_verification', v_data,
    'dns_readiness', v_dnsp,
    'payment_readiness', v_pay,
    'cutover_readiness', v_cut,
    'overall', v_overall,
    'mailboxes', v_mb_total,
    'messages_source', v_msg_src,
    'messages_verified', v_msg_ver
  );
end $$;

-- ---------------------------------------------------------------------------
-- 12) DEAL OPEN + LEGAL TRANSITION (payment gates DB enforce karti hai)
-- ---------------------------------------------------------------------------
create or replace function public.movein_open_deal(
  p_company text,
  p_email text,
  p_mailboxes int default 1,
  p_domain text default null,
  p_provider text default 'other',
  p_contact text default null,
  p_user uuid default null,
  p_month date default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_band text; v_price numeric; v_book jsonb;
begin
  v_band  := public.movein_band_for(p_mailboxes);
  v_price := public.movein_price_for(v_band);

  insert into public.movein_deals
    (reference, user_id, company, contact_name, contact_email, domain, source_provider,
     mailbox_count, band, price_gbp, deposit_gbp, final_gbp)
  values
    (public.movein_next_reference(), p_user, p_company, p_contact, lower(p_email), lower(p_domain),
     p_provider, greatest(coalesce(p_mailboxes,1),1), v_band, v_price,
     round(v_price/2,2), v_price - round(v_price/2,2))
  returning id into v_id;

  perform public.movein_seed_runbook(v_id);
  perform public.movein_sync_payments(v_id);
  insert into public.movein_audit (deal_id, actor, action, to_state, reason, payload)
    values (v_id, 'system', 'deal_opened', 'LEAD', 'move-in request received',
            jsonb_build_object('band', v_band, 'price_gbp', v_price));

  if p_month is not null then
    v_book := public.movein_book_slot(v_id, p_month);
  end if;

  perform public.movein_health(v_id);
  return jsonb_build_object('deal_id', v_id, 'band', v_band, 'price_gbp', v_price,
                            'deposit_gbp', round(v_price/2,2), 'capacity', v_book,
                            'reference', (select reference from public.movein_deals where id = v_id));
end $$;

create or replace function public.movein_transition(
  p_deal uuid,
  p_to public.movein_state,
  p_actor text default 'founder',
  p_reason text default null,
  p_evidence text default null,
  p_actor_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare d record; v_gate text; v_ok boolean := true; v_why text;
begin
  select * into d from public.movein_deals where id = p_deal for update;
  if d is null then return jsonb_build_object('ok', false, 'error', 'deal_not_found'); end if;
  if d.state = p_to then
    return jsonb_build_object('ok', true, 'state', p_to, 'idempotent', true);
  end if;

  select gate into v_gate from public.movein_transitions
   where from_state = d.state and to_state = p_to;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'illegal_transition',
      'from', d.state, 'to', p_to,
      'allowed', (select coalesce(jsonb_agg(to_state), '[]'::jsonb)
                    from public.movein_transitions where from_state = d.state));
  end if;

  if v_gate = 'deposit_paid' and not public.movein_leg_paid(p_deal, 'deposit') then
    v_ok := false; v_why := 'deposit_50_not_paid';
  elsif v_gate = 'final_paid' and not public.movein_leg_paid(p_deal, 'final') then
    v_ok := false; v_why := 'final_50_not_paid';
  elsif v_gate = 'data_verified' and exists (
        select 1 from public.movein_mailboxes where deal_id = p_deal and result <> 'VERIFIED') then
    v_ok := false; v_why := 'mailbox_ledger_not_verified';
  elsif v_gate = 'cutover_ready' and not public.movein_cutover_ready(p_deal) then
    v_ok := false; v_why := 'runbook_or_dns_or_exception_open';
  elsif v_gate = 'cutover_armed' and d.cutover_armed_at is null then
    v_ok := false; v_why := 'cutover_not_armed';
  elsif v_gate = 'dns_green' and not public.movein_dns_green(p_deal, 'POST') then
    v_ok := false; v_why := 'post_cutover_dns_not_green';
  end if;

  if not v_ok then
    insert into public.movein_audit (deal_id, actor, actor_id, action, from_state, to_state, reason, payload)
      values (p_deal, p_actor, p_actor_id, 'transition_blocked', d.state, p_to, v_why,
              jsonb_build_object('gate', v_gate));
    return jsonb_build_object('ok', false, 'error', 'gate_blocked', 'gate', v_gate, 'reason', v_why);
  end if;

  update public.movein_deals set
      state = p_to,
      cutover_executed_at = case when p_to = 'CUTOVER_EXECUTED' then now() else cutover_executed_at end,
      closed_at = case when p_to in ('CLOSED','CANCELLED') then now() else closed_at end,
      updated_at = now()
   where id = p_deal;

  insert into public.movein_audit (deal_id, actor, actor_id, action, from_state, to_state, reason, evidence, payment_state, payload)
    values (p_deal, p_actor, p_actor_id, 'state_changed', d.state, p_to, p_reason, p_evidence,
            case when public.movein_leg_paid(p_deal,'final') then 'final_paid'
                 when public.movein_leg_paid(p_deal,'deposit') then 'deposit_paid'
                 else 'unpaid' end,
            jsonb_build_object('gate', v_gate));

  perform public.movein_health(p_deal);
  return jsonb_build_object('ok', true, 'from', d.state, 'state', p_to, 'gate', v_gate);
end $$;

-- arm the cutover (do-aadmi gate: ready hona zaroori, warna arm nahi hota)
create or replace function public.movein_arm_cutover(p_deal uuid, p_actor text default 'founder')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.movein_cutover_ready(p_deal) then
    insert into public.movein_audit (deal_id, actor, action, reason)
      values (p_deal, p_actor, 'arm_blocked', 'runbook / dns / exceptions not clear');
    return jsonb_build_object('ok', false, 'error', 'not_ready');
  end if;
  if not exists (select 1 from public.movein_rollback_points where deal_id = p_deal and available) then
    return jsonb_build_object('ok', false, 'error', 'no_rollback_point');
  end if;
  update public.movein_deals set cutover_armed_at = now(), updated_at = now() where id = p_deal;
  insert into public.movein_audit (deal_id, actor, action, reason)
    values (p_deal, p_actor, 'cutover_armed', 'all required checks verified, rollback point recorded');
  return jsonb_build_object('ok', true, 'armed_at', now());
end $$;

-- ---------------------------------------------------------------------------
-- 13) EVIDENCE VAULT — structured handover bundle (customer + internal)
-- ---------------------------------------------------------------------------
create or replace function public.movein_evidence_bundle(p_deal uuid)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'reference', d.reference,
    'company', d.company,
    'domain', d.domain,
    'band', d.band,
    'price_gbp', d.price_gbp,
    'state', d.state,
    'scope', jsonb_build_object('mailboxes', d.mailbox_count, 'source_provider', d.source_provider,
                                'cutover_window_start', d.cutover_window_start,
                                'cutover_window_end', d.cutover_window_end),
    'payments', (select coalesce(jsonb_agg(jsonb_build_object('leg', leg, 'amount_gbp', amount_gbp,
                        'state', state, 'paid_at', paid_at) order by leg), '[]'::jsonb)
                   from public.movein_payments where deal_id = d.id),
    'mailbox_ledger', (select coalesce(jsonb_agg(to_jsonb(m) order by m.address), '[]'::jsonb)
                   from public.movein_mailboxes m where m.deal_id = d.id),
    'dns_proof', (select coalesce(jsonb_agg(to_jsonb(p) order by p.phase, p.record), '[]'::jsonb)
                   from public.movein_dns_proof p where p.deal_id = d.id),
    'runbook', (select coalesce(jsonb_agg(jsonb_build_object('label', label, 'result', result,
                        'evidence', evidence, 'completed_at', completed_at) order by position), '[]'::jsonb)
                   from public.movein_runbook where deal_id = d.id),
    'exceptions', (select coalesce(jsonb_agg(jsonb_build_object('scope', scope, 'ref', ref,
                        'severity', severity, 'reason', reason, 'required_action', required_action,
                        'resolved_at', resolved_at) order by created_at), '[]'::jsonb)
                   from public.movein_exceptions where deal_id = d.id),
    'rollback', (select coalesce(jsonb_agg(jsonb_build_object('label', label, 'available', available,
                        'created_at', created_at) order by created_at desc), '[]'::jsonb)
                   from public.movein_rollback_points where deal_id = d.id),
    'audit', (select coalesce(jsonb_agg(jsonb_build_object('actor', actor, 'action', action,
                        'from_state', from_state, 'to_state', to_state, 'reason', reason,
                        'evidence', evidence, 'at', created_at) order by created_at), '[]'::jsonb)
                   from public.movein_audit where deal_id = d.id),
    'health', public.movein_health(d.id),
    'cutover_note', 'Scheduled overnight cut-over designed to avoid interruption.',
    'generated_at', now()
  )
  from public.movein_deals d where d.id = p_deal
$$;

-- customer portal progress (safe subset — no internal notes)
create or replace function public.movein_customer_view(p_deal uuid)
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'reference', d.reference,
    'company', d.company,
    'state', d.state,
    'progress', (select round(100.0 * count(*) filter (where t.reached) / greatest(count(*),1))
                   from (select unnest(array['PLAN_ACCEPTED','DEPOSIT_PAID_50','MIGRATION_PREP',
                                             'DATA_VERIFIED','CUTOVER_SCHEDULED','CUTOVER_EXECUTED',
                                             'POST_CUTOVER_VERIFIED','FINAL_50_PAID','HANDOVER_COMPLETE']) as s) x,
                        lateral (select exists (select 1 from public.movein_audit a
                                  where a.deal_id = d.id and a.to_state::text = x.s) as reached) t),
    'cutover_window', jsonb_build_object('start', d.cutover_window_start, 'end', d.cutover_window_end),
    'cutover_note', 'Scheduled overnight cut-over designed to avoid interruption.',
    'payments', (select coalesce(jsonb_agg(jsonb_build_object('leg', leg, 'amount_gbp', amount_gbp,
                        'state', state) order by leg), '[]'::jsonb)
                   from public.movein_payments where deal_id = d.id),
    'dns_proof', (select coalesce(jsonb_agg(jsonb_build_object('phase', phase, 'record', record,
                        'result', result, 'checked_at', checked_at) order by phase, record), '[]'::jsonb)
                   from public.movein_dns_proof where deal_id = d.id),
    'mailboxes_verified', (select count(*) from public.movein_mailboxes where deal_id = d.id and result='VERIFIED'),
    'mailboxes_total', (select count(*) from public.movein_mailboxes where deal_id = d.id),
    'customer_action', (select coalesce(jsonb_agg(jsonb_build_object('reason', reason,
                        'required_action', required_action)), '[]'::jsonb)
                   from public.movein_exceptions
                  where deal_id = d.id and resolved_at is null
                    and severity = 'CUSTOMER_ACTION_REQUIRED'),
    'health', public.movein_health(d.id)
  ) from public.movein_deals d where d.id = p_deal
$$;

-- ---------------------------------------------------------------------------
-- 14) FOUNDER COCKPIT (single call, sab kuch SQL se)
-- ---------------------------------------------------------------------------
create or replace view public.movein_cash_clock as
  select
    (select coalesce(sum(price_gbp),0) from public.movein_deals
      where state not in ('LEAD','QUALIFIED','CANCELLED'))                    as booked_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments where leg='deposit' and state<>'void')  as deposits_expected_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments where leg='deposit' and state='paid')   as deposits_paid_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments where leg='final' and state<>'void')    as final_expected_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments where leg='final' and state='paid')     as final_paid_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments where state in ('due','invoiced'))      as outstanding_gbp,
    (select coalesce(sum(amount_gbp),0) from public.movein_payments
      where state in ('due','invoiced') and due_at is not null and due_at < now())                          as overdue_gbp;

create or replace view public.movein_attention as
  select d.id as deal_id, d.reference, 'final_payment_overdue' as kind,
         'Final 50% overdue' as message, d.state::text as state
    from public.movein_deals d join public.movein_payments p on p.deal_id = d.id
   where p.leg='final' and p.state in ('due','invoiced') and p.due_at is not null and p.due_at < now()
  union all
  select d.id, d.reference, 'deposit_overdue', 'Deposit 50% overdue', d.state::text
    from public.movein_deals d join public.movein_payments p on p.deal_id = d.id
   where p.leg='deposit' and p.state in ('due','invoiced') and p.due_at is not null and p.due_at < now()
  union all
  select d.id, d.reference, 'exception_' || lower(e.severity::text), e.reason, d.state::text
    from public.movein_deals d join public.movein_exceptions e on e.deal_id = d.id
   where e.resolved_at is null and e.severity in ('BLOCKED','FAILED','ROLLBACK_REQUIRED','CUSTOMER_ACTION_REQUIRED')
  union all
  select d.id, d.reference, 'cutover_not_ready', 'Cut-over scheduled but checks not clear', d.state::text
    from public.movein_deals d
   where d.state = 'CUTOVER_SCHEDULED' and not public.movein_cutover_ready(d.id);

create or replace function public.movein_cockpit()
returns jsonb language sql stable as $$
  select jsonb_build_object(
    'active_moves', (select count(*) from public.movein_deals
       where state not in ('LEAD','QUALIFIED','CLOSED','CANCELLED')),
    'capacity', (select coalesce(to_jsonb(c), '{}'::jsonb) from public.movein_capacity_state c
       where c.month = date_trunc('month', now())::date),
    'waitlisted', (select count(*) from public.movein_waitlist where released_at is null),
    'cash', (select to_jsonb(x) from public.movein_cash_clock x),
    'cutovers_tonight', (select count(*) from public.movein_deals
       where cutover_window_start between now() and now() + interval '24 hours'),
    'blocked', (select count(*) from public.movein_exceptions
       where resolved_at is null and severity in ('BLOCKED','FAILED','ROLLBACK_REQUIRED')),
    'exceptions_open', (select count(*) from public.movein_exceptions where resolved_at is null),
    'dns_proof_pct', (select coalesce(round(100.0 * count(*) filter (where result='VERIFIED')
       / greatest(count(*),1)), 0) from public.movein_dns_proof),
    'mailbox_verification_pct', (select coalesce(round(100.0 * count(*) filter (where result='VERIFIED')
       / greatest(count(*),1)), 0) from public.movein_mailboxes),
    'attention', (select coalesce(jsonb_agg(to_jsonb(a)), '[]'::jsonb) from public.movein_attention a),
    'board', (select coalesce(jsonb_agg(jsonb_build_object(
         'id', d.id, 'reference', d.reference, 'company', d.company, 'state', d.state,
         'band', d.band, 'price_gbp', d.price_gbp, 'health', d.health_score,
         'waitlisted', d.waitlisted, 'mailboxes', d.mailbox_count,
         'deposit_paid', public.movein_leg_paid(d.id,'deposit'),
         'final_paid', public.movein_leg_paid(d.id,'final'),
         'cutover_window_start', d.cutover_window_start,
         'updated_at', d.updated_at) order by d.updated_at desc), '[]'::jsonb)
       from public.movein_deals d where d.state <> 'CLOSED'),
    'generated_at', now()
  )
$$;

-- ---------------------------------------------------------------------------
-- 15) GRANTS (pehle) -> RLS -> policies
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['movein_deals','movein_audit','movein_transitions','movein_mailboxes',
    'movein_capacity','movein_waitlist','movein_dns_checks','movein_runbook','movein_exceptions',
    'movein_rollback_points','movein_payments']
  loop
    execute format('grant select on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

grant select on public.movein_capacity_state, public.movein_cash_clock,
  public.movein_dns_proof, public.movein_attention, public.movein_mailbox_gaps to authenticated;
grant select on public.movein_capacity_state, public.movein_cash_clock,
  public.movein_dns_proof, public.movein_attention, public.movein_mailbox_gaps to service_role;

-- customer apna deal dekh sakta hai (portal). Founder/operator server key se.
drop policy if exists movein_deals_own on public.movein_deals;
create policy movein_deals_own on public.movein_deals for select to authenticated
  using (user_id = auth.uid() or owner_id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['movein_mailboxes','movein_dns_checks','movein_runbook',
    'movein_exceptions','movein_payments','movein_audit','movein_rollback_points']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_own', t);
    execute format($f$create policy %I on public.%I for select to authenticated
      using (exists (select 1 from public.movein_deals d
                      where d.id = %I.deal_id and (d.user_id = auth.uid() or d.owner_id = auth.uid())))$f$,
      t || '_own', t, t);
  end loop;
end $$;

drop policy if exists movein_transitions_read on public.movein_transitions;
create policy movein_transitions_read on public.movein_transitions for select to authenticated using (true);

-- capacity + waitlist: read-only visibility (kitne slot bache hain — public promise)
drop policy if exists movein_capacity_read on public.movein_capacity;
create policy movein_capacity_read on public.movein_capacity for select to authenticated using (true);
drop policy if exists movein_waitlist_own on public.movein_waitlist;
create policy movein_waitlist_own on public.movein_waitlist for select to authenticated
  using (exists (select 1 from public.movein_deals d where d.id = movein_waitlist.deal_id
                  and (d.user_id = auth.uid() or d.owner_id = auth.uid())));

-- current + next 3 months ke capacity rows (2 slots per month locked)
insert into public.movein_capacity (month, slots_total)
select (date_trunc('month', now()) + (i || ' month')::interval)::date, 2
  from generate_series(0,3) i
on conflict (month) do nothing;

commit;
