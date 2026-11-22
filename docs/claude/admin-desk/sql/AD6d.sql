-- AD6d (ADMIN DESK SQL, 22 Nov 2026 PKT): D5a-2 CORRECTION to the awam blueprint (his 22:19 word: read the awam blueprint, the pull stays unaccepted until it is right).
-- 1) The AI packages (ai_pro, ai_business, ai_executive) belong to the AI product ai.anexomail.com (July 2027); the awam side and so the Desk must not carry them (AWAM-BLUEPRINT-ALPHABETIC section A.5). Registry rows are append-only, so they are RETIRED (not deleted) and leave the list.
-- 2) The registry lists exactly what the live landing page (anexomail.com/plans, read in my Chrome 22 Nov 22:2x PKT) offers: Basic, Pro, Business, Business Pro. Business Premium and Business Max are decided (AWAM-PACKAGES-PROPOSAL section 6, G4, G5) but are NOT on the landing page yet; they are added by a later AD file the day the landing page shows them.
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
COMMIT;
