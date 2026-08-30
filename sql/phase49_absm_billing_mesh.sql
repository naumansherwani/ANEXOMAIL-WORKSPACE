-- ANEXOMAIL — Phase 49: AUTONOMOUS BILLING STATE MESH (ABSM)
-- Supabase #4 · idempotent + self-healing.
--
-- Invariant (locked):
--   Koi bhi webhook, network failure, provider delay ya node failure — akela
--   canonical billing state ko ghalat ya permanently unrecoverable nahi bana sakta.
--
-- Layers:
--   Polar        = external provider (observation only)
--   Webhook      = fast signal, authority NAHI
--   Supabase     = canonical truth  (yeh file)
--   QUIC mesh    = internal transport (billing_outbox / billing_inbox)
--   Reconcile    = recovery brain   (priority P0..P4)
--   Receipts     = immutable financial evidence

begin;

-- =========================================================================
-- 0) billing_intents ko guest-capable + versioned banao (Phase 36 upgrade)
-- =========================================================================
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='billing_intents'
                and column_name='user_id' and is_nullable='NO') then
    alter table public.billing_intents alter column user_id drop not null;
  end if;
end $$;

alter table public.billing_intents add column if not exists guest_email   text;
alter table public.billing_intents add column if not exists guest_token   text;
alter table public.billing_intents add column if not exists claimed_at    timestamptz;
alter table public.billing_intents add column if not exists fsm_state     text not null default 'CREATED';
alter table public.billing_intents add column if not exists state_version int  not null default 1;
alter table public.billing_intents add column if not exists state_hash    text;
alter table public.billing_intents add column if not exists expires_at    timestamptz;
alter table public.billing_intents add column if not exists trace_id      uuid not null default gen_random_uuid();

create unique index if not exists billing_intents_guest_token_uidx
  on public.billing_intents (guest_token) where guest_token is not null;
create index if not exists billing_intents_fsm_idx on public.billing_intents (fsm_state, updated_at desc);

-- =========================================================================
-- 1) OBSERVATION LAYER — provider kabhi truth nahi, sirf observation
-- =========================================================================
create table if not exists public.billing_observations (
  id                uuid primary key default gen_random_uuid(),
  provider          text not null default 'polar',
  channel           text not null check (channel in ('webhook','pull','manual')),
  provider_event_id text,
  entity_type       text not null,           -- checkout | order | subscription
  entity_id         text,
  intent_id         uuid references public.billing_intents(id) on delete set null,
  observed_state    text,
  amount            numeric(12,2),
  currency          text,
  product_id        text,
  customer_ref      text,
  signature_ok      boolean not null default true,
  payload           jsonb not null default '{}'::jsonb,
  observed_at       timestamptz not null default now()
);
create unique index if not exists billing_obs_event_uidx
  on public.billing_observations (provider, channel, provider_event_id)
  where provider_event_id is not null;
create index if not exists billing_obs_entity_idx
  on public.billing_observations (entity_type, entity_id, observed_at desc);

-- =========================================================================
-- 2) VERSIONED STATE + HASH (divergence detection)
-- =========================================================================
create table if not exists public.billing_state_versions (
  id            bigserial primary key,
  entity_type   text not null,
  entity_id     uuid not null,
  state_version int  not null,
  state         text not null,
  state_hash    text not null,
  source        text not null default 'reconcile',
  trace_id      uuid,
  created_at    timestamptz not null default now(),
  unique (entity_type, entity_id, state_version)
);

create or replace function public.billing_state_hash(p_entity text, p_id uuid, p_state text, p_version int)
returns text language sql immutable as $$
  select encode(digest(coalesce(p_entity,'')||'|'||coalesce(p_id::text,'')||'|'||
                       coalesce(p_state,'')||'|'||coalesce(p_version::text,''), 'sha256'), 'hex');
$$;

-- =========================================================================
-- 3) OUTBOX / INBOX — QUIC ka durability safety net
-- =========================================================================
create table if not exists public.billing_outbox (
  message_id    uuid primary key default gen_random_uuid(),
  entity_type   text not null,
  entity_id     uuid not null,
  state         text not null,
  state_version int  not null,
  state_hash    text not null,
  mode          text not null default 'DELTA' check (mode in ('DELTA','SNAPSHOT')),
  target        text not null default 'server2',
  payload       jsonb not null default '{}'::jsonb,
  attempts      int  not null default 0,
  next_try_at   timestamptz not null default now(),
  delivered_at  timestamptz,
  acked_at      timestamptz,
  last_error    text,
  trace_id      uuid,
  created_at    timestamptz not null default now()
);
create index if not exists billing_outbox_pending_idx
  on public.billing_outbox (next_try_at) where acked_at is null;

create table if not exists public.billing_inbox (
  message_id    uuid primary key,
  entity_type   text not null,
  entity_id     uuid not null,
  state         text not null,
  state_version int  not null,
  state_hash    text not null,
  applied       boolean not null default false,
  stale         boolean not null default false,
  received_at   timestamptz not null default now(),
  applied_at    timestamptz
);

-- =========================================================================
-- 4) RECONCILIATION ENGINE tables
-- =========================================================================
create table if not exists public.billing_reconciliation_runs (
  id           uuid primary key default gen_random_uuid(),
  scope        text not null default 'hot' check (scope in ('hot','warm','cold','daily')),
  started_at   timestamptz not null default now(),
  finished_at  timestamptz,
  checked      int not null default 0,
  repaired     int not null default 0,
  failed       int not null default 0,
  lease_until  timestamptz,
  note         text
);

create table if not exists public.billing_reconciliation_items (
  id          uuid primary key default gen_random_uuid(),
  run_id      uuid references public.billing_reconciliation_runs(id) on delete cascade,
  intent_id   uuid references public.billing_intents(id) on delete cascade,
  priority    text not null default 'P3' check (priority in ('P0','P1','P2','P3','P4')),
  before_state text,
  after_state  text,
  action       text,
  ok           boolean not null default true,
  detail       text,
  created_at   timestamptz not null default now()
);

create table if not exists public.billing_watermarks (
  key        text primary key,
  cursor_at  timestamptz,
  cursor_id  text,
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_failures (
  id         uuid primary key default gen_random_uuid(),
  scope      text not null,
  intent_id  uuid,
  code       text not null,
  detail     text,
  resolved   boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.billing_receipts (
  id                  uuid primary key default gen_random_uuid(),
  intent_id           uuid not null references public.billing_intents(id) on delete cascade,
  user_id             uuid,
  provider            text not null default 'polar',
  provider_object_id  text,
  amount              numeric(12,2) not null,
  currency            text not null default 'GBP',
  state               text not null,
  state_version       int not null,
  state_hash          text not null,
  confirmed_at        timestamptz not null default now(),
  trace_id            uuid,
  unique (intent_id, state_version)
);

-- =========================================================================
-- 5) GUEST CHECKOUT — sign-in ke bina bhi checkout khulta hai
-- =========================================================================
create or replace function public.billing_guest_intent_open(
  p_kind text,
  p_plan text default null,
  p_band text default null,
  p_product_key text default null,
  p_product_id text default null,
  p_seats int default 1,
  p_amount numeric default null,
  p_currency text default 'GBP',
  p_email text default null
) returns table (intent_id uuid, guest_token text)
language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_tok text;
begin
  v_tok := encode(gen_random_bytes(24), 'hex');
  insert into public.billing_intents
    (user_id, kind, plan, band, product_key, product_id, seats, amount_expected, currency,
     guest_email, guest_token, fsm_state, expires_at)
  values (null, coalesce(p_kind,'plan'), p_plan, p_band, p_product_key, p_product_id,
          greatest(1, coalesce(p_seats,1)), p_amount, coalesce(p_currency,'GBP'),
          nullif(trim(coalesce(p_email,'')),''), v_tok, 'CHECKOUT_OPEN', now() + interval '2 hours')
  returning id into v_id;

  insert into public.billing_state_versions (entity_type, entity_id, state_version, state, state_hash, source)
  values ('intent', v_id, 1, 'CHECKOUT_OPEN',
          public.billing_state_hash('intent', v_id, 'CHECKOUT_OPEN', 1), 'app');

  return query select v_id, v_tok;
end;
$$;

-- guest intent ko sign-in ke baad asli user se jodo (idempotent)
create or replace function public.billing_guest_intent_claim(p_token text, p_user uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  update public.billing_intents
     set user_id = coalesce(user_id, p_user),
         claimed_at = coalesce(claimed_at, now()),
         updated_at = now()
   where guest_token = p_token
   returning id into v_id;
  if v_id is null then return null; end if;

  -- paid guest checkout: entitlement claim ke waqt lagta hai
  if exists (select 1 from public.billing_intents where id = v_id and state = 'paid') then
    perform public.billing_apply_entitlement(v_id);
  end if;
  return v_id;
end;
$$;

-- =========================================================================
-- 6) STATE TRANSITION (version guard + hash + outbox enqueue + receipt)
-- =========================================================================
create or replace function public.billing_state_apply(
  p_intent uuid,
  p_state text,
  p_source text default 'reconcile',
  p_amount numeric default null,
  p_provider_object text default null
) returns int
language plpgsql security definer set search_path = public as $$
declare v_ver int; v_hash text; v_user uuid; v_trace uuid;
begin
  select state_version, user_id, trace_id into v_ver, v_user, v_trace
    from public.billing_intents where id = p_intent for update;
  if v_ver is null then return null; end if;

  v_ver := v_ver + 1;
  v_hash := public.billing_state_hash('intent', p_intent, p_state, v_ver);

  update public.billing_intents
     set fsm_state = p_state,
         state_version = v_ver,
         state_hash = v_hash,
         amount_paid = coalesce(p_amount, amount_paid),
         updated_at = now()
   where id = p_intent;

  insert into public.billing_state_versions
    (entity_type, entity_id, state_version, state, state_hash, source, trace_id)
  values ('intent', p_intent, v_ver, p_state, v_hash, coalesce(p_source,'reconcile'), v_trace)
  on conflict do nothing;

  insert into public.billing_outbox
    (entity_type, entity_id, state, state_version, state_hash, trace_id, payload)
  values ('intent', p_intent, p_state, v_ver, v_hash, v_trace,
          jsonb_build_object('source', p_source, 'provider_object_id', p_provider_object));

  if p_state in ('PAYMENT_CONFIRMED','SUBSCRIPTION_ACTIVE') then
    insert into public.billing_receipts
      (intent_id, user_id, provider_object_id, amount, currency, state, state_version, state_hash, trace_id)
    select p_intent, v_user, p_provider_object,
           coalesce(p_amount, i.amount_paid, i.amount_expected, 0), i.currency,
           p_state, v_ver, v_hash, v_trace
      from public.billing_intents i where i.id = p_intent
    on conflict (intent_id, state_version) do nothing;
  end if;

  return v_ver;
end;
$$;

-- QUIC inbox apply (Server 2): at-least-once delivery, idempotent business op
create or replace function public.billing_inbox_apply(
  p_message uuid, p_entity text, p_entity_id uuid, p_state text, p_version int, p_hash text
) returns text
language plpgsql security definer set search_path = public as $$
declare v_local int; v_expect text;
begin
  if exists (select 1 from public.billing_inbox where message_id = p_message) then
    return 'DUPLICATE_ACK';
  end if;

  v_expect := public.billing_state_hash(p_entity, p_entity_id, p_state, p_version);
  if v_expect <> p_hash then
    insert into public.billing_failures (scope, intent_id, code, detail)
    values ('quic_inbox', p_entity_id, 'state_hash_mismatch', p_hash);
    return 'HASH_MISMATCH';
  end if;

  select state_version into v_local from public.billing_intents where id = p_entity_id;

  insert into public.billing_inbox (message_id, entity_type, entity_id, state, state_version, state_hash)
  values (p_message, p_entity, p_entity_id, p_state, p_version, p_hash);

  if v_local is null then
    return 'UNKNOWN_ENTITY';
  elsif p_version <= v_local then
    update public.billing_inbox set stale = true where message_id = p_message;
    return 'STALE_IGNORED';
  elsif p_version > v_local + 1 then
    return 'GAP_SNAPSHOT_REQUIRED';
  end if;

  update public.billing_intents
     set fsm_state = p_state, state_version = p_version, state_hash = p_hash, updated_at = now()
   where id = p_entity_id;
  update public.billing_inbox set applied = true, applied_at = now() where message_id = p_message;
  return 'APPLIED';
end;
$$;

create or replace function public.billing_outbox_ack(p_message uuid, p_hash text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  update public.billing_outbox
     set acked_at = now(), delivered_at = coalesce(delivered_at, now())
   where message_id = p_message and state_hash = p_hash
   returning true into v_ok;
  return coalesce(v_ok, false);
end;
$$;

-- =========================================================================
-- 7) ADAPTIVE RECONCILIATION QUEUE (priority: financial risk pehle)
-- =========================================================================
create or replace view public.billing_reconcile_queue as
select i.id as intent_id,
       i.user_id,
       i.guest_token is not null as guest,
       i.polar_checkout_id,
       i.state,
       i.fsm_state,
       i.state_version,
       i.amount_expected,
       i.amount_paid,
       i.created_at,
       case
         when i.state = 'paid' and e.user_id is null then 'P0'          -- paid, entitlement missing
         when i.state = 'paid' and i.fsm_state <> 'SUBSCRIPTION_ACTIVE' then 'P1'
         when i.state = 'open' and i.created_at > now() - interval '10 minutes' then 'P1'
         when i.state = 'open' and i.created_at > now() - interval '24 hours'  then 'P2'
         when i.state = 'stuck' then 'P2'
         else 'P4'
       end as priority,
       case
         when i.created_at > now() - interval '2 minutes'  then 5
         when i.created_at > now() - interval '10 minutes' then 15
         when i.created_at > now() - interval '1 hour'     then 120
         when i.created_at > now() - interval '24 hours'   then 900
         else 3600
       end as poll_seconds
  from public.billing_intents i
  left join public.entitlement_state e on e.user_id = i.user_id
 where i.state in ('open','paid','stuck')
    or i.fsm_state in ('CHECKOUT_OPEN','PAYMENT_PENDING','PAYMENT_CONFIRMED');

-- single-flight lease: do parallel sweeps kabhi nahi
create or replace function public.billing_reconcile_begin(p_scope text default 'hot')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if exists (select 1 from public.billing_reconciliation_runs
              where finished_at is null and lease_until > now()) then
    return null;
  end if;
  insert into public.billing_reconciliation_runs (scope, lease_until)
  values (coalesce(p_scope,'hot'), now() + interval '5 minutes')
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.billing_reconcile_finish(
  p_run uuid, p_checked int default 0, p_repaired int default 0, p_failed int default 0, p_note text default null
) returns void language sql security definer set search_path = public as $$
  update public.billing_reconciliation_runs
     set finished_at = now(), checked = p_checked, repaired = p_repaired,
         failed = p_failed, note = p_note, lease_until = null
   where id = p_run;
$$;

create or replace view public.billing_mesh_health as
select
  (select count(*) from public.billing_reconcile_queue where priority = 'P0') as p0_paid_without_entitlement,
  (select count(*) from public.billing_reconcile_queue where priority = 'P1') as p1_urgent,
  (select count(*) from public.billing_outbox where acked_at is null)          as outbox_pending,
  (select count(*) from public.billing_inbox where applied = false and stale = false) as inbox_unapplied,
  (select count(*) from public.billing_observations
    where signature_ok = false and observed_at > now() - interval '24 hours')  as bad_signatures_24h,
  (select count(*) from public.billing_failures where resolved = false)        as open_failures,
  (select max(finished_at) from public.billing_reconciliation_runs)            as last_run_at;

-- =========================================================================
-- 8) GRANTS + RLS
-- =========================================================================
grant select on public.billing_receipts, public.billing_state_versions to authenticated;
grant all on public.billing_observations, public.billing_state_versions, public.billing_outbox,
             public.billing_inbox, public.billing_reconciliation_runs,
             public.billing_reconciliation_items, public.billing_watermarks,
             public.billing_failures, public.billing_receipts to service_role;
grant select on public.billing_reconcile_queue, public.billing_mesh_health to service_role;
grant usage on sequence public.billing_state_versions_id_seq to service_role;

alter table public.billing_observations          enable row level security;
alter table public.billing_state_versions        enable row level security;
alter table public.billing_outbox                enable row level security;
alter table public.billing_inbox                 enable row level security;
alter table public.billing_reconciliation_runs   enable row level security;
alter table public.billing_reconciliation_items  enable row level security;
alter table public.billing_watermarks            enable row level security;
alter table public.billing_failures              enable row level security;
alter table public.billing_receipts              enable row level security;

drop policy if exists own_receipts on public.billing_receipts;
create policy own_receipts on public.billing_receipts for select to authenticated
  using (user_id = auth.uid());

drop policy if exists service_all on public.billing_observations;
create policy service_all on public.billing_observations for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_outbox;
create policy service_all on public.billing_outbox for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_inbox;
create policy service_all on public.billing_inbox for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_state_versions;
create policy service_all on public.billing_state_versions for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_reconciliation_runs;
create policy service_all on public.billing_reconciliation_runs for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_reconciliation_items;
create policy service_all on public.billing_reconciliation_items for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_watermarks;
create policy service_all on public.billing_watermarks for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_failures;
create policy service_all on public.billing_failures for all to service_role using (true) with check (true);
drop policy if exists service_all on public.billing_receipts;
create policy service_all on public.billing_receipts for all to service_role using (true) with check (true);

grant execute on function public.billing_guest_intent_open(text,text,text,text,text,int,numeric,text,text) to service_role;
grant execute on function public.billing_guest_intent_claim(text,uuid) to service_role;
grant execute on function public.billing_state_apply(uuid,text,text,numeric,text) to service_role;
grant execute on function public.billing_inbox_apply(uuid,text,uuid,text,int,text) to service_role;
grant execute on function public.billing_outbox_ack(uuid,text) to service_role;
grant execute on function public.billing_reconcile_begin(text) to service_role;
grant execute on function public.billing_reconcile_finish(uuid,int,int,int,text) to service_role;

commit;
