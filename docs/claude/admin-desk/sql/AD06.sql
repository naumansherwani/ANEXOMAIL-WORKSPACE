-- ==============================================================================================================================
-- AD6 (ADMIN DESK SQL, step 6, 22 Nov 2026 PKT): D5a-2 THE VERSIONED PACKAGE REGISTRY (what each package includes, never what it costs).
-- HIS ORDER: one registry from the landing-page list; package, version, effective date, features, limits, trial and grace rules, SLA target; old subscriptions keep their version; empty until he supplies the list; the Desk shows NO price.
-- BUILT ON (schema-first, read in full): AD2 (fadm_action, fadm_policy, fadm_need, fadm_audit, closed ledger kinds), AD4 (field guard style), AD5 (door pattern).
-- TECHNOLOGY: PostgreSQL forced RLS, append-only version rows (update/delete/truncate refused), CHECKs that refuse any money word in a feature or limit name, SECURITY DEFINER doors with fixed search_path,
--   SHA-256 hash-chained ledger line for every published version. The Rust read door (D5a-3) only reads through fadm_pkg_current / fadm_pkg_versions.
-- RULES: Desk tables only, idempotent, ONE transaction, SELFTEST rolls back (fail P0AG1, success P0AG2). NO price, amount or invoice column exists or can be added by the door.
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('ad6.selftest','info','AD6'),('package.publish','notice','a new package version was published') ON CONFLICT (kind) DO NOTHING;
INSERT INTO desk.fadm_action (action, note) VALUES ('package.publish','publish a new version of a package in the registry') ON CONFLICT (action) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES ('p_package_publish','permit','package.publish','admin') ON CONFLICT (name) DO NOTHING;

CREATE TABLE IF NOT EXISTS desk.fadm_pkg (
  pkg_id text PRIMARY KEY CHECK (pkg_id ~ '^[a-z][a-z0-9_]{1,40}$' AND pkg_id !~* '(price|amount|invoice|card|refund|polar|webhook)'), -- no-money-gate-ok
  title  text NOT NULL CHECK (length(title) BETWEEN 2 AND 60),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS desk.fadm_pkg_version (
  pkg_id text NOT NULL REFERENCES desk.fadm_pkg(pkg_id),
  version int NOT NULL CHECK (version >= 1),
  effective_from date NOT NULL,
  features jsonb NOT NULL CHECK (jsonb_typeof(features) = 'array'),
  limits jsonb NOT NULL CHECK (jsonb_typeof(limits) = 'object'),
  trial_days int NOT NULL DEFAULT 0 CHECK (trial_days BETWEEN 0 AND 365),
  grace_days int NOT NULL CHECK (grace_days BETWEEN 0 AND 365),
  sla_target text CHECK (sla_target IS NULL OR length(sla_target) BETWEEN 3 AND 120),
  published_by uuid NOT NULL REFERENCES desk.fadm_owner(id),
  published_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (pkg_id, version),
  CHECK (NOT (features::text ~* '(price|amount|invoice|card|refund|polar|webhook|payment)')), -- no-money-gate-ok
  CHECK (NOT (limits::text ~* '(price|amount|invoice|card|refund|polar|webhook|payment)')) -- no-money-gate-ok
);
-- limits may only carry the known keys, each a non-negative whole number or null (null = no fixed cap)
CREATE OR REPLACE FUNCTION desk.fadm_pkg_version_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE k text; v jsonb; prev record;
BEGIN
  FOR k, v IN SELECT * FROM jsonb_each(NEW.limits) LOOP
    IF k NOT IN ('storage_gb','seats','attachment_mb','chat_file_mb','mailboxes') THEN RAISE EXCEPTION 'limit % is not on the closed list', k USING ERRCODE = 'check_violation'; END IF;
    IF jsonb_typeof(v) NOT IN ('number','null') OR (jsonb_typeof(v) = 'number' AND (v::text !~ '^[0-9]+$')) THEN RAISE EXCEPTION 'limit % must be a whole number or null', k USING ERRCODE = 'check_violation'; END IF;
  END LOOP;
  IF EXISTS (SELECT 1 FROM jsonb_array_elements(NEW.features) e WHERE jsonb_typeof(e) <> 'string' OR (e #>> '{}') !~ '^[a-z][a-z0-9_.]{1,60}$') THEN RAISE EXCEPTION 'every feature is a short lowercase key' USING ERRCODE = 'check_violation'; END IF;
  SELECT * INTO prev FROM desk.fadm_pkg_version WHERE pkg_id = NEW.pkg_id ORDER BY version DESC LIMIT 1;
  IF FOUND AND (NEW.version <> prev.version + 1 OR NEW.effective_from < prev.effective_from) THEN RAISE EXCEPTION 'a new version is the next number and not earlier than the last one' USING ERRCODE = 'check_violation'; END IF;
  IF NOT FOUND AND NEW.version <> 1 THEN RAISE EXCEPTION 'the first version is 1' USING ERRCODE = 'check_violation'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_pkg_version_00guard ON desk.fadm_pkg_version;
CREATE TRIGGER fadm_pkg_version_00guard BEFORE INSERT ON desk.fadm_pkg_version FOR EACH ROW EXECUTE FUNCTION desk.fadm_pkg_version_guard();
CREATE OR REPLACE FUNCTION desk.fadm_pkg_frozen() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN RAISE EXCEPTION 'a published package version is never edited or removed; publish a new version' USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_pkg_version_frozen ON desk.fadm_pkg_version;
CREATE TRIGGER fadm_pkg_version_frozen BEFORE UPDATE OR DELETE ON desk.fadm_pkg_version FOR EACH ROW EXECUTE FUNCTION desk.fadm_pkg_frozen();
DROP TRIGGER IF EXISTS fadm_pkg_version_frozen_t ON desk.fadm_pkg_version;
CREATE TRIGGER fadm_pkg_version_frozen_t BEFORE TRUNCATE ON desk.fadm_pkg_version FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_pkg_frozen();

-- doors ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_pkg_publish(p_actor uuid, p_pkg text, p_title text, p_effective date, p_features jsonb, p_limits jsonb, p_trial int, p_grace int, p_sla text, p_ip inet DEFAULT NULL) RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE v int;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'package.publish', desk.fadm_unit_id('department','desk'), p_ip);
  INSERT INTO desk.fadm_pkg (pkg_id, title) VALUES (p_pkg, p_title) ON CONFLICT (pkg_id) DO NOTHING;
  SELECT coalesce(max(version), 0) + 1 INTO v FROM desk.fadm_pkg_version WHERE pkg_id = p_pkg;
  INSERT INTO desk.fadm_pkg_version (pkg_id, version, effective_from, features, limits, trial_days, grace_days, sla_target, published_by) VALUES (p_pkg, v, p_effective, p_features, p_limits, p_trial, p_grace, p_sla, p_actor);
  PERFORM desk.fadm_audit(p_actor, 'package.publish', jsonb_build_object('package', p_pkg, 'version', v, 'effective_from', p_effective));
  RETURN v;
END $f$;
-- the version a subscription holds today: the newest version whose effective date has come (a subscription that stays on an older version asks fadm_pkg_versions)
CREATE OR REPLACE FUNCTION desk.fadm_pkg_current(p_pkg text) RETURNS TABLE (pkg_id text, version int, effective_from date, features jsonb, limits jsonb, trial_days int, grace_days int, sla_target text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT v.pkg_id, v.version, v.effective_from, v.features, v.limits, v.trial_days, v.grace_days, v.sla_target FROM desk.fadm_pkg_version v WHERE v.pkg_id = p_pkg AND v.effective_from <= current_date ORDER BY v.version DESC LIMIT 1
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_pkg_versions(p_pkg text) RETURNS TABLE (version int, effective_from date, features jsonb, limits jsonb, trial_days int, grace_days int, sla_target text) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT v.version, v.effective_from, v.features, v.limits, v.trial_days, v.grace_days, v.sla_target FROM desk.fadm_pkg_version v WHERE v.pkg_id = p_pkg ORDER BY v.version
$f$;

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_pkg','fadm_pkg_version'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION desk.fadm_pkg_version_guard(), desk.fadm_pkg_frozen(), desk.fadm_pkg_publish(uuid,text,text,date,jsonb,jsonb,int,int,text,inet), desk.fadm_pkg_current(text), desk.fadm_pkg_versions(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_pkg_publish(uuid,text,text,date,jsonb,jsonb,int,int,text,inet), desk.fadm_pkg_current(text), desk.fadm_pkg_versions(text) TO desk_app;

-- SELFTEST (rolls back; P0AG2 = success) ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad6_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD6 selftest: %', msg USING ERRCODE = 'P0AG1'; END IF; END $f$;
DO $$
DECLARE o uuid; a uuid; sfx text := substr(md5(random()::text), 1, 8); sup uuid := desk.fadm_unit_id('department','desk'); v int; r record;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o6-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a6-' || sfx || '@selftest.invalid', 'Selftest Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a;
  PERFORM desk.fadm_access_grant(o, a, sup, 'agent');
  v := desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date - 10, '["mail.basic","chat.basic"]', '{"storage_gb":50,"seats":10,"attachment_mb":25}', 14, 7, 'first reply in 2 business days', NULL);
  PERFORM pg_temp.ad6_ok(v = 1, 'first version is 1');
  v := desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date - 1, '["mail.basic","chat.basic","crm"]', '{"storage_gb":100,"seats":null}', 14, 7, NULL, NULL);
  PERFORM pg_temp.ad6_ok(v = 2, 'second version is 2');
  v := desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date + 30, '["mail.basic"]', '{"seats":5}', 0, 3, NULL, NULL);
  SELECT * INTO r FROM desk.fadm_pkg_current('selftest_pkg');
  PERFORM pg_temp.ad6_ok(r.version = 2, 'a version that has not started yet is not current');
  PERFORM pg_temp.ad6_ok((SELECT count(*) FROM desk.fadm_pkg_versions('selftest_pkg')) = 3, 'all versions stay readable, old subscriptions keep theirs');
  BEGIN UPDATE desk.fadm_pkg_version SET grace_days = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_pkg_version; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_pkg_version; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date, '["x1"]', '{"price_gbp":5}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN check_violation THEN NULL; END; -- no-money-gate-ok
  BEGIN PERFORM desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date, '["invoice_view"]', '{}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN check_violation THEN NULL; END; -- no-money-gate-ok
  BEGIN PERFORM desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date, '["x1"]', '{"seats":-3}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_pkg_publish(o, 'selftest_pkg', 'Selftest', current_date - 400, '["x1"]', '{}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_pkg_publish(o, 'price_pkg', 'Bad id', current_date, '["x1"]', '{}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN check_violation THEN NULL; END; -- no-money-gate-ok
  BEGIN PERFORM desk.fadm_pkg_publish(a, 'agent_pkg', 'Agent', current_date, '["x1"]', '{}', 0, 1, NULL, NULL); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AG1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad6_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'package.publish' AND detail->>'package' = 'selftest_pkg') = 3, 'every published version is in the ledger');
  PERFORM pg_temp.ad6_ok(NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'desk' AND table_name IN ('fadm_pkg','fadm_pkg_version') AND column_name ~* '(price|amount|invoice|card|refund|currency)'), 'no money column exists'); -- no-money-gate-ok
  PERFORM desk.fadm_audit(o, 'ad6.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad6_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad6_ok(NOT has_table_privilege('desk_app', 'desk.fadm_pkg_version', 'SELECT') AND has_function_privilege('desk_app', 'desk.fadm_pkg_current(text)', 'EXECUTE'), 'desk_app reads only through the doors');
  RAISE EXCEPTION 'AD6 selftest passed, rolling back' USING ERRCODE = 'P0AG2';
EXCEPTION WHEN SQLSTATE 'P0AG2' THEN RAISE NOTICE 'AD6 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
