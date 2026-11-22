-- ==============================================================================================================================
-- AD10 (ADMIN DESK SQL, step 10, 23 Nov 2026 PKT): ESCALATION CASES. Phase 1l (D5c). List: docs/claude/admin-desk/D5C-ESCALATE-LIST-23NOV.md (L1..L12).
-- BUILT ON (SCHEMA-FIRST LAW, read in full): AD1 (fadm_owner, fadm_ledger, forced RLS + p_installer pattern), AD9 (fadm_runbook_staff, version chain pattern), AD9b (tick chain + flood ceiling pattern), AD2/AD3 CHECK rule "no PUBLIC execute".
-- TECHNOLOGY: a case is a REAL record (L1); its status is the latest of APPEND-ONLY events with their OWN SHA-256 hash chain (L3); an IDEMPOTENT request id (L4);
--   a TRANSACTIONAL OUTBOX written in the SAME transaction as the case, claimed with FOR UPDATE SKIP LOCKED, retried with back-off, dead-lettered after 8 tries (L5, L9);
--   SECURITY DEFINER doors only (desk_app has no table right, trigger and helper functions revoked from PUBLIC), forced RLS, a flood ceiling (L10), a selftest that rolls back.
-- RULES: Desk tables only (fadm_*), nothing of the founder lane. Only metadata and an audit reference; the free note is capped and refuses money and promise words (L7). Idempotent, ONE transaction.
-- The founder side that RECEIVES the hand-over is the later phase FOUNDER-ESCALATION-INBOX: the claim and mark functions below are NOT granted to desk_app until that phase (no unused door).
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('ad10.selftest','info','AD10'),('escalation.flood','notice','a person opened cases faster than the ceiling'),('escalation.stuck','high','a case hand-over failed 8 times and is parked for a person to look at')
ON CONFLICT (kind) DO NOTHING;

CREATE TABLE IF NOT EXISTS desk.fadm_escalation (
  id          bigserial PRIMARY KEY,
  case_no     text UNIQUE,
  request_id  text NOT NULL UNIQUE CHECK (request_id ~ '^[A-Za-z0-9_-]{16,64}$'),
  company_ref text NOT NULL CHECK (company_ref ~ '^[A-Za-z0-9_.:-]{3,64}$'),
  reason      text NOT NULL CHECK (reason IN ('payment_not_active','features_missing','limit_reached','grace_period','suspended','cannot_sign_in','mail_not_delivered','attachment_blocked','many_customers','other')),
  priority    text NOT NULL CHECK (priority IN ('urgent','high','normal')),
  flag        text NOT NULL DEFAULT 'none' CHECK (flag IN ('none','payment_received_not_active','limit_reached','suspended','many_customers')),
  audit_ref   text NOT NULL DEFAULT '' CHECK (audit_ref ~ '^[A-Za-z0-9_.:-]{0,80}$'),
  runbook_key text,
  note        text NOT NULL DEFAULT '' CHECK (length(note) <= 280 AND note !~* '(promise|guarantee|definitely|refund|credit|compensat|discount|invoice|price|amount|iban|card number|[$£€])'),   -- no-money-gate-ok -- no-money-gate-ok
  actor       uuid NOT NULL REFERENCES desk.fadm_owner(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS fadm_escalation_company_i ON desk.fadm_escalation (company_ref, id DESC);
CREATE INDEX IF NOT EXISTS fadm_escalation_actor_i ON desk.fadm_escalation (actor, created_at DESC);

CREATE TABLE IF NOT EXISTS desk.fadm_escalation_event (
  id        bigserial PRIMARY KEY,
  case_id   bigint NOT NULL REFERENCES desk.fadm_escalation(id),
  kind      text NOT NULL CHECK (kind IN ('created','queued','received','in_review','decided','returned','closed','stuck')),
  actor     uuid REFERENCES desk.fadm_owner(id),
  detail    jsonb NOT NULL DEFAULT '{}'::jsonb,
  at        timestamptz NOT NULL DEFAULT now(),
  prev_hash bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash      bytea NOT NULL DEFAULT sha256('x'::bytea)
);
CREATE INDEX IF NOT EXISTS fadm_escalation_event_case_i ON desk.fadm_escalation_event (case_id, id);

CREATE TABLE IF NOT EXISTS desk.fadm_escalation_outbox (
  id           bigserial PRIMARY KEY,
  case_id      bigint NOT NULL UNIQUE REFERENCES desk.fadm_escalation(id),
  payload      jsonb NOT NULL,
  state        text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending','published','stuck')),
  attempts     integer NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 8),
  next_try     timestamptz NOT NULL DEFAULT now(),
  created_at   timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  CHECK ((state = 'published') = (published_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS fadm_escalation_outbox_pending_i ON desk.fadm_escalation_outbox (next_try, id) WHERE state = 'pending';

-- case number (ESC-YYMMDD-00042) and the event hash chain, both by trigger ------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_escalation_no() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN NEW.case_no := 'ESC-' || to_char(now() AT TIME ZONE 'UTC', 'YYMMDD') || '-' || lpad(NEW.id::text, 5, '0'); RETURN NEW; END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_escalation_event_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_escalation_event'));
  SELECT hash INTO p FROM desk.fadm_escalation_event ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-case-genesis'::bytea); END IF;
  NEW.at := now(); NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.case_id || '|' || NEW.kind || '|' || COALESCE(NEW.actor::text, '-') || '|' || NEW.detail::text || '|' || NEW.at::text, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_escalation_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
-- the case row itself never changes and never goes away
DROP TRIGGER IF EXISTS fadm_escalation_no ON desk.fadm_escalation;
CREATE TRIGGER fadm_escalation_no BEFORE INSERT ON desk.fadm_escalation FOR EACH ROW EXECUTE FUNCTION desk.fadm_escalation_no();
DROP TRIGGER IF EXISTS fadm_escalation_frozen ON desk.fadm_escalation;
CREATE TRIGGER fadm_escalation_frozen BEFORE UPDATE OR DELETE ON desk.fadm_escalation FOR EACH ROW EXECUTE FUNCTION desk.fadm_escalation_frozen();
DROP TRIGGER IF EXISTS fadm_escalation_frozen_t ON desk.fadm_escalation;
CREATE TRIGGER fadm_escalation_frozen_t BEFORE TRUNCATE ON desk.fadm_escalation FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_escalation_frozen();
DROP TRIGGER IF EXISTS fadm_escalation_event_chain ON desk.fadm_escalation_event;
CREATE TRIGGER fadm_escalation_event_chain BEFORE INSERT ON desk.fadm_escalation_event FOR EACH ROW EXECUTE FUNCTION desk.fadm_escalation_event_chain();
DROP TRIGGER IF EXISTS fadm_escalation_event_frozen ON desk.fadm_escalation_event;
CREATE TRIGGER fadm_escalation_event_frozen BEFORE UPDATE OR DELETE ON desk.fadm_escalation_event FOR EACH ROW EXECUTE FUNCTION desk.fadm_escalation_frozen();
DROP TRIGGER IF EXISTS fadm_escalation_event_frozen_t ON desk.fadm_escalation_event;
CREATE TRIGGER fadm_escalation_event_frozen_t BEFORE TRUNCATE ON desk.fadm_escalation_event FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_escalation_frozen();

DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_escalation','fadm_escalation_event','fadm_escalation_outbox'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t); EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('REVOKE ALL ON desk.%I FROM PUBLIC', t); EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t); EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
  END LOOP;
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_escalation_id_seq, desk.fadm_escalation_event_id_seq, desk.fadm_escalation_outbox_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_escalation_no(), desk.fadm_escalation_event_chain(), desk.fadm_escalation_frozen() FROM PUBLIC;   -- the AD1c lesson: a helper is never PUBLIC-executable

-- the acknowledge TARGET per priority in minutes: a target to reply, never a promise (L2)
CREATE OR REPLACE FUNCTION desk.fadm_escalation_target_min(p_priority text) RETURNS int LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  SELECT CASE p_priority WHEN 'urgent' THEN 15 WHEN 'high' THEN 60 ELSE 240 END $f$;
REVOKE ALL ON FUNCTION desk.fadm_escalation_target_min(text) FROM PUBLIC;

-- DOOR: open a case (L1, L4, L5, L10). Returns {case_no, status, duplicate} or NULL (refused). Idempotent by request id; one open problem = one case (10 minute window).
CREATE OR REPLACE FUNCTION desk.fadm_escalation_create(p_owner uuid, p_request_id text, p_company text, p_reason text, p_priority text, p_flag text, p_audit_ref text, p_runbook_key text, p_note text)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c desk.fadm_escalation; recent int; dup bigint; pay jsonb;
BEGIN
  IF NOT desk.fadm_runbook_staff(p_owner) THEN RETURN NULL; END IF;
  IF p_request_id IS NULL OR p_request_id !~ '^[A-Za-z0-9_-]{16,64}$' OR p_company IS NULL OR p_company !~ '^[A-Za-z0-9_.:-]{3,64}$' THEN RETURN NULL; END IF;
  IF p_reason NOT IN ('payment_not_active','features_missing','limit_reached','grace_period','suspended','cannot_sign_in','mail_not_delivered','attachment_blocked','many_customers','other') THEN RETURN NULL; END IF;
  IF p_priority NOT IN ('urgent','high','normal') OR p_flag NOT IN ('none','payment_received_not_active','limit_reached','suspended','many_customers') THEN RETURN NULL; END IF;
  p_audit_ref := COALESCE(p_audit_ref, ''); p_note := COALESCE(p_note, '');
  IF p_audit_ref !~ '^[A-Za-z0-9_.:-]{0,80}$' OR length(p_note) > 280 OR p_note ~* '(promise|guarantee|definitely|refund|credit|compensat|discount|invoice|price|amount|iban|card number|[$£€])' THEN RETURN NULL; END IF;   -- no-money-gate-ok -- no-money-gate-ok
  -- idempotent: the same request id is the same case
  SELECT * INTO c FROM desk.fadm_escalation WHERE request_id = p_request_id;
  IF FOUND THEN RETURN jsonb_build_object('case_no', c.case_no, 'status', (SELECT kind FROM desk.fadm_escalation_event WHERE case_id = c.id ORDER BY id DESC LIMIT 1), 'duplicate', true); END IF;
  -- one open problem is one case: same company + same reason inside 10 minutes
  SELECT id INTO dup FROM desk.fadm_escalation WHERE company_ref = p_company AND reason = p_reason AND created_at > now() - interval '10 minutes' ORDER BY id DESC LIMIT 1;
  IF dup IS NOT NULL THEN SELECT * INTO c FROM desk.fadm_escalation WHERE id = dup;
    RETURN jsonb_build_object('case_no', c.case_no, 'status', (SELECT kind FROM desk.fadm_escalation_event WHERE case_id = c.id ORDER BY id DESC LIMIT 1), 'duplicate', true); END IF;
  SELECT count(*) INTO recent FROM desk.fadm_escalation WHERE actor = p_owner AND created_at > now() - interval '1 minute';
  IF recent >= 10 THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (p_owner, 'escalation.flood', jsonb_build_object('per_minute', recent)); RETURN NULL; END IF;
  INSERT INTO desk.fadm_escalation (request_id, company_ref, reason, priority, flag, audit_ref, runbook_key, note, actor)
    VALUES (p_request_id, p_company, p_reason, p_priority, p_flag, p_audit_ref, p_runbook_key, p_note, p_owner) RETURNING * INTO c;
  INSERT INTO desk.fadm_escalation_event (case_id, kind, actor) VALUES (c.id, 'created', p_owner);
  pay := jsonb_build_object('case_no', c.case_no, 'request_id', c.request_id, 'company_ref', c.company_ref, 'reason', c.reason, 'priority', c.priority, 'flag', c.flag,
    'audit_ref', c.audit_ref, 'runbook_key', c.runbook_key, 'note', c.note, 'employee', (SELECT display_name FROM desk.fadm_owner WHERE id = p_owner),
    'created_at', c.created_at, 'target_minutes', desk.fadm_escalation_target_min(c.priority));
  INSERT INTO desk.fadm_escalation_outbox (case_id, payload) VALUES (c.id, pay);              -- the hand-over row: SAME transaction as the case (L5)
  INSERT INTO desk.fadm_escalation_event (case_id, kind, actor) VALUES (c.id, 'queued', p_owner);
  RETURN jsonb_build_object('case_no', c.case_no, 'status', 'queued', 'duplicate', false);
END $f$;

-- DOOR: the cases of one company, or (no company) my own cases. Case number + status + the acknowledge target; never more (L2).
CREATE OR REPLACE FUNCTION desk.fadm_escalation_list(p_owner uuid, p_company text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_runbook_staff(p_owner) THEN RETURN NULL; END IF;
  IF p_company IS NOT NULL AND p_company !~ '^[A-Za-z0-9_.:-]{3,64}$' THEN RETURN NULL; END IF;
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object('case_no', c.case_no, 'company_ref', c.company_ref, 'reason', c.reason, 'priority', c.priority,
      'status', (SELECT kind FROM desk.fadm_escalation_event e WHERE e.case_id = c.id ORDER BY e.id DESC LIMIT 1), 'created_at', c.created_at,
      'target_minutes', desk.fadm_escalation_target_min(c.priority), 'by', o.display_name,
      'events', (SELECT jsonb_agg(jsonb_build_object('kind', e.kind, 'at', e.at) ORDER BY e.id) FROM desk.fadm_escalation_event e WHERE e.case_id = c.id)) ORDER BY c.id DESC)
    FROM (SELECT * FROM desk.fadm_escalation WHERE (p_company IS NOT NULL AND company_ref = p_company) OR (p_company IS NULL AND actor = p_owner) ORDER BY id DESC LIMIT 50) c
    JOIN desk.fadm_owner o ON o.id = c.actor), '[]'::jsonb);
END $f$;

-- INTERNAL (installer / founder-side phase only, NOT granted to desk_app yet): claim pending hand-over rows with SKIP LOCKED, in id order, only those due (L5)
CREATE OR REPLACE FUNCTION desk.fadm_escalation_outbox_claim(p_batch int) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF p_batch IS NULL OR p_batch < 1 OR p_batch > 100 THEN RETURN '[]'::jsonb; END IF;
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object('outbox_id', q.id, 'attempts', q.attempts, 'payload', q.payload) ORDER BY q.id)
    FROM (SELECT id, attempts, payload FROM desk.fadm_escalation_outbox WHERE state = 'pending' AND next_try <= now() ORDER BY id LIMIT p_batch FOR UPDATE SKIP LOCKED) q), '[]'::jsonb);
END $f$;
-- INTERNAL: the result of one delivery. ok = published; failure = exponential back-off with jitter, and after 8 tries the case is parked as 'stuck' with a ledger alert (L9)
CREATE OR REPLACE FUNCTION desk.fadm_escalation_outbox_mark(p_outbox_id bigint, p_ok boolean) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE o desk.fadm_escalation_outbox;
BEGIN
  SELECT * INTO o FROM desk.fadm_escalation_outbox WHERE id = p_outbox_id AND state = 'pending' FOR UPDATE; IF NOT FOUND THEN RETURN false; END IF;
  IF p_ok THEN
    UPDATE desk.fadm_escalation_outbox SET state = 'published', published_at = now() WHERE id = o.id;
    INSERT INTO desk.fadm_escalation_event (case_id, kind) VALUES (o.case_id, 'received');
  ELSIF o.attempts + 1 >= 8 THEN
    UPDATE desk.fadm_escalation_outbox SET state = 'stuck', attempts = 8 WHERE id = o.id;
    INSERT INTO desk.fadm_escalation_event (case_id, kind, detail) VALUES (o.case_id, 'stuck', jsonb_build_object('attempts', 8));
    INSERT INTO desk.fadm_ledger (kind, detail) VALUES ('escalation.stuck', jsonb_build_object('case_id', o.case_id));
  ELSE
    UPDATE desk.fadm_escalation_outbox SET attempts = o.attempts + 1, next_try = now() + make_interval(secs => (power(2, o.attempts + 1) * 5) + floor(random() * 5)) WHERE id = o.id;
  END IF;
  RETURN true;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_escalation_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record; p bytea := sha256('anexomail-desk-case-genesis'::bytea);
BEGIN
  FOR r IN SELECT * FROM desk.fadm_escalation_event ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.case_id || '|' || r.kind || '|' || COALESCE(r.actor::text, '-') || '|' || r.detail::text || '|' || r.at::text, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;
REVOKE ALL ON FUNCTION desk.fadm_escalation_create(uuid,text,text,text,text,text,text,text,text), desk.fadm_escalation_list(uuid,text), desk.fadm_escalation_outbox_claim(int), desk.fadm_escalation_outbox_mark(bigint,boolean), desk.fadm_escalation_chain_verify() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_escalation_create(uuid,text,text,text,text,text,text,text,text), desk.fadm_escalation_list(uuid,text), desk.fadm_escalation_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AJ1) ---------------------------------------------------------------------------------------------------------
DO $t$
DECLARE ag uuid; ow uuid; r jsonb; n0 int; i int; cl jsonb; ob bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('ad10-selftest-owner@example.test','AD10 owner','owner','$argon2id$selftest') RETURNING id INTO ow;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('ad10-selftest-agent@example.test','AD10 agent','agent',NULL,true,'active',true) RETURNING id INTO ag;
  r := desk.fadm_escalation_create(ag, 'req-selftest-000000001', 'TESTCO001', 'suspended', 'high', 'suspended', 'audit:abc123', 'R5', 'customer asked twice');
  IF r IS NULL OR r->>'status' <> 'queued' OR (r->>'duplicate')::boolean IS NOT FALSE OR r->>'case_no' !~ '^ESC-[0-9]{6}-[0-9]{5}$' THEN RAISE EXCEPTION 'AD10 selftest: case not created: %', r; END IF;
  -- idempotent: the same request id, the same case, no new rows
  SELECT count(*) INTO n0 FROM desk.fadm_escalation;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000001', 'TESTCO001', 'suspended', 'high', 'suspended', 'audit:abc123', 'R5', 'x')->>'case_no' <> r->>'case_no' OR (SELECT count(*) FROM desk.fadm_escalation) <> n0 THEN RAISE EXCEPTION 'AD10 selftest: a repeat made a second case'; END IF;
  -- one open problem is one case (other request id, same company + reason)
  IF (desk.fadm_escalation_create(ag, 'req-selftest-000000002', 'TESTCO001', 'suspended', 'high', 'none', '', NULL, '')->>'duplicate')::boolean IS NOT TRUE THEN RAISE EXCEPTION 'AD10 selftest: same problem opened a second case'; END IF;
  -- refusals leave NO rows (atomic): bad company, money word, promise word, bad priority, bad reason, stranger, too long, bad request id
  SELECT count(*) INTO n0 FROM desk.fadm_escalation;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000003', 'bad company!', 'other', 'high', 'none', '', NULL, '') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: bad company accepted'; END IF;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000004', 'TESTCO002', 'other', 'high', 'none', '', NULL, 'please refund them') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a money word was accepted'; END IF;   -- no-money-gate-ok
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000005', 'TESTCO002', 'other', 'high', 'none', '', NULL, 'we promise a fix') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a promise word was accepted'; END IF;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000006', 'TESTCO002', 'other', 'asap', 'none', '', NULL, '') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: bad priority accepted'; END IF;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000007', 'TESTCO002', 'weird', 'high', 'none', '', NULL, '') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: bad reason accepted'; END IF;
  IF desk.fadm_escalation_create(gen_random_uuid(), 'req-selftest-000000008', 'TESTCO002', 'other', 'high', 'none', '', NULL, '') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a stranger opened a case'; END IF;
  IF desk.fadm_escalation_create(ag, 'req-selftest-000000009', 'TESTCO002', 'other', 'high', 'none', '', NULL, repeat('x', 281)) IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a long note was accepted'; END IF;
  IF desk.fadm_escalation_create(ag, 'short', 'TESTCO002', 'other', 'high', 'none', '', NULL, '') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a short request id was accepted'; END IF;
  IF (SELECT count(*) FROM desk.fadm_escalation) <> n0 THEN RAISE EXCEPTION 'AD10 selftest: a refusal left a row behind'; END IF;
  -- the hand-over row exists, written with the case, with the metadata only
  SELECT id, payload INTO ob, cl FROM desk.fadm_escalation_outbox o ORDER BY id DESC LIMIT 1;
  IF cl->>'company_ref' <> 'TESTCO001' OR cl ? 'amount' OR cl->>'employee' <> 'AD10 agent' OR (cl->>'target_minutes')::int <> 60 THEN RAISE EXCEPTION 'AD10 selftest: hand-over payload wrong: %', cl; END IF; -- no-money-gate-ok
  -- lists: by company and mine; another company sees nothing
  IF jsonb_array_length(desk.fadm_escalation_list(ow, 'TESTCO001')) <> 1 OR jsonb_array_length(desk.fadm_escalation_list(ag, NULL)) <> 1 OR jsonb_array_length(desk.fadm_escalation_list(ow, 'OTHERCO009')) <> 0 THEN RAISE EXCEPTION 'AD10 selftest: list wrong'; END IF;
  IF desk.fadm_escalation_list(gen_random_uuid(), 'TESTCO001') IS NOT NULL THEN RAISE EXCEPTION 'AD10 selftest: a stranger listed cases'; END IF;
  -- claim (SKIP LOCKED), publish -> received event; a published row is not claimed again
  IF jsonb_array_length(desk.fadm_escalation_outbox_claim(10)) <> 1 THEN RAISE EXCEPTION 'AD10 selftest: claim did not return the pending row'; END IF;
  IF desk.fadm_escalation_outbox_mark(ob, true) IS NOT TRUE OR jsonb_array_length(desk.fadm_escalation_outbox_claim(10)) <> 0 THEN RAISE EXCEPTION 'AD10 selftest: publish failed'; END IF;
  IF desk.fadm_escalation_list(ow, 'TESTCO001')->0->>'status' <> 'received' THEN RAISE EXCEPTION 'AD10 selftest: status did not become received'; END IF;
  -- retries back off, and after 8 failures the case is parked and the ledger shouts
  PERFORM desk.fadm_escalation_create(ag, 'req-selftest-000000010', 'TESTCO003', 'other', 'normal', 'none', '', NULL, '');
  SELECT id INTO ob FROM desk.fadm_escalation_outbox WHERE state = 'pending' ORDER BY id DESC LIMIT 1;
  FOR i IN 1..7 LOOP
    IF desk.fadm_escalation_outbox_mark(ob, false) IS NOT TRUE THEN RAISE EXCEPTION 'AD10 selftest: failure mark refused at %', i; END IF;
    IF (SELECT next_try FROM desk.fadm_escalation_outbox WHERE id = ob) <= now() THEN RAISE EXCEPTION 'AD10 selftest: no back-off at %', i; END IF;
    UPDATE desk.fadm_escalation_outbox SET next_try = now() WHERE id = ob;
  END LOOP;
  IF desk.fadm_escalation_outbox_mark(ob, false) IS NOT TRUE THEN RAISE EXCEPTION 'AD10 selftest: the eighth failure mark was refused'; END IF;
  IF (SELECT state FROM desk.fadm_escalation_outbox WHERE id = ob) <> 'stuck' THEN RAISE EXCEPTION 'AD10 selftest: not parked after 8 failures'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'escalation.stuck') THEN RAISE EXCEPTION 'AD10 selftest: the stuck case did not reach the ledger'; END IF;
  -- flood ceiling: 10 a minute per person
  FOR i IN 1..12 LOOP PERFORM desk.fadm_escalation_create(ow, 'req-flood-selftest-' || lpad(i::text, 4, '0'), 'FLOODCO' || i, 'other', 'normal', 'none', '', NULL, ''); END LOOP;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'escalation.flood') THEN RAISE EXCEPTION 'AD10 selftest: the flood ceiling did not fire'; END IF;
  -- append-only and chains
  BEGIN UPDATE desk.fadm_escalation SET note = 'edit'; RAISE EXCEPTION 'AD10 selftest: a case was edited'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_escalation_event; RAISE EXCEPTION 'AD10 selftest: events deleted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF desk.fadm_escalation_chain_verify() IS NOT TRUE OR desk.fadm_ledger_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD10 selftest: a chain is broken'; END IF;
  RAISE EXCEPTION 'AD10 selftest passed' USING ERRCODE = 'P0AJ1';
EXCEPTION WHEN SQLSTATE 'P0AJ1' THEN NULL;
END $t$;
COMMIT;
