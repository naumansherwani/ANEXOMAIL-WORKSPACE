-- E88 — Business Pro-package (naam: PRO) v6 (26 Oct 2026, founder hukm): £105 / month, £1,155 / year, up to 20 users,
--       10 mailboxes, 300 GB SHARED storage, 35 MB attachment, 3 booking links. Basic ke 1 link / Business 20 / Business Pro unlimited bhi yahin.
--
-- Kya badalta hai (Basic E87 jaisa hi raha; Business/Business Pro/Personal ko haath nahi):
--  1) storage_plans 'pro': per-mailbox 10 GB x 5 mailboxes  ->  300 GB shared pool, 10 mailboxes, send 35 MB.
--  2) team_seat_calc: 'basic' = hamesha 5, 'pro' = hamesha 20 (khareede hue seats ki ginti se nahi).
--  3) get_billing_subscription: business Pro = £105 (saalana £1,155), seats 20, user_cap 20, storage_pooled_gb 300.
--     NEW: seats_used ab asli ginti (org ke active members) — pehle hamesha 1 likha aata tha. Personal Pro £46 abhi wahi (HOLD).
--  4) BOOKING LINKS (server-side gate, UI akela nahi): chat_phase_entitlements feature 'booking_links'
--     basic 1 / pro 3 / business 20 / business_pro + baqi unlimited. booking_pages se unique(user_id) hata (ek user ke kai pages),
--     handle unique rehta hai; naya page banate waqt trigger plan ka cap rokta hai (advisory lock => 2 parallel insert cap tod nahi sakte).
--  Devices (2/4/10/50), domains (1/3), mail Pro+ tools (Rust pro_gate), thread analytics (Rust Pro+) PEHLE SE server-side asli hain — yahan nahi chhede.
-- Polar :3400 NO-TOUCH. Dobara chalana safe. Server se: sql-run.sh (auto) ya `. /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E88_pro_v6.sql`
begin;
select pg_advisory_xact_lock(hashtext('E88_pro_v6'));

do $$ begin
  if to_regclass('public.storage_plans') is null then raise exception 'E88 PREFLIGHT: storage_plans nahi (phase48)'; end if;
  if to_regprocedure('public.team_seat_calc(text,integer,integer,integer)') is null then raise exception 'E88 PREFLIGHT: team_seat_calc nahi (E34 pehle)'; end if;
  if to_regprocedure('public.get_billing_subscription(uuid)') is null then raise exception 'E88 PREFLIGHT: get_billing_subscription nahi (E40/E87 pehle)'; end if;
  if to_regclass('public.chat_phase_entitlements') is null or to_regprocedure('public.chat_feature_allowed(uuid,text)') is null then
    raise exception 'E88 PREFLIGHT: chat_phase_entitlements / chat_feature_allowed nahi (anexochat phase19_22 pehle)'; end if;
  if to_regclass('public.booking_pages') is null then raise exception 'E88 PREFLIGHT: booking_pages nahi (E59 pehle)'; end if;
  if (select (r->>'seats')::int from (select public.team_seat_calc('basic',0,0,0) r) x) is distinct from 5 then
    raise exception 'E88 PREFLIGHT: E87 (Basic 5 users) pehle chalana hai'; end if;
end $$;

-- 1) storage: Pro = 300 GiB shared, 10 mailboxes, send 35 MiB
update public.storage_plans
   set per_mailbox_bytes = null,
       pooled_bytes      = 322122547200,
       mailbox_limit     = 10,
       max_send_bytes    = 36700160,
       updated_at        = now()
 where plan_id = 'pro';

-- 2) user cap: Basic 5, Pro 20; baqi plans ka hisaab E34/E87 jaisa
create or replace function public.team_seat_calc(p_plan text, p_seats integer, p_used integer, p_pending integer)
returns jsonb
language sql
immutable
as $$
  with s as (
    select case coalesce(p_plan, '') when 'basic' then 5 when 'pro' then 20 else p_seats end as seats
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

-- 3) billing page: Basic £40 / Pro £105 (flat per month), asli seats_used
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
        price        := 97;
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
    price := case price when 23 then 253 when 40 then 440 when 105 then 1155 when 46 then 506 when 97 then 970 when 2850 then 28500 else price * 12 end;
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

grant execute on function public.get_billing_subscription(uuid) to authenticated, service_role;

-- 4) BOOKING LINKS — entitlement (plan -> cap) + trigger (server-side rok)
insert into public.chat_phase_entitlements (plan, feature, allowed, limit_value, note)
select p.plan, 'booking_links', true,
       case p.plan when 'basic' then 1 when 'pro' then 3 when 'business' then 20 else null end,
       case p.plan when 'basic' then 'public booking links: 1' when 'pro' then 'public booking links: 3'
                   when 'business' then 'public booking links: 20' else 'public booking links: unlimited' end
  from (select distinct plan from public.chat_phase_entitlements) p
on conflict (plan, feature) do update
  set allowed = excluded.allowed, limit_value = excluded.limit_value, note = excluded.note;

-- ek user ke kai pages: unique(user_id) hata, plain index rakha. handle unique (booking_pages_handle_uq) waise hi rehta hai.
drop index if exists public.booking_pages_user_uq;
create index if not exists booking_pages_user_idx on public.booking_pages (user_id, created_at);

create or replace function public.booking_pages_cap()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare v jsonb; lim integer; n integer;
begin
  -- ek hi user ke do parallel insert cap nahi tod sakte
  perform pg_advisory_xact_lock(hashtext('booking_pages_cap'), hashtext(NEW.user_id::text));
  v := public.chat_feature_allowed(NEW.user_id, 'booking_links');
  if coalesce((v->>'allowed')::boolean, false) is not true and (v->>'limit') is null then
    lim := 1;                                  -- row hi na mile to sab se kam cap (Basic jaisa), kabhi khula nahi
  else
    lim := nullif(v->>'limit', '')::integer;   -- null = unlimited
  end if;
  if lim is not null then
    select count(*) into n from public.booking_pages where user_id = NEW.user_id;
    if n >= lim then
      raise exception 'booking_link_limit_reached' using errcode = 'P0001',
        detail = format('plan=%s limit=%s used=%s', v->>'plan', lim, n);
    end if;
  end if;
  return NEW;
end $$;

drop trigger if exists booking_pages_cap_trg on public.booking_pages;
create trigger booking_pages_cap_trg before insert on public.booking_pages
  for each row execute function public.booking_pages_cap();
revoke all on function public.booking_pages_cap() from public, anon, authenticated;

notify pgrst, 'reload schema';

-- self-test (kuch likhta nahi): seat caps
do $$
declare r jsonb;
begin
  r := public.team_seat_calc('pro', 0, 15, 2);
  if (r->>'seats')::int <> 20 or (r->>'free')::int <> 3 or (r->>'enforced')::boolean is not true then raise exception 'E88 SELFTEST FAIL pro cap: %', r; end if;
  r := public.team_seat_calc('pro', 99, 20, 0);
  if (r->>'free')::int <> 0 then raise exception 'E88 SELFTEST FAIL pro full: %', r; end if;
  r := public.team_seat_calc('basic', 2, 3, 1);
  if (r->>'seats')::int <> 5 or (r->>'free')::int <> 1 then raise exception 'E88 SELFTEST FAIL basic still 5: %', r; end if;
  r := public.team_seat_calc('business', 7, 3, 1);
  if (r->>'seats')::int <> 7 then raise exception 'E88 SELFTEST FAIL business unchanged: %', r; end if;
  r := public.team_seat_calc('business_pro', 3, 900, 5);
  if (r->>'unlimited')::boolean is not true then raise exception 'E88 SELFTEST FAIL business_pro unlimited: %', r; end if;
end $$;

-- self-test: business account + Pro plan => £105 (ya £1155), user_cap 20, pool 300 GB
do $$
declare v_u uuid; v jsonb;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  select es.user_id into v_u
    from public.entitlement_state es join public.account_profiles p on p.user_id = es.user_id
   where coalesce(p.preferences->>'workspace_kind', '') = 'business' and lower(es.plan) = 'pro' limit 1;
  if v_u is null then raise notice 'E88: business+pro user nahi mila — billing self-test chhoda'; return; end if;
  v := public.get_billing_subscription(v_u);
  if (v->>'price_per_seat')::int not in (105, 1155) or (v->>'user_cap')::int <> 20 or (v->>'storage_pooled_gb')::int <> 300 or v->>'display_name' <> 'Pro' then
    raise exception 'E88 SELFTEST FAIL: business Pro => %', v;
  end if;
end $$;

select 'E88' as cheez, 'Pro v6: £105 / £1,155, 20 users, 10 mailboxes, 300 GB shared, 35 MB; booking links 1/3/20/unlimited' as haal;

commit;
