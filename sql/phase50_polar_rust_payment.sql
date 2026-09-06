-- ============================================================================
-- ANEXOMAIL — Phase 50: POLAR RUST PAYMENT ENGINE (Supabase #4)
--
-- Locked design (5 Sep 2026):
--   Webhook  = signal only (verify -> INSERT -> instant 200). Authority NAHI.
--   Postgres = canonical truth. State sync AFTER INSERT trigger se background mein.
--   Grace    = 3 din warning, service block KABHI nahi.
--   Emails   = outbox rows (receipt + welcome), sender Postfix worker.
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
              where table_schema='public' and table_name='polar_webhook_inbox')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='polar_webhook_inbox' and column_name='event_id') then
    execute format('alter table public.polar_webhook_inbox rename to polar_webhook_inbox_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables
              where table_schema='public' and table_name='polar_subscriptions')
     and not exists (select 1 from information_schema.columns
              where table_schema='public' and table_name='polar_subscriptions' and column_name='grace_until') then
    execute format('alter table public.polar_subscriptions rename to polar_subscriptions_legacy_%s', ts);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 1) WEBHOOK INBOX — Rust engine sirf yahan likhta hai (raw, immutable)
-- ---------------------------------------------------------------------------
create table if not exists public.polar_webhook_inbox (
  id           uuid primary key default gen_random_uuid(),
  event_id     text not null unique,
  event_type   text not null,
  payload      jsonb not null default '{}'::jsonb,
  processed    boolean not null default false,
  process_error text,
  received_at  timestamptz not null default now(),
  processed_at timestamptz
);
create index if not exists polar_inbox_unprocessed_idx
  on public.polar_webhook_inbox (received_at) where not processed;

-- ---------------------------------------------------------------------------
-- 2) CHECKOUT LOG — kis card se kaun checkout par gaya (return_to samet)
-- ---------------------------------------------------------------------------
create table if not exists public.polar_checkout_log (
  checkout_id  text primary key,
  product_key  text not null,
  product_id   text not null,
  user_id      uuid,
  email        text,
  return_to    text not null default '/app/billing',
  payload      jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);
create index if not exists polar_checkout_log_user_idx on public.polar_checkout_log (user_id);
create index if not exists polar_checkout_log_email_idx on public.polar_checkout_log (lower(email));

-- ---------------------------------------------------------------------------
-- 3) SUBSCRIPTIONS — canonical billing state (grace 3 din)
-- ---------------------------------------------------------------------------
create table if not exists public.polar_subscriptions (
  id                  uuid primary key default gen_random_uuid(),
  polar_subscription_id text unique,
  polar_customer_id   text,
  user_id             uuid,
  email               text,
  product_key         text,
  product_id          text,
  status              text not null default 'active'
                        check (status in ('active','past_due','grace','canceled','revoked')),
  current_period_end  timestamptz,
  grace_until         timestamptz,
  seats               int not null default 1,
  last_event_id       text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists polar_subs_user_idx on public.polar_subscriptions (user_id);
create index if not exists polar_subs_email_idx on public.polar_subscriptions (lower(email));

-- ---------------------------------------------------------------------------
-- 4) MAIL OUTBOX — receipt + welcome email (Postfix worker bhejta hai)
-- ---------------------------------------------------------------------------
create table if not exists public.polar_mail_outbox (
  id          uuid primary key default gen_random_uuid(),
  kind        text not null check (kind in ('receipt','welcome','grace_warning')),
  to_email    text not null,
  user_id     uuid,
  subject     text not null,
  data        jsonb not null default '{}'::jsonb,
  sent_at     timestamptz,
  attempts    int not null default 0,
  last_error  text,
  created_at  timestamptz not null default now(),
  unique (kind, to_email, subject)
);
create index if not exists polar_outbox_pending_idx
  on public.polar_mail_outbox (created_at) where sent_at is null;

-- ---------------------------------------------------------------------------
-- 5) PROCESSOR — AFTER INSERT trigger. Polar ka wait khatam.
-- ---------------------------------------------------------------------------
create or replace function public.polar_inbox_apply()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  d           jsonb := coalesce(new.payload -> 'data', '{}'::jsonb);
  meta        jsonb := coalesce(d -> 'metadata', '{}'::jsonb);
  sub_id      text  := d ->> 'id';
  cust_id     text  := coalesce(d ->> 'customer_id', d #>> '{customer,id}');
  mail        text  := lower(coalesce(d #>> '{customer,email}', d ->> 'customer_email', meta ->> 'email'));
  ext_user    text  := coalesce(d ->> 'external_customer_id', d #>> '{customer,external_id}', meta ->> 'user_id');
  uid         uuid;
  pkey        text  := meta ->> 'product_key';
  pid         text  := coalesce(d ->> 'product_id', d #>> '{product,id}');
  period_end  timestamptz := nullif(d ->> 'current_period_end','')::timestamptz;
  new_status  text;
begin
  begin
    if ext_user ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
      uid := ext_user::uuid;
    end if;
    if uid is null and mail is not null then
      select id into uid from auth.users where lower(email) = mail limit 1;
    end if;

    new_status := case
      when new.event_type in ('subscription.active','subscription.created','subscription.uncanceled','order.paid') then 'active'
      when new.event_type = 'subscription.past_due' then 'past_due'
      when new.event_type = 'subscription.canceled' then 'canceled'
      when new.event_type = 'subscription.revoked' then 'revoked'
      else null
    end;

    if new_status is not null and (sub_id is not null or mail is not null) then
      insert into public.polar_subscriptions as s
        (polar_subscription_id, polar_customer_id, user_id, email, product_key, product_id,
         status, current_period_end, grace_until, last_event_id)
      values
        (sub_id, cust_id, uid, mail, pkey, pid, new_status, period_end,
         case when new_status = 'past_due' then now() + interval '3 days' else null end,
         new.event_id)
      on conflict (polar_subscription_id) do update
        set polar_customer_id  = coalesce(excluded.polar_customer_id, s.polar_customer_id),
            user_id            = coalesce(excluded.user_id, s.user_id),
            email              = coalesce(excluded.email, s.email),
            product_key        = coalesce(excluded.product_key, s.product_key),
            product_id         = coalesce(excluded.product_id, s.product_id),
            status             = excluded.status,
            current_period_end = coalesce(excluded.current_period_end, s.current_period_end),
            grace_until        = case
                                   when excluded.status = 'past_due'
                                     then coalesce(s.grace_until, now() + interval '3 days')
                                   else null
                                 end,
            last_event_id      = excluded.last_event_id,
            updated_at         = now();
    end if;

    -- receipt (regular email par) + welcome (pehli active subscription par)
    if new.event_type = 'order.paid' and mail is not null then
      insert into public.polar_mail_outbox (kind, to_email, user_id, subject, data)
      values ('receipt', mail, uid, 'Your ANEXOMAIL payment receipt',
              jsonb_build_object('product_key', pkey, 'event_id', new.event_id,
                                 'amount', d ->> 'total_amount', 'currency', d ->> 'currency'))
      on conflict do nothing;
    end if;

    if new.event_type in ('subscription.active','subscription.created') and mail is not null then
      insert into public.polar_mail_outbox (kind, to_email, user_id, subject, data)
      values ('welcome', mail, uid, 'Welcome to ANEXOMAIL Workspace',
              jsonb_build_object('product_key', pkey, 'event_id', new.event_id))
      on conflict do nothing;
    end if;

    if new_status = 'past_due' and mail is not null then
      insert into public.polar_mail_outbox (kind, to_email, user_id, subject, data)
      values ('grace_warning', mail, uid, 'Action needed: payment due (3 day grace)',
              jsonb_build_object('product_key', pkey, 'event_id', new.event_id))
      on conflict do nothing;
    end if;

    update public.polar_webhook_inbox
       set processed = true, processed_at = now(), process_error = null
     where id = new.id;
  exception when others then
    -- FAIL-SAFE: event kabhi kho nahi sakta; error row par likha jata hai,
    -- reconcile isay dobara process kar sakta hai. Polar ko farq nahi padta.
    update public.polar_webhook_inbox
       set processed = false, process_error = sqlerrm
     where id = new.id;
  end;
  return null;
end $$;

drop trigger if exists polar_inbox_apply_trg on public.polar_webhook_inbox;
create trigger polar_inbox_apply_trg
  after insert on public.polar_webhook_inbox
  for each row execute function public.polar_inbox_apply();

-- ---------------------------------------------------------------------------
-- 6) BILLING STATE — in-app panel ke liye sach (block kabhi nahi)
-- ---------------------------------------------------------------------------
create or replace function public.polar_billing_state(_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    (select jsonb_build_object(
       'plan',               s.product_key,
       'status',             s.status,
       'seats',              s.seats,
       'current_period_end', s.current_period_end,
       'grace_until',        s.grace_until,
       'grace_days_left',    greatest(0, ceil(extract(epoch from (s.grace_until - now())) / 86400))::int,
       'payment_due',        s.status in ('past_due','grace'),
       'service_blocked',    false
     )
     from public.polar_subscriptions s
     where s.user_id = _user
     order by s.updated_at desc
     limit 1),
    jsonb_build_object('plan', null, 'status', 'none', 'payment_due', false, 'service_blocked', false)
  )
$$;

-- ---------------------------------------------------------------------------
-- 7) GRANTS + RLS (locked order: grants -> RLS -> policies)
-- ---------------------------------------------------------------------------
grant all on public.polar_webhook_inbox, public.polar_checkout_log,
             public.polar_subscriptions, public.polar_mail_outbox to service_role;
grant select on public.polar_subscriptions, public.polar_checkout_log to authenticated;
grant execute on function public.polar_billing_state(uuid) to authenticated, service_role;

alter table public.polar_webhook_inbox   enable row level security;
alter table public.polar_checkout_log    enable row level security;
alter table public.polar_subscriptions   enable row level security;
alter table public.polar_mail_outbox     enable row level security;

drop policy if exists service_all on public.polar_webhook_inbox;
create policy service_all on public.polar_webhook_inbox for all to service_role using (true) with check (true);

drop policy if exists service_all on public.polar_mail_outbox;
create policy service_all on public.polar_mail_outbox for all to service_role using (true) with check (true);

drop policy if exists own_rows on public.polar_subscriptions;
create policy own_rows on public.polar_subscriptions for select to authenticated using (user_id = auth.uid());

drop policy if exists own_rows on public.polar_checkout_log;
create policy own_rows on public.polar_checkout_log for select to authenticated using (user_id = auth.uid());

commit;
