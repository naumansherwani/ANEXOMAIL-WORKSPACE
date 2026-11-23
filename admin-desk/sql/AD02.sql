
-- ==============================================================================================================================
-- AD2 (ADMIN DESK SQL, step 2, 22 Nov 2026 PKT): ORGANISATION + RELATION AUTHORISATION + POLICY ENGINE + STAFF LIFECYCLE for 50,000 staff.
-- BUILT ON (SCHEMA-FIRST LAW, read in full before writing): AD1 = desk.fadm_owner (id, email, display_name, role owner|agent, pw_hash ARGON2ID, passkey_required, active),
--   desk.fadm_session (owner_id FK, token_hash, dbsc_key, expires/revoked), desk.fadm_passkey (owner_id FK, cred_id, public_key, sign_count, rp_id), desk.fadm_mailbox, desk.fadm_ledger
--   (seq, prev_hash, hash chain, trigger fadm_ledger_chain, three freeze triggers, fadm_ledger_verify()), fadm_me(), fadm_login_lookup(); policies p_installer / p_owner_self / p_session_own ...;
--   AD1b = fadm_session_lookup / fadm_session_create / fadm_session_revoke. NOTHING is renamed or copied: AD2 EXTENDS fadm_owner (staff are owners with role agent) and fadm_passkey, and reuses the ONE ledger.
-- PLAN: docs/claude/admin-desk/SCALE-50K-DESIGN-22NOV.md (S1 org, S2 relations, S3 JIT, S8 team key), WORLD-ADVANCE W2 (policy engine), EMPLOYEE-ACCOUNTS-PLAN ON1 ON4 ON5 ON9 ON10 ON11 ON12.
-- TECHNOLOGY: PostgreSQL 14+ ROW LEVEL SECURITY (ENABLE + FORCE on every table), Zanzibar-style relation tuples with consistency token (zookie), deny-by-default policy engine where FORBID beats PERMIT,
--   zero standing privilege (expiring tuples, two-person approval, loud break-glass), device-bound passkey rules enforced IN THE DATABASE (no synced credential, AAGUID allow-list, two devices), one-transaction leaver,
--   recovery with two distinct approvers and a cooling period, per-minute burst circuit breaker, closed-list append-only SHA-256 hash-chained ledger.
-- RULES: Desk tables only (fadm_*), no extension, NO superuser needed (runs in a hosted SQL editor), idempotent, ONE transaction, SELFTEST rolls its own rows back, desk_app gets SELECT on reference tables and EXECUTE on
--   functions, NEVER direct INSERT/UPDATE/DELETE on any AD2 table. DESK ISOLATION: no founder or awam object is read or written. Run only through ad-sql-run.sh (by number), then checks/AD02-check.sql.
-- HONEST NOTES: (1) the AAGUID allow-list starts EMPTY: deny by default, the owner adds exactly the models he accepts (nothing invented here). (2) alerts go to the Desk's OWN bridge (fadm_alert); the Founder
--   Bridge is another security domain and is never written from the Desk. (3) Argon2id hashing of the enrollment code happens in the Rust door; the database stores and compares only the PHC string shape.
-- ==============================================================================================================================
BEGIN;

-- 1) EXTEND fadm_owner: a staff member is an owner row with role 'agent' (no password, passkeys only). ----------------------------------------------------------------------------------------
ALTER TABLE desk.fadm_owner ADD COLUMN IF NOT EXISTS status     text        NOT NULL DEFAULT 'active';
ALTER TABLE desk.fadm_owner ADD COLUMN IF NOT EXISTS invited_by uuid        REFERENCES desk.fadm_owner(id);
ALTER TABLE desk.fadm_owner ADD COLUMN IF NOT EXISTS left_at    timestamptz;
ALTER TABLE desk.fadm_owner ADD COLUMN IF NOT EXISTS timezone   text        NOT NULL DEFAULT 'Asia/Karachi';
ALTER TABLE desk.fadm_owner ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE desk.fadm_owner ALTER COLUMN pw_hash DROP NOT NULL;
DO $$ DECLARE c record; BEGIN
  FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'desk.fadm_owner'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) ILIKE '%pw_hash%' AND conname <> 'fadm_owner_pw_by_role' LOOP
    EXECUTE format('ALTER TABLE desk.fadm_owner DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;
ALTER TABLE desk.fadm_owner DROP CONSTRAINT IF EXISTS fadm_owner_pw_by_role;
ALTER TABLE desk.fadm_owner ADD CONSTRAINT fadm_owner_pw_by_role CHECK ((role = 'owner' AND pw_hash LIKE '$argon2id$%') OR (role = 'agent' AND pw_hash IS NULL));   -- staff NEVER have a password
ALTER TABLE desk.fadm_owner DROP CONSTRAINT IF EXISTS fadm_owner_status_chk;
ALTER TABLE desk.fadm_owner ADD CONSTRAINT fadm_owner_status_chk CHECK (status IN ('invited','active','suspended','left'));
ALTER TABLE desk.fadm_owner DROP CONSTRAINT IF EXISTS fadm_owner_staff_passkey;
ALTER TABLE desk.fadm_owner ADD CONSTRAINT fadm_owner_staff_passkey CHECK (role = 'owner' OR passkey_required);                              -- staff sign in with passkeys only
CREATE OR REPLACE FUNCTION desk.fadm_owner_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = NEW.timezone) THEN RAISE EXCEPTION 'unknown time zone %', NEW.timezone USING ERRCODE = 'check_violation'; END IF;
  IF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'left' AND NEW.status <> 'left' THEN RAISE EXCEPTION 'a staff member who left cannot come back (create a new record)' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.role <> OLD.role THEN RAISE EXCEPTION 'role is fixed once created' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.id <> OLD.id OR NEW.email <> OLD.email THEN RAISE EXCEPTION 'id and email are fixed' USING ERRCODE = 'check_violation'; END IF;
  END IF;
  NEW.active := (NEW.status = 'active'); NEW.updated_at := now();
  IF NEW.status = 'left' AND NEW.left_at IS NULL THEN NEW.left_at := now(); END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_owner_guard ON desk.fadm_owner;
CREATE TRIGGER fadm_owner_guard BEFORE INSERT OR UPDATE ON desk.fadm_owner FOR EACH ROW EXECUTE FUNCTION desk.fadm_owner_guard();
-- the password door is for the OWNER role only; a staff row can never sign in with a password, whatever its hash column says
CREATE OR REPLACE FUNCTION desk.fadm_login_lookup(p_email text) RETURNS TABLE (id uuid, pw_hash text, passkey_required boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT o.id, o.pw_hash, o.passkey_required FROM desk.fadm_owner o WHERE o.email = lower(p_email) AND o.active AND o.status = 'active' AND o.role = 'owner'
$f$;
-- a session can only be created for an ACTIVE person (belt and braces under fadm_session_create)
CREATE OR REPLACE FUNCTION desk.fadm_session_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = NEW.owner_id AND status = 'active') THEN RAISE EXCEPTION 'no session for a person who is not active' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_session_guard ON desk.fadm_session;
CREATE TRIGGER fadm_session_guard BEFORE INSERT ON desk.fadm_session FOR EACH ROW EXECUTE FUNCTION desk.fadm_session_guard();

-- 2) CLOSED LISTS: ledger kinds, relations (a total order of power), actions. -------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_ledger_kind (kind text PRIMARY KEY CHECK (kind ~ '^[a-z0-9_.]{1,60}$'), severity text NOT NULL DEFAULT 'info' CHECK (severity IN ('info','notice','high')), note text);
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad1.selftest','info','AD1'),('ad2.selftest','info','AD2'),('login.ok','info','AD1b'),('owner.password_set','notice','desk-owner.sh'),
  ('staff.invited','notice','joiner'),('staff.enroll_issued','notice','one-time code issued'),('staff.enroll_used','notice','code consumed'),('staff.activated','notice','two device-bound passkeys registered'),
  ('staff.suspended','high','session frozen'),('staff.left','high','leaver in one transaction'),('staff.moved','notice','mover'),('passkey.registered','notice','device-bound key'),('passkey.refused','high','rule violated'),
  ('access.granted','notice','tuple written'),('access.revoked','notice','tuple revoked'),('elevation.requested','notice','JIT'),('elevation.approved','high','JIT approved by a second person'),('elevation.denied','notice','JIT'),
  ('breakglass.used','high','owner break-glass'),('recovery.opened','high','lost devices'),('recovery.approved','high','one approver'),('recovery.completed','high','cooling over, keys wiped'),('recovery.cancelled','notice','recovery'),
  ('burst.freeze','high','circuit breaker tripped'),('policy.changed','high','policy toggled'),('aaguid.changed','high','allow-list changed'),('org.changed','notice','unit created')
ON CONFLICT (kind) DO NOTHING;
CREATE OR REPLACE FUNCTION desk.fadm_ledger_kind_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger_kind WHERE kind = NEW.kind) THEN RAISE EXCEPTION 'ledger kind % is not on the closed list', NEW.kind USING ERRCODE = 'check_violation'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_ledger_00kind ON desk.fadm_ledger;                       -- name sorts BEFORE fadm_ledger_chain, so a refused kind never reaches the chain
CREATE TRIGGER fadm_ledger_00kind BEFORE INSERT ON desk.fadm_ledger FOR EACH ROW EXECUTE FUNCTION desk.fadm_ledger_kind_guard();
CREATE OR REPLACE FUNCTION desk.fadm_audit(p_actor uuid, p_kind text, p_detail jsonb) RETURNS void LANGUAGE sql VOLATILE SET search_path = pg_catalog, desk AS $f$
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (p_actor, p_kind, coalesce(p_detail, '{}'::jsonb))
$f$;

CREATE TABLE IF NOT EXISTS desk.fadm_relation (relation text PRIMARY KEY CHECK (relation ~ '^[a-z_]{3,20}$'), rank smallint NOT NULL UNIQUE CHECK (rank BETWEEN 1 AND 9), note text);
INSERT INTO desk.fadm_relation (relation, rank, note) VALUES ('viewer',1,'sees'),('member',2,'belongs'),('agent',3,'works cases'),('lead',4,'runs a team'),('supervisor',5,'runs a department'),('admin',6,'owns the policy')
ON CONFLICT (relation) DO NOTHING;
CREATE TABLE IF NOT EXISTS desk.fadm_action (action text PRIMARY KEY CHECK (action ~ '^[a-z_]+(\.[a-z_]+)+$'), note text);
INSERT INTO desk.fadm_action (action, note) VALUES
  ('staff.invite','add a joiner'),('staff.read','list staff'),('staff.suspend','freeze or remove'),('staff.move','change team'),('staff.recover','open or approve a recovery'),
  ('access.grant','write a relation'),('access.elevate.approve','approve a JIT elevation'),('case.read','open a case'),('case.reply','answer a case'),('case.assign','assign a case'),
  ('export.run','export data'),('ui.release','release a UI change'),('audit.read','read the audit trail'),('policy.edit','toggle a policy')
ON CONFLICT (action) DO NOTHING;
CREATE OR REPLACE FUNCTION desk.fadm_rank(p_rel text) RETURNS smallint LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT rank FROM desk.fadm_relation WHERE relation = p_rel $f$;

-- 3) S1 ORGANISATION: department > team > queue. The team key is on every row below (S8: partition-ready, RLS second wall). -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_unit (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        text NOT NULL CHECK (kind IN ('department','team','queue')),
  slug        text NOT NULL CHECK (slug ~ '^[a-z0-9_]{2,40}$'),
  name        text NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  parent_id   uuid REFERENCES desk.fadm_unit(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  archived_at timestamptz,
  UNIQUE (kind, slug),
  CHECK ((kind = 'department') = (parent_id IS NULL))
);
CREATE INDEX IF NOT EXISTS fadm_unit_parent ON desk.fadm_unit (parent_id);
CREATE OR REPLACE FUNCTION desk.fadm_unit_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE pk text;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.kind <> OLD.kind OR NEW.parent_id IS DISTINCT FROM OLD.parent_id OR NEW.id <> OLD.id) THEN RAISE EXCEPTION 'kind, parent and id of a unit are fixed' USING ERRCODE = 'check_violation'; END IF;
  IF NEW.parent_id IS NOT NULL THEN
    SELECT kind INTO pk FROM desk.fadm_unit WHERE id = NEW.parent_id;
    IF (NEW.kind = 'team' AND pk <> 'department') OR (NEW.kind = 'queue' AND pk <> 'team') THEN RAISE EXCEPTION 'a % must sit under a % ', NEW.kind, CASE NEW.kind WHEN 'team' THEN 'department' ELSE 'team' END USING ERRCODE = 'check_violation'; END IF;
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_unit_guard ON desk.fadm_unit;
CREATE TRIGGER fadm_unit_guard BEFORE INSERT OR UPDATE ON desk.fadm_unit FOR EACH ROW EXECUTE FUNCTION desk.fadm_unit_guard();
-- his decided first teams (22 Nov 2026): support, migration, frontend_demo (every UI change needs his approval, see policy ui_release below)
INSERT INTO desk.fadm_unit (kind, slug, name) VALUES ('department', 'desk', 'Admin Desk') ON CONFLICT (kind, slug) DO NOTHING;
INSERT INTO desk.fadm_unit (kind, slug, name, parent_id) SELECT 'team', t.slug, t.name, d.id FROM desk.fadm_unit d, (VALUES ('support','Live Support and Ticket Resolution'),('migration','Move Your Business and Onboarding'),('frontend_demo','UI Editing and Tech Demos')) AS t(slug, name) WHERE d.kind = 'department' AND d.slug = 'desk' ON CONFLICT (kind, slug) DO NOTHING;
INSERT INTO desk.fadm_unit (kind, slug, name, parent_id) SELECT 'queue', t.slug || '_main', t.name || ' queue', t.id FROM desk.fadm_unit t WHERE t.kind = 'team' ON CONFLICT (kind, slug) DO NOTHING;

-- 4) S2 RELATION TUPLES (Zanzibar style): object#relation@subject, soft-deleted only, every write gets a consistency token (zookie). ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS desk.fadm_rel_zk;
CREATE TABLE IF NOT EXISTS desk.fadm_rel (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  object_type      text   NOT NULL CHECK (object_type IN ('unit','mailbox','case')),
  object_id        uuid   NOT NULL,
  relation         text   NOT NULL REFERENCES desk.fadm_relation(relation),
  subject_type     text   NOT NULL CHECK (subject_type IN ('owner','unit')),
  subject_id       uuid   NOT NULL,
  subject_relation text   CHECK (subject_relation = 'member'),
  source           text   NOT NULL DEFAULT 'direct' CHECK (source IN ('direct','elevation','breakglass')),
  created_by       uuid   REFERENCES desk.fadm_owner(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  expires_at       timestamptz,
  revoked_at       timestamptz,
  zk               bigint NOT NULL DEFAULT nextval('desk.fadm_rel_zk'),
  CHECK ((subject_type = 'unit') = (subject_relation IS NOT NULL)),
  CHECK (expires_at IS NULL OR expires_at > created_at),
  CHECK (source = 'direct' OR expires_at IS NOT NULL)                      -- an elevation or break-glass tuple ALWAYS expires: zero standing privilege
);
CREATE UNIQUE INDEX IF NOT EXISTS fadm_rel_live ON desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, coalesce(subject_relation, '')) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS fadm_rel_subject ON desk.fadm_rel (subject_type, subject_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS fadm_rel_object ON desk.fadm_rel (object_type, object_id) WHERE revoked_at IS NULL;
CREATE OR REPLACE FUNCTION desk.fadm_rel_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'relation tuples are never deleted, they are revoked' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF TG_OP = 'INSERT' THEN
    IF NEW.object_type = 'unit' AND NOT EXISTS (SELECT 1 FROM desk.fadm_unit WHERE id = NEW.object_id AND archived_at IS NULL) THEN RAISE EXCEPTION 'no such live unit' USING ERRCODE = 'foreign_key_violation'; END IF;
    IF NEW.object_type = 'mailbox' AND NOT EXISTS (SELECT 1 FROM desk.fadm_mailbox WHERE id = NEW.object_id) THEN RAISE EXCEPTION 'no such mailbox' USING ERRCODE = 'foreign_key_violation'; END IF;
    IF NEW.subject_type = 'owner' AND NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = NEW.subject_id) THEN RAISE EXCEPTION 'no such person' USING ERRCODE = 'foreign_key_violation'; END IF;
    IF NEW.subject_type = 'unit' AND NOT EXISTS (SELECT 1 FROM desk.fadm_unit WHERE id = NEW.subject_id) THEN RAISE EXCEPTION 'no such unit' USING ERRCODE = 'foreign_key_violation'; END IF;
    NEW.zk := nextval('desk.fadm_rel_zk'); RETURN NEW;
  END IF;
  IF (NEW.object_type, NEW.object_id, NEW.relation, NEW.subject_type, NEW.subject_id, NEW.subject_relation, NEW.source, NEW.created_at, NEW.created_by, NEW.expires_at)
     IS DISTINCT FROM (OLD.object_type, OLD.object_id, OLD.relation, OLD.subject_type, OLD.subject_id, OLD.subject_relation, OLD.source, OLD.created_at, OLD.created_by, OLD.expires_at) THEN
    RAISE EXCEPTION 'a tuple can only be revoked, never edited' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF OLD.revoked_at IS NOT NULL THEN RAISE EXCEPTION 'already revoked' USING ERRCODE = 'insufficient_privilege'; END IF;
  NEW.zk := nextval('desk.fadm_rel_zk'); RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_rel_guard ON desk.fadm_rel;
CREATE TRIGGER fadm_rel_guard BEFORE INSERT OR UPDATE OR DELETE ON desk.fadm_rel FOR EACH ROW EXECUTE FUNCTION desk.fadm_rel_guard();
CREATE OR REPLACE FUNCTION desk.fadm_zookie() RETURNS bigint LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT coalesce((SELECT last_value FROM desk.fadm_rel_zk), 0) $f$;
-- a new owner-role person is admin of the root department (explicit tuple, Zanzibar-pure: no hidden superuser in code)
CREATE OR REPLACE FUNCTION desk.fadm_owner_bootstrap() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NEW.role = 'owner' THEN
    INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by)
    SELECT 'unit', d.id, 'admin', 'owner', NEW.id, NEW.id FROM desk.fadm_unit d WHERE d.kind = 'department' AND d.slug = 'desk' ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_owner_bootstrap ON desk.fadm_owner;
CREATE TRIGGER fadm_owner_bootstrap AFTER INSERT ON desk.fadm_owner FOR EACH ROW EXECUTE FUNCTION desk.fadm_owner_bootstrap();
INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by)
  SELECT 'unit', d.id, 'admin', 'owner', o.id, o.id FROM desk.fadm_owner o, desk.fadm_unit d WHERE o.role = 'owner' AND d.kind = 'department' AND d.slug = 'desk' ON CONFLICT DO NOTHING;

-- 5) THE CHECK: does person P hold at least relation R on object O at time T? (Zanzibar check, recursive over unit ancestors + one level of group usersets) ---------------------------------------------
-- A relation held on a department holds on every team and queue under it. Expired and revoked tuples never count. A person who is not ACTIVE holds nothing. Unknown relation = false. Deny by default.
CREATE OR REPLACE FUNCTION desk.fadm_check(p_owner uuid, p_otype text, p_oid uuid, p_rel text, p_at timestamptz DEFAULT now()) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  WITH RECURSIVE anc(id, depth) AS (
    SELECT p_oid, 0 WHERE p_otype = 'unit'
    UNION ALL
    SELECT u.parent_id, a.depth + 1 FROM anc a JOIN desk.fadm_unit u ON u.id = a.id WHERE u.parent_id IS NOT NULL AND a.depth < 4
  ),
  live AS (
    SELECT r.* FROM desk.fadm_rel r WHERE r.revoked_at IS NULL AND (r.expires_at IS NULL OR r.expires_at > p_at) AND r.created_at <= p_at
  ),
  grp AS (                                         -- units this person is a member of (member or stronger, held directly)
    SELECT l.object_id AS unit_id FROM live l WHERE l.object_type = 'unit' AND l.subject_type = 'owner' AND l.subject_id = p_owner AND desk.fadm_rank(l.relation) >= 2
  ),
  hit AS (
    SELECT l.relation FROM live l
     WHERE l.object_type = p_otype AND (l.object_id = p_oid OR (p_otype = 'unit' AND l.object_id IN (SELECT id FROM anc)))
       AND ((l.subject_type = 'owner' AND l.subject_id = p_owner)
         OR (l.subject_type = 'unit' AND l.subject_relation = 'member' AND l.subject_id IN (SELECT unit_id FROM grp)))
  )
  SELECT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_owner AND o.status = 'active')
     AND coalesce((SELECT bool_or(desk.fadm_rank(h.relation) >= desk.fadm_rank(p_rel)) FROM hit h), false)
$f$;
-- strongest relation rank a person holds on a unit (0 = none); used to stop anyone granting power above their own
CREATE OR REPLACE FUNCTION desk.fadm_rank_on(p_owner uuid, p_unit uuid) RETURNS smallint LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT coalesce(max(r.rank), 0)::smallint FROM desk.fadm_relation r WHERE desk.fadm_check(p_owner, 'unit', p_unit, r.relation)
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_unit_id(p_kind text, p_slug text) RETURNS uuid LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT id FROM desk.fadm_unit WHERE kind = p_kind AND slug = p_slug AND archived_at IS NULL $f$;
CREATE OR REPLACE FUNCTION desk.fadm_team_of(p_owner uuid) RETURNS uuid LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$
  SELECT r.object_id FROM desk.fadm_rel r JOIN desk.fadm_unit u ON u.id = r.object_id AND u.kind = 'team'
   WHERE r.object_type = 'unit' AND r.subject_type = 'owner' AND r.subject_id = p_owner AND r.revoked_at IS NULL ORDER BY r.created_at LIMIT 1
$f$;

-- 6) POLICY ENGINE (W2): deny by default; a FORBID that matches beats every PERMIT. Conditions are a closed list, evaluated in the database. ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_shift (owner_id uuid NOT NULL REFERENCES desk.fadm_owner(id), dow smallint NOT NULL CHECK (dow BETWEEN 0 AND 6), start_min smallint NOT NULL CHECK (start_min BETWEEN 0 AND 1439),
  end_min smallint NOT NULL CHECK (end_min BETWEEN 1 AND 1440), PRIMARY KEY (owner_id, dow, start_min), CHECK (end_min > start_min));
CREATE TABLE IF NOT EXISTS desk.fadm_ip_allow (cidr cidr PRIMARY KEY, label text NOT NULL CHECK (length(label) BETWEEN 1 AND 80), enabled boolean NOT NULL DEFAULT true, created_at timestamptz NOT NULL DEFAULT now());
-- no row at all = the lock is not switched on yet (nothing is invented); once one office address is listed, every other address is refused for staff actions
CREATE OR REPLACE FUNCTION desk.fadm_ip_ok(p_ip inet) RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$
  SELECT NOT EXISTS (SELECT 1 FROM desk.fadm_ip_allow WHERE enabled) OR (p_ip IS NOT NULL AND EXISTS (SELECT 1 FROM desk.fadm_ip_allow a WHERE a.enabled AND a.cidr >>= p_ip))
$f$;
-- no shift rows for a person = no shift lock for that person; with rows, only inside a listed window in HIS OWN time zone
CREATE OR REPLACE FUNCTION desk.fadm_in_shift(p_owner uuid, p_at timestamptz DEFAULT now()) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = pg_catalog, desk AS $f$
DECLARE tz text; loc timestamp; m int;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_shift WHERE owner_id = p_owner) THEN RETURN true; END IF;
  SELECT timezone INTO tz FROM desk.fadm_owner WHERE id = p_owner;
  loc := p_at AT TIME ZONE coalesce(tz, 'UTC'); m := extract(hour FROM loc)::int * 60 + extract(minute FROM loc)::int;
  RETURN EXISTS (SELECT 1 FROM desk.fadm_shift s WHERE s.owner_id = p_owner AND s.dow = extract(dow FROM loc)::int AND m >= s.start_min AND m < s.end_min);
END $f$;
CREATE TABLE IF NOT EXISTS desk.fadm_policy (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name      text NOT NULL UNIQUE CHECK (name ~ '^[a-z0-9_]{3,60}$'),
  effect    text NOT NULL CHECK (effect IN ('permit','forbid')),
  action    text NOT NULL REFERENCES desk.fadm_action(action),
  relation  text REFERENCES desk.fadm_relation(relation),
  cond      text NOT NULL DEFAULT 'none' CHECK (cond IN ('none','outside_shift','ip_not_allowed','not_owner_role')),
  enabled   boolean NOT NULL DEFAULT true,
  note      text,
  CHECK ((effect = 'permit' AND relation IS NOT NULL AND cond = 'none') OR (effect = 'forbid' AND relation IS NULL AND cond <> 'none'))
);
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES
  ('p_staff_invite','permit','staff.invite','lead'),('p_staff_read','permit','staff.read','lead'),('p_staff_suspend','permit','staff.suspend','supervisor'),('p_staff_move','permit','staff.move','supervisor'),
  ('p_staff_recover','permit','staff.recover','supervisor'),('p_access_grant','permit','access.grant','supervisor'),('p_elevate_approve','permit','access.elevate.approve','supervisor'),
  ('p_case_read','permit','case.read','agent'),('p_case_reply','permit','case.reply','agent'),('p_case_assign','permit','case.assign','lead'),('p_export_run','permit','export.run','supervisor'),
  ('p_ui_release','permit','ui.release','admin'),('p_audit_read','permit','audit.read','supervisor'),('p_policy_edit','permit','policy.edit','admin')
ON CONFLICT (name) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, cond, note)
  SELECT 'f_' || replace(a, '.', '_') || '_' || c, 'forbid', a, c, 'zero-trust lock' FROM unnest(ARRAY['case.read','case.reply','export.run']) a, unnest(ARRAY['outside_shift','ip_not_allowed']) c
ON CONFLICT (name) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, cond, note) VALUES
  ('f_ui_release_not_owner','forbid','ui.release','not_owner_role','every UI change needs the owner (his word 22 Nov)'),('f_policy_edit_not_owner','forbid','policy.edit','not_owner_role','only the owner edits the policy')
ON CONFLICT (name) DO NOTHING;
CREATE OR REPLACE FUNCTION desk.fadm_cond(p_cond text, p_owner uuid, p_ip inet, p_at timestamptz) RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$
  SELECT CASE p_cond WHEN 'none' THEN true WHEN 'outside_shift' THEN NOT desk.fadm_in_shift(p_owner, p_at) WHEN 'ip_not_allowed' THEN NOT desk.fadm_ip_ok(p_ip)
    WHEN 'not_owner_role' THEN coalesce((SELECT o.role <> 'owner' FROM desk.fadm_owner o WHERE o.id = p_owner), true) ELSE true END
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_authorize(p_owner uuid, p_action text, p_unit uuid, p_ip inet DEFAULT NULL, p_at timestamptz DEFAULT now())
RETURNS TABLE (allowed boolean, reason text, zk bigint) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE pol record; z bigint := desk.fadm_zookie();
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_owner AND o.status = 'active') THEN RETURN QUERY SELECT false, 'not_active'::text, z; RETURN; END IF;
  FOR pol IN SELECT * FROM desk.fadm_policy WHERE enabled AND effect = 'forbid' AND action = p_action ORDER BY name LOOP
    IF desk.fadm_cond(pol.cond, p_owner, p_ip, p_at) THEN RETURN QUERY SELECT false, ('forbid:' || pol.name)::text, z; RETURN; END IF;
  END LOOP;
  FOR pol IN SELECT * FROM desk.fadm_policy WHERE enabled AND effect = 'permit' AND action = p_action ORDER BY name LOOP
    IF desk.fadm_check(p_owner, 'unit', p_unit, pol.relation, p_at) THEN RETURN QUERY SELECT true, ('permit:' || pol.name)::text, z; RETURN; END IF;
  END LOOP;
  RETURN QUERY SELECT false, 'default_deny'::text, z;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_need(p_owner uuid, p_action text, p_unit uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record;
BEGIN
  SELECT * INTO r FROM desk.fadm_authorize(p_owner, p_action, p_unit, p_ip);
  IF NOT r.allowed THEN RAISE EXCEPTION 'not allowed: % (%)', p_action, r.reason USING ERRCODE = 'insufficient_privilege'; END IF;
END $f$;

-- 7) DEVICE-BOUND PASSKEYS, enforced IN THE DATABASE (ON2, ON9): a staff credential must not be synced, must come from an allow-listed hardware model, and each person holds two (primary + backup). -----------------
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS aaguid          uuid;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS attestation_fmt text;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS backup_eligible boolean;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS backup_state    boolean;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS transports      text[];
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS label           text;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS slot            text;
ALTER TABLE desk.fadm_passkey ADD COLUMN IF NOT EXISTS revoked_at      timestamptz;
ALTER TABLE desk.fadm_passkey DROP CONSTRAINT IF EXISTS fadm_passkey_slot_chk;
ALTER TABLE desk.fadm_passkey ADD CONSTRAINT fadm_passkey_slot_chk CHECK (slot IS NULL OR slot IN ('primary','backup'));
ALTER TABLE desk.fadm_passkey DROP CONSTRAINT IF EXISTS fadm_passkey_label_chk;
ALTER TABLE desk.fadm_passkey ADD CONSTRAINT fadm_passkey_label_chk CHECK (label IS NULL OR length(label) BETWEEN 1 AND 60);
CREATE UNIQUE INDEX IF NOT EXISTS fadm_passkey_slot_live ON desk.fadm_passkey (owner_id, slot) WHERE revoked_at IS NULL AND slot IS NOT NULL;
CREATE TABLE IF NOT EXISTS desk.fadm_aaguid_allow (aaguid uuid PRIMARY KEY, label text NOT NULL CHECK (length(label) BETWEEN 1 AND 80), enabled boolean NOT NULL DEFAULT true, added_by uuid REFERENCES desk.fadm_owner(id), created_at timestamptz NOT NULL DEFAULT now());
-- STARTS EMPTY on purpose: no model is accepted until the owner lists it (security keys first; laptop passkeys often give no attestation, so they are NOT assumed trustworthy).
CREATE OR REPLACE FUNCTION desk.fadm_passkey_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE r text;
BEGIN
  SELECT role INTO r FROM desk.fadm_owner WHERE id = NEW.owner_id;
  IF TG_OP = 'UPDATE' AND (NEW.cred_id <> OLD.cred_id OR NEW.public_key <> OLD.public_key OR NEW.owner_id <> OLD.owner_id) THEN RAISE EXCEPTION 'a credential is never edited, only revoked' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF TG_OP = 'UPDATE' AND OLD.revoked_at IS NOT NULL AND NEW.revoked_at IS NULL THEN RAISE EXCEPTION 'a revoked credential stays revoked' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF r = 'agent' AND NEW.revoked_at IS NULL THEN
    IF NEW.slot IS NULL THEN RAISE EXCEPTION 'staff credentials need a slot (primary or backup)' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.backup_eligible IS DISTINCT FROM false OR NEW.backup_state IS DISTINCT FROM false THEN RAISE EXCEPTION 'synced or syncable passkeys are refused: device-bound only' USING ERRCODE = 'check_violation'; END IF;
    IF NEW.aaguid IS NULL OR NOT EXISTS (SELECT 1 FROM desk.fadm_aaguid_allow a WHERE a.aaguid = NEW.aaguid AND a.enabled) THEN RAISE EXCEPTION 'this authenticator model is not on the allow-list' USING ERRCODE = 'check_violation'; END IF;
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_passkey_guard ON desk.fadm_passkey;
CREATE TRIGGER fadm_passkey_guard BEFORE INSERT OR UPDATE ON desk.fadm_passkey FOR EACH ROW EXECUTE FUNCTION desk.fadm_passkey_guard();

-- 8) ONBOARDING (ON1, ON2): a joiner starts with NO access; the lead hands over a one-time code (Argon2id hash only, 15 minutes, 5 tries); two device-bound passkeys activate the account. -------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_enroll_token (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES desk.fadm_owner(id), code_hash text NOT NULL CHECK (code_hash LIKE '$argon2id$%'),
  created_by uuid NOT NULL REFERENCES desk.fadm_owner(id), created_at timestamptz NOT NULL DEFAULT now(), expires_at timestamptz NOT NULL,
  attempts smallint NOT NULL DEFAULT 0 CHECK (attempts BETWEEN 0 AND 5), used_at timestamptz, revoked_at timestamptz,
  CHECK (expires_at > created_at AND expires_at <= created_at + interval '15 minutes')
);
CREATE UNIQUE INDEX IF NOT EXISTS fadm_enroll_live ON desk.fadm_enroll_token (owner_id) WHERE used_at IS NULL AND revoked_at IS NULL;
CREATE OR REPLACE FUNCTION desk.fadm_staff_invite(p_actor uuid, p_email text, p_name text, p_team text, p_ip inet DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE t uuid := desk.fadm_unit_id('team', p_team); n uuid;
BEGIN
  IF t IS NULL THEN RAISE EXCEPTION 'no such team %', p_team USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.invite', t, p_ip);
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, invited_by) VALUES (lower(p_email), p_name, 'agent', NULL, true, 'invited', p_actor) RETURNING id INTO n;
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by) VALUES ('unit', t, 'member', 'owner', n, p_actor);   -- belongs, but holds NO permission (zero-privilege default)
  PERFORM desk.fadm_audit(p_actor, 'staff.invited', jsonb_build_object('staff', n, 'team', p_team));
  RETURN n;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_enroll_issue(p_actor uuid, p_staff uuid, p_code_hash text, p_ip inet DEFAULT NULL) RETURNS timestamptz LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE t uuid := desk.fadm_team_of(p_staff); e timestamptz := now() + interval '15 minutes';
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND role = 'agent' AND status = 'invited') THEN RAISE EXCEPTION 'only a joiner in status invited can enrol' USING ERRCODE = 'check_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.invite', t, p_ip);
  UPDATE desk.fadm_enroll_token SET revoked_at = now() WHERE owner_id = p_staff AND used_at IS NULL AND revoked_at IS NULL;
  INSERT INTO desk.fadm_enroll_token (owner_id, code_hash, created_by, expires_at) VALUES (p_staff, p_code_hash, p_actor, e);
  PERFORM desk.fadm_audit(p_actor, 'staff.enroll_issued', jsonb_build_object('staff', p_staff));
  RETURN e;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_enroll_lookup(p_email text) RETURNS TABLE (owner_id uuid, code_hash text, attempts smallint) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT o.id, k.code_hash, k.attempts FROM desk.fadm_owner o JOIN desk.fadm_enroll_token k ON k.owner_id = o.id
   WHERE o.email = lower(p_email) AND o.status = 'invited' AND k.used_at IS NULL AND k.revoked_at IS NULL AND k.expires_at > now() AND k.attempts < 5
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_enroll_fail(p_owner uuid) RETURNS smallint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE a smallint;
BEGIN
  UPDATE desk.fadm_enroll_token SET attempts = attempts + 1, revoked_at = CASE WHEN attempts + 1 >= 5 THEN now() END WHERE owner_id = p_owner AND used_at IS NULL AND revoked_at IS NULL RETURNING attempts INTO a;
  IF a >= 5 THEN PERFORM desk.fadm_audit(p_owner, 'passkey.refused', jsonb_build_object('why', 'enrol code locked after 5 wrong tries')); END IF;
  RETURN coalesce(a, 0);
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_enroll_consume(p_owner uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n int;
BEGIN
  UPDATE desk.fadm_enroll_token SET used_at = now() WHERE owner_id = p_owner AND used_at IS NULL AND revoked_at IS NULL AND expires_at > now();
  GET DIAGNOSTICS n = ROW_COUNT;
  IF n = 1 THEN PERFORM desk.fadm_audit(p_owner, 'staff.enroll_used', '{}'::jsonb); END IF;
  RETURN n = 1;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_try_activate(p_owner uuid) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF (SELECT count(*) FROM desk.fadm_passkey WHERE owner_id = p_owner AND revoked_at IS NULL AND slot IN ('primary','backup')) < 2 THEN RETURN false; END IF;
  UPDATE desk.fadm_owner SET status = 'active' WHERE id = p_owner AND role = 'agent' AND status = 'invited';
  IF FOUND THEN PERFORM desk.fadm_audit(p_owner, 'staff.activated', '{}'::jsonb); RETURN true; END IF;
  RETURN false;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_register_passkey(p_owner uuid, p_cred bytea, p_pub bytea, p_rp text, p_aaguid uuid, p_fmt text, p_be boolean, p_bs boolean, p_transports text[], p_label text, p_slot text)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_owner AND role = 'agent' AND status IN ('invited','active')) THEN RAISE EXCEPTION 'no such staff member' USING ERRCODE = 'check_violation'; END IF;
  INSERT INTO desk.fadm_passkey (owner_id, cred_id, public_key, rp_id, aaguid, attestation_fmt, backup_eligible, backup_state, transports, label, slot) VALUES (p_owner, p_cred, p_pub, p_rp, p_aaguid, p_fmt, p_be, p_bs, p_transports, p_label, p_slot);
  PERFORM desk.fadm_audit(p_owner, 'passkey.registered', jsonb_build_object('slot', p_slot, 'aaguid', p_aaguid));
  RETURN desk.fadm_staff_try_activate(p_owner);
END $f$;

-- 9) MOVER / LEAVER / ACCESS (ON4): one transaction each; nothing is half done. -----------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_staff_end_access(p_staff uuid) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  UPDATE desk.fadm_session   SET revoked_at = now() WHERE owner_id = p_staff AND revoked_at IS NULL;
  UPDATE desk.fadm_enroll_token SET revoked_at = now() WHERE owner_id = p_staff AND used_at IS NULL AND revoked_at IS NULL;
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_suspend(p_actor uuid, p_staff uuid, p_on boolean, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'staff.suspend', desk.fadm_team_of(p_staff), p_ip);
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND role = 'agent' AND status IN ('active','suspended')) THEN RAISE EXCEPTION 'only an active or suspended staff member can be (un)suspended' USING ERRCODE = 'check_violation'; END IF;
  UPDATE desk.fadm_owner SET status = CASE WHEN p_on THEN 'suspended' ELSE 'active' END WHERE id = p_staff;
  IF p_on THEN PERFORM desk.fadm_staff_end_access(p_staff); END IF;
  PERFORM desk.fadm_audit(p_actor, 'staff.suspended', jsonb_build_object('staff', p_staff, 'on', p_on));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_leave(p_actor uuid, p_staff uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE t uuid := desk.fadm_team_of(p_staff);
BEGIN
  PERFORM desk.fadm_need(p_actor, 'staff.suspend', t, p_ip);
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND role = 'agent' AND status <> 'left') THEN RAISE EXCEPTION 'no such staff member (or already left)' USING ERRCODE = 'check_violation'; END IF;
  UPDATE desk.fadm_owner   SET status = 'left' WHERE id = p_staff;
  UPDATE desk.fadm_rel     SET revoked_at = now() WHERE subject_type = 'owner' AND subject_id = p_staff AND revoked_at IS NULL;
  UPDATE desk.fadm_passkey SET revoked_at = now() WHERE owner_id = p_staff AND revoked_at IS NULL;
  UPDATE desk.fadm_recovery SET status = 'cancelled' WHERE owner_id = p_staff AND status = 'open';
  PERFORM desk.fadm_staff_end_access(p_staff);
  PERFORM desk.fadm_audit(p_actor, 'staff.left', jsonb_build_object('staff', p_staff, 'team', t));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_move(p_actor uuid, p_staff uuid, p_new_team text, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE o uuid := desk.fadm_team_of(p_staff); n uuid := desk.fadm_unit_id('team', p_new_team);
BEGIN
  IF n IS NULL THEN RAISE EXCEPTION 'no such team %', p_new_team USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.move', o, p_ip);
  PERFORM desk.fadm_need(p_actor, 'staff.move', n, p_ip);
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND role = 'agent' AND status IN ('invited','active','suspended')) THEN RAISE EXCEPTION 'no such staff member' USING ERRCODE = 'check_violation'; END IF;
  -- the old team's powers end now; nothing is carried over (mover rule): he arrives as a plain member of the new team
  UPDATE desk.fadm_rel r SET revoked_at = now() FROM desk.fadm_unit u WHERE r.subject_type = 'owner' AND r.subject_id = p_staff AND r.revoked_at IS NULL AND r.object_type = 'unit' AND u.id = r.object_id AND (u.kind <> 'department');
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by) VALUES ('unit', n, 'member', 'owner', p_staff, p_actor);
  PERFORM desk.fadm_audit(p_actor, 'staff.moved', jsonb_build_object('staff', p_staff, 'to', p_new_team));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_access_grant(p_actor uuid, p_staff uuid, p_unit uuid, p_rel text, p_expires timestamptz DEFAULT NULL, p_ip inet DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE mine smallint := desk.fadm_rank_on(p_actor, p_unit); nid uuid;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'access.grant', p_unit, p_ip);
  IF desk.fadm_rank(p_rel) IS NULL THEN RAISE EXCEPTION 'unknown relation %', p_rel USING ERRCODE = 'check_violation'; END IF;
  IF desk.fadm_rank(p_rel) >= mine AND mine < 6 THEN RAISE EXCEPTION 'you cannot grant a relation equal to or above your own' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND status IN ('invited','active')) THEN RAISE EXCEPTION 'grantee is not a live person' USING ERRCODE = 'check_violation'; END IF;
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by, expires_at) VALUES ('unit', p_unit, p_rel, 'owner', p_staff, p_actor, p_expires) RETURNING fadm_rel.id INTO nid;
  PERFORM desk.fadm_audit(p_actor, 'access.granted', jsonb_build_object('tuple', nid, 'staff', p_staff, 'unit', p_unit, 'relation', p_rel));
  RETURN nid;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_access_revoke(p_actor uuid, p_tuple uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE t desk.fadm_rel;
BEGIN
  SELECT * INTO t FROM desk.fadm_rel WHERE id = p_tuple AND revoked_at IS NULL AND object_type = 'unit';
  IF NOT FOUND THEN RAISE EXCEPTION 'no such live tuple' USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'access.grant', t.object_id, p_ip);
  IF desk.fadm_rank(t.relation) >= desk.fadm_rank_on(p_actor, t.object_id) AND desk.fadm_rank_on(p_actor, t.object_id) < 6 THEN RAISE EXCEPTION 'you cannot revoke a relation equal to or above your own' USING ERRCODE = 'insufficient_privilege'; END IF;
  UPDATE desk.fadm_rel SET revoked_at = now() WHERE id = p_tuple;
  PERFORM desk.fadm_audit(p_actor, 'access.revoked', jsonb_build_object('tuple', p_tuple));
END $f$;

-- 10) RECOVERY (ON5): lost devices = two DISTINCT supervisors approve, neither is the person, then a 24 hour cooling period; completion wipes keys and sessions and returns the person to 'invited'. ---------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_recovery (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES desk.fadm_owner(id), opened_by uuid NOT NULL REFERENCES desk.fadm_owner(id),
  opened_at timestamptz NOT NULL DEFAULT now(), cool_until timestamptz NOT NULL, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','completed','cancelled')), completed_at timestamptz,
  CHECK (cool_until >= opened_at + interval '24 hours'), CHECK ((status = 'completed') = (completed_at IS NOT NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS fadm_recovery_one_open ON desk.fadm_recovery (owner_id) WHERE status = 'open';
CREATE TABLE IF NOT EXISTS desk.fadm_recovery_approval (recovery_id uuid NOT NULL REFERENCES desk.fadm_recovery(id), approver uuid NOT NULL REFERENCES desk.fadm_owner(id), at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (recovery_id, approver));
CREATE OR REPLACE FUNCTION desk.fadm_recovery_approval_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE r desk.fadm_recovery;
BEGIN
  SELECT * INTO r FROM desk.fadm_recovery WHERE id = NEW.recovery_id;
  IF r.status <> 'open' THEN RAISE EXCEPTION 'recovery is not open' USING ERRCODE = 'check_violation'; END IF;
  IF NEW.approver = r.owner_id THEN RAISE EXCEPTION 'nobody approves his own recovery' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_recovery_approval_guard ON desk.fadm_recovery_approval;
CREATE TRIGGER fadm_recovery_approval_guard BEFORE INSERT ON desk.fadm_recovery_approval FOR EACH ROW EXECUTE FUNCTION desk.fadm_recovery_approval_guard();
CREATE OR REPLACE FUNCTION desk.fadm_recovery_open(p_actor uuid, p_staff uuid, p_ip inet DEFAULT NULL) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE nid uuid;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'staff.recover', desk.fadm_team_of(p_staff), p_ip);
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_staff AND role = 'agent' AND status IN ('invited','active','suspended')) THEN RAISE EXCEPTION 'no such staff member' USING ERRCODE = 'check_violation'; END IF;
  INSERT INTO desk.fadm_recovery (owner_id, opened_by, cool_until) VALUES (p_staff, p_actor, now() + interval '24 hours') RETURNING fadm_recovery.id INTO nid;
  PERFORM desk.fadm_staff_end_access(p_staff);                                   -- from this moment the old devices cannot hold a session
  PERFORM desk.fadm_audit(p_actor, 'recovery.opened', jsonb_build_object('recovery', nid, 'staff', p_staff));
  RETURN nid;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_recovery_approve(p_actor uuid, p_recovery uuid, p_ip inet DEFAULT NULL) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r desk.fadm_recovery;
BEGIN
  SELECT * INTO r FROM desk.fadm_recovery WHERE id = p_recovery AND status = 'open';
  IF NOT FOUND THEN RAISE EXCEPTION 'no open recovery' USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.recover', desk.fadm_team_of(r.owner_id), p_ip);
  INSERT INTO desk.fadm_recovery_approval (recovery_id, approver) VALUES (p_recovery, p_actor);
  PERFORM desk.fadm_audit(p_actor, 'recovery.approved', jsonb_build_object('recovery', p_recovery));
  RETURN (SELECT count(*)::int FROM desk.fadm_recovery_approval WHERE recovery_id = p_recovery);
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_recovery_complete(p_actor uuid, p_recovery uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r desk.fadm_recovery;
BEGIN
  SELECT * INTO r FROM desk.fadm_recovery WHERE id = p_recovery AND status = 'open' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no open recovery' USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.recover', desk.fadm_team_of(r.owner_id), p_ip);
  IF (SELECT count(*) FROM desk.fadm_recovery_approval WHERE recovery_id = p_recovery) < 2 THEN RAISE EXCEPTION 'two distinct approvers are needed' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF now() < r.cool_until THEN RAISE EXCEPTION 'cooling period is not over (until %)', r.cool_until USING ERRCODE = 'insufficient_privilege'; END IF;
  UPDATE desk.fadm_passkey SET revoked_at = now() WHERE owner_id = r.owner_id AND revoked_at IS NULL;
  PERFORM desk.fadm_staff_end_access(r.owner_id);
  UPDATE desk.fadm_owner SET status = 'invited' WHERE id = r.owner_id AND status IN ('active','suspended');
  UPDATE desk.fadm_recovery SET status = 'completed', completed_at = now() WHERE id = p_recovery;
  PERFORM desk.fadm_audit(p_actor, 'recovery.completed', jsonb_build_object('recovery', p_recovery, 'staff', r.owner_id));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_recovery_cancel(p_actor uuid, p_recovery uuid, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r desk.fadm_recovery;
BEGIN
  SELECT * INTO r FROM desk.fadm_recovery WHERE id = p_recovery AND status = 'open';
  IF NOT FOUND THEN RAISE EXCEPTION 'no open recovery' USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, 'staff.recover', desk.fadm_team_of(r.owner_id), p_ip);
  UPDATE desk.fadm_recovery SET status = 'cancelled' WHERE id = p_recovery;
  PERFORM desk.fadm_audit(p_actor, 'recovery.cancelled', jsonb_build_object('recovery', p_recovery));
END $f$;

-- 11) ZERO STANDING PRIVILEGE (S3): just-in-time elevation needs a reason, a short life (max 60 min) and a SECOND person; break-glass is owner-only and shouts in the ledger. ------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_elevation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), requester uuid NOT NULL REFERENCES desk.fadm_owner(id), unit_id uuid NOT NULL REFERENCES desk.fadm_unit(id), relation text NOT NULL REFERENCES desk.fadm_relation(relation),
  reason text NOT NULL CHECK (length(btrim(reason)) >= 10), minutes smallint NOT NULL CHECK (minutes BETWEEN 5 AND 60), requested_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','denied')), approver uuid REFERENCES desk.fadm_owner(id), decided_at timestamptz, rel_id uuid REFERENCES desk.fadm_rel(id),
  CHECK (approver IS NULL OR approver <> requester), CHECK ((status = 'pending') = (approver IS NULL))
);
CREATE OR REPLACE FUNCTION desk.fadm_elevation_request(p_actor uuid, p_unit uuid, p_rel text, p_reason text, p_minutes int) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE nid uuid;
BEGIN
  IF coalesce(desk.fadm_rank(p_rel), 9) > 5 THEN RAISE EXCEPTION 'this relation cannot be requested' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NOT desk.fadm_check(p_actor, 'unit', p_unit, 'member') THEN RAISE EXCEPTION 'you are not a member of this unit' USING ERRCODE = 'insufficient_privilege'; END IF;
  INSERT INTO desk.fadm_elevation (requester, unit_id, relation, reason, minutes) VALUES (p_actor, p_unit, p_rel, p_reason, p_minutes) RETURNING fadm_elevation.id INTO nid;
  PERFORM desk.fadm_audit(p_actor, 'elevation.requested', jsonb_build_object('elevation', nid, 'unit', p_unit, 'relation', p_rel, 'minutes', p_minutes));
  RETURN nid;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_elevation_decide(p_actor uuid, p_elev uuid, p_approve boolean, p_ip inet DEFAULT NULL) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE e desk.fadm_elevation; rid uuid;
BEGIN
  SELECT * INTO e FROM desk.fadm_elevation WHERE id = p_elev AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no pending request' USING ERRCODE = 'foreign_key_violation'; END IF;
  IF e.requester = p_actor THEN RAISE EXCEPTION 'two-person rule: you cannot approve your own request' USING ERRCODE = 'insufficient_privilege'; END IF;
  PERFORM desk.fadm_need(p_actor, 'access.elevate.approve', e.unit_id, p_ip);
  IF p_approve AND desk.fadm_rank(e.relation) >= desk.fadm_rank_on(p_actor, e.unit_id) AND desk.fadm_rank_on(p_actor, e.unit_id) < 6 THEN RAISE EXCEPTION 'you cannot approve a relation equal to or above your own' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF p_approve THEN
    INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, source, created_by, expires_at) VALUES ('unit', e.unit_id, e.relation, 'owner', e.requester, 'elevation', p_actor, now() + make_interval(mins => e.minutes)) RETURNING fadm_rel.id INTO rid;
  END IF;
  UPDATE desk.fadm_elevation SET status = CASE WHEN p_approve THEN 'approved' ELSE 'denied' END, approver = p_actor, decided_at = now(), rel_id = rid WHERE id = p_elev;
  PERFORM desk.fadm_audit(p_actor, CASE WHEN p_approve THEN 'elevation.approved' ELSE 'elevation.denied' END, jsonb_build_object('elevation', p_elev, 'requester', e.requester));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_breakglass(p_actor uuid, p_unit uuid, p_reason text, p_minutes int) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE rid uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_actor AND role = 'owner' AND status = 'active') THEN RAISE EXCEPTION 'break-glass is for the owner only' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 10 OR p_minutes NOT BETWEEN 5 AND 60 THEN RAISE EXCEPTION 'a reason (10+ characters) and 5 to 60 minutes are required' USING ERRCODE = 'check_violation'; END IF;
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, source, created_by, expires_at) VALUES ('unit', p_unit, 'admin', 'owner', p_actor, 'breakglass', p_actor, now() + make_interval(mins => p_minutes)) RETURNING fadm_rel.id INTO rid;
  PERFORM desk.fadm_audit(p_actor, 'breakglass.used', jsonb_build_object('unit', p_unit, 'minutes', p_minutes, 'reason', p_reason));
  RETURN rid;
END $f$;

-- 12) ANTI-SCRAPING CIRCUIT BREAKER (ON11): per person, per action, per minute. Over the limit = sessions frozen, status suspended, alert on the Desk's OWN bridge (never the Founder Bridge). ---------------------
CREATE TABLE IF NOT EXISTS desk.fadm_burst_limit (action text PRIMARY KEY, max_per_min integer NOT NULL CHECK (max_per_min BETWEEN 1 AND 100000));
INSERT INTO desk.fadm_burst_limit (action, max_per_min) VALUES ('case.read', 50), ('export.run', 3) ON CONFLICT (action) DO NOTHING;
CREATE TABLE IF NOT EXISTS desk.fadm_burst (owner_id uuid NOT NULL REFERENCES desk.fadm_owner(id), action text NOT NULL, minute timestamptz NOT NULL, n integer NOT NULL DEFAULT 0, PRIMARY KEY (owner_id, action, minute));
CREATE TABLE IF NOT EXISTS desk.fadm_alert (id bigserial PRIMARY KEY, at timestamptz NOT NULL DEFAULT now(), severity text NOT NULL CHECK (severity IN ('notice','high')), kind text NOT NULL CHECK (length(kind) BETWEEN 1 AND 60),
  owner_id uuid REFERENCES desk.fadm_owner(id), detail jsonb NOT NULL DEFAULT '{}'::jsonb, acked_by uuid REFERENCES desk.fadm_owner(id), acked_at timestamptz);
CREATE OR REPLACE FUNCTION desk.fadm_alert_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'alerts are never deleted' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (NEW.id, NEW.at, NEW.severity, NEW.kind, NEW.owner_id, NEW.detail) IS DISTINCT FROM (OLD.id, OLD.at, OLD.severity, OLD.kind, OLD.owner_id, OLD.detail) OR OLD.acked_at IS NOT NULL THEN RAISE EXCEPTION 'an alert can only be acknowledged, once' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_alert_guard ON desk.fadm_alert;
CREATE TRIGGER fadm_alert_guard BEFORE UPDATE OR DELETE ON desk.fadm_alert FOR EACH ROW EXECUTE FUNCTION desk.fadm_alert_guard();
-- returns true while under the limit; on the call that crosses it, freezes the person and returns false (an action with no limit row is never counted)
CREATE OR REPLACE FUNCTION desk.fadm_burst_hit(p_owner uuid, p_action text) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE lim integer; c integer;
BEGIN
  SELECT max_per_min INTO lim FROM desk.fadm_burst_limit WHERE action = p_action;
  IF lim IS NULL THEN RETURN true; END IF;
  INSERT INTO desk.fadm_burst (owner_id, action, minute, n) VALUES (p_owner, p_action, date_trunc('minute', now()), 1)
    ON CONFLICT (owner_id, action, minute) DO UPDATE SET n = desk.fadm_burst.n + 1 RETURNING n INTO c;
  DELETE FROM desk.fadm_burst WHERE owner_id = p_owner AND minute < now() - interval '1 hour';
  IF c <= lim THEN RETURN true; END IF;
  IF c = lim + 1 THEN
    UPDATE desk.fadm_owner SET status = 'suspended' WHERE id = p_owner AND role = 'agent' AND status = 'active';
    PERFORM desk.fadm_staff_end_access(p_owner);
    INSERT INTO desk.fadm_alert (severity, kind, owner_id, detail) VALUES ('high', 'burst.freeze', p_owner, jsonb_build_object('action', p_action, 'limit', lim, 'seen', c));
    PERFORM desk.fadm_audit(p_owner, 'burst.freeze', jsonb_build_object('action', p_action, 'limit', lim));
  END IF;
  RETURN false;
END $f$;

-- 13) POLICY AND ALLOW-LIST CHANGES ARE AUDITED, ONLY THE OWNER ROLE MAKES THEM (policy.edit). --------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_policy_set(p_actor uuid, p_name text, p_enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'policy.edit', desk.fadm_unit_id('department', 'desk'));
  UPDATE desk.fadm_policy SET enabled = p_enabled WHERE name = p_name;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such policy' USING ERRCODE = 'foreign_key_violation'; END IF;
  PERFORM desk.fadm_audit(p_actor, 'policy.changed', jsonb_build_object('policy', p_name, 'enabled', p_enabled));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_aaguid_set(p_actor uuid, p_aaguid uuid, p_label text, p_enabled boolean) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'policy.edit', desk.fadm_unit_id('department', 'desk'));
  INSERT INTO desk.fadm_aaguid_allow (aaguid, label, enabled, added_by) VALUES (p_aaguid, p_label, p_enabled, p_actor) ON CONFLICT (aaguid) DO UPDATE SET enabled = EXCLUDED.enabled, label = EXCLUDED.label;
  PERFORM desk.fadm_audit(p_actor, 'aaguid.changed', jsonb_build_object('aaguid', p_aaguid, 'enabled', p_enabled));
END $f$;

-- 14) ROW LEVEL SECURITY ON EVERY NEW TABLE (ENABLE + FORCE), one p_installer policy each; desk_app reads reference tables only and NEVER writes an AD2 table directly. ---------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_ledger_kind','fadm_relation','fadm_action','fadm_unit','fadm_rel','fadm_shift','fadm_ip_allow','fadm_policy','fadm_aaguid_allow','fadm_enroll_token','fadm_recovery','fadm_recovery_approval','fadm_elevation','fadm_burst_limit','fadm_burst','fadm_alert'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['fadm_ledger_kind','fadm_relation','fadm_action','fadm_unit','fadm_policy'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS p_ref_read ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_ref_read ON desk.%I FOR SELECT TO desk_app USING (desk.fadm_me() IS NOT NULL)', t);
    EXECUTE format('GRANT SELECT ON desk.%I TO desk_app', t);
  END LOOP;
END $$;
-- triggers that read other Desk tables run with the definer's rights, so a desk_app write (ledger, session, passkey) never needs a table grant it must not have
ALTER FUNCTION desk.fadm_ledger_kind_guard() SECURITY DEFINER;  ALTER FUNCTION desk.fadm_session_guard() SECURITY DEFINER;  ALTER FUNCTION desk.fadm_passkey_guard() SECURITY DEFINER;
ALTER FUNCTION desk.fadm_owner_guard() SECURITY DEFINER;        ALTER FUNCTION desk.fadm_rel_guard() SECURITY DEFINER;      ALTER FUNCTION desk.fadm_unit_guard() SECURITY DEFINER;
ALTER FUNCTION desk.fadm_recovery_approval_guard() SECURITY DEFINER;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA desk FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_check(uuid,text,uuid,text,timestamptz), desk.fadm_authorize(uuid,text,uuid,inet,timestamptz), desk.fadm_zookie(),
  desk.fadm_staff_invite(uuid,text,text,text,inet), desk.fadm_enroll_issue(uuid,uuid,text,inet), desk.fadm_enroll_lookup(text), desk.fadm_enroll_fail(uuid), desk.fadm_enroll_consume(uuid),
  desk.fadm_staff_register_passkey(uuid,bytea,bytea,text,uuid,text,boolean,boolean,text[],text,text), desk.fadm_staff_suspend(uuid,uuid,boolean,inet), desk.fadm_staff_leave(uuid,uuid,inet),
  desk.fadm_staff_move(uuid,uuid,text,inet), desk.fadm_access_grant(uuid,uuid,uuid,text,timestamptz,inet), desk.fadm_access_revoke(uuid,uuid,inet),
  desk.fadm_recovery_open(uuid,uuid,inet), desk.fadm_recovery_approve(uuid,uuid,inet), desk.fadm_recovery_complete(uuid,uuid,inet), desk.fadm_recovery_cancel(uuid,uuid,inet),
  desk.fadm_elevation_request(uuid,uuid,text,text,int), desk.fadm_elevation_decide(uuid,uuid,boolean,inet), desk.fadm_breakglass(uuid,uuid,text,int), desk.fadm_burst_hit(uuid,text),
  desk.fadm_policy_set(uuid,text,boolean), desk.fadm_aaguid_set(uuid,uuid,text,boolean) TO desk_app;

-- 15) SELFTEST: runs every rule against real rows and ROLLS ITSELF BACK (custom SQLSTATE P0AD2). Any gap FAILS the whole file (BEGIN ... COMMIT is one transaction, nothing half-installed). ------------------------------
CREATE FUNCTION pg_temp.ad2_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD2 selftest: %', msg USING ERRCODE = 'P0AD3'; END IF; END $f$;
DO $$
DECLARE o uuid; o2 uuid; l uuid; s uuid; s2 uuid; sup uuid := desk.fadm_unit_id('department','desk'); tsup uuid := desk.fadm_unit_id('team','support'); tmig uuid := desk.fadm_unit_id('team','migration');
  qsup uuid := desk.fadm_unit_id('queue','support_main'); ag uuid := gen_random_uuid(); ag2 uuid := gen_random_uuid(); r record; e uuid; rid uuid; m int; m0 int; tz text;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sfx text := substr(md5(random()::text), 1, 8);
BEGIN
  -- people and the zero-privilege default
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o1-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o2-' || sfx || '@selftest.invalid', 'Selftest Owner Two', 'owner', h) RETURNING id INTO o2;
  PERFORM pg_temp.ad2_ok(desk.fadm_check(o, 'unit', qsup, 'admin'), 'the owner is admin of the department and so of every queue under it');
  s := desk.fadm_staff_invite(o, 's-' || sfx || '@selftest.invalid', 'Selftest Staff', 'support');
  l := desk.fadm_staff_invite(o, 'l-' || sfx || '@selftest.invalid', 'Selftest Lead', 'support');
  PERFORM pg_temp.ad2_ok((SELECT status FROM desk.fadm_owner WHERE id = s) = 'invited' AND NOT (SELECT active FROM desk.fadm_owner WHERE id = s), 'a joiner is invited and not active');
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup)), 'an invited joiner can do nothing');
  BEGIN INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (s, sha256('x'::bytea), now() + interval '1 hour'); RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required) VALUES ('bad1-' || sfx || '@selftest.invalid', 'x', 'agent', h, true); RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN check_violation THEN NULL; END;                                                          -- staff never have a password
  BEGIN INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required) VALUES ('bad2-' || sfx || '@selftest.invalid', 'x', 'agent', NULL, false); RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN check_violation THEN NULL; END;                                                          -- staff always passkey_required
  BEGIN INSERT INTO desk.fadm_unit (kind, slug, name, parent_id) VALUES ('queue', 'bad_q_' || sfx, 'x', sup); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN check_violation THEN NULL; END;                                                          -- a queue sits under a team only
  -- enrolment code: 15 minutes, 5 tries, Argon2id shape
  BEGIN PERFORM desk.fadm_enroll_issue(s, s, h); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- a joiner cannot enrol himself
  PERFORM pg_temp.ad2_ok(desk.fadm_enroll_issue(o, s, h) <= now() + interval '15 minutes 1 second', 'code lives at most 15 minutes');
  PERFORM pg_temp.ad2_ok((SELECT count(*) FROM desk.fadm_enroll_lookup('s-' || sfx || '@selftest.invalid')) = 1, 'a live code is found by email');
  FOR m IN 1..5 LOOP PERFORM desk.fadm_enroll_fail(s); END LOOP;
  PERFORM pg_temp.ad2_ok((SELECT count(*) FROM desk.fadm_enroll_lookup('s-' || sfx || '@selftest.invalid')) = 0, 'the code is dead after 5 wrong tries');
  PERFORM desk.fadm_enroll_issue(o, s, h);
  PERFORM pg_temp.ad2_ok(desk.fadm_enroll_consume(s) AND NOT desk.fadm_enroll_consume(s), 'a code works once');
  -- device-bound passkeys only, allow-listed models, two per person
  BEGIN PERFORM desk.fadm_staff_register_passkey(s, convert_to('c1-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'key one', 'primary'); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN check_violation THEN NULL; END;                                                          -- model not on the allow-list (the list starts empty)
  PERFORM desk.fadm_aaguid_set(o, ag, 'selftest model', true);
  BEGIN PERFORM desk.fadm_aaguid_set(s, ag2, 'x', true); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- staff cannot edit the list
  BEGIN PERFORM desk.fadm_staff_register_passkey(s, convert_to('c2-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', true, true, ARRAY['internal'], 'synced', 'primary'); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN check_violation THEN NULL; END;                                                          -- synced passkey refused
  PERFORM pg_temp.ad2_ok(NOT desk.fadm_staff_register_passkey(s, convert_to('c3-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'key one', 'primary'), 'one key does not activate');
  BEGIN PERFORM desk.fadm_staff_register_passkey(s, convert_to('c4-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'dup', 'primary'); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AD3';
  EXCEPTION WHEN unique_violation THEN NULL; END;                                                         -- one live primary only
  PERFORM pg_temp.ad2_ok(desk.fadm_staff_register_passkey(s, convert_to('c5-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'key two', 'backup'), 'second key returns activated');
  PERFORM pg_temp.ad2_ok((SELECT status FROM desk.fadm_owner WHERE id = s) = 'active', 'two device-bound keys activate the account');
  PERFORM desk.fadm_staff_register_passkey(l, convert_to('l1-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'lead one', 'primary');
  PERFORM desk.fadm_staff_register_passkey(l, convert_to('l2-' || sfx, 'UTF8'), '\x01'::bytea, 'admindesk.anexomail.com', ag, 'packed', false, false, ARRAY['usb'], 'lead two', 'backup');
  -- zero privilege until granted; rank limits; inheritance down the tree
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup)) AND (SELECT reason FROM desk.fadm_authorize(s, 'case.read', qsup)) = 'default_deny', 'an active member with no grant is denied by default');
  PERFORM desk.fadm_access_grant(o, l, tsup, 'lead');
  BEGIN PERFORM desk.fadm_access_grant(l, s, tsup, 'agent'); RAISE EXCEPTION 'no refusal 10' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- a lead is not a grant-giver
  rid := desk.fadm_access_grant(o, s, tsup, 'agent');
  PERFORM pg_temp.ad2_ok((SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup)), 'an agent on the team may read cases of its queue (inheritance)');
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', desk.fadm_unit_id('queue','migration_main'))), 'no access to another team');
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'staff.invite', tsup)), 'an agent cannot invite');
  PERFORM pg_temp.ad2_ok((SELECT allowed FROM desk.fadm_authorize(l, 'staff.invite', tsup)), 'a lead can invite into his team');
  -- shift gate and office IP lock (forbid beats permit)
  SELECT timezone INTO tz FROM desk.fadm_owner WHERE id = s;
  m := extract(hour FROM now() AT TIME ZONE tz)::int * 60 + extract(minute FROM now() AT TIME ZONE tz)::int; m0 := (m + 720) % 1440;
  INSERT INTO desk.fadm_shift (owner_id, dow, start_min, end_min) VALUES (s, extract(dow FROM now() AT TIME ZONE tz)::int, m0, least(m0 + 1, 1440));
  SELECT * INTO r FROM desk.fadm_authorize(s, 'case.read', qsup);
  PERFORM pg_temp.ad2_ok(NOT r.allowed AND r.reason = 'forbid:f_case_read_outside_shift', 'outside the shift window is forbidden');
  DELETE FROM desk.fadm_shift WHERE owner_id = s;
  PERFORM pg_temp.ad2_ok((SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup)), 'no shift rows = no shift lock');
  INSERT INTO desk.fadm_ip_allow (cidr, label) VALUES ('10.9.9.0/24', 'selftest office');
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup, '10.1.1.1')) AND NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup, NULL)), 'an address outside the office list is refused');
  PERFORM pg_temp.ad2_ok((SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup, '10.9.9.5')), 'the office address is accepted');
  DELETE FROM desk.fadm_ip_allow WHERE label = 'selftest office';
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(l, 'ui.release', tsup)) AND (SELECT reason FROM desk.fadm_authorize(o, 'ui.release', tsup)) = 'permit:p_ui_release', 'only the owner releases a UI change');
  BEGIN PERFORM desk.fadm_policy_set(l, 'p_case_read', false); RAISE EXCEPTION 'no refusal 11' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM desk.fadm_policy_set(o, 'p_case_read', false);
  PERFORM pg_temp.ad2_ok(NOT (SELECT allowed FROM desk.fadm_authorize(s, 'case.read', qsup)), 'a switched-off permit denies');
  PERFORM desk.fadm_policy_set(o, 'p_case_read', true);
  -- just-in-time elevation (two-person) and tuple immutability
  e := desk.fadm_elevation_request(s, tsup, 'lead', 'need to assign a stuck case', 15);
  BEGIN PERFORM desk.fadm_elevation_decide(s, e, true); RAISE EXCEPTION 'no refusal 12' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- not his own
  BEGIN PERFORM desk.fadm_elevation_decide(l, e, true); RAISE EXCEPTION 'no refusal 13' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- a lead cannot approve
  BEGIN PERFORM desk.fadm_elevation_request(s, tsup, 'agent', 'short', 15); RAISE EXCEPTION 'no refusal 14' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- reason too short
  PERFORM desk.fadm_elevation_decide(o, e, true);
  PERFORM pg_temp.ad2_ok(desk.fadm_check(s, 'unit', tsup, 'lead') AND NOT desk.fadm_check(s, 'unit', tsup, 'lead', now() + interval '16 minutes'), 'an elevation holds now and is gone after its minutes');
  BEGIN DELETE FROM desk.fadm_rel WHERE id = rid; RAISE EXCEPTION 'no refusal 15' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.fadm_rel SET relation = 'admin' WHERE id = rid; RAISE EXCEPTION 'no refusal 16' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_breakglass(l, tsup, 'not allowed for a lead', 10); RAISE EXCEPTION 'no refusal 17' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM desk.fadm_breakglass(o, tsup, 'selftest break-glass proof', 10);
  PERFORM pg_temp.ad2_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'breakglass.used') >= 1, 'break-glass is in the ledger');
  -- circuit breaker
  FOR m IN 1..3 LOOP PERFORM pg_temp.ad2_ok(desk.fadm_burst_hit(s, 'export.run'), 'under the limit'); END LOOP;
  PERFORM pg_temp.ad2_ok(NOT desk.fadm_burst_hit(s, 'export.run'), 'the 4th export in a minute is refused');
  PERFORM pg_temp.ad2_ok((SELECT status FROM desk.fadm_owner WHERE id = s) = 'suspended' AND (SELECT count(*) FROM desk.fadm_alert WHERE owner_id = s AND kind = 'burst.freeze') = 1, 'the person is frozen and an alert is raised');
  PERFORM desk.fadm_staff_suspend(o, s, false);
  -- mover: old powers end, he arrives as a plain member
  PERFORM desk.fadm_staff_move(o, s, 'migration');
  PERFORM pg_temp.ad2_ok(desk.fadm_check(s, 'unit', tmig, 'member') AND NOT desk.fadm_check(s, 'unit', tsup, 'agent') AND NOT desk.fadm_check(s, 'unit', tmig, 'agent'), 'mover: old team powers gone, nothing carried');
  -- recovery: two distinct approvers, cooling, completion wipes keys
  e := desk.fadm_recovery_open(o, s);
  PERFORM pg_temp.ad2_ok(desk.fadm_recovery_approve(o, e) = 1, 'first approval');
  BEGIN PERFORM desk.fadm_recovery_approve(o, e); RAISE EXCEPTION 'no refusal 18' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN unique_violation THEN NULL; END;   -- same approver twice
  PERFORM pg_temp.ad2_ok(desk.fadm_recovery_approve(o2, e) = 2, 'second distinct approval');
  BEGIN PERFORM desk.fadm_recovery_complete(o, e); RAISE EXCEPTION 'no refusal 19' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- cooling not over
  PERFORM desk.fadm_recovery_cancel(o, e);
  e := gen_random_uuid();
  INSERT INTO desk.fadm_recovery (id, owner_id, opened_by, opened_at, cool_until) VALUES (e, s, o, now() - interval '25 hours', now() - interval '1 hour');
  INSERT INTO desk.fadm_recovery_approval (recovery_id, approver) VALUES (e, o), (e, o2);
  PERFORM desk.fadm_recovery_complete(o, e);
  PERFORM pg_temp.ad2_ok((SELECT status FROM desk.fadm_owner WHERE id = s) = 'invited' AND NOT EXISTS (SELECT 1 FROM desk.fadm_passkey WHERE owner_id = s AND revoked_at IS NULL), 'after recovery his keys are wiped and he must enrol again');
  BEGIN INSERT INTO desk.fadm_recovery_approval (recovery_id, approver) VALUES (e, l); RAISE EXCEPTION 'no refusal 20' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- recovery no longer open
  -- leaver: one transaction
  s2 := desk.fadm_staff_invite(o, 's2-' || sfx || '@selftest.invalid', 'Selftest Leaver', 'support');
  PERFORM desk.fadm_staff_leave(o, s2);
  PERFORM pg_temp.ad2_ok((SELECT status FROM desk.fadm_owner WHERE id = s2) = 'left' AND NOT EXISTS (SELECT 1 FROM desk.fadm_rel WHERE subject_id = s2 AND revoked_at IS NULL), 'leaver: status left and every tuple revoked');
  BEGIN UPDATE desk.fadm_owner SET status = 'active' WHERE id = s2; RAISE EXCEPTION 'no refusal 21' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- no way back
  -- closed ledger kinds and the chain
  BEGIN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'made.up.kind', '{}'); RAISE EXCEPTION 'no refusal 22' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_audit(o, 'ad2.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad2_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad2_ok(desk.fadm_zookie() > 0, 'zookie moves');
  PERFORM pg_temp.ad2_ok(NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app' AND (rolsuper OR rolbypassrls)), 'desk_app is no superuser and does not bypass RLS');
  PERFORM pg_temp.ad2_ok(NOT has_table_privilege('desk_app', 'desk.fadm_rel', 'INSERT') AND NOT has_table_privilege('desk_app', 'desk.fadm_policy', 'UPDATE') AND NOT has_table_privilege('desk_app', 'desk.fadm_alert', 'DELETE'), 'desk_app has no direct write on AD2 tables');
  RAISE EXCEPTION 'AD2 selftest passed, rolling back' USING ERRCODE = 'P0AD2';
EXCEPTION WHEN SQLSTATE 'P0AD2' THEN RAISE NOTICE 'AD2 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
