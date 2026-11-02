-- =============================================================================
-- E125 — Personal packages retired (founder 2 Nov 2026 08:14-08:28: "root se delete ... final ... nobody has bought one").
-- Idempotent. Safe parts ONLY. Founder PX0 list (2 Nov 08:36): 18 accounts, 3 personal-kind (masoodsherwani@, basic.test@, alikhan@), 0 paid subscriptions.
--   1. The 3 Personal rows of personal_polar_map (E2) are removed, so no account is ever shown a "Personal X" label again (personal_workspace_label() then returns NULL = no label; the function stays, the session code calls it).
--   2. The 6 Personal products in billing_price_book (E13) are switched off, then deleted if nothing references them (if something does, they stay switched off and the file says so).
--   3. masoodsherwani@anexomail.com is kept and his plan is made sure to be 'pro' (he already is). His workspace kind is NOT touched: a Basic/Pro workspace without an organisation is "personal" kind inside the plan engine, and
--      that engine also serves the Business ladder (Basic / Pro). Changing it would push him through business onboarding; that is a separate decision.
--   4. NO account is deleted here (see CHECK_PX0B_TEST_FOOTPRINT + E126 after the founder's explicit yes for the two test accounts).
-- Not touched on purpose: billing_personal_product_guard() trigger (harmless: it only fires for PERSONAL keys), personal_workspace_label() / personal_name_for_polar() (the login session calls them).
-- Needs: nothing new. Reads/changes: personal_polar_map, billing_price_book, family_accounts. Every step skips when its table is not there.
-- =============================================================================
set search_path = public, extensions;

do $$
declare v_n integer; v_deleted integer := 0; v_kept integer := 0; r record;
begin
  perform pg_advisory_xact_lock(hashtextextended('E125:retire_personal', 0));

  -- 1) the Personal label map
  if to_regclass('public.personal_polar_map') is not null then
    delete from public.personal_polar_map;
    get diagnostics v_n = row_count;
    raise notice 'E125: personal_polar_map rows removed: %', v_n;
  end if;

  -- 2) the 6 Personal products
  if to_regclass('public.billing_price_book') is not null then
    update public.billing_price_book set active = false, polar_listed = false, updated_at = now() where product_key like 'POLAR_PRODUCT_PLAN_PERSONAL_%';
    for r in select product_key from public.billing_price_book where product_key like 'POLAR_PRODUCT_PLAN_PERSONAL_%' loop
      begin
        delete from public.billing_price_book where product_key = r.product_key;
        v_deleted := v_deleted + 1;
      exception when foreign_key_violation then
        v_kept := v_kept + 1;
        raise notice 'E125: % is still referenced; kept switched off (active=false)', r.product_key;
      end;
    end loop;
    raise notice 'E125: Personal price-book rows deleted % / kept off %', v_deleted, v_kept;
  end if;

  -- 3) Masood: keep, on Pro
  if to_regclass('public.family_accounts') is not null then
    update public.family_accounts set plan = 'pro' where lower(email) = 'masoodsherwani@anexomail.com' and plan is distinct from 'pro';
    get diagnostics v_n = row_count;
    raise notice 'E125: masoodsherwani plan set to pro on % row(s) (0 = already pro)', v_n;
  end if;
end $$;
