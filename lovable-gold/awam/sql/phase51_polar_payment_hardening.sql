-- ============================================================================
-- ANEXOMAIL — Phase 51: POLAR PAYMENT HARDENING (Supabase #4)
--
-- Phase 50 ka trigger (polar_inbox_apply) ZINDA rehta hai — fast path wahi hai.
-- Yeh phase sirf sach aur safety add karta hai:
--   1) polar_signature_rejects  — 401 wale events ka raw body + headers (evidence)
--   2) polar_reconcile_log      — Polar API vs internal state (ok/missing/diverged)
--   3) polar_payment_alerts     — engine watchdog (queue stalled / dead letter)
--   4) polar_payment_pulse()    — ek call mein poora payment sach (founder deck)
--
-- Idempotent + self-healing. Run: Supabase #4 -> SQL Editor.
-- ============================================================================

begin;

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- self-heal: purani conflicting shape -> _legacy rename
-- ---------------------------------------------------------------------------
do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='polar_signature_rejects')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='polar_signature_rejects' and column_name='raw_body') then
    execute format('alter table public.polar_signature_rejects rename to polar_signature_rejects_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='polar_reconcile_log')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='polar_reconcile_log' and column_name='verdict') then
    execute format('alter table public.polar_reconcile_log rename to polar_reconcile_log_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='polar_payment_alerts')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='polar_payment_alerts' and column_name='bucket') then
    execute format('alter table public.polar_payment_alerts rename to polar_payment_alerts_legacy_%s', ts);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) SIGNATURE REJECTS — 401 phir bhi jaata hai, magar data khota nahi
-- ---------------------------------------------------------------------------
create table if not exists public.polar_signature_rejects (
  id          uuid primary key default gen_random_uuid(),
  reason      text not null,
  raw_body    text,
  headers     jsonb not null default '{}'::jsonb,
  reviewed    boolean not null default false,
  created_at  timestamptz not null default now()
);
create index if not exists polar_rejects_recent_idx
  on public.polar_signature_rejects (created_at desc);

-- ---------------------------------------------------------------------------
-- 2) RECONCILE LOG — har 15 min Rust engine likhti hai
-- ---------------------------------------------------------------------------
create table if not exists public.polar_reconcile_log (
  id            uuid primary key default gen_random_uuid(),
  kind          text not null default 'subscription'
                  check (kind in ('subscription','order')),
  polar_id      text not null,
  verdict       text not null check (verdict in ('ok','missing','diverged','unknown')),
  polar_status  text,
  local_status  text,
  payload       jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);
create index if not exists polar_reconcile_recent_idx
  on public.polar_reconcile_log (created_at desc);
create index if not exists polar_reconcile_gap_idx
  on public.polar_reconcile_log (created_at desc) where verdict in ('missing','diverged');

-- ---------------------------------------------------------------------------
-- 3) PAYMENT ALERTS — watchdog (queue stalled, dead letter). Hourly bucket
--    se ek hi alert, spam nahi.
-- ---------------------------------------------------------------------------
create table if not exists public.polar_payment_alerts (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null check (kind in ('queue_stalled','queue_depth_high','dead_letter','reconcile_gap')),
  bucket      timestamptz not null,
  to_email    text not null default 'hello@anexomail.com',
  detail      jsonb not null default '{}'::jsonb,
  sent_at     timestamptz,
  created_at  timestamptz not null default now(),
  unique (kind, bucket)
);
create index if not exists polar_alerts_pending_idx
  on public.polar_payment_alerts (created_at) where sent_at is null;

-- ---------------------------------------------------------------------------
-- 4) PAYMENT PULSE — ek call, poora sach (Founder view / status page)
-- ---------------------------------------------------------------------------
create or replace function public.polar_payment_pulse()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'inbox_total',        (select count(*) from public.polar_webhook_inbox),
    'inbox_pending',      (select count(*) from public.polar_webhook_inbox where not processed),
    'inbox_failed',       (select count(*) from public.polar_webhook_inbox where process_error is not null),
    'last_event_at',      (select max(received_at) from public.polar_webhook_inbox),
    'active_subs',        (select count(*) from public.polar_subscriptions where status = 'active'),
    'past_due_subs',      (select count(*) from public.polar_subscriptions where status in ('past_due','grace')),
    'rejects_24h',        (select count(*) from public.polar_signature_rejects where created_at > now() - interval '24 hours'),
    'reconcile_last_at',  (select max(created_at) from public.polar_reconcile_log),
    'reconcile_gap_24h',  (select count(*) from public.polar_reconcile_log
                            where verdict in ('missing','diverged') and created_at > now() - interval '24 hours'),
    'alerts_open',        (select count(*) from public.polar_payment_alerts where sent_at is null),
    'mail_outbox_pending',(select count(*) from public.polar_mail_outbox where sent_at is null)
  )
$$;

-- ---------------------------------------------------------------------------
-- 5) GRANTS + RLS (locked order: grants -> RLS -> policies)
-- ---------------------------------------------------------------------------
grant all on public.polar_signature_rejects, public.polar_reconcile_log,
             public.polar_payment_alerts to service_role;
grant execute on function public.polar_payment_pulse() to service_role, authenticated;

alter table public.polar_signature_rejects enable row level security;
alter table public.polar_reconcile_log     enable row level security;
alter table public.polar_payment_alerts    enable row level security;

drop policy if exists service_all on public.polar_signature_rejects;
create policy service_all on public.polar_signature_rejects for all to service_role using (true) with check (true);

drop policy if exists service_all on public.polar_reconcile_log;
create policy service_all on public.polar_reconcile_log for all to service_role using (true) with check (true);

drop policy if exists service_all on public.polar_payment_alerts;
create policy service_all on public.polar_payment_alerts for all to service_role using (true) with check (true);

commit;
