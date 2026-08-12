-- ============================================================================
-- ANEXOMAIL — Phase 36: STATE SYNC ENGINE (Supabase #4 = source of truth)
-- Promise: NO PAYMENT FAILURE.
--   Polar sirf MESSENGER hai. Asli sach yahan hai:
--   1) har purchase pehle Supabase mein `billing_intents` row banti hai (checkout
--      se PEHLE) — is liye koi payment "orphan" nahi ho sakti
--   2) entitlement sirf `billing_apply_entitlement()` se badalta hai (immutable log)
--   3) PULL loop: webhook aaye ya na aaye, sweep khud Polar se sach kheench kar
--      intent confirm karta hai (backoff, kabhi delete nahi)
--   4) paid intent kabhi abandoned nahi hota — sirf unpaid stale (>24h) abandon
--   5) `billing_truth_gaps` view: paid hai magar entitlement nahi = foran nazar
-- Idempotent + self-healing.
-- ============================================================================

begin;

-- ---------- 1) intents: har purchase attempt ka asli ghar ----------
do $$
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='billing_intents')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='billing_intents' and column_name='desired_state') then
    execute 'alter table public.billing_intents rename to billing_intents_legacy_' || extract(epoch from now())::bigint;
  end if;
end $$;

create table if not exists public.billing_intents (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null,
  kind              text not null default 'plan',          -- plan | movein | support
  plan              text,                                   -- basic | pro | business
  band              text,                                   -- 1-5 | 6-15 | 16-29 | 30plus
  product_key       text,
  product_id        text,
  seats             int  not null default 1,
  amount_expected   numeric(12,2),
  amount_paid       numeric(12,2),
  currency          text not null default 'GBP',
  desired_state     text not null default 'entitled',
  state             text not null default 'open'
                    check (state in ('open','paid','entitled','stuck','abandoned')),
  polar_checkout_id text,
  polar_order_id    text,
  source            text,                                   -- webhook | pull | founder
  attempts          int  not null default 0,
  last_error        text,
  next_sync_at      timestamptz not null default now(),
  paid_at           timestamptz,
  resolved_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists billing_intents_user_idx   on public.billing_intents (user_id, created_at desc);
create index if not exists billing_intents_sync_idx   on public.billing_intents (state, next_sync_at);
create unique index if not exists billing_intents_checkout_uidx
  on public.billing_intents (polar_checkout_id) where polar_checkout_id is not null;

-- ---------- 2) entitlement state: authoritative ----------
create table if not exists public.entitlement_state (
  user_id        uuid primary key,
  plan           text,
  seats          int not null default 0,
  movein_band    text,
  support_active boolean not null default false,
  active_until   timestamptz,
  revision       int not null default 0,
  source_intent  uuid,
  updated_at     timestamptz not null default now()
);

-- ---------- 3) immutable transition log ----------
create table if not exists public.billing_state_log (
  id         bigserial primary key,
  user_id    uuid,
  intent_id  uuid,
  from_state text,
  to_state   text not null,
  reason     text,
  source     text,
  payload    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists billing_state_log_user_idx on public.billing_state_log (user_id, created_at desc);

-- ---------- 4) open an intent (idempotent within 30 min) ----------
create or replace function public.billing_intent_open(
  p_user uuid,
  p_kind text,
  p_plan text default null,
  p_band text default null,
  p_product_key text default null,
  p_product_id text default null,
  p_seats int default 1,
  p_amount numeric default null,
  p_currency text default 'GBP'
) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  select id into v_id
    from public.billing_intents
   where user_id = p_user
     and state = 'open'
     and coalesce(product_id,'') = coalesce(p_product_id,'')
     and created_at > now() - interval '30 minutes'
   order by created_at desc limit 1;

  if v_id is not null then return v_id; end if;

  insert into public.billing_intents
    (user_id, kind, plan, band, product_key, product_id, seats, amount_expected, currency)
  values (p_user, coalesce(p_kind,'plan'), p_plan, p_band, p_product_key, p_product_id,
          greatest(1, coalesce(p_seats,1)), p_amount, coalesce(p_currency,'GBP'))
  returning id into v_id;

  insert into public.billing_state_log (user_id, intent_id, from_state, to_state, reason, source)
  values (p_user, v_id, null, 'open', 'intent opened before checkout', 'app');
  return v_id;
end;
$$;

create or replace function public.billing_intent_attach_checkout(p_intent uuid, p_checkout_id text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.billing_intents
     set polar_checkout_id = p_checkout_id, updated_at = now()
   where id = p_intent and polar_checkout_id is null;
end;
$$;

-- ---------- 5) entitlement apply (only writer) ----------
create or replace function public.billing_apply_entitlement(
  p_user uuid,
  p_kind text,
  p_plan text,
  p_band text,
  p_seats int,
  p_intent uuid,
  p_source text
) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into public.entitlement_state (user_id, plan, seats, movein_band, support_active,
                                        active_until, revision, source_intent, updated_at)
  values (
    p_user,
    case when p_kind = 'plan' then p_plan else null end,
    case when p_kind = 'plan' then greatest(1, coalesce(p_seats,1)) else 0 end,
    case when p_kind = 'movein' then p_band else null end,
    p_kind = 'support',
    case when p_kind in ('plan','support') then now() + interval '31 days' else null end,
    1, p_intent, now()
  )
  on conflict (user_id) do update set
    plan           = coalesce(case when p_kind='plan' then p_plan else null end, entitlement_state.plan),
    seats          = case when p_kind='plan' then greatest(1, coalesce(p_seats,1)) else entitlement_state.seats end,
    movein_band    = coalesce(case when p_kind='movein' then p_band else null end, entitlement_state.movein_band),
    support_active = entitlement_state.support_active or (p_kind='support'),
    active_until   = case when p_kind in ('plan','support') then now() + interval '31 days'
                          else entitlement_state.active_until end,
    revision       = entitlement_state.revision + 1,
    source_intent  = p_intent,
    updated_at     = now();

  insert into public.billing_state_log (user_id, intent_id, from_state, to_state, reason, source)
  values (p_user, p_intent, 'paid', 'entitled', 'entitlement applied: ' || coalesce(p_kind,'plan'), p_source);
end;
$$;

-- ---------- 6) confirm payment (idempotent, webhook ya pull dono se) ----------
create or replace function public.billing_intent_confirm(
  p_intent uuid default null,
  p_checkout_id text default null,
  p_order_id text default null,
  p_amount numeric default null,
  p_source text default 'pull'
) returns table (intent_id uuid, state text, already boolean)
language plpgsql security definer set search_path = public as $$
declare r public.billing_intents;
begin
  select * into r from public.billing_intents
   where (p_intent is not null and id = p_intent)
      or (p_checkout_id is not null and polar_checkout_id = p_checkout_id)
   order by created_at desc limit 1;

  if r.id is null then
    insert into public.payment_alerts (severity, kind, message)
    values ('critical','payment_without_intent',
            'paid signal without matching intent — checkout=' || coalesce(p_checkout_id,'?') ||
            ' order=' || coalesce(p_order_id,'?'));
    return query select null::uuid, 'no_intent'::text, false;
    return;
  end if;

  if r.state = 'entitled' then
    return query select r.id, r.state, true;
    return;
  end if;

  update public.billing_intents
     set state = 'paid', paid_at = coalesce(paid_at, now()),
         polar_order_id = coalesce(p_order_id, polar_order_id),
         amount_paid = coalesce(p_amount, amount_paid),
         source = p_source, last_error = null, updated_at = now()
   where id = r.id;

  insert into public.billing_state_log (user_id, intent_id, from_state, to_state, reason, source)
  values (r.user_id, r.id, r.state, 'paid', 'payment confirmed', p_source);

  perform public.billing_apply_entitlement(r.user_id, r.kind, r.plan, r.band, r.seats, r.id, p_source);

  update public.billing_intents
     set state = 'entitled', resolved_at = now(), next_sync_at = now() + interval '100 years',
         updated_at = now()
   where id = r.id;

  return query select r.id, 'entitled'::text, false;
end;
$$;

-- ---------- 7) sync loop: claim / fail / abandon ----------
create or replace function public.billing_sync_claim(p_limit int default 25)
returns table (id uuid, user_id uuid, kind text, plan text, band text,
               polar_checkout_id text, state text, attempts int, created_at timestamptz)
language sql security definer set search_path = public as $$
  select i.id, i.user_id, i.kind, i.plan, i.band, i.polar_checkout_id, i.state, i.attempts, i.created_at
    from public.billing_intents i
   where i.state in ('open','paid','stuck')
     and i.next_sync_at <= now()
   order by i.created_at asc
   limit greatest(1, least(p_limit, 100));
$$;

create or replace function public.billing_sync_touch(p_intent uuid, p_delay_seconds int default 60)
returns void language sql security definer set search_path = public as $$
  update public.billing_intents
     set next_sync_at = now() + make_interval(secs => greatest(15, p_delay_seconds)),
         updated_at = now()
   where id = p_intent;
$$;

create or replace function public.billing_sync_fail(p_intent uuid, p_error text)
returns void language plpgsql security definer set search_path = public as $$
declare v_attempts int; v_state text;
begin
  update public.billing_intents
     set attempts = attempts + 1,
         last_error = p_error,
         -- backoff 30s, 1m, 2m ... capped 1h
         next_sync_at = now() + least(interval '1 hour', (interval '30 seconds') * power(2, least(attempts, 7))),
         state = case when state = 'paid' and attempts + 1 >= 5 then 'stuck' else state end,
         updated_at = now()
   where id = p_intent
  returning attempts, state into v_attempts, v_state;

  if coalesce(v_attempts,0) >= 3 then
    insert into public.payment_alerts (severity, kind, message)
    values ('critical','state_sync_failed',
            'intent ' || p_intent || ' attempt ' || v_attempts || ': ' || coalesce(p_error,'unknown'));
  end if;
end;
$$;

-- sirf unpaid + 24h purana intent abandon hota hai. paid kabhi nahi.
create or replace function public.billing_sync_abandon_stale()
returns int language plpgsql security definer set search_path = public as $$
declare v_count int;
begin
  with done as (
    update public.billing_intents
       set state = 'abandoned', resolved_at = now(), updated_at = now()
     where state = 'open'
       and paid_at is null
       and created_at < now() - interval '24 hours'
    returning id, user_id, state
  )
  insert into public.billing_state_log (user_id, intent_id, from_state, to_state, reason, source)
  select user_id, id, 'open', 'abandoned', 'unpaid for 24h', 'sweep' from done;
  get diagnostics v_count = row_count;
  return coalesce(v_count, 0);
end;
$$;

-- ---------- 8) truth gaps: founder dashboard ka dil ----------
create or replace view public.billing_truth_gaps as
  select 'paid_without_entitlement' as gap, i.id::text as ref, i.user_id, i.state,
         i.paid_at as at, i.last_error as detail
    from public.billing_intents i
    left join public.entitlement_state e on e.user_id = i.user_id
   where i.paid_at is not null and (e.user_id is null or e.source_intent is distinct from i.id)
     and i.state <> 'entitled'
  union all
  select 'stuck_intent', i.id::text, i.user_id, i.state, i.updated_at, i.last_error
    from public.billing_intents i where i.state = 'stuck'
  union all
  select 'unverified_webhook', r.id::text, null::uuid, 'raw', r.received_at, r.reject_reason
    from public.polar_webhook_raw r
   where r.verified = false and r.received_at > now() - interval '30 days';

create or replace view public.billing_state_health as
  select
    (select count(*) from public.billing_intents where state = 'open')      as open_intents,
    (select count(*) from public.billing_intents where state = 'paid')      as paid_pending,
    (select count(*) from public.billing_intents where state = 'stuck')     as stuck_intents,
    (select count(*) from public.billing_intents where state = 'entitled')  as entitled_total,
    (select count(*) from public.billing_truth_gaps)                        as open_gaps,
    (select count(*) from public.payment_alerts where resolved_at is null)  as open_alerts,
    (select max(updated_at) from public.billing_intents)                    as last_sync_at;

-- ---------- 9) grants + RLS ----------
grant select on public.billing_intents, public.entitlement_state, public.billing_state_log to authenticated;
grant all on public.billing_intents, public.entitlement_state, public.billing_state_log to service_role;
grant select on public.billing_truth_gaps, public.billing_state_health to service_role;

alter table public.billing_intents    enable row level security;
alter table public.entitlement_state  enable row level security;
alter table public.billing_state_log  enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='billing_intents' and policyname='service manages intents') then
    create policy "service manages intents" on public.billing_intents for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='billing_intents' and policyname='users read own intents') then
    create policy "users read own intents" on public.billing_intents for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='entitlement_state' and policyname='service manages entitlement') then
    create policy "service manages entitlement" on public.entitlement_state for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='entitlement_state' and policyname='users read own entitlement') then
    create policy "users read own entitlement" on public.entitlement_state for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='billing_state_log' and policyname='service manages state log') then
    create policy "service manages state log" on public.billing_state_log for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='billing_state_log' and policyname='users read own state log') then
    create policy "users read own state log" on public.billing_state_log for select to authenticated using (user_id = auth.uid());
  end if;
end $$;

commit;
