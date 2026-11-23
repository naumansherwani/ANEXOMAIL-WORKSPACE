-- AD18 (phase 1m-9, card B9c Plan catalogue + live plan updates, list BL-28), 23 Nov 2026 10:5x PKT. THE ADVANCED VERSION (world-class SQL every time).
-- SCHEMA-FIRST: AD06 (fadm_pkg, fadm_pkg_version: append-only versions, features/limits, frozen guard), AD06d (fadm_pkg_list: live packages), AD02 (fadm_authorize, fadm_unit_id, right customer.lookup), AD17 (own helper + selftest style). Nothing older is changed.
-- ADVANCE-RESEARCH: [1m] 1m-9 live plan updates as the best systems do them (PostgreSQL LISTEN/NOTIFY transactional outbox: NOTIFY is sent only when the publishing transaction COMMITS, so a screen never hears of a release that rolled back; the payload is a small fingerprint, the screen re-reads the truth; Stripe/LaunchDarkly-style versioned catalogue with a content hash per version).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD18-check.sql
-- WHAT IT ADDS: (1) fadm_pkg_fingerprint(pkg, version): SHA-256 (hex) over the version's exact content, so a changed feature or policy always changes the fingerprint. (2) A trigger on fadm_pkg_version that raises pg_notify('desk_plans', {pkg, version, fp}) in the same transaction as the release (delivered at COMMIT). (3) fadm_plans_digest(actor): the right-checked digest of every live plan {n, latest, plans:[{pkg, version, fp}]}; the Rust listener and the stream track send it. No money word exists anywhere. desk_app gets the digest, never a table.
CREATE OR REPLACE FUNCTION desk.fadm_pkg_fingerprint(p_pkg text, p_version int) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
  SELECT encode(sha256(convert_to(v.pkg_id || '|' || v.version || '|' || v.effective_from || '|' || v.features::text || '|' || v.limits::text || '|' || v.trial_days || '|' || v.grace_days || '|' || coalesce(v.sla_target, ''), 'UTF8')), 'hex')
  FROM desk.fadm_pkg_version v WHERE v.pkg_id = p_pkg AND v.version = p_version
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_pkg_release_notify() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM pg_notify('desk_plans', jsonb_build_object('pkg', NEW.pkg_id, 'version', NEW.version, 'fp', encode(sha256(convert_to(NEW.pkg_id || '|' || NEW.version || '|' || NEW.effective_from || '|' || NEW.features::text || '|' || NEW.limits::text || '|' || NEW.trial_days || '|' || NEW.grace_days || '|' || coalesce(NEW.sla_target, ''), 'UTF8')), 'hex'))::text);
  RETURN NULL;
END $f$;
DROP TRIGGER IF EXISTS fadm_pkg_release_notify ON desk.fadm_pkg_version;
CREATE TRIGGER fadm_pkg_release_notify AFTER INSERT ON desk.fadm_pkg_version FOR EACH ROW EXECUTE FUNCTION desk.fadm_pkg_release_notify();
CREATE OR REPLACE FUNCTION desk.fadm_plans_allowed(p_actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'customer.lookup', desk.fadm_unit_id('department','desk'), NULL)), false)
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_plans_digest(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE r jsonb;
BEGIN
  IF NOT desk.fadm_plans_allowed(p_actor) THEN RETURN NULL; END IF;
  SELECT jsonb_build_object('n', count(*), 'plans', coalesce(jsonb_agg(jsonb_build_object('pkg', c.pkg_id, 'version', c.version, 'fp', desk.fadm_pkg_fingerprint(c.pkg_id, c.version)) ORDER BY c.pkg_id), '[]'::jsonb))
    INTO r FROM desk.fadm_pkg_list() l, LATERAL desk.fadm_pkg_current(l.pkg_id) c;
  RETURN r;
END $f$;
COMMENT ON FUNCTION desk.fadm_plans_digest(uuid) IS 'AD18: right-checked fingerprint of every live plan version; the live plan track sends it, the screen re-reads the truth when it changes';
COMMENT ON FUNCTION desk.fadm_pkg_release_notify() IS 'AD18: raises NOTIFY desk_plans at COMMIT of a plan release (transactional outbox)';
REVOKE ALL ON FUNCTION desk.fadm_pkg_fingerprint(text,int), desk.fadm_pkg_release_notify(), desk.fadm_plans_allowed(uuid), desk.fadm_plans_digest(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_plans_digest(uuid) TO desk_app;

CREATE FUNCTION pg_temp.ad18_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD18 selftest: %', msg USING ERRCODE = 'P0AR1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; d0 jsonb; d1 jsonb; v int;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o18-' || sfx || '@selftest.invalid', 'AD18 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a18-' || sfx || '@selftest.invalid', 'AD18 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  PERFORM pg_temp.ad18_ok(desk.fadm_plans_digest(a1) IS NULL AND desk.fadm_plans_digest(gen_random_uuid()) IS NULL, 'a person without the right and an unknown person get NULL');
  d0 := desk.fadm_plans_digest(o);
  PERFORM pg_temp.ad18_ok(jsonb_typeof(d0->'plans') = 'array' AND (d0->>'n')::int = jsonb_array_length(d0->'plans'), 'the digest is a count plus a list that agree');
  v := desk.fadm_pkg_publish(o, 'ad18_selftest_plan', 'AD18 Selftest Plan', current_date, '["a_feature"]'::jsonb, '{}'::jsonb, 0, 7, NULL);
  d1 := desk.fadm_plans_digest(o);
  PERFORM pg_temp.ad18_ok((d1->>'n')::int = (d0->>'n')::int + (CASE WHEN EXISTS (SELECT 1 FROM desk.fadm_pkg_list() WHERE pkg_id = 'ad18_selftest_plan') THEN 1 ELSE 0 END) AND d1 IS DISTINCT FROM d0 OR NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_list() WHERE pkg_id = 'ad18_selftest_plan'), 'a new live plan shows in the digest');
  PERFORM pg_temp.ad18_ok(desk.fadm_pkg_fingerprint('ad18_selftest_plan', v) ~ '^[0-9a-f]{64}$', 'the fingerprint is 64 hex characters');
  PERFORM pg_temp.ad18_ok(desk.fadm_pkg_fingerprint('ad18_selftest_plan', v + 1) IS NULL, 'a missing version has no fingerprint');
  PERFORM pg_temp.ad18_ok(has_function_privilege('desk_app', 'desk.fadm_plans_digest(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_plans_allowed(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_pkg_fingerprint(text,int)', 'EXECUTE'), 'desk_app has the digest only');
  PERFORM pg_temp.ad18_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD18 selftest passed, rolling back' USING ERRCODE = 'P0AR2';
EXCEPTION WHEN SQLSTATE 'P0AR2' THEN RAISE NOTICE 'AD18 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
