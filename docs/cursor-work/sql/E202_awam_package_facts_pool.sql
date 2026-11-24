
-- E202 AWAM PACKAGE FACTS + POOL LEVELS (phase AWL-3 SQL, second half, his 24 Nov 2026 08:17 PKT order: every word of the awam blueprint points must be in the SQL), AWAM ONLY, E-series.
-- SCHEMA-FIRST: read before writing: E201_awam_package_caps_final.sql (package_seat_cap, package_cap_ledger, package_cap_alerts_open), sql/phase21_billing_platform.sql (workspace_plans id/price/active), E94_plan_promises.sql + E100_plan_interop_matrix.sql (locked values: attachment MB, storage GB, mailboxes per plan), anexochat/sql/phase61_file_limits_quota.sql (chat file per plan), docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md sections 1, 2, 6, G4, G5 and the 22 Nov chart (his points).
-- ADVANCE-RESEARCH: [AWL-3] a plan's limits belong in ONE reviewed table with provenance, a closed "starred" list for values that are recommendations (never shown as a public promise), a derived-number check (pool = seats x 50 GB), and usage levels as a pure function with a hash-chained alert ledger (the same chain E201 uses); web research 24 Nov 2026 as in E201 (advisory locks, tamper-evident ledgers) plus the SaaS pattern of a separate public-card view that hides unverified numbers.
-- CHECK-FILE: docs/cursor-work/sql/CHECK_E202.sql
-- WHAT IT ADDS (nothing else): (1) public.package_fact = his chart as data: flat monthly price, storage, email attachment, chat file, monthly outbound pool, yearly free months (2 / 2 / 2 / 3), own-domain mailboxes (Premium, Max), "unlimited seats" only for Max, and a closed STARRED list (Premium storage + pool; Max storage, attachment, chat file, pool = recommendations, not locked, Hetzner capacity unverified); (2) public.package_card_public = the only view the site may read: starred numbers come out NULL; (3) public.package_pool_level = 70 percent warn, 85 percent high, 100 percent slow-down, NEVER blocked; (4) package_cap_ledger learns pool70 / pool85 / pool100 and the door public.package_pool_report (the Rust meter reports usage, one line per company, level and month); (5) public.package_fact_of(org).
-- HONEST LIMITS: the outbound-usage METER (attachments, downloads, chat files, calls) does not exist as one table yet, so the door takes the number from the Rust meter and invents none; prices in workspace_plans for basic / pro / business stay as they are (his rule: no price change until he says go), this file only REPORTS the difference as a fact; values come from the repo-locked numbers and his chart, a conflict is recorded in the note, never silently resolved.

create table if not exists public.package_fact (
  plan                  text primary key references public.workspace_plans(id),
  price_gbp_month       numeric(12,2) not null check (price_gbp_month > 0),
  storage_gb            integer not null check (storage_gb > 0),
  attach_mb             integer not null check (attach_mb > 0),
  chat_file_gb          numeric(6,2) check (chat_file_gb is null or chat_file_gb > 0),
  pool_gb               integer not null check (pool_gb > 0),
  yearly_free_months    smallint check (yearly_free_months is null or yearly_free_months between 1 and 6),
  own_domain_mailboxes  boolean not null default false,
  seats_unlimited_card  boolean not null default false,
  starred               text[] not null default '{}',
  note                  text not null default '' check (length(note) <= 400),
  source                text not null check (length(source) between 5 and 200),
  check (starred <@ array['storage_gb', 'attach_mb', 'chat_file_gb', 'pool_gb']),
  check (not seats_unlimited_card or plan = 'business_max')            -- "unlimited" is a word for SEATS and only for Max; Business Pro and Premium are never unlimited
);
alter table public.package_fact enable row level security;
alter table public.package_fact force row level security;
revoke all on public.package_fact from public, anon, authenticated;
grant select on public.package_fact to service_role;
do $$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'package_fact' and policyname = 'package_fact_rw') then
    create policy package_fact_rw on public.package_fact for all using (true) with check (true);   -- table rights are revoked from every client role above
  end if;
end $$;
create or replace function public.package_fact_frozen202() returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $f$
begin
  if tg_op = 'TRUNCATE' or coalesce(current_setting('anexo.package_cap_migration', true), '') <> 'E202' then
    raise exception 'public.package_fact changes only through a numbered SQL migration (% refused)', tg_op using errcode = 'insufficient_privilege';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $f$;
revoke all on function public.package_fact_frozen202() from public, anon, authenticated;
drop trigger if exists package_fact_frozen on public.package_fact;
create trigger package_fact_frozen before update or delete on public.package_fact for each row execute function public.package_fact_frozen202();
drop trigger if exists package_fact_nottruncate on public.package_fact;
create trigger package_fact_nottruncate before truncate on public.package_fact for each statement execute function public.package_fact_frozen202();

select set_config('anexo.package_cap_migration', 'E202', false);
insert into public.package_fact (plan, price_gbp_month, storage_gb, attach_mb, chat_file_gb, pool_gb, yearly_free_months, own_domain_mailboxes, seats_unlimited_card, starred, note, source) values
  ('basic',            40.00,     15,      25,   null, 250,    null, false, false, '{}', 'chart says 25 GB storage; repo-locked 15 GB shared stays (his D, 7 Nov); no yearly offer decided',            'his chart 22 Nov + proposal section 2 + E94'),
  ('pro',              105.00,    300,     35,   null, 1000,   null, false, false, '{}', 'no yearly offer decided',                                                                                  'his chart 22 Nov + E94'),
  ('business',         360.00,    1500,    45,   0.50, 3000,   2,    false, false, '{}', 'yearly: 2 months free, the FIRST months, shown as free months in billing (his G5)',                        'his chart 22 Nov + G5 + E100'),
  ('business_pro',     2850.00,   10000,   60,   1.50, 28500,  2,    false, false, '{}', 'chart says 100 MB attachment; repo-locked 60 MB stays (his 26 Oct 03:09); never unlimited, cap 570',       'his chart 22 Nov + G5 + E100'),
  ('business_premium', 21000.00,  70000,   100,  4.00, 350000, 2,    true,  false, array['storage_gb', 'pool_gb'], 'flat GBP 21,000 for up to 7,000 users; storage and pool are recommendations until Hetzner is verified',  'his decisions 7 Nov 22:12 A B C + G5'),
  ('business_max',     125000.00, 250000,  250,  10.00, 500000, 3,   true,  true,  array['storage_gb', 'attach_mb', 'chat_file_gb', 'pool_gb'], 'price 125,000 FINAL (his 24 Nov 08:03); unlimited = SEATS only, strict cap 125,000 (E201); yearly 3 months free', 'his decisions G4 + G5 + 24 Nov 08:03')
on conflict (plan) do update set price_gbp_month = excluded.price_gbp_month, storage_gb = excluded.storage_gb, attach_mb = excluded.attach_mb, chat_file_gb = excluded.chat_file_gb, pool_gb = excluded.pool_gb,
  yearly_free_months = excluded.yearly_free_months, own_domain_mailboxes = excluded.own_domain_mailboxes, seats_unlimited_card = excluded.seats_unlimited_card, starred = excluded.starred, note = excluded.note, source = excluded.source;
select set_config('anexo.package_cap_migration', '', false);

-- the only thing the public site may read: starred numbers never leave the database as a promise
create or replace view public.package_card_public with (security_invoker = false) as
  select f.plan, f.price_gbp_month,
         case when 'storage_gb' = any (f.starred) then null else f.storage_gb end as storage_gb,
         case when 'attach_mb' = any (f.starred) then null else f.attach_mb end as attach_mb,
         case when 'chat_file_gb' = any (f.starred) then null else f.chat_file_gb end as chat_file_gb,
         case when 'pool_gb' = any (f.starred) then null else f.pool_gb end as pool_gb,
         f.yearly_free_months, f.own_domain_mailboxes,
         case when f.seats_unlimited_card then null else c.seat_cap end as seat_cap_shown,
         f.seats_unlimited_card as seats_unlimited
    from public.package_fact f join public.package_seat_cap c on c.plan = f.plan;
revoke all on public.package_card_public from public, anon, authenticated;
grant select on public.package_card_public to service_role;

-- pool levels: 70 warn, 85 high, 100 slow-down; never blocked
create or replace function public.package_pool_level(p_used_gb numeric, p_pool_gb numeric)
returns text language sql immutable parallel safe set search_path = pg_catalog as $f$
  select case when p_pool_gb is null or p_pool_gb <= 0 or p_used_gb is null or p_used_gb < 0 then 'none'
              when p_used_gb >= p_pool_gb then 'slow'
              when p_used_gb * 100 >= p_pool_gb * 85 then 'high'
              when p_used_gb * 100 >= p_pool_gb * 70 then 'warn'
              else 'ok' end
$f$;
revoke all on function public.package_pool_level(numeric, numeric) from public, anon, authenticated;
grant execute on function public.package_pool_level(numeric, numeric) to service_role;
comment on function public.package_pool_level(numeric, numeric) is 'E202: ok / warn (70 percent) / high (85 percent) / slow (100 percent: big transfers and calls slowed, e-mail and incoming mail keep working, nothing deleted). Never "blocked".';

-- the ledger learns the pool kinds (the constraint is replaced, the E201 chain is untouched)
do $$ declare c text; begin
  select conname into c from pg_constraint where conrelid = 'public.package_cap_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%selftest%';
  if c is not null then execute format('alter table public.package_cap_ledger drop constraint %I', c); end if;
  alter table public.package_cap_ledger add constraint package_cap_ledger_kind_check202
    check (kind in ('raise', 'yellow', 'high', 'full', 'selftest', 'pool70', 'pool85', 'pool100'));
exception when duplicate_object then null;
end $$;
create unique index if not exists package_cap_ledger_pool_once on public.package_cap_ledger (org_id, kind, (substr(note, 1, 7))) where kind in ('pool70', 'pool85', 'pool100');

create or replace function public.package_fact_of(p_org uuid) returns jsonb
language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select to_jsonb(f) from public.package_fact f where f.plan = public.package_of_org201(p_org)
$f$;
revoke all on function public.package_fact_of(uuid) from public, anon, authenticated;
grant execute on function public.package_fact_of(uuid) to service_role;

create or replace function public.package_pool_report(p_org uuid, p_used_gb numeric, p_month text)
returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public, pg_temp set lock_timeout = '2s' set statement_timeout = '10s' as $f$
declare v_plan text; v_pool integer; v_level text; v_kind text;
begin
  if p_org is null or p_used_gb is null or p_used_gb < 0 or p_month is null or p_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    raise exception 'E202: company, usage (GB, not negative) and month YYYY-MM are required' using errcode = 'check_violation';
  end if;
  v_plan := public.package_of_org201(p_org);
  if v_plan is null then raise exception 'E202: this company has no running package' using errcode = 'check_violation'; end if;
  select f.pool_gb into v_pool from public.package_fact f where f.plan = v_plan;
  v_level := public.package_pool_level(p_used_gb, v_pool);
  v_kind := case v_level when 'warn' then 'pool70' when 'high' then 'pool85' when 'slow' then 'pool100' else null end;
  if v_kind is not null then
    insert into public.package_cap_ledger (kind, org_id, plan, seats, cap, note) values (v_kind, p_org, v_plan, null, v_pool, p_month || ' used ' || round(p_used_gb)::text || ' GB') on conflict do nothing;
  end if;
  return jsonb_build_object('plan', v_plan, 'pool_gb', v_pool, 'level', v_level, 'blocked', false);
end $f$;
revoke all on function public.package_pool_report(uuid, numeric, text) from public, anon, authenticated;
grant execute on function public.package_pool_report(uuid, numeric, text) to service_role;

create or replace function public.package_facts_posture202() returns jsonb language sql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
  select jsonb_build_object(
    'rls_forced', (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.package_fact'::regclass),
    'six_facts', (select count(*) from public.package_fact) = 6,
    'pool_is_seats_x_50gb', (select count(*) from public.package_fact f join public.package_seat_cap c on c.plan = f.plan where f.plan <> 'business_max' and f.pool_gb = c.seat_cap * 50) = 5,
    'max_pool_500tb_starred', (select pool_gb = 500000 and 'pool_gb' = any (starred) from public.package_fact where plan = 'business_max'),
    'unlimited_only_max', (select count(*) from public.package_fact where seats_unlimited_card) = 1 and (select seats_unlimited_card from public.package_fact where plan = 'business_max'),
    'yearly_free_2_2_2_3', (select string_agg(coalesce(yearly_free_months::text, '-'), ',' order by price_gbp_month) from public.package_fact) = '-,-,2,2,2,3',
    'own_domain_premium_max', (select string_agg(plan, ',' order by plan) from public.package_fact where own_domain_mailboxes) = 'business_max,business_premium',
    'public_card_hides_stars', (select count(*) from public.package_card_public where plan = 'business_max' and (storage_gb is not null or pool_gb is not null or attach_mb is not null or chat_file_gb is not null)) = 0
                               and (select count(*) from public.package_card_public where plan = 'business' and storage_gb = 1500 and pool_gb = 3000) = 1,
    'no_client_grants', not has_table_privilege('anon', 'public.package_fact', 'select') and not has_table_privilege('authenticated', 'public.package_card_public', 'select') and not has_table_privilege('public', 'public.package_fact', 'select'),
    'doors_service_only', has_function_privilege('service_role', 'public.package_pool_report(uuid, numeric, text)', 'execute') and not has_function_privilege('anon', 'public.package_pool_report(uuid, numeric, text)', 'execute') and not has_function_privilege('public', 'public.package_fact_of(uuid)', 'execute'),
    'ledger_kinds', (select count(*) from pg_constraint where conrelid = 'public.package_cap_ledger'::regclass and conname = 'package_cap_ledger_kind_check202') = 1,
    'chain_ok', public.package_cap_ledger_verify201(),
    'price_differences_vs_workspace_plans', (select jsonb_object_agg(f.plan, jsonb_build_object('chart', f.price_gbp_month, 'workspace_plans', p.price)) from public.package_fact f join public.workspace_plans p on p.id = f.plan where f.price_gbp_month <> p.price))
$f$;
revoke all on function public.package_facts_posture202() from public, anon, authenticated;
grant execute on function public.package_facts_posture202() to service_role;

create or replace function public.package_facts_selftest202() returns jsonb language plpgsql volatile security definer set search_path = pg_catalog, public, pg_temp as $f$
declare n int := 0; bad text := ''; v_ok boolean; v_org uuid := gen_random_uuid();
begin
  begin
    n := n + 1; if public.package_pool_level(0, 1000) <> 'ok' or public.package_pool_level(699, 1000) <> 'ok' or public.package_pool_level(700, 1000) <> 'warn' or public.package_pool_level(849, 1000) <> 'warn' or public.package_pool_level(850, 1000) <> 'high' or public.package_pool_level(999, 1000) <> 'high' or public.package_pool_level(1000, 1000) <> 'slow' or public.package_pool_level(5000, 1000) <> 'slow' or public.package_pool_level(1, null) <> 'none' then bad := bad || ' pool-levels'; end if;
    n := n + 1; if public.package_pool_level(1000, 1000) = 'blocked' then bad := bad || ' never-blocked'; end if;
    n := n + 1; if not (public.package_facts_posture202() ->> 'pool_is_seats_x_50gb')::boolean then bad := bad || ' pool-50gb'; end if;
    n := n + 1; if not (public.package_facts_posture202() ->> 'public_card_hides_stars')::boolean then bad := bad || ' stars'; end if;
    n := n + 1; v_ok := false; begin update public.package_fact set price_gbp_month = 1 where plan = 'business_max'; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' fact-update'; end if;
    n := n + 1; v_ok := false; begin delete from public.package_fact where plan = 'basic'; exception when insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' fact-delete'; end if;
    n := n + 1; v_ok := false; begin insert into public.package_fact (plan, price_gbp_month, storage_gb, attach_mb, pool_gb, seats_unlimited_card, source) values ('business_pro', 1, 1, 1, 1, true, 'selftest only'); exception when check_violation or unique_violation or insufficient_privilege then v_ok := true; end; if not v_ok then bad := bad || ' unlimited-only-max'; end if;
    n := n + 1; v_ok := false; begin perform public.package_pool_report(v_org, 10, '2026-11'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' report-no-package'; end if;
    n := n + 1; v_ok := false; begin perform public.package_pool_report(v_org, -1, '2026-11'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' report-negative'; end if;
    n := n + 1; v_ok := false; begin perform public.package_pool_report(v_org, 1, 'November'); exception when check_violation then v_ok := true; end; if not v_ok then bad := bad || ' report-month'; end if;
    insert into public.package_cap_ledger (kind, org_id, plan, cap, note) values ('pool70', v_org, 'business', 3000, '2026-11 used 2100 GB') on conflict do nothing;
    insert into public.package_cap_ledger (kind, org_id, plan, cap, note) values ('pool70', v_org, 'business', 3000, '2026-11 used 2200 GB') on conflict do nothing;
    insert into public.package_cap_ledger (kind, org_id, plan, cap, note) values ('pool70', v_org, 'business', 3000, '2026-12 used 2100 GB') on conflict do nothing;
    n := n + 1; if (select count(*) from public.package_cap_ledger where org_id = v_org and kind = 'pool70') <> 2 then bad := bad || ' pool-once-per-month'; end if;
    n := n + 1; if not public.package_cap_ledger_verify201() then bad := bad || ' chain'; end if;
    raise exception 'E202 selftest done' using errcode = 'AE202', detail = bad;
  exception when sqlstate 'AE202' then
    get stacked diagnostics bad = pg_exception_detail;
  end;
  return jsonb_build_object('ok', coalesce(bad, '') = '', 'total', n, 'failed', coalesce(nullif(bad, ''), 'none'));
end $f$;
revoke all on function public.package_facts_selftest202() from public, anon, authenticated;
grant execute on function public.package_facts_selftest202() to service_role;

do $st$ declare r jsonb; begin
  r := public.package_facts_selftest202();
  if not (r ->> 'ok')::boolean then raise exception 'E202 selftest failed: %', r; end if;
  raise notice 'E202 selftest: ALL RULES PASSED (% checks, rows rolled back)', r ->> 'total';
end $st$;
