
-- =============================================================================
-- E20 — real signup != trial. "Personal Basic" jhoota label hata do.
-- Supabase #4 SQL Editor mein poori file paste → Run. Idempotent.
--
-- WAJAH (13 Oct 2026, founder ne khud real account pe dekha — screenshot:
-- "Ali Khan" naya personal signup → dashboard par "Personal Basic" +
-- "47h 56m left in your trial" — koi plan choose nahi kiya, koi payment
-- nahi hui, phir bhi paid-tier ka naam + countdown dikh raha tha.
--
-- ROOT CAUSE (do alag jagah, dono "defaults to basic" bug):
--   1. server/routes/auth.ts /signup har signup par (business ho ya
--      personal) unconditionally trial_start() chalata tha — jo
--      trial_accounts.status = 'trial' (DB column default) set kar deta
--      hai, 48h ka clock shuru. Poore codebase mein koi aur jagah
--      deliberately "start a free trial" button/flow NAHI hai — yeh sirf
--      Phase 32 ki legacy plumbing thi (naya buyer signup = row reserve
--      karne ke liye), lekin uska 'trial' status side-effect (countdown +
--      business_data/ai gating) har real signup par chipak gaya.
--   2. personal_workspace_label() (E2) aur server/routes/auth.ts ka
--      workspacePlan dono: jab koi real plan kahin nahi milta (no
--      family_accounts row, no trial_accounts.plan, no entitlement_state),
--      woh confidently 'basic' fallback kar dete the — matlab "kabhi kuch
--      select/pay nahi kiya" aur "Basic plan liya" dono ek jaisa dikhte the.
--
-- FIX (surgical, Phase 32 lifecycle ko nahi tod rahe — business/future
-- genuine-trial users ke liye 'trial'/'active'/'expired' etc. bilkul waisa
-- hi chalta rahega):
--   - Naya status value 'pending_plan': "account bana, mailbox claim ho
--     gaya, lekin koi plan abhi select/pay nahi hua." Na countdown, na
--     business_data, na AI — bas "/plans par jao" tak hold.
--   - ensure_trial_account_row(): trial_start() ki jagah /signup se yeh
--     call hoga — same plumbing row banata hai lekin status='pending_plan'
--     se (trial clock shuru NAHI karta). account_state() khud hi isko
--     sahi handle kar leta hai (st='trial'/'active' checks already match
--     'pending_plan' ko kabhi nahi, isliye account_state() ko edit karne
--     ki zaroorat nahi padi — sirf naya allowed status value).
--   - personal_workspace_label(): 'basic' fallback hata diya — genuinely
--     koi plan na mile to NULL (frontend "Choose your plan" dikhata hai,
--     kabhi jhoota "Basic" nahi).
--   - One-time backfill: jo accounts PEHLE se is bug ka shikar hain (status
--     'trial', plan NULL, kahin koi real billing row nahi — exactly jaisa
--     founder ka "Ali Khan" test account) — unhe bhi 'pending_plan' par
--     move kar diya, taake fix turant live accounts par bhi dikhe, naya
--     signup banane ki zaroorat na ho.
--
-- phase32_trial.sql / E2_personal_polar.sql khud edit nahi hue (Rule 8 SQL
-- fail-rule precedent — E18/E19 ki tarah) — sirf create-or-replace se upar
-- se override, aur ek naya allowed status value add.
--
-- ENGINEERING HARDENING (founder ne poocha "duniya ka advance SQL mein kya
-- hona chahiye" — yahan woh hai, bulk ke liye nahi, defense-in-depth ke
-- liye — section numbers neeche inline comments se match karte hain):
--   §1b. DATA INTEGRITY INVARIANT — DB khud guarantee karta hai ke
--      status='pending_plan' row par KABHI plan set nahi ho sakta (CHECK
--      constraint). Application code bug-free rahe tab bhi — agar koi
--      future code galti se plan set kare bina status 'active' kiye, DB
--      insert/update khud reject kar dega. Yeh "humein trust karo" se
--      "DB guarantee karta hai" tak le jata hai.
--   §1c. FUNNEL AUDIT TRAIL — naya trial_events value 'pending_plan_entered',
--      idempotency index mein bhi widen (E17 jaisa precedent) — taake har
--      signup → pending_plan transition queryable audit mein rahe, sirf
--      current-state snapshot nahi.
--   §4. MONITORING VIEW (v_signup_plan_funnel) — service_role-only, ek
--      query se batata hai kitne accounts kis stage par hain aur average
--      kitna time lag raha hai — business ko pata chalta hai signup →
--      payment ke beech kahan log ruk rahe hain.
--   §5. STALE DETECTOR (pending_plan_stale) — READ-ONLY, Phase 24A ki
--      locked philosophy follow karta hai: engine KABHI khud block/act
--      nahi karti, sirf surface karti hai (jaise device_vault), human
--      decide karta hai (win-back email bhejna ya na bhejna).
--   §1b/§2/§4 "comment on". SELF-DOCUMENTING — schema khud apna purpose
--      bataye (`\d+`, information_schema se visible).
--
-- Fail = isi file ko theek likho. E20b / _fix / _v2 banned.
-- =============================================================================
set search_path = public, extensions;

-- ── 1) naya status value: 'pending_plan' ──────────────────────────────────
alter table public.trial_accounts drop constraint if exists trial_accounts_status_check;
alter table public.trial_accounts add constraint trial_accounts_status_check
  check (status in ('trial','active','expired','frozen','released','pending_plan'));

-- ── 1b) DATA INTEGRITY INVARIANT — pending_plan row par plan kabhi set nahi
-- ho sakta. trial_subscribe() (phase32) hamesha status + plan EK SAATH,
-- same UPDATE mein set karta hai ('active', _plan) — isliye yeh constraint
-- correct code ke liye kabhi fire nahi hoga. Yeh sirf FUTURE bug se bachata
-- hai: agar kal koi naya code galti se sirf plan set kar de status update
-- kiye bina, Postgres khud us insert/update ko reject kar dega — "Personal
-- Basic" wala bug class permanently DB level par band ho jata hai, sirf
-- application code ke bharose nahi.
alter table public.trial_accounts drop constraint if exists trial_accounts_pending_plan_no_plan_check;
alter table public.trial_accounts add constraint trial_accounts_pending_plan_no_plan_check
  check (status <> 'pending_plan' or plan is null);

-- ── 1c) funnel audit — naya trial_events value + idempotency index widen
-- (same technique jo E17 ne 'workspace_provisioned' ke liye use ki thi).
-- 22 Oct 2026: constraint kabhi chhota nahi hota (E17 jaisa guard; maujooda rows shamil) — dobara chalana safe.
do $$
declare
  have text; vals text[];
begin
  select pg_get_constraintdef(c.oid) into have from pg_constraint c
   where c.conrelid = 'public.trial_events'::regclass and c.conname = 'trial_events_event_type_check';
  if have is null or have not like '%pending_plan_entered%' then
    select array_agg(distinct v order by v) into vals from (
      select unnest(array['signup','claim','passkey_set','recovery_set','warn_24h','warn_2h','expired','subscribed','frozen','released','mail_hold','recovery_used',
                          'workspace_provisioned','pending_plan_entered']::text[]) as v
      union select event_type from public.trial_events) u;
    execute 'alter table public.trial_events drop constraint if exists trial_events_event_type_check';
    execute format('alter table public.trial_events add constraint trial_events_event_type_check check (event_type = any (%L::text[]))', vals);
  end if;
end $$;

drop index if exists trial_events_once_idx;
create unique index trial_events_once_idx
  on public.trial_events (user_id, event_type)
  where event_type in (
    'signup','claim','passkey_set','recovery_set','warn_24h','warn_2h',
    'expired','frozen','released','pending_plan_entered'
  );

-- ── 2) ensure_trial_account_row — trial_start() ka naya, honest replacement ─
-- Same plumbing (claim/provisioning ke liye row chahiye), lekin trial clock
-- shuru NAHI karta. account_state() ke 'st = ...' comparisons 'pending_plan'
-- ko khud-ba-khud sahi handle karte hain (hours_left=0, business_data=false,
-- trial_limited=false, ai_enabled=false) — account_state() ko edit nahi
-- karna pada.
create or replace function public.ensure_trial_account_row(_user_id uuid, _social_email text, _provider text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare a public.trial_accounts;
begin
  insert into public.trial_accounts (user_id, social_email, social_provider, status)
  values (_user_id, _social_email, _provider, 'pending_plan')
  on conflict (user_id) do update set social_email = coalesce(excluded.social_email, trial_accounts.social_email),
                                      updated_at = now()
  returning * into a;
  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'signup', jsonb_build_object('provider', _provider, 'email', _social_email))
  on conflict do nothing;
  -- Funnel audit (hardening #6): 'signup' event pehle se tha, lekin woh
  -- generic hai (business+personal dono, trial_start() ke zamane se).
  -- 'pending_plan_entered' specifically batata hai "yeh account ab plan
  -- choose karne ka intezaar kar raha hai" — v_signup_plan_funnel aur
  -- pending_plan_stale() isi par query karte hain.
  insert into public.trial_events (user_id, event_type, detail)
  values (_user_id, 'pending_plan_entered', jsonb_build_object('provider', _provider))
  on conflict do nothing;
  return public.account_state(_user_id);
end $$;

revoke all on function public.ensure_trial_account_row(uuid,text,text) from public, anon, authenticated;
grant execute on function public.ensure_trial_account_row(uuid,text,text) to service_role;
comment on function public.ensure_trial_account_row(uuid,text,text) is
  'E20 (13 Oct 2026): signup plumbing row only, status=pending_plan (NOT a trial clock). Replaces trial_start() at /signup for every kind.';

-- ── 3) personal_workspace_label — 'basic' fallback hataya (E2 override) ───
create or replace function public.personal_workspace_label(_user_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  kind text;
  billed text;
  email text;
begin
  if _user_id is null then return null; end if;

  select lower(nullif(btrim(p.preferences->>'workspace_kind'), ''))
    into kind
  from public.account_profiles p
  where p.user_id = _user_id;

  select u.email into email from auth.users u where u.id = _user_id;

  if to_regclass('public.family_accounts') is not null and email is not null then
    execute $q$
      select plan from public.family_accounts
      where lower(email) = lower($1)
      limit 1
    $q$ into billed using email;
  end if;

  if (billed is null or btrim(billed) = '')
     and to_regclass('public.trial_accounts') is not null then
    execute 'select plan from public.trial_accounts where user_id = $1 limit 1'
      into billed using _user_id;
  end if;

  if (billed is null or btrim(billed) = '')
     and to_regclass('public.entitlement_state') is not null then
    execute $q$
      select plan from public.entitlement_state
      where user_id = $1
      order by updated_at desc nulls last
      limit 1
    $q$ into billed using _user_id;
  end if;

  -- E20: koi bhi real source se plan nahi mila to NULL — kabhi 'basic' mat
  -- fabricate karo. Frontend (plan-surface.ts surfaceFromSession) null ko
  -- "Choose your plan" dikhata hai.
  billed := replace(lower(coalesce(nullif(btrim(billed), ''), '')), '-', '_');
  if billed = '' then
    return null;
  end if;
  if billed = 'businesspro' then billed := 'business_pro'; end if;

  if kind is null then
    if billed in ('basic', 'pro') then
      kind := 'personal';
    else
      return null;
    end if;
  end if;

  if kind <> 'personal' then
    return null;
  end if;

  return public.personal_name_for_polar(billed);
end;
$$;

grant execute on function public.personal_workspace_label(uuid) to authenticated, service_role;
comment on function public.personal_workspace_label(uuid) is
  'E20: returns NULL (never fakes ''basic'') when no real plan exists anywhere for this user — frontend shows "Choose your plan".';

comment on column public.trial_accounts.status is
  'trial|active|expired|frozen|released = Phase 32 lifecycle (unchanged). pending_plan (E20, 13 Oct 2026) = address claimed, no plan chosen/paid yet — NOT a trial, no countdown.';

-- ── 4) MONITORING VIEW — signup → payment funnel, ek nazar mein ──────────
-- service_role-only (business-sensitive aggregate data, awam ko nahi).
-- Founder/dashboard isay query kare: "kitne log pending_plan mein phanse
-- hain, kitne active ho gaye, average kitna time lagta hai."
create or replace view public.v_signup_plan_funnel as
select
  status,
  count(*)                                                              as accounts,
  count(*) filter (where created_at > now() - interval '7 days')        as last_7_days,
  count(*) filter (where created_at > now() - interval '30 days')       as last_30_days,
  round(avg(
    extract(epoch from (coalesce(converted_at, now()) - trial_started_at)) / 3600.0
  )::numeric, 1)                                                        as avg_hours_in_state
from public.trial_accounts
group by status
order by status;

revoke all on public.v_signup_plan_funnel from public, anon, authenticated;
grant select on public.v_signup_plan_funnel to service_role;
comment on view public.v_signup_plan_funnel is
  'E20: signup->payment funnel by trial_accounts.status. service_role only.';

-- ── 5) STALE DETECTOR — read-only, HUMAN decides (Phase 24A philosophy:
-- engine kabhi khud block/act nahi karti, sirf surface karti hai, jaise
-- device_vault "suspicious" marking). Abandoned-checkout accounts flag
-- karta hai taake founder chahe to win-back email bheje — kuch khud nahi
-- karta, kisi ko block/delete/email nahi karta.
create or replace function public.pending_plan_stale(_hours int default 72)
returns table(user_id uuid, anexomail_address text, hours_pending numeric)
language sql stable security definer set search_path = public as $$
  select t.user_id, t.anexomail_address,
         round(extract(epoch from (now() - t.updated_at)) / 3600.0, 1) as hours_pending
  from public.trial_accounts t
  where t.status = 'pending_plan'
    and t.updated_at <= now() - (_hours || ' hours')::interval
  order by t.updated_at asc;
$$;

revoke all on function public.pending_plan_stale(int) from public, anon, authenticated;
grant execute on function public.pending_plan_stale(int) to service_role;
comment on function public.pending_plan_stale(int) is
  'E20: read-only — abandoned-checkout accounts stuck in pending_plan >_hours. Surfaces for a human win-back decision, never auto-acts.';

-- ── 6) one-time backfill — accounts jo PEHLE se is bug ka shikar hain ─────
-- Sirf woh rows jinke paas kahin bhi koi real plan evidence nahi hai (exactly
-- founder ke "Ali Khan" test account jaisa). Ek baar chalta hai, dobara
-- chalane se kuch nahi badalta (already 'pending_plan' wale rows WHERE
-- status='trial' se match hi nahi karte).
update public.trial_accounts t
   set status = 'pending_plan', updated_at = now()
 where t.status = 'trial'
   and t.plan is null
   and (
     to_regclass('public.family_accounts') is null
     or not exists (
       select 1 from public.family_accounts f
        where t.anexomail_address is not null
          and lower(f.email) = lower(t.anexomail_address)
     )
   )
   and (
     to_regclass('public.entitlement_state') is null
     or not exists (select 1 from public.entitlement_state e where e.user_id = t.user_id)
   );

-- Verify (read-only):
-- select user_id, status, plan, anexomail_address from public.trial_accounts
--  where status = 'pending_plan' order by updated_at desc limit 20;
