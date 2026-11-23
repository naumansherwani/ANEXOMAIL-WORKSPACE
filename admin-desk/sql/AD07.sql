-- ==============================================================================================================================
-- AD7 (ADMIN DESK SQL, step 7, 22 Nov 2026 PKT): STAFF QUEUES = THE CASE (support, move-in, general, billing), assignment, status, Priority Support label + 2-business-day first-reply clock, one audit event per change (phase K foundation).
-- HIS ORDER (22 Nov 11:06): resolved@ = Support queue, moveyourbusiness@ = Managed Move-In queue (a separate work record per company), hello@ general, billing@ authorized finance only; Priority Support = a LABEL + SLA on a support thread (first reply within 2 business days),
--   NOT a mailbox; every employee signs in alone and assignment, reply and status changes are audited; a staff reply leaves from the address the customer used (AD5 fadm_reply_from). Employees NEVER promise (rule 14 / no-promise law): this table stores no promise text.
-- BUILT ON (SCHEMA-FIRST LAW, read in full): AD1 (fadm_owner, fadm_ledger), AD2 (fadm_unit department/team/queue, fadm_check with inheritance, fadm_need, fadm_action case.read / case.reply / case.assign + their policies and zero-trust locks, fadm_burst_limit + fadm_burst_hit),
--   AD5 (fadm_address, fadm_route_inbound, fadm_reply_from, fadm_mailbox_can_read, fadm_mailbox_grant).
-- TECHNOLOGY: PostgreSQL forced RLS, CHECK rules, a legal-transition trigger (status machine decided by the database), append-only event ledger per case, SECURITY DEFINER doors, hash-chained fadm_ledger line per change, team key on every row (50,000-staff design).
--   The Rust mail door (phase I) calls fadm_case_ingest for every inbound mail; the screens (S5) read only through fadm_case_list. No mail body is stored here: only an opaque thread id.
-- RULES: Desk tables only, idempotent, ONE transaction, SELFTEST rolls back (fail P0AH1, success P0AH2), desk_app has no table right, only the doors. DESK ISOLATION: nothing of founder or awam is touched. No money field.
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('ad7.selftest','info','AD7'),('case.ingest','info','a mail became a case'),('case.assign','notice','a case was assigned'),('case.status','notice','a case changed status'),('case.reply','notice','a staff reply was recorded') ON CONFLICT (kind) DO NOTHING;
INSERT INTO desk.fadm_burst_limit (action, max_per_min) VALUES ('case.read', 120) ON CONFLICT (action) DO NOTHING;

-- 1) THE CASE -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS desk.fadm_case_ref_seq;
CREATE TABLE IF NOT EXISTS desk.fadm_case (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ref          text NOT NULL UNIQUE DEFAULT ('C-' || lpad(nextval('desk.fadm_case_ref_seq')::text, 6, '0')),
  queue        text NOT NULL CHECK (queue IN ('general','movein','support','billing')),
  address      text NOT NULL REFERENCES desk.fadm_address(local_part),
  thread_id    text NOT NULL CHECK (length(thread_id) BETWEEN 6 AND 200 AND thread_id !~ '[[:space:]]'),
  company_ref  text CHECK (company_ref IS NULL OR company_ref ~ '^[A-Za-z0-9_-]{6,64}$'),
  subject      text NOT NULL CHECK (length(subject) BETWEEN 1 AND 200 AND subject !~ E'[\\r\\n]'),
  label        text CHECK (label IS NULL OR label ~ '^[a-z0-9_-]{2,30}$'),
  restricted   boolean NOT NULL DEFAULT false,
  priority     boolean NOT NULL DEFAULT false,
  status       text NOT NULL DEFAULT 'new' CHECK (status IN ('new','open','waiting','resolved','closed')),
  assignee     uuid REFERENCES desk.fadm_owner(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  first_reply_at timestamptz,
  sla_due_at   timestamptz,
  UNIQUE (address, thread_id),
  CHECK (NOT priority OR queue = 'support'),                                  -- Priority Support lives only on the support queue (resolved@)
  CHECK (priority = (sla_due_at IS NOT NULL)),                                -- the 2-business-day clock exists exactly when the label does
  CHECK (queue <> 'billing' OR restricted),                                   -- billing cases are always restricted
  CHECK (status = 'new' OR assignee IS NOT NULL OR status = 'closed')         -- a case that left "new" has an owner
);
CREATE INDEX IF NOT EXISTS fadm_case_queue_status ON desk.fadm_case (queue, status, created_at);
CREATE INDEX IF NOT EXISTS fadm_case_assignee ON desk.fadm_case (assignee) WHERE assignee IS NOT NULL;
CREATE INDEX IF NOT EXISTS fadm_case_due ON desk.fadm_case (sla_due_at) WHERE sla_due_at IS NOT NULL AND first_reply_at IS NULL;
CREATE TABLE IF NOT EXISTS desk.fadm_case_event (
  case_id uuid NOT NULL REFERENCES desk.fadm_case(id),
  seq     int  NOT NULL,
  at      timestamptz NOT NULL DEFAULT now(),
  actor   uuid REFERENCES desk.fadm_owner(id),
  kind    text NOT NULL CHECK (kind IN ('ingest','assign','status','reply','priority')),
  detail  jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (case_id, seq)
);
CREATE OR REPLACE FUNCTION desk.fadm_case_event_frozen() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN RAISE EXCEPTION 'case events are append-only' USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_case_event_frozen ON desk.fadm_case_event;
CREATE TRIGGER fadm_case_event_frozen BEFORE UPDATE OR DELETE ON desk.fadm_case_event FOR EACH ROW EXECUTE FUNCTION desk.fadm_case_event_frozen();
DROP TRIGGER IF EXISTS fadm_case_event_frozen_t ON desk.fadm_case_event;
CREATE TRIGGER fadm_case_event_frozen_t BEFORE TRUNCATE ON desk.fadm_case_event FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_case_event_frozen();
-- legal status moves, decided by the database; identity of the case is fixed
CREATE OR REPLACE FUNCTION desk.fadm_case_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'a case is never deleted' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.id <> OLD.id OR NEW.ref <> OLD.ref OR NEW.queue <> OLD.queue OR NEW.address <> OLD.address OR NEW.thread_id <> OLD.thread_id OR NEW.created_at <> OLD.created_at OR NEW.restricted <> OLD.restricted
    THEN RAISE EXCEPTION 'identity, queue, address and restriction of a case are fixed' USING ERRCODE = 'check_violation'; END IF;
  IF OLD.priority AND NOT NEW.priority THEN RAISE EXCEPTION 'a priority label is never taken away silently' USING ERRCODE = 'check_violation'; END IF;
  IF NEW.status <> OLD.status AND NOT ((OLD.status, NEW.status) IN (('new','open'),('open','waiting'),('open','resolved'),('waiting','open'),('waiting','resolved'),('resolved','open'),('resolved','closed'),('new','closed')))
    THEN RAISE EXCEPTION 'illegal status move % -> %', OLD.status, NEW.status USING ERRCODE = 'check_violation'; END IF;
  IF OLD.first_reply_at IS NOT NULL AND NEW.first_reply_at IS DISTINCT FROM OLD.first_reply_at THEN RAISE EXCEPTION 'the first reply time is fixed' USING ERRCODE = 'check_violation'; END IF;
  NEW.updated_at := now();
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_case_00guard ON desk.fadm_case;
CREATE TRIGGER fadm_case_00guard BEFORE UPDATE OR DELETE ON desk.fadm_case FOR EACH ROW EXECUTE FUNCTION desk.fadm_case_guard();

-- 2) HELPERS ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- which organisation unit owns a queue: support and general = the support team, move-in = the migration team; billing has NO unit, only the restricted mailbox grant
CREATE OR REPLACE FUNCTION desk.fadm_queue_unit(p_queue text) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT CASE p_queue WHEN 'support' THEN desk.fadm_unit_id('queue','support_main') WHEN 'general' THEN desk.fadm_unit_id('queue','support_main') WHEN 'movein' THEN desk.fadm_unit_id('queue','migration_main') ELSE NULL END
$f$;
-- may this person work this case? unit relation for staff queues; billing also needs the finance grant; restricted cases (abuse security label) need a grant on the restricted address resolved forwards from = admin-granted label access via unit lead
CREATE OR REPLACE FUNCTION desk.fadm_case_can(p_owner uuid, p_case desk.fadm_case, p_action text, p_ip inet DEFAULT NULL) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE u uuid := desk.fadm_queue_unit(p_case.queue);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_owner AND o.status = 'active') THEN RETURN false; END IF;
  IF p_case.queue = 'billing' THEN
    RETURN desk.fadm_mailbox_can_read(p_owner, 'billing') AND (SELECT allowed FROM desk.fadm_authorize(p_owner, p_action, desk.fadm_unit_id('department','desk'), p_ip));
  END IF;
  IF p_case.restricted AND NOT desk.fadm_check(p_owner, 'unit', u, 'lead') THEN RETURN false; END IF;      -- restricted security labels: team leads and above only
  RETURN (SELECT allowed FROM desk.fadm_authorize(p_owner, p_action, u, p_ip));
END $f$;
-- the first-reply deadline for Priority Support: 2 business days (Mon-Fri, UTC) after the first message
CREATE OR REPLACE FUNCTION desk.fadm_add_business_days(p_from timestamptz, p_days int) RETURNS timestamptz LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog AS $f$
DECLARE t timestamptz := p_from; n int := 0;
BEGIN
  WHILE n < p_days LOOP t := t + interval '1 day'; IF extract(isodow FROM t AT TIME ZONE 'UTC') < 6 THEN n := n + 1; END IF; END LOOP;
  RETURN t;
END $f$;

-- 3) DOORS ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- INGEST (called by the Rust mail door for every inbound mail; no person acts): routes by address through AD5, same thread = same case, Priority Support label only for the support queue
CREATE OR REPLACE FUNCTION desk.fadm_case_ingest(p_address text, p_thread text, p_subject text, p_company_ref text DEFAULT NULL, p_priority boolean DEFAULT false) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record; c uuid; pr boolean; subj text := btrim(regexp_replace(coalesce(p_subject, ''), '[\r\n]+', ' ', 'g'));
BEGIN
  SELECT * INTO r FROM desk.fadm_route_inbound(p_address);
  IF NOT FOUND THEN RAISE EXCEPTION 'address % takes no inbound mail for staff', p_address USING ERRCODE = 'check_violation'; END IF;
  IF subj = '' THEN subj := '(no subject)'; END IF;
  pr := p_priority AND r.queue = 'support';
  SELECT id INTO c FROM desk.fadm_case WHERE address = p_address AND thread_id = p_thread;
  IF FOUND THEN
    IF pr AND NOT (SELECT priority FROM desk.fadm_case WHERE id = c) THEN
      UPDATE desk.fadm_case SET priority = true, sla_due_at = desk.fadm_add_business_days(created_at, 2) WHERE id = c;
      INSERT INTO desk.fadm_case_event (case_id, seq, kind, detail) VALUES (c, (SELECT coalesce(max(seq),0)+1 FROM desk.fadm_case_event WHERE case_id = c), 'priority', '{"label":"priority_support"}');
    END IF;
    RETURN c;
  END IF;
  INSERT INTO desk.fadm_case (queue, address, thread_id, company_ref, subject, label, restricted, priority, sla_due_at)
    VALUES (r.queue, p_address, p_thread, p_company_ref, left(subj, 200), r.label, r.restricted OR r.queue = 'billing', pr, CASE WHEN pr THEN desk.fadm_add_business_days(now(), 2) END) RETURNING id INTO c;
  INSERT INTO desk.fadm_case_event (case_id, seq, kind, detail) VALUES (c, 1, 'ingest', jsonb_build_object('address', p_address, 'queue', r.queue, 'label', r.label, 'priority', pr));
  PERFORM desk.fadm_audit(NULL, 'case.ingest', jsonb_build_object('case', c, 'address', p_address, 'queue', r.queue, 'priority', pr));
  RETURN c;
END $f$;
-- LIST: only what this person may work; billing and restricted cases need their extra right; newest first, priority and overdue first
CREATE OR REPLACE FUNCTION desk.fadm_case_list(p_actor uuid, p_queue text DEFAULT NULL, p_status text DEFAULT NULL, p_limit int DEFAULT 50, p_ip inet DEFAULT NULL)
RETURNS TABLE (id uuid, ref text, queue text, address text, subject text, label text, restricted boolean, priority boolean, status text, assignee uuid, created_at timestamptz, sla_due_at timestamptz, first_reply_at timestamptz, overdue boolean)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_burst_hit(p_actor, 'case.read') THEN RETURN; END IF;
  RETURN QUERY SELECT c.id, c.ref, c.queue, c.address, c.subject, c.label, c.restricted, c.priority, c.status, c.assignee, c.created_at, c.sla_due_at, c.first_reply_at,
      (c.sla_due_at IS NOT NULL AND c.first_reply_at IS NULL AND c.sla_due_at < now())
    FROM desk.fadm_case c
   WHERE (p_queue IS NULL OR c.queue = p_queue) AND (p_status IS NULL OR c.status = p_status) AND desk.fadm_case_can(p_actor, c, 'case.read', p_ip)
   ORDER BY (c.sla_due_at IS NOT NULL AND c.first_reply_at IS NULL) DESC, c.sla_due_at NULLS LAST, c.created_at DESC LIMIT least(greatest(p_limit, 1), 200);
END $f$;
-- ASSIGN: a lead (case.assign) gives a case to an active agent who may work that queue; take = assign to yourself (case.reply is enough)
CREATE OR REPLACE FUNCTION desk.fadm_case_assign(p_actor uuid, p_case uuid, p_to uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c desk.fadm_case;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE id = p_case FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'no such case' USING ERRCODE = 'no_data_found'; END IF;
  IF p_to = p_actor THEN IF NOT desk.fadm_case_can(p_actor, c, 'case.reply', p_ip) THEN RAISE EXCEPTION 'not allowed: case.reply' USING ERRCODE = 'insufficient_privilege'; END IF;
  ELSE IF NOT desk.fadm_case_can(p_actor, c, 'case.assign', p_ip) THEN RAISE EXCEPTION 'not allowed: case.assign' USING ERRCODE = 'insufficient_privilege'; END IF; END IF;
  IF NOT desk.fadm_case_can(p_to, c, 'case.reply', p_ip) THEN RAISE EXCEPTION 'that person may not work this queue' USING ERRCODE = 'check_violation'; END IF;
  IF c.status IN ('resolved','closed') THEN RAISE EXCEPTION 'reopen the case first' USING ERRCODE = 'check_violation'; END IF;
  UPDATE desk.fadm_case SET assignee = p_to, status = CASE WHEN status = 'new' THEN 'open' ELSE status END WHERE id = p_case;
  INSERT INTO desk.fadm_case_event (case_id, seq, actor, kind, detail) VALUES (p_case, (SELECT max(seq)+1 FROM desk.fadm_case_event WHERE case_id = p_case), p_actor, 'assign', jsonb_build_object('to', p_to, 'from', c.assignee));
  PERFORM desk.fadm_audit(p_actor, 'case.assign', jsonb_build_object('case', p_case, 'to', p_to, 'from', c.assignee));
END $f$;
-- STATUS: the assignee or a lead moves the case along the legal path
CREATE OR REPLACE FUNCTION desk.fadm_case_status(p_actor uuid, p_case uuid, p_status text, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c desk.fadm_case;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE id = p_case FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'no such case' USING ERRCODE = 'no_data_found'; END IF;
  IF NOT (c.assignee = p_actor AND desk.fadm_case_can(p_actor, c, 'case.reply', p_ip) OR desk.fadm_case_can(p_actor, c, 'case.assign', p_ip)) THEN RAISE EXCEPTION 'not allowed: only the assignee or a lead changes the status' USING ERRCODE = 'insufficient_privilege'; END IF;
  UPDATE desk.fadm_case SET status = p_status WHERE id = p_case;
  INSERT INTO desk.fadm_case_event (case_id, seq, actor, kind, detail) VALUES (p_case, (SELECT max(seq)+1 FROM desk.fadm_case_event WHERE case_id = p_case), p_actor, 'status', jsonb_build_object('from', c.status, 'to', p_status));
  PERFORM desk.fadm_audit(p_actor, 'case.status', jsonb_build_object('case', p_case, 'from', c.status, 'to', p_status));
END $f$;
-- REPLY RECORD: the assignee records that a staff reply was sent; returns the address it must leave from (AD5); the first one stops the Priority clock. The mail itself is sent by the Rust mail door.
CREATE OR REPLACE FUNCTION desk.fadm_case_reply(p_actor uuid, p_case uuid, p_ip inet DEFAULT NULL) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c desk.fadm_case; rf text;
BEGIN
  SELECT * INTO c FROM desk.fadm_case WHERE id = p_case FOR UPDATE; IF NOT FOUND THEN RAISE EXCEPTION 'no such case' USING ERRCODE = 'no_data_found'; END IF;
  IF c.assignee IS DISTINCT FROM p_actor OR NOT desk.fadm_case_can(p_actor, c, 'case.reply', p_ip) THEN RAISE EXCEPTION 'not allowed: only the assignee replies' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF c.status NOT IN ('open','waiting') THEN RAISE EXCEPTION 'a reply needs an open case' USING ERRCODE = 'check_violation'; END IF;
  rf := desk.fadm_reply_from(c.address);
  IF rf IS NULL THEN RAISE EXCEPTION 'no staff reply is allowed from %', c.address USING ERRCODE = 'check_violation'; END IF;
  UPDATE desk.fadm_case SET first_reply_at = coalesce(first_reply_at, now()), status = 'waiting' WHERE id = p_case;
  INSERT INTO desk.fadm_case_event (case_id, seq, actor, kind, detail) VALUES (p_case, (SELECT max(seq)+1 FROM desk.fadm_case_event WHERE case_id = p_case), p_actor, 'reply', jsonb_build_object('from_address', rf, 'first', c.first_reply_at IS NULL, 'in_time', c.sla_due_at IS NULL OR now() <= c.sla_due_at));
  PERFORM desk.fadm_audit(p_actor, 'case.reply', jsonb_build_object('case', p_case, 'from_address', rf));
  RETURN rf;
END $f$;

-- 4) RLS AND GRANTS ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_case','fadm_case_event'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_case_ref_seq FROM PUBLIC, desk_app;
REVOKE ALL ON FUNCTION desk.fadm_case_event_frozen(), desk.fadm_case_guard(), desk.fadm_queue_unit(text), desk.fadm_case_can(uuid, desk.fadm_case, text, inet), desk.fadm_add_business_days(timestamptz,int),
  desk.fadm_case_ingest(text,text,text,text,boolean), desk.fadm_case_list(uuid,text,text,int,inet), desk.fadm_case_assign(uuid,uuid,uuid,inet), desk.fadm_case_status(uuid,uuid,text,inet), desk.fadm_case_reply(uuid,uuid,inet) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_case_ingest(text,text,text,text,boolean), desk.fadm_case_list(uuid,text,text,int,inet), desk.fadm_case_assign(uuid,uuid,uuid,inet), desk.fadm_case_status(uuid,uuid,text,inet), desk.fadm_case_reply(uuid,uuid,inet), desk.fadm_add_business_days(timestamptz,int) TO desk_app;

-- SELFTEST (rolls back; P0AH2 = success) ----------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad7_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD7 selftest: %', msg USING ERRCODE = 'P0AH1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; a2 uuid; m1 uuid; l uuid; f uuid; sfx text := substr(md5(random()::text), 1, 8); sup uuid := desk.fadm_unit_id('team','support'); mig uuid := desk.fadm_unit_id('team','migration'); dept uuid := desk.fadm_unit_id('department','desk');
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; cs uuid; cp uuid; cm uuid; cb uuid; ca uuid; cg uuid; r text; n int; ts timestamptz;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o7-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a1-' || sfx || '@selftest.invalid', 'Agent One', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a2-' || sfx || '@selftest.invalid', 'Agent Two', 'agent', NULL, true, 'active', true) RETURNING id INTO a2;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('m1-' || sfx || '@selftest.invalid', 'Move Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO m1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('l1-' || sfx || '@selftest.invalid', 'Lead', 'agent', NULL, true, 'active', true) RETURNING id INTO l;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('f1-' || sfx || '@selftest.invalid', 'Finance', 'agent', NULL, true, 'active', true) RETURNING id INTO f;
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent'); PERFORM desk.fadm_access_grant(o, a2, sup, 'agent'); PERFORM desk.fadm_access_grant(o, m1, mig, 'agent'); PERFORM desk.fadm_access_grant(o, l, sup, 'lead'); PERFORM desk.fadm_access_grant(o, f, dept, 'agent');
  PERFORM desk.fadm_mailbox_grant_set(o, f, 'billing', true);
  -- the business-day clock: Friday + 2 business days = Tuesday; Sunday + 2 = Tuesday
  PERFORM pg_temp.ad7_ok(desk.fadm_add_business_days('2026-11-20 10:00+00', 2) = '2026-11-24 10:00+00' AND desk.fadm_add_business_days('2026-11-22 10:00+00', 2) = '2026-11-24 10:00+00', 'two business days skip the weekend');
  -- ingest: routing by address, one case per thread, priority only on support
  cs := desk.fadm_case_ingest('resolved', 'thread-support-1', 'I cannot sign in', 'co_selftest_1');
  PERFORM pg_temp.ad7_ok((SELECT queue = 'support' AND status = 'new' AND NOT priority AND sla_due_at IS NULL AND assignee IS NULL FROM desk.fadm_case WHERE id = cs), 'resolved@ makes a support case, new, no clock');
  PERFORM pg_temp.ad7_ok(desk.fadm_case_ingest('resolved', 'thread-support-1', 'Re: I cannot sign in') = cs, 'the same thread is the same case');
  cp := desk.fadm_case_ingest('resolved', 'thread-prio-1', 'Urgent mail problem', 'co_selftest_2', true);
  PERFORM pg_temp.ad7_ok((SELECT priority AND sla_due_at > created_at + interval '1 day' AND sla_due_at <= created_at + interval '4 days' FROM desk.fadm_case WHERE id = cp), 'Priority Support carries the label and a 2-business-day clock');
  cm := desk.fadm_case_ingest('moveyourbusiness', 'thread-move-1', 'Move 12 mailboxes', 'co_selftest_3', true);
  PERFORM pg_temp.ad7_ok((SELECT queue = 'movein' AND NOT priority AND sla_due_at IS NULL FROM desk.fadm_case WHERE id = cm), 'move-in goes to its own queue and never takes the Priority label');
  cb := desk.fadm_case_ingest('billing', 'thread-bill-1', 'A question about my account');
  PERFORM pg_temp.ad7_ok((SELECT queue = 'billing' AND restricted FROM desk.fadm_case WHERE id = cb), 'billing is a restricted case');
  ca := desk.fadm_case_ingest('abuse', 'thread-abuse-1', 'Phishing report');
  PERFORM pg_temp.ad7_ok((SELECT queue = 'support' AND label = 'security' AND restricted FROM desk.fadm_case WHERE id = ca), 'abuse@ lands in support with the restricted security label');
  cg := desk.fadm_case_ingest('hello', 'thread-hello-1', 'Hello, a question');
  PERFORM pg_temp.ad7_ok((SELECT queue = 'general' FROM desk.fadm_case WHERE id = cg), 'hello@ is the general queue');
  BEGIN PERFORM desk.fadm_case_ingest('noreply', 'thread-nr-1', 'x'); RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_case_ingest('naumansherwani.founder', 'thread-f-1', 'x'); RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- who sees what
  PERFORM pg_temp.ad7_ok((SELECT count(*) FROM desk.fadm_case_list(a1)) = 3 AND NOT EXISTS (SELECT 1 FROM desk.fadm_case_list(a1) WHERE id IN (cm, cb, ca)), 'a support agent sees support and general only (no move-in, billing or security)');
  PERFORM pg_temp.ad7_ok((SELECT count(*) FROM desk.fadm_case_list(m1)) = 1 AND EXISTS (SELECT 1 FROM desk.fadm_case_list(m1) WHERE id = cm), 'a move-in agent sees only the move-in queue');
  PERFORM pg_temp.ad7_ok(EXISTS (SELECT 1 FROM desk.fadm_case_list(l) WHERE id = ca), 'a team lead sees the restricted security case');
  PERFORM pg_temp.ad7_ok(EXISTS (SELECT 1 FROM desk.fadm_case_list(f) WHERE id = cb) AND NOT EXISTS (SELECT 1 FROM desk.fadm_case_list(a1) WHERE id = cb), 'only the granted finance person sees billing');
  PERFORM pg_temp.ad7_ok((SELECT id FROM desk.fadm_case_list(a1, 'support', 'new') LIMIT 1) = cp, 'priority and clocked cases are listed first');
  -- assignment
  PERFORM desk.fadm_case_assign(a1, cs, a1);
  PERFORM pg_temp.ad7_ok((SELECT assignee = a1 AND status = 'open' FROM desk.fadm_case WHERE id = cs), 'taking a case makes it open and yours');
  BEGIN PERFORM desk.fadm_case_assign(m1, cp, m1); RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_case_assign(a1, cp, a2); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_case_assign(l, cp, m1); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_case_assign(l, cp, a2);
  PERFORM pg_temp.ad7_ok((SELECT assignee = a2 FROM desk.fadm_case WHERE id = cp), 'a lead assigns a case to an agent of that queue');
  BEGIN PERFORM desk.fadm_case_assign(a1, ca, a1); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- status machine
  BEGIN PERFORM desk.fadm_case_status(a1, cs, 'closed'); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_case_status(a2, cs, 'resolved'); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- reply: only the assignee, from the right address, the first one stops the clock
  r := desk.fadm_case_reply(a1, cs);
  PERFORM pg_temp.ad7_ok(r = 'resolved' AND (SELECT first_reply_at IS NOT NULL AND status = 'waiting' FROM desk.fadm_case WHERE id = cs), 'a support reply leaves from resolved@ and the case waits');
  BEGIN PERFORM desk.fadm_case_reply(a1, cp); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  r := desk.fadm_case_reply(a2, cp);
  PERFORM pg_temp.ad7_ok((SELECT first_reply_at IS NOT NULL AND (SELECT (detail->>'in_time')::boolean FROM desk.fadm_case_event WHERE case_id = cp AND kind = 'reply') FROM desk.fadm_case WHERE id = cp), 'the Priority clock stops at the first reply and records in time');
  PERFORM desk.fadm_case_assign(m1, cm, m1);
  PERFORM pg_temp.ad7_ok(desk.fadm_case_reply(m1, cm) = 'moveyourbusiness', 'a move-in reply leaves from moveyourbusiness@');
  PERFORM desk.fadm_case_assign(l, ca, l);
  PERFORM pg_temp.ad7_ok(desk.fadm_case_reply(l, ca) = 'resolved', 'a reply to a forwarded abuse report leaves from resolved@');
  PERFORM desk.fadm_case_status(a1, cs, 'resolved'); PERFORM desk.fadm_case_status(a1, cs, 'closed');
  BEGIN PERFORM desk.fadm_case_reply(a1, cs); RAISE EXCEPTION 'no refusal 10' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- identity is fixed, events are append-only, nothing is deleted
  BEGIN UPDATE desk.fadm_case SET queue = 'general' WHERE id = cs; RAISE EXCEPTION 'no refusal 11' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_case WHERE id = cs; RAISE EXCEPTION 'no refusal 12' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.fadm_case_event SET kind = 'status'; RAISE EXCEPTION 'no refusal 13' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_case_event; RAISE EXCEPTION 'no refusal 14' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.fadm_case SET priority = false, sla_due_at = NULL WHERE id = cp; RAISE EXCEPTION 'no refusal 15' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_case (queue, address, thread_id, subject, priority) VALUES ('movein', 'moveyourbusiness', 'thread-x-9999', 'x', true); RAISE EXCEPTION 'no refusal 16' USING ERRCODE = 'P0AH1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad7_ok((SELECT count(*) FROM desk.fadm_case_event WHERE case_id = cs) = 5, 'every change of the case left an event (ingest, assign, reply, resolved, closed)');
  PERFORM pg_temp.ad7_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind IN ('case.assign','case.status','case.reply','case.ingest')) >= 10, 'the changes are in the hash-chained ledger');
  PERFORM desk.fadm_audit(o, 'ad7.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad7_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad7_ok(NOT has_table_privilege('desk_app', 'desk.fadm_case', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_case_event', 'INSERT') AND has_function_privilege('desk_app', 'desk.fadm_case_list(uuid,text,text,int,inet)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_case_can(uuid,desk.fadm_case,text,inet)', 'EXECUTE'), 'desk_app reaches cases only through the doors');
  RAISE EXCEPTION 'AD7 selftest passed, rolling back' USING ERRCODE = 'P0AH2';
EXCEPTION WHEN SQLSTATE 'P0AH2' THEN RAISE NOTICE 'AD7 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
