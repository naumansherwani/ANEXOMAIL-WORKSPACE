-- Phase 63 - Business Pro support SLA (card promise: "Priority human support - 12h response")
-- Idempotent. Run once on the live DB; safe to re-run.
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.founder_reply_queue'::regclass and contype = 'c'
      and (pg_get_constraintdef(oid) ilike '%response_due_hours%' or pg_get_constraintdef(oid) ilike '%plan%in%')
      and pg_get_constraintdef(oid) not ilike '%state%'
  loop
    execute format('alter table public.founder_reply_queue drop constraint %I', c.conname);
  end loop;
  alter table public.founder_reply_queue
    add constraint founder_reply_queue_plan_check
    check (plan in ('basic','pro','business','business_pro'));
  alter table public.founder_reply_queue
    add constraint founder_reply_queue_response_due_hours_check
    check (response_due_hours in (12,24,48,72));
end $$;

create or replace function public.enqueue_founder_reply(
  p_user_id uuid, p_customer_email text, p_subject text,
  p_thread_id uuid default null, p_received_at timestamptz default now()
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_user_id uuid; v_plan text; v_hours integer; v_id uuid;
begin
  select user_id, coalesce(plan,'basic') into v_user_id, v_plan
  from public.workspace_subscriptions
  where state in ('active','trialing')
    and (lower(customer_email) = lower(p_customer_email) or user_id = p_user_id)
  order by (lower(customer_email) = lower(p_customer_email)) desc limit 1;
  v_user_id := coalesce(v_user_id, p_user_id);
  v_plan := coalesce(v_plan,'basic');
  v_hours := case v_plan when 'business_pro' then 12 when 'business' then 24 when 'pro' then 48 else 72 end;
  insert into public.founder_reply_queue (user_id, thread_id, customer_email, subject, plan,
    response_due_hours, received_at, respond_by)
  values (v_user_id, p_thread_id, p_customer_email, coalesce(p_subject,''), v_plan,
    v_hours, p_received_at, p_received_at + make_interval(hours => v_hours))
  returning id into v_id;
  return v_id;
end $$;
revoke all on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) from public, anon, authenticated;
grant execute on function public.enqueue_founder_reply(uuid,text,text,uuid,timestamptz) to service_role;
