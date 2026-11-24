-- AD32 (phase 1m B13 step T3b, SENDER-RESOLVE ATTEMPT LOG), 24 Nov 2026 PKT. T3a (AD31, awam database) answers "which company is this sender?" with ONE word; T3b (Rust: Control Plane door /control/v1/resolve, Desk client resolve_cp.rs) asks it over HTTP/3. This file is the Desk's own tamper-evident memory of every attempt: who asked for which case, when, with what outcome. Desk database ONLY (schema desk).
-- SCHEMA-FIRST: read before writing: AD30 (desk.fadm_case_binding + desk.fadm_case_bind: the binding this verdict later feeds; freeze-trigger pattern), AD02 (desk.fadm_audit, the CLOSED kind list desk.fadm_ledger_kind with severities info|notice|high), AD01 (hash-chained ledger), AD07 (desk.fadm_case: id uuid, ref), AD31 (the six verdict words: resolved, shared, unknown, ambiguous, multi_member, unaligned; a tenant UUID exists exactly when resolved).
-- ADVANCE-RESEARCH: [1m] B13 T3b (24 Nov 2026 web search, his order 11:04 "RFC 9421, IETF WIMSE HTTP-signature draft, RFC 7489, OWASP Logging: ek bhi nahi chodo"): (1) RFC 9421 HTTP Message Signatures: a signature covers created, expires, nonce, key id, a tag and the request target; our door signs issued_at/expires_at (60 s), request_id (nonce + replay cache), kid, aud (tag) and, new in T3b, the path. (2) IETF WIMSE workload-to-workload HTTP signature draft (draft-ietf-wimse-http-signature): service-to-service calls are signed by the workload's own key, short lived, bound to the target, replay refused; the Control Plane and the Desk are two such workloads over HTTP/3. (3) RFC 7489 DMARC identifier alignment: a sender is trusted as a domain only if SPF or DKIM passed AND the authenticated domain aligns with the From domain; the Folder 2 mail door will pass that fact as the required boolean "aligned" (never defaulted), AD31 refuses to resolve an unaligned sender. (4) OWASP Logging Cheat Sheet: log who, what, when, outcome for successes AND failures; keep the log tamper-evident; never log personal data or secrets: this file has NO parameter for an address or a domain, so the ledger can only ever hold the case ref, the request id, a closed outcome, the verdict word and the tenant UUID.
-- DECISION-READ: docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (read in full: hybrid A+B+controlled C, shared domains never auto-match, two claimants = quarantine, multi-membership needs explicit selection, tenant UUID immutable per case; this file only RECORDS what the Control Plane answered, it binds nothing and grants nothing)
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD32-check.sql
-- WHAT IT ADDS (AD01..AD31 unchanged): desk.fadm_resolve_attempt (one row per signed request, forever, append-only), ledger kinds 'sender.resolved' (info) and 'sender.resolve_failed' (notice), desk.fadm_resolve_log(...) (the only writer, idempotent), desk.fadm_case_resolution(case ref) (read: the latest attempt of a case, for the Folder 3 case card in T3d).
-- IDEMPOTENT + CONCURRENCY-SAFE: the request id is the primary key; the same attempt reported twice is a success that writes nothing; the same request id with DIFFERENT content is refused and changes nothing; two parallel reports of one request queue on a per-request advisory lock.
-- HONEST LIMITS: this file proves "the Desk asked about this case and the Control Plane's verified answer was this word at this time". It does NOT bind the case: binding (AD30 fadm_case_bind, source verified_domain / verified_member) is step T3c, which has the sender from the Folder 2 mail door.
CREATE TABLE IF NOT EXISTS desk.fadm_resolve_attempt (
  request_id uuid PRIMARY KEY,
  case_id    uuid NOT NULL REFERENCES desk.fadm_case(id),
  outcome    text NOT NULL CHECK (outcome IN ('answered', 'unavailable', 'refused', 'invalid')),
  verdict    text CHECK (verdict IN ('resolved', 'shared', 'unknown', 'ambiguous', 'multi_member', 'unaligned')),
  tenant_id  uuid,
  at         timestamptz NOT NULL DEFAULT clock_timestamp(),   -- the real moment of the attempt, so two attempts in one transaction still order
  CONSTRAINT fadm_resolve_attempt_verdict_only_when_answered CHECK ((outcome = 'answered') = (verdict IS NOT NULL)),
  CONSTRAINT fadm_resolve_attempt_tenant_only_when_resolved CHECK ((verdict = 'resolved') = (tenant_id IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS fadm_resolve_attempt_case ON desk.fadm_resolve_attempt (case_id, at DESC);
ALTER TABLE desk.fadm_resolve_attempt ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_resolve_attempt FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_resolve_attempt FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_resolve_attempt' AND policyname = 'p_resolve_none') THEN
    CREATE POLICY p_resolve_none ON desk.fadm_resolve_attempt FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;
CREATE OR REPLACE FUNCTION desk.fadm_resolve_attempt_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION 'desk.fadm_resolve_attempt is append-only (% refused): an attempt is history', TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_resolve_attempt_frozen ON desk.fadm_resolve_attempt;
CREATE TRIGGER fadm_resolve_attempt_frozen BEFORE UPDATE OR DELETE ON desk.fadm_resolve_attempt FOR EACH ROW EXECUTE FUNCTION desk.fadm_resolve_attempt_frozen();
DROP TRIGGER IF EXISTS fadm_resolve_attempt_frozen_t ON desk.fadm_resolve_attempt;
CREATE TRIGGER fadm_resolve_attempt_frozen_t BEFORE TRUNCATE ON desk.fadm_resolve_attempt FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_resolve_attempt_frozen();

INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('sender.resolved', 'info', 'B13 T3b: the Control Plane answered a sender-resolve request (verdict word, tenant only when resolved; never an address)'), ('sender.resolve_failed', 'notice', 'B13 T3b: a sender-resolve request got no usable answer, or the report was malformed') ON CONFLICT (kind) DO NOTHING;

CREATE OR REPLACE FUNCTION desk.fadm_resolve_log(p_case text, p_request uuid, p_outcome text, p_verdict text, p_tenant uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE c record; why text; old record; n integer;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF NOT FOUND OR p_request IS NULL THEN RETURN false; END IF;
  IF p_outcome IS NULL OR p_outcome NOT IN ('answered', 'unavailable', 'refused', 'invalid') THEN why := 'bad_outcome';
  ELSIF (p_outcome = 'answered') <> (p_verdict IS NOT NULL) THEN why := 'bad_verdict';
  ELSIF p_verdict IS NOT NULL AND p_verdict NOT IN ('resolved', 'shared', 'unknown', 'ambiguous', 'multi_member', 'unaligned') THEN why := 'bad_verdict';
  ELSIF (p_verdict = 'resolved') <> (p_tenant IS NOT NULL) THEN why := 'bad_tenant';
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(NULL, 'sender.resolve_failed', jsonb_build_object('case', p_case, 'request', p_request, 'why', why));
    RETURN false;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_resolve_log:' || p_request::text, 32));   -- two reports of one request wait for each other
  SELECT * INTO old FROM desk.fadm_resolve_attempt WHERE request_id = p_request;
  IF FOUND THEN
    IF old.case_id = c.id AND old.outcome = p_outcome AND old.verdict IS NOT DISTINCT FROM p_verdict AND old.tenant_id IS NOT DISTINCT FROM p_tenant THEN RETURN true; END IF;   -- IDEMPOTENT: the same report again writes nothing
    PERFORM desk.fadm_audit(NULL, 'sender.resolve_failed', jsonb_build_object('case', p_case, 'request', p_request, 'why', 'request_reused'));
    RETURN false;
  END IF;
  INSERT INTO desk.fadm_resolve_attempt (request_id, case_id, outcome, verdict, tenant_id) VALUES (p_request, c.id, p_outcome, p_verdict, p_tenant);
  IF p_outcome = 'answered' THEN
    PERFORM desk.fadm_audit(NULL, 'sender.resolved', CASE WHEN p_tenant IS NULL THEN jsonb_build_object('case', p_case, 'request', p_request, 'verdict', p_verdict) ELSE jsonb_build_object('case', p_case, 'request', p_request, 'verdict', p_verdict, 'tenant', p_tenant) END);
  ELSE
    PERFORM desk.fadm_audit(NULL, 'sender.resolve_failed', jsonb_build_object('case', p_case, 'request', p_request, 'outcome', p_outcome));
  END IF;
  RETURN true;
END $f$;
COMMENT ON FUNCTION desk.fadm_resolve_log(text, uuid, text, text, uuid) IS 'AD32: the ONLY writer of a sender-resolve attempt; idempotent per request id; no parameter can carry an address or a domain; every attempt, good or bad, is a ledger line.';

CREATE OR REPLACE FUNCTION desk.fadm_case_resolution(p_case text) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
  SELECT jsonb_build_object('outcome', a.outcome, 'verdict', a.verdict, 'at', extract(epoch FROM a.at)::bigint)
  FROM desk.fadm_case c JOIN desk.fadm_resolve_attempt a ON a.case_id = c.id WHERE c.ref = p_case ORDER BY a.at DESC, a.request_id LIMIT 1
$f$;
COMMENT ON FUNCTION desk.fadm_case_resolution(text) IS 'AD32: the latest sender-resolve attempt of a case as {outcome, verdict, at}; NULL = never asked. The tenant is read through desk.fadm_case_tenant (AD30), never from here.';

REVOKE ALL ON FUNCTION desk.fadm_resolve_log(text, uuid, text, text, uuid), desk.fadm_case_resolution(text), desk.fadm_resolve_attempt_frozen() FROM PUBLIC;
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
  GRANT EXECUTE ON FUNCTION desk.fadm_resolve_log(text, uuid, text, text, uuid), desk.fadm_case_resolution(text) TO desk_app;
END IF; END $g$;

-- SELFTEST (rolls back; success is the exception P0AV2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad32_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD32 selftest: %', msg USING ERRCODE = 'P0AV1'; END IF; END $f$;
DO $$
DECLARE sfx text := substr(md5(random()::text), 1, 8); adr text; cref text; t1 uuid := gen_random_uuid(); r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); r3 uuid := gen_random_uuid(); r4 uuid := gen_random_uuid(); n0 bigint; s0 bigint; bad_keys int;
BEGIN
  SELECT local_part INTO adr FROM desk.fadm_address LIMIT 1;
  PERFORM pg_temp.ad32_ok(adr IS NOT NULL, 'a mailbox address exists to hang a test case on');
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad32-' || sfx, 'AD32 case') RETURNING ref INTO cref;
  SELECT coalesce(max(seq), 0) INTO s0 FROM desk.fadm_ledger;
  PERFORM pg_temp.ad32_ok(desk.fadm_case_resolution(cref) IS NULL, 'a case never asked has no resolution');
  PERFORM pg_temp.ad32_ok(desk.fadm_resolve_log(cref, r1, 'answered', 'unknown', NULL), 'an unknown verdict is recorded');
  PERFORM pg_temp.ad32_ok((SELECT count(*) FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.resolved') = 1, 'one info line for the answer');
  PERFORM pg_temp.ad32_ok(desk.fadm_resolve_log(cref, r2, 'answered', 'resolved', t1), 'a resolved verdict with its tenant is recorded');
  PERFORM pg_temp.ad32_ok((SELECT detail->>'tenant' FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.resolved' AND detail->>'request' = r2::text) = t1::text, 'the tenant UUID is in the line of a resolved verdict');
  PERFORM pg_temp.ad32_ok((SELECT NOT detail ? 'tenant' FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.resolved' AND detail->>'request' = r1::text), 'no tenant key on a verdict that is not resolved');
  n0 := (SELECT count(*) FROM desk.fadm_ledger);
  PERFORM pg_temp.ad32_ok(desk.fadm_resolve_log(cref, r2, 'answered', 'resolved', t1) AND (SELECT count(*) FROM desk.fadm_ledger) = n0 AND (SELECT count(*) FROM desk.fadm_resolve_attempt WHERE request_id = r2) = 1, 'the same report again is a success and writes nothing (idempotent)');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r1, 'answered', 'shared', NULL) AND (SELECT verdict FROM desk.fadm_resolve_attempt WHERE request_id = r1) = 'unknown', 'the same request id with another verdict is refused and changes nothing');
  PERFORM pg_temp.ad32_ok(desk.fadm_resolve_log(cref, r3, 'unavailable', NULL, NULL), 'a failed attempt is recorded');
  PERFORM pg_temp.ad32_ok((SELECT count(*) FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.resolve_failed' AND detail->>'outcome' = 'unavailable') = 1, 'a failed attempt is a notice line too (failures are logged, not only successes)');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r4, 'answered', 'resolved', NULL), 'resolved without a tenant is refused');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r4, 'answered', 'unknown', t1), 'a tenant on a verdict that is not resolved is refused');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r4, 'answered', 'maybe', NULL), 'a word outside the closed list is refused');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r4, 'unavailable', 'unknown', NULL), 'a verdict on a failed attempt is refused');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log(cref, r4, 'perhaps', NULL, NULL), 'an outcome outside the closed list is refused');
  PERFORM pg_temp.ad32_ok((SELECT count(*) FROM desk.fadm_resolve_attempt WHERE request_id = r4) = 0 AND (SELECT count(*) FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.resolve_failed' AND detail->>'request' = r4::text) = 5, 'every malformed report is a ledger line and writes no attempt');
  PERFORM pg_temp.ad32_ok(NOT desk.fadm_resolve_log('NO-SUCH-CASE', r4, 'answered', 'unknown', NULL), 'an unknown case is refused');
  SELECT count(*) INTO bad_keys FROM desk.fadm_ledger l, jsonb_object_keys(l.detail) k WHERE l.seq > s0 AND l.kind IN ('sender.resolved', 'sender.resolve_failed') AND k NOT IN ('case', 'request', 'verdict', 'tenant', 'outcome', 'why');
  PERFORM pg_temp.ad32_ok(bad_keys = 0 AND NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE seq > s0 AND kind IN ('sender.resolved', 'sender.resolve_failed') AND detail::text ~ '@'), 'OWASP: the ledger lines hold only the closed keys and never an address');
  PERFORM pg_temp.ad32_ok((desk.fadm_case_resolution(cref)->>'outcome') = 'unavailable' AND (desk.fadm_case_resolution(cref)->'verdict') = 'null'::jsonb, 'the case card reads the latest attempt');
  BEGIN UPDATE desk.fadm_resolve_attempt SET verdict = 'shared'; RAISE EXCEPTION 'no refusal u' USING ERRCODE = 'P0AV1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_resolve_attempt; RAISE EXCEPTION 'no refusal d' USING ERRCODE = 'P0AV1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_resolve_attempt; RAISE EXCEPTION 'no refusal t' USING ERRCODE = 'P0AV1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad32_ok(desk.fadm_case_tenant(cref) IS NULL, 'an attempt binds nothing: the case is still unresolved');
  PERFORM pg_temp.ad32_ok(desk.fadm_ledger_verify(), 'the hash chain verifies after all of it');
  PERFORM pg_temp.ad32_ok(has_function_privilege('desk_app', 'desk.fadm_resolve_log(text,uuid,text,text,uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_resolve_log(text,uuid,text,text,uuid)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_resolve_attempt', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_resolve_attempt', 'INSERT')
    AND (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_resolve_attempt'::regclass), 'desk_app can call the doors only; the table is forced RLS and closed');
  RAISE EXCEPTION 'AD32 selftest passed, rolling back' USING ERRCODE = 'P0AV2';
EXCEPTION WHEN SQLSTATE 'P0AV2' THEN RAISE NOTICE 'AD32 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
