
-- E94 — PLAN PROMISES: plan card par jo vaada user se kiya, uska EK registry + khud-jaanch (audit). Kuch aur nahi badalta.
--  Basic (£40/£440): 5 users, 15 GB shared, 3 mailboxes, 25 MB attachment, 1 domain, 1 booking link, 2 trusted devices, support 72h.
--  Pro   (£105/£1,155): 20 users, 300 GB, 10 mailboxes, 35 MB, 3 domains, 3 booking links, 4 devices, support 48h.
--  Business / Business Pro: vaade registry mein "enforcement = todo" ke saath (TODO-1: abhi code mein nahi) — jhoot nahi likhte.
-- Banata hai: plan_promises (registry, RLS on), plan_promise_audit() (vaada vs asli server-gate), v_plan_promise_gaps (sirf jo toot raha ho),
--             plan_promise_log (har audit ki tareekh, taa ke pata chale kab toota).
-- Dobara chalana safe. Server se: sql-run.sh (auto). Polar :3400 NO-TOUCH.
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.storage_plans') is null then raise exception 'E94 PREFLIGHT: storage_plans nahi (phase48)'; end if;
  if to_regprocedure('public.team_seat_calc(text,integer,integer,integer)') is null then raise exception 'E94 PREFLIGHT: team_seat_calc nahi (E34)'; end if;
  if to_regprocedure('public.org_domain_cap(text)') is null then raise exception 'E94 PREFLIGHT: org_domain_cap nahi (E15)'; end if;
  if to_regclass('public.chat_phase_entitlements') is null then raise exception 'E94 PREFLIGHT: chat_phase_entitlements nahi (anexochat phase19_22)'; end if;
  if to_regclass('public.mail_attach_limits') is null then raise exception 'E94 PREFLIGHT: mail_attach_limits nahi (E48)'; end if;
end $$;

set search_path = public, extensions;

-- 1) Registry ------------------------------------------------------------------------------------------------------------------
create table if not exists public.plan_promises (
  plan         text        not null,
  feature      text        not null,
  promised     numeric,                                   -- NULL = "unlimited" ya sirf-process vaada
  unit         text        not null default 'count',
  enforcement  text        not null default 'server',     -- server | process | todo
  source       text        not null default '',           -- kaun si table/function/Rust file rok rahi hai
  note         text,
  updated_at   timestamptz not null default now(),
  primary key (plan, feature)
);
alter table public.plan_promises add column if not exists note text;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'plan_promises_plan_chk') then
    alter table public.plan_promises add constraint plan_promises_plan_chk
      check (plan in ('basic','pro','business','business_pro','enterprise')) not valid;
    alter table public.plan_promises validate constraint plan_promises_plan_chk;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'plan_promises_enf_chk') then
    alter table public.plan_promises add constraint plan_promises_enf_chk
      check (enforcement in ('server','process','todo')) not valid;
    alter table public.plan_promises validate constraint plan_promises_enf_chk;
  end if;
  if not exists (select 1 from pg_constraint where conname = 'plan_promises_unit_chk') then
    alter table public.plan_promises add constraint plan_promises_unit_chk
      check (unit in ('count','gib','mib','hours','flag')) not valid;
    alter table public.plan_promises validate constraint plan_promises_unit_chk;
  end if;
end $$;

alter table public.plan_promises enable row level security;
revoke all on public.plan_promises from public, anon, authenticated;
grant all on public.plan_promises to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_promises' and policyname='plan_promises_service') then
    create policy plan_promises_service on public.plan_promises for all to service_role using (true) with check (true);
  end if;
end $$;

-- 2) Seed: plans.ts + plan card ka sach (v6). Server-gate wale "server"; support-hours "process"; Business/BP "todo".
insert into public.plan_promises (plan, feature, promised, unit, enforcement, source, note) values
  ('basic','seats',          5,   'count','server','team_seat_calc',        'flat per company, per-user fee nahi'),
  ('basic','storage',        15,  'gib',  'server','storage_plans.pooled',  'shared pool'),
  ('basic','mailboxes',      3,   'count','server','storage_plans.mailbox_limit',null),
  ('basic','attachment',     25,  'mib',  'server','storage_plans.max_send_bytes + mail_attach_limits.server_ceiling_bytes','asli = chhota dono mein se'),
  ('basic','domains',        1,   'count','server','org_domain_cap',        null),
  ('basic','booking_links',  1,   'count','server','booking_pages_cap_trg', null),
  ('basic','devices',        2,   'count','server','chat_phase_entitlements.device_vault',null),
  ('basic','support_hours',  72,  'hours','process','support desk',         'SLA sirf process, code gate nahi'),
  ('pro','seats',            20,  'count','server','team_seat_calc',        null),
  ('pro','storage',          300, 'gib',  'server','storage_plans.pooled',  null),
  ('pro','mailboxes',        10,  'count','server','storage_plans.mailbox_limit',null),
  ('pro','attachment',       35,  'mib',  'server','storage_plans.max_send_bytes + mail_attach_limits.server_ceiling_bytes',null),
  ('pro','domains',          3,   'count','server','org_domain_cap',        null),
  ('pro','booking_links',    3,   'count','server','booking_pages_cap_trg', null),
  ('pro','devices',          4,   'count','server','chat_phase_entitlements.device_vault',null),
  ('pro','support_hours',    48,  'hours','process','support desk',         null),
  ('business','seats',       60,  'count','todo','TODO-1',                  'v6 enforcement SQL abhi nahi'),
  ('business','storage',     1536,'gib',  'todo','TODO-1',                  '1.5 TB'),
  ('business','attachment',  45,  'mib',  'todo','TODO-1 + Postfix limit',  null),
  ('business','support_hours',24, 'hours','process','support desk',         null),
  ('business_pro','seats',   570, 'count','todo','TODO-1',                  null),
  ('business_pro','storage', 10240,'gib', 'todo','TODO-1',                  '10 TB'),
  ('business_pro','attachment',60,'mib',  'todo','TODO-1 + Postfix limit',  null),
  ('business_pro','support_hours',12,'hours','process','support desk',      null)
on conflict (plan, feature) do update
  set promised = excluded.promised, unit = excluded.unit, enforcement = excluded.enforcement,
      source = excluded.source, note = excluded.note, updated_at = now()
  where (plan_promises.promised, plan_promises.unit, plan_promises.enforcement, plan_promises.source)
        is distinct from (excluded.promised, excluded.unit, excluded.enforcement, excluded.source);

-- 3) Asli qeemat nikalne wala (STABLE; har feature ek jagah se). NULL = is feature ka koi server-gate nahi.
create or replace function public.plan_promise_actual(p_plan text, p_feature text)
returns numeric
language plpgsql stable security definer
set search_path = public, extensions, pg_temp
as $fn$
declare v numeric; ceil_b numeric;
begin
  if p_feature = 'seats' then
    return (public.team_seat_calc(p_plan, 0, 0, 0) ->> 'seats')::numeric;
  elsif p_feature = 'storage' then
    select round(pooled_bytes / 1073741824.0, 2) into v from public.storage_plans where plan_id = p_plan;
    return v;
  elsif p_feature = 'mailboxes' then
    select mailbox_limit into v from public.storage_plans where plan_id = p_plan;
    return v;
  elsif p_feature = 'attachment' then
    select max_send_bytes into v from public.storage_plans where plan_id = p_plan;
    select value into ceil_b from public.mail_attach_limits where key = 'server_ceiling_bytes';
    if v is null then return null; end if;
    return round(least(v, coalesce(ceil_b, v)) / 1048576.0, 2);   -- asli: plan cap aur server ceiling mein se chhota
  elsif p_feature = 'domains' then
    return public.org_domain_cap(p_plan);
  elsif p_feature = 'booking_links' then
    select limit_value into v from public.chat_phase_entitlements where plan = p_plan and feature = 'booking_links';
    return v;
  elsif p_feature = 'devices' then
    select limit_value into v from public.chat_phase_entitlements where plan = p_plan and feature = 'device_vault';
    return v;
  end if;
  return null;
end
$fn$;
revoke all on function public.plan_promise_actual(text, text) from public, anon, authenticated;
grant execute on function public.plan_promise_actual(text, text) to service_role;

-- 4) Audit: vaada vs asli. status: ok | broken | todo | process. (broken = server-gate vaade se alag.)
create or replace function public.plan_promise_audit(p_plan text default null)
returns table (plan text, feature text, promised numeric, unit text, actual numeric, enforcement text, status text, source text)
language sql stable security definer
set search_path = public, extensions, pg_temp
as $fn$
  select p.plan, p.feature, p.promised, p.unit,
         case when p.enforcement = 'server' then public.plan_promise_actual(p.plan, p.feature) end as actual,
         p.enforcement,
         case
           when p.enforcement = 'process' then 'process'
           when p.enforcement = 'todo'    then 'todo'
           when public.plan_promise_actual(p.plan, p.feature) is not distinct from p.promised then 'ok'
           else 'broken'
         end as status,
         p.source
  from public.plan_promises p
  where p_plan is null or p.plan = p_plan
  order by p.plan, p.feature
$fn$;
revoke all on function public.plan_promise_audit(text) from public, anon, authenticated;
grant execute on function public.plan_promise_audit(text) to service_role;

-- 5) Sirf toote hue vaade
create or replace view public.v_plan_promise_gaps with (security_invoker = true) as
  select * from public.plan_promise_audit(null) where status = 'broken';
revoke all on public.v_plan_promise_gaps from public, anon, authenticated;
grant select on public.v_plan_promise_gaps to service_role;

-- 6) Audit ka log + snapshot function (har run par ek row; cron/Brain chahe to roz bula sakta hai)
create table if not exists public.plan_promise_log (
  id         bigint generated always as identity primary key,
  taken_at   timestamptz not null default now(),
  ok_count   integer not null,
  broken     integer not null,
  todo       integer not null,
  detail     jsonb not null default '[]'::jsonb
);
create index if not exists plan_promise_log_taken_idx on public.plan_promise_log (taken_at desc);
alter table public.plan_promise_log enable row level security;
revoke all on public.plan_promise_log from public, anon, authenticated;
grant all on public.plan_promise_log to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='plan_promise_log' and policyname='plan_promise_log_service') then
    create policy plan_promise_log_service on public.plan_promise_log for all to service_role using (true) with check (true);
  end if;
end $$;

create or replace function public.plan_promise_snapshot()
returns bigint
language plpgsql security definer
set search_path = public, extensions, pg_temp
as $fn$
declare r record; new_id bigint;
begin
  select count(*) filter (where status = 'ok') as ok_c,
         count(*) filter (where status = 'broken') as br,
         count(*) filter (where status = 'todo') as td,
         coalesce(jsonb_agg(jsonb_build_object('plan', plan, 'feature', feature, 'promised', promised, 'actual', actual))
                  filter (where status = 'broken'), '[]'::jsonb) as det
    into r from public.plan_promise_audit(null);
  insert into public.plan_promise_log (ok_count, broken, todo, detail) values (r.ok_c, r.br, r.td, r.det) returning id into new_id;
  delete from public.plan_promise_log where taken_at < now() - interval '180 days';   -- log hamesha nahi barhta
  return new_id;
end
$fn$;
revoke all on function public.plan_promise_snapshot() from public, anon, authenticated;
grant execute on function public.plan_promise_snapshot() to service_role;

-- 7) Basic + Pro ke liye ek hi nazar mein jawab: kya koi vaada toot raha hai? (Rust/Brain isi ko bula sakta hai)
create or replace function public.plan_promise_ok(p_plan text)
returns boolean
language sql stable security definer
set search_path = public, extensions, pg_temp
as $fn$
  select not exists (select 1 from public.plan_promise_audit(p_plan) where status = 'broken')
$fn$;
revoke all on function public.plan_promise_ok(text) from public, anon, authenticated;
grant execute on function public.plan_promise_ok(text) to service_role;

comment on table public.plan_promises is 'E94: plan card ke vaade (registry). enforcement=server => plan_promise_audit asli gate se milata hai.';
comment on function public.plan_promise_audit(text) is 'E94: vaada vs asli server-gate. status ok|broken|todo|process.';
