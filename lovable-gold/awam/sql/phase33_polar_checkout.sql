-- ANEXOMAIL — Phase 33: Polar Checkout + Webhook Tables (Supabase #4)
-- Idempotent + self-healing: purani conflicting table _legacy rename, phir fresh.

begin;

-- ---------- self-heal: agar purani shape hai to legacy rename ----------
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='polar_checkout_sessions'
             and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='polar_checkout_sessions' and column_name='product_key')) then
    execute 'alter table public.polar_checkout_sessions rename to polar_checkout_sessions_legacy_' || extract(epoch from now())::bigint;
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='polar_webhook_events'
             and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='polar_webhook_events' and column_name='processed_at')) then
    execute 'alter table public.polar_webhook_events rename to polar_webhook_events_legacy_' || extract(epoch from now())::bigint;
  end if;
end $$;

-- ---------- 1. checkout sessions (created by our backend) ----------
create table if not exists public.polar_checkout_sessions (
  id                 uuid primary key default gen_random_uuid(),
  polar_checkout_id  text not null unique,
  user_id            uuid not null,
  product_id         text not null,
  product_key        text,
  url                text not null,
  status             text not null default 'open' check (status in ('open','confirmed','failed','unknown')),
  payload            jsonb not null default '{}'::jsonb,
  confirmed_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index if not exists polar_checkout_user_idx on public.polar_checkout_sessions (user_id);
create index if not exists polar_checkout_status_idx on public.polar_checkout_sessions (status);

-- ---------- 2. webhook event log (immutable, idempotent) ----------
create table if not exists public.polar_webhook_events (
  id              uuid primary key default gen_random_uuid(),
  polar_event_id  text not null unique,
  type            text not null,
  payload         jsonb not null default '{}'::jsonb,
  processed_at    timestamptz,
  created_at      timestamptz not null default now()
);
create index if not exists polar_webhook_type_idx on public.polar_webhook_events (type);
create index if not exists polar_webhook_created_idx on public.polar_webhook_events (created_at desc);

-- ---------- grants (Data API) ----------
grant select, insert, update on public.polar_checkout_sessions to authenticated;
grant select, insert on public.polar_webhook_events to authenticated;
grant all on public.polar_checkout_sessions, public.polar_webhook_events to service_role;

alter table public.polar_checkout_sessions enable row level security;
alter table public.polar_webhook_events enable row level security;

-- service_role (backend) owns everything; authenticated users only read their own sessions via app code
-- NOTE: RLS for authenticated on checkout sessions is intentionally permissive for insert because backend
-- uses service_role; authenticated direct inserts are blocked by policy below.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='polar_checkout_sessions' and policyname='service manages checkout sessions') then
    create policy "service manages checkout sessions" on public.polar_checkout_sessions for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='polar_checkout_sessions' and policyname='users read own checkout sessions') then
    create policy "users read own checkout sessions" on public.polar_checkout_sessions for select to authenticated using (user_id = auth.uid());
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='polar_webhook_events' and policyname='service manages webhook events') then
    create policy "service manages webhook events" on public.polar_webhook_events for all to service_role using (true) with check (true);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='polar_webhook_events' and policyname='users cannot write webhook events') then
    create policy "users cannot write webhook events" on public.polar_webhook_events for select to authenticated using (false);
  end if;
end $$;

commit;
