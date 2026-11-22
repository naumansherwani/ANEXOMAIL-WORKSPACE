-- AD6d (ADMIN DESK SQL, 22 Nov 2026 PKT): D5a-2 CORRECTION to the awam blueprint (his 22:19 word: read the awam blueprint, the pull stays unaccepted until it is right).
-- 1) The AI packages (ai_pro, ai_business, ai_executive) belong to the AI product ai.anexomail.com (July 2027); the awam side and so the Desk must not carry them (AWAM-BLUEPRINT-ALPHABETIC section A.5). Registry rows are append-only, so they are RETIRED (not deleted) and leave the list.
-- 2) The awam ladder is Basic, Pro, Business, Business Pro, Business Premium, Business Max (AW0, AW0 FINAL line, AWAM-PACKAGES-PROPOSAL section 6 + G4 + G5). Premium and Max get version 1: Premium 7,000 users, 70 TB, 100 MB attachment, 4 GB chat file; Max card unlimited with a STRICT 125,000-user cap (limit 125000), 250 TB, 250 MB, 10 GB (his * values still to be verified).
-- BUILT ON AD6 + AD6b + AD6c (schema-first, read in full). No money word. One transaction, idempotent.
BEGIN;
ALTER TABLE desk.fadm_pkg ADD COLUMN IF NOT EXISTS retired_at timestamptz;
ALTER TABLE desk.fadm_pkg ADD COLUMN IF NOT EXISTS retired_reason text CHECK (retired_reason IS NULL OR length(retired_reason) BETWEEN 5 AND 300);
CREATE OR REPLACE FUNCTION desk.fadm_pkg_list() RETURNS TABLE (pkg_id text, title text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT p.pkg_id, p.title FROM desk.fadm_pkg p WHERE p.retired_at IS NULL ORDER BY coalesce(array_position(ARRAY['basic','pro','business','business_pro','business_premium','business_max'], p.pkg_id), 99), p.pkg_id
$f$;
REVOKE ALL ON FUNCTION desk.fadm_pkg_list() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_pkg_list() TO desk_app;
UPDATE desk.fadm_pkg SET retired_at = now(), retired_reason = 'AI product (ai.anexomail.com, July 2027): not part of the awam packages or the Desk' WHERE pkg_id IN ('ai_pro','ai_business','ai_executive') AND retired_at IS NULL;
DO $$
DECLARE o uuid; bp jsonb; v int;
BEGIN
  SELECT id INTO o FROM desk.fadm_owner WHERE role = 'owner' AND active ORDER BY created_at LIMIT 1;
  IF o IS NULL THEN RAISE EXCEPTION 'AD6d needs the owner row (AD1) to publish as' USING ERRCODE = 'no_data_found'; END IF;
  SELECT features INTO bp FROM desk.fadm_pkg_current('business_pro');
  IF bp IS NULL THEN RAISE EXCEPTION 'AD6d needs business_pro (AD6b) first' USING ERRCODE = 'no_data_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_version WHERE pkg_id = 'business_premium') THEN
    v := desk.fadm_pkg_publish(o, 'business_premium', 'Business Premium', current_date,
      bp || '["monthly_outbound_pool_350tb","anexochat_file_up_to_4gb","company_creates_mailboxes_for_its_users","mailboxes_on_the_company_own_domain"]'::jsonb,
      '{"seats": 7000, "storage_gb": 70000, "attachment_mb": 100, "chat_file_mb": 4096}'::jsonb, 2, 3, NULL, NULL);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_version WHERE pkg_id = 'business_max') THEN
    v := desk.fadm_pkg_publish(o, 'business_max', 'Business Max', current_date,
      bp || '["monthly_outbound_pool_500tb","anexochat_file_up_to_10gb","company_creates_mailboxes_for_its_users","mailboxes_on_the_company_own_domain","panel_shows_unlimited_users_strict_cap_125000","near_cap_alert_90_yellow_95_high_never_blocked"]'::jsonb,
      '{"seats": 125000, "storage_gb": 250000, "attachment_mb": 250, "chat_file_mb": 10240}'::jsonb, 2, 3, NULL, NULL);
  END IF;
END $$;
COMMIT;
