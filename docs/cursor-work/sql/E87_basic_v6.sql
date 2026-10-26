
-- E87 — Business Basic v6 (26 Oct 2026, founder hukm): £40 / month, £440 / year, up to 5 users, 15 GB SHARED storage.
--
-- Kya badalta hai (sirf Business-kind Basic; Pro/Business/Business Pro/Personal ko haath nahi):
--  1) storage_plans 'basic': per-mailbox 5 GB / 3 mailboxes -> 15 GB shared pool, 3 mailboxes. (Pool ka code pehle se hai: pooled_bytes wala raasta.)
--  2) team_seat_calc: 'basic' ke liye cap HAMESHA 5 (khareede hue seats ki ginti se nahi) — 6th member / invite roka jata hai.
--  3) get_billing_subscription: business Basic = £40 (saalana £440), seats = 5, user_cap = 5, storage_pooled_gb = 15.
--     Personal Basic ka £23 abhi wahi (Personal HOLD hai, founder alag meeting mein). Naye keys: user_cap, storage_pooled_gb.
-- Polar :3400 NO-TOUCH. Dobara chalana safe. Server se: sql-run.sh (auto) ya `. /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E87_basic_v6.sql`
set lock_timeout = '5s';
set statement_timeout = '60s';

do $$ begin
  if to_regclass('public.storage_plans') is null then raise exception 'E87 PREFLIGHT: storage_plans nahi (phase48)'; end if;
  if to_regprocedure('public.team_seat_calc(text,integer,integer,integer)') is null then raise exception 'E87 PREFLIGHT: team_seat_calc nahi (E34 pehle)'; end if;
  if to_regprocedure('public.get_billing_subscription(uuid)') is null then raise exception 'E87 PREFLIGHT: get_billing_subscription nahi (E40 pehle)'; end if;
end $$;

-- 1) storage: Basic = 15 GiB shared, 3 mailboxes, send 25 MB (pehle jaisa)
update public.storage_plans
   set per_mailbox_bytes = null,
       pooled_bytes      = 16106127360,
       mailbox_limit     = 3,
       max_send_bytes    = 26214400,
       updated_at        = now()
 where plan_id = 'basic';

-- 2) user cap: Basic = 5 users (member + pending invites), baqi plans ka hisaab E34 jaisa hi
create or replace function public.team_seat_calc(p_plan text, p_seats integer, p_used integer, p_pending integer)
returns jsonb
language sql
immutable
as $$
  with s as (
    select case when coalesce(p_plan, '') = 'basic' then 5 else p_seats end as seats
  )
  select jsonb_build_object(
    'plan',      p_plan,
    'unlimited', coalesce(p_plan, '') = 'business_pro',
    'known',     coalesce(s.seats, 0) > 0,
    'enforced',  coalesce(p_plan, '') <> 'business_pro' and coalesce(s.seats, 0) > 0,
    'seats',     case when coalesce(p_plan, '') <> 'business_pro' and coalesce(s.seats, 0) > 0 then s.seats else null end,
    'used',      greatest(coalesce(p_used, 0), 0),
    'pending',   greatest(coalesce(p_pending, 0), 0),
    'free',      case when coalesce(p_plan, '') <> 'business_pro' and coalesce(s.seats, 0) > 0
                      then greatest(s.seats - greatest(coalesce(p_used, 0), 0) - greatest(coalesce(p_pending, 0), 0), 0)
                      else null end
  ) from s
$$;

-- 3) billing page: business Basic = £40 / £440, 5 users, 15 GB shared
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
        price        := 97;
        storage      := 25;
      when 'business_pro' then
        display_name := 'Business Pro';
        price        := 2850;
        storage      := null;  -- 1TB pooled
      when 'pro' then
        display_name := 'Pro';
        price        := 46;
        storage      := 10;
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
    price := case price when 23 then 253 when 40 then 440 when 46 then 506 when 97 then 970 when 2850 then 28500 else price * 12 end;
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
    'seats_used',             1,
    'storage_per_mailbox_gb', storage,
    'user_cap',               user_cap,
    'storage_pooled_gb',      pool_gb,
    'renews_at',              renews_at,
    'cancel_at',              cancel_at,
    'lifetime',               lifetime
  );
end;
$$;

grant execute on function public.get_billing_subscription(uuid) to authenticated, service_role;

-- self-test (kuch likhta nahi): team_seat_calc Basic = cap 5
do $$
declare r jsonb;
begin
  r := public.team_seat_calc('basic', 0, 3, 1);
  if (r->>'seats')::int <> 5 or (r->>'free')::int <> 1 or (r->>'enforced')::boolean is not true then raise exception 'E87 SELFTEST FAIL basic cap: %', r; end if;
  r := public.team_seat_calc('basic', 2, 5, 0);
  if (r->>'free')::int <> 0 then raise exception 'E87 SELFTEST FAIL basic full: %', r; end if;
  r := public.team_seat_calc('business', 5, 3, 1);
  if (r->>'seats')::int <> 5 or (r->>'free')::int <> 1 then raise exception 'E87 SELFTEST FAIL business unchanged: %', r; end if;
  r := public.team_seat_calc('business_pro', 3, 900, 5);
  if (r->>'unlimited')::boolean is not true then raise exception 'E87 SELFTEST FAIL business_pro unlimited: %', r; end if;
end $$;

-- self-test: business account + Basic plan => £40 (ya £440), user_cap 5, pool 15 GB
do $$
declare v_u uuid; v jsonb;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  select es.user_id into v_u
    from public.entitlement_state es join public.account_profiles p on p.user_id = es.user_id
   where coalesce(p.preferences->>'workspace_kind', '') = 'business' and lower(es.plan) = 'basic' limit 1;
  if v_u is null then raise notice 'E87: business+basic user nahi mila — billing self-test chhoda'; return; end if;
  v := public.get_billing_subscription(v_u);
  if (v->>'price_per_seat')::int not in (40, 440) or (v->>'user_cap')::int <> 5 or (v->>'storage_pooled_gb')::int <> 15 or v->>'display_name' <> 'Basic' then
    raise exception 'E87 SELFTEST FAIL: business Basic => %', v;
  end if;
end $$;

select 'E87' as cheez, 'Business Basic v6: £40 / £440, 5 users, 15 GB shared' as haal;

