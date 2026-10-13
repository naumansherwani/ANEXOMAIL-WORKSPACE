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
update public.workspace_subscriptions
set response_due_hours = case plan when 'business' then 24 when 'pro' then 48 else 72 end
where response_due_hours is null;
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
alter table public.founder_reply_queue add column if not exists message_id uuid;
create index if not exists founder_reply_queue_due_idx
  on public.founder_reply_queue (state, respond_by);
create unique index if not exists founder_reply_queue_message_idx
  on public.founder_reply_queue (message_id)
  where message_id is not null;

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
  v_user_id uuid;
  v_plan text;
  v_hours integer;
  v_id uuid;
begin
  select user_id, coalesce(plan, 'basic') into v_user_id, v_plan
  from public.workspace_subscriptions
  where state in ('active','trialing')
    and (lower(customer_email) = lower(p_customer_email) or user_id = p_user_id)
  order by (lower(customer_email) = lower(p_customer_email)) desc
  limit 1;

  v_user_id := coalesce(v_user_id, p_user_id);
  v_plan := coalesce(v_plan, 'basic');
  v_hours := case v_plan when 'business' then 24 when 'pro' then 48 else 72 end;

  insert into public.founder_reply_queue (
    user_id, thread_id, customer_email, subject, plan,
    response_due_hours, received_at, respond_by
  ) values (
    v_user_id, p_thread_id, p_customer_email, coalesce(p_subject, ''), v_plan,
    v_hours, p_received_at, p_received_at + make_interval(hours => v_hours)
  ) returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) from public, anon, authenticated;
grant execute on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) to service_role;

-- Postfix delivery hook mail_messages mein insert karta hai. Support inbox ka har
-- inbound message automatically founder queue mein aata hai. to_jsonb schema
-- variations ko tolerate karta hai; unknown shape par trigger mail delivery ko nahi rokta.
create or replace function public.queue_inbound_support_reply()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  j jsonb := to_jsonb(new);
  tj jsonb := '{}'::jsonb;
  v_thread_id uuid;
  v_message_id uuid;
  v_customer_email text;
  v_subject text;
  v_received_at timestamptz;
  v_recipient_text text;
  v_queue_id uuid;
begin
  if coalesce(j->>'direction', 'in') not in ('in','inbound') then return new; end if;

  begin v_thread_id := nullif(j->>'thread_id','')::uuid; exception when others then v_thread_id := null; end;
  begin v_message_id := nullif(j->>'id','')::uuid; exception when others then v_message_id := null; end;
  if v_thread_id is not null then
    select to_jsonb(t) into tj from public.mail_threads t where t.id = v_thread_id;
    tj := coalesce(tj, '{}'::jsonb);
  end if;

  v_recipient_text := lower(concat_ws(' ',
    j->>'to', j->>'to_address', j->>'to_addresses', j->>'recipient', j->>'recipient_address',
    tj->>'account_address', tj->>'to_address', tj->>'recipient_address'
  ));
  if position('hello@anexomail.com' in v_recipient_text) = 0 then return new; end if;

  v_customer_email := coalesce(nullif(j->>'from_address',''), nullif(j->>'sender',''), nullif(tj->>'from_address',''));
  if v_customer_email is null then return new; end if;
  v_subject := coalesce(nullif(j->>'subject',''), nullif(tj->>'subject',''), 'Support conversation');
  begin
    v_received_at := coalesce(nullif(j->>'sent_at','')::timestamptz, nullif(j->>'received_at','')::timestamptz, now());
  exception when others then
    v_received_at := now();
  end;

  if v_message_id is not null and exists (select 1 from public.founder_reply_queue where message_id = v_message_id) then
    return new;
  end if;

  v_queue_id := public.enqueue_founder_reply(null, v_customer_email, v_subject, v_thread_id, v_received_at);
  if v_message_id is not null then
    update public.founder_reply_queue set message_id = v_message_id where id = v_queue_id;
  end if;
  return new;
exception when others then
  raise warning 'queue_inbound_support_reply skipped: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists mail_messages_support_reply_clock on public.mail_messages;
create trigger mail_messages_support_reply_clock
after insert on public.mail_messages
for each row execute function public.queue_inbound_support_reply();

-- Founder ka outbound reply isi thread par aate hi clock automatically close.
create or replace function public.close_founder_reply_clock()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  j jsonb := to_jsonb(new);
  v_thread_id uuid;
  v_sent_at timestamptz;
begin
  if coalesce(j->>'direction', '') not in ('out','outbound') then return new; end if;
  begin v_thread_id := nullif(j->>'thread_id','')::uuid; exception when others then v_thread_id := null; end;
  if v_thread_id is null then return new; end if;
  begin v_sent_at := coalesce(nullif(j->>'sent_at','')::timestamptz, now()); exception when others then v_sent_at := now(); end;

  update public.founder_reply_queue
  set state = 'replied', replied_at = v_sent_at
  where thread_id = v_thread_id and state = 'awaiting_reply';
  return new;
exception when others then
  raise warning 'close_founder_reply_clock skipped: %', sqlerrm;
  return new;
end;
$$;

drop trigger if exists mail_messages_close_reply_clock on public.mail_messages;
create trigger mail_messages_close_reply_clock
after insert on public.mail_messages
for each row execute function public.close_founder_reply_clock();

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