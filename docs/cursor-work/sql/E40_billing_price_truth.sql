-- E40 — Billing page sahi daam — 20 Oct 2026 (Basic live audit: business account ke Basic plan par "£97.00 / month · 25 GB / mailbox")
--
-- Kyun: E5 `get_billing_subscription` mein business account ka har plan jo business / business_pro nahi tha
-- "else" mein ja kar Business ka daam (£97, 25 GB) le leta tha. Basic (£23, 5 GB) aur Pro (£46, 10 GB) galat dikhte the.
-- Saalana plan par mahine ka daam "/ year" ke saath dikhta tha (£23 / year).
-- Hal: wohi function, sirf yeh do cheezein theek (plans.ts ke daam: Basic 23/253, Pro 46/506, Business 97/970, Business Pro 2850/28500).
-- Koi table / data nahi badalta. Polar :3400 NO-TOUCH. Supabase SQL Editor-safe. Dobara chalana safe.
-- Server se: . /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f E40_billing_price_truth.sql
begin;
select pg_advisory_xact_lock(hashtext('E40_billing_price_truth'));

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
        -- E40: Business account par Basic ab Basic hi dikhta hai (pehle £97 / 25 GB likha aata tha)
        display_name := 'Basic';
        price        := 23;
        storage      := 5;
    end case;
  end if;

  -- ── Step 7b (E40): saalana plan => saal ki asli raqam (plans.ts), "£23 / year" jaisi galti nahi ──────────
  if intv = 'year' and price is not null then
    price := case price when 23 then 253 when 46 then 506 when 97 then 970 when 2850 then 28500 else price * 12 end;
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
    'renews_at',              renews_at,
    'cancel_at',              cancel_at,
    'lifetime',               lifetime
  );
end;
$$;

grant execute on function public.get_billing_subscription(uuid) to authenticated, service_role;

-- self-test: business account + Basic plan => £23 / 5 GB (service_role ki tarah padhte hain; kuch likhta nahi)
do $$
declare v_u uuid; v jsonb;
begin
  perform set_config('request.jwt.claims', '{"role":"service_role"}', true);
  perform set_config('request.jwt.claim.role', 'service_role', true);
  select es.user_id into v_u
    from public.entitlement_state es join public.account_profiles p on p.user_id = es.user_id
   where coalesce(p.preferences->>'workspace_kind', '') = 'business' and lower(es.plan) = 'basic' limit 1;
  if v_u is null then raise notice 'E40: business+basic user nahi mila — self-test chhoda'; return; end if;
  v := public.get_billing_subscription(v_u);
  if (v->>'price_per_seat')::int not in (23, 253) or coalesce((v->>'storage_per_mailbox_gb')::int, 0) <> 5 or v->>'display_name' <> 'Basic' then
    raise exception 'E40 SELFTEST FAIL: business Basic => %', v;
  end if;
end $$;

select 'get_billing_subscription' as cheez, 'E40 laga (business Basic = £23 / 5 GB, Pro = £46 / 10 GB, saalana = saal ki raqam)' as haal;

commit;
