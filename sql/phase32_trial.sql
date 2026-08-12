-- ============================================================================
-- ANEXOMAIL — Phase 32: TRIAL LIFECYCLE (Supabase #4)
--
-- FOUNDER LOCK (locked refinements):
--   1. 48h trial · AI hard zero · mandatory @anexomail.com claim
--   2. Recovery path MANDATORY when social login ends (never lock a user out)
--   3. Frozen mailbox NEVER silently loses incoming mail (hold or reject, logged)
--   4. Expired/frozen users keep account + billing + recovery access, NOT business data
--   5. Trial warning events IDEMPOTENT (unique per user per event)
--   6. Truth lives in the DB: public.account_state(uuid) is the only authority
--
-- Idempotent + self-healing. Grants pehle, phir RLS.
-- ============================================================================
create extension if not exists pgcrypto;

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='trial_accounts')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='trial_accounts' and column_name='trial_ends_at') then
    execute format('alter table public.trial_accounts rename to trial_accounts_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='trial_events')
     and not exists (select 1 from information_schema.columns
             where table_schema='public' and table_name='trial_events' and column_name='event_type') then
    execute format('alter table public.trial_events rename to trial_events_legacy_%s', ts);
  end if;
end $$;

-- ─── 1. TRIAL ACCOUNTS ────────────────────────────────────────
create table if not exists public.trial_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  social_email text,
  social_provider text,
  anexomail_address text,
  anexomail_handle text,                       -- lowercased local part (ci uniqueness)
  trial_started_at timestamptz not null default now(),
  trial_ends_at timestamptz not null default now() + interval '48 hours',
  status text not null default 'trial'
    check (status in ('trial','active','expired','frozen','released')),
  plan text check (plan in ('basic','pro','business')),
  passkey_set boolean not null default false,
  recovery_set boolean not null default false,
  recovery_kind text,                          -- gmail | apple | outlook | other_email | phone
  recovery_hint text,                          -- masked hint only, never full secret
  expired_at timestamptz,
  frozen_at timestamptz,
  address_reserved_until timestamptz,          -- 30-day reservation after expiry
  converted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists trial_accounts_handle_ci_idx
  on public.trial_accounts (lower(anexomail_handle)) where anexomail_handle is not null;
create index if not exists trial_accounts_status_idx on public.trial_accounts (status, trial_ends_at);

-- ─── 2. IMMUTABLE EVENT LEDGER (idempotent warnings) ──────────
create table if not exists public.trial_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  event_type text not null check (event_type in
    ('signup','claim','passkey_set','recovery_set','warn_24h','warn_2h',
     'expired','subscribed','frozen','released','mail_hold','recovery_used')),
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists trial_events_user_idx on public.trial_events (user_id, created_at desc);
-- IDEMPOTENCY: ek user ko ek lifecycle event sirf ek baar (warnings dobara nahi jaayengi)
create unique index if not exists trial_events_once_idx
  on public.trial_events (user_id, event_type)
  where event_type in ('signup','claim','passkey_set','recovery_set','warn_24h','warn_2h','expired','frozen','released');

create or replace function public.trial_events_immutable() returns trigger
language plpgsql as $$
begin
  raise exception 'trial_events is append-only (immutable audit ledger)';
end $$;
drop trigger if exists trial_events_no_update on public.trial_events;
create trigger trial_events_no_update before update or delete on public.trial_events
  for each row execute function public.trial_events_immutable();

-- ─── 3. RESERVED ADDRESSES (awam ko block) ────────────────────
create table if not exists public.reserved_handles (
  handle text primary key,
  reason text not null default 'system'
);
insert into public.reserved_handles (handle, reason) values
  ('admin','system'),('administrator','system'),('postmaster','system'),('hostmaster','system'),
  ('webmaster','system'),('abuse','system'),('security','system'),('root','system'),
  ('hello','brand'),('support','brand'),('billing','brand'),('noreply','brand'),
  ('no-reply','brand'),('info','brand'),('sales','brand'),('contact','brand'),
  ('trials','brand'),('dmarc','system'),('resolved','internal'),('leo','internal'),
  ('jimmy','internal'),('jimmyjohn','internal'),('sherlock','internal'),
  ('anexomail','brand'),('nexatect','brand'),('founder','brand'),
  ('moveyourbusiness','brand'),('legal','brand'),('privacy','brand'),('press','brand')
on conflict (handle) do nothing;

-- ─── 4. FROZEN MAIL HOLD (mail kabhi silently gum nahi hoti) ──
create table if not exists public.trial_mail_holds (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  anexomail_address text not null,
  from_address text,
  subject text,
  message_id text unique,
  disposition text not null default 'held'
    check (disposition in ('held','rejected','delivered')),
  reason text,
  received_at timestamptz not null default now(),
  released_at timestamptz
);
create index if not exists trial_mail_holds_addr_idx on public.trial_mail_holds (anexomail_address, received_at desc);

-- ─── 5. GRANTS (RLS se pehle) ─────────────────────────────────
grant select on public.trial_accounts to authenticated;
grant select on public.trial_events to authenticated;
grant select on public.reserved_handles to authenticated, anon;
grant select on public.trial_mail_holds to authenticated;
grant all on public.trial_accounts, public.trial_events,
             public.reserved_handles, public.trial_mail_holds to service_role;

alter table public.trial_accounts enable row level security;
alter table public.trial_events enable row level security;
alter table public.trial_mail_holds enable row level security;
alter table public.reserved_handles enable row level security;

-- Account/billing/recovery visibility hamesha rehti hai (expired/frozen bhi) —
-- business data (mail/crm/etc) RLS unke apne tables pe entitled_full() se banda hai.
drop policy if exists trial_accounts_own on public.trial_accounts;
create policy trial_accounts_own on public.trial_accounts
  for select to authenticated using (user_id = auth.uid());

drop policy if exists trial_events_own on public.trial_events;
create policy trial_events_own on public.trial_events
  for select to authenticated using (user_id = auth.uid());

drop policy if exists trial_mail_holds_own on public.trial_mail_holds;
create policy trial_mail_holds_own on public.trial_mail_holds
  for select to authenticated using (user_id = auth.uid());

drop policy if exists reserved_handles_read on public.reserved_handles;
create policy reserved_handles_read on public.reserved_handles
  for select to authenticated, anon using (true);

-- ─── 6. THE AUTHORITY: account_state() ────────────────────────
-- Frontend timer sirf display hai. Har gate isi function se guzarta hai.
create or replace function public.account_state(_user_id uuid default auth.uid())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare a public.trial_accounts; st text; hrs numeric; res_left numeric;
begin
  select * into a from public.trial_accounts where user_id = _user_id;
  if a.user_id is null then
    return jsonb_build_object(
      'state','none','hours_left',0,'can_social_login',true,'ai_enabled',false,
      'address',null,'needs_claim',true,'needs_passkey',true,'needs_recovery',true,
      'business_data',false,'billing_access',true,'recovery_access',true);
  end if;

  st := a.status;
  -- DB decides expiry, not the clock in the browser
  if st = 'trial' and a.trial_ends_at <= now() then st := 'expired'; end if;
  if st = 'expired' and a.expired_at is not null
     and a.expired_at + interval '30 days' <= now() then st := 'released'; end if;

  hrs := greatest(0, round(extract(epoch from (a.trial_ends_at - now())) / 3600.0, 2));
  res_left := case when a.address_reserved_until is null then null
                   else greatest(0, round(extract(epoch from (a.address_reserved_until - now())) / 86400.0, 2)) end;

  return jsonb_build_object(
    'state', st,
    'plan', a.plan,
    'hours_left', case when st = 'trial' then hrs else 0 end,
    'trial_ends_at', a.trial_ends_at,
    -- REFINEMENT 1+2: social login trial ke andar hi chalta hai; band hone ke baad
    -- recovery path hamesha khula rehta hai — koi account permanently locked nahi.
    'can_social_login', st in ('trial','active'),
    'recovery_access', true,
    'billing_access', true,
    'business_data', st = 'active' or st = 'trial',
    'ai_enabled', st = 'active',                 -- trial/expired/frozen = HARD ZERO
    'address', a.anexomail_address,
    'address_reserved_days_left', res_left,
    'needs_claim', a.anexomail_address is null,
    'needs_passkey', not a.passkey_set,
    'needs_recovery', not a.recovery_set
  );
end $$;

grant execute on function public.account_state(uuid) to authenticated, service_role;

-- Business-data gate for other tables' RLS: `using (public.entitled_full())`
create or replace function public.entitled_full(_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((public.account_state(_user_id) ->> 'business_data')::boolean, false);
$$;
grant execute on function public.entitled_full(uuid) to authenticated, service_role;

create or replace function public.ai_enabled(_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce((public.account_state(_user_id) ->> 'ai_enabled')::boolean, false);
$$;
grant execute on function public.ai_enabled(uuid) to authenticated, service_role;

-- AI tables: trial/expired/frozen user AI ledger ko chhoo bhi nahi sakta
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='ai_credit_ledger') then
    execute 'drop policy if exists ai_ledger_ai_enabled on public.ai_credit_ledger';
    execute 'create policy ai_ledger_ai_enabled on public.ai_credit_ledger
             for select to authenticated using (user_id = auth.uid() and public.ai_enabled())';
  end if;
  if exists (select 1 from information_schema.tables
             where table_schema='public' and table_name='ai_credit_wallets') then
    execute 'drop policy if exists ai_wallet_ai_enabled on public.ai_credit_wallets';
    execute 'create policy ai_wallet_ai_enabled on public.ai_credit_wallets
             for select to authenticated using (owner_id = auth.uid() and public.ai_enabled())';
  end if;
end $$;

-- ─── 7. LIFECYCLE RPCs (sirf server_role/backend chalata hai) ──
create or replace function public.trial_start(_user_id uuid, _social_email text, _provider text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a public.trial_accounts;
begin
  insert into public.trial_accounts (user_id, social_email, social_provider)
  values (_user_id, _social_email, _provider)
  on conflict (user_id) do update set social_email = coalesce(excluded.social_email, trial_accounts.social_email),
                                      updated_at = now()
  returning * into a;
  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'signup', jsonb_build_object('provider', _provider, 'email', _social_email))
  on conflict do nothing;
  return public.account_state(_user_id);
end $$;

create or replace function public.trial_claim_address(_user_id uuid, _handle text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare h text := lower(trim(_handle));
begin
  if h !~ '^[a-z0-9]([a-z0-9.-]{1,28})[a-z0-9]$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_handle');
  end if;
  if exists (select 1 from public.reserved_handles where handle = h) then
    return jsonb_build_object('ok', false, 'error', 'reserved_handle');
  end if;
  if exists (select 1 from public.trial_accounts
             where lower(anexomail_handle) = h and user_id <> _user_id
               and (status <> 'released')) then
    return jsonb_build_object('ok', false, 'error', 'taken');
  end if;
  update public.trial_accounts
     set anexomail_handle = h, anexomail_address = h || '@anexomail.com', updated_at = now()
   where user_id = _user_id;
  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'claim', jsonb_build_object('address', h || '@anexomail.com'))
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'state', public.account_state(_user_id));
end $$;

create or replace function public.trial_set_security(
  _user_id uuid, _passkey boolean, _recovery_kind text, _recovery_hint text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  update public.trial_accounts
     set passkey_set = passkey_set or coalesce(_passkey, false),
         recovery_set = recovery_set or (_recovery_kind is not null),
         recovery_kind = coalesce(_recovery_kind, recovery_kind),
         recovery_hint = coalesce(_recovery_hint, recovery_hint),
         updated_at = now()
   where user_id = _user_id;
  if coalesce(_passkey, false) then
    insert into public.trial_events (user_id, event_type) values (_user_id, 'passkey_set')
    on conflict do nothing;
  end if;
  if _recovery_kind is not null then
    insert into public.trial_events (user_id, event_type, detail)
    values (_user_id, 'recovery_set', jsonb_build_object('kind', _recovery_kind, 'hint', _recovery_hint))
    on conflict do nothing;
  end if;
  return public.account_state(_user_id);
end $$;

create or replace function public.trial_subscribe(_user_id uuid, _plan text, _payment_ref text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if _plan not in ('basic','pro','business') then
    return jsonb_build_object('ok', false, 'error', 'invalid_plan');
  end if;
  update public.trial_accounts
     set status = 'active', plan = _plan, converted_at = coalesce(converted_at, now()),
         expired_at = null, frozen_at = null, address_reserved_until = null, updated_at = now()
   where user_id = _user_id;
  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'subscribed', jsonb_build_object('plan', _plan, 'payment_ref', _payment_ref))
  on conflict do nothing;
  return jsonb_build_object('ok', true, 'state', public.account_state(_user_id));
end $$;

grant execute on function public.trial_start(uuid,text,text) to service_role;
grant execute on function public.trial_claim_address(uuid,text) to service_role, authenticated;
grant execute on function public.trial_set_security(uuid,boolean,text,text) to service_role, authenticated;
grant execute on function public.trial_subscribe(uuid,text,text) to service_role;

-- ─── 8. HOURLY SWEEP (idempotent) ─────────────────────────────
create or replace function public.trial_sweep()
returns jsonb language plpgsql security definer set search_path = public as $$
declare warned24 int := 0; warned2 int := 0; expired int := 0; frozen int := 0; released int := 0;
begin
  -- 24h warning (once — unique index guarantees it)
  with c as (
    select user_id from public.trial_accounts
     where status = 'trial' and trial_ends_at between now() and now() + interval '24 hours'
  ), i as (
    insert into public.trial_events (user_id, event_type)
    select user_id, 'warn_24h' from c on conflict do nothing returning 1
  ) select count(*) into warned24 from i;

  with c as (
    select user_id from public.trial_accounts
     where status = 'trial' and trial_ends_at between now() and now() + interval '2 hours'
  ), i as (
    insert into public.trial_events (user_id, event_type)
    select user_id, 'warn_2h' from c on conflict do nothing returning 1
  ) select count(*) into warned2 from i;

  -- trial -> expired (social login band, recovery khula, address 30 din reserved)
  with u as (
    update public.trial_accounts
       set status = 'expired', expired_at = now(),
           address_reserved_until = now() + interval '30 days', updated_at = now()
     where status = 'trial' and trial_ends_at <= now()
     returning user_id
  ), i as (
    insert into public.trial_events (user_id, event_type) select user_id, 'expired' from u
    on conflict do nothing returning 1
  ) select count(*) into expired from i;

  -- expired -> frozen (mailbox inaccessible, mail held/rejected — kabhi discard nahi)
  with u as (
    update public.trial_accounts set status = 'frozen', frozen_at = now(), updated_at = now()
     where status = 'expired' and expired_at <= now() - interval '24 hours'
     returning user_id
  ), i as (
    insert into public.trial_events (user_id, event_type) select user_id, 'frozen' from u
    on conflict do nothing returning 1
  ) select count(*) into frozen from i;

  -- 30 din baad address release
  with u as (
    update public.trial_accounts
       set status = 'released', anexomail_handle = null, address_reserved_until = null, updated_at = now()
     where status in ('expired','frozen') and address_reserved_until is not null
       and address_reserved_until <= now()
     returning user_id
  ), i as (
    insert into public.trial_events (user_id, event_type) select user_id, 'released' from u
    on conflict do nothing returning 1
  ) select count(*) into released from i;

  return jsonb_build_object('warn_24h', warned24, 'warn_2h', warned2,
    'expired', expired, 'frozen', frozen, 'released', released, 'ran_at', now());
end $$;
grant execute on function public.trial_sweep() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('anexomail_trial_sweep')
      where exists (select 1 from cron.job where jobname = 'anexomail_trial_sweep');
    perform cron.schedule('anexomail_trial_sweep', '5 * * * *', 'select public.trial_sweep()');
  end if;
end $$;
