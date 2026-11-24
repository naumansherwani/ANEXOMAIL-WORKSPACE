-- AD34 (phase 1m B13 step T4a, MANUAL COMPANY EXCEPTION WITH A SECOND REVIEWER), 25 Nov 2026 PKT. AD30 fadm_case_bind already refuses a manual binding unless two DIFFERENT active staff both hold case.assign; this file is the WORKFLOW that produces those two people: one proposes, a different one decides, the decision (and only the decision) calls the ONE writer.
-- SCHEMA-FIRST: read before writing: AD30 (desk.fadm_case_binding + desk.fadm_case_bind, the ONLY writer; sources and the manual two-people rule), AD02 (desk.fadm_authorize / fadm_rel / fadm_policy: case.assign is a 'lead' permit on the department unit; desk.fadm_ledger_kind and desk.fadm_audit: the hash-chained ledger), AD07 (desk.fadm_case: ref, restricted), AD33 (the idempotent state-transition style: advisory lock per entity, closed answer words, timeouts).
-- ADVANCE-RESEARCH: [1m] B13 T4 (25 Nov 2026 web search, plan docs/claude/admin-desk/D6-B13-T4-MANUAL-EXCEPTION-PLAN-25NOV.md): (1) NIST SP 800-53 AC-5 separation of duties and the four-eyes / dual-control guides: the person who proposes a sensitive action can never be the person who approves it, enforced in the DATABASE (CHECK + function), not only in a screen; (2) the PostgreSQL state-transition pattern (thoughtbot "Inserting State Transitions in Postgres", AppMaster tamper-evident audit trails): one open item per entity by a PARTIAL UNIQUE INDEX, a transition guard trigger that allows only pending -> one terminal state, an advisory transaction lock per item so approve and deny racing on one proposal queue and the first wins, every transition a hash-chained ledger line; (3) OWASP Logging: ledger lines carry closed words and ids, never free text.
-- DECISION-READ: docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (controlled manual exception C: two authorised staff, a reason, a ledger line, never a silent guess; a bound case never changes tenant).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD34-check.sql
-- WHAT IT ADDS (AD01..AD33 unchanged): desk.fadm_bind_proposal (one row per proposal, forced RLS, closed to every client), the guard trigger, ledger kinds bind.proposed / bind.approved / bind.denied / bind.withdrawn / bind.expired / bind.refused, and the doors desk.fadm_bind_propose, desk.fadm_bind_decide, desk.fadm_bind_withdraw, desk.fadm_bind_pending (reader), desk.fadm_bind_sweep.
-- WHO MAY DO WHAT: propose and decide need an ACTIVE person holding case.assign on the desk department (the same right AD30 re-checks); the decider is never the proposer (CHECK in the table AND answer 'same_person' in the function); at most 5 open proposals per proposer; one open proposal per case; a proposal lives 24 hours.
-- IDEMPOTENT + CONCURRENCY-SAFE: the same decision twice answers 'already_decided' and writes nothing; approve and deny racing on one proposal queue on the per-proposal advisory lock AND the row lock (SELECT ... FOR UPDATE), the first wins. ATOMIC: decide is ONE function = ONE transaction: fadm_case_bind and the proposal's end state commit together or not at all; a writer that answers false makes the proposal 'void', never 'approved'. EXPIRY: checked at decision time, enforced by a table CHECK (no approval after expires_at) and swept by a background worker (idempotent, cannot resurrect an ended proposal).
-- HONEST LIMITS: this file proves the two-people workflow and that approval goes through the ONE writer. That the tenant UUID is a real company is proved by the Rust door asking the Control Plane (T4b) before it calls fadm_bind_propose; the database refuses only a NULL or nil UUID.
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('bind.proposed', 'notice', 'B13 T4: a manual company exception was proposed (ids and closed words only)'),
  ('bind.approved', 'notice', 'B13 T4: a second person approved a manual company exception'),
  ('bind.denied', 'notice', 'B13 T4: a second person denied a manual company exception'),
  ('bind.withdrawn', 'info', 'B13 T4: the proposer withdrew a manual company exception'),
  ('bind.expired', 'info', 'B13 T4: a manual company exception passed its 24 hours'),
  ('bind.refused', 'high', 'B13 T4: a propose / decide / withdraw call was refused (closed reason word)')
ON CONFLICT (kind) DO NOTHING;

CREATE TABLE IF NOT EXISTS desk.fadm_bind_proposal (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id     uuid NOT NULL REFERENCES desk.fadm_case(id),
  tenant_id   uuid NOT NULL CHECK (tenant_id <> '00000000-0000-0000-0000-000000000000'::uuid),
  reason      text NOT NULL CHECK (reason IN ('customer_emailed_from_other_domain', 'new_domain_not_yet_verified', 'forwarded_mail', 'staff_checked_contract', 'other_with_note')),
  note        text NOT NULL DEFAULT '' CHECK (char_length(note) <= 200 AND (reason <> 'other_with_note' OR char_length(btrim(note)) >= 10)),
  proposer    uuid NOT NULL REFERENCES desk.fadm_owner(id),
  proposed_at timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL DEFAULT now() + interval '24 hours',
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'denied', 'expired', 'withdrawn', 'void')),
  decided_by  uuid REFERENCES desk.fadm_owner(id),
  decided_at  timestamptz,
  CONSTRAINT fadm_bind_proposal_window CHECK (expires_at > proposed_at AND expires_at <= proposed_at + interval '24 hours'),
  CONSTRAINT fadm_bind_proposal_two_people CHECK (status NOT IN ('approved', 'denied') OR (decided_by IS NOT NULL AND decided_by <> proposer)),
  CONSTRAINT fadm_bind_proposal_withdraw_by_proposer CHECK (status <> 'withdrawn' OR decided_by = proposer),
  CONSTRAINT fadm_bind_proposal_system_end CHECK (status NOT IN ('pending', 'expired', 'void') OR decided_by IS NULL),
  CONSTRAINT fadm_bind_proposal_decided_at CHECK ((status = 'pending') = (decided_at IS NULL)),
  CONSTRAINT fadm_bind_proposal_no_late_approval CHECK (status <> 'approved' OR decided_at <= expires_at)   -- a late approval cannot exist as a row, whether or not the expiry worker ran
);
DO $c$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_bind_proposal'::regclass AND conname = 'fadm_bind_proposal_no_late_approval') THEN
    ALTER TABLE desk.fadm_bind_proposal ADD CONSTRAINT fadm_bind_proposal_no_late_approval CHECK (status <> 'approved' OR decided_at <= expires_at);   -- re-run / upgrade safe
  END IF;
END $c$;
CREATE UNIQUE INDEX IF NOT EXISTS fadm_bind_proposal_one_open ON desk.fadm_bind_proposal (case_id) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS fadm_bind_proposal_open_by ON desk.fadm_bind_proposal (proposer) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS fadm_bind_proposal_recent ON desk.fadm_bind_proposal (proposed_at DESC);
ALTER TABLE desk.fadm_bind_proposal ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_bind_proposal FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_bind_proposal FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_bind_proposal' AND policyname = 'p_bind_proposal_none') THEN
    CREATE POLICY p_bind_proposal_none ON desk.fadm_bind_proposal FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;
COMMENT ON TABLE desk.fadm_bind_proposal IS 'AD34: manual company exception proposals. One open per case, 24 h life, pending -> exactly one end state (guard trigger), decider <> proposer (CHECK), never read or written by a client role: only the SECURITY DEFINER doors touch it.';

CREATE OR REPLACE FUNCTION desk.fadm_bind_proposal_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN
  IF TG_OP IN ('DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'desk.fadm_bind_proposal is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  IF OLD.status <> 'pending' THEN RAISE EXCEPTION 'a decided proposal never changes' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.status = 'pending' THEN RAISE EXCEPTION 'a pending proposal may only move to an end state' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (NEW.id, NEW.case_id, NEW.tenant_id, NEW.reason, NEW.note, NEW.proposer, NEW.proposed_at, NEW.expires_at) IS DISTINCT FROM (OLD.id, OLD.case_id, OLD.tenant_id, OLD.reason, OLD.note, OLD.proposer, OLD.proposed_at, OLD.expires_at)
    THEN RAISE EXCEPTION 'only the end state may change' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_bind_proposal_guard ON desk.fadm_bind_proposal;
CREATE TRIGGER fadm_bind_proposal_guard BEFORE UPDATE OR DELETE ON desk.fadm_bind_proposal FOR EACH ROW EXECUTE FUNCTION desk.fadm_bind_proposal_guard();
DROP TRIGGER IF EXISTS fadm_bind_proposal_guard_t ON desk.fadm_bind_proposal;
CREATE TRIGGER fadm_bind_proposal_guard_t BEFORE TRUNCATE ON desk.fadm_bind_proposal FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_bind_proposal_guard();

-- one place that answers "may this person assign cases" (the same right AD30 re-checks) --------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_may(p_actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'case.assign', desk.fadm_unit_id('department', 'desk'), NULL)), false)
$f$;

-- expire the stale open proposals (all, or one case); every expiry is a ledger line; returns how many ----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_sweep() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE r record; n integer := 0; cref text;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_bind_proposal WHERE status = 'pending' AND expires_at <= now() ORDER BY expires_at LIMIT 200 FOR UPDATE SKIP LOCKED LOOP
    UPDATE desk.fadm_bind_proposal SET status = 'expired', decided_at = now() WHERE id = r.id;
    SELECT ref INTO cref FROM desk.fadm_case WHERE id = r.case_id;
    PERFORM desk.fadm_audit(NULL, 'bind.expired', jsonb_build_object('proposal', r.id, 'case', cref));
    n := n + 1;
  END LOOP;
  RETURN n;
END $f$;

-- PROPOSE ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_propose(p_actor uuid, p_case text, p_tenant uuid, p_reason text, p_note text DEFAULT '')
RETURNS TABLE (outcome text, proposal_id uuid) LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE c record; why text; nid uuid; note text := btrim(COALESCE(p_note, ''));
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN why := 'not_active_staff';
  ELSIF NOT desk.fadm_bind_may(p_actor) THEN why := 'no_right';
  ELSIF c.id IS NULL THEN why := 'no_case';
  ELSIF p_tenant IS NULL OR p_tenant = '00000000-0000-0000-0000-000000000000'::uuid THEN why := 'bad_tenant';
  ELSIF p_reason IS NULL OR p_reason NOT IN ('customer_emailed_from_other_domain', 'new_domain_not_yet_verified', 'forwarded_mail', 'staff_checked_contract', 'other_with_note') THEN why := 'bad_reason';
  ELSIF char_length(note) > 200 OR (p_reason = 'other_with_note' AND char_length(note) < 10) THEN why := 'bad_note';
  ELSIF EXISTS (SELECT 1 FROM desk.fadm_case_binding WHERE case_id = c.id) THEN why := 'already_bound';
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(p_actor, 'bind.refused', jsonb_build_object('step', 'propose', 'case', left(COALESCE(p_case, '-'), 40), 'why', why));
    RETURN QUERY SELECT why, NULL::uuid; RETURN;
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_bind_propose:' || c.id::text, 34));
  PERFORM desk.fadm_bind_sweep();                                     -- a stale open proposal must not block a new one
  IF EXISTS (SELECT 1 FROM desk.fadm_bind_proposal WHERE case_id = c.id AND status = 'pending') THEN why := 'already_open';
  ELSIF (SELECT count(*) FROM desk.fadm_bind_proposal WHERE proposer = p_actor AND status = 'pending') >= 5 THEN why := 'too_many_open';
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(p_actor, 'bind.refused', jsonb_build_object('step', 'propose', 'case', c.ref, 'why', why));
    RETURN QUERY SELECT why, NULL::uuid; RETURN;
  END IF;
  INSERT INTO desk.fadm_bind_proposal (case_id, tenant_id, reason, note, proposer) VALUES (c.id, p_tenant, p_reason, note, p_actor) RETURNING id INTO nid;
  PERFORM desk.fadm_audit(p_actor, 'bind.proposed', jsonb_build_object('proposal', nid, 'case', c.ref, 'tenant', p_tenant, 'reason', p_reason));   -- the note is NEVER written to the ledger
  RETURN QUERY SELECT 'proposed'::text, nid;
END $f$;

-- DECIDE (approve or deny) ---------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_decide(p_actor uuid, p_proposal uuid, p_approve boolean) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE p record; cref text; why text; ok boolean;
BEGIN
  IF p_approve IS NULL THEN why := 'bad_call';
  ELSIF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN why := 'not_active_staff';
  ELSIF NOT desk.fadm_bind_may(p_actor) THEN why := 'no_right';
  END IF;
  IF why IS NULL THEN
    PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_bind_decide:' || COALESCE(p_proposal::text, '-'), 34));
    SELECT * INTO p FROM desk.fadm_bind_proposal WHERE id = p_proposal FOR UPDATE;   -- row lock + the advisory lock above: approve and deny on one proposal run one after the other, the first wins
    IF NOT FOUND THEN why := 'no_proposal';
    ELSIF p.status <> 'pending' THEN why := 'already_decided';
    ELSIF p.expires_at <= now() THEN
      UPDATE desk.fadm_bind_proposal SET status = 'expired', decided_at = now() WHERE id = p.id;
      SELECT ref INTO cref FROM desk.fadm_case WHERE id = p.case_id;
      PERFORM desk.fadm_audit(NULL, 'bind.expired', jsonb_build_object('proposal', p.id, 'case', cref));
      RETURN 'expired';
    ELSIF p.proposer = p_actor THEN why := 'same_person';
    END IF;
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(p_actor, 'bind.refused', jsonb_build_object('step', 'decide', 'proposal', p_proposal, 'why', why));
    RETURN why;
  END IF;
  SELECT ref INTO cref FROM desk.fadm_case WHERE id = p.case_id;
  IF NOT p_approve THEN
    UPDATE desk.fadm_bind_proposal SET status = 'denied', decided_by = p_actor, decided_at = now() WHERE id = p.id;
    PERFORM desk.fadm_audit(p_actor, 'bind.denied', jsonb_build_object('proposal', p.id, 'case', cref));
    RETURN 'denied';
  END IF;
  -- approval goes through the ONE writer; it re-checks both people, the right, the case and the "already bound" rule (AD30)
  ok := desk.fadm_case_bind(cref, p.tenant_id, 'manual_exception', p.proposer, p_actor, jsonb_build_object('proposal', p.id, 'reason', p.reason));
  IF NOT ok THEN
    UPDATE desk.fadm_bind_proposal SET status = 'void', decided_at = now() WHERE id = p.id;
    PERFORM desk.fadm_audit(p_actor, 'bind.refused', jsonb_build_object('step', 'decide', 'proposal', p.id, 'why', 'bind_refused'));
    RETURN 'bind_refused';
  END IF;
  UPDATE desk.fadm_bind_proposal SET status = 'approved', decided_by = p_actor, decided_at = now() WHERE id = p.id;
  PERFORM desk.fadm_audit(p_actor, 'bind.approved', jsonb_build_object('proposal', p.id, 'case', cref, 'tenant', p.tenant_id));
  RETURN 'approved';
END $f$;

-- WITHDRAW (proposer only) -----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_withdraw(p_actor uuid, p_proposal uuid) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE p record; cref text; why text;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_bind_decide:' || COALESCE(p_proposal::text, '-'), 34));
  SELECT * INTO p FROM desk.fadm_bind_proposal WHERE id = p_proposal FOR UPDATE;
  IF p_actor IS NULL OR NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN why := 'not_active_staff';
  ELSIF NOT FOUND THEN why := 'no_proposal';
  ELSIF p.proposer <> p_actor THEN why := 'not_proposer';
  ELSIF p.status <> 'pending' THEN why := 'already_decided';
  END IF;
  IF why IS NOT NULL THEN
    PERFORM desk.fadm_audit(p_actor, 'bind.refused', jsonb_build_object('step', 'withdraw', 'proposal', p_proposal, 'why', why));
    RETURN why;
  END IF;
  UPDATE desk.fadm_bind_proposal SET status = 'withdrawn', decided_by = p_actor, decided_at = now() WHERE id = p.id;
  SELECT ref INTO cref FROM desk.fadm_case WHERE id = p.case_id;
  PERFORM desk.fadm_audit(p_actor, 'bind.withdrawn', jsonb_build_object('proposal', p.id, 'case', cref));
  RETURN 'withdrawn';
END $f$;

-- READER: the open proposals a person with case.assign may see; no customer data, no mail text ----------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_bind_pending(p_actor uuid)
RETURNS TABLE (proposal_id uuid, case_ref text, tenant_id uuid, reason text, note text, proposer_role text, proposed_at timestamptz, expires_at timestamptz, seconds_left integer, mine boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
  SELECT p.id, c.ref, p.tenant_id, p.reason, p.note, o.role, p.proposed_at, p.expires_at, GREATEST(0, floor(extract(epoch FROM p.expires_at - now()))::integer), p.proposer = p_actor
  FROM desk.fadm_bind_proposal p JOIN desk.fadm_case c ON c.id = p.case_id JOIN desk.fadm_owner o ON o.id = p.proposer
  WHERE p.status = 'pending' AND p.expires_at > now() AND desk.fadm_bind_may(p_actor)
  ORDER BY p.proposed_at DESC LIMIT 100
$f$;

COMMENT ON FUNCTION desk.fadm_bind_propose(uuid, text, uuid, text, text) IS 'AD34: propose a manual company exception; closed outcome words; the note never reaches the ledger.';
COMMENT ON FUNCTION desk.fadm_bind_decide(uuid, uuid, boolean) IS 'AD34: a DIFFERENT person approves (through the ONE writer fadm_case_bind) or denies; first decision wins.';
COMMENT ON FUNCTION desk.fadm_bind_withdraw(uuid, uuid) IS 'AD34: the proposer takes a pending proposal back.';
COMMENT ON FUNCTION desk.fadm_bind_pending(uuid) IS 'AD34: open proposals for a person with case.assign: ids, closed words and the short note, never customer data.';
COMMENT ON FUNCTION desk.fadm_bind_sweep() IS 'AD34: expire stale open proposals, one ledger line each.';

REVOKE ALL ON FUNCTION desk.fadm_bind_may(uuid), desk.fadm_bind_sweep(), desk.fadm_bind_propose(uuid, text, uuid, text, text), desk.fadm_bind_decide(uuid, uuid, boolean), desk.fadm_bind_withdraw(uuid, uuid), desk.fadm_bind_pending(uuid) FROM PUBLIC;
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
  GRANT EXECUTE ON FUNCTION desk.fadm_bind_sweep(), desk.fadm_bind_propose(uuid, text, uuid, text, text), desk.fadm_bind_decide(uuid, uuid, boolean), desk.fadm_bind_withdraw(uuid, uuid), desk.fadm_bind_pending(uuid) TO desk_app;
END IF; END $g$;

-- SELFTEST (rolls back; success is the exception P0AW4) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad34_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD34 selftest: %', msg USING ERRCODE = 'P0AW3'; END IF; END $f$;
DO $$
DECLARE sfx text := substr(md5(random()::text), 1, 8); adr text; a1 uuid; a2 uuid; a3 uuid; unit uuid := desk.fadm_unit_id('department', 'desk'); ca text; cb text; cc text; t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid();
  r record; p1 uuid; p2 uuid; p3 uuid; n0 bigint; w text; marker text := 'NOTE-MARKER-' || substr(md5(random()::text), 1, 6);
BEGIN
  SELECT local_part INTO adr FROM desk.fadm_address LIMIT 1;
  PERFORM pg_temp.ad34_ok(adr IS NOT NULL, 'a mailbox address exists to hang test cases on');
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a34a-' || sfx || '@selftest.invalid', 'AD34 A', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a34b-' || sfx || '@selftest.invalid', 'AD34 B', 'agent', NULL, true, 'UTC') RETURNING id INTO a2;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a34c-' || sfx || '@selftest.invalid', 'AD34 C', 'agent', NULL, true, 'UTC') RETURNING id INTO a3;
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by) VALUES ('unit', unit, 'lead', 'owner', a1, a1), ('unit', unit, 'lead', 'owner', a2, a1);   -- a1 and a2 hold case.assign; a3 does not
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_may(a1) AND desk.fadm_bind_may(a2) AND NOT desk.fadm_bind_may(a3), 'case.assign is held by a1 and a2 only');
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad34a-' || sfx, 'AD34 case A') RETURNING ref INTO ca;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad34b-' || sfx, 'AD34 case B') RETURNING ref INTO cb;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad34c-' || sfx, 'AD34 case C') RETURNING ref INTO cc;
  -- refusals, each a ledger line, none writes a proposal
  n0 := (SELECT count(*) FROM desk.fadm_ledger);
  SELECT * INTO r FROM desk.fadm_bind_propose(a3, ca, t1, 'forwarded_mail', 'x'); PERFORM pg_temp.ad34_ok(r.outcome = 'no_right' AND r.proposal_id IS NULL, 'a person without case.assign cannot propose');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, 'no-such-case', t1, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'no_case', 'an unknown case is refused');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, NULL, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'bad_tenant', 'no tenant is refused');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, '00000000-0000-0000-0000-000000000000'::uuid, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'bad_tenant', 'the nil UUID is refused');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t1, 'because i said so', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'bad_reason', 'a reason outside the closed list is refused');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t1, 'other_with_note', 'short'); PERFORM pg_temp.ad34_ok(r.outcome = 'bad_note', 'other_with_note needs a real note (10 characters)');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t1, 'forwarded_mail', repeat('x', 201)); PERFORM pg_temp.ad34_ok(r.outcome = 'bad_note', 'a note over 200 characters is refused');
  PERFORM pg_temp.ad34_ok((SELECT count(*) FROM desk.fadm_bind_proposal WHERE case_id IN (SELECT id FROM desk.fadm_case WHERE ref IN (ca, cb, cc))) = 0 AND (SELECT count(*) FROM desk.fadm_ledger) >= n0 + 7, 'refusals wrote no proposal and each is a ledger line');
  -- propose
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t1, 'other_with_note', marker || ' contract seen on paper'); p1 := r.proposal_id;
  PERFORM pg_temp.ad34_ok(r.outcome = 'proposed' AND p1 IS NOT NULL, 'a person with case.assign can propose');
  SELECT * INTO r FROM desk.fadm_bind_propose(a2, ca, t2, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'already_open', 'one open proposal per case, even from another person');
  PERFORM pg_temp.ad34_ok((SELECT count(*) FROM desk.fadm_bind_pending(a2)) = 1 AND (SELECT NOT mine FROM desk.fadm_bind_pending(a2) LIMIT 1) AND (SELECT mine FROM desk.fadm_bind_pending(a1) LIMIT 1) AND (SELECT count(*) FROM desk.fadm_bind_pending(a3)) = 0, 'the reader shows the proposal to people with case.assign only, and marks the proposer''s own');
  PERFORM pg_temp.ad34_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l WHERE l.detail::text LIKE '%' || marker || '%'), 'the note never reaches the ledger');
  -- four eyes
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a1, p1, true) = 'same_person', 'the proposer cannot approve his own proposal');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a1, p1, false) = 'same_person', 'the proposer cannot deny his own proposal either');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a3, p1, true) = 'no_right', 'a person without case.assign cannot decide');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, gen_random_uuid(), true) = 'no_proposal', 'an unknown proposal is refused');
  PERFORM pg_temp.ad34_ok(desk.fadm_case_tenant(ca) IS NULL, 'refused decisions bound nothing');
  BEGIN INSERT INTO desk.fadm_bind_proposal (case_id, tenant_id, reason, proposer, status, decided_by, decided_at) SELECT id, t2, 'forwarded_mail', a1, 'approved', a1, now() FROM desk.fadm_case WHERE ref = cb; RAISE EXCEPTION 'no refusal self' USING ERRCODE = 'P0AW3';
  EXCEPTION WHEN check_violation THEN NULL; END;                 -- the database itself refuses an approval by the proposer (AC-5)
  -- deny, then a fresh proposal is possible
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, p1, false) = 'denied', 'a different person can deny');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, p1, true) = 'already_decided' AND desk.fadm_case_tenant(ca) IS NULL, 'a decided proposal cannot be decided again');
  PERFORM pg_temp.ad34_ok((SELECT status FROM desk.fadm_bind_proposal WHERE id = p1) = 'denied', 'status is denied');
  -- approve goes through the ONE writer
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t1, 'staff_checked_contract', ''); p2 := r.proposal_id;
  PERFORM pg_temp.ad34_ok(r.outcome = 'proposed', 'after a denial a new proposal is allowed');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, p2, true) = 'approved', 'a different person can approve');
  PERFORM pg_temp.ad34_ok(desk.fadm_case_tenant(ca) = t1, 'the case is now bound to the proposed tenant');
  PERFORM pg_temp.ad34_ok(EXISTS (SELECT 1 FROM desk.fadm_case_binding b JOIN desk.fadm_case c ON c.id = b.case_id WHERE c.ref = ca AND b.source = 'manual_exception' AND b.actor = a1 AND b.reviewer = a2 AND b.evidence ->> 'proposal' = p2::text), 'the binding is manual_exception, proposer = actor, decider = reviewer, proposal id kept as evidence');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, p2, true) = 'already_decided', 'approving twice is a success-free no-op (already_decided)');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, ca, t2, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'already_bound', 'a bound case takes no new proposal');
  -- withdraw
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cb, t2, 'forwarded_mail', ''); p3 := r.proposal_id;
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_withdraw(a2, p3) = 'not_proposer', 'only the proposer can withdraw');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_withdraw(a1, p3) = 'withdrawn' AND desk.fadm_bind_withdraw(a1, p3) = 'already_decided', 'the proposer withdraws once');
  PERFORM pg_temp.ad34_ok(desk.fadm_bind_decide(a2, p3, true) = 'already_decided' AND desk.fadm_case_tenant(cb) IS NULL, 'a withdrawn proposal cannot be approved');
  -- expiry: time is moved with the guard switched off inside this rolled-back test only
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cb, t2, 'forwarded_mail', ''); p3 := r.proposal_id;
  ALTER TABLE desk.fadm_bind_proposal DISABLE TRIGGER fadm_bind_proposal_guard;
  UPDATE desk.fadm_bind_proposal SET proposed_at = now() - interval '25 hours', expires_at = now() - interval '1 hour' WHERE id = p3;
  ALTER TABLE desk.fadm_bind_proposal ENABLE TRIGGER fadm_bind_proposal_guard;
  PERFORM pg_temp.ad34_ok((SELECT count(*) FROM desk.fadm_bind_pending(a2)) = 0, 'an expired proposal is not shown');
  w := desk.fadm_bind_decide(a2, p3, true);
  PERFORM pg_temp.ad34_ok(w = 'expired' AND desk.fadm_case_tenant(cb) IS NULL AND (SELECT status FROM desk.fadm_bind_proposal WHERE id = p3) = 'expired', 'an old proposal cannot be rubber-stamped: expired, nothing bound');
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cb, t2, 'forwarded_mail', ''); p3 := r.proposal_id;
  PERFORM pg_temp.ad34_ok(r.outcome = 'proposed', 'after expiry a new proposal is allowed');
  -- sweep is idempotent and never touches an ended proposal (late worker cannot resurrect anything)
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cc, t2, 'forwarded_mail', ''); p3 := r.proposal_id;
  ALTER TABLE desk.fadm_bind_proposal DISABLE TRIGGER fadm_bind_proposal_guard;
  UPDATE desk.fadm_bind_proposal SET proposed_at = now() - interval '25 hours', expires_at = now() - interval '1 hour' WHERE id = p3;
  ALTER TABLE desk.fadm_bind_proposal ENABLE TRIGGER fadm_bind_proposal_guard;
  n0 := (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'bind.expired');
  w := desk.fadm_bind_sweep()::text;
  PERFORM pg_temp.ad34_ok(w::integer >= 1 AND (SELECT status FROM desk.fadm_bind_proposal WHERE id = p3) = 'expired' AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'bind.expired') = n0 + 1, 'the worker expires a stale proposal with ONE ledger line');
  n0 := (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'bind.expired');
  w := desk.fadm_bind_sweep()::text;
  PERFORM pg_temp.ad34_ok(w = '0' AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'bind.expired') = n0, 'a second run finds nothing and writes nothing (idempotent)');
  BEGIN UPDATE desk.fadm_bind_proposal SET status = 'pending', decided_at = NULL WHERE id = p3; RAISE EXCEPTION 'no refusal resurrect' USING ERRCODE = 'P0AW3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad34_ok((SELECT status FROM desk.fadm_bind_proposal WHERE id = p3) = 'expired', 'an expired proposal cannot be brought back');
  BEGIN INSERT INTO desk.fadm_bind_proposal (case_id, tenant_id, reason, proposer, status, decided_by, decided_at, proposed_at, expires_at) SELECT id, t2, 'forwarded_mail', a1, 'approved', a2, now(), now() - interval '2 hours', now() - interval '1 hour' FROM desk.fadm_case WHERE ref = cc; RAISE EXCEPTION 'no refusal late' USING ERRCODE = 'P0AW3';
  EXCEPTION WHEN check_violation THEN NULL; END;                 -- no approved row can exist after its 24 hours, worker or not
  -- writer atomicity: the proposer loses case.assign before the approval -> the ONE writer refuses -> the proposal is void, nothing is bound, nothing is half done
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cc, t2, 'forwarded_mail', ''); p3 := r.proposal_id;
  UPDATE desk.fadm_rel SET revoked_at = now() WHERE subject_id = a1 AND object_id = unit;
  w := desk.fadm_bind_decide(a2, p3, true);
  PERFORM pg_temp.ad34_ok(w = 'bind_refused' AND (SELECT status FROM desk.fadm_bind_proposal WHERE id = p3) = 'void' AND desk.fadm_case_tenant(cc) IS NULL, 'when the writer refuses, the proposal is void and nothing is bound (never approved without a binding)');
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by) VALUES ('unit', unit, 'lead', 'owner', a1, a2);   -- a1 gets the right back (a revoked tuple is never un-revoked)
  -- cap of 5 open per proposer
  FOR i IN 1..4 LOOP INSERT INTO desk.fadm_case (queue, address, thread_id, subject) VALUES ('support', adr, 'thr-ad34x' || i || '-' || sfx, 'AD34 cap ' || i) RETURNING ref INTO w; PERFORM desk.fadm_bind_propose(a1, w, t2, 'forwarded_mail', ''); END LOOP;
  SELECT * INTO r FROM desk.fadm_bind_propose(a1, cc, t2, 'forwarded_mail', ''); PERFORM pg_temp.ad34_ok(r.outcome = 'too_many_open', 'a person may hold at most 5 open proposals');
  -- the table is append-only and closed
  BEGIN UPDATE desk.fadm_bind_proposal SET tenant_id = t1 WHERE id = p2; RAISE EXCEPTION 'no refusal u' USING ERRCODE = 'P0AW3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_bind_proposal WHERE id = p2; RAISE EXCEPTION 'no refusal d' USING ERRCODE = 'P0AW3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_bind_proposal; RAISE EXCEPTION 'no refusal t' USING ERRCODE = 'P0AW3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad34_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind IN ('bind.proposed', 'bind.approved', 'bind.denied', 'bind.withdrawn', 'bind.expired', 'bind.refused')) >= 18, 'every step is a ledger line');
  PERFORM pg_temp.ad34_ok(desk.fadm_ledger_verify(), 'the hash chain verifies after all of it');
  PERFORM pg_temp.ad34_ok(has_function_privilege('desk_app', 'desk.fadm_bind_propose(uuid,text,uuid,text,text)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_bind_decide(uuid,uuid,boolean)', 'EXECUTE')
    AND NOT has_function_privilege('public', 'desk.fadm_bind_propose(uuid,text,uuid,text,text)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_bind_decide(uuid,uuid,boolean)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_bind_proposal', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_bind_proposal', 'INSERT')
    AND (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_bind_proposal'::regclass), 'desk_app calls the doors only; the table is forced RLS and closed');
  RAISE EXCEPTION 'AD34 selftest passed, rolling back' USING ERRCODE = 'P0AW4';
EXCEPTION WHEN SQLSTATE 'P0AW4' THEN RAISE NOTICE 'AD34 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
