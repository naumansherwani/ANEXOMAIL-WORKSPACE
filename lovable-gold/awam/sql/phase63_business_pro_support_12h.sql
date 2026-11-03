-- ANEXOMAIL — Phase 63: Business Pro support reply clock = 12 hours (founder decision, 17 Oct 2026).
-- Problem (phase34): founder_reply_queue allowed only plan basic|pro|business and 24|48|72 h, and enqueue_founder_reply
-- mapped every other plan to 72 h. So a Business Pro customer who wrote to hello@anexomail.com either got NO queue row
-- (check violation, swallowed by the delivery trigger) or the SLOWEST clock (72 h) — the "12h priority support" on the
-- plan page was not true.
-- Safe: only founder_reply_queue + enqueue_founder_reply. Polar / payment tables and code are NOT touched.
-- Idempotent. Run:  bash sql/run.sh sql/phase63_business_pro_support_12h.sql

begin;

-- 1. widen the two single-column CHECKs (found by column, so auto-generated names do not matter)
do $$
declare c text;
begin
  for c in
    select distinct k.conname
    from pg_constraint k
    join pg_attribute a on a.attrelid = k.conrelid and a.attnum = any (k.conkey)
    where k.conrelid = 'public.founder_reply_queue'::regclass
      and k.contype = 'c'
      and a.attname in ('plan', 'response_due_hours')
  loop
    execute format('alter table public.founder_reply_queue drop constraint %I', c);
  end loop;
end $$;

alter table public.founder_reply_queue
  add constraint founder_reply_queue_plan_check
  check (plan in ('basic', 'pro', 'business', 'business_pro'));
alter table public.founder_reply_queue
  add constraint founder_reply_queue_response_due_hours_check
  check (response_due_hours in (12, 24, 48, 72));

-- 2. same function, same signature; only the hours mapping gains business_pro = 12
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
  select user_id, lower(coalesce(plan, 'basic')) into v_user_id, v_plan
  from public.workspace_subscriptions
  where state in ('active', 'trialing')
    and (lower(customer_email) = lower(p_customer_email) or user_id = p_user_id)
  order by (lower(customer_email) = lower(p_customer_email)) desc
  limit 1;

  v_user_id := coalesce(v_user_id, p_user_id);
  v_plan := coalesce(v_plan, 'basic');
  if v_plan not in ('basic', 'pro', 'business', 'business_pro') then v_plan := 'basic'; end if;
  v_hours := case v_plan when 'business_pro' then 12 when 'business' then 24 when 'pro' then 48 else 72 end;

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
revoke all on function public.enqueue_founder_reply(uuid, text, text, uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.enqueue_founder_reply(uuid, text, text, uuid, timestamptz) to service_role;

-- 3. self-test inside a sub-transaction (rolled back): a business_pro / 12 h row must now be accepted
do $$
begin
  begin
    insert into public.founder_reply_queue (customer_email, plan, response_due_hours, received_at, respond_by)
    values ('phase63-selftest@invalid.example', 'business_pro', 12, now(), now() + interval '12 hours');
    raise exception 'phase63_selftest_ok';
  exception when others then
    if sqlerrm <> 'phase63_selftest_ok' then
      raise exception 'phase63 FAILED: %', sqlerrm;
    end if;
  end;
end $$;

commit;

-- read-only proof (run after): select conname, pg_get_constraintdef(oid) from pg_constraint
--   where conrelid = 'public.founder_reply_queue'::regclass and contype = 'c';
