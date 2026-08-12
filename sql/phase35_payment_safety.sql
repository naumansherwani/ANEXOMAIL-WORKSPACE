-- ============================================================================
-- ANEXOMAIL — Phase 35: PAYMENT SAFETY NET (Supabase #4)
-- Promise: ek bhi payment kabhi zaya nahi hogi.
--   1) har webhook hit RAW capture hota hai (signature fail ho to bhi)
--   2) verified event ek hi dafa process hota hai (idempotent)
--   3) processing fail ho to Polar ko 200 milta hai + humara apna retry queue
--      exponential backoff se dobara chalata hai
--   4) 3 fail ke baad founder alert
--   5) reconciliation view: paid order jiska invoice/subscription missing hai
-- Idempotent + self-healing. Supabase SQL editor mein run karo.
-- ============================================================================

-- ---------- 1) retry state on polar_webhook_events ----------
alter table public.polar_webhook_events
  add column if not exists state text not null default 'pending',
  add column if not exists attempts int not null default 0,
  add column if not exists last_error text,
  add column if not exists next_retry_at timestamptz,
  add column if not exists first_seen_at timestamptz not null default now();

update public.polar_webhook_events
  set state = 'processed'
  where processed_at is not null and state <> 'processed';

create index if not exists polar_webhook_events_retry_idx
  on public.polar_webhook_events (state, next_retry_at);

-- ---------- 2) RAW capture — kuch bhi discard nahi ----------
create table if not exists public.polar_webhook_raw (
  id uuid primary key default gen_random_uuid(),
  polar_event_id text,
  event_type text,
  verified boolean not null default false,
  reject_reason text,
  headers jsonb,
  body jsonb,
  received_at timestamptz not null default now()
);
create index if not exists polar_webhook_raw_recent_idx
  on public.polar_webhook_raw (received_at desc);
create index if not exists polar_webhook_raw_unverified_idx
  on public.polar_webhook_raw (verified, received_at desc);

-- ---------- 3) founder alerts ----------
create table if not exists public.payment_alerts (
  id uuid primary key default gen_random_uuid(),
  severity text not null default 'critical',
  kind text not null,
  polar_event_id text,
  message text not null,
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists payment_alerts_open_idx
  on public.payment_alerts (resolved_at, created_at desc);

-- ---------- 4) capture fn ----------
create or replace function public.webhook_capture_raw(
  p_event_id text,
  p_type text,
  p_body jsonb,
  p_verified boolean,
  p_reason text default null,
  p_headers jsonb default '{}'::jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare v_id uuid;
begin
  insert into public.polar_webhook_raw
    (polar_event_id, event_type, verified, reject_reason, headers, body)
  values (p_event_id, p_type, p_verified, p_reason, p_headers, p_body)
  returning id into v_id;

  if not p_verified then
    insert into public.payment_alerts (severity, kind, polar_event_id, message)
    values ('critical', 'webhook_rejected', p_event_id,
            coalesce(p_reason, 'unverified webhook') || ' — raw payload saved, manual replay possible');
  end if;
  return v_id;
end;
$$;

-- ---------- 5) mark processed / failed with backoff ----------
create or replace function public.webhook_mark_processed(p_event_id text)
returns void
language sql
security definer
set search_path = public
as $$
  update public.polar_webhook_events
     set processed_at = now(), state = 'processed', last_error = null, next_retry_at = null
   where polar_event_id = p_event_id;
$$;

create or replace function public.webhook_mark_failed(p_event_id text, p_error text)
returns table (attempts int, next_retry_at timestamptz, state text)
language plpgsql
security definer
set search_path = public
as $$
declare v_attempts int;
begin
  update public.polar_webhook_events e
     set attempts = e.attempts + 1,
         last_error = p_error,
         state = case when e.attempts + 1 >= 8 then 'dead' else 'retry' end,
         -- backoff: 1m, 2m, 4m, 8m ... capped at 6h
         next_retry_at = now() + least(interval '6 hours',
                                       (interval '1 minute') * power(2, least(e.attempts, 9)))
   where e.polar_event_id = p_event_id
  returning e.attempts into v_attempts;

  if coalesce(v_attempts, 0) >= 3 then
    insert into public.payment_alerts (severity, kind, polar_event_id, message)
    values ('critical', 'webhook_processing_failed', p_event_id,
            'attempt ' || v_attempts || ' failed: ' || coalesce(p_error, 'unknown'));
  end if;

  return query
    select e.attempts, e.next_retry_at, e.state
      from public.polar_webhook_events e
     where e.polar_event_id = p_event_id;
end;
$$;

-- ---------- 6) retry claim ----------
create or replace function public.webhook_claim_retries(p_limit int default 20)
returns table (polar_event_id text, type text, payload jsonb, attempts int)
language sql
security definer
set search_path = public
as $$
  select e.polar_event_id, e.type, e.payload, e.attempts
    from public.polar_webhook_events e
   where e.processed_at is null
     and e.state in ('pending', 'retry')
     and coalesce(e.next_retry_at, e.first_seen_at) <= now()
   order by e.first_seen_at asc
   limit greatest(1, least(p_limit, 100));
$$;

-- ---------- 7) reconciliation: paid but not fully landed ----------
create or replace view public.payment_reconciliation_gaps as
select r.polar_event_id,
       r.polar_order_id,
       r.user_id,
       r.customer_email,
       r.plan,
       r.amount_gbp,
       r.created_at,
       (i.id is null) as invoice_missing,
       (r.plan is not null and s.user_id is null) as subscription_missing
  from public.billing_event_receipts r
  left join public.workspace_invoices i
         on i.user_id = r.user_id
        and i.total = r.amount_gbp
  left join public.workspace_subscriptions s
         on s.user_id = r.user_id
 where i.id is null
    or (r.plan is not null and s.user_id is null);

-- ---------- 8) single health view ----------
create or replace view public.payment_health as
select
  (select count(*) from public.polar_webhook_events where processed_at is null and state in ('pending','retry')) as awaiting_retry,
  (select count(*) from public.polar_webhook_events where state = 'dead') as dead_letters,
  (select count(*) from public.polar_webhook_raw where verified = false) as unverified_hits,
  (select count(*) from public.payment_reconciliation_gaps) as reconciliation_gaps,
  (select count(*) from public.payment_alerts where resolved_at is null) as open_alerts,
  (select max(received_at) from public.polar_webhook_raw) as last_webhook_at;

-- ---------- 9) grants (Data API) ----------
grant all on public.polar_webhook_raw, public.payment_alerts to service_role;
grant select on public.payment_reconciliation_gaps, public.payment_health to service_role;
grant execute on function public.webhook_capture_raw(text, text, jsonb, boolean, text, jsonb) to service_role;
grant execute on function public.webhook_mark_processed(text) to service_role;
grant execute on function public.webhook_mark_failed(text, text) to service_role;
grant execute on function public.webhook_claim_retries(int) to service_role;

alter table public.polar_webhook_raw enable row level security;
alter table public.payment_alerts enable row level security;
-- awam ka koi access nahi: sirf service_role (backend) padhta-likhta hai.
