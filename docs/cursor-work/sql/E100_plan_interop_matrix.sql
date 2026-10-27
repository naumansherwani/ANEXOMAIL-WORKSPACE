
-- E100 — PLAN x PLAN INTEROP: poori website ke log ek dusre se contact kar sakte hain (mail, meeting invite, booking, share).
-- Rule: contact par koi plan-gate NAHI. Gate sirf apne feature par — bhejne wale ke apne plan ki limit/feature se (resolve_plan).
-- Banata hai: plan_interop (5x5 x action registry, RLS on), plan_interop_allowed(from,to,action), plan_interop_audit() (sirf jo rule toote).
-- Dobara chalana safe. Server se: sql-run.sh (auto). Polar :3400 NO-TOUCH.
set lock_timeout = '5s';
set statement_timeout = '60s';
set search_path = public, extensions;

create table if not exists public.plan_interop (
  from_plan  text not null,
  to_plan    text not null,
  action     text not null,
  allowed    boolean not null default true,
  gate       text not null default 'own_plan_feature',
  note       text,
  updated_at timestamptz not null default now(),
  primary key (from_plan, to_plan, action)
);

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plan_interop_chk') then
    alter table public.plan_interop add constraint plan_interop_chk check (
      from_plan in ('basic','pro','business','business_pro','enterprise','personal')
      and to_plan in ('basic','pro','business','business_pro','enterprise','personal')
      and action in ('mail','invite','booking','share_thread','chat')
      and gate in ('none','own_plan_feature')) not valid;
    alter table public.plan_interop validate constraint plan_interop_chk;
  end if;
end $$;

alter table public.plan_interop enable row level security;
revoke all on public.plan_interop from public, anon, authenticated;
grant all on public.plan_interop to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_interop' and policyname='plan_interop_service') then
    create policy plan_interop_service on public.plan_interop for all to service_role using (true) with check (true);
  end if;
end $$;

-- 6 x 6 x 5 = 180 row: hamesha allowed. Gate = sirf bhejne wale ka apna feature (jaise Pro ka 3 booking links, Basic ka 1).
insert into public.plan_interop (from_plan, to_plan, action, allowed, gate, note)
select f, t, a, true,
       case when a = 'mail' then 'none' else 'own_plan_feature' end,
       'contact har plan ke beech khula; limit sirf bhejne wale ke apne plan ki'
from unnest(array['basic','pro','business','business_pro','enterprise','personal']) f
cross join unnest(array['basic','pro','business','business_pro','enterprise','personal']) t
cross join unnest(array['mail','invite','booking','share_thread','chat']) a
on conflict (from_plan, to_plan, action) do nothing;

create or replace function public.plan_interop_allowed(p_from text, p_to text, p_action text)
returns boolean language sql stable set search_path = public as $$
  select coalesce((select allowed from public.plan_interop
                    where from_plan = lower(p_from) and to_plan = lower(p_to) and action = lower(p_action)), false);
$$;
revoke all on function public.plan_interop_allowed(text,text,text) from public, anon, authenticated;
grant execute on function public.plan_interop_allowed(text,text,text) to service_role;

create or replace function public.plan_interop_audit()
returns table (from_plan text, to_plan text, action text, problem text)
language sql stable set search_path = public as $$
  select from_plan, to_plan, action, 'blocked: plan-to-plan contact band nahi hona chahiye'
    from public.plan_interop where not allowed
  union all
  select from_plan, to_plan, action, 'mail par gate nahi hona chahiye'
    from public.plan_interop where action = 'mail' and gate <> 'none';
$$;
revoke all on function public.plan_interop_audit() from public, anon, authenticated;
grant execute on function public.plan_interop_audit() to service_role;
