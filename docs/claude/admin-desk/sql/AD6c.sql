-- AD6c (ADMIN DESK SQL, 22 Nov 2026 PKT): D5a-2 CORRECTION. His FINAL decision F (AWAM-PACKAGES-PROPOSAL-07NOV.md section 6): "The 48-hour trial is the only free entry" -> every package carries trial_days = 2 (48 hours). AD6b had written 0.
-- BUILT ON AD6 + AD6b (schema-first): versions are append-only, so the fix is a NEW version 2 per package (features, limits, grace, sla copied from the current version; effective today). Idempotent: a package whose current version already has trial_days 2 is left alone. One transaction.
BEGIN;
DO $$
DECLARE o uuid; r record; v int;
BEGIN
  SELECT id INTO o FROM desk.fadm_owner WHERE role = 'owner' AND active ORDER BY created_at LIMIT 1;
  IF o IS NULL THEN RAISE EXCEPTION 'AD6c needs the owner row (AD1) to publish as' USING ERRCODE = 'no_data_found'; END IF;
  FOR r IN SELECT p.id AS pkg FROM unnest(ARRAY['basic','pro','business','business_pro','ai_pro','ai_business','ai_executive']) AS p(id) LOOP
    FOR v IN SELECT 1 FROM desk.fadm_pkg_current(r.pkg) c WHERE c.trial_days <> 2 LOOP
      PERFORM desk.fadm_pkg_publish(o, r.pkg, (SELECT title FROM desk.fadm_pkg WHERE pkg_id = r.pkg), current_date, (SELECT features FROM desk.fadm_pkg_current(r.pkg)), (SELECT limits FROM desk.fadm_pkg_current(r.pkg)), 2, (SELECT grace_days FROM desk.fadm_pkg_current(r.pkg)), (SELECT sla_target FROM desk.fadm_pkg_current(r.pkg)), NULL);
    END LOOP;
  END LOOP;
END $$;
COMMIT;
