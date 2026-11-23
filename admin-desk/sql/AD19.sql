-- AD19 (phase 1m-9, card B9c Plan catalogue + live plan updates, list BL-28, step Y5), 24 Nov 2026 02:3x PKT. THE ADVANCED VERSION (world-class SQL every time).
-- SCHEMA-FIRST: AD06 (fadm_pkg, fadm_pkg_version: append-only versions, closed limit list, frozen guard, fadm_pkg_publish, fadm_pkg_current), AD06b (the four published packages, idempotent seed style), AD06d (fadm_pkg_list order of the six packages), AD14 (fadm_customers_begin: hands the seat promise of each package to the Control Plane; its loop knew only FOUR packages), AD18 (a release raises NOTIFY desk_plans at COMMIT, so THIS release is also the live one-second proof Y6). Nothing older is edited.
-- ADVANCE-RESEARCH: [1m] 1m-9 Y5 Premium and Max seat promises join the over-limit count. The six package keys live in ONE immutable function (single source of truth, so a list in one place can never drift from another, the Zendesk plan and agent seat usage idea of one catalogue feeding every count). The two packages are published through the SAME append-only versioned registry as the other four (a release, never an edit; fingerprint + NOTIFY come from AD18). Only values the founder FINALISED are published: Business Premium 7,000 users (his 7 Nov section 6 A, FINAL) and Business Max strict backend cap 125,000 users per company (his 8 Nov G4). Storage, transfer and file limits of the two are NOT published because they are starred recommendations not yet verified (Hetzner egress), and no feature list is invented: the landing page list holds four packages only.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD19-check.sql
-- WHAT IT ADDS: (1) fadm_pkg_keys(): the six package keys in display order. (2) Version 1 of business_premium (seats 7000) and business_max (seats 125000), published as the owner, only when the package has no version yet (idempotent). (3) fadm_customers_begin now hands over the seat promise of ALL SIX packages (4 before), same right check, same one throttled ledger line. No new table, no new grant: desk_app keeps only the two doors it had.
BEGIN;
CREATE OR REPLACE FUNCTION desk.fadm_pkg_keys() RETURNS text[] LANGUAGE sql IMMUTABLE PARALLEL SAFE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT ARRAY['basic','pro','business','business_pro','business_premium','business_max']::text[]
$f$;
COMMENT ON FUNCTION desk.fadm_pkg_keys() IS 'AD19: the six package keys in display order, the one list every seat-promise count reads';

DO $$
DECLARE o uuid; v int;
BEGIN
  SELECT id INTO o FROM desk.fadm_owner WHERE role = 'owner' AND active ORDER BY created_at LIMIT 1;
  IF o IS NULL THEN RAISE EXCEPTION 'AD19 needs the owner row (AD1) to publish as' USING ERRCODE = 'no_data_found'; END IF;
  -- Business Premium: 7,000 users (his 7 Nov 2026 section 6 A, FINAL). Limits: seats only; the other Premium limits are starred, unverified recommendations.
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_version WHERE pkg_id = 'business_premium') THEN
    v := desk.fadm_pkg_publish(o, 'business_premium', 'Business Premium', current_date, '[]'::jsonb, '{"seats":7000}'::jsonb, 0, 3, NULL);
  END IF;
  -- Business Max: strict cap 125,000 users per company in the backend and in SQL (his 8 Nov 2026 G4); the card says unlimited, the cap is the promise the count uses.
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_version WHERE pkg_id = 'business_max') THEN
    v := desk.fadm_pkg_publish(o, 'business_max', 'Business Max', current_date, '[]'::jsonb, '{"seats":125000}'::jsonb, 0, 3, NULL);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION desk.fadm_customers_begin(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE r jsonb := '{}'::jsonb; k text; s text;
BEGIN
  IF NOT desk.fadm_census_allowed(p_actor) THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE actor = p_actor AND kind = 'lookup.company' AND detail->>'company' = '(census)' AND ts > now() - interval '10 minutes') THEN
    PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', '(census)', 'reason', 'customers and plans board opened', 'fields', '[]'::jsonb));
  END IF;
  FOREACH k IN ARRAY desk.fadm_pkg_keys() LOOP
    SELECT c.limits->>'seats' INTO s FROM desk.fadm_pkg_current(k) c;
    IF s IS NOT NULL AND s ~ '^[0-9]{1,6}$' THEN r := r || jsonb_build_object(k, s::int); END IF;
  END LOOP;
  RETURN r;
END $f$;
COMMENT ON FUNCTION desk.fadm_customers_begin(uuid) IS 'AD14 + AD19: right check, one throttled ledger line, the seat promise of all six packages (list from fadm_pkg_keys)';
REVOKE ALL ON FUNCTION desk.fadm_pkg_keys(), desk.fadm_customers_begin(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_customers_begin(uuid) TO desk_app;

CREATE FUNCTION pg_temp.ad19_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD19 selftest: %', msg USING ERRCODE = 'P0AS1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; r jsonb; k text;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o19-' || sfx || '@selftest.invalid', 'AD19 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a19-' || sfx || '@selftest.invalid', 'AD19 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  PERFORM pg_temp.ad19_ok(cardinality(desk.fadm_pkg_keys()) = 6 AND desk.fadm_pkg_keys() = ARRAY(SELECT l.pkg_id FROM desk.fadm_pkg_list() l WHERE l.pkg_id = ANY (desk.fadm_pkg_keys())), 'the six keys are the live package list in the same order');
  PERFORM pg_temp.ad19_ok(desk.fadm_customers_begin(a1) IS NULL AND desk.fadm_customers_begin(gen_random_uuid()) IS NULL, 'a person without the right and an unknown person get NULL');
  r := desk.fadm_customers_begin(o);
  PERFORM pg_temp.ad19_ok(jsonb_typeof(r) = 'object' AND (r->>'business_premium')::int = 7000 AND (r->>'business_max')::int = 125000, 'Premium 7000 and Max 125000 are in the seat promise');
  FOR k IN SELECT jsonb_object_keys(r) LOOP
    PERFORM pg_temp.ad19_ok(k = ANY (desk.fadm_pkg_keys()), 'only the six closed keys are handed over');
    PERFORM pg_temp.ad19_ok((r->>k)::int = (SELECT (c.limits->>'seats')::int FROM desk.fadm_pkg_current(k) c), 'every promise equals the live registry version');
  END LOOP;
  PERFORM pg_temp.ad19_ok(NOT has_function_privilege('desk_app', 'desk.fadm_pkg_keys()', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_customers_begin(uuid)', 'EXECUTE'), 'desk_app keeps the one door it had and gets nothing new');
  PERFORM pg_temp.ad19_ok((SELECT count(*) FROM desk.fadm_pkg_version WHERE pkg_id IN ('business_premium','business_max')) >= 2, 'both new packages have a published version');
  PERFORM pg_temp.ad19_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD19 selftest passed, rolling back' USING ERRCODE = 'P0AS2';
EXCEPTION WHEN SQLSTATE 'P0AS2' THEN RAISE NOTICE 'AD19 selftest: ALL RULES PASSED (selftest rows rolled back)';
END $$;
COMMIT;
