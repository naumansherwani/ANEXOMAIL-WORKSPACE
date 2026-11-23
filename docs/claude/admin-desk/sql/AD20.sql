-- AD20 (phase 1m, card B13, list BL-46: customer data access with CONSENT and a TIMER), 24 Nov 2026 05:0x PKT.
-- SCHEMA-FIRST: read in full before writing: AD01 (fadm_owner, fadm_ledger SHA-256 chain + frozen triggers, fadm_audit), AD02 (closed ledger-kind list fadm_ledger_kind + guard, fadm_authorize), AD07 (fadm_case: ref, restricted, company_ref, status), AD19 (selftest pattern: pg_temp helper, rollback via P0AS2). NOTHING is renamed or copied.
-- ADVANCE-RESEARCH: [1m] web research (Google Access Approval, PostgreSQL tstzrange + EXCLUDE) in docs/claude/admin-desk/D6-B13-CONSENT-ACCESS-LIST-24NOV.md (Google Access Approval: staff request, the customer admin approves or denies, no access before approval, every request signed, revocable any time, history kept; PostgreSQL tstzrange + EXCLUDE temporal constraints). His locked answers 24 Nov 04:26: approver = the customer's Company Admin / Security Admin (single-user account: the owner); timers metadata 60 min, headers 30 min, content 15 min; NO break-glass on customer data, no auto-approval, no Chairman bypass.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD20-check.sql
-- WHAT IT ADDS:
--   1. desk.fadm_consent: one row per request (case + scope + reason). Scope metadata | headers | content. Status requested -> approved | denied | cancelled, approved -> revoked | expired (a closed state machine enforced by a trigger). The window is a tstzrange that exists ONLY once approved, never longer than the scope maximum (60 / 30 / 15 minutes), never open-ended. Forced RLS, no policy: nobody reads the table directly, only the SECURITY DEFINER doors below. No DELETE, no TRUNCATE, request facts frozen.
--   2. One live grant per person + case + scope: EXCLUDE USING gist on the window (btree_gist), or when that extension cannot be created here, a partial unique index (the fallback is named in the NOTICE).
--   3. fadm_consent_minutes(scope), fadm_consent_request(actor, case ref, scope, reason): an active staff person asks for ONE case; restricted (billing) cases never allow content; at most 5 requests waiting per person.
--   4. fadm_consent_decide(consent, decision, consent_ref, approver_ref): the customer-side answer (verified by Rust, Rule 52, before this runs) opens the window starting NOW. Only 'requested' can be decided. No auto-approval exists.
--   5. fadm_consent_revoke(consent, by_ref): closes a live window at once.
--   6. fadm_consent_open(actor, consent): the AUDIT LINE IS WRITTEN FIRST, then (only for the person who asked, only inside the window) the case id, scope and seconds left are returned; any other call returns NULL and writes a refusal line. Read-only: the function never writes a customer row.
--   7. fadm_consent_sweep(): marks windows that ended as expired, one ledger line each. Called inside open and board (no cron needed: expiry is also enforced by the window test itself).
--   8. fadm_consent_board(actor): counts and the person's own requests (case ref, scope, status, seconds left). No name, address, subject or money.
-- No money. Every helper is REVOKEd from PUBLIC (the AD1c lesson). desk_app gets the doors only, never the table.
BEGIN;
DO $$ BEGIN
  BEGIN CREATE EXTENSION IF NOT EXISTS btree_gist; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'AD20: btree_gist cannot be created here (%), the partial unique index fallback is used', SQLERRM; END;
END $$;

INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('consent.requested','notice','B13: staff asked for case access'),('consent.approved','high','B13: the customer approved, the timer started'),('consent.denied','notice','B13: the customer denied'),
  ('consent.revoked','high','B13: the customer closed a live window'),('consent.expired','notice','B13: the window ended'),('consent.cancelled','notice','B13: staff withdrew the request'),
  ('consent.opened','high','B13: a case was opened inside a live window (written BEFORE the read)'),('consent.refused','high','B13: an open was refused'),('ad20.selftest','info','AD20')
ON CONFLICT (kind) DO NOTHING;

CREATE OR REPLACE FUNCTION desk.fadm_consent_minutes(p_scope text) RETURNS integer LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = pg_catalog AS $f$
  SELECT CASE p_scope WHEN 'metadata' THEN 60 WHEN 'headers' THEN 30 WHEN 'content' THEN 15 END
$f$;

CREATE TABLE IF NOT EXISTS desk.fadm_consent (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id       uuid NOT NULL REFERENCES desk.fadm_case(id),
  requested_by  uuid NOT NULL REFERENCES desk.fadm_owner(id),
  scope         text NOT NULL CHECK (scope IN ('metadata','headers','content')),
  reason        text NOT NULL CHECK (length(reason) BETWEEN 20 AND 300 AND reason !~ E'[\\r\\n]'),
  status        text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','approved','denied','revoked','expired','cancelled')),
  requested_at  timestamptz NOT NULL DEFAULT now(),
  decided_at    timestamptz,
  consent_ref   text CHECK (consent_ref IS NULL OR consent_ref ~ '^[A-Za-z0-9_.:-]{8,120}$'),
  approver_ref  text CHECK (approver_ref IS NULL OR approver_ref ~ '^[A-Za-z0-9_.:-]{4,120}$'),
  access_window tstzrange,
  CHECK ((status IN ('approved','revoked','expired')) = (access_window IS NOT NULL)),
  CHECK (access_window IS NULL OR (NOT lower_inf(access_window) AND NOT upper_inf(access_window))),
  CHECK (access_window IS NULL OR upper(access_window) - lower(access_window) <= make_interval(mins => desk.fadm_consent_minutes(scope))),
  CHECK (status = 'requested' OR status = 'cancelled' OR decided_at IS NOT NULL),
  CHECK (access_window IS NULL OR (consent_ref IS NOT NULL AND approver_ref IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS fadm_consent_by ON desk.fadm_consent (requested_by, status);
CREATE INDEX IF NOT EXISTS fadm_consent_case ON desk.fadm_consent (case_id);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'btree_gist') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fadm_consent_no_overlap') THEN
      ALTER TABLE desk.fadm_consent ADD CONSTRAINT fadm_consent_no_overlap EXCLUDE USING gist (requested_by WITH =, case_id WITH =, scope WITH =, access_window WITH &&) WHERE (status = 'approved');
    END IF;
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS fadm_consent_one_live ON desk.fadm_consent (requested_by, case_id, scope) WHERE status = 'approved';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP IN ('DELETE','TRUNCATE') THEN RAISE EXCEPTION 'desk.fadm_consent is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.case_id <> OLD.case_id OR NEW.requested_by <> OLD.requested_by OR NEW.scope <> OLD.scope OR NEW.reason <> OLD.reason OR NEW.requested_at <> OLD.requested_at THEN
    RAISE EXCEPTION 'the facts of a consent request are frozen' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.status <> OLD.status AND NOT ((OLD.status = 'requested' AND NEW.status IN ('approved','denied','cancelled')) OR (OLD.status = 'approved' AND NEW.status IN ('revoked','expired'))) THEN
    RAISE EXCEPTION 'consent status % -> % is not allowed', OLD.status, NEW.status USING ERRCODE = 'check_violation'; END IF;
  IF OLD.status NOT IN ('requested','approved') THEN RAISE EXCEPTION 'a closed consent request cannot change' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF OLD.access_window IS NOT NULL AND NEW.access_window IS DISTINCT FROM OLD.access_window AND NOT (NEW.status = 'revoked' AND lower(NEW.access_window) = lower(OLD.access_window) AND upper(NEW.access_window) <= upper(OLD.access_window)) THEN
    RAISE EXCEPTION 'a granted window can only be closed earlier, never moved or made longer' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_consent_guard ON desk.fadm_consent;
CREATE TRIGGER fadm_consent_guard BEFORE UPDATE OR DELETE ON desk.fadm_consent FOR EACH ROW EXECUTE FUNCTION desk.fadm_consent_guard();
DROP TRIGGER IF EXISTS fadm_consent_guard_t ON desk.fadm_consent;
CREATE TRIGGER fadm_consent_guard_t BEFORE TRUNCATE ON desk.fadm_consent FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_consent_guard();
ALTER TABLE desk.fadm_consent ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_consent FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_consent FROM PUBLIC;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN REVOKE ALL ON desk.fadm_consent FROM desk_app; END IF; END $$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_sweep() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record; n integer := 0;
BEGIN
  FOR r IN SELECT id, case_id, scope FROM desk.fadm_consent WHERE status = 'approved' AND upper(access_window) <= now() FOR UPDATE SKIP LOCKED LOOP
    PERFORM desk.fadm_audit(NULL, 'consent.expired', jsonb_build_object('consent', r.id, 'scope', r.scope));
    UPDATE desk.fadm_consent SET status = 'expired' WHERE id = r.id; n := n + 1;
  END LOOP;
  RETURN n;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_request(p_actor uuid, p_case text, p_scope text, p_reason text) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE c record; id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN RAISE EXCEPTION 'not allowed: not an active staff person' USING ERRCODE = 'insufficient_privilege'; END IF;
  SELECT * INTO c FROM desk.fadm_case WHERE ref = p_case;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such case' USING ERRCODE = 'no_data_found'; END IF;
  IF c.restricted AND p_scope = 'content' THEN RAISE EXCEPTION 'a restricted case never opens its content' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (SELECT count(*) FROM desk.fadm_consent WHERE requested_by = p_actor AND status = 'requested') >= 5 THEN RAISE EXCEPTION 'too many requests are waiting' USING ERRCODE = 'insufficient_privilege'; END IF;
  INSERT INTO desk.fadm_consent (case_id, requested_by, scope, reason) VALUES (c.id, p_actor, p_scope, p_reason) RETURNING fadm_consent.id INTO id;
  PERFORM desk.fadm_audit(p_actor, 'consent.requested', jsonb_build_object('consent', id, 'case', c.ref, 'scope', p_scope));
  RETURN id;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_decide(p_consent uuid, p_decision text, p_consent_ref text, p_approver_ref text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE r desk.fadm_consent;
BEGIN
  IF p_decision NOT IN ('approved','denied') THEN RAISE EXCEPTION 'decision must be approved or denied' USING ERRCODE = 'check_violation'; END IF;
  SELECT * INTO r FROM desk.fadm_consent WHERE id = p_consent FOR UPDATE;
  IF NOT FOUND OR r.status <> 'requested' THEN RETURN false; END IF;
  IF p_decision = 'approved' THEN
    PERFORM desk.fadm_audit(r.requested_by, 'consent.approved', jsonb_build_object('consent', r.id, 'scope', r.scope, 'minutes', desk.fadm_consent_minutes(r.scope), 'consent_ref', p_consent_ref));
    UPDATE desk.fadm_consent SET status = 'approved', decided_at = now(), consent_ref = p_consent_ref, approver_ref = p_approver_ref,
      access_window = tstzrange(now(), now() + make_interval(mins => desk.fadm_consent_minutes(r.scope)), '[)') WHERE id = r.id;
  ELSE
    PERFORM desk.fadm_audit(r.requested_by, 'consent.denied', jsonb_build_object('consent', r.id, 'scope', r.scope));
    UPDATE desk.fadm_consent SET status = 'denied', decided_at = now(), approver_ref = p_approver_ref WHERE id = r.id;
  END IF;
  RETURN true;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_revoke(p_consent uuid, p_by_ref text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE r desk.fadm_consent;
BEGIN
  SELECT * INTO r FROM desk.fadm_consent WHERE id = p_consent FOR UPDATE;
  IF NOT FOUND OR r.status <> 'approved' THEN RETURN false; END IF;
  PERFORM desk.fadm_audit(r.requested_by, 'consent.revoked', jsonb_build_object('consent', r.id, 'scope', r.scope, 'by', left(p_by_ref, 60)));
  UPDATE desk.fadm_consent SET status = 'revoked', access_window = tstzrange(lower(access_window), least(now(), upper(access_window)), '[)') WHERE id = r.id;
  RETURN true;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_open(p_actor uuid, p_consent uuid) RETURNS TABLE (case_id uuid, scope text, seconds_left integer) LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
DECLARE r desk.fadm_consent;
BEGIN
  PERFORM desk.fadm_consent_sweep();
  SELECT * INTO r FROM desk.fadm_consent WHERE id = p_consent;
  IF NOT FOUND OR r.requested_by <> p_actor OR r.status <> 'approved' OR NOT (now() <@ r.access_window)
     OR NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN
    PERFORM desk.fadm_audit(p_actor, 'consent.refused', jsonb_build_object('consent', p_consent));
    RETURN;
  END IF;
  PERFORM desk.fadm_audit(p_actor, 'consent.opened', jsonb_build_object('consent', r.id, 'scope', r.scope));   -- the line is written BEFORE anything is returned
  RETURN QUERY SELECT r.case_id, r.scope, greatest(0, floor(extract(epoch FROM upper(r.access_window) - now()))::integer);
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_consent_board(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN RETURN NULL; END IF;
  PERFORM desk.fadm_consent_sweep();
  RETURN jsonb_build_object('waiting', (SELECT count(*) FROM desk.fadm_consent WHERE requested_by = p_actor AND status = 'requested'),
    'live', (SELECT count(*) FROM desk.fadm_consent WHERE requested_by = p_actor AND status = 'approved'),
    'mine', coalesce((SELECT jsonb_agg(jsonb_build_object('id', x.id, 'case', x.ref, 'scope', x.scope, 'status', x.status,
        'seconds_left', CASE WHEN x.status = 'approved' THEN greatest(0, floor(extract(epoch FROM upper(x.access_window) - now()))::integer) END) ORDER BY x.requested_at DESC)
      FROM (SELECT c.id, k.ref, c.scope, c.status, c.access_window, c.requested_at FROM desk.fadm_consent c JOIN desk.fadm_case k ON k.id = c.case_id WHERE c.requested_by = p_actor ORDER BY c.requested_at DESC LIMIT 25) x), '[]'::jsonb));
END $f$;

COMMENT ON TABLE desk.fadm_consent IS 'AD20 B13: consent-gated, time-boxed, read-only access to ONE case; window only after the customer approves; no break-glass, no auto-approval';
REVOKE ALL ON FUNCTION desk.fadm_consent_minutes(text), desk.fadm_consent_sweep(), desk.fadm_consent_request(uuid,text,text,text), desk.fadm_consent_decide(uuid,text,text,text), desk.fadm_consent_revoke(uuid,text), desk.fadm_consent_open(uuid,uuid), desk.fadm_consent_board(uuid) FROM PUBLIC;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
  GRANT EXECUTE ON FUNCTION desk.fadm_consent_request(uuid,text,text,text), desk.fadm_consent_decide(uuid,text,text,text), desk.fadm_consent_revoke(uuid,text), desk.fadm_consent_open(uuid,uuid), desk.fadm_consent_board(uuid) TO desk_app;
END IF; END $$;

CREATE FUNCTION pg_temp.ad20_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD20 selftest: %', msg USING ERRCODE = 'P0AS1'; END IF; END $f$;
DO $$
DECLARE a1 uuid; a2 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; adr text; cs uuid; cref text; cr uuid; rr record; ok boolean; led bigint;
BEGIN
  SELECT local_part INTO adr FROM desk.fadm_address LIMIT 1;
  PERFORM pg_temp.ad20_ok(adr IS NOT NULL, 'a mailbox address exists to hang a test case on');
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a20-' || sfx || '@selftest.invalid', 'AD20 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('b20-' || sfx || '@selftest.invalid', 'AD20 Other', 'agent', NULL, true, 'UTC') RETURNING id INTO a2;
  INSERT INTO desk.fadm_case (queue, address, thread_id, subject, restricted) VALUES ('general', adr, 'ad20-thread-' || sfx, 'selftest', false) RETURNING id, ref INTO cs, cref;
  PERFORM pg_temp.ad20_ok(desk.fadm_consent_minutes('metadata') = 60 AND desk.fadm_consent_minutes('headers') = 30 AND desk.fadm_consent_minutes('content') = 15, 'timers are 60 / 30 / 15 minutes');
  BEGIN PERFORM desk.fadm_consent_request(gen_random_uuid(), cref, 'metadata', 'a reason that is long enough here'); RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_consent_request(a1, cref, 'metadata', 'short'); RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN check_violation THEN NULL; END;
  cr := desk.fadm_consent_request(a1, cref, 'content', 'customer reported a missing message, need the body');
  SELECT count(*) INTO led FROM desk.fadm_ledger WHERE kind = 'consent.opened';
  ok := NOT EXISTS (SELECT 1 FROM desk.fadm_consent_open(a1, cr));
  PERFORM pg_temp.ad20_ok(ok, 'no access before the customer approves (default closed)');
  PERFORM pg_temp.ad20_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'consent.opened') = led, 'a refused open writes no opened line');
  PERFORM pg_temp.ad20_ok(desk.fadm_consent_decide(cr, 'approved', 'consent-' || sfx || '-0001', 'admin-ref-' || sfx), 'the customer approval opens the window');
  PERFORM pg_temp.ad20_ok(NOT desk.fadm_consent_decide(cr, 'denied', 'x', 'y'), 'an approved request cannot be decided again');
  SELECT * INTO rr FROM desk.fadm_consent_open(a1, cr);
  PERFORM pg_temp.ad20_ok(rr.case_id = cs AND rr.scope = 'content' AND rr.seconds_left BETWEEN 800 AND 900, 'the asker gets the case, the scope and at most 15 minutes');
  PERFORM pg_temp.ad20_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_consent_open(a2, cr)), 'another staff person cannot use the grant');
  PERFORM pg_temp.ad20_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'consent.opened') = led + 1 AND EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'consent.refused'), 'one opened line for the good open, a refusal line for the bad one');
  BEGIN UPDATE desk.fadm_consent SET access_window = tstzrange(now(), now() + interval '3 hours') WHERE id = cr; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege OR check_violation THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_consent WHERE id = cr; RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad20_ok(desk.fadm_consent_revoke(cr, 'admin-ref-' || sfx), 'the customer can revoke a live window');
  PERFORM pg_temp.ad20_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_consent_open(a1, cr)), 'after a revoke the open is refused');
  cr := desk.fadm_consent_request(a1, cref, 'metadata', 'checking delivery status for the same case again');
  PERFORM desk.fadm_consent_decide(cr, 'approved', 'consent-' || sfx || '-0002', 'admin-ref-' || sfx);
  PERFORM pg_temp.ad20_ok(EXISTS (SELECT 1 FROM desk.fadm_consent_open(a1, cr)), 'a fresh approval opens again');
  ALTER TABLE desk.fadm_consent DISABLE TRIGGER fadm_consent_guard;   -- time travel only inside this rolled-back selftest
  UPDATE desk.fadm_consent SET access_window = tstzrange(now() - interval '2 hours', now() - interval '1 hour') WHERE id = cr;
  ALTER TABLE desk.fadm_consent ENABLE TRIGGER fadm_consent_guard;
  PERFORM pg_temp.ad20_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_consent_open(a1, cr)), 'after the timer the open is refused');
  PERFORM pg_temp.ad20_ok((SELECT status FROM desk.fadm_consent WHERE id = cr) = 'expired', 'and the row is marked expired');
  cr := desk.fadm_consent_request(a1, cref, 'headers', 'looking at routing headers of the same case now');
  PERFORM pg_temp.ad20_ok((desk.fadm_consent_board(a1)->>'waiting')::int = 1 AND desk.fadm_consent_board(gen_random_uuid()) IS NULL AND desk.fadm_consent_board(a1)::text !~* '(@|subject|money)', 'the board shows counts and own requests only, NULL for a stranger');
  PERFORM pg_temp.ad20_ok(desk.fadm_ledger_verify(), 'the ledger hash chain still verifies after all of it');
  PERFORM desk.fadm_audit(NULL, 'ad20.selftest', '{}'::jsonb);
  RAISE EXCEPTION 'AD20 selftest done' USING ERRCODE = 'P0AS2';
EXCEPTION WHEN SQLSTATE 'P0AS2' THEN RAISE NOTICE 'AD20 selftest: ALL RULES PASSED (selftest rows rolled back)';
END $$;
COMMIT;
