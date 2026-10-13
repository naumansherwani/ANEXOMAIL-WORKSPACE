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
-- Fail = isi file ko theek likho. E20b / _fix / _v2 banned.
-- =============================================================================
set search_path = public, extensions;

-- ── 1) naya status value: 'pending_plan' ──────────────────────────────────
alter table public.trial_accounts drop constraint if exists trial_accounts_status_check;
alter table public.trial_accounts add constraint trial_accounts_status_check
  check (status in ('trial','active','expired','frozen','released','pending_plan'));

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
  return public.account_state(_user_id);
end $$;

revoke all on function public.ensure_trial_account_row(uuid,text,text) from public, anon, authenticated;
grant execute on function public.ensure_trial_account_row(uuid,text,text) to service_role;

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

-- ── 4) one-time backfill — accounts jo PEHLE se is bug ka shikar hain ─────
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
