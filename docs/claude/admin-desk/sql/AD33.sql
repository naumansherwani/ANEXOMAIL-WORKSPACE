-- AD33 (phase 1m B13 step T3c, APPLY A VERIFIED VERDICT TO A CASE), 24 Nov 2026 PKT. T3b (AD32) records what the Control Plane said about a case's sender. This file is the ONE door that turns the LATEST such answer into the case-to-company binding (AD30 fadm_case_bind, source verified_domain). The mail door (Folder 2) only has to call fadm_resolve_log and then this function.
-- SCHEMA-FIRST: read before writing: AD32 (desk.fadm_resolve_attempt: one row per signed request, the verdict and the tenant only on an answered+resolved row; desk.fadm_case_resolution reader), AD30 (desk.fadm_case_binding + desk.fadm_case_bind, the ONLY writer of a binding; refusals are ledger lines; sources verified_domain / verified_member / manual_exception), AD02 (desk.fadm_audit and the CLOSED kind list desk.fadm_ledger_kind), AD01 (hash-chained ledger), AD07 (desk.fadm_case).
-- ADVANCE-RESEARCH: [1m] B13 T3c (24 Nov 2026 web search): (1) PostgreSQL idempotent state-transition pattern (advisory transaction lock per entity, same request again = success that writes nothing, lock plus unique key, as described in the thoughtbot and PostgreSQL mailing-list idempotency notes): the case is locked while it is applied. (2) NIST SP 800-53 AU-10 non-repudiation and AC-3 access enforcement: a binding is attributable to a recorded verified answer (the request id is stored in the binding evidence) and the writer is closed to everyone but the one function. (3) RFC 7489 alignment: only an ANSWERED + RESOLVED latest attempt may bind; unaligned, shared, unknown, ambiguous and multi_member never bind. (4) OWASP Logging Cheat Sheet: every apply, bound or not, is one ledger line with a closed word and no address, no domain. (5) Latest decision wins and fail closed: an older resolved answer can never bind a case whose newest attempt says anything else.
-- DECISION-READ: docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (hybrid A+B+controlled C: a verified domain may bind automatically, a shared domain never, two claimants = quarantine, multi-membership needs a person's explicit choice, the tenant of a case never changes once bound).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD33-check.sql
-- WHAT IT ADDS (AD01..AD32 unchanged): ledger kind 'sender.applied' (info) and desk.fadm_case_apply_resolution(case ref) returning ONE closed word: bound, already_bound, not_resolved, no_attempt, refused.
-- IDEMPOTENT + CONCURRENCY-SAFE: applying twice binds once (fadm_case_bind is idempotent for the same tenant); two parallel applications of one case queue on a per-case advisory lock.
-- HONEST LIMITS: this file proves "a case is bound ONLY from the newest verified answer, and only when that answer was resolved". The automatic call at case creation is the Folder 2 mail door; the manual two-staff exception is T4.
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('sender.applied', 'info', 'B13 T3c: the newest sender-resolve answer of a case was applied (closed word: bound, already_bound, not_resolved, no_attempt, refused; never an address or a domain)') ON CONFLICT (kind) DO NOTHING;

CREATE OR REPLACE FUNCTION desk.fadm_case_apply_resolution(p_case text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE c record; a record; w text; ok boolean;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF NOT FOUND THEN RETURN 'no_attempt'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_case_apply_resolution:' || c.id::text, 33));   -- two applications of one case wait for each other
  SELECT * INTO a FROM desk.fadm_resolve_attempt WHERE case_id = c.id ORDER BY at DESC, request_id LIMIT 1;   -- the NEWEST attempt decides (latest decision wins)
  IF NOT FOUND THEN w := 'no_attempt';
  ELSIF a.outcome <> 'answered' OR a.verdict IS DISTINCT FROM 'resolved' OR a.tenant_id IS NULL THEN w := 'not_resolved';
  ELSIF EXISTS (SELECT 1 FROM desk.fadm_case_binding WHERE case_id = c.id AND tenant_id = a.tenant_id) THEN w := 'already_bound';
  ELSE
    ok := desk.fadm_case_bind(p_case, a.tenant_id, 'verified_domain', NULL, NULL, jsonb_build_object('request', a.request_id, 'verdict', 'resolved'));
    w := CASE WHEN ok THEN 'bound' ELSE 'refused' END;
  END IF;
  PERFORM desk.fadm_audit(NULL, 'sender.applied', jsonb_build_object('case', p_case, 'word', w) || CASE WHEN a.request_id IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('request', a.request_id) END);
  RETURN w;
END $f$;
COMMENT ON FUNCTION desk.fadm_case_apply_resolution(text) IS 'AD33: binds a case to a company ONLY from its newest answered+resolved sender-resolve attempt (source verified_domain, the request id kept as evidence); every call is one sender.applied ledger line with a closed word; no address, no domain.';
REVOKE ALL ON FUNCTION desk.fadm_case_apply_resolution(text) FROM PUBLIC;
DO $g$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
    GRANT EXECUTE ON FUNCTION desk.fadm_case_apply_resolution(text) TO desk_app;
  END IF;
END $g$;

-- SELFTEST (rolls back; success is the exception P0AW2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad33_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD33 selftest: %', msg USING ERRCODE = 'P0AW1'; END IF; END $f$;
DO $$
DECLARE w text; sfx text := substr(md5(random()::text), 1, 8); adr text; c1 text; c2 text; c3 text; t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid(); r1 uuid := gen_random_uuid(); r2 uuid := gen_random_uuid(); r3 uuid := gen_random_uuid(); r4 uuid := gen_random_uuid(); s0 bigint; n0 bigint; bad_keys integer;
BEGIN
  SELECT local_part INTO adr FROM desk.fadm_address LIMIT 1;
  PERFORM pg_temp.ad33_ok(adr IS NOT NULL, 'a mailbox address exists to hang test cases on');
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad33a-' || sfx, 'AD33 case A') RETURNING ref INTO c1;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad33b-' || sfx, 'AD33 case B') RETURNING ref INTO c2;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad33c-' || sfx, 'AD33 case C') RETURNING ref INTO c3;
  SELECT coalesce(max(seq), 0) INTO s0 FROM desk.fadm_ledger;
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'no_attempt' AND desk.fadm_case_tenant(c1) IS NULL, 'a case never asked binds nothing');
  w := desk.fadm_case_apply_resolution('NO-SUCH-CASE');
  PERFORM pg_temp.ad33_ok(w = 'no_attempt', 'an unknown case binds nothing');
  PERFORM desk.fadm_resolve_log(c1, r1, 'answered', 'unknown', NULL);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved' AND desk.fadm_case_tenant(c1) IS NULL, 'unknown never binds');
  PERFORM desk.fadm_resolve_log(c1, gen_random_uuid(), 'answered', 'shared', NULL);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved', 'shared never binds');
  PERFORM desk.fadm_resolve_log(c1, gen_random_uuid(), 'answered', 'unaligned', NULL);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved', 'unaligned never binds');
  PERFORM desk.fadm_resolve_log(c1, gen_random_uuid(), 'unavailable', NULL, NULL);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved' AND desk.fadm_case_tenant(c1) IS NULL, 'a failed attempt never binds');
  PERFORM desk.fadm_resolve_log(c1, r2, 'answered', 'resolved', t1);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'bound' AND desk.fadm_case_tenant(c1) = t1, 'a resolved answer binds the case to its company');
  PERFORM pg_temp.ad33_ok((SELECT source FROM desk.fadm_case_binding b JOIN desk.fadm_case c ON c.id = b.case_id WHERE c.ref = c1) = 'verified_domain' AND (SELECT evidence->>'request' FROM desk.fadm_case_binding b JOIN desk.fadm_case c ON c.id = b.case_id WHERE c.ref = c1) = r2::text, 'the binding says verified_domain and keeps the request id as evidence');
  n0 := (SELECT count(*) FROM desk.fadm_case_binding);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'already_bound' AND (SELECT count(*) FROM desk.fadm_case_binding) = n0, 'applying twice binds once (idempotent)');
  PERFORM desk.fadm_resolve_log(c1, r3, 'answered', 'resolved', t2);
  w := desk.fadm_case_apply_resolution(c1);
  PERFORM pg_temp.ad33_ok(w = 'refused' AND desk.fadm_case_tenant(c1) = t1, 'a later answer for ANOTHER company never moves a bound case');
  PERFORM desk.fadm_resolve_log(c2, r4, 'answered', 'resolved', t1);
  PERFORM desk.fadm_resolve_log(c2, gen_random_uuid(), 'answered', 'ambiguous', NULL);
  w := desk.fadm_case_apply_resolution(c2);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved' AND desk.fadm_case_tenant(c2) IS NULL, 'latest decision wins: an older resolved answer cannot bind when the newest says ambiguous');
  PERFORM desk.fadm_resolve_log(c3, gen_random_uuid(), 'answered', 'multi_member', NULL);
  w := desk.fadm_case_apply_resolution(c3);
  PERFORM pg_temp.ad33_ok(w = 'not_resolved' AND desk.fadm_case_tenant(c3) IS NULL, 'multi_member waits for a person');
  PERFORM pg_temp.ad33_ok((SELECT count(*) FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.applied') = 10, 'every apply of a known case is exactly one ledger line');
  SELECT count(*) INTO bad_keys FROM desk.fadm_ledger l, jsonb_object_keys(l.detail) k WHERE l.seq > s0 AND l.kind = 'sender.applied' AND k NOT IN ('case', 'word', 'request');
  PERFORM pg_temp.ad33_ok(bad_keys = 0 AND NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.applied' AND detail::text ~ '@') AND NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE seq > s0 AND kind = 'sender.applied' AND detail->>'word' NOT IN ('bound', 'already_bound', 'not_resolved', 'no_attempt', 'refused')), 'OWASP: the ledger lines have a closed word and no address');
  PERFORM pg_temp.ad33_ok(desk.fadm_ledger_verify(), 'the hash chain verifies after all of it');
  PERFORM pg_temp.ad33_ok(has_function_privilege('desk_app', 'desk.fadm_case_apply_resolution(text)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_case_apply_resolution(text)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_case_bind(text,uuid,text,uuid,uuid,jsonb)', 'EXECUTE'), 'desk_app may call the door only; the binding writer stays closed to PUBLIC');
  RAISE EXCEPTION 'AD33 selftest passed, rolling back' USING ERRCODE = 'P0AW2';
EXCEPTION WHEN SQLSTATE 'P0AW2' THEN RAISE NOTICE 'AD33 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
