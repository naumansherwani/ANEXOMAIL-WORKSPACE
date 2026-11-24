
-- E201 AWAM PACKAGE CAPS FINAL (phase AWL-3 SQL half + the SQL part of AWL-2, loopholes L1 + L3, list BL-46 order-lock: awam lane, own gate), 24 Nov 2026 PKT. AWAM ONLY: no founder table, no Desk table, no Control Plane object.
-- SCHEMA-FIRST: read before writing: sql/phase21_billing_platform.sql (workspace_plans with 4 rows and workspace_subscriptions.plan FOREIGN KEY to it), sql/phase60_org_identity_repair.sql (org_members: org_id, user_id, role, status), E27 (workspace_plans.mailboxes_included now nullable), anexochat/sql/phase61_file_limits_quota.sql (file_chart, _file_chart_guard, file_plan_limits), E100 (plan_catalog: business 60 users, business_pro 570), E193 + E187 (plan names business_premium, business_max), CP4 (the six packages), CP6 (hash-chain ledger pattern); docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md section 6 A + G4 (his decisions).
-- ADVANCE-RESEARCH: [AWL-3] web research 24 Nov 2026: a seat count checked in a trigger must be serialised, a transaction-level advisory lock per company stops two simultaneous adds both passing the check (dev.to "Defeating the multi-tenant SaaS concurrency trap in PostgreSQL"); tamper-evident audit = append-only table with UPDATE / DELETE / TRUNCATE refused by trigger plus a SHA-256 hash chain verified by a function (appmaster.io "tamper-evident audit trails in PostgreSQL"). Plan limits live in ONE table with a strict seat guard, alerts are a ledger, never a silent log.
-- CHECK-FILE: docs/cursor-work/sql/CHECK_E201.sql
-- WHAT IT CHANGES (nothing else): (1) workspace_plans gets business_premium and business_max (active = false: sold by contract only, proposal section G) so a subscription for them can be stored; (2) public.package_seat_cap = ONE table with the seat cap of the six packages (5 / 20 / 60 / 570 / 7,000 / 125,000) and the alert levels 90 and 95; (3) public.package_cap_ledger = append-only SHA-256 chain of raises and alerts; (4) strict seat guard + alert trigger on org_members; (5) door public.package_seat_cap_raise (he raises one company, reason of 20+ characters, service_role only); (6) door public.package_cap_alerts_open (the founder dashboard card reads it later); (7) IF phase61 is installed: file_chart follows (Premium 21,000 -> 7,000, Business 20 -> 60) with its own guard still on.
-- HONEST LIMITS: no billing row is invented (workspace_subscriptions stays as it is); a company with no running subscription is not capped; the guard refuses only a NEW active member over the cap, it never removes anyone; Business Max chat-file row (10 GB*) waits for the verified Hetzner values; never run phase61 again after this file (sql-run runs by number only).
-- No e-mail, name or money is written to the new tables: company uuid, package name, counts, times only.

do $pre$ begin
  if to_regclass('public.workspace_plans') is null or to_regclass('public.workspace_subscriptions') is null or to_regclass('public.org_members') is null then
    raise exception 'E201 needs phase21_billing_platform.sql and phase60_org_identity_repair.sql first';
  end if;
end $pre$;

-- 1) the six packages exist in the plan table (the FOREIGN KEY of workspace_subscriptions.plan could not hold Premium or Max before) -------------------------------------------
insert into public.workspace_plans (id, label, price, currency, mailboxes_included, sort_order, active) values
  ('business_premium', 'Business Premium', 21000.00, 'GBP', null, 5, false),
  ('business_max',     'Business Max',     125000.00, 'GBP', null, 6, false)
on conflict (id) do nothing;

-- 2) ONE table: the seat cap of every package (his decisions: Premium 7,000 final; Max card unlimited, strict 125,000) -----------------------------------------------------------
create table if not exists public.package_seat_cap (
  plan       text primary key references public.workspace_plans(id),
  seat_cap   integer not null check (seat_cap between 1 and 1000000),
  yellow_pct smallint not null default 90,
  high_pct   smallint not null default 95,
  source     text not null check (length(source) between 5 and 200),
  check (yellow_pct between 1 and 98 and high_pct between 2 and 99 and yellow_pct < high_pct)
);
alter table public.package_seat_cap enable row level security;
alter table public.package_seat_cap force row level security;
revoke all on public.package_seat_cap from public, anon, authenticated;
grant select on public.package_seat_cap to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'package_seat_cap' and policyname = 'package_seat_cap_rw') then
    -- table rights are revoked from every client role above, so this policy only lets the owner / definer doors through
    create policy package_seat_cap_rw on public.package_seat_cap for all using (true) with check (true);
  end if;
end $$;
create or replace function public.package_seat_cap_frozen201() returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $f$
begin
  if tg_op = 'TRUNCATE' or coalesce(current_setting('anexo.package_cap_migration', true), '') <> 'E201' then
    raise exception 'public.package_seat_cap changes only through a numbered SQL migration (% refused)', tg_op using errcode = 'insufficient_privilege';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $f$;
revoke all on function public.package_seat_cap_frozen201() from public, anon, authenticated;
drop trigger if exists package_seat_cap_frozen on public.package_seat_cap;
create trigger package_seat_cap_frozen before update or delete on public.package_seat_cap for each row execute function public.package_seat_cap_frozen201();
drop trigger if exists package_seat_cap_nottruncate on public.package_seat_cap;
create trigger package_seat_cap_nottruncate before truncate on public.package_seat_cap for each statement execute function public.package_seat_cap_frozen201();

select set_config('anexo.package_cap_migration', 'E201', false);
insert into public.package_seat_cap (plan, seat_cap, source) values
  ('basic',            5,      'card: Basic 5 users (plan_catalog E100)'),
  ('pro',              20,     'card: Pro 20 users (plan_catalog E100)'),
  ('business',         60,     'card + his 22 Nov 2026 chart: Business 60 users'),
  ('business_pro',     570,    'card + his 22 Nov 2026 chart: Business Pro 570 users'),
  ('business_premium', 7000,   'his decision 7 Nov 2026 22:12 A: Premium 7,000 users FINAL'),
  ('business_max',     125000, 'his decision 8 Nov 2026 G4: Max card unlimited, STRICT 125,000 users per company')
on conflict (plan) do update set seat_cap = excluded.seat_cap, source = excluded.source;
select set_config('anexo.package_cap_migration', '', false);

-- 3) the ledger: raises and alerts, append-only, SHA-256 chain ---------------------------------------------------------------------------------------------------------------
create table if not exists public.package_cap_ledger (
  id      bigserial primary key,
  at      timestamptz not null default now(),
  kind    text not null check (kind in ('raise', 'yellow', 'high', 'full', 'selftest')),
  org_id  uuid,
  plan    text,
  seats   integer check (seats is null or seats >= 0),
  cap     integer check (cap is null or cap between 1 and 1000000),
  note    text not null default '' check (length(note) <= 300),
  prev    bytea not null,
  hash    bytea not null
);
create unique index if not exists package_cap_ledger_alert_once on public.package_cap_ledger (org_id, kind, cap) where kind in ('yellow', 'high', 'full');
create index if not exists package_cap_ledger_org on public.package_cap_ledger (org_id, id desc);
alter table public.package_cap_ledger enable row level security;
alter table public.package_cap_ledger force row level security;
revoke all on public.package_cap_ledger from public, anon, authenticated;
grant select on public.package_cap_ledger to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'package_cap_ledger' and policyname = 'package_cap_ledger_rw') then
    create policy package_cap_ledger_rw on public.package_cap_ledger for all using (true) with check (true);
  end if;
end $$;

create or replace function public.package_cap_line_hash201(p_prev bytea, p_kind text, p_org uuid, p_plan text, p_seats integer, p_cap integer, p_note text, p_at timestamptz)
returns bytea language sql immutable parallel safe set search_path = pg_catalog, pg_temp as $f$
  select sha256(p_prev || convert_to(concat_ws('|', p_kind, coalesce(p_org::text, ''), coalesce(p_plan, ''), coalesce(p_seats::text, ''), coalesce(p_cap::text, ''), p_note,
                                                to_char(p_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US')), 'UTF8'))
$f$;
create or replace function public.package_cap_ledger_guard201() returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $f$
declare v_prev bytea;
begin
  if tg_op in ('UPDATE', 'DELETE', 'TRUNCATE') then
    raise exception 'public.package_cap_ledger is append-only (% refused)', tg_op using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('public.package_cap_ledger', 201));
  select l.hash into v_prev from public.package_cap_ledger l order by l.id desc limit 1;
  new.prev := coalesce(v_prev, decode(repeat('00', 32), 'hex'));
  new.hash := public.package_cap_line_hash201(new.prev, new.kind, new.org_id, new.plan, new.seats, new.cap, new.note, new.at);
  return new;
end $f$;
revoke all on function public.package_cap_line_hash201(bytea, text, uuid, text, integer, integer, text, timestamptz) from public, anon, authenticated;
revoke all on function public.package_cap_ledger_guard201() from public, anon, authenticated;
drop trigger if exists package_cap_ledger_chain on public.package_cap_ledger;
create trigger package_cap_ledger_chain before insert on public.package_cap_ledger for each row execute function public.package_cap_ledger_guard201();
drop trigger if exists package_cap_ledger_frozen on public.package_cap_ledger;
create trigger package_cap_ledger_frozen before update or delete on public.package_cap_ledger for each row execute function public.package_cap_ledger_guard201();
drop trigger if exists package_cap_ledger_nottruncate on public.package_cap_ledger;
create trigger package_cap_ledger_nottruncate before truncate on public.package_cap_ledger for each statement execute function public.package_cap_ledger_guard201();

create or replace function public.package_cap_ledger_verify201() returns boolean language plpgsql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
declare r record; v_prev bytea := decode(repeat('00', 32), 'hex');
begin
  for r in select * from public.package_cap_ledger order by id loop
    if r.prev <> v_prev or r.hash <> public.package_cap_line_hash201(r.prev, r.kind, r.org_id, r.plan, r.seats, r.cap, r.note, r.at) then return false; end if;
    v_prev := r.hash;
  end loop;
  return true;
end $f$;
revoke all on function public.package_cap_ledger_verify201() from public, anon, authenticated;
grant execute on function public.package_cap_ledger_verify201() to service_role;

-- 4) pure rules (one place each) ---------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.package_seat_level(p_seats integer, p_cap integer, p_yellow integer default 90, p_high integer default 95)
returns text language sql immutable parallel safe set search_path = pg_catalog as $f$
  select case when p_cap is null or p_cap <= 0 or p_seats is null then 'none'
              when p_seats >= p_cap then 'full'
              when p_seats::bigint * 100 >= p_cap::bigint * p_high then 'high'
              when p_seats::bigint * 100 >= p_cap::bigint * p_yellow then 'yellow'
              else 'ok' end
$f$;
create or replace function public.package_seat_admit201(p_active_now integer, p_cap integer)
returns boolean language sql immutable parallel safe set search_path = pg_catalog as $f$
  select p_cap is null or p_active_now < p_cap      -- one more seat is allowed only while the count is under the cap
$f$;
revoke all on function public.package_seat_level(integer, integer, integer, integer) from public, anon, authenticated;
revoke all on function public.package_seat_admit201(integer, integer) from public, anon, authenticated;
grant execute on function public.package_seat_level(integer, integer, integer, integer) to service_role;
comment on function public.package_seat_level(integer, integer, integer, integer) is 'E201: ok / yellow (90 percent) / high (95 percent) / full (100 percent) / none. The only place the alert levels live.';

-- 5) which package does a company run, and what is its cap now -----------------------------------------------------------------------------------------------------------------
create or replace function public.package_of_org201(p_org uuid) returns text language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select s.plan from public.workspace_subscriptions s
   where s.org_id = p_org and s.plan is not null and s.state in ('trialing', 'active', 'past_due')
   order by s.updated_at desc nulls last limit 1
$f$;
create or replace function public.package_seat_cap_of(p_org uuid)
returns table (plan text, base_cap integer, cap integer, yellow_pct integer, high_pct integer)
language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select c.plan, c.seat_cap,
         greatest(c.seat_cap, coalesce((select l.cap from public.package_cap_ledger l where l.org_id = p_org and l.kind = 'raise' order by l.id desc limit 1), 0)),
         c.yellow_pct::integer, c.high_pct::integer
    from public.package_seat_cap c where c.plan = public.package_of_org201(p_org)
$f$;
revoke all on function public.package_of_org201(uuid) from public, anon, authenticated;
revoke all on function public.package_seat_cap_of(uuid) from public, anon, authenticated;
grant execute on function public.package_seat_cap_of(uuid) to service_role;

-- 6) the strict guard + the alert writer on org_members ------------------------------------------------------------------------------------------------------------------------
create or replace function public.package_seat_guard201() returns trigger language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $f$
declare v_cap record; v_now integer;
begin
  if coalesce(new.status, 'active') <> 'active' then return new; end if;
  if tg_op = 'UPDATE' and coalesce(old.status, 'active') = 'active' and old.org_id is not distinct from new.org_id then return new; end if;   -- nobody is added: nothing to count
  perform pg_advisory_xact_lock(hashtextextended('pkg_seat:' || new.org_id::text, 201));                                                      -- two simultaneous adds cannot both pass
  select * into v_cap from public.package_seat_cap_of(new.org_id);
  if not found then return new; end if;                                                                                                       -- no running package: not capped
  select count(*)::integer into v_now from public.org_members m where m.org_id = new.org_id and coalesce(m.status, 'active') = 'active' and m.id is distinct from new.id;
  if not public.package_seat_admit201(v_now, v_cap.cap) then
    raise exception 'seat cap reached: package % allows % active members, this company has %', v_cap.plan, v_cap.cap, v_now using errcode = 'check_violation';
  end if;
  return new;
end $f$;
create or replace function public.package_seat_alert201() returns trigger language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $f$
declare v_cap record; v_now integer; v_level text;
begin
  if coalesce(new.status, 'active') <> 'active' then return null; end if;
  begin
    select * into v_cap from public.package_seat_cap_of(new.org_id);
    if found then
      select count(*)::integer into v_now from public.org_members m where m.org_id = new.org_id and coalesce(m.status, 'active') = 'active';
      v_level := public.package_seat_level(v_now, v_cap.cap, v_cap.yellow_pct, v_cap.high_pct);
      if v_level in ('yellow', 'high', 'full') then
        insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values (v_level, new.org_id, v_cap.plan, v_now, v_cap.cap, 'seat level reached') on conflict do nothing;
      end if;
    end if;
  exception when others then
    raise warning 'E201 alert not written: %', sqlerrm;                                                                                         -- an alert problem never blocks a member add
  end;
  return null;
end $f$;
revoke all on function public.package_seat_guard201() from public, anon, authenticated;
revoke all on function public.package_seat_alert201() from public, anon, authenticated;
drop trigger if exists org_members_package_seat_guard on public.org_members;
create trigger org_members_package_seat_guard before insert or update of status, org_id on public.org_members for each row execute function public.package_seat_guard201();
drop trigger if exists org_members_package_seat_alert on public.org_members;
create trigger org_members_package_seat_alert after insert or update of status, org_id on public.org_members for each row execute function public.package_seat_alert201();

-- 7) the doors for the founder side (service_role only) --------------------------------------------------------------------------------------------------------------------------
create or replace function public.package_seat_cap_raise(p_org uuid, p_cap integer, p_reason text) returns jsonb
language plpgsql volatile security definer set search_path = pg_catalog, public, pg_temp set lock_timeout = '2s' set statement_timeout = '10s' as $f$
declare v_cap record; v_reason text := btrim(coalesce(p_reason, ''));
begin
  if p_org is null or p_cap is null or p_cap > 1000000 then raise exception 'E201: company and a cap up to 1,000,000 are required' using errcode = 'check_violation'; end if;
  if length(v_reason) < 20 or length(v_reason) > 300 then raise exception 'E201: the reason must be 20 to 300 characters' using errcode = 'check_violation'; end if;
  perform pg_advisory_xact_lock(hashtextextended('pkg_seat:' || p_org::text, 201));
  select * into v_cap from public.package_seat_cap_of(p_org);
  if not found then raise exception 'E201: this company has no running package' using errcode = 'check_violation'; end if;
  if p_cap <= v_cap.cap then raise exception 'E201: a cap is only ever raised (now %)', v_cap.cap using errcode = 'check_violation'; end if;
  insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values ('raise', p_org, v_cap.plan, null, p_cap, v_reason);
  return jsonb_build_object('plan', v_cap.plan, 'old_cap', v_cap.cap, 'new_cap', p_cap);
end $f$;
create or replace function public.package_cap_alerts_open() returns table (org_id uuid, plan text, seats integer, cap integer, level text, first_at timestamptz)
language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select o.org_id, c.plan, s.n, c.cap, public.package_seat_level(s.n, c.cap, c.yellow_pct, c.high_pct), o.first_at
    from (select l.org_id, min(l.at) as first_at from public.package_cap_ledger l where l.kind in ('yellow', 'high', 'full') group by l.org_id) o
    cross join lateral public.package_seat_cap_of(o.org_id) c
    cross join lateral (select count(*)::integer as n from public.org_members m where m.org_id = o.org_id and coalesce(m.status, 'active') = 'active') s
   where public.package_seat_level(s.n, c.cap, c.yellow_pct, c.high_pct) in ('yellow', 'high', 'full')
$f$;
revoke all on function public.package_seat_cap_raise(uuid, integer, text) from public, anon, authenticated;
revoke all on function public.package_cap_alerts_open() from public, anon, authenticated;
grant execute on function public.package_seat_cap_raise(uuid, integer, text) to service_role;
grant execute on function public.package_cap_alerts_open() to service_role;

-- 8) the file chart follows, ONLY if phase61 is installed (its own guard stays on) ------------------------------------------------------------------------------------------------
do $p61$
begin
  if to_regclass('public.file_plan_limits') is null or to_regprocedure('public.file_chart(text)') is null then
    raise notice 'E201: phase61 (file_chart) is not installed here, the file chart part is skipped';
    return;
  end if;
  execute $fn$
    create or replace function public.file_chart(p_plan text) returns table (max_file_bytes bigint, max_users integer)
    language sql immutable parallel safe set search_path = pg_catalog, public as $b$
      select v.f, v.u from (values
        ('business',         524288000::bigint,  60),
        ('ai_pro',           524288000::bigint,  20),
        ('business_pro',     1610612736::bigint, 570),
        ('ai_business',      1610612736::bigint, 570),
        ('business_premium', 4294967296::bigint, 7000),
        ('enterprise',       4294967296::bigint, 21000),
        ('ai_executive',     4294967296::bigint, 21000)
      ) as v(p, f, u) where v.p = lower(coalesce(p_plan, ''))
    $b$
  $fn$;
  update public.file_plan_limits l set max_users = (select c.max_users from public.file_chart(l.plan) c) where l.plan in ('business', 'business_premium') and l.max_users is distinct from (select c.max_users from public.file_chart(l.plan) c);
end $p61$;

-- 9) posture + selftest (the selftest writes nothing: it raises a custom SQLSTATE and catches it) ---------------------------------------------------------------------------------------
create or replace function public.package_file_chart_users201(p_plan text) returns integer language plpgsql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
declare v integer;
begin
  if to_regprocedure('public.file_chart(text)') is null then return null; end if;      -- phase61 not installed: nothing to compare
  execute 'select max_users from public.file_chart($1)' into v using p_plan;
  return v;
end $f$;
revoke all on function public.package_file_chart_users201(text) from public, anon, authenticated;
create or replace function public.package_caps_posture201() returns jsonb language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select jsonb_build_object(
    'rls_forced', (select count(*) = 2 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname in ('package_seat_cap', 'package_cap_ledger') and c.relrowsecurity and c.relforcerowsecurity),
    'no_client_grants', not has_table_privilege('anon', 'public.package_seat_cap', 'select') and not has_table_privilege('authenticated', 'public.package_cap_ledger', 'select') and not has_table_privilege('public', 'public.package_cap_ledger', 'select'),
    'six_packages', (select count(*) from public.package_seat_cap) = 6 and (select count(*) from public.package_seat_cap c join public.workspace_plans p on p.id = c.plan) = 6,
    'premium_7000_max_125000', (select seat_cap from public.package_seat_cap where plan = 'business_premium') = 7000 and (select seat_cap from public.package_seat_cap where plan = 'business_max') = 125000,
    'premium_max_not_self_serve', (select count(*) from public.workspace_plans where id in ('business_premium', 'business_max') and active) = 0,
    'guard_triggers', (select count(*) from pg_trigger t where not t.tgisinternal and t.tgname in ('org_members_package_seat_guard', 'org_members_package_seat_alert')) = 2,
    'ledger_append_only', (select count(*) from pg_trigger t where not t.tgisinternal and t.tgrelid = 'public.package_cap_ledger'::regclass) = 3,
    'doors_service_only', has_function_privilege('service_role', 'public.package_seat_cap_raise(uuid, integer, text)', 'execute') and not has_function_privilege('anon', 'public.package_seat_cap_raise(uuid, integer, text)', 'execute') and not has_function_privilege('public', 'public.package_cap_alerts_open()', 'execute'),
    'chain_ok', public.package_cap_ledger_verify201(),
    'old_21000_gone', coalesce(public.package_file_chart_users201('business_premium') = 7000, true))
$f$;
revoke all on function public.package_caps_posture201() from public, anon, authenticated;
grant execute on function public.package_caps_posture201() to service_role;

create or replace function public.package_caps_selftest201() returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public, pg_temp as $f$
declare n int := 0; bad text := ''; v_org uuid := gen_random_uuid(); v_ok boolean;
begin
  -- the body returns through a custom SQLSTATE so nothing is ever kept
  begin
    -- levels at the exact edges
    n := n + 1; if public.package_seat_level(112499, 125000) <> 'ok' or public.package_seat_level(112500, 125000) <> 'yellow' or public.package_seat_level(118749, 125000) <> 'yellow' or public.package_seat_level(118750, 125000) <> 'high' or public.package_seat_level(124999, 125000) <> 'high' or public.package_seat_level(125000, 125000) <> 'full' then bad := bad || ' max-levels'; end if;
    n := n + 1; if public.package_seat_level(6299, 7000) <> 'ok' or public.package_seat_level(6300, 7000) <> 'yellow' or public.package_seat_level(6650, 7000) <> 'high' or public.package_seat_level(7000, 7000) <> 'full' or public.package_seat_level(1, null) <> 'none' then bad := bad || ' premium-levels'; end if;
    n := n + 1; if public.package_seat_admit201(124999, 125000) is not true or public.package_seat_admit201(125000, 125000) is not false or public.package_seat_admit201(7000, 7000) is not false or public.package_seat_admit201(5, null) is not true then bad := bad || ' admit'; end if;
    -- the chart
    n := n + 1; if (select string_agg(plan || '=' || seat_cap, ',' order by seat_cap) from public.package_seat_cap) <> 'basic=5,pro=20,business=60,business_pro=570,business_premium=7000,business_max=125000' then bad := bad || ' chart'; end if;
    -- the table cannot be changed by hand
    n := n + 1; v_ok := false; begin update public.package_seat_cap set seat_cap = 21000 where plan = 'business_premium'; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' cap-update'; end if;
    n := n + 1; v_ok := false; begin delete from public.package_seat_cap where plan = 'business_max'; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' cap-delete'; end if;
    -- the ledger chain and its guards
    insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values ('selftest', v_org, 'business_max', 112500, 125000, 'selftest one'), ('selftest', v_org, 'business_max', 118750, 125000, 'selftest two');
    n := n + 1; if not public.package_cap_ledger_verify201() then bad := bad || ' chain'; end if;
    n := n + 1; v_ok := false; begin update public.package_cap_ledger set note = 'x' where org_id = v_org; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' ledger-update'; end if;
    n := n + 1; v_ok := false; begin delete from public.package_cap_ledger where org_id = v_org; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' ledger-delete'; end if;
    n := n + 1; if not exists (select 1 from pg_trigger t where t.tgrelid = 'public.package_cap_ledger'::regclass and t.tgname = 'package_cap_ledger_nottruncate' and not t.tgisinternal) then bad := bad || ' ledger-truncate-guard'; end if;   -- TRUNCATE itself cannot run while a query is open, so the guard is checked by its presence (posture counts all 3)
    -- the doors refuse
    n := n + 1; v_ok := false; begin perform public.package_seat_cap_raise(v_org, 130000, 'a reason that is long enough here'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' raise-no-package'; end if;
    n := n + 1; v_ok := false; begin perform public.package_seat_cap_raise(v_org, 130000, 'short'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' raise-short-reason'; end if;
    n := n + 1; v_ok := false; begin perform public.package_seat_cap_raise(v_org, 2000000, 'a reason that is long enough here'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' raise-too-big'; end if;
    -- a company with no running package is not capped and has no cap row
    n := n + 1; if exists (select 1 from public.package_seat_cap_of(v_org)) then bad := bad || ' nocap'; end if;
    -- the alert ledger accepts one line per company, level and cap (a second one is ignored)
    insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values ('yellow', v_org, 'business_max', 112500, 125000, 'once') on conflict do nothing;
    insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values ('yellow', v_org, 'business_max', 112600, 125000, 'twice') on conflict do nothing;
    n := n + 1; if (select count(*) from public.package_cap_ledger where org_id = v_org and kind = 'yellow') <> 1 then bad := bad || ' alert-once'; end if;
    -- phase61 follows when installed
    n := n + 1; if coalesce(public.package_file_chart_users201('business_premium') <> 7000 or public.package_file_chart_users201('business') <> 60, false) then bad := bad || ' file-chart'; end if;
    raise exception 'E201 selftest done' using errcode = 'AE201', detail = bad;
  exception when sqlstate 'AE201' then
    get stacked diagnostics bad = pg_exception_detail;
  end;
  return jsonb_build_object('ok', coalesce(bad, '') = '', 'total', n, 'failed', coalesce(nullif(bad, ''), 'none'));
end $f$;
revoke all on function public.package_caps_selftest201() from public, anon, authenticated;
grant execute on function public.package_caps_selftest201() to service_role;

do $st$ declare r jsonb; begin
  r := public.package_caps_selftest201();
  if not (r ->> 'ok')::boolean then raise exception 'E201 selftest failed: %', r; end if;
  raise notice 'E201 selftest: ALL RULES PASSED (% checks, rows rolled back)', r ->> 'total';
end $st$;
