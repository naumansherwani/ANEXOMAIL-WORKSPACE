
-- E202 AWAM PRICE MIGRATION TO HIS FINAL CHART (phase AWL-3 SQL, third piece, his 24 Nov 2026 08:31 PKT order "purane pe new schema ka ek sql E202, E201 apni jagah rahe"). AWAM ONLY: no founder table, no Desk table, no Control Plane object. Runs AFTER E201.
-- SCHEMA-FIRST: read before writing: sql/phase21_billing_platform.sql (workspace_plans: id, label, price per USER 23 / 46 / 97 / 2850), sql/phase43_annual_billing_lock.sql + sql/phase46_pricing_v5.sql (billing_price_book: product_key, amount_gbp, per_seat, annual_rule, polar_product_id), E87_basic_v6.sql + E88_pro_v6.sql (get_billing_subscription: Basic 40 and Pro 105 already flat; Business still 97, yearly map still 97 -> 970), E90_kernel_constitution.sql (flat_plan_price 40 / 105 / 360 / 2850 already new), E201_awam_package_caps_final.sql (six packages, package_seat_cap, ledger pattern).
-- ADVANCE-RESEARCH: [AWL-3] web research 24 Nov 2026: a price book is changed by a numbered, repeatable migration and every price change is written to an append-only, hash-chained record (audit-log practice, the same SHA-256 chain pattern as package_cap_ledger in E201), the update only touches a row whose value differs (idempotent, second run changes nothing), and a plan's price is a flat per-company number like Zendesk-class plans, never a per-user value multiplied in several places.
-- CHECK-FILE: docs/cursor-work/sql/CHECK_E202.sql
-- WHAT IT CHANGES (nothing else): (1) workspace_plans.price = his chart, flat per company per month: basic 40, pro 105, business 360, business_pro 2850 (Premium 21,000 and Max 125,000 stay as E201 wrote them, still active = false); (2) billing_price_book (only if it exists): basic 40 / 440 a year, pro 105 / 1,155 a year, business 360 / 3,600 a year (two months free), business_pro unchanged, per_seat false; (3) get_billing_subscription: business 360 (was 97) and the yearly figure 3,600 (was 970), everything else of the E88 function untouched, grant kept; (4) public.package_price_ledger = append-only SHA-256 chain of every number this file changes (old value, new value, where).
-- HONEST LIMITS: Polar's own product prices are NOT changed by SQL (Polar is outside the database: the products in his Polar dashboard must carry the same numbers, his hands; there are 0 subscriptions today so no customer is charged on the old figure); the personal-account branch of the billing function (Personal Basic 23, Personal Pro 46) is untouched: personal packages are retired (E125) and that branch is dead code until the retire is finished; the Premium and Max price-book rows come with their awam code phase.
-- No e-mail, name or customer data is written: plan names and numbers only.

do $pre$ begin
  if to_regclass('public.workspace_plans') is null or to_regclass('public.package_seat_cap') is null then
    raise exception 'E202 needs phase21_billing_platform.sql and E201 first';
  end if;
  if to_regprocedure('public.get_billing_subscription(uuid)') is null then
    raise exception 'E202 needs get_billing_subscription (E5 / E40 / E87 / E88) first';
  end if;
end $pre$;

-- 1) the record of every changed number: append-only, SHA-256 chain -----------------------------------------------------------------------------------------------------------
create table if not exists public.package_price_ledger (
  id      bigserial primary key,
  at      timestamptz not null default now(),
  kind    text not null check (kind in ('migrate', 'selftest')),
  place   text not null check (place in ('workspace_plans', 'billing_price_book', 'billing_function', 'selftest')),
  plan    text not null,
  old_gbp numeric(12,2),
  new_gbp numeric(12,2) not null,
  note    text not null default '' check (length(note) <= 300),
  prev    bytea not null,
  hash    bytea not null
);
alter table public.package_price_ledger enable row level security;
alter table public.package_price_ledger force row level security;
revoke all on public.package_price_ledger from public, anon, authenticated;
grant select on public.package_price_ledger to service_role;
do $p$ begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'package_price_ledger' and policyname = 'package_price_ledger_rw') then
    create policy package_price_ledger_rw on public.package_price_ledger for all using (true) with check (true);
  end if;
end $p$;
create or replace function public.package_price_line_hash202(p_prev bytea, p_kind text, p_place text, p_plan text, p_old numeric, p_new numeric, p_note text, p_at timestamptz) returns bytea
language sql immutable set search_path = pg_catalog, pg_temp as $f$
  select sha256(p_prev || convert_to(concat_ws('|', p_kind, p_place, p_plan, coalesce(p_old::text, '-'), p_new::text, p_note,
                                                to_char(p_at at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US')), 'UTF8'))
$f$;
create or replace function public.package_price_ledger_guard202() returns trigger language plpgsql set search_path = pg_catalog, pg_temp as $f$
declare v_prev bytea;
begin
  if tg_op in ('UPDATE', 'DELETE', 'TRUNCATE') then
    raise exception 'public.package_price_ledger is append-only (% refused)', tg_op using errcode = 'insufficient_privilege';
  end if;
  perform pg_advisory_xact_lock(hashtextextended('public.package_price_ledger', 202));
  select l.hash into v_prev from public.package_price_ledger l order by l.id desc limit 1;
  new.prev := coalesce(v_prev, decode(repeat('00', 32), 'hex'));
  new.hash := public.package_price_line_hash202(new.prev, new.kind, new.place, new.plan, new.old_gbp, new.new_gbp, new.note, new.at);
  return new;
end $f$;
revoke all on function public.package_price_line_hash202(bytea, text, text, text, numeric, numeric, text, timestamptz) from public, anon, authenticated;
revoke all on function public.package_price_ledger_guard202() from public, anon, authenticated;
drop trigger if exists package_price_ledger_chain on public.package_price_ledger;
create trigger package_price_ledger_chain before insert on public.package_price_ledger for each row execute function public.package_price_ledger_guard202();
drop trigger if exists package_price_ledger_frozen on public.package_price_ledger;
create trigger package_price_ledger_frozen before update or delete on public.package_price_ledger for each row execute function public.package_price_ledger_guard202();
drop trigger if exists package_price_ledger_nottruncate on public.package_price_ledger;
create trigger package_price_ledger_nottruncate before truncate on public.package_price_ledger for each statement execute function public.package_price_ledger_guard202();
create or replace function public.package_price_ledger_verify202() returns boolean language plpgsql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
declare r record; v_prev bytea := decode(repeat('00', 32), 'hex');
begin
  for r in select * from public.package_price_ledger order by id loop
    if r.prev <> v_prev or r.hash <> public.package_price_line_hash202(r.prev, r.kind, r.place, r.plan, r.old_gbp, r.new_gbp, r.note, r.at) then return false; end if;
    v_prev := r.hash;
  end loop;
  return true;
end $f$;
revoke all on function public.package_price_ledger_verify202() from public, anon, authenticated;

-- 2) his final chart in workspace_plans (flat per company per month); a row that already holds the number is not touched -------------------------------------------------------
do $m$
declare r record;
begin
  for r in select * from (values ('basic', 40.00), ('pro', 105.00), ('business', 360.00), ('business_pro', 2850.00)) v(plan, gbp) loop
    if exists (select 1 from public.workspace_plans w where w.id = r.plan and w.price is distinct from r.gbp) then
      insert into public.package_price_ledger (kind, place, plan, old_gbp, new_gbp, note)
        select 'migrate', 'workspace_plans', r.plan, w.price, r.gbp, 'his final chart, flat per company per month' from public.workspace_plans w where w.id = r.plan;
      update public.workspace_plans set price = r.gbp where id = r.plan;
    end if;
  end loop;
end $m$;

-- 3) the price book (only where the table exists): Basic 40 / 440, Pro 105 / 1,155, Business 360 / 3,600, flat per company ------------------------------------------------------------
do $b$
declare r record;
begin
  if to_regclass('public.billing_price_book') is null then
    raise notice 'E202: billing_price_book is not here, the price book part is skipped';
    return;
  end if;
  for r in select * from (values
      ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY',    'basic',    40.00,   'one-month-free'),
      ('POLAR_PRODUCT_PLAN_BASIC_YEARLY',     'basic',    440.00,  'one-month-free'),
      ('POLAR_PRODUCT_PLAN_PRO_MONTHLY',      'pro',      105.00,  'one-month-free'),
      ('POLAR_PRODUCT_PLAN_PRO_YEARLY',       'pro',      1155.00, 'one-month-free'),
      ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY', 'business', 360.00,  'two-months-free'),
      ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY',  'business', 3600.00, 'two-months-free')) v(pkey, plan, gbp, rule) loop
    if exists (select 1 from public.billing_price_book b where b.product_key = r.pkey and (b.amount_gbp is distinct from r.gbp or b.per_seat)) then
      insert into public.package_price_ledger (kind, place, plan, old_gbp, new_gbp, note)
        select 'migrate', 'billing_price_book', r.plan, b.amount_gbp, r.gbp, r.pkey from public.billing_price_book b where b.product_key = r.pkey;
      update public.billing_price_book set amount_gbp = r.gbp, per_seat = false,
             annual_rule = case when billing_cycle = 'yearly' then r.rule else null end, updated_at = now()
       where product_key = r.pkey;
    end if;
  end loop;
end $b$;

-- 4) the billing function: the E88 text, ONLY Business changes (97 -> 360, yearly 970 -> 3,600) --------------------------------------------------------------------------------------
do $l$ begin
  if pg_get_functiondef('public.get_billing_subscription(uuid)'::regprocedure) like '%price        := 97;%' then
    insert into public.package_price_ledger (kind, place, plan, old_gbp, new_gbp, note)
      values ('migrate', 'billing_function', 'business', 97.00, 360.00, 'get_billing_subscription business branch, yearly 970 -> 3600');
  end if;
end $l$;

create or replace function public.get_billing_subscription(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  raw          jsonb;
  -- polar_billing_state() returns key 'plan' whose value is the product_key
  -- e.g. "POLAR_PRODUCT_PLAN_PRO_MONTHLY" — NOT a clean plan_id.
  product_key_raw text;
  plan_id      text;   -- clean: basic | pro | business | business_pro
  kind         text;   -- personal | business (from account_profiles)
  intv         text;   -- month | year
  price        integer;
  storage      integer;
  display_name text;
  st           text;
  seats        integer;
  renews_at    timestamptz;
  cancel_at    timestamptz;
  lifetime     boolean := false;
  user_cap     integer := null;   -- E87: v6 flat plan ka user cap (Basic = 5)
  pool_gb      integer := null;   -- E87: shared storage (Basic = 15 GB)
  used_n       integer := 1;      -- E88: asli ginti (org ke active members); pehle hamesha 1 likha aata tha
begin
  -- ── SECURITY: only own row or service_role ────────────────────────────────
  if auth.uid() is distinct from p_user_id
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'forbidden';
  end if;

  if p_user_id is null then return null; end if;

  -- Family accounts (founder ka parivar) = asli buyer jaisa SAB KUCH, farq sirf itna ke unka plan muft aur umar bhar ka hai.
  -- Billing page "£/month" ki jagah "Lifetime access" dikhata hai. Koi alag code path nahi.
  select exists (
    select 1 from auth.users u
    join public.family_accounts f on lower(f.email) = lower(u.email)
    where u.id = p_user_id
  ) into lifetime;

  -- ── Step 1: account_kind — personal vs business [Phase 65] ───────────────
  select lower(nullif(btrim(coalesce(
    p.preferences->>'workspace_kind',
    ''
  )), ''))
  into kind
  from public.account_profiles p
  where p.user_id = p_user_id;

  -- ── Step 2: canonical plan_id from entitlement_state [Phase 36] ──────────
  select lower(nullif(btrim(es.plan), ''))
  into plan_id
  from public.entitlement_state es
  where es.user_id = p_user_id
  limit 1;

  -- ── Step 3: polar_billing_state() — Phase 50, no-touch ───────────────────
  --    Returns: { "plan": "<product_key_string>", "status": ..., "seats": ... }
  --    NOTE: key is literally "plan" even though value is a product_key.
  raw := public.polar_billing_state(p_user_id);
  product_key_raw := lower(coalesce(raw ->> 'plan', ''));
  st              := coalesce(raw ->> 'status', 'none');
  seats           := coalesce((raw ->> 'seats')::integer, 1);
  renews_at       := (raw ->> 'current_period_end')::timestamptz;

  -- ── Step 4: parse product_key → plan_id (fallback if entitlement empty) ───
  if plan_id is null or plan_id = '' then
    plan_id := case
      when product_key_raw ilike '%business_pro%'
        or product_key_raw ilike '%businesspro%'  then 'business_pro'
      when product_key_raw ilike '%business%'     then 'business'
      when product_key_raw ilike '%pro%'          then 'pro'
      when product_key_raw ilike '%basic%'        then 'basic'
      else null
    end;
  end if;

  -- ── Step 5: default kind from plan if still unknown ──────────────────────
  if kind is null or kind = '' then
    kind := case
      when plan_id in ('basic', 'pro') then 'personal'
      when plan_id in ('business', 'business_pro') then 'business'
      else 'personal'
    end;
  end if;

  -- ── Step 6: billing interval from product_key ────────────────────────────
  intv := case when product_key_raw ilike '%yearly%' then 'year' else 'month' end;

  -- ── Step 7: kind-aware display name + price + storage ────────────────────
  --    Billing display only. Feature power is plan-surface.ts featurePlan().
  --    Personal Pro = same POWER as Business Pro, but kind stays personal.
  if kind = 'personal' then
    case plan_id
      when 'basic' then
        display_name := 'Personal Basic';
        price        := 23;
        storage      := 5;
      when 'pro' then
        display_name := 'Personal Pro';
        price        := 46;
        storage      := 10;
      when 'business' then
        -- Personal account on Business SKU → treated as Personal Pro
        display_name := 'Personal Pro';
        price        := 46;
        storage      := 10;
      when 'business_pro' then
        display_name := 'Personal Premium';
        price        := 2850;
        storage      := null;  -- 1TB pooled
      else
        display_name := 'Personal Basic';
        price        := 23;
        storage      := 5;
    end case;
  else
    -- business kind
    case plan_id
      when 'business' then
        display_name := 'Business';
        price        := 360;   -- E202 (24 Nov 2026, his final chart): Business = GBP 360 flat per company per month (was 97 per user)
        storage      := 25;
      when 'business_pro' then
        display_name := 'Business Pro';
        price        := 2850;
        storage      := null;  -- 1TB pooled
      when 'pro' then
        -- E88 (26 Oct 2026, founder): Business Pro-package (Pro) = v6 flat per month, £105, up to 20 users, 300 GB SHARED
        display_name := 'Pro';
        price        := 105;
        storage      := null;
        user_cap     := 20;
        pool_gb      := 300;
        seats        := 20;
      else
        -- E40: Business account par Basic ab Basic hi dikhta hai (pehle £97 / 15 GB likha aata tha)
        -- E87 (26 Oct 2026, founder): Business Basic = v6 flat per month, £40, up to 5 users, 15 GB SHARED (per-mailbox nahi)
        display_name := 'Basic';
        price        := 40;
        storage      := null;
        user_cap     := 5;
        pool_gb      := 15;
        seats        := 5;
    end case;
  end if;

  -- ── Step 7b (E40): saalana plan => saal ki asli raqam (plans.ts), "£23 / year" jaisi galti nahi ──────────
  if intv = 'year' and price is not null then
    price := case price when 23 then 253 when 40 then 440 when 105 then 1155 when 46 then 506 when 360 then 3600 when 2850 then 28500 else price * 12 end;
  end if;

  -- ── Step 8: map Rust :3400 status → UI state ─────────────────────────────
  st := case st
    when 'active'   then 'active'
    when 'past_due' then 'past_due'
    when 'grace'    then 'past_due'
    when 'canceled' then 'cancelled'
    when 'revoked'  then 'cancelled'
    else 'none'
  end;

  cancel_at := case when st = 'cancelled' then renews_at else null end;

  -- E88: seats_used = org ke active (revoked nahi) members; table na ho / koi error to purani value 1
  if to_regclass('public.org_members') is not null then
    begin
      select count(*)::integer into used_n
        from public.org_members m2
       where m2.org_id = (select m.org_id from public.org_members m where m.user_id = p_user_id
                           order by (m.role::text = 'owner') desc limit 1)
         and coalesce(m2.status::text, 'active') <> 'revoked';
      used_n := greatest(coalesce(used_n, 1), 1);
    exception when others then used_n := 1;
    end;
  end if;

  -- No subscription at all
  if plan_id is null then
    return jsonb_build_object(
      'plan',                   null,
      'kind',                   coalesce(kind, 'personal'),
      'display_name',           null,
      'state',                  'none',
      'price_per_seat',         0,
      'currency',               'GBP',
      'interval',               'month',
      'seats',                  0,
      'seats_used',             0,
      'storage_per_mailbox_gb', null,
      'user_cap',               null,
      'storage_pooled_gb',      null,
      'renews_at',              null,
      'cancel_at',              null,
      'lifetime',               lifetime
    );
  end if;

  return jsonb_build_object(
    'plan',                   plan_id,
    'kind',                   kind,
    'display_name',           display_name,
    'state',                  st,
    'price_per_seat',         price,
    'currency',               'GBP',
    'interval',               intv,
    'seats',                  seats,
    'seats_used',             used_n,
    'storage_per_mailbox_gb', storage,
    'user_cap',               user_cap,
    'storage_pooled_gb',      pool_gb,
    'renews_at',              renews_at,
    'cancel_at',              cancel_at,
    'lifetime',               lifetime
  );
end;
$$;

revoke all on function public.get_billing_subscription(uuid) from public, anon;
grant execute on function public.get_billing_subscription(uuid) to authenticated, service_role;

-- 5) posture + selftest -----------------------------------------------------------------------------------------------------------------------------------------------------------
create or replace function public.package_price_posture202() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public, pg_temp as $f$
declare
  v_plans boolean; v_book boolean := true; v_old_left integer; v_fn boolean; v_src text;
begin
  select count(*) = 4 into v_plans from public.workspace_plans w
   where (w.id, w.price) in (('basic', 40.00), ('pro', 105.00), ('business', 360.00), ('business_pro', 2850.00));
  select count(*) into v_old_left from public.workspace_plans w where w.id in ('basic', 'pro', 'business') and w.price in (23.00, 46.00, 97.00);
  if to_regclass('public.billing_price_book') is not null then
    select count(*) = 6 into v_book from public.billing_price_book b
     where (b.product_key, b.amount_gbp, b.per_seat) in (
       ('POLAR_PRODUCT_PLAN_BASIC_MONTHLY', 40.00, false), ('POLAR_PRODUCT_PLAN_BASIC_YEARLY', 440.00, false),
       ('POLAR_PRODUCT_PLAN_PRO_MONTHLY', 105.00, false), ('POLAR_PRODUCT_PLAN_PRO_YEARLY', 1155.00, false),
       ('POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY', 360.00, false), ('POLAR_PRODUCT_PLAN_BUSINESS_YEARLY', 3600.00, false));
  end if;
  v_src := pg_get_functiondef('public.get_billing_subscription(uuid)'::regprocedure);
  v_fn := v_src like '%price        := 360;%' and v_src like '%when 360 then 3600%' and v_src not like '%price        := 97;%' and v_src not like '%when 97 then 970%';
  return jsonb_build_object(
    'plans_final', v_plans,
    'no_old_price_in_plans', v_old_left = 0,
    'price_book_final', v_book,
    'billing_function_final', v_fn,
    'flat_plan_price_agrees', public.flat_plan_price('basic') = 40 and public.flat_plan_price('pro') = 105 and public.flat_plan_price('business') = 360 and public.flat_plan_price('business_pro') = 2850,
    'ledger_append_only', (select count(*) from pg_trigger where tgrelid = 'public.package_price_ledger'::regclass and tgname in ('package_price_ledger_chain', 'package_price_ledger_frozen', 'package_price_ledger_nottruncate')) = 3
                          and (select relforcerowsecurity from pg_class where oid = 'public.package_price_ledger'::regclass),
    'chain_ok', public.package_price_ledger_verify202(),
    'no_client_grants', not exists (select 1 from information_schema.role_table_grants g where g.table_schema = 'public' and g.table_name = 'package_price_ledger' and g.grantee in ('anon', 'authenticated', 'PUBLIC'))
  );
end $f$;
revoke all on function public.package_price_posture202() from public, anon, authenticated;

create or replace function public.package_price_selftest202() returns jsonb language plpgsql security definer set search_path = pg_catalog, public, pg_temp as $f$
declare n integer := 0; v_ok boolean; v_id bigint; v_before integer;
begin
  -- 1 the ledger refuses an update, a delete and a truncate
  select min(id) into v_id from public.package_price_ledger;
  if v_id is null then
    insert into public.package_price_ledger (kind, place, plan, old_gbp, new_gbp, note) values ('selftest', 'selftest', 'basic', null, 1, 'seed') returning id into v_id;
  end if;
  n := n + 1; v_ok := false; begin update public.package_price_ledger set note = 'x' where id = v_id; exception when insufficient_privilege then v_ok := true; end;
  if not v_ok then raise exception 'E202 selftest %: ledger accepted an update', n using errcode = 'AE202'; end if;
  n := n + 1; v_ok := false; begin delete from public.package_price_ledger where id = v_id; exception when insufficient_privilege then v_ok := true; end;
  if not v_ok then raise exception 'E202 selftest %: ledger accepted a delete', n using errcode = 'AE202'; end if;
  n := n + 1; v_ok := false; begin truncate public.package_price_ledger; exception when insufficient_privilege then v_ok := true; end;
  if not v_ok then raise exception 'E202 selftest %: ledger accepted a truncate', n using errcode = 'AE202'; end if;
  -- 2 a line is chained and the chain verifies
  n := n + 1; select count(*) into v_before from public.package_price_ledger;
  insert into public.package_price_ledger (kind, place, plan, old_gbp, new_gbp, note) values ('selftest', 'selftest', 'pro', 1, 2, 'chain probe');
  if (select count(*) from public.package_price_ledger) <> v_before + 1 or not public.package_price_ledger_verify202() then
    raise exception 'E202 selftest %: chain does not verify after an insert', n using errcode = 'AE202';
  end if;
  -- 3 a bad kind and a bad place are refused
  n := n + 1; v_ok := false; begin insert into public.package_price_ledger (kind, place, plan, new_gbp) values ('bogus', 'selftest', 'pro', 1); exception when check_violation then v_ok := true; end;
  if not v_ok then raise exception 'E202 selftest %: bad kind accepted', n using errcode = 'AE202'; end if;
  n := n + 1; v_ok := false; begin insert into public.package_price_ledger (kind, place, plan, new_gbp) values ('migrate', 'bogus', 'pro', 1); exception when check_violation then v_ok := true; end;
  if not v_ok then raise exception 'E202 selftest %: bad place accepted', n using errcode = 'AE202'; end if;
  -- 4 the final prices are in place and no old one is left
  n := n + 1;
  if not ((public.package_price_posture202() ->> 'plans_final')::boolean and (public.package_price_posture202() ->> 'no_old_price_in_plans')::boolean
          and (public.package_price_posture202() ->> 'billing_function_final')::boolean and (public.package_price_posture202() ->> 'price_book_final')::boolean) then
    raise exception 'E202 selftest %: a final price is missing or an old one is left', n using errcode = 'AE202';
  end if;
  -- the rows written above are rolled back by the caller (the DO block raises AE202 after the check)
  raise exception 'E202 selftest ALL OK (% checks)', n using errcode = 'AE202', detail = n::text;
end $f$;
revoke all on function public.package_price_selftest202() from public, anon, authenticated;

do $t$
declare v_msg text;
begin
  begin
    perform public.package_price_selftest202();
  exception when sqlstate 'AE202' then
    get stacked diagnostics v_msg = message_text;
    if v_msg not like 'E202 selftest ALL OK%' then raise; end if;
    raise notice '%, rows rolled back', v_msg;
  end;
end $t$;
