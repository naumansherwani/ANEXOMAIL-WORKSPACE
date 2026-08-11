-- ANEXOMAIL — Phase 26: Security Platform (Supabase #4)
--
-- LOCKED: koi API keys nahi. Access ka unit = DEVICE (fingerprint + trust score).
--
-- 6 advance features:
--   1. Device Trust        — security_devices (fingerprint, trust_score, state)
--   2. Impossible travel   — security_anomalies (km + minutes + freeze)
--   3. Ownership proof     — security_proofs + security_proof_checks (hashed)
--   4. Encryption ledger   — security_encryption_surfaces + security_key_ledger
--   5. Login replay        — security_login_events (risk_score, story, disowned)
--   6. Blast-radius kill   — security_kill_switches + hash-chained security_ledger
--
-- Rules: idempotent + self-healing (purani conflicting table _legacy rename),
-- GRANTS pehle phir RLS, har table user_id = auth.uid() se scoped.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Self-heal: agar purani table mein user_id column nahi hai to legacy rename
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
  ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  foreach t in array array[
    'security_devices','security_sessions','security_login_events',
    'security_anomalies','security_encryption_surfaces','security_key_ledger',
    'security_proofs','security_proof_checks','security_kill_switches','security_ledger'
  ]
  loop
    if exists (select 1 from information_schema.tables
               where table_schema='public' and table_name=t)
       and not exists (select 1 from information_schema.columns
               where table_schema='public' and table_name=t and column_name='user_id')
    then
      execute format('alter table public.%I rename to %I', t, t||'_legacy_'||ts);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 1) Device Trust — API keys ki jagah
-- ---------------------------------------------------------------------------
create table if not exists public.security_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null,
  fingerprint text not null,
  platform text,
  browser text,
  state text not null default 'pending' check (state in ('trusted','pending','blocked')),
  trust_score int not null default 50 check (trust_score between 0 and 100),
  reasons jsonb not null default '[]'::jsonb,
  city text,
  country text,
  ip text,
  current boolean not null default false,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  unique (user_id, fingerprint)
);
create index if not exists security_devices_user_idx on public.security_devices(user_id, last_seen_at desc);

-- ---------------------------------------------------------------------------
-- 2) Sessions
-- ---------------------------------------------------------------------------
create table if not exists public.security_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  device_id uuid references public.security_devices(id) on delete set null,
  device_label text,
  ip text,
  city text,
  country text,
  lat double precision,
  lon double precision,
  risk text not null default 'low' check (risk in ('low','medium','high')),
  current boolean not null default false,
  killed_at timestamptz,
  started_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz
);
create index if not exists security_sessions_user_idx on public.security_sessions(user_id, last_seen_at desc);

-- ---------------------------------------------------------------------------
-- 3) Login replay
-- ---------------------------------------------------------------------------
create table if not exists public.security_login_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null,
  method text not null default 'password' check (method in ('password','google','apple','passkey','recovery')),
  outcome text not null default 'success' check (outcome in ('success','failed','blocked','challenged')),
  ip text,
  city text,
  country text,
  lat double precision,
  lon double precision,
  device_id uuid references public.security_devices(id) on delete set null,
  device_label text,
  risk_score int not null default 0 check (risk_score between 0 and 100),
  story text,
  disowned boolean not null default false,
  at timestamptz not null default now()
);
create index if not exists security_login_events_user_idx on public.security_login_events(user_id, at desc);

-- ---------------------------------------------------------------------------
-- 4) Anomalies — impossible travel etc. Server pehle freeze karta hai.
-- ---------------------------------------------------------------------------
create table if not exists public.security_anomalies (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('impossible_travel','new_country','token_reuse','mass_export','brute_force')),
  severity text not null default 'medium' check (severity in ('low','medium','high')),
  state text not null default 'open' check (state in ('open','frozen','cleared')),
  detail text not null,
  km double precision,
  minutes int,
  created_at timestamptz not null default now()
);
create index if not exists security_anomalies_user_idx on public.security_anomalies(user_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 5) Encryption ledger
-- ---------------------------------------------------------------------------
create table if not exists public.security_encryption_surfaces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  scope text not null check (scope in ('at_rest','in_transit')),
  surface text not null,
  algorithm text not null,
  cipher text,
  state text not null default 'on' check (state in ('on','off','partial')),
  detail text,
  updated_at timestamptz not null default now(),
  unique (user_id, scope, surface)
);

create table if not exists public.security_key_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  surface text not null default 'all',
  hash text not null,
  at timestamptz not null default now()
);
create index if not exists security_key_ledger_user_idx on public.security_key_ledger(user_id, at desc);

-- ---------------------------------------------------------------------------
-- 6) Ownership proof packs
-- ---------------------------------------------------------------------------
create table if not exists public.security_proofs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  domain text not null,
  ran_at timestamptz not null default now(),
  passed int not null default 0,
  failed int not null default 0,
  proof_hash text
);
create index if not exists security_proofs_user_idx on public.security_proofs(user_id, ran_at desc);

create table if not exists public.security_proof_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  proof_id uuid not null references public.security_proofs(id) on delete cascade,
  check_name text not null,
  result text not null default 'skip' check (result in ('pass','fail','skip')),
  observed text,
  expected text,
  fix text
);
create index if not exists security_proof_checks_proof_idx on public.security_proof_checks(proof_id);

-- ---------------------------------------------------------------------------
-- 7) Blast-radius kill switch + hash-chained ledger
-- ---------------------------------------------------------------------------
create table if not exists public.security_kill_switches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text,
  sessions_killed int not null default 0,
  devices_blocked int not null default 0,
  hash text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.security_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  actor text not null default 'owner',
  payload jsonb not null default '{}'::jsonb,
  prev_hash text,
  hash text not null,
  at timestamptz not null default now()
);
create index if not exists security_ledger_user_idx on public.security_ledger(user_id, at desc);

-- ---------------------------------------------------------------------------
-- GRANTS pehle, phir RLS (locked order)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'security_devices','security_sessions','security_login_events',
    'security_anomalies','security_encryption_surfaces','security_key_ledger',
    'security_proofs','security_proof_checks','security_kill_switches','security_ledger'
  ]
  loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format(
      'create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Founder god-view (service_role only)
-- ---------------------------------------------------------------------------
create or replace function public.founder_security_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'tenants', (select count(distinct user_id) from security_devices),
    'devices_blocked', (select count(*) from security_devices where state = 'blocked'),
    'open_anomalies', (select count(*) from security_anomalies where state = 'open'),
    'frozen_accounts', (select count(distinct user_id) from security_anomalies where state = 'frozen'),
    'failed_logins_24h', (select count(*) from security_login_events
                          where outcome in ('failed','blocked') and at > now() - interval '24 hours'),
    'kill_switches_30d', (select count(*) from security_kill_switches
                          where created_at > now() - interval '30 days'),
    'worst_tenants', coalesce((
      select jsonb_agg(x) from (
        select a.user_id::text as tenant,
               count(*) filter (where a.state <> 'cleared') as anomalies,
               (select count(*) from security_login_events e
                where e.user_id = a.user_id and e.outcome in ('failed','blocked')
                  and e.at > now() - interval '24 hours') as failed_logins
        from security_anomalies a
        group by a.user_id
        order by anomalies desc
        limit 8
      ) x), '[]'::jsonb)
  );
$$;

revoke all on function public.founder_security_overview() from public, anon, authenticated;
grant execute on function public.founder_security_overview() to service_role;