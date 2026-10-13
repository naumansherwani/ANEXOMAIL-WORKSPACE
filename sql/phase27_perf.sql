-- ============================================================================
-- ANEXOMAIL — Phase 27: Performance Platform (Supabase #4)
--
-- Idempotent + self-healing: purani conflicting table `_legacy` ho jati hai,
-- phir fresh create. Grants pehle, phir RLS + own_rows policy.
--
-- 6 advance features:
--   1. Speed receipts      — perf_budgets + perf_samples (p50/p95/p99 asli samples se)
--   2. Prefetch brain      — perf_prefetch_events (hit/miss + saved_ms)
--   3. Cold-start killer   — perf_surface_starts (first paint vs warm)
--   4. Query lab           — perf_search_traces (stage waterfall JSON)
--   5. Device twin         — perf_device_profiles (network class, rtt, p95)
--   6. Regression sentinel — perf_releases + perf_regressions
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- self-heal
do $$
declare t text;
begin
  foreach t in array array[
    'perf_samples','perf_budgets','perf_prefetch_events','perf_surface_starts',
    'perf_search_traces','perf_device_profiles','perf_releases','perf_regressions'
  ] loop
    if exists (select 1 from information_schema.tables
               where table_schema = 'public' and table_name = t)
       and not exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = t and column_name = 'user_id') then
      execute format('alter table public.%I rename to %I', t, t || '_legacy');
    end if;
  end loop;
end $$;

-- ------------------------------------------------------------- 1. receipts
create table if not exists public.perf_budgets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  label text not null,
  budget_ms integer not null check (budget_ms > 0),
  created_at timestamptz not null default now(),
  unique (user_id, action)
);

create table if not exists public.perf_samples (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  surface text,
  duration_ms integer not null check (duration_ms >= 0),
  device_fingerprint text,
  release text,
  cold boolean not null default false,
  at timestamptz not null default now()
);
create index if not exists perf_samples_user_action_idx on public.perf_samples (user_id, action, at desc);

-- ------------------------------------------------------------- 2. prefetch
create table if not exists public.perf_prefetch_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  surface text not null,
  outcome text not null check (outcome in ('hit','miss')),
  saved_ms integer not null default 0,
  at timestamptz not null default now()
);
create index if not exists perf_prefetch_user_idx on public.perf_prefetch_events (user_id, at desc);

-- ---------------------------------------------------------- 3. cold starts
create table if not exists public.perf_surface_starts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  surface text not null,
  first_paint_ms integer,
  warm_ms integer,
  cold boolean not null default false,
  at timestamptz not null default now()
);
create index if not exists perf_surface_starts_user_idx on public.perf_surface_starts (user_id, at desc);

-- ------------------------------------------------------------ 4. query lab
create table if not exists public.perf_search_traces (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  query text not null,
  total_ms integer not null default 0,
  rows_returned integer not null default 0,
  cached boolean not null default false,
  stages jsonb not null default '[]'::jsonb,
  at timestamptz not null default now()
);
create index if not exists perf_search_traces_user_idx on public.perf_search_traces (user_id, at desc);

-- --------------------------------------------------------- 5. device twins
create table if not exists public.perf_device_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  fingerprint text not null,
  label text not null default 'Unknown device',
  platform text,
  browser text,
  network text not null default 'unknown' check (network in ('wifi','4g','3g','ethernet','unknown')),
  downlink_mbps numeric,
  rtt_ms integer,
  last_seen_at timestamptz not null default now(),
  unique (user_id, fingerprint)
);

-- ----------------------------------------------------- 6. regressions
create table if not exists public.perf_releases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  release text not null,
  shipped_at timestamptz not null default now(),
  unique (user_id, release)
);

create table if not exists public.perf_regressions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  release text not null,
  previous_release text,
  before_p95_ms integer,
  after_p95_ms integer,
  delta_pct numeric,
  state text not null default 'open' check (state in ('open','acknowledged','resolved')),
  advice text,
  detected_at timestamptz not null default now()
);
create index if not exists perf_regressions_user_idx on public.perf_regressions (user_id, detected_at desc);

-- ------------------------------------------------------- grants, then RLS
do $$
declare t text;
begin
  foreach t in array array[
    'perf_samples','perf_budgets','perf_prefetch_events','perf_surface_starts',
    'perf_search_traces','perf_device_profiles','perf_releases','perf_regressions'
  ] loop
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('grant all on public.%I to service_role', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists own_rows on public.%I', t);
    execute format(
      'create policy own_rows on public.%I for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid())',
      t);
  end loop;
end $$;

-- --------------------------------------------- seed: real speed budgets
insert into public.perf_budgets (user_id, action, label, budget_ms)
select u.id, b.action, b.label, b.budget_ms
from auth.users u
cross join (values
  ('thread.open',   'Open a thread',        80),
  ('mail.list',     'Load a mail folder',  120),
  ('mail.send',     'Send a message',      400),
  ('search.global', 'Global search',       150),
  ('palette.open',  'Command palette',      50),
  ('calendar.week', 'Calendar week view',  150),
  ('app.boot',      'First paint (cold)',  900)
) as b(action, label, budget_ms)
on conflict (user_id, action) do update set label = excluded.label, budget_ms = excluded.budget_ms;

-- ------------------------------------------------------- founder view
create or replace function public.founder_perf_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  with s as (
    select user_id, duration_ms from public.perf_samples where at > now() - interval '24 hours'
  ),
  per_tenant as (
    select user_id,
           percentile_disc(0.95) within group (order by duration_ms) as p95
    from s group by user_id
  )
  select jsonb_build_object(
    'tenants', (select count(distinct user_id) from public.perf_budgets),
    'p95_ms', (select percentile_disc(0.95) within group (order by duration_ms) from s),
    'budgets_failing', (
      select count(*) from public.perf_budgets b
      where (select percentile_disc(0.95) within group (order by sm.duration_ms)
             from public.perf_samples sm
             where sm.user_id = b.user_id and sm.action = b.action
               and sm.at > now() - interval '24 hours') > b.budget_ms
    ),
    'open_regressions', (select count(*) from public.perf_regressions where state = 'open'),
    'cold_starts_24h', (select count(*) from public.perf_surface_starts
                        where cold and at > now() - interval '24 hours'),
    'ms_saved_24h', (select coalesce(sum(saved_ms), 0) from public.perf_prefetch_events
                     where outcome = 'hit' and at > now() - interval '24 hours'),
    'worst_tenants', coalesce((
      select jsonb_agg(x) from (
        select coalesce(u.email, t.user_id::text) as tenant,
               t.p95 as p95_ms,
               (select count(*) from public.perf_budgets b
                where b.user_id = t.user_id
                  and (select percentile_disc(0.95) within group (order by sm.duration_ms)
                       from public.perf_samples sm
                       where sm.user_id = b.user_id and sm.action = b.action
                         and sm.at > now() - interval '24 hours') > b.budget_ms) as failing
        from per_tenant t
        left join auth.users u on u.id = t.user_id
        order by t.p95 desc nulls last
        limit 10
      ) x), '[]'::jsonb)
  );
$$;

revoke all on function public.founder_perf_overview() from public;
grant execute on function public.founder_perf_overview() to authenticated, service_role;