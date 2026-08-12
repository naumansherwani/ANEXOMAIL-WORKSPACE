-- ANEXOMAIL — Phase 34: Polar billing truth + founder reply clock (Supabase #4)
-- No ticket system. This is a conversation reply queue tied to the paid plan.
-- Basic 72h · Pro 48h · Business 24h. Priority Support remains 2 business days.

begin;

do $$
declare ts text := to_char(now(), 'YYYYMMDDHH24MISS');
begin
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='billing_event_receipts')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='billing_event_receipts' and column_name='polar_event_id') then
    execute format('alter table public.billing_event_receipts rename to billing_event_receipts_legacy_%s', ts);
  end if;
  if exists (select 1 from information_schema.tables where table_schema='public' and table_name='founder_reply_queue')
     and not exists (select 1 from information_schema.columns where table_schema='public' and table_name='founder_reply_queue' and column_name='respond_by') then
    execute format('alter table public.founder_reply_queue rename to founder_reply_queue_legacy_%s', ts);
  end if;
end $$;

-- Existing Phase 21 subscription becomes Polar-authoritative without replacing it.
alter table public.workspace_subscriptions add column if not exists polar_customer_id text;
alter table public.workspace_subscriptions add column if not exists polar_subscription_id text;
alter table public.workspace_subscriptions add column if not exists customer_email text;
alter table public.workspace_subscriptions add column if not exists response_due_hours integer;
alter table public.workspace_subscriptions add column if not exists provider_payload jsonb not null default '{}'::jsonb;
create unique index if not exists workspace_subscriptions_polar_subscription_idx
  on public.workspace_subscriptions (polar_subscription_id)
  where polar_subscription_id is not null;

-- NO REFUNDS: purana Phase 21 constraint self-heal karke sirf paid/open/void rakho.
alter table public.workspace_invoices drop constraint if exists workspace_invoices_state_check;
alter table public.workspace_invoices
  add constraint workspace_invoices_state_check check (state in ('paid','open','void'));

-- Immutable billing event receipt: webhook truth, amount, plan and customer.
create table if not exists public.billing_event_receipts (
  id uuid primary key default gen_random_uuid(),
  polar_event_id text not null unique,
  polar_order_id text,
  user_id uuid references auth.users(id) on delete set null,
  customer_email text,
  event_type text not null,
  plan text check (plan is null or plan in ('basic','pro','business')),
  amount_gbp numeric(12,2),
  currency text not null default 'GBP',
  provider_email_state text not null default 'provider_managed'
    check (provider_email_state in ('provider_managed','sent','failed')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists billing_event_receipts_user_idx
  on public.billing_event_receipts (user_id, created_at desc);

-- Not a ticket desk: one row is one real email conversation awaiting founder reply.
create table if not exists public.founder_reply_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  thread_id uuid,
  customer_email text not null,
  subject text not null default '',
  plan text not null default 'basic' check (plan in ('basic','pro','business')),
  response_due_hours integer not null check (response_due_hours in (24,48,72)),
  received_at timestamptz not null default now(),
  respond_by timestamptz not null,
  state text not null default 'awaiting_reply'
    check (state in ('awaiting_reply','replied','closed')),
  replied_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists founder_reply_queue_due_idx
  on public.founder_reply_queue (state, respond_by);

-- Delivery hook/support ingestion is function ko call kare. Plan aur deadline DB khud nikalti hai.
create or replace function public.enqueue_founder_reply(
  p_user_id uuid,
  p_customer_email text,
  p_subject text,
  p_thread_id uuid default null,
  p_received_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_plan text;
  v_hours integer;
  v_id uuid;
begin
  select coalesce(plan, 'basic') into v_plan
  from public.workspace_subscriptions
  where user_id = p_user_id and state in ('active','trialing')
  limit 1;

  v_plan := coalesce(v_plan, 'basic');
  v_hours := case v_plan when 'business' then 24 when 'pro' then 48 else 72 end;

  insert into public.founder_reply_queue (
    user_id, thread_id, customer_email, subject, plan,
    response_due_hours, received_at, respond_by
  ) values (
    p_user_id, p_thread_id, p_customer_email, coalesce(p_subject, ''), v_plan,
    v_hours, p_received_at, p_received_at + make_interval(hours => v_hours)
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) from public, anon, authenticated;
grant execute on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) to service_role;

grant select on public.billing_event_receipts to authenticated;
grant select, insert, update on public.founder_reply_queue to authenticated;
grant all on public.billing_event_receipts, public.founder_reply_queue to service_role;

alter table public.billing_event_receipts enable row level security;
alter table public.founder_reply_queue enable row level security;

drop policy if exists users_read_own_billing_receipts on public.billing_event_receipts;
create policy users_read_own_billing_receipts on public.billing_event_receipts
  for select to authenticated using (user_id = auth.uid());

drop policy if exists founder_reads_billing_receipts on public.billing_event_receipts;
create policy founder_reads_billing_receipts on public.billing_event_receipts
  for select to authenticated using (
    exists (select 1 from public.founder_accounts f where f.user_id = auth.uid())
  );

drop policy if exists founder_manages_reply_queue on public.founder_reply_queue;
create policy founder_manages_reply_queue on public.founder_reply_queue
  for all to authenticated
  using (exists (select 1 from public.founder_accounts f where f.user_id = auth.uid()))
  with check (exists (select 1 from public.founder_accounts f where f.user_id = auth.uid()));

-- Billing receipts are append-only.
create or replace function public.block_billing_receipt_mutation()
returns trigger language plpgsql as $$
begin
  raise exception 'billing_event_receipts is append-only';
end;
$$;
drop trigger if exists billing_receipts_immutable on public.billing_event_receipts;
create trigger billing_receipts_immutable
before update or delete on public.billing_event_receipts
for each row execute function public.block_billing_receipt_mutation();

commit;