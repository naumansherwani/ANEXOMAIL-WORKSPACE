
-- =============================================================================
-- E23 — payment ke baad account KHUD active ho (#20 ka wiring).
-- Supabase #4 SQL Editor mein poori file paste -> Run. Idempotent.
--
-- WAJAH (14 Oct 2026, E20 audit): E20 ne pending_plan account ko /app se bahar
-- (/plans par) rakha — theek. Lekin payment ke baad us status ko 'active' karne
-- wala koi bhi hissa wired nahi tha:
--   * billing_apply_entitlement() sirf entitlement_state likhta hai.
--   * trial_subscribe() (Phase 32) kisi payment path se call hi nahi hota tha.
--   * Express route POST /api/trial/subscribe sirf `payment_ref != ""` dekhti thi
--     — koi bhi login user kisi bhi string ke saath apna plan khud 'active' kar
--     sakta tha, bina payment (server/routes/trial.ts — us route ko E23 band
--     karta hai, neeche).
-- Natija: asli paisa dene ke baad bhi user /plans par wapas bounce hota.
--
-- FIX (sirf wahan jahan paisa VERIFIED hai):
--   billing_intent_confirm() amount + currency + product match check karta hai,
--   phir billing_apply_entitlement() entitlement_state.plan likhta hai. Us row
--   par ek AFTER trigger: plan set hua -> trial_accounts (pending_plan/trial)
--   ko trial_subscribe() se 'active'. £0 / mismatch payment entitlement tak
--   pohanchti hi nahi, to account bhi active nahi hota (guard ka matlab barqarar).
--   Trigger payment ko kabhi nahi rokta: koi bhi error -> sirf WARNING, entitlement
--   ka write waise hi commit.
-- Webhook / polar_inbox_apply / Rust engine / Phase 50 SQL ko haath nahi.
-- =============================================================================
set search_path = public, extensions;

-- 1) ek hi jagah jo account ko 'active' karti hai (sirf pending_plan / trial)
create or replace function public.activate_paid_account(_user uuid, _plan text, _ref text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if _user is null or _plan is null then return false; end if;
  if _plan not in ('basic','pro','business','business_pro') then return false; end if;
  if not exists (
    select 1 from public.trial_accounts
     where user_id = _user and status in ('pending_plan','trial')
  ) then
    return false;   -- active / expired / frozen / released ko yahan nahi chheda jata
  end if;
  perform public.trial_subscribe(_user, _plan, _ref);
  return true;
end $$;

revoke all on function public.activate_paid_account(uuid,text,text) from public, anon, authenticated;
grant execute on function public.activate_paid_account(uuid,text,text) to service_role;
comment on function public.activate_paid_account(uuid,text,text) is
  'E23: verified-payment entitlement -> trial_accounts pending_plan/trial => active (via trial_subscribe). No-op for every other status.';

-- 2) trigger function — kabhi payment ko fail nahi karta
create or replace function public.trg_entitlement_activates_account()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  begin
    perform public.activate_paid_account(
      new.user_id, new.plan, 'entitlement:' || coalesce(new.source_intent::text, ''));
  exception when others then
    raise warning 'E23 activate_paid_account failed for %: %', new.user_id, sqlerrm;
  end;
  return null;
end $$;

drop trigger if exists entitlement_activates_account_trg on public.entitlement_state;
create trigger entitlement_activates_account_trg
  after insert or update of plan on public.entitlement_state
  for each row
  when (new.plan is not null)
  execute function public.trg_entitlement_activates_account();

-- 3) client plan/payment_ref par bharosa nahi: sirf entitlement_state se
--    (POST /api/trial/subscribe ab yahi call karta hai)
create or replace function public.trial_activate_if_paid(_user uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare p text;
begin
  select e.plan into p
    from public.entitlement_state e
   where e.user_id = _user
     and e.plan is not null
     and (e.active_until is null or e.active_until > now())
   limit 1;
  if p is null then
    return jsonb_build_object('ok', false, 'error', 'no_verified_payment');
  end if;
  perform public.activate_paid_account(_user, p, 'entitlement:poke');
  return jsonb_build_object('ok', true, 'state', public.account_state(_user));
end $$;

revoke all on function public.trial_activate_if_paid(uuid) from public, anon, authenticated;
grant execute on function public.trial_activate_if_paid(uuid) to service_role;

-- 4) pehle se paid (entitlement hai) lekin pending_plan mein atke accounts
select public.activate_paid_account(e.user_id, e.plan, 'e23_backfill') as activated, e.user_id
  from public.entitlement_state e
  join public.trial_accounts t on t.user_id = e.user_id
 where t.status = 'pending_plan'
   and e.plan is not null
   and (e.active_until is null or e.active_until > now());

-- VERIFY (paste karke dekho)
-- select tgname from pg_trigger where tgname = 'entitlement_activates_account_trg';  -- 1 row
-- select to_regprocedure('public.trial_activate_if_paid(uuid)');                      -- naam aaye
