-- =============================================================================
-- E20 ROLLBACK — agar E20_personal_plan_pending.sql ki wajah se kuch toot
-- jaye, isay Supabase #4 SQL Editor mein paste → Run karo. Poora wapis
-- purani (E20-se-pehle) state par.
--
-- JAAN-BUJH KAR ALAG FILE: migration aur rollback kabhi ek saath paste na
-- ho, warna galti se dono chal jayen aur kuch na badle.
--
-- SQL-SIDE ONLY: yeh sirf database wapis karta hai. `server/routes/auth.ts`
-- (ensure_trial_account_row call, has_chosen_plan) aur frontend
-- (claim.tsx → /plans, app.tsx redirect, plan-surface.ts label) application
-- code hai — woh git revert se wapis hoga:
--   git log --oneline -- server/routes/auth.ts src/routes/claim.tsx
--   git revert <E20 commit sha>
-- Is file ko chalane ke baad agar application code E20 wala hi reh gaya
-- (git revert nahi kiya), to naya signup phir se `ensure_trial_account_row`
-- call karega — jo yahan dropped hone ke baad error dega. Isliye: SQL
-- rollback + app code revert HAMESHA SAATH mein.
-- =============================================================================
set search_path = public, extensions;

-- ── 1) pending_plan rows ko wapis 'trial' par le aao (status + clock) ────
-- NOTE: trial_ends_at purana hi reh jata hai (E20 ne usay chhua nahi tha),
-- lekin agar woh ab guzar chuka hai, account_state() khud 'expired' bana
-- dega — yeh behaviour E20-se-pehle bhi waisa hi tha, correct hai.
update public.trial_accounts
   set status = 'trial', updated_at = now()
 where status = 'pending_plan';

-- ── 2) naye constraints/index hatao, purane wapis ─────────────────────────
alter table public.trial_accounts drop constraint if exists trial_accounts_pending_plan_no_plan_check;

alter table public.trial_accounts drop constraint if exists trial_accounts_status_check;
alter table public.trial_accounts add constraint trial_accounts_status_check
  check (status in ('trial','active','expired','frozen','released'));

alter table public.trial_events drop constraint if exists trial_events_event_type_check;
alter table public.trial_events add constraint trial_events_event_type_check
  check (event_type = any (array[
    'signup','claim','passkey_set','recovery_set','warn_24h','warn_2h',
    'expired','subscribed','frozen','released','mail_hold','recovery_used',
    'workspace_provisioned'
  ]::text[]));

drop index if exists trial_events_once_idx;
create unique index trial_events_once_idx
  on public.trial_events (user_id, event_type)
  where event_type in ('signup','claim','passkey_set','recovery_set','warn_24h','warn_2h','expired','frozen','released');

-- 'pending_plan_entered' events audit trail mein chhod diye (immutable
-- ledger, trigger unhe delete hone nahi deta — yeh sahi hai, history kabhi
-- erase nahi honi chahiye) — sirf naye events ab iss type ke nahi banenge.

-- ── 3) naye objects drop ──────────────────────────────────────────────────
drop function if exists public.pending_plan_stale(int);
drop view if exists public.v_signup_plan_funnel;

-- ── 4) personal_workspace_label() — E2 ki original 'basic' fallback wapis ─
create or replace function public.personal_workspace_label(_user_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  kind text;
  billed text := 'basic';
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

  billed := replace(lower(coalesce(nullif(btrim(billed), ''), 'basic')), '-', '_');
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

-- ── 5) ensure_trial_account_row — drop (purana trial_start() phase32 mein
-- khud maujood hai, dobara banane ki zaroorat nahi, bas is naye wrapper ko
-- hatao taake confusion na ho) ──────────────────────────────────────────────
drop function if exists public.ensure_trial_account_row(uuid, text, text);

-- Verify (read-only):
-- select conname from pg_constraint where conname like 'trial_accounts%check';
-- select proname from pg_proc where proname in
--   ('ensure_trial_account_row','pending_plan_stale','personal_workspace_label');
