-- =============================================================================
-- E126 — founder 2 Nov 2026 08:54 PKT (verbatim): "alikhan@ ... yeh seedha delete kero aur masood ko pro business wala do convert kero"
--        + basic.test@ listed as delete-ready and approved in the same message.
-- Idempotent. One transaction (DO block): any failure changes NOTHING.
--   A) masoodsherwani@anexomail.com stays (NEVER deleted): workspace_kind personal -> business (same as humza/raana: org slug family-*), onboarded=true, plan stays 'pro'.
--      resolve_account_kind: pref "business" -> business, so he keeps every Pro feature under the Business ladder and is not pushed through onboarding (he already owns an org).
--   B) basic.test@anexomail.com and alikhan@anexomail.com are deleted: only those two emails, never Masood (hard guard below).
--      Uses the existing E24 engine public.account_purge(user, false, true, false) (it unlocks append-only ledgers like trial_events inside the transaction; first attempt 08:59 failed on trial_events and changed nothing).
--      Then their family_accounts rows. Any refusal aborts the whole step (nothing changed).
-- NOT done here: the real mailboxes on the mail server (Stalwart / files) — separate step after this. Polar customers: none (0 subscriptions).
-- =============================================================================
set search_path = public, extensions;

do $$
declare
  v_masood uuid; v_ids uuid[]; v_n integer; v_rep jsonb; r record;
begin
  perform pg_advisory_xact_lock(hashtextextended('E126:test_accounts', 0));

  select id into v_masood from auth.users where lower(email) = 'masoodsherwani@anexomail.com';
  if v_masood is null then raise exception 'E126: masoodsherwani@anexomail.com not found, stopping'; end if;

  -- A) Masood -> business kind, plan pro
  if to_regclass('public.account_profiles') is not null then
    update public.account_profiles
       set preferences = coalesce(preferences, '{}'::jsonb) || jsonb_build_object('workspace_kind', 'business'), onboarded = true, updated_at = now()
     where user_id = v_masood;
    get diagnostics v_n = row_count;
    raise notice 'E126: Masood profile rows set to business: %', v_n;
  end if;
  if to_regclass('public.family_accounts') is not null then
    update public.family_accounts set plan = 'pro' where lower(email) = 'masoodsherwani@anexomail.com' and plan is distinct from 'pro';
  end if;

  -- B) the two test accounts
  select coalesce(array_agg(id), '{}') into v_ids from auth.users
   where lower(email) in ('basic.test@anexomail.com', 'alikhan@anexomail.com') and id <> v_masood;
  if array_length(v_ids, 1) is null then
    raise notice 'E126: the two test accounts are already gone (idempotent rerun).';
    return;
  end if;

  -- the repo's own purge engine (E24 account_purge): unlocks the immutable ledgers (trial_events etc.) inside this transaction, removes the user's rows and the orgs where
  -- the user is the ONLY member, then deletes auth.users. skip_grace = true (test accounts). Any refusal (blocked / storage files / not found) aborts everything.
  for r in select id, email from auth.users where id = any(v_ids) loop
    v_rep := public.account_purge(r.id, false, true, false);
    if coalesce((v_rep->>'ok')::boolean, false) is not true then
      raise exception 'E126: account_purge refused % : %', r.email, v_rep::text;
    end if;
    raise notice 'E126: purged %', r.email;
  end loop;
  if to_regclass('public.family_accounts') is not null then
    delete from public.family_accounts where lower(email) in ('basic.test@anexomail.com', 'alikhan@anexomail.com');
  end if;

  select count(*) into v_n from auth.users where id = any(v_ids);
  if v_n > 0 then raise exception 'E126: % account(s) still exist after purge', v_n; end if;
end $$;
