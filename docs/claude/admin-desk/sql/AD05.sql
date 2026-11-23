-- ==============================================================================================================================
-- AD5 (ADMIN DESK SQL, step 5, 22 Nov 2026 PKT): THE ADDRESS-ROLE TRUTH = which address is which queue, who may read it, which address a staff reply leaves from (phase I foundation).
-- HIS ORDER (22 Nov 11:06): resolved@ = Support queue (Priority Support is only a label + SLA on a thread, NOT a mailbox), moveyourbusiness@ = Managed Move-In queue, hello@ = general, billing@ = authorized finance staff only, leo@ = system, the founder address is
--   private (staff never log into it), noreply@ send-only, postmaster@ / abuse@ / dmarc@ forward to resolved@ with a label. A staff reply leaves from the address the customer wrote to (support from resolved@, move-in from moveyourbusiness@).
-- BUILT ON (SCHEMA-FIRST LAW, read in full before writing): AD1 (fadm_mailbox with its CHECKs, the seed resolved / billing / noreply), AD2 (fadm_action, fadm_policy, fadm_need, fadm_audit, closed ledger kinds), AD3/AD4 (the same RLS + doors pattern).
-- LOOPHOLE FOUND AND FIXED HERE: AD1 made billing@ SEND-ONLY (CHECK fadm_mailbox_check), so billing@ could never receive; his rule is that authorized finance staff read billing@. Only noreply@ stays send-only.
-- TECHNOLOGY: PostgreSQL forced ROW LEVEL SECURITY, CHECK constraints that carry his rules, triggers (a private or system address can never become a staff mailbox), SECURITY DEFINER doors with fixed search_path, explicit grants for the restricted mailbox,
--   SHA-256 hash-chained ledger line for every grant. The Rust mail door (phase I) asks fadm_route_inbound and fadm_reply_from; it never decides routing itself.
-- RULES: Desk tables only (fadm_*), no extension, no superuser, idempotent, ONE transaction, SELFTEST rolls back (fail SQLSTATE P0AF1, success exit P0AF2), desk_app has no table right, only the doors. DESK ISOLATION: nothing of founder or awam is touched; the founder address
--   is only a ROW that says private, the Desk holds no founder mailbox.
-- ==============================================================================================================================
BEGIN;

-- 1) LEDGER KIND + ACTION -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('ad5.selftest','info','AD5'),('mailbox.grant','notice','a person was given or lost the restricted mailbox') ON CONFLICT (kind) DO NOTHING;
INSERT INTO desk.fadm_action (action, note) VALUES ('mailbox.grant','give or take away access to a restricted mailbox') ON CONFLICT (action) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES ('p_mailbox_grant','permit','mailbox.grant','admin') ON CONFLICT (name) DO NOTHING;

-- 2) THE LOOPHOLE FIX: only noreply@ is send-only; "priority" can never be a mailbox (Priority Support is a label) -----------------------------------------------------------------------------------------------
ALTER TABLE desk.fadm_mailbox DROP CONSTRAINT IF EXISTS fadm_mailbox_check;
ALTER TABLE desk.fadm_mailbox DROP CONSTRAINT IF EXISTS fadm_mailbox_noreply_ck;
ALTER TABLE desk.fadm_mailbox ADD CONSTRAINT fadm_mailbox_noreply_ck CHECK (local_part <> 'noreply' OR send_only);
ALTER TABLE desk.fadm_mailbox DROP CONSTRAINT IF EXISTS fadm_mailbox_nopriority_ck;
ALTER TABLE desk.fadm_mailbox ADD CONSTRAINT fadm_mailbox_nopriority_ck CHECK (local_part <> 'priority');
UPDATE desk.fadm_mailbox SET send_only = false WHERE local_part = 'billing';

-- 3) THE ADDRESS TABLE: the ten addresses and their role, in one place --------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_address (
  local_part  text PRIMARY KEY CHECK (local_part = lower(local_part) AND local_part ~ '^[a-z0-9._-]{1,60}$' AND local_part NOT IN ('support','priority')),
  domain      text NOT NULL DEFAULT 'anexomail.com',
  purpose     text NOT NULL CHECK (length(purpose) BETWEEN 5 AND 200),
  queue       text NOT NULL CHECK (queue IN ('general','movein','support','billing','system','founder')),
  kind        text NOT NULL CHECK (kind IN ('mailbox','send_only','system','forward')),
  visibility  text NOT NULL CHECK (visibility IN ('staff','restricted','system','private')),
  reply_from  text,
  forward_to  text,
  label       text CHECK (label IS NULL OR label ~ '^[a-z0-9_-]{2,30}$'),
  sla_note    text,
  CHECK (kind <> 'forward' OR (forward_to IS NOT NULL AND label IS NOT NULL AND reply_from IS NULL)),
  CHECK (kind = 'forward' OR forward_to IS NULL),
  CHECK (kind <> 'send_only' OR (reply_from IS NULL AND forward_to IS NULL)),
  CHECK (local_part <> 'noreply' OR kind = 'send_only'),
  CHECK (local_part <> 'billing' OR (visibility = 'restricted' AND kind = 'mailbox')),
  CHECK (local_part <> 'leo' OR (visibility = 'system' AND kind = 'system')),
  CHECK (queue <> 'founder' OR visibility = 'private'),
  CHECK (visibility <> 'private' OR queue = 'founder'),
  CHECK (kind NOT IN ('mailbox') OR reply_from = local_part)
);
INSERT INTO desk.fadm_address (local_part, purpose, queue, kind, visibility, reply_from, forward_to, label, sla_note) VALUES
  ('hello','General questions and first enquiries','general','mailbox','staff','hello',NULL,NULL,NULL),
  ('moveyourbusiness','Managed Move-In: quote, schedule and company handover, one work record per company','movein','mailbox','staff','moveyourbusiness',NULL,NULL,NULL),
  ('resolved','Customer support queue: employees see, assign, answer and resolve; Priority Support is a label and SLA on a thread','support','mailbox','staff','resolved',NULL,NULL,'Priority Support: first reply within 2 business days, as the landing page says'),
  ('billing','Billing and payment questions; only authorized finance staff','billing','mailbox','restricted','billing',NULL,NULL,NULL),
  ('leo','LEO automatic replies and system work; not a staff inbox','system','system','system',NULL,NULL,NULL,NULL),
  ('naumansherwani.founder','The founder private account; staff never log in; a reply as founder is a draft the founder approves','founder','mailbox','private','naumansherwani.founder',NULL,NULL,NULL),
  ('noreply','Automatic system mail only; nothing is received','system','send_only','system',NULL,NULL,NULL,NULL),
  ('postmaster','Mail server technical notices, forwarded to resolved with a label','support','forward','staff',NULL,'resolved','technical',NULL),
  ('abuse','Abuse and security reports, forwarded to resolved with a restricted security label','support','forward','restricted',NULL,'resolved','security',NULL),
  ('dmarc','Domain mail security reports, auto-filtered away from customer support','support','forward','staff',NULL,'resolved','dmarc-filter',NULL)
ON CONFLICT (local_part) DO NOTHING;
-- the founder address is a private row, never a staff mailbox: the Desk mailbox table may never carry a private or system address
CREATE OR REPLACE FUNCTION desk.fadm_mailbox_private_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF EXISTS (SELECT 1 FROM desk.fadm_address a WHERE a.local_part = NEW.local_part AND (a.visibility = 'private' OR a.kind = 'system'))
    THEN RAISE EXCEPTION 'address % is private or system: staff never get a mailbox on it', NEW.local_part USING ERRCODE = 'check_violation'; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_address a WHERE a.local_part = NEW.local_part AND a.kind = 'forward')
    THEN RAISE EXCEPTION 'address % is a forward, not a mailbox', NEW.local_part USING ERRCODE = 'check_violation'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_mailbox_00private ON desk.fadm_mailbox;
CREATE TRIGGER fadm_mailbox_00private BEFORE INSERT OR UPDATE OF local_part ON desk.fadm_mailbox FOR EACH ROW EXECUTE FUNCTION desk.fadm_mailbox_private_guard();
-- the staff mailboxes that exist in the Desk (billing included, restricted below); noreply stays send-only
INSERT INTO desk.fadm_mailbox (local_part, send_only) VALUES ('hello', false), ('moveyourbusiness', false), ('resolved', false), ('billing', false), ('noreply', true) ON CONFLICT DO NOTHING;

-- 4) THE RESTRICTED MAILBOX: only people with an explicit grant (billing@ = authorized finance staff) -------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_mailbox_grant (
  local_part text NOT NULL REFERENCES desk.fadm_address(local_part),
  owner_id   uuid NOT NULL REFERENCES desk.fadm_owner(id),
  granted_by uuid NOT NULL REFERENCES desk.fadm_owner(id),
  granted_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  PRIMARY KEY (local_part, owner_id)
);
-- doors ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- may this person read this address's queue? staff addresses: an agent relation; restricted: an explicit live grant; private and system: never
CREATE OR REPLACE FUNCTION desk.fadm_mailbox_can_read(p_owner uuid, p_local text) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE a record;
BEGIN
  SELECT * INTO a FROM desk.fadm_address WHERE local_part = p_local;
  IF NOT FOUND THEN RETURN false; END IF;
  IF a.visibility IN ('private','system') THEN RETURN false; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_owner AND o.status = 'active') THEN RETURN false; END IF;
  IF a.visibility = 'restricted' THEN RETURN EXISTS (SELECT 1 FROM desk.fadm_mailbox_grant g WHERE g.local_part = p_local AND g.owner_id = p_owner AND g.revoked_at IS NULL) AND desk.fadm_check(p_owner, 'unit', desk.fadm_unit_id('department','desk'), 'agent'); END IF;
  RETURN desk.fadm_check(p_owner, 'unit', desk.fadm_unit_id('department','desk'), 'agent');
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_mailbox_grant_set(p_actor uuid, p_owner uuid, p_local text, p_on boolean, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'mailbox.grant', desk.fadm_unit_id('department','desk'), p_ip);
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_address WHERE local_part = p_local AND visibility = 'restricted') THEN RAISE EXCEPTION 'only a restricted address takes grants' USING ERRCODE = 'check_violation'; END IF;
  IF p_actor = p_owner THEN RAISE EXCEPTION 'a person cannot grant himself' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_owner AND status = 'active') THEN RAISE EXCEPTION 'the person must be active' USING ERRCODE = 'check_violation'; END IF;
  IF p_on THEN INSERT INTO desk.fadm_mailbox_grant (local_part, owner_id, granted_by) VALUES (p_local, p_owner, p_actor) ON CONFLICT (local_part, owner_id) DO UPDATE SET revoked_at = NULL, granted_by = p_actor, granted_at = now();
  ELSE UPDATE desk.fadm_mailbox_grant SET revoked_at = now() WHERE local_part = p_local AND owner_id = p_owner AND revoked_at IS NULL; END IF;
  PERFORM desk.fadm_audit(p_actor, 'mailbox.grant', jsonb_build_object('address', p_local, 'person', p_owner, 'on', p_on));
END $f$;
-- routing of an inbound address: which queue, which label, where it is forwarded
CREATE OR REPLACE FUNCTION desk.fadm_route_inbound(p_local text) RETURNS TABLE (queue text, label text, deliver_to text, restricted boolean) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT t.queue, coalesce(a.label, CASE WHEN a.local_part = 'resolved' THEN NULL END), t.local_part, (a.visibility = 'restricted' OR t.visibility = 'restricted')
    FROM desk.fadm_address a JOIN desk.fadm_address t ON t.local_part = coalesce(a.forward_to, a.local_part)
   WHERE a.local_part = p_local AND a.kind <> 'send_only' AND a.visibility <> 'private'
$f$;
-- the address a staff reply leaves from: the one the customer wrote to (forwards answer from resolved); NULL if no staff reply is allowed
CREATE OR REPLACE FUNCTION desk.fadm_reply_from(p_local text) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT CASE WHEN a.kind = 'forward' THEN a.forward_to WHEN a.kind = 'mailbox' AND a.visibility IN ('staff','restricted') THEN a.reply_from ELSE NULL END
    FROM desk.fadm_address a WHERE a.local_part = p_local
$f$;

-- 5) RLS AND GRANTS ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_address','fadm_mailbox_grant'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
REVOKE ALL ON FUNCTION desk.fadm_mailbox_private_guard(), desk.fadm_mailbox_can_read(uuid,text), desk.fadm_mailbox_grant_set(uuid,uuid,text,boolean,inet), desk.fadm_route_inbound(text), desk.fadm_reply_from(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_mailbox_can_read(uuid,text), desk.fadm_mailbox_grant_set(uuid,uuid,text,boolean,inet), desk.fadm_route_inbound(text), desk.fadm_reply_from(text) TO desk_app;

-- 6) SELFTEST (rolls back; P0AF2 = success) ---------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad5_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD5 selftest: %', msg USING ERRCODE = 'P0AF1'; END IF; END $f$;
DO $$
DECLARE o uuid; a uuid; f uuid; sfx text := substr(md5(random()::text), 1, 8); r record; n int;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('department','desk');
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o1-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a-' || sfx || '@selftest.invalid', 'Selftest Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('f-' || sfx || '@selftest.invalid', 'Selftest Finance', 'agent', NULL, true, 'active', true) RETURNING id INTO f;
  PERFORM desk.fadm_access_grant(o, a, sup, 'agent'); PERFORM desk.fadm_access_grant(o, f, sup, 'agent');
  PERFORM pg_temp.ad5_ok((SELECT count(*) FROM desk.fadm_address) = 10, 'ten addresses are in the table');
  -- the loophole: billing is no longer send-only; noreply still is
  PERFORM pg_temp.ad5_ok((SELECT send_only FROM desk.fadm_mailbox WHERE local_part = 'billing') = false, 'billing can receive');
  BEGIN UPDATE desk.fadm_mailbox SET send_only = false WHERE local_part = 'noreply'; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('support'); RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('priority'); RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_address (local_part, purpose, queue, kind, visibility, reply_from) VALUES ('priority', 'Priority mailbox', 'support', 'mailbox', 'staff', 'priority'); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- the founder and system addresses can never become a staff mailbox
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('naumansherwani.founder'); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('leo'); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('abuse'); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  -- routing: support, move-in, general, billing, forwards with labels, noreply and founder take nothing
  PERFORM pg_temp.ad5_ok((SELECT queue FROM desk.fadm_route_inbound('resolved')) = 'support', 'resolved goes to the support queue');
  PERFORM pg_temp.ad5_ok((SELECT queue FROM desk.fadm_route_inbound('moveyourbusiness')) = 'movein', 'moveyourbusiness goes to the Managed Move-In queue');
  PERFORM pg_temp.ad5_ok((SELECT queue FROM desk.fadm_route_inbound('hello')) = 'general', 'hello is general');
  PERFORM pg_temp.ad5_ok((SELECT restricted FROM desk.fadm_route_inbound('billing')) = true, 'billing is restricted');
  SELECT * INTO r FROM desk.fadm_route_inbound('abuse');
  PERFORM pg_temp.ad5_ok(r.deliver_to = 'resolved' AND r.label = 'security' AND r.restricted, 'abuse lands in resolved with the restricted security label');
  SELECT * INTO r FROM desk.fadm_route_inbound('dmarc');
  PERFORM pg_temp.ad5_ok(r.deliver_to = 'resolved' AND r.label = 'dmarc-filter', 'dmarc lands in resolved with its own filter label');
  SELECT * INTO r FROM desk.fadm_route_inbound('postmaster');
  PERFORM pg_temp.ad5_ok(r.deliver_to = 'resolved' AND r.label = 'technical', 'postmaster lands in resolved with the technical label');
  PERFORM pg_temp.ad5_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_route_inbound('noreply')) AND NOT EXISTS (SELECT 1 FROM desk.fadm_route_inbound('naumansherwani.founder')), 'noreply receives nothing and the founder address is not routed to staff');
  -- the reply address: the one the customer wrote to; forwards answer from resolved; none for noreply, leo, founder
  PERFORM pg_temp.ad5_ok(desk.fadm_reply_from('resolved') = 'resolved' AND desk.fadm_reply_from('moveyourbusiness') = 'moveyourbusiness' AND desk.fadm_reply_from('hello') = 'hello' AND desk.fadm_reply_from('billing') = 'billing', 'a staff reply leaves from the address the customer used');
  PERFORM pg_temp.ad5_ok(desk.fadm_reply_from('abuse') = 'resolved' AND desk.fadm_reply_from('postmaster') = 'resolved' AND desk.fadm_reply_from('dmarc') = 'resolved', 'forwarded addresses are answered from resolved');
  PERFORM pg_temp.ad5_ok(desk.fadm_reply_from('noreply') IS NULL AND desk.fadm_reply_from('leo') IS NULL AND desk.fadm_reply_from('naumansherwani.founder') IS NULL, 'no staff reply from noreply, leo or the founder address');
  -- who may read: agents the staff queues, nobody the restricted one without a grant, nobody the private or system ones
  PERFORM pg_temp.ad5_ok(desk.fadm_mailbox_can_read(a, 'resolved') AND desk.fadm_mailbox_can_read(a, 'moveyourbusiness') AND desk.fadm_mailbox_can_read(a, 'hello'), 'an agent reads the staff queues');
  PERFORM pg_temp.ad5_ok(NOT desk.fadm_mailbox_can_read(a, 'billing') AND NOT desk.fadm_mailbox_can_read(o, 'naumansherwani.founder') AND NOT desk.fadm_mailbox_can_read(o, 'leo'), 'billing needs a grant; the founder and system addresses are never read by staff');
  BEGIN PERFORM desk.fadm_mailbox_grant_set(a, f, 'billing', true); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_mailbox_grant_set(o, o, 'billing', true); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_mailbox_grant_set(o, f, 'resolved', true); RAISE EXCEPTION 'no refusal 10' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_mailbox_grant_set(o, f, 'billing', true);
  PERFORM pg_temp.ad5_ok(desk.fadm_mailbox_can_read(f, 'billing') AND NOT desk.fadm_mailbox_can_read(a, 'billing'), 'only the granted finance person reads billing');
  PERFORM pg_temp.ad5_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'mailbox.grant' AND detail->>'person' = f::text) = 1, 'the grant is in the ledger');
  PERFORM desk.fadm_mailbox_grant_set(o, f, 'billing', false);
  PERFORM pg_temp.ad5_ok(NOT desk.fadm_mailbox_can_read(f, 'billing'), 'a revoked grant stops the access');
  -- the address rules are constraints
  BEGIN INSERT INTO desk.fadm_address (local_part, purpose, queue, kind, visibility) VALUES ('leo2', 'x test addr', 'system', 'forward', 'staff'); RAISE EXCEPTION 'no refusal 11' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_address SET visibility = 'staff' WHERE local_part = 'billing'; RAISE EXCEPTION 'no refusal 12' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_address SET visibility = 'staff' WHERE local_part = 'naumansherwani.founder'; RAISE EXCEPTION 'no refusal 13' USING ERRCODE = 'P0AF1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_audit(o, 'ad5.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad5_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad5_ok(NOT has_table_privilege('desk_app', 'desk.fadm_address', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_mailbox_grant', 'INSERT'), 'desk_app has no direct right on the address tables');
  PERFORM pg_temp.ad5_ok(has_function_privilege('desk_app', 'desk.fadm_route_inbound(text)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_lookup_begin(uuid,text,text,text[],uuid,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_session_lookup(bytea)', 'EXECUTE'), 'the new doors are granted and the older doors kept their grant');
  RAISE EXCEPTION 'AD5 selftest passed, rolling back' USING ERRCODE = 'P0AF2';
EXCEPTION WHEN SQLSTATE 'P0AF2' THEN RAISE NOTICE 'AD5 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
