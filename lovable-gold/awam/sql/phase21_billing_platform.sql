-- ANEXOMAIL — Phase 21: Billing platform (Supabase #4)
-- Workspace plans only: Basic £23 · Pro £46 · Business £97 per user/month;
-- Business Pro £2,850 per company/month.
-- AI credits alag product hai (phase19_ai_billing.sql). Yahan AI ka koi zikr nahi.

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='workspace_subscriptions')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='workspace_subscriptions' and column_name='user_id') then
    execute format('alter table public.workspace_subscriptions rename to workspace_subscriptions_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='workspace_invoices')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='workspace_invoices' and column_name='user_id') then
    execute format('alter table public.workspace_invoices rename to workspace_invoices_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='billing_tax_profiles')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='billing_tax_profiles' and column_name='user_id') then
    execute format('alter table public.billing_tax_profiles rename to billing_tax_profiles_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='billing_payment_methods')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='billing_payment_methods' and column_name='user_id') then
    execute format('alter table public.billing_payment_methods rename to billing_payment_methods_legacy_%s', ts);
  end if;
end $$;

create table if not exists public.workspace_plans (
  id text primary key,
  label text not null,
  price numeric(12,2) not null,
  currency text not null default 'GBP',
  mailboxes_included integer not null default 1,
  storage_per_mailbox_gb integer not null default 5,
  sort_order integer not null default 0,
  active boolean not null default true
);

insert into public.workspace_plans (id, label, price, mailboxes_included, storage_per_mailbox_gb, sort_order) values
  ('basic',        'Basic',        23.00,   3,  5,   1),
  ('pro',          'Pro',          46.00,   5,  10,  2),
  ('business',     'Business',     97.00,  30,  25,  3),
  ('business_pro', 'Business Pro', 2850.00, 1, 1000, 4)
on conflict (id) do update
  set label = excluded.label,
      price = excluded.price,
      mailboxes_included = excluded.mailboxes_included,
      storage_per_mailbox_gb = excluded.storage_per_mailbox_gb,
      sort_order = excluded.sort_order,
      active = true;

create table if not exists public.workspace_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  org_id uuid,
  plan text references public.workspace_plans(id),
  state text not null default 'none' check (state in ('trialing','active','past_due','cancelled','none')),
  seats integer not null default 1,
  seats_used integer not null default 1,
  price_per_seat numeric(12,2) not null default 0,
  currency text not null default 'GBP',
  interval text not null default 'month' check (interval in ('month','year')),
  renews_at timestamptz,
  cancel_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id)
);

create table if not exists public.workspace_invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  number text not null,
  state text not null default 'open' check (state in ('paid','open','void','refunded')),
  subtotal numeric(12,2) not null default 0,
  tax numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  currency text not null default 'GBP',
  period_start timestamptz,
  period_end timestamptz,
  issued_at timestamptz not null default now(),
  paid_at timestamptz,
  pdf_url text,
  unique (user_id, number)
);
create index if not exists workspace_invoices_user_idx
  on public.workspace_invoices (user_id, issued_at desc);

create table if not exists public.billing_tax_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  legal_name text,
  country text,
  vat_number text,
  vat_validated boolean not null default false,
  reverse_charge boolean not null default false,
  address text,
  updated_at timestamptz not null default now()
);

create table if not exists public.billing_payment_methods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  brand text not null default 'card',
  last4 text not null,
  exp text not null,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

grant select on public.workspace_plans to authenticated;
grant select, insert, update, delete on public.workspace_subscriptions to authenticated;
grant select on public.workspace_invoices to authenticated;
grant select, insert, update, delete on public.billing_tax_profiles to authenticated;
grant select, insert, update, delete on public.billing_payment_methods to authenticated;
grant all on public.workspace_plans to service_role;
grant all on public.workspace_subscriptions to service_role;
grant all on public.workspace_invoices to service_role;
grant all on public.billing_tax_profiles to service_role;
grant all on public.billing_payment_methods to service_role;

alter table public.workspace_plans enable row level security;
alter table public.workspace_subscriptions enable row level security;
alter table public.workspace_invoices enable row level security;
alter table public.billing_tax_profiles enable row level security;
alter table public.billing_payment_methods enable row level security;

drop policy if exists read_plans on public.workspace_plans;
create policy read_plans on public.workspace_plans for select to authenticated using (active);

drop policy if exists own_rows on public.workspace_subscriptions;
create policy own_rows on public.workspace_subscriptions for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists own_rows on public.workspace_invoices;
create policy own_rows on public.workspace_invoices for select to authenticated
  using (user_id = auth.uid());

drop policy if exists own_rows on public.billing_tax_profiles;
create policy own_rows on public.billing_tax_profiles for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists own_rows on public.billing_payment_methods;
create policy own_rows on public.billing_payment_methods for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
