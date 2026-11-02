-- =============================================================================
-- E126 — founder 2 Nov 2026 08:54 PKT (verbatim): "alikhan@ ... yeh seedha delete kero aur masood ko pro business wala do convert kero"
--        + basic.test@ listed as delete-ready and approved in the same message.
-- Idempotent. One transaction (DO block): any failure changes NOTHING.
--   A) masoodsherwani@anexomail.com stays (NEVER deleted): workspace_kind personal -> business (same as humza/raana: org slug family-*), onboarded=true, plan stays 'pro'.
--      resolve_account_kind: pref "business" -> business, so he keeps every Pro feature under the Business ladder and is not pushed through onboarding (he already owns an org).
--   B) basic.test@anexomail.com and alikhan@anexomail.com are deleted: only those two emails, never Masood (hard guard below).
--      Rows blocking the delete (foreign keys with NO ACTION / RESTRICT) are removed first, generically, for auth.users and for the organisations they own.
--      Their family_accounts rows and mail_accounts rows are removed too. If a blocker cannot be removed automatically the whole step aborts with its name (nothing changed).
-- NOT done here: the real mailboxes on the mail server (Stalwart / files) — separate step after this. Polar customers: none (0 subscriptions).
-- =============================================================================
set search_path = public, extensions;

do $$
declare
  v_masood uuid; v_ids uuid[]; v_orgs uuid[]; v_n integer; r record;
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

  select coalesce(array_agg(id), '{}') into v_orgs from public.organisations where owner_id = any(v_ids);

  -- children of the organisations they own (FK NO ACTION / RESTRICT only; CASCADE ones go by themselves)
  for r in select c.conrelid::regclass::text as tbl, a.attname as col
           from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.contype = 'f' and c.confrelid = 'public.organisations'::regclass and array_length(c.conkey, 1) = 1 and c.confdeltype in ('a', 'r') loop
    execute format('delete from %s where %I = any($1)', r.tbl, r.col) using v_orgs;
    get diagnostics v_n = row_count;
    if v_n > 0 then raise notice 'E126: % (%): % rows removed', r.tbl, r.col, v_n; end if;
  end loop;
  if to_regclass('public.mail_accounts') is not null then
    delete from public.mail_accounts where org_id = any(v_orgs) or lower(address) in ('basic.test@anexomail.com', 'alikhan@anexomail.com');
  end if;
  delete from public.organisations where id = any(v_orgs);

  -- rows blocking auth.users
  for r in select c.conrelid::regclass::text as tbl, a.attname as col
           from pg_constraint c join pg_attribute a on a.attrelid = c.conrelid and a.attnum = c.conkey[1]
           where c.contype = 'f' and c.confrelid = 'auth.users'::regclass and array_length(c.conkey, 1) = 1 and c.confdeltype in ('a', 'r') loop
    execute format('delete from %s where %I = any($1)', r.tbl, r.col) using v_ids;
    get diagnostics v_n = row_count;
    if v_n > 0 then raise notice 'E126: % (%): % rows removed', r.tbl, r.col, v_n; end if;
  end loop;
  if to_regclass('public.family_accounts') is not null then
    delete from public.family_accounts where lower(email) in ('basic.test@anexomail.com', 'alikhan@anexomail.com');
  end if;

  delete from auth.users where id = any(v_ids) and id <> v_masood;
  get diagnostics v_n = row_count;
  raise notice 'E126: auth.users deleted: %', v_n;
end $$;
