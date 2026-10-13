-- =============================================================================
-- E22 — package badalna = naye plan ka POORA price, purana plan band.
-- Supabase #4 SQL Editor mein poori file paste -> Run. Idempotent.
--
-- FOUNDER RULE (13 Oct 2026): user ne jis package ke paise diye hain, agar woh
-- naye package pe jana chahe to naye package ke paise shuru se dega. Purane ka
-- koi credit / prorate nahi. Purani subscription band.
--
-- FLOW:
--   1. user naye plan ka normal (poore price ka) Polar checkout kholta hai;
--      Bun/Rust usi waqt yahan ek 'pending' row likhta hai: "yeh purani
--      subscription is naye product ke payment ke baad band hogi".
--   2. Rust payment engine (polar-rust-payment :3400) ka naya alag loop dekhta
--      hai: user ke naye product ki subscription polar_subscriptions mein
--      'active' ho gayi? Tab SIRF wahi ek purani subscription Polar se revoke
--      karta hai aur row 'done' kar deta hai.
--   3. checkout beech mein chhoda gaya -> naya active nahi aata -> purana plan
--      jaisa tha waisa. 48h baad row 'abandoned'.
--
-- PART 1: polar_plan_replacements table (naya, koi purana table nahi chhua).
-- PART 2: polar_billing_state() ka sirf order-by:
--   Phase 50 ka function user ki "sab se aakhir mein update hui" row dikhata
--   tha. Purani subscription revoke hogi to uski row 'revoked' ban kar sab se
--   naye updated_at par aa jati hai aur billing page "purana plan, revoked"
--   dikhata. Ab active/past_due/grace rows pehle, phir updated_at. Function
--   ka baqi har hissa (signature, security, return shape, grants) Phase 50 wala
--   hi hai, akshar ba akshar.
-- =============================================================================

-- ── PART 1 ────────────────────────────────────────────────────────────────────
create table if not exists public.polar_plan_replacements (
  id                  uuid primary key default gen_random_uuid(),
  user_id             uuid not null,
  old_subscription_id text not null,
  target_product_id   text not null,
  target_product_key  text,
  intent_id           uuid,
  checkout_id         text,
  state               text not null default 'pending'
                        check (state in ('pending','done','abandoned','failed')),
  attempts            int  not null default 0,
  last_error          text,
  created_at          timestamptz not null default now(),
  done_at             timestamptz
);

-- ek purani subscription ke liye ek waqt mein sirf ek pending row
create unique index if not exists polar_plan_repl_one_pending
  on public.polar_plan_replacements (old_subscription_id)
  where state = 'pending';
create index if not exists polar_plan_repl_pending_idx
  on public.polar_plan_replacements (created_at)
  where state = 'pending';

-- locked order: grants -> RLS -> policies
grant all on public.polar_plan_replacements to service_role;
alter table public.polar_plan_replacements enable row level security;
drop policy if exists service_all on public.polar_plan_replacements;
create policy service_all on public.polar_plan_replacements
  for all to service_role using (true) with check (true);

-- ── PART 2 ────────────────────────────────────────────────────────────────────
create or replace function public.polar_billing_state(_user uuid)
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce(
    (select jsonb_build_object(
       'plan',               s.product_key,
       'status',             s.status,
       'seats',              s.seats,
       'current_period_end', s.current_period_end,
       'grace_until',        s.grace_until,
       'grace_days_left',    greatest(0, ceil(extract(epoch from (s.grace_until - now())) / 86400))::int,
       'payment_due',        s.status in ('past_due','grace'),
       'service_blocked',    false
     )
     from public.polar_subscriptions s
     where s.user_id = _user
     order by (s.status in ('active','past_due','grace')) desc, s.updated_at desc
     limit 1),
    jsonb_build_object('plan', null, 'status', 'none', 'payment_due', false, 'service_blocked', false)
  )
$$;

grant execute on function public.polar_billing_state(uuid) to authenticated, service_role;

-- ── VERIFY (paste karke dekho) ────────────────────────────────────────────────
-- select to_regclass('public.polar_plan_replacements');   -- naam aana chahiye
-- select pg_get_functiondef('public.polar_billing_state(uuid)'::regprocedure);
--   -> "order by (s.status in ('active','past_due','grace')) desc" nazar aaye
