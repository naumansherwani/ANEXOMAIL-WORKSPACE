-- ==============================================================================================================================
-- AD4 (ADMIN DESK SQL, step 4, 22 Nov 2026 PKT): THE COMPANY LOOKUP AUDIT = D5a-4 (every look at a customer company leaves a reason and an append-only line).
-- HIS ORDER (22 Nov 10:10 approved, 10:27 subphases): the Desk shows a company only through a signed read-only lookup to his Control Plane; the employee types a reason; the look is recorded BEFORE any data is shown; no copy of the customer data is kept.
-- BUILT ON (SCHEMA-FIRST LAW, read in full before writing): AD1 (fadm_owner, fadm_ledger + chain + fadm_ledger_verify), AD2 (fadm_audit, fadm_ledger_kind closed list, fadm_action + fadm_policy, fadm_need, fadm_burst_limit + fadm_burst_hit breaker),
--   AD3 (fadm_append_only_guard, the p_installer RLS pattern, the schema-wide function re-grant). AD4 adds NOTHING to those tables; it only adds rows to the closed lists and its own tables.
-- CONTRACT: docs/claude/admin-desk/gates/DESK-LOOKUP-CONTRACT.json (allowed fields; money fields are forbidden by name; the commit gate DESK NO-MONEY reads the same file).
-- TECHNOLOGY: PostgreSQL forced ROW LEVEL SECURITY, SECURITY DEFINER doors with fixed search_path, append-only event table with guard triggers, SHA-256 hash-chained ledger line per look, per-person burst breaker (bulk viewing freezes the account),
--   deny-by-default authorisation (customer.lookup needs the agent relation). The Rust door (D5a-3) calls begin BEFORE it sends the signed request and finish after the answer.
-- RULES: Desk tables only (fadm_*), no extension, no superuser needed, idempotent, ONE transaction, SELFTEST rolls its own rows back (fail SQLSTATE P0AE4, success exit P0AE5), desk_app gets EXECUTE on the doors and NEVER direct table rights.
--   DESK ISOLATION: no founder or awam object is read or written. The company is held only as an opaque reference (letters, digits, - and _), never a name, an address or an amount.
-- HONEST NOTES: (1) AD4 records WHO looked at WHICH company, WHY, WHICH fields; it stores none of the answer. (2) The signed request itself is the Rust door (D5a-3). (3) A look that the Control Plane could not answer is recorded as unavailable, never as answered.
-- ==============================================================================================================================
BEGIN;

-- 1) CLOSED LEDGER KINDS --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad4.selftest','info','AD4'),('lookup.company','notice','a company was opened with a reason'),('lookup.unavailable','notice','the control plane did not answer a lookup')
ON CONFLICT (kind) DO NOTHING;

-- 2) ACTION, POLICY, BULK-VIEW BREAKER ------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_action (action, note) VALUES ('customer.lookup','open a customer company with a reason') ON CONFLICT (action) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES ('p_customer_lookup','permit','customer.lookup','agent') ON CONFLICT (name) DO NOTHING;
INSERT INTO desk.fadm_burst_limit (action, max_per_min) VALUES ('customer.lookup', 30) ON CONFLICT (action) DO NOTHING;

-- 3) THE CLOSED LIST OF FIELDS A LOOKUP MAY ASK (same names as DESK-LOOKUP-CONTRACT.json allowed_fields) -----------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_field (
  field text PRIMARY KEY CHECK (field ~ '^[a-z_]{3,48}$' AND field !~* '(amount|invoice|card|cvv|refund|transaction|iban|bank|polar|webhook|price|payment_method)'),  -- no-money-gate-ok
  note text
);
INSERT INTO desk.fadm_lookup_field (field, note) VALUES
  ('package_id','package'),('package_version','package version'),('package_effective_from','version start'),('features_included','what the package includes'),('features_enabled','what is actually on'),
  ('limit_storage','storage limit'),('limit_seats','seat limit'),('limit_attachment','attachment limit'),('usage_storage','storage used'),('usage_seats','seats used'),('service_state','active, not active yet, grace, suspended, setting up'),
  ('payment_received_service_not_active','the one safe flag'),('payment_flag_since','since when'),('grace_days_left','grace days'),('suspension_class','SR1..SR8'),('suspension_since','since when'),('sla_target','plan target'),('data_freshness','age of the answer')
ON CONFLICT (field) DO NOTHING;

-- 4) THE LOOKUP EVENTS: append-only; a look is first 'requested' (before any data), later ONE of answered / unavailable / refused -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ts          timestamptz NOT NULL DEFAULT now(),
  employee_id uuid NOT NULL REFERENCES desk.fadm_owner(id),
  company_ref text NOT NULL CHECK (company_ref ~ '^[A-Za-z0-9_-]{6,64}$'),
  reason      text NOT NULL CHECK (length(btrim(reason)) BETWEEN 10 AND 300 AND reason !~ '[\r\n]'),
  fields      text[] NOT NULL CHECK (cardinality(fields) BETWEEN 1 AND 20),
  request_id  uuid NOT NULL,
  outcome     text NOT NULL CHECK (outcome IN ('requested','answered','unavailable','refused')),
  UNIQUE (request_id, outcome)
);
CREATE INDEX IF NOT EXISTS fadm_lookup_company_idx ON desk.fadm_lookup (company_ref, ts DESC);
CREATE INDEX IF NOT EXISTS fadm_lookup_employee_idx ON desk.fadm_lookup (employee_id, ts DESC);
CREATE OR REPLACE FUNCTION desk.fadm_lookup_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE bad text;
BEGIN
  SELECT f INTO bad FROM unnest(NEW.fields) AS f WHERE NOT EXISTS (SELECT 1 FROM desk.fadm_lookup_field x WHERE x.field = f) LIMIT 1;
  IF bad IS NOT NULL THEN RAISE EXCEPTION 'field % is not on the closed lookup list', bad USING ERRCODE = 'check_violation'; END IF;
  IF NEW.outcome <> 'requested' AND NOT EXISTS (SELECT 1 FROM desk.fadm_lookup r WHERE r.request_id = NEW.request_id AND r.outcome = 'requested' AND r.employee_id = NEW.employee_id AND r.company_ref = NEW.company_ref)
    THEN RAISE EXCEPTION 'no answer without a recorded request' USING ERRCODE = 'check_violation'; END IF;
  IF NEW.outcome IN ('answered','unavailable','refused') AND EXISTS (SELECT 1 FROM desk.fadm_lookup r WHERE r.request_id = NEW.request_id AND r.outcome <> 'requested')
    THEN RAISE EXCEPTION 'this request already has its result' USING ERRCODE = 'check_violation'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_lookup_00guard ON desk.fadm_lookup;
CREATE TRIGGER fadm_lookup_00guard BEFORE INSERT ON desk.fadm_lookup FOR EACH ROW EXECUTE FUNCTION desk.fadm_lookup_guard();
DROP TRIGGER IF EXISTS fadm_lookup_frozen ON desk.fadm_lookup;
CREATE TRIGGER fadm_lookup_frozen BEFORE UPDATE OR DELETE ON desk.fadm_lookup FOR EACH ROW EXECUTE FUNCTION desk.fadm_append_only_guard();
DROP TRIGGER IF EXISTS fadm_lookup_frozen_t ON desk.fadm_lookup;
CREATE TRIGGER fadm_lookup_frozen_t BEFORE TRUNCATE ON desk.fadm_lookup FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_append_only_guard();
ALTER FUNCTION desk.fadm_append_only_guard() SECURITY DEFINER;

-- 5) THE DOORS -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- begin: permission, bulk-view breaker (returns NULL when frozen), the request line (BEFORE any data is asked), the ledger line
CREATE OR REPLACE FUNCTION desk.fadm_lookup_begin(p_actor uuid, p_company_ref text, p_reason text, p_fields text[], p_request_id uuid, p_ip inet DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE root uuid := desk.fadm_unit_id('department', 'desk'); n bigint;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'customer.lookup', root, p_ip);
  IF NOT desk.fadm_burst_hit(p_actor, 'customer.lookup') THEN RETURN NULL; END IF;   -- NULL = refused and the account is frozen (an exception here would roll the freeze back)
  INSERT INTO desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) VALUES (p_actor, p_company_ref, btrim(p_reason), p_fields, p_request_id, 'requested') RETURNING id INTO n;
  PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', p_company_ref, 'reason', btrim(p_reason), 'fields', to_jsonb(p_fields), 'request', p_request_id));
  RETURN n;
END $f$;
-- finish: the result of that request (answered, unavailable, refused); an unavailable answer is also a ledger line
CREATE OR REPLACE FUNCTION desk.fadm_lookup_finish(p_actor uuid, p_request_id uuid, p_outcome text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record;
BEGIN
  IF p_outcome NOT IN ('answered','unavailable','refused') THEN RAISE EXCEPTION 'unknown outcome %', p_outcome USING ERRCODE = 'check_violation'; END IF;
  SELECT * INTO r FROM desk.fadm_lookup WHERE request_id = p_request_id AND outcome = 'requested' AND employee_id = p_actor;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such request for this person' USING ERRCODE = 'no_data_found'; END IF;
  INSERT INTO desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) VALUES (r.employee_id, r.company_ref, r.reason, r.fields, r.request_id, p_outcome);
  IF p_outcome = 'unavailable' THEN PERFORM desk.fadm_audit(p_actor, 'lookup.unavailable', jsonb_build_object('company', r.company_ref, 'request', p_request_id)); END IF;
END $f$;
-- history: who looked at this company, why, which fields (needs audit.read)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_history(p_actor uuid, p_company_ref text, p_limit integer DEFAULT 50, p_ip inet DEFAULT NULL)
RETURNS TABLE (ts timestamptz, employee text, reason text, fields text[], outcome text, request_id uuid) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  RETURN QUERY SELECT l.ts, o.display_name, l.reason, l.fields, l.outcome, l.request_id FROM desk.fadm_lookup l JOIN desk.fadm_owner o ON o.id = l.employee_id
    WHERE l.company_ref = p_company_ref ORDER BY l.ts DESC, l.id DESC LIMIT least(greatest(p_limit, 1), 200);
END $f$;

-- 6) RLS AND GRANTS (same pattern as AD3: the installer role owns, desk_app has no table right, only the doors) -------------------------------------------------------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_lookup_field','fadm_lookup'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION desk.fadm_lookup_guard(), desk.fadm_lookup_begin(uuid,text,text,text[],uuid,inet), desk.fadm_lookup_finish(uuid,uuid,text), desk.fadm_lookup_history(uuid,text,integer,inet) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_lookup_begin(uuid,text,text,text[],uuid,inet), desk.fadm_lookup_finish(uuid,uuid,text), desk.fadm_lookup_history(uuid,text,integer,inet) TO desk_app;

-- 7) SELFTEST: every rule against real rows, then ROLLS ITSELF BACK (P0AE5 is the success exit). Any gap FAILS the whole file. ---------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad4_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD4 selftest: %', msg USING ERRCODE = 'P0AE4'; END IF; END $f$;
DO $$
DECLARE o uuid; s uuid; j uuid; sfx text := substr(md5(random()::text), 1, 8); rq uuid := gen_random_uuid(); rq2 uuid := gen_random_uuid(); n int; k int;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('department','desk'); cref text := 'co_' || sfx;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o1-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('s-' || sfx || '@selftest.invalid', 'Selftest Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO s;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('j-' || sfx || '@selftest.invalid', 'Selftest Joiner', 'agent', NULL, true, 'active', true) RETURNING id INTO j;
  PERFORM desk.fadm_access_grant(o, s, sup, 'agent');
  -- a person with no relation cannot look (deny by default)
  BEGIN PERFORM desk.fadm_lookup_begin(j, cref, 'customer says mail is missing', ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- the agent looks: request line and ledger line appear BEFORE any answer
  PERFORM pg_temp.ad4_ok(desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['package_id','service_state','usage_storage'], rq) IS NOT NULL, 'an agent can open a company with a reason');
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_lookup WHERE request_id = rq AND outcome = 'requested') = 1, 'the request line exists before any answer');
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'request' = rq::text AND detail->>'reason' = 'customer says mail is missing') = 1, 'the look leaves a hash-chained ledger line with the reason');
  -- reason rules
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'short', ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, E'two\nlines of reason here', ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, repeat('x', 301), ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- company reference is opaque
  BEGIN PERFORM desk.fadm_lookup_begin(s, 'Acme Ltd, 10 High Street', 'customer says mail is missing', ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- money and unknown fields are refused, by the closed list and by the name rule
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['amount_cents'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;  -- no-money-gate-ok
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['service_state','invoice_url'], gen_random_uuid()); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;  -- no-money-gate-ok
  BEGIN INSERT INTO desk.fadm_lookup_field (field) VALUES ('card_number'); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;  -- no-money-gate-ok
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY[]::text[], gen_random_uuid()); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- the same request id cannot be opened twice
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['service_state'], rq); RAISE EXCEPTION 'no refusal 10' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN unique_violation THEN NULL; END;
  -- result: only for a recorded request, only once, only by the same person
  BEGIN PERFORM desk.fadm_lookup_finish(s, gen_random_uuid(), 'answered'); RAISE EXCEPTION 'no refusal 11' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN no_data_found THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_finish(o, rq, 'answered'); RAISE EXCEPTION 'no refusal 12' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN no_data_found THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_finish(s, rq, 'maybe'); RAISE EXCEPTION 'no refusal 13' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_lookup_finish(s, rq, 'answered');
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_lookup WHERE request_id = rq) = 2, 'a request has exactly its request line and its result');
  BEGIN PERFORM desk.fadm_lookup_finish(s, rq, 'unavailable'); RAISE EXCEPTION 'no refusal 14' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN check_violation OR unique_violation THEN NULL; END;
  -- control plane down: recorded as unavailable and in the ledger, never as answered
  PERFORM desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['service_state'], rq2);
  PERFORM desk.fadm_lookup_finish(s, rq2, 'unavailable');
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_lookup WHERE request_id = rq2 AND outcome = 'answered') = 0 AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.unavailable' AND detail->>'request' = rq2::text) = 1, 'an outage is recorded as unavailable');
  -- append-only
  BEGIN UPDATE desk.fadm_lookup SET reason = 'changed after the fact' WHERE request_id = rq; RAISE EXCEPTION 'no refusal 15' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_lookup WHERE request_id = rq; RAISE EXCEPTION 'no refusal 16' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_lookup; RAISE EXCEPTION 'no refusal 17' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- history: who looked at this company needs audit.read (an agent cannot, the owner can)
  BEGIN PERFORM * FROM desk.fadm_lookup_history(s, cref); RAISE EXCEPTION 'no refusal 18' USING ERRCODE = 'P0AE4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  SELECT count(*) INTO n FROM desk.fadm_lookup_history(o, cref);
  PERFORM pg_temp.ad4_ok(n = 4, 'the history shows who looked, why, which fields (two request lines, answered, unavailable)');
  -- bulk viewing breaker: the 31st look in one minute freezes the agent
  FOR k IN 1..28 LOOP PERFORM desk.fadm_lookup_begin(s, cref, 'bulk viewing selftest ' || k, ARRAY['service_state'], gen_random_uuid()); END LOOP;
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_lookup WHERE employee_id = s AND outcome = 'requested') = 30, 'thirty lookups in a minute pass');
  PERFORM pg_temp.ad4_ok(desk.fadm_lookup_begin(s, cref, 'bulk viewing selftest 31', ARRAY['service_state'], gen_random_uuid()) IS NULL, 'the 31st look in a minute is refused (NULL)');
  PERFORM pg_temp.ad4_ok((SELECT count(*) FROM desk.fadm_lookup WHERE employee_id = s AND outcome = 'requested') = 30, 'a refused look leaves no request line');
  PERFORM pg_temp.ad4_ok((SELECT status FROM desk.fadm_owner WHERE id = s) = 'suspended', 'the 31st look in a minute freezes the account');
  -- closed ledger and privileges
  PERFORM desk.fadm_audit(o, 'ad4.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad4_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad4_ok(NOT has_table_privilege('desk_app', 'desk.fadm_lookup', 'INSERT') AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup_field', 'UPDATE'), 'desk_app has no direct right on the lookup tables');
  PERFORM pg_temp.ad4_ok(has_function_privilege('desk_app', 'desk.fadm_lookup_begin(uuid,text,text,text[],uuid,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_lookup_finish(uuid,uuid,text)', 'EXECUTE')
    AND has_function_privilege('desk_app', 'desk.fadm_bridge_summary(uuid,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_session_lookup(bytea)', 'EXECUTE'), 'the lookup doors are granted and the older doors kept their grant');
  RAISE EXCEPTION 'AD4 selftest passed, rolling back' USING ERRCODE = 'P0AE5';
EXCEPTION WHEN SQLSTATE 'P0AE5' THEN RAISE NOTICE 'AD4 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
