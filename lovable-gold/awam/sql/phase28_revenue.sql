-- ANEXOMAIL — Phase 28: Revenue Engine (Supabase #4)
-- Idempotent + self-healing: purani conflicting table _legacy ho jati hai, phir fresh.
-- 4 money roads: subscriptions · migration service · white-label partners · enterprise SLA.

begin;

-- ---------- self-heal: agar purani shape hai to legacy rename ----------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='revenue_leads')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='revenue_leads' and column_name='reference') then
    execute 'alter table public.revenue_leads rename to revenue_leads_legacy_' || extract(epoch from now())::bigint;
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='revenue_accounts')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='revenue_accounts' and column_name='mrr_gbp') then
    execute 'alter table public.revenue_accounts rename to revenue_accounts_legacy_' || extract(epoch from now())::bigint;
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='revenue_partners')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='revenue_partners' and column_name='live_seats') then
    execute 'alter table public.revenue_partners rename to revenue_partners_legacy_' || extract(epoch from now())::bigint;
  end if;
end $$;

-- ---------- 1. leads (public form writes here) ----------
create table if not exists public.revenue_leads (
  id           uuid primary key default gen_random_uuid(),
  reference    text not null unique,
  kind         text not null check (kind in ('migration','partner','sla','plan')),
  company      text not null,
  email        text not null,
  contact_name text,
  domain       text,
  seats        int,
  quote_gbp    numeric(10,2),
  message      text,
  detail       jsonb not null default '{}'::jsonb,
  stage        text not null default 'new' check (stage in ('new','contacted','quoted','won','lost')),
  source_ip    text,
  user_agent   text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists revenue_leads_created_idx on public.revenue_leads (created_at desc);
create index if not exists revenue_leads_stage_idx   on public.revenue_leads (stage);

-- ---------- 2. paying accounts (recurring + one-off) ----------
create table if not exists public.revenue_accounts (
  id           uuid primary key default gen_random_uuid(),
  company      text not null,
  domain       text,
  plan         text not null default 'basic' check (plan in ('basic','pro','business')),
  seats        int  not null default 1,
  mrr_gbp      numeric(10,2) not null default 0,
  sla_addon    boolean not null default false,
  partner_id   uuid,
  status       text not null default 'active' check (status in ('trial','active','paused','churned')),
  started_at   timestamptz not null default now(),
  created_at   timestamptz not null default now()
);
create index if not exists revenue_accounts_status_idx on public.revenue_accounts (status);

-- ---------- 3. one-off jobs (migration service) ----------
create table if not exists public.revenue_jobs (
  id          uuid primary key default gen_random_uuid(),
  account_id  uuid references public.revenue_accounts(id) on delete set null,
  lead_id     uuid references public.revenue_leads(id) on delete set null,
  kind        text not null default 'migration',
  company     text not null,
  amount_gbp  numeric(10,2) not null default 0,
  deposit_gbp numeric(10,2) not null default 0,
  stage       text not null default 'quoted' check (stage in ('quoted','booked','running','delivered','invoiced','paid','cancelled')),
  cutover_at  timestamptz,
  created_at  timestamptz not null default now()
);
create index if not exists revenue_jobs_stage_idx on public.revenue_jobs (stage);

-- ---------- 4. partners (white-label / reseller) ----------
create table if not exists public.revenue_partners (
  id             uuid primary key default gen_random_uuid(),
  company        text not null,
  email          text not null,
  tier           text not null default 'reseller' check (tier in ('reseller','gold','platinum')),
  commission_rate numeric(5,4) not null default 0.20,
  live_seats     int not null default 0,
  stage          text not null default 'applied' check (stage in ('applied','approved','live','paused','ended')),
  created_at     timestamptz not null default now()
);

-- ---------- 5. founder target ----------
create table if not exists public.revenue_targets (
  id         uuid primary key default gen_random_uuid(),
  month      date not null unique,
  target_gbp numeric(10,2) not null default 500,
  created_at timestamptz not null default now()
);
insert into public.revenue_targets (month, target_gbp)
values (date_trunc('month', now())::date, 500)
on conflict (month) do nothing;

-- ---------- grants (Data API) ----------
grant select, insert, update, delete on public.revenue_leads    to authenticated;
grant select, insert, update, delete on public.revenue_accounts to authenticated;
grant select, insert, update, delete on public.revenue_jobs     to authenticated;
grant select, insert, update, delete on public.revenue_partners to authenticated;
grant select, insert, update, delete on public.revenue_targets  to authenticated;
grant all on public.revenue_leads, public.revenue_accounts, public.revenue_jobs,
             public.revenue_partners, public.revenue_targets to service_role;

alter table public.revenue_leads    enable row level security;
alter table public.revenue_accounts enable row level security;
alter table public.revenue_jobs     enable row level security;
alter table public.revenue_partners enable row level security;
alter table public.revenue_targets  enable row level security;

-- Sab kuch service_role (backend) se chalta hai; koi anon read nahi.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='revenue_leads' and policyname='service manages leads') then
    create policy "service manages leads" on public.revenue_leads for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='revenue_accounts' and policyname='service manages accounts') then
    create policy "service manages accounts" on public.revenue_accounts for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='revenue_jobs' and policyname='service manages jobs') then
    create policy "service manages jobs" on public.revenue_jobs for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='revenue_partners' and policyname='service manages partners') then
    create policy "service manages partners" on public.revenue_partners for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='revenue_targets' and policyname='service manages targets') then
    create policy "service manages targets" on public.revenue_targets for all to service_role using (true) with check (true);
  end if;
end $$;

commit;
