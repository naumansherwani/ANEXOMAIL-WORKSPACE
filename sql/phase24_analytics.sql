-- ANEXOMAIL — Phase 24: Analytics Center (Supabase #4)
-- NO VANITY: koi open-rate/click-rate table nahi. Sirf faisla badalne wale numbers.
-- 6 advance features: Response debt (£) · Thread economics · Deep work map
--                     · Attention leaks · Promise SLA · Next-week forecast
begin;

create extension if not exists pg_trgm;

-- 1) Cost model: kis ka waqt kitna mehnga hai (£/hour) ----------------------
create table if not exists public.analytics_rates (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  scope        text not null default 'self' check (scope in ('self','team','external')),
  hourly_rate  numeric(10,2) not null default 60.00,
  currency     text not null default 'GBP',
  updated_at   timestamptz not null default now(),
  unique (user_id, scope)
);
grant select, insert, update, delete on public.analytics_rates to authenticated;
grant all on public.analytics_rates to service_role;
alter table public.analytics_rates enable row level security;
drop policy if exists analytics_rates_own on public.analytics_rates;
create policy analytics_rates_own on public.analytics_rates for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 2) Response debt snapshots (trend without recomputing history) ------------
create table if not exists public.analytics_debt_daily (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  day              date not null,
  waiting_people   integer not null default 0,
  waiting_threads  integer not null default 0,
  oldest_hours     numeric(10,2) not null default 0,
  median_hours     numeric(10,2) not null default 0,
  cost_of_delay    numeric(12,2) not null default 0,
  currency         text not null default 'GBP',
  created_at       timestamptz not null default now(),
  unique (user_id, day)
);
grant select, insert, update on public.analytics_debt_daily to authenticated;
grant all on public.analytics_debt_daily to service_role;
alter table public.analytics_debt_daily enable row level security;
drop policy if exists analytics_debt_own on public.analytics_debt_daily;
create policy analytics_debt_own on public.analytics_debt_daily for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 3) Thread economics ledger (minutes + people-hours per thread) ------------
create table if not exists public.analytics_thread_cost (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users(id) on delete cascade,
  thread_id     uuid,
  subject       text,
  messages      integer not null default 0,
  participants  integer not null default 0,
  minutes       integer not null default 0,
  people_hours  numeric(10,2) not null default 0,
  cost          numeric(12,2) not null default 0,
  currency      text not null default 'GBP',
  resolved      boolean not null default false,
  computed_at   timestamptz not null default now(),
  unique (user_id, thread_id)
);
create index if not exists analytics_thread_cost_idx on public.analytics_thread_cost(user_id, cost desc);
grant select, insert, update, delete on public.analytics_thread_cost to authenticated;
grant all on public.analytics_thread_cost to service_role;
alter table public.analytics_thread_cost enable row level security;
drop policy if exists analytics_thread_cost_own on public.analytics_thread_cost;
create policy analytics_thread_cost_own on public.analytics_thread_cost for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 4) Deep work map (per day: deep vs inbox vs meetings) ---------------------
create table if not exists public.analytics_deep_work (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users(id) on delete cascade,
  day                     date not null,
  deep_minutes            integer not null default 0,
  inbox_minutes           integer not null default 0,
  meeting_minutes         integer not null default 0,
  longest_focus_minutes   integer not null default 0,
  fragmentation           integer not null default 0,
  best_window             text,
  unique (user_id, day)
);
grant select, insert, update on public.analytics_deep_work to authenticated;
grant all on public.analytics_deep_work to service_role;
alter table public.analytics_deep_work enable row level security;
drop policy if exists analytics_deep_work_own on public.analytics_deep_work;
create policy analytics_deep_work_own on public.analytics_deep_work for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 5) Attention leaks (who/what interrupts, and the fix) --------------------
create table if not exists public.analytics_attention_leaks (
  id                 uuid primary key default gen_random_uuid(),
  user_id            uuid not null references auth.users(id) on delete cascade,
  source             text not null,
  kind               text not null default 'person' check (kind in ('person','list','automation','notification')),
  interruptions_7d   integer not null default 0,
  minutes_7d         integer not null default 0,
  fix                text,
  computed_at        timestamptz not null default now(),
  unique (user_id, source)
);
grant select, insert, update, delete on public.analytics_attention_leaks to authenticated;
grant all on public.analytics_attention_leaks to service_role;
alter table public.analytics_attention_leaks enable row level security;
drop policy if exists analytics_leaks_own on public.analytics_attention_leaks;
create policy analytics_leaks_own on public.analytics_attention_leaks for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 6) Promise SLA (commitment made in a thread -> kept/late/broken) ---------
create table if not exists public.analytics_promises (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  thread_id   uuid,
  subject     text,
  person      text,
  phrase      text,
  due_at      timestamptz,
  state       text not null default 'open' check (state in ('open','kept','late','broken')),
  kept_at     timestamptz,
  late_hours  numeric(10,2),
  created_at  timestamptz not null default now()
);
create index if not exists analytics_promises_idx on public.analytics_promises(user_id, state, due_at);
grant select, insert, update, delete on public.analytics_promises to authenticated;
grant all on public.analytics_promises to service_role;
alter table public.analytics_promises enable row level security;
drop policy if exists analytics_promises_own on public.analytics_promises;
create policy analytics_promises_own on public.analytics_promises for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 7) Founder god-view: platform-wide debt truth ---------------------------
create or replace function public.founder_analytics_overview()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'tenants', (select count(distinct user_id) from public.analytics_debt_daily),
    'currency', 'GBP',
    'total_debt_cost', coalesce((
      select sum(cost_of_delay) from public.analytics_debt_daily
      where day = (select max(day) from public.analytics_debt_daily)
    ), 0),
    'threads_30d', coalesce((
      select count(*) from public.analytics_thread_cost where computed_at > now() - interval '30 days'
    ), 0),
    'platform_keep_rate', coalesce((
      select round(100.0 * count(*) filter (where state = 'kept') / greatest(count(*), 1), 1)
      from public.analytics_promises where created_at > now() - interval '30 days'
    ), 0),
    'worst_tenants', coalesce((
      select jsonb_agg(x) from (
        select user_id::text as tenant, cost_of_delay as debt, waiting_people as waiting
        from public.analytics_debt_daily
        where day = (select max(day) from public.analytics_debt_daily)
        order by cost_of_delay desc limit 10
      ) x
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.founder_analytics_overview() from public;
grant execute on function public.founder_analytics_overview() to service_role;

commit;
