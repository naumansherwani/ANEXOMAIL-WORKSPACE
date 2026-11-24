-- ANEXOMAIL CONTROL PLANE CP5 (phase 1m, card B13 step Z4a, list BL-46: the CUSTOMER side of consent with a timer), 24 Nov 2026 PKT.
-- SCHEMA-FIRST: read before writing: AD20 (desk.fadm_consent: status requested -> approved|denied|cancelled, approved -> revoked|expired, window 60/30/15 minutes, fadm_consent_decide(consent, decision, consent_ref, approver_ref)), CP1 + CP4 (schema cp, role cp_lookup, SECURITY DEFINER with search_path = pg_catalog, pg_temp), the live awam schema docs/cursor-work/live-snapshot/sql/schema-public.sql (public.orgs, public.org_members(org_id, user_id, role org_role owner|admin|member, status)). Nothing is renamed or copied.
-- ADVANCE-RESEARCH: [1m] Z4a web research is in docs/claude/admin-desk/D6-B13-CONSENT-ACCESS-LIST-24NOV.md and D6-B13-Z4-CUSTOMER-APPROVAL-PLAN-24NOV.md (Google Access Approval: staff request, the customer admin approves, denies or revokes, history kept; PostgreSQL tstzrange windows, forced RLS, append-only hash chain).
-- CHECK-FILE: control-plane/sql/checks/CP5-check.sql
-- WHAT IT ADDS (nothing else): cp.consent_inbox (one row per Desk request, per company), cp.consent_ledger (append-only SHA-256 hash chain, line written BEFORE each change), and six SECURITY DEFINER doors.
--   SECURITY SPLIT: the Control Plane service role cp_lookup may ONLY push, cancel and poll. It can NEVER decide or revoke. The customer side (role cp_consent_customer, used later by the customer screen Z4c) may inbox, decide and revoke. A decision needs an ACTIVE owner or admin of THAT company and a passkey-assertion digest (verified by the customer screen's Rust in Z4c; the database requires it present and shaped, and keeps it). No auto-approval, no break-glass, no staff path to decide.
--   No content, name, address, e-mail or money is stored: only case ref, scope, reason, times, ids.
BEGIN;
CREATE SCHEMA IF NOT EXISTS cp;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cp_lookup') THEN CREATE ROLE cp_lookup NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cp_consent_customer') THEN CREATE ROLE cp_consent_customer NOLOGIN; END IF;
END $$;

CREATE OR REPLACE FUNCTION cp.consent_minutes(p_scope text) RETURNS integer LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = pg_catalog, pg_temp AS $f$
  SELECT CASE p_scope WHEN 'metadata' THEN 60 WHEN 'headers' THEN 30 WHEN 'content' THEN 15 END
$f$;

-- ledger first (the inbox lines refer to it)
CREATE TABLE IF NOT EXISTS cp.consent_ledger (
  id bigserial PRIMARY KEY,
  at timestamptz NOT NULL DEFAULT now(),
  kind text NOT NULL CHECK (kind IN ('pushed','cancelled','approved','denied','revoked','expired','refused','selftest')),
  consent_id uuid,
  org_id uuid,
  actor text NOT NULL DEFAULT '' CHECK (length(actor) <= 80),
  note text NOT NULL DEFAULT '' CHECK (length(note) <= 300),
  prev bytea NOT NULL,
  hash bytea NOT NULL
);
CREATE OR REPLACE FUNCTION cp.consent_line_hash(p_prev bytea, p_kind text, p_consent uuid, p_org uuid, p_actor text, p_note text, p_at timestamptz) RETURNS bytea LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = pg_catalog, pg_temp AS $f$
  SELECT sha256(p_prev || convert_to(concat_ws('|', p_kind, coalesce(p_consent::text, ''), coalesce(p_org::text, ''), p_actor, p_note, to_char(p_at AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US')), 'UTF8'))
$f$;
CREATE OR REPLACE FUNCTION cp.consent_ledger_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $f$
DECLARE v_prev bytea;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'cp.consent_ledger is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('cp.consent_ledger'));
  SELECT l.hash INTO v_prev FROM cp.consent_ledger l ORDER BY l.id DESC LIMIT 1;
  NEW.prev := coalesce(v_prev, decode(repeat('00', 32), 'hex'));
  NEW.hash := cp.consent_line_hash(NEW.prev, NEW.kind, NEW.consent_id, NEW.org_id, NEW.actor, NEW.note, NEW.at);
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS consent_ledger_chain ON cp.consent_ledger;
CREATE TRIGGER consent_ledger_chain BEFORE INSERT ON cp.consent_ledger FOR EACH ROW EXECUTE FUNCTION cp.consent_ledger_guard();
DROP TRIGGER IF EXISTS consent_ledger_frozen ON cp.consent_ledger;
CREATE TRIGGER consent_ledger_frozen BEFORE UPDATE OR DELETE ON cp.consent_ledger FOR EACH ROW EXECUTE FUNCTION cp.consent_ledger_guard();
DROP TRIGGER IF EXISTS consent_ledger_nottruncate ON cp.consent_ledger;
CREATE TRIGGER consent_ledger_nottruncate BEFORE TRUNCATE ON cp.consent_ledger FOR EACH STATEMENT EXECUTE FUNCTION cp.consent_ledger_guard();

CREATE TABLE IF NOT EXISTS cp.consent_inbox (
  consent_id uuid PRIMARY KEY,
  org_id uuid NOT NULL,
  case_ref text NOT NULL CHECK (case_ref ~ '^[A-Za-z0-9_-]{4,40}$'),
  scope text NOT NULL CHECK (scope IN ('metadata', 'headers', 'content')),
  reason text NOT NULL CHECK (length(reason) BETWEEN 20 AND 300),
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'approved', 'denied', 'cancelled', 'revoked', 'expired')),
  requested_at timestamptz NOT NULL DEFAULT now(),
  decided_at timestamptz,
  decided_by uuid,
  passkey_digest text CHECK (passkey_digest IS NULL OR passkey_digest ~ '^[0-9a-f]{32,128}$'),
  access_window tstzrange,
  decision_hash text,
  CHECK ((status IN ('approved', 'revoked', 'expired')) = (access_window IS NOT NULL) OR status IN ('denied', 'cancelled', 'requested')),
  CHECK (access_window IS NULL OR (NOT lower_inf(access_window) AND NOT upper_inf(access_window) AND upper(access_window) - lower(access_window) <= make_interval(mins => cp.consent_minutes(scope)))),
  CHECK (status NOT IN ('approved', 'denied', 'revoked') OR (decided_by IS NOT NULL AND passkey_digest IS NOT NULL AND decided_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS consent_inbox_org ON cp.consent_inbox (org_id, status);
CREATE OR REPLACE FUNCTION cp.consent_inbox_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $f$
BEGIN
  IF TG_OP IN ('DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'cp.consent_inbox is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (NEW.consent_id, NEW.org_id, NEW.case_ref, NEW.scope, NEW.reason, NEW.requested_at) IS DISTINCT FROM (OLD.consent_id, OLD.org_id, OLD.case_ref, OLD.scope, OLD.reason, OLD.requested_at) THEN RAISE EXCEPTION 'request facts are frozen' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.status IS DISTINCT FROM OLD.status AND NOT ((OLD.status = 'requested' AND NEW.status IN ('approved', 'denied', 'cancelled')) OR (OLD.status = 'approved' AND NEW.status IN ('revoked', 'expired'))) THEN
    RAISE EXCEPTION 'status % -> % is not allowed', OLD.status, NEW.status USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.status IN ('denied', 'cancelled', 'revoked', 'expired') AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'a closed request cannot change' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS consent_inbox_guard ON cp.consent_inbox;
CREATE TRIGGER consent_inbox_guard BEFORE UPDATE OR DELETE ON cp.consent_inbox FOR EACH ROW EXECUTE FUNCTION cp.consent_inbox_guard();
DROP TRIGGER IF EXISTS consent_inbox_nottruncate ON cp.consent_inbox;
CREATE TRIGGER consent_inbox_nottruncate BEFORE TRUNCATE ON cp.consent_inbox FOR EACH STATEMENT EXECUTE FUNCTION cp.consent_inbox_guard();

ALTER TABLE cp.consent_ledger ENABLE ROW LEVEL SECURITY; ALTER TABLE cp.consent_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE cp.consent_inbox ENABLE ROW LEVEL SECURITY; ALTER TABLE cp.consent_inbox FORCE ROW LEVEL SECURITY;
REVOKE ALL ON cp.consent_ledger FROM PUBLIC; REVOKE ALL ON cp.consent_inbox FROM PUBLIC;
REVOKE ALL ON cp.consent_ledger FROM cp_lookup, cp_consent_customer; REVOKE ALL ON cp.consent_inbox FROM cp_lookup, cp_consent_customer;
REVOKE ALL ON SEQUENCE cp.consent_ledger_id_seq FROM PUBLIC;

CREATE OR REPLACE FUNCTION cp.consent_note(p_kind text, p_consent uuid, p_org uuid, p_actor text, p_note text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
  INSERT INTO cp.consent_ledger (kind, consent_id, org_id, actor, note) VALUES (p_kind, p_consent, p_org, p_actor, p_note)
$f$;

-- WHO MAY DECIDE: an ACTIVE owner or admin of that company in public.org_members. ONE function, so the rule lives in one place.
-- HONEST NOTE: org_members.org_id references public.organisations(id) while the Desk's company id is public.orgs(id); that both id families are the same set is NOT proven. CP5-check reports how many companies have a reachable approver, and Z4c does not start until his paste shows it.
CREATE OR REPLACE FUNCTION cp.consent_is_approver(p_org uuid, p_user uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
  SELECT EXISTS (SELECT 1 FROM public.org_members m WHERE m.org_id = p_org AND m.user_id = p_user AND m.role IN ('owner', 'admin') AND coalesce(m.status::text, 'active') = 'active')
$f$;
CREATE OR REPLACE FUNCTION cp.consent_approver_reach() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
  SELECT jsonb_build_object('companies', (SELECT count(*) FROM public.orgs), 'companies_with_an_approver', (SELECT count(*) FROM public.orgs o WHERE EXISTS (SELECT 1 FROM public.org_members m WHERE m.org_id = o.id AND m.role IN ('owner', 'admin') AND coalesce(m.status::text, 'active') = 'active')))
$f$;

-- DOOR 1 (Control Plane, from the Desk): a staff request arrives. Idempotent per consent id. Unknown company, bad shape, or a flood = refused (null / error), never invented.
CREATE OR REPLACE FUNCTION cp.consent_push(p_consent uuid, p_company text, p_case text, p_scope text, p_reason text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
DECLARE v_org uuid; v_row cp.consent_inbox;
BEGIN
  IF p_consent IS NULL OR p_company IS NULL OR p_company !~ '^[0-9a-fA-F-]{36}$' OR p_case IS NULL OR p_case !~ '^[A-Za-z0-9_-]{4,40}$' OR p_scope NOT IN ('metadata', 'headers', 'content') OR p_reason IS NULL OR length(p_reason) NOT BETWEEN 20 AND 300 THEN
    PERFORM cp.consent_note('refused', p_consent, NULL, 'desk', 'push: bad shape'); RETURN NULL;
  END IF;
  SELECT o.id INTO v_org FROM public.orgs o WHERE o.id = p_company::uuid;
  IF v_org IS NULL THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'desk', 'push: unknown company'); RETURN NULL; END IF;
  SELECT * INTO v_row FROM cp.consent_inbox WHERE consent_id = p_consent;
  IF FOUND THEN
    IF v_row.org_id <> v_org OR v_row.case_ref <> p_case OR v_row.scope <> p_scope THEN PERFORM cp.consent_note('refused', p_consent, v_org, 'desk', 'push: same id, different facts'); RETURN NULL; END IF;
    RETURN jsonb_build_object('consent', p_consent, 'status', v_row.status);
  END IF;
  IF (SELECT count(*) FROM cp.consent_inbox i WHERE i.org_id = v_org AND i.status = 'requested') >= 20 THEN PERFORM cp.consent_note('refused', p_consent, v_org, 'desk', 'push: too many waiting'); RETURN NULL; END IF;
  PERFORM cp.consent_note('pushed', p_consent, v_org, 'desk', 'case ' || p_case || ' scope ' || p_scope);
  INSERT INTO cp.consent_inbox (consent_id, org_id, case_ref, scope, reason) VALUES (p_consent, v_org, p_case, p_scope, p_reason);
  RETURN jsonb_build_object('consent', p_consent, 'status', 'requested');
END $f$;

-- DOOR 2 (Control Plane): staff withdraw a waiting request.
CREATE OR REPLACE FUNCTION cp.consent_cancel(p_consent uuid) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
DECLARE v_row cp.consent_inbox;
BEGIN
  SELECT * INTO v_row FROM cp.consent_inbox WHERE consent_id = p_consent FOR UPDATE;
  IF NOT FOUND OR v_row.status <> 'requested' THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'desk', 'cancel: not a waiting request'); RETURN NULL; END IF;
  PERFORM cp.consent_note('cancelled', p_consent, v_row.org_id, 'desk', 'staff withdrew');
  UPDATE cp.consent_inbox SET status = 'cancelled' WHERE consent_id = p_consent;
  RETURN jsonb_build_object('consent', p_consent, 'status', 'cancelled');
END $f$;

-- DOOR 3 (Control Plane, read only): the Desk asks for the answers to its waiting / live requests (max 50 ids). A window that ended is REPORTED expired (the clock decides, no cron).
CREATE OR REPLACE FUNCTION cp.consent_poll(p_consents uuid[]) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
  SELECT CASE WHEN p_consents IS NULL OR cardinality(p_consents) NOT BETWEEN 1 AND 50 THEN NULL ELSE
    coalesce((SELECT jsonb_agg(jsonb_build_object('consent', i.consent_id,
      'status', CASE WHEN i.status = 'approved' AND upper(i.access_window) <= now() THEN 'expired' ELSE i.status END,
      'window_start', CASE WHEN i.access_window IS NULL THEN NULL ELSE floor(extract(epoch FROM lower(i.access_window)))::bigint END,
      'window_end', CASE WHEN i.access_window IS NULL THEN NULL ELSE floor(extract(epoch FROM upper(i.access_window)))::bigint END,
      'decision_ref', i.decision_hash) ORDER BY i.requested_at)
      FROM cp.consent_inbox i WHERE i.consent_id = ANY (p_consents)), '[]'::jsonb) END
$f$;

-- DOOR 4 (customer side only): the waiting and live requests of ONE company, for an active owner or admin of it. No content, no staff name.
CREATE OR REPLACE FUNCTION cp.consent_inbox_for(p_org uuid, p_user uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
  SELECT CASE WHEN cp.consent_is_approver(p_org, p_user) THEN
    coalesce((SELECT jsonb_agg(jsonb_build_object('consent', i.consent_id, 'case_ref', i.case_ref, 'scope', i.scope, 'reason', i.reason, 'minutes', cp.consent_minutes(i.scope),
      'status', CASE WHEN i.status = 'approved' AND upper(i.access_window) <= now() THEN 'expired' ELSE i.status END,
      'asked_at', floor(extract(epoch FROM i.requested_at))::bigint,
      'window_end', CASE WHEN i.access_window IS NULL THEN NULL ELSE floor(extract(epoch FROM upper(i.access_window)))::bigint END) ORDER BY i.requested_at DESC)
      FROM (SELECT * FROM cp.consent_inbox x WHERE x.org_id = p_org ORDER BY x.requested_at DESC LIMIT 100) i), '[]'::jsonb) ELSE NULL END
$f$;

-- DOOR 5 (customer side only): approve or deny. Needs an ACTIVE owner/admin of THAT company and a passkey digest. Only a waiting request can be decided. The ledger line is written FIRST; its hash is the decision reference the Desk keeps.
CREATE OR REPLACE FUNCTION cp.consent_decide(p_consent uuid, p_user uuid, p_decision text, p_passkey_digest text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
DECLARE v_row cp.consent_inbox; v_now timestamptz := clock_timestamp(); v_hash text; v_kind text;
BEGIN
  IF p_decision NOT IN ('approve', 'deny') OR p_passkey_digest IS NULL OR p_passkey_digest !~ '^[0-9a-f]{32,128}$' THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'customer', 'decide: bad shape'); RETURN NULL; END IF;
  SELECT * INTO v_row FROM cp.consent_inbox WHERE consent_id = p_consent FOR UPDATE;
  IF NOT FOUND OR v_row.status <> 'requested' THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'customer', 'decide: not a waiting request'); RETURN NULL; END IF;
  IF NOT cp.consent_is_approver(v_row.org_id, p_user) THEN
    PERFORM cp.consent_note('refused', p_consent, v_row.org_id, 'customer', 'decide: not an active owner or admin of this company'); RETURN NULL;
  END IF;
  v_kind := CASE p_decision WHEN 'approve' THEN 'approved' ELSE 'denied' END;
  PERFORM cp.consent_note(v_kind, p_consent, v_row.org_id, 'user ' || p_user::text, 'passkey ' || left(p_passkey_digest, 16));
  SELECT encode(l.hash, 'hex') INTO v_hash FROM cp.consent_ledger l ORDER BY l.id DESC LIMIT 1;
  UPDATE cp.consent_inbox SET status = v_kind, decided_at = v_now, decided_by = p_user, passkey_digest = p_passkey_digest, decision_hash = v_hash,
    access_window = CASE WHEN v_kind = 'approved' THEN tstzrange(v_now, v_now + make_interval(mins => cp.consent_minutes(v_row.scope)), '[)') ELSE NULL END
    WHERE consent_id = p_consent;
  RETURN jsonb_build_object('consent', p_consent, 'status', v_kind, 'decision_ref', v_hash);
END $f$;

-- DOOR 6 (customer side only): close a live window at once.
CREATE OR REPLACE FUNCTION cp.consent_revoke(p_consent uuid, p_user uuid, p_passkey_digest text) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
DECLARE v_row cp.consent_inbox; v_now timestamptz := clock_timestamp();
BEGIN
  IF p_passkey_digest IS NULL OR p_passkey_digest !~ '^[0-9a-f]{32,128}$' THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'customer', 'revoke: bad shape'); RETURN NULL; END IF;
  SELECT * INTO v_row FROM cp.consent_inbox WHERE consent_id = p_consent FOR UPDATE;
  IF NOT FOUND OR v_row.status <> 'approved' OR upper(v_row.access_window) <= v_now THEN PERFORM cp.consent_note('refused', p_consent, NULL, 'customer', 'revoke: no live window'); RETURN NULL; END IF;
  IF NOT cp.consent_is_approver(v_row.org_id, p_user) THEN
    PERFORM cp.consent_note('refused', p_consent, v_row.org_id, 'customer', 'revoke: not an active owner or admin of this company'); RETURN NULL;
  END IF;
  PERFORM cp.consent_note('revoked', p_consent, v_row.org_id, 'user ' || p_user::text, 'passkey ' || left(p_passkey_digest, 16));
  UPDATE cp.consent_inbox SET status = 'revoked', access_window = tstzrange(lower(access_window), v_now, '[)'), decided_by = p_user, passkey_digest = p_passkey_digest WHERE consent_id = p_consent;
  RETURN jsonb_build_object('consent', p_consent, 'status', 'revoked');
END $f$;

-- Chain check (read only): true when every line chains to the one before.
CREATE OR REPLACE FUNCTION cp.consent_ledger_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
DECLARE r record; p bytea := decode(repeat('00', 32), 'hex');
BEGIN
  FOR r IN SELECT * FROM cp.consent_ledger ORDER BY id LOOP
    IF r.prev <> p OR r.hash <> cp.consent_line_hash(r.prev, r.kind, r.consent_id, r.org_id, r.actor, r.note, r.at) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

REVOKE ALL ON FUNCTION cp.consent_minutes(text), cp.consent_line_hash(bytea, text, uuid, uuid, text, text, timestamptz), cp.consent_ledger_guard(), cp.consent_inbox_guard(), cp.consent_note(text, uuid, uuid, text, text), cp.consent_is_approver(uuid, uuid), cp.consent_approver_reach(),
  cp.consent_push(uuid, text, text, text, text), cp.consent_cancel(uuid), cp.consent_poll(uuid[]), cp.consent_inbox_for(uuid, uuid), cp.consent_decide(uuid, uuid, text, text), cp.consent_revoke(uuid, uuid, text), cp.consent_ledger_verify() FROM PUBLIC;
GRANT USAGE ON SCHEMA cp TO cp_lookup, cp_consent_customer;
GRANT EXECUTE ON FUNCTION cp.consent_push(uuid, text, text, text, text), cp.consent_cancel(uuid), cp.consent_poll(uuid[]), cp.consent_ledger_verify() TO cp_lookup;
GRANT EXECUTE ON FUNCTION cp.consent_inbox_for(uuid, uuid), cp.consent_decide(uuid, uuid, text, text), cp.consent_revoke(uuid, uuid, text), cp.consent_ledger_verify() TO cp_consent_customer;
GRANT EXECUTE ON FUNCTION cp.consent_approver_reach() TO cp_consent_customer;

-- SELFTEST (rolled back): every rule once, then it raises to undo its own rows.
CREATE FUNCTION pg_temp.cp5_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'CP5 selftest: %', msg USING ERRCODE = 'P0AS1'; END IF; END $f$;
DO $$
DECLARE o1 uuid := gen_random_uuid(); o2 uuid := gen_random_uuid(); u_admin uuid := gen_random_uuid(); u_member uuid := gen_random_uuid(); u_other uuid := gen_random_uuid();
        c1 uuid := gen_random_uuid(); c2 uuid := gen_random_uuid(); c3 uuid := gen_random_uuid(); r jsonb; dg text := repeat('ab', 32); failed boolean;
BEGIN
  PERFORM pg_temp.cp5_ok(cp.consent_is_approver(gen_random_uuid(), gen_random_uuid()) IS FALSE, 'the REAL membership query runs on the live schema and finds nobody for random ids');
  INSERT INTO public.orgs (id, name) VALUES (o1, 'cp5-a-' || o1), (o2, 'cp5-b-' || o2);
  -- org_members has foreign keys to auth.users and organisations, so the test people live in a temp table and the approver door is swapped for a test copy INSIDE this rolled-back selftest only
  CREATE TEMP TABLE cp5_approvers (org uuid, usr uuid) ON COMMIT DROP;
  INSERT INTO cp5_approvers VALUES (o1, u_admin), (o2, u_other);
  EXECUTE 'CREATE OR REPLACE FUNCTION cp.consent_is_approver(p_org uuid, p_user uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $x$ SELECT EXISTS (SELECT 1 FROM pg_temp.cp5_approvers a WHERE a.org = p_org AND a.usr = p_user) $x$';
  PERFORM pg_temp.cp5_ok(cp.consent_push(c1, o1::text, 'CASE-0001', 'metadata', 'customer says mail is missing since noon') ->> 'status' = 'requested', 'push creates a waiting request');
  PERFORM pg_temp.cp5_ok(cp.consent_push(c1, o1::text, 'CASE-0001', 'metadata', 'customer says mail is missing since noon') ->> 'status' = 'requested', 'push is idempotent');
  PERFORM pg_temp.cp5_ok(cp.consent_push(c1, o1::text, 'CASE-0002', 'metadata', 'customer says mail is missing since noon') IS NULL, 'same id with other facts is refused');
  PERFORM pg_temp.cp5_ok(cp.consent_push(gen_random_uuid(), gen_random_uuid()::text, 'CASE-0001', 'metadata', 'customer says mail is missing since noon') IS NULL, 'unknown company refused');
  PERFORM pg_temp.cp5_ok(cp.consent_push(gen_random_uuid(), o1::text, 'CASE-0001', 'everything', 'customer says mail is missing since noon') IS NULL, 'bad scope refused');
  PERFORM pg_temp.cp5_ok(cp.consent_push(gen_random_uuid(), o1::text, 'CASE-0001', 'metadata', 'short') IS NULL, 'short reason refused');
  PERFORM pg_temp.cp5_ok(cp.consent_inbox_for(o1, u_member) IS NULL, 'a plain member cannot see the inbox');
  PERFORM pg_temp.cp5_ok(cp.consent_inbox_for(o1, u_other) IS NULL, 'an admin of ANOTHER company cannot see this inbox');
  PERFORM pg_temp.cp5_ok(jsonb_array_length(cp.consent_inbox_for(o1, u_admin)) = 1, 'the company admin sees one waiting request');
  PERFORM pg_temp.cp5_ok(cp.consent_decide(c1, u_member, 'approve', dg) IS NULL, 'a member cannot decide');
  PERFORM pg_temp.cp5_ok(cp.consent_decide(c1, u_other, 'approve', dg) IS NULL, 'an owner of another company cannot decide');
  PERFORM pg_temp.cp5_ok(cp.consent_decide(c1, u_admin, 'approve', 'nope') IS NULL, 'no passkey digest, no decision');
  PERFORM pg_temp.cp5_ok(cp.consent_decide(c1, u_admin, 'maybe', dg) IS NULL, 'closed decision list');
  r := cp.consent_decide(c1, u_admin, 'approve', dg);
  PERFORM pg_temp.cp5_ok(r ->> 'status' = 'approved' AND length(r ->> 'decision_ref') = 64, 'the company admin approves, a decision reference comes back');
  PERFORM pg_temp.cp5_ok(cp.consent_decide(c1, u_admin, 'deny', dg) IS NULL, 'a decided request cannot be decided again');
  PERFORM pg_temp.cp5_ok((SELECT upper(access_window) - lower(access_window) FROM cp.consent_inbox WHERE consent_id = c1) = interval '60 minutes', 'metadata window is exactly 60 minutes');
  r := cp.consent_poll(ARRAY[c1]); PERFORM pg_temp.cp5_ok(r -> 0 ->> 'status' = 'approved' AND (r -> 0 ->> 'window_end')::bigint > extract(epoch FROM now()), 'poll shows the live window');
  PERFORM pg_temp.cp5_ok(cp.consent_cancel(c1) IS NULL, 'a decided request cannot be cancelled');
  PERFORM cp.consent_push(c2, o1::text, 'CASE-0003', 'content', 'customer asked us to look at the bounced message');
  r := cp.consent_decide(c2, u_admin, 'approve', dg); PERFORM pg_temp.cp5_ok((SELECT upper(access_window) - lower(access_window) FROM cp.consent_inbox WHERE consent_id = c2) = interval '15 minutes', 'content window is exactly 15 minutes');
  PERFORM pg_temp.cp5_ok(cp.consent_revoke(c2, u_member, dg) IS NULL, 'a member cannot revoke');
  PERFORM pg_temp.cp5_ok(cp.consent_revoke(c2, u_admin, dg) ->> 'status' = 'revoked', 'the admin revokes at once');
  PERFORM pg_temp.cp5_ok(cp.consent_poll(ARRAY[c2]) -> 0 ->> 'status' = 'revoked' AND (cp.consent_poll(ARRAY[c2]) -> 0 ->> 'window_end')::bigint <= extract(epoch FROM clock_timestamp()) + 1, 'revoked window ends now');
  PERFORM cp.consent_push(c3, o1::text, 'CASE-0004', 'headers', 'customer asked about delivery of one thread');
  PERFORM pg_temp.cp5_ok(cp.consent_cancel(c3) ->> 'status' = 'cancelled', 'staff withdraw a waiting request');
  PERFORM pg_temp.cp5_ok(cp.consent_poll(ARRAY[]::uuid[]) IS NULL AND cp.consent_poll(NULL) IS NULL, 'poll shape is closed');
  failed := false; BEGIN UPDATE cp.consent_ledger SET note = 'x'; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp5_ok(failed, 'ledger UPDATE refused');
  failed := false; BEGIN DELETE FROM cp.consent_ledger; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp5_ok(failed, 'ledger DELETE refused');
  failed := false; BEGIN DELETE FROM cp.consent_inbox; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp5_ok(failed, 'inbox DELETE refused');
  failed := false; BEGIN UPDATE cp.consent_inbox SET status = 'approved' WHERE consent_id = c3; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp5_ok(failed, 'a cancelled request cannot be approved by a raw update');
  failed := false; BEGIN UPDATE cp.consent_inbox SET reason = 'a different reason for the same request' WHERE consent_id = c3; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp5_ok(failed, 'request facts are frozen');
  PERFORM pg_temp.cp5_ok(cp.consent_ledger_verify(), 'the ledger chain verifies');
  PERFORM pg_temp.cp5_ok(NOT has_function_privilege('cp_lookup', 'cp.consent_decide(uuid, uuid, text, text)', 'execute') AND NOT has_function_privilege('cp_lookup', 'cp.consent_revoke(uuid, uuid, text)', 'execute') AND NOT has_function_privilege('cp_lookup', 'cp.consent_inbox_for(uuid, uuid)', 'execute'), 'the Control Plane role can NEVER decide, revoke or read the customer inbox');
  PERFORM pg_temp.cp5_ok(NOT has_function_privilege('cp_consent_customer', 'cp.consent_push(uuid, text, text, text, text)', 'execute'), 'the customer role can never push a request');
  PERFORM cp.consent_note('selftest', NULL, NULL, 'cp5', '');
  RAISE EXCEPTION 'CP5 selftest done' USING ERRCODE = 'P0AS2';
EXCEPTION WHEN SQLSTATE 'P0AS2' THEN RAISE NOTICE 'CP5 selftest: ALL RULES PASSED (selftest rows rolled back)';
END $$;
COMMIT;
