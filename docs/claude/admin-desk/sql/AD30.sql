-- AD30 (phase 1m B13 step T2, CASE-TO-TENANT BINDING), 24 Nov 2026 PKT. His saved decision (TENANT-IDENTITY-CONSENT-DECISION-24NOV.md, outside advisor, 07:16): a case gets ONE immutable tenant UUID; free text company_ref is a hint only; no consent request until the case is bound. Desk database ONLY (schema desk). T1 (AD26, the registry that proves a UUID is a real tenant and owns a domain) is GREEN; T3 (automatic resolution) and T4 (manual second reviewer UI) come after.
-- SCHEMA-FIRST: read before writing: AD07 (desk.fadm_case: id uuid, ref, company_ref free text, no tenant column), AD20 (desk.fadm_consent_request: the function that starts a consent request, its checks, the audit line), AD02 (desk.fadm_owner, desk.fadm_audit, the CLOSED kind list desk.fadm_ledger_kind, fadm_authorize rights case.read / case.assign), AD01 (hash-chained ledger), AD26 (cp.domain_ownership lives in the AWAM database, so no foreign key may cross databases: the tenant UUID is proved by the Rust side against the Control Plane, this file stores and protects the binding).
-- ADVANCE-RESEARCH: [1m] B13 T2 (24 Nov 2026 web search + his advisor text): tenant-isolation designs bind the tenant id to the record once, enforce it in the database (not only in application code), keep the binding append-only and tamper-evident with a hash-chained audit line, and make a correction a separate, dual-approved, audited act that never edits history (Iru multi-tenant isolation notes, PostgreSQL tamper-evident audit-trail write-ups, composite-key tenant enforcement); this file does exactly that: UNIQUE (case) so a second binding is impossible, three freeze triggers, evidence shape closed, manual source needs a SECOND person, and the consent door refuses an unbound case.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD30-check.sql
-- WHAT IT ADDS (AD01..AD29 unchanged except ONE function body: fadm_consent_request now refuses a case with no binding): desk.fadm_case_binding (one row per case, forever), kinds 'case.bound' and 'case.bind_refused' on the closed ledger list, desk.fadm_case_bind(...) (the only writer), desk.fadm_case_tenant(case ref) (read, NULL = unresolved), desk.fadm_consent_request (same checks as AD20 plus the binding rule).
-- WHO MAY WRITE: sources 'verified_domain' and 'verified_member' are written by the Desk service itself after T3 proved them against the Control Plane (actor NULL = the system); source 'manual_exception' needs an active staff actor with the right case.assign AND a DIFFERENT active staff reviewer with the right case.assign (two people, never one). A correction of a wrong binding is NOT here: it is a later dual-approved procedure (T5) that adds a new row type, never an UPDATE.
-- HONEST LIMITS: this file proves "this case is bound to this UUID by this source, by these people, at this time". That the UUID is a real tenant is proved by T1 + the Rust door (Control Plane check) before it calls fadm_case_bind; the database cannot reach the awam database.
CREATE TABLE IF NOT EXISTS desk.fadm_case_binding (
  case_id    uuid PRIMARY KEY REFERENCES desk.fadm_case(id),
  tenant_id  uuid NOT NULL,
  source     text NOT NULL CHECK (source IN ('verified_domain', 'verified_member', 'manual_exception')),
  actor      uuid REFERENCES desk.fadm_owner(id),
  reviewer   uuid REFERENCES desk.fadm_owner(id),
  evidence   jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(evidence) = 'object' AND octet_length(evidence::text) <= 2000),
  bound_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT fadm_case_binding_manual_two_people CHECK (source <> 'manual_exception' OR (actor IS NOT NULL AND reviewer IS NOT NULL AND actor <> reviewer)),
  CONSTRAINT fadm_case_binding_auto_is_system CHECK (source = 'manual_exception' OR (actor IS NULL AND reviewer IS NULL))
);
CREATE INDEX IF NOT EXISTS fadm_case_binding_tenant ON desk.fadm_case_binding (tenant_id, bound_at DESC);
ALTER TABLE desk.fadm_case_binding ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_case_binding FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_case_binding FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_case_binding' AND policyname = 'p_binding_none') THEN
    CREATE POLICY p_binding_none ON desk.fadm_case_binding FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;
CREATE OR REPLACE FUNCTION desk.fadm_case_binding_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION 'desk.fadm_case_binding is immutable (% refused): a bound case never changes tenant', TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_case_binding_frozen ON desk.fadm_case_binding;
CREATE TRIGGER fadm_case_binding_frozen BEFORE UPDATE OR DELETE ON desk.fadm_case_binding FOR EACH ROW EXECUTE FUNCTION desk.fadm_case_binding_frozen();
DROP TRIGGER IF EXISTS fadm_case_binding_frozen_t ON desk.fadm_case_binding;
CREATE TRIGGER fadm_case_binding_frozen_t BEFORE TRUNCATE ON desk.fadm_case_binding FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_case_binding_frozen();

INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('case.bound', 'notice', 'B13 T2: a case was bound to one tenant'), ('case.bind_refused', 'high', 'B13 T2: a binding was refused') ON CONFLICT (kind) DO NOTHING;

CREATE OR REPLACE FUNCTION desk.fadm_case_bind(p_case text, p_tenant uuid, p_source text, p_actor uuid, p_reviewer uuid, p_evidence jsonb) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE c record; why text;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF NOT FOUND THEN RETURN false; END IF;
  p_evidence := COALESCE(p_evidence, '{}'::jsonb);
  IF p_tenant IS NULL THEN why := 'no_tenant';
  ELSIF p_source NOT IN ('verified_domain', 'verified_member', 'manual_exception') THEN why := 'bad_source';
  ELSIF jsonb_typeof(p_evidence) <> 'object' OR octet_length(p_evidence::text) > 2000 THEN why := 'bad_evidence';
  ELSIF EXISTS (SELECT 1 FROM desk.fadm_case_binding WHERE case_id = c.id) THEN why := 'already_bound';
  ELSIF p_source = 'manual_exception' AND (p_actor IS NULL OR p_reviewer IS NULL OR p_actor = p_reviewer) THEN why := 'two_people_needed';
  ELSIF p_source = 'manual_exception' AND (SELECT count(*) FROM desk.fadm_owner o WHERE o.id IN (p_actor, p_reviewer) AND o.status = 'active') <> 2 THEN why := 'not_active_staff';
  ELSIF p_source = 'manual_exception' AND NOT (COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'case.assign', desk.fadm_unit_id('department', 'desk'), NULL)), false) AND COALESCE((SELECT allowed FROM desk.fadm_authorize(p_reviewer, 'case.assign', desk.fadm_unit_id('department', 'desk'), NULL)), false)) THEN why := 'no_right';
  ELSIF p_source <> 'manual_exception' AND (p_actor IS NOT NULL OR p_reviewer IS NOT NULL) THEN why := 'auto_is_system';
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(p_actor, 'case.bind_refused', jsonb_build_object('case', p_case, 'why', why, 'source', left(COALESCE(p_source, '-'), 20)));
    RETURN false;
  END IF;
  INSERT INTO desk.fadm_case_binding (case_id, tenant_id, source, actor, reviewer, evidence) VALUES (c.id, p_tenant, p_source, p_actor, p_reviewer, p_evidence);
  PERFORM desk.fadm_audit(p_actor, 'case.bound', jsonb_build_object('case', p_case, 'tenant', p_tenant, 'source', p_source, 'reviewer', p_reviewer));
  RETURN true;
END $f$;
COMMENT ON FUNCTION desk.fadm_case_bind(text, uuid, text, uuid, uuid, jsonb) IS 'AD30: the ONLY writer of a case-to-tenant binding; refusals are ledger lines; manual source needs two different active staff with case.assign.';

CREATE OR REPLACE FUNCTION desk.fadm_case_tenant(p_case text) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT b.tenant_id FROM desk.fadm_case c JOIN desk.fadm_case_binding b ON b.case_id = c.id WHERE c.ref = p_case
$f$;
COMMENT ON FUNCTION desk.fadm_case_tenant(text) IS 'AD30: the tenant UUID a case is bound to, NULL = unresolved (consent requests stay closed).';

CREATE OR REPLACE FUNCTION desk.fadm_consent_request(p_actor uuid, p_case text, p_scope text, p_reason text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE c record; id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN RAISE EXCEPTION 'not allowed: not an active staff person' USING ERRCODE = 'insufficient_privilege'; END IF;
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such case' USING ERRCODE = 'no_data_found'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_case_binding WHERE case_id = c.id) THEN RAISE EXCEPTION 'the case is not bound to a company yet' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF c.restricted AND p_scope = 'content' THEN RAISE EXCEPTION 'a restricted case never opens its content' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (SELECT count(*) FROM desk.fadm_consent WHERE requested_by = p_actor AND status = 'requested') >= 5 THEN RAISE EXCEPTION 'too many requests are waiting' USING ERRCODE = 'insufficient_privilege'; END IF;
  INSERT INTO desk.fadm_consent (case_id, requested_by, scope, reason) VALUES (c.id, p_actor, p_scope, p_reason) RETURNING fadm_consent.id INTO id;
  PERFORM desk.fadm_audit(p_actor, 'consent.requested', jsonb_build_object('consent', id, 'case', c.ref, 'scope', p_scope));
  RETURN id;
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_case_bind(text, uuid, text, uuid, uuid, jsonb), desk.fadm_case_tenant(text) FROM PUBLIC;
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
  GRANT EXECUTE ON FUNCTION desk.fadm_case_bind(text, uuid, text, uuid, uuid, jsonb), desk.fadm_case_tenant(text) TO desk_app;
END IF; END $g$;

-- SELFTEST (rolls back; success is the exception P0AT2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad30_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD30 selftest: %', msg USING ERRCODE = 'P0AT1'; END IF; END $f$;
DO $$
DECLARE sfx text := substr(md5(random()::text), 1, 8); adr text; a1 uuid; a2 uuid; a3 uuid; cref text; t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid(); n0 bigint; ok boolean; r boolean;
BEGIN
  SELECT local_part INTO adr FROM desk.fadm_address LIMIT 1;
  PERFORM pg_temp.ad30_ok(adr IS NOT NULL, 'a mailbox address exists to hang test cases on');
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a30a-' || sfx || '@selftest.invalid', 'AD30 A', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a30b-' || sfx || '@selftest.invalid', 'AD30 B', 'agent', NULL, true, 'UTC') RETURNING id INTO a2;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad30a-' || sfx, 'AD30 case A') RETURNING ref INTO cref;
  PERFORM pg_temp.ad30_ok(desk.fadm_case_tenant(cref) IS NULL, 'a new case is unresolved');
  BEGIN PERFORM desk.fadm_consent_request(a1, cref, 'metadata', 'AD30 selftest reason is long enough'); RAISE EXCEPTION 'no refusal' USING ERRCODE = 'P0AT1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  SELECT count(*) INTO n0 FROM desk.fadm_ledger;
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t1, 'manual_exception', a1, a1, '{}'::jsonb), 'one person cannot be actor and reviewer');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t1, 'manual_exception', a1, NULL, '{}'::jsonb), 'manual needs a reviewer');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t1, 'verified_domain', a1, NULL, '{}'::jsonb), 'an automatic source is written by the system, not a person');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t1, 'guess', NULL, NULL, '{}'::jsonb), 'an unknown source is refused');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, NULL, 'verified_domain', NULL, NULL, '{}'::jsonb), 'no tenant is refused');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t1, 'verified_domain', NULL, NULL, '[1]'::jsonb), 'evidence must be an object');
  PERFORM pg_temp.ad30_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'case.bind_refused') >= 6 AND (SELECT count(*) FROM desk.fadm_ledger) >= n0 + 6, 'every refusal is a ledger line');
  PERFORM pg_temp.ad30_ok(desk.fadm_case_tenant(cref) IS NULL, 'refusals bound nothing');
  PERFORM pg_temp.ad30_ok(desk.fadm_case_bind(cref, t1, 'verified_domain', NULL, NULL, jsonb_build_object('domain', 'example.com')), 'the system binds a verified-domain case');
  PERFORM pg_temp.ad30_ok(desk.fadm_case_tenant(cref) = t1, 'the case now has its tenant');
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t2, 'verified_domain', NULL, NULL, '{}'::jsonb) AND desk.fadm_case_tenant(cref) = t1, 'a second binding (another tenant) is refused: already_bound');
  BEGIN UPDATE desk.fadm_case_binding SET tenant_id = t2; RAISE EXCEPTION 'no refusal u' USING ERRCODE = 'P0AT1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_case_binding; RAISE EXCEPTION 'no refusal d' USING ERRCODE = 'P0AT1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_case_binding; RAISE EXCEPTION 'no refusal t' USING ERRCODE = 'P0AT1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad30_ok(desk.fadm_consent_request(a1, cref, 'metadata', 'AD30 selftest reason is long enough') IS NOT NULL, 'a bound case may start a consent request');
  -- a second case: manual exception, two different active staff; they need the case.assign right, so grant nothing: without the right it must be refused
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad30b-' || sfx, 'AD30 case B') RETURNING ref INTO cref;
  PERFORM pg_temp.ad30_ok(NOT desk.fadm_case_bind(cref, t2, 'manual_exception', a1, a2, '{}'::jsonb), 'two people WITHOUT the case.assign right are refused');
  PERFORM pg_temp.ad30_ok(desk.fadm_case_tenant(cref) IS NULL, 'still unresolved');
  PERFORM pg_temp.ad30_ok(desk.fadm_ledger_verify(), 'the hash chain verifies after all of it');
  PERFORM pg_temp.ad30_ok(has_function_privilege('desk_app', 'desk.fadm_case_bind(text,uuid,text,uuid,uuid,jsonb)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_case_bind(text,uuid,text,uuid,uuid,jsonb)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_case_binding', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_case_binding', 'INSERT')
    AND (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_case_binding'::regclass), 'desk_app can call the doors only; the table is forced RLS and closed');
  RAISE EXCEPTION 'AD30 selftest passed, rolling back' USING ERRCODE = 'P0AT2';
EXCEPTION WHEN SQLSTATE 'P0AT2' THEN RAISE NOTICE 'AD30 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
