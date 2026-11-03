-- ANEXOMAIL — Phase 19: AI Credits & Billing (Supabase #4)
-- Locked rules: idempotent + self-healing, grants pehle phir RLS, user_id = auth.uid().
-- AI billing sirf ai.anexomail.com ka product hai. Workspace plans se koi taalluq nahi.

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  -- ai_wallets
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_wallets')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_wallets' and column_name='user_id') then
    execute format('alter table public.ai_wallets rename to ai_wallets_legacy_%s', ts);
  end if;
  -- ai_credit_events
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_credit_events')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_credit_events' and column_name='user_id') then
    execute format('alter table public.ai_credit_events rename to ai_credit_events_legacy_%s', ts);
  end if;
  -- ai_topup_packs
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_topup_packs')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_topup_packs' and column_name='credits') then
    execute format('alter table public.ai_topup_packs rename to ai_topup_packs_legacy_%s', ts);
  end if;
  -- ai_checkouts
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='ai_checkouts')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='ai_checkouts' and column_name='user_id') then
    execute format('alter table public.ai_checkouts rename to ai_checkouts_legacy_%s', ts);
  end if;
end $$;

create table if not exists public.ai_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text,
  unlimited boolean not null default false,
  balance integer not null default 0,
  monthly_grant integer not null default 0,
  complimentary integer not null default 0,
  currency text not null default 'GBP',
  daily_cap numeric(12,4),
  renews_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_credit_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('grant','spend','topup','refund','expiry','complimentary')),
  credits integer not null default 0,
  cost numeric(12,6) not null default 0,
  currency text not null default 'GBP',
  model text,
  surface text,
  session_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create index if not exists ai_credit_events_user_day_idx
  on public.ai_credit_events (user_id, created_at desc);

create table if not exists public.ai_topup_packs (
  id text primary key,
  credits integer not null,
  bonus integer not null default 0,
  price numeric(12,2) not null,
  currency text not null default 'GBP',
  best_value boolean not null default false,
  active boolean not null default true,
  sort_order integer not null default 0
);

create table if not exists public.ai_checkouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pack_id text not null,
  credits integer not null,
  charged numeric(12,2) not null default 0,
  currency text not null default 'GBP',
  sandbox boolean not null default false,
  state text not null default 'granted' check (state in ('pending','granted','failed','refunded')),
  created_at timestamptz not null default now()
);

-- Locked AI plan tiers + top-ups (ai.anexomail.com only)
insert into public.ai_topup_packs (id, credits, bonus, price, currency, best_value, sort_order) values
  ('ai_500',   500,   0,  135.00, 'GBP', false, 1),
  ('ai_1500',  1500,  0,  300.00, 'GBP', false, 2),
  ('ai_6000',  6000,  0, 1000.00, 'GBP', true,  3),
  ('ai_10000', 10000, 0, 2000.00, 'GBP', false, 4)
on conflict (id) do update
  set credits = excluded.credits,
      price = excluded.price,
      best_value = excluded.best_value,
      sort_order = excluded.sort_order,
      active = true;

grant select, insert, update, delete on public.ai_wallets to authenticated;
grant select, insert, update, delete on public.ai_credit_events to authenticated;
grant select on public.ai_topup_packs to authenticated;
grant select, insert, update, delete on public.ai_checkouts to authenticated;
grant all on public.ai_wallets to service_role;
grant all on public.ai_credit_events to service_role;
grant all on public.ai_topup_packs to service_role;
grant all on public.ai_checkouts to service_role;

alter table public.ai_wallets enable row level security;
alter table public.ai_credit_events enable row level security;
alter table public.ai_topup_packs enable row level security;
alter table public.ai_checkouts enable row level security;

drop policy if exists own_rows on public.ai_wallets;
create policy own_rows on public.ai_wallets for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists own_rows on public.ai_credit_events;
create policy own_rows on public.ai_credit_events for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists own_rows on public.ai_checkouts;
create policy own_rows on public.ai_checkouts for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists read_packs on public.ai_topup_packs;
create policy read_packs on public.ai_topup_packs for select to authenticated using (active);
