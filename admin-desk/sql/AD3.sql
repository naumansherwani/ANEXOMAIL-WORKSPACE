-- ==============================================================================================================================
-- AD3 (ADMIN DESK SQL, step 3, 22 Nov 2026 PKT): THE DESK BRIDGE = ALERT CENTER + SERVICE HEALTH + INCIDENTS + WATCHES + THE LIVE COMMAND BAR SUMMARY.
-- HIS ORDER (22 Nov 03:38): the Bridge of the Admin Desk is made for the Desk's own needs (it represents the company Anexomail), separate from the Founder Bridge.
-- BUILT ON (SCHEMA-FIRST LAW, read in full before writing): AD1 (fadm_owner, fadm_ledger + chain + fadm_ledger_verify, fadm_me), AD2 (fadm_alert table + fadm_alert_guard, fadm_audit, fadm_authorize / fadm_need, fadm_action,
--   fadm_policy, fadm_unit_id, fadm_ledger_kind closed list, RLS pattern p_installer). AD3 EXTENDS fadm_alert (adds source + dedupe_key, severity ladder info < notice < high < critical) and never renames or copies anything.
-- PLAN: docs/claude/admin-desk/BRIDGE-PLAN-22NOV.md. Research: Google Workspace alert center (alert lifecycle, assignee, notes, email rules, ~300 alerts per rule per day cap, 10-year retention),
--   Microsoft 365 service health (incident vs advisory, status ladder, update feed, post-incident report, history, notification subscriptions).
-- TECHNOLOGY: PostgreSQL ROW LEVEL SECURITY (ENABLE + FORCE on every table), append-only event tables with guard triggers, SECURITY DEFINER functions with fixed search_path, deny-by-default authorisation through fadm_authorize (AD2),
--   de-duplication by key, per-rule flood cap, probe-based service state that says "unknown" when the data is stale (never a guessed green), closed-list SHA-256 hash-chained ledger for every Bridge decision.
-- RULES: Desk tables only (fadm_*), no extension, NO superuser needed, idempotent, ONE transaction, SELFTEST rolls its own rows back (SQLSTATE P0AD3), desk_app gets EXECUTE on functions and NEVER direct write on an AD3 table.
--   DESK ISOLATION: nothing of founder or awam is read or written; the Founder Bridge is another security domain. Run only through ad-sql-run.sh (by number), then checks/AD3-check.sql.
-- HONEST NOTES: (1) a service with no probe shows UNKNOWN, never operational. (2) The probes themselves (Rust, tokio) arrive in R4-1b step 2; AD3 is the ledger of them. (3) Email/push delivery of alerts is a later step: watches here
--   feed the in-app inbox only. (4) fadm_bridge_summary verifies the whole ledger chain on each call: fine now, to be replaced by an incremental checkpoint at scale (noted in the plan).
-- ==============================================================================================================================
BEGIN;

-- 1) CLOSED LEDGER KINDS for every Bridge decision (the AD2 guard refuses any kind not on this list). ------------------------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad3.selftest','info','AD3'),('alert.critical','high','a critical alert was raised'),('alert.ack','notice','alert acknowledged'),('alert.assign','notice','alert assigned'),
  ('alert.status','notice','alert status changed'),('alert.note','info','note on an alert'),('service.outage','high','three failed probes in a row'),('service.recovered','notice','a probe passed again'),
  ('incident.opened','high','incident or advisory opened'),('incident.updated','notice','incident update'),('incident.closed','notice','incident closed'),('watch.changed','info','alert watch changed')
ON CONFLICT (kind) DO NOTHING;

-- 2) ACTIONS AND POLICIES (deny by default: the person needs the relation on the root department; forbid beats permit). ------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_action (action, note) VALUES
  ('alert.read','see the alert center'),('alert.ack','acknowledge or comment on an alert'),('alert.assign','assign an alert'),('alert.resolve','resolve or dismiss an alert'),
  ('health.read','see service health'),('incident.manage','open or update an incident')
ON CONFLICT (action) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES
  ('p_alert_read','permit','alert.read','agent'),('p_alert_ack','permit','alert.ack','lead'),('p_alert_assign','permit','alert.assign','lead'),('p_alert_resolve','permit','alert.resolve','supervisor'),
  ('p_health_read','permit','health.read','agent'),('p_incident_manage','permit','incident.manage','supervisor')
ON CONFLICT (name) DO NOTHING;

-- 3) EXTEND THE ALERT: a source, a de-duplication key and the severity ladder (info, notice, high, critical = P1). The alert row itself stays immutable; its life is in fadm_alert_state + fadm_alert_event. -----------------
DO $$ DECLARE c record; BEGIN
  FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'desk.fadm_alert'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) ILIKE '%severity%' LOOP
    EXECUTE format('ALTER TABLE desk.fadm_alert DROP CONSTRAINT %I', c.conname);
  END LOOP;
END $$;
ALTER TABLE desk.fadm_alert ADD CONSTRAINT fadm_alert_severity_ck CHECK (severity IN ('info','notice','high','critical'));
ALTER TABLE desk.fadm_alert ADD COLUMN IF NOT EXISTS source     text NOT NULL DEFAULT 'security';
ALTER TABLE desk.fadm_alert ADD COLUMN IF NOT EXISTS dedupe_key text;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fadm_alert_source_ck') THEN
    ALTER TABLE desk.fadm_alert ADD CONSTRAINT fadm_alert_source_ck CHECK (source IN ('security','access','service','mail','case','plan','system'));
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS fadm_alert_dedupe_ix ON desk.fadm_alert (source, dedupe_key, at DESC) WHERE dedupe_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS fadm_alert_kind_at_ix ON desk.fadm_alert (source, kind, at DESC);
-- the immutability guard now also freezes source and dedupe_key (acknowledging with acked_by/acked_at stays the only allowed change, once)
CREATE OR REPLACE FUNCTION desk.fadm_alert_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP = 'DELETE' THEN RAISE EXCEPTION 'alerts are never deleted' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (NEW.id, NEW.at, NEW.severity, NEW.kind, NEW.owner_id, NEW.detail, NEW.source, NEW.dedupe_key) IS DISTINCT FROM (OLD.id, OLD.at, OLD.severity, OLD.kind, OLD.owner_id, OLD.detail, OLD.source, OLD.dedupe_key) OR OLD.acked_at IS NOT NULL
    THEN RAISE EXCEPTION 'an alert can only be acknowledged, once' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;

-- 4) ALERT LIFE: state (one row per alert) + append-only event history (ack, assign, status, note). ----------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_alert_state (
  alert_id    bigint PRIMARY KEY REFERENCES desk.fadm_alert(id),
  status      text NOT NULL DEFAULT 'new' CHECK (status IN ('new','ack','in_progress','resolved','false_positive')),
  assignee    uuid REFERENCES desk.fadm_owner(id),
  seen_count  integer NOT NULL DEFAULT 1 CHECK (seen_count >= 1),
  last_at     timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  closed_at   timestamptz,
  CONSTRAINT fadm_alert_state_closed_ck CHECK ((status IN ('resolved','false_positive')) = (closed_at IS NOT NULL))
);
CREATE INDEX IF NOT EXISTS fadm_alert_state_open_ix ON desk.fadm_alert_state (status) WHERE closed_at IS NULL;
CREATE TABLE IF NOT EXISTS desk.fadm_alert_event (
  id       bigserial PRIMARY KEY,
  alert_id bigint NOT NULL REFERENCES desk.fadm_alert(id),
  at       timestamptz NOT NULL DEFAULT now(),
  actor    uuid REFERENCES desk.fadm_owner(id),                    -- NULL = the system (a probe or the breaker)
  event    text NOT NULL CHECK (event IN ('raised','seen_again','ack','assign','status','note')),
  detail   jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS fadm_alert_event_alert_ix ON desk.fadm_alert_event (alert_id, at);
CREATE OR REPLACE FUNCTION desk.fadm_append_only_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN RAISE EXCEPTION '% is append-only', TG_TABLE_NAME USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_alert_event_guard ON desk.fadm_alert_event;
CREATE TRIGGER fadm_alert_event_guard BEFORE UPDATE OR DELETE ON desk.fadm_alert_event FOR EACH ROW EXECUTE FUNCTION desk.fadm_append_only_guard();
-- every alert, including the ones AD2 raises (burst.freeze), gets its state row and its first event automatically
CREATE OR REPLACE FUNCTION desk.fadm_alert_after_insert() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  INSERT INTO desk.fadm_alert_state (alert_id, last_at) VALUES (NEW.id, NEW.at) ON CONFLICT (alert_id) DO NOTHING;
  INSERT INTO desk.fadm_alert_event (alert_id, actor, event, detail) VALUES (NEW.id, NULL, 'raised', jsonb_build_object('severity', NEW.severity, 'source', NEW.source, 'kind', NEW.kind));
  IF NEW.severity = 'critical' THEN PERFORM desk.fadm_audit(NULL, 'alert.critical', jsonb_build_object('alert', NEW.id, 'source', NEW.source, 'kind', NEW.kind)); END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_alert_after_insert ON desk.fadm_alert;
CREATE TRIGGER fadm_alert_after_insert AFTER INSERT ON desk.fadm_alert FOR EACH ROW EXECUTE FUNCTION desk.fadm_alert_after_insert();
INSERT INTO desk.fadm_alert_state (alert_id, last_at, status, closed_at)
  SELECT a.id, a.at, CASE WHEN a.acked_at IS NOT NULL THEN 'ack' ELSE 'new' END, NULL FROM desk.fadm_alert a ON CONFLICT (alert_id) DO NOTHING;

-- 5) RAISE: de-duplicated by key while an alert with that key is still open, and capped at 300 new alerts per source+kind per 24 hours (Google's own alert-center rule cap). Returns the alert id, or NULL when capped. ----
CREATE OR REPLACE FUNCTION desk.fadm_alert_raise(p_source text, p_severity text, p_kind text, p_owner uuid DEFAULT NULL, p_detail jsonb DEFAULT '{}'::jsonb, p_dedupe text DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE a bigint; n integer;
BEGIN
  IF p_dedupe IS NOT NULL THEN
    SELECT x.id INTO a FROM desk.fadm_alert x JOIN desk.fadm_alert_state s ON s.alert_id = x.id
     WHERE x.source = p_source AND x.dedupe_key = p_dedupe AND s.closed_at IS NULL ORDER BY x.at DESC LIMIT 1;
    IF a IS NOT NULL THEN
      UPDATE desk.fadm_alert_state SET seen_count = seen_count + 1, last_at = now(), updated_at = now() WHERE alert_id = a;
      INSERT INTO desk.fadm_alert_event (alert_id, actor, event, detail) VALUES (a, NULL, 'seen_again', coalesce(p_detail, '{}'::jsonb));
      RETURN a;
    END IF;
  END IF;
  SELECT count(*) INTO n FROM desk.fadm_alert WHERE source = p_source AND kind = p_kind AND at > now() - interval '24 hours';
  IF n >= 300 THEN RETURN NULL; END IF;
  INSERT INTO desk.fadm_alert (severity, kind, owner_id, detail, source, dedupe_key) VALUES (p_severity, p_kind, p_owner, coalesce(p_detail, '{}'::jsonb), p_source, p_dedupe) RETURNING id INTO a;
  RETURN a;
END $f$;

-- 6) ACT ON AN ALERT: ack, assign, status change, note. Needs the right action; a person cannot close an alert about himself; resolved is final; false_positive only from an open alert. ---------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_alert_act(p_actor uuid, p_alert bigint, p_event text, p_status text DEFAULT NULL, p_assignee uuid DEFAULT NULL, p_note text DEFAULT NULL, p_ip inet DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE root uuid := desk.fadm_unit_id('department', 'desk'); st record; al record; need text;
BEGIN
  SELECT * INTO al FROM desk.fadm_alert WHERE id = p_alert;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such alert' USING ERRCODE = 'no_data_found'; END IF;
  SELECT * INTO st FROM desk.fadm_alert_state WHERE alert_id = p_alert FOR UPDATE;
  need := CASE p_event WHEN 'ack' THEN 'alert.ack' WHEN 'assign' THEN 'alert.assign' WHEN 'note' THEN 'alert.ack'
                       WHEN 'status' THEN CASE WHEN p_status IN ('resolved','false_positive') THEN 'alert.resolve' ELSE 'alert.ack' END ELSE NULL END;
  IF need IS NULL THEN RAISE EXCEPTION 'unknown alert event %', p_event USING ERRCODE = 'check_violation'; END IF;
  PERFORM desk.fadm_need(p_actor, need, root, p_ip);
  IF st.closed_at IS NOT NULL THEN RAISE EXCEPTION 'alert is closed' USING ERRCODE = 'check_violation'; END IF;
  IF p_event = 'status' AND p_status IN ('resolved','false_positive') AND al.owner_id IS NOT NULL AND al.owner_id = p_actor
    THEN RAISE EXCEPTION 'a person cannot close an alert about himself' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF p_event = 'ack' THEN
    IF st.status <> 'new' THEN RAISE EXCEPTION 'only a new alert can be acknowledged' USING ERRCODE = 'check_violation'; END IF;
    UPDATE desk.fadm_alert_state SET status = 'ack', updated_at = now() WHERE alert_id = p_alert;
    UPDATE desk.fadm_alert SET acked_by = p_actor, acked_at = now() WHERE id = p_alert AND acked_at IS NULL;
    PERFORM desk.fadm_audit(p_actor, 'alert.ack', jsonb_build_object('alert', p_alert));
  ELSIF p_event = 'assign' THEN
    IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_assignee AND o.status = 'active') THEN RAISE EXCEPTION 'assignee must be an active person' USING ERRCODE = 'check_violation'; END IF;
    UPDATE desk.fadm_alert_state SET assignee = p_assignee, updated_at = now() WHERE alert_id = p_alert;
    PERFORM desk.fadm_audit(p_actor, 'alert.assign', jsonb_build_object('alert', p_alert, 'assignee', p_assignee));
  ELSIF p_event = 'status' THEN
    IF p_status NOT IN ('in_progress','resolved','false_positive') THEN RAISE EXCEPTION 'status % cannot be set here', p_status USING ERRCODE = 'check_violation'; END IF;
    UPDATE desk.fadm_alert_state SET status = p_status, updated_at = now(), closed_at = CASE WHEN p_status IN ('resolved','false_positive') THEN now() END WHERE alert_id = p_alert;
    PERFORM desk.fadm_audit(p_actor, 'alert.status', jsonb_build_object('alert', p_alert, 'status', p_status));
  ELSE
    IF p_note IS NULL OR length(p_note) NOT BETWEEN 1 AND 2000 THEN RAISE EXCEPTION 'note must be 1 to 2000 characters' USING ERRCODE = 'check_violation'; END IF;
    PERFORM desk.fadm_audit(p_actor, 'alert.note', jsonb_build_object('alert', p_alert));
  END IF;
  INSERT INTO desk.fadm_alert_event (alert_id, actor, event, detail)
    VALUES (p_alert, p_actor, p_event, jsonb_strip_nulls(jsonb_build_object('status', p_status, 'assignee', p_assignee, 'note', p_note)));
END $f$;

-- 7) SERVICE HEALTH: a closed list of services, an append-only probe log, a state that is honest about missing data. ----------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_service (
  service        text PRIMARY KEY CHECK (service ~ '^[a-z0-9_]{2,30}$'),
  label          text NOT NULL,
  critical       boolean NOT NULL DEFAULT false,
  probe_every_s  integer NOT NULL CHECK (probe_every_s BETWEEN 5 AND 3600),
  degraded_ms    integer NOT NULL CHECK (degraded_ms BETWEEN 1 AND 600000)
);
INSERT INTO desk.fadm_service (service, label, critical, probe_every_s, degraded_ms) VALUES
  ('h3_edge','HTTP/3 QUIC edge (UDP)',true,30,800),('tls','TLS 1.3 handshake',true,60,800),('db','Desk database',true,30,300),('signer','Desk answer signer (Ed25519)',true,60,300),
  ('ledger','Ledger hash chain',true,300,2000),('mail_in','Inbound mail',true,60,3000),('mail_out','Outbound mail',true,60,3000),('dns','DNS (SPF, DKIM, DMARC, MTA-STS)',false,300,2000),
  ('storage_box','Attachment storage (Storage Box)',false,120,2000),('clamav','ClamAV scanner',true,60,2000)
ON CONFLICT (service) DO NOTHING;
CREATE TABLE IF NOT EXISTS desk.fadm_probe (
  id         bigserial PRIMARY KEY,
  service    text NOT NULL REFERENCES desk.fadm_service(service),
  at         timestamptz NOT NULL DEFAULT now(),
  ok         boolean NOT NULL,
  latency_ms integer CHECK (latency_ms IS NULL OR latency_ms BETWEEN 0 AND 600000),
  detail     jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS fadm_probe_svc_at_ix ON desk.fadm_probe (service, at DESC);
-- probes are append-only; the only deletion path is the pruning function, which sets a transaction-local switch (30 days kept)
CREATE OR REPLACE FUNCTION desk.fadm_probe_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF TG_OP = 'DELETE' AND current_setting('desk.prune', true) = 'on' AND OLD.at < now() - interval '30 days' THEN RETURN OLD; END IF;
  RAISE EXCEPTION 'fadm_probe is append-only' USING ERRCODE = 'insufficient_privilege';
END $f$;
DROP TRIGGER IF EXISTS fadm_probe_guard ON desk.fadm_probe;
CREATE TRIGGER fadm_probe_guard BEFORE UPDATE OR DELETE ON desk.fadm_probe FOR EACH ROW EXECUTE FUNCTION desk.fadm_probe_guard();
CREATE OR REPLACE FUNCTION desk.fadm_probe_prune() RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n integer;
BEGIN PERFORM set_config('desk.prune', 'on', true); DELETE FROM desk.fadm_probe WHERE at < now() - interval '30 days'; GET DIAGNOSTICS n = ROW_COUNT; PERFORM set_config('desk.prune', 'off', true); RETURN n; END $f$;
-- state: unknown (no probe, or the last one is older than 3 intervals), outage (last 3 failed), degraded (last failed, or slower than the limit), operational
CREATE OR REPLACE FUNCTION desk.fadm_service_state(p_service text, p_at timestamptz DEFAULT now()) RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE sv record; last record; fails integer;
BEGIN
  SELECT * INTO sv FROM desk.fadm_service WHERE service = p_service;
  IF NOT FOUND THEN RETURN 'unknown'; END IF;
  SELECT * INTO last FROM desk.fadm_probe WHERE service = p_service AND at <= p_at ORDER BY at DESC, id DESC LIMIT 1;
  IF NOT FOUND OR last.at < p_at - make_interval(secs => sv.probe_every_s * 3) THEN RETURN 'unknown'; END IF;
  SELECT count(*) FILTER (WHERE NOT ok) INTO fails FROM (SELECT ok FROM desk.fadm_probe WHERE service = p_service AND at <= p_at ORDER BY at DESC, id DESC LIMIT 3) t;
  IF fails = 3 THEN RETURN 'outage'; END IF;
  IF NOT last.ok OR coalesce(last.latency_ms, 0) > sv.degraded_ms THEN RETURN 'degraded'; END IF;
  RETURN 'operational';
END $f$;
-- record a probe; the transition into outage raises ONE critical (or high) alert, the first pass after an outage closes it, both leave a ledger line
CREATE OR REPLACE FUNCTION desk.fadm_probe_record(p_service text, p_ok boolean, p_latency_ms integer DEFAULT NULL, p_detail jsonb DEFAULT '{}'::jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE sv record; before text; after text; a bigint;
BEGIN
  SELECT * INTO sv FROM desk.fadm_service WHERE service = p_service;
  IF NOT FOUND THEN RAISE EXCEPTION 'unknown service %', p_service USING ERRCODE = 'foreign_key_violation'; END IF;
  before := desk.fadm_service_state(p_service);
  INSERT INTO desk.fadm_probe (service, ok, latency_ms, detail) VALUES (p_service, p_ok, p_latency_ms, coalesce(p_detail, '{}'::jsonb));
  after := desk.fadm_service_state(p_service);
  IF after = 'outage' AND before <> 'outage' THEN
    PERFORM desk.fadm_alert_raise('service', CASE WHEN sv.critical THEN 'critical' ELSE 'high' END, 'service.outage', NULL, jsonb_build_object('service', p_service, 'label', sv.label), 'svc:' || p_service);
    PERFORM desk.fadm_audit(NULL, 'service.outage', jsonb_build_object('service', p_service));
  ELSIF before = 'outage' AND after <> 'outage' THEN
    FOR a IN SELECT x.id FROM desk.fadm_alert x JOIN desk.fadm_alert_state s ON s.alert_id = x.id WHERE x.source = 'service' AND x.dedupe_key = 'svc:' || p_service AND s.closed_at IS NULL LOOP
      UPDATE desk.fadm_alert_state SET status = 'resolved', closed_at = now(), updated_at = now() WHERE alert_id = a;
      INSERT INTO desk.fadm_alert_event (alert_id, actor, event, detail) VALUES (a, NULL, 'status', jsonb_build_object('status', 'resolved', 'by', 'probe'));
    END LOOP;
    PERFORM desk.fadm_audit(NULL, 'service.recovered', jsonb_build_object('service', p_service));
  END IF;
  RETURN after;
END $f$;

-- 8) INCIDENTS AND ADVISORIES (Microsoft's model): an incident = a service or major function is unavailable, an advisory = degraded but usable; every change is an update in an append-only feed. ----------------------
CREATE TABLE IF NOT EXISTS desk.fadm_incident (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  service    text NOT NULL REFERENCES desk.fadm_service(service),
  kind       text NOT NULL CHECK (kind IN ('incident','advisory')),
  status     text NOT NULL DEFAULT 'investigating' CHECK (status IN ('investigating','degradation','interruption','restoring','restored','false_positive','post_report_published')),
  title      text NOT NULL CHECK (length(title) BETWEEN 3 AND 200),
  impact     text NOT NULL DEFAULT '' CHECK (length(impact) <= 2000),
  opened_by  uuid NOT NULL REFERENCES desk.fadm_owner(id),
  opened_at  timestamptz NOT NULL DEFAULT now(),
  closed_at  timestamptz
);
CREATE INDEX IF NOT EXISTS fadm_incident_open_ix ON desk.fadm_incident (service) WHERE closed_at IS NULL;
CREATE TABLE IF NOT EXISTS desk.fadm_incident_update (
  id          bigserial PRIMARY KEY,
  incident_id uuid NOT NULL REFERENCES desk.fadm_incident(id),
  at          timestamptz NOT NULL DEFAULT now(),
  actor       uuid NOT NULL REFERENCES desk.fadm_owner(id),
  status      text NOT NULL,
  body        text NOT NULL CHECK (length(body) BETWEEN 1 AND 4000)
);
DROP TRIGGER IF EXISTS fadm_incident_update_guard ON desk.fadm_incident_update;
CREATE TRIGGER fadm_incident_update_guard BEFORE UPDATE OR DELETE ON desk.fadm_incident_update FOR EACH ROW EXECUTE FUNCTION desk.fadm_append_only_guard();
CREATE OR REPLACE FUNCTION desk.fadm_incident_open(p_actor uuid, p_service text, p_kind text, p_title text, p_impact text DEFAULT '', p_ip inet DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE i uuid;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'incident.manage', desk.fadm_unit_id('department', 'desk'), p_ip);
  INSERT INTO desk.fadm_incident (service, kind, title, impact, opened_by) VALUES (p_service, p_kind, p_title, coalesce(p_impact, ''), p_actor) RETURNING id INTO i;
  INSERT INTO desk.fadm_incident_update (incident_id, actor, status, body) VALUES (i, p_actor, 'investigating', 'opened: ' || p_title);
  PERFORM desk.fadm_audit(p_actor, 'incident.opened', jsonb_build_object('incident', i, 'service', p_service, 'kind', p_kind));
  RETURN i;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_incident_update_add(p_actor uuid, p_incident uuid, p_status text, p_body text, p_ip inet DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE inc record; closing boolean := p_status IN ('restored','false_positive');
BEGIN
  PERFORM desk.fadm_need(p_actor, 'incident.manage', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT * INTO inc FROM desk.fadm_incident WHERE id = p_incident FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such incident' USING ERRCODE = 'no_data_found'; END IF;
  IF inc.closed_at IS NOT NULL AND p_status <> 'post_report_published' THEN RAISE EXCEPTION 'incident is closed: only a post-incident report can follow' USING ERRCODE = 'check_violation'; END IF;
  IF inc.status = 'post_report_published' THEN RAISE EXCEPTION 'the post-incident report is the last word' USING ERRCODE = 'check_violation'; END IF;
  IF p_status = 'post_report_published' AND inc.closed_at IS NULL THEN RAISE EXCEPTION 'close the incident before its report' USING ERRCODE = 'check_violation'; END IF;
  INSERT INTO desk.fadm_incident_update (incident_id, actor, status, body) VALUES (p_incident, p_actor, p_status, p_body);
  UPDATE desk.fadm_incident SET status = p_status, closed_at = CASE WHEN closing THEN now() ELSE closed_at END WHERE id = p_incident;
  PERFORM desk.fadm_audit(p_actor, CASE WHEN closing THEN 'incident.closed' ELSE 'incident.updated' END, jsonb_build_object('incident', p_incident, 'status', p_status));
END $f$;

-- 9) WATCHES (Google's notification rules, in-app first): a person says which sources and which minimum severity land in his inbox. -------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_alert_watch (
  owner_id     uuid NOT NULL REFERENCES desk.fadm_owner(id),
  source       text NOT NULL CHECK (source IN ('security','access','service','mail','case','plan','system')),
  min_severity text NOT NULL DEFAULT 'high' CHECK (min_severity IN ('info','notice','high','critical')),
  PRIMARY KEY (owner_id, source)
);
CREATE OR REPLACE FUNCTION desk.fadm_sev_rank(p text) RETURNS smallint LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$ SELECT CASE p WHEN 'info' THEN 1 WHEN 'notice' THEN 2 WHEN 'high' THEN 3 WHEN 'critical' THEN 4 END::smallint $f$;
CREATE OR REPLACE FUNCTION desk.fadm_watch_set(p_actor uuid, p_source text, p_min text, p_on boolean DEFAULT true, p_ip inet DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'alert.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  IF p_on THEN
    INSERT INTO desk.fadm_alert_watch (owner_id, source, min_severity) VALUES (p_actor, p_source, p_min) ON CONFLICT (owner_id, source) DO UPDATE SET min_severity = EXCLUDED.min_severity;
  ELSE DELETE FROM desk.fadm_alert_watch WHERE owner_id = p_actor AND source = p_source; END IF;
  PERFORM desk.fadm_audit(p_actor, 'watch.changed', jsonb_build_object('source', p_source, 'min', p_min, 'on', p_on));
END $f$;

-- 10) READ SIDE for the Rust door and the dashboard (every read is authorised; desk_app never selects these tables directly). -------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_alert_list(p_actor uuid, p_open_only boolean DEFAULT true, p_limit integer DEFAULT 100, p_inbox boolean DEFAULT false, p_ip inet DEFAULT NULL)
RETURNS TABLE (id bigint, at timestamptz, severity text, source text, kind text, status text, assignee uuid, seen_count integer, last_at timestamptz, detail jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'alert.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  RETURN QUERY SELECT a.id, a.at, a.severity, a.source, a.kind, s.status, s.assignee, s.seen_count, s.last_at, a.detail
    FROM desk.fadm_alert a JOIN desk.fadm_alert_state s ON s.alert_id = a.id
   WHERE (NOT p_open_only OR s.closed_at IS NULL)
     AND (NOT p_inbox OR EXISTS (SELECT 1 FROM desk.fadm_alert_watch w WHERE w.owner_id = p_actor AND w.source = a.source AND desk.fadm_sev_rank(a.severity) >= desk.fadm_sev_rank(w.min_severity)))
   ORDER BY desk.fadm_sev_rank(a.severity) DESC, a.at DESC LIMIT least(greatest(p_limit, 1), 500);
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_bridge_services(p_actor uuid, p_ip inet DEFAULT NULL)
RETURNS TABLE (service text, label text, critical boolean, state text, last_probe_at timestamptz, age_s integer, last_latency_ms integer, uptime_24h numeric, probes_24h integer)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'health.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  RETURN QUERY SELECT v.service, v.label, v.critical, desk.fadm_service_state(v.service), l.at, (extract(epoch FROM now() - l.at))::integer, l.latency_ms,
      CASE WHEN c.n = 0 THEN NULL ELSE round(100.0 * c.ok_n / c.n, 2) END, c.n::integer
    FROM desk.fadm_service v
    LEFT JOIN LATERAL (SELECT p.at, p.latency_ms FROM desk.fadm_probe p WHERE p.service = v.service ORDER BY p.at DESC, p.id DESC LIMIT 1) l ON true
    LEFT JOIN LATERAL (SELECT count(*) AS n, count(*) FILTER (WHERE p.ok) AS ok_n FROM desk.fadm_probe p WHERE p.service = v.service AND p.at > now() - interval '24 hours') c ON true
   ORDER BY v.critical DESC, v.service;
END $f$;
-- THE LIVE COMMAND BAR NUMBERS (his 22 Nov 03:18 item A2 + A3): P1 = open critical alerts, plus every open high one, services by state, ledger seal. No number is invented: NULL means not measured.
CREATE OR REPLACE FUNCTION desk.fadm_bridge_summary(p_actor uuid, p_ip inet DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r jsonb;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'health.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT jsonb_build_object(
    'p1_open',        (SELECT count(*) FROM desk.fadm_alert a JOIN desk.fadm_alert_state s ON s.alert_id = a.id WHERE s.closed_at IS NULL AND a.severity = 'critical'),
    'high_open',      (SELECT count(*) FROM desk.fadm_alert a JOIN desk.fadm_alert_state s ON s.alert_id = a.id WHERE s.closed_at IS NULL AND a.severity = 'high'),
    'unacked',        (SELECT count(*) FROM desk.fadm_alert_state s WHERE s.status = 'new'),
    'oldest_unacked_s',(SELECT (extract(epoch FROM now() - min(a.at)))::integer FROM desk.fadm_alert a JOIN desk.fadm_alert_state s ON s.alert_id = a.id WHERE s.status = 'new'),
    'incidents_open', (SELECT count(*) FROM desk.fadm_incident i WHERE i.closed_at IS NULL AND i.kind = 'incident'),
    'advisories_open',(SELECT count(*) FROM desk.fadm_incident i WHERE i.closed_at IS NULL AND i.kind = 'advisory'),
    'services',       (SELECT coalesce(jsonb_object_agg(v.service, desk.fadm_service_state(v.service)), '{}'::jsonb) FROM desk.fadm_service v),
    'critical_not_ok',(SELECT count(*) FROM desk.fadm_service v WHERE v.critical AND desk.fadm_service_state(v.service) IN ('outage','degraded')),
    'critical_unknown',(SELECT count(*) FROM desk.fadm_service v WHERE v.critical AND desk.fadm_service_state(v.service) = 'unknown'),
    'ledger_ok',      desk.fadm_ledger_verify(),
    'at',             now()) INTO r;
  RETURN r;
END $f$;

-- 11) ROW LEVEL SECURITY ON EVERY NEW TABLE (ENABLE + FORCE), desk_app gets no direct privilege on any of them; the Rust door goes through the functions above. ---------------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_alert_state','fadm_alert_event','fadm_service','fadm_probe','fadm_incident','fadm_incident_update','fadm_alert_watch'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
ALTER FUNCTION desk.fadm_append_only_guard() SECURITY DEFINER;  ALTER FUNCTION desk.fadm_probe_guard() SECURITY DEFINER;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA desk FROM PUBLIC;
-- re-grant what AD1/AD1b/AD2 had granted (REVOKE ... ALL FUNCTIONS above is schema-wide), then the AD3 doors
DO $$ DECLARE f record; BEGIN
  FOR f IN SELECT p.oid::regprocedure AS sig FROM pg_proc p JOIN pg_namespace s ON s.oid = p.pronamespace
            WHERE s.nspname = 'desk' AND p.proname IN ('fadm_me','fadm_login_lookup','fadm_session_lookup','fadm_session_create','fadm_session_revoke','fadm_ledger_verify','fadm_check','fadm_authorize','fadm_zookie',
              'fadm_staff_invite','fadm_enroll_issue','fadm_enroll_lookup','fadm_enroll_fail','fadm_enroll_consume','fadm_staff_register_passkey','fadm_staff_suspend','fadm_staff_leave','fadm_staff_move',
              'fadm_access_grant','fadm_access_revoke','fadm_recovery_open','fadm_recovery_approve','fadm_recovery_complete','fadm_recovery_cancel','fadm_elevation_request','fadm_elevation_decide',
              'fadm_breakglass','fadm_burst_hit','fadm_policy_set','fadm_aaguid_set',
              'fadm_alert_raise','fadm_alert_act','fadm_alert_list','fadm_probe_record','fadm_probe_prune','fadm_service_state','fadm_incident_open','fadm_incident_update_add','fadm_watch_set','fadm_bridge_services','fadm_bridge_summary')
  LOOP EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO desk_app', f.sig); END LOOP;
END $$;
ALTER FUNCTION desk.fadm_alert_after_insert() SECURITY DEFINER;

-- 12) SELFTEST: every Bridge rule against real rows, then ROLLS ITSELF BACK (SQLSTATE P0AD4 is the success exit). Any gap FAILS the whole file. -------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad3_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD3 selftest: %', msg USING ERRCODE = 'P0AD3'; END IF; END $f$;
DO $$
DECLARE o uuid; o2 uuid; l uuid; s uuid; a1 bigint; a2 bigint; a3 bigint; i uuid; sfx text := substr(md5(random()::text), 1, 8); r jsonb; n int; st text;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('department','desk'); tsup uuid := desk.fadm_unit_id('team','support');
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o1-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o2-' || sfx || '@selftest.invalid', 'Selftest Owner Two', 'owner', h) RETURNING id INTO o2;
  -- an agent with only the base relation, a lead: both set up through the AD2 doors would need passkeys, so the selftest writes active rows directly (installer rights inside the file)
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('s-' || sfx || '@selftest.invalid', 'Selftest Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO s;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('l-' || sfx || '@selftest.invalid', 'Selftest Lead', 'agent', NULL, true, 'active', true) RETURNING id INTO l;
  PERFORM desk.fadm_access_grant(o, s, sup, 'agent');
  PERFORM desk.fadm_access_grant(o, l, sup, 'lead');
  -- severity ladder and the three automatic effects of an alert row
  BEGIN INSERT INTO desk.fadm_alert (severity, kind, detail) VALUES ('urgent', 'x', '{}'); RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;
  a1 := desk.fadm_alert_raise('service', 'critical', 'service.outage', NULL, '{"service":"selftest"}', 'selftest:' || sfx);
  PERFORM pg_temp.ad3_ok(a1 IS NOT NULL AND (SELECT status FROM desk.fadm_alert_state WHERE alert_id = a1) = 'new', 'a raised alert gets a state row (new)');
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert_event WHERE alert_id = a1 AND event = 'raised') = 1, 'the first event is written');
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'alert.critical' AND (detail->>'alert')::bigint = a1) = 1, 'a critical alert leaves a ledger line');
  -- de-duplication by key
  a2 := desk.fadm_alert_raise('service', 'critical', 'service.outage', NULL, '{}', 'selftest:' || sfx);
  PERFORM pg_temp.ad3_ok(a2 = a1 AND (SELECT seen_count FROM desk.fadm_alert_state WHERE alert_id = a1) = 2, 'the same key while open counts a second sighting instead of a second alert');
  -- immutability
  BEGIN UPDATE desk.fadm_alert SET severity = 'info' WHERE id = a1; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.fadm_alert SET dedupe_key = 'other' WHERE id = a1; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_alert WHERE id = a1; RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_alert_event WHERE alert_id = a1; RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- authorisation: an agent reads but cannot acknowledge; a lead acknowledges but cannot resolve; a supervisor-level person (the owner) resolves
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert_list(s, true, 50)) >= 1, 'an agent can read the alert center');
  BEGIN PERFORM desk.fadm_alert_act(s, a1, 'ack'); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM desk.fadm_alert_act(l, a1, 'ack');
  PERFORM pg_temp.ad3_ok((SELECT status FROM desk.fadm_alert_state WHERE alert_id = a1) = 'ack' AND (SELECT acked_by FROM desk.fadm_alert WHERE id = a1) = l, 'ack moves new to ack and stamps who');
  BEGIN PERFORM desk.fadm_alert_act(l, a1, 'ack'); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- only a new alert is acknowledged
  PERFORM desk.fadm_alert_act(l, a1, 'assign', NULL, s);
  PERFORM desk.fadm_alert_act(l, a1, 'status', 'in_progress');
  PERFORM desk.fadm_alert_act(l, a1, 'note', NULL, NULL, 'looking at it');
  BEGIN PERFORM desk.fadm_alert_act(l, a1, 'status', 'resolved'); RAISE EXCEPTION 'no refusal 8' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_alert_act(l, a1, 'assign', NULL, gen_random_uuid()); RAISE EXCEPTION 'no refusal 9' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- assignee must be a real active person
  PERFORM desk.fadm_alert_act(o, a1, 'status', 'resolved');
  PERFORM pg_temp.ad3_ok((SELECT closed_at IS NOT NULL FROM desk.fadm_alert_state WHERE alert_id = a1), 'resolved closes the alert');
  BEGIN PERFORM desk.fadm_alert_act(o, a1, 'status', 'in_progress'); RAISE EXCEPTION 'no refusal 10' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;   -- resolved is final
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert_event WHERE alert_id = a1) >= 6, 'every step is in the event history');
  -- nobody closes an alert about himself
  INSERT INTO desk.fadm_alert (severity, kind, owner_id, source) VALUES ('high', 'burst.freeze', o2, 'security') RETURNING id INTO a3;
  BEGIN PERFORM desk.fadm_alert_act(o2, a3, 'status', 'resolved'); RAISE EXCEPTION 'no refusal 11' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM desk.fadm_alert_act(o, a3, 'status', 'false_positive');
  -- an AD2-style alert (inserted without source) is picked up by the trigger and defaults to security
  PERFORM pg_temp.ad3_ok((SELECT source FROM desk.fadm_alert WHERE id = a3) = 'security' AND EXISTS (SELECT 1 FROM desk.fadm_alert_state WHERE alert_id = a3), 'old-style alerts join the lifecycle');
  -- the flood cap: 300 per source+kind per 24 hours, then NULL
  FOR n IN 1..300 LOOP PERFORM desk.fadm_alert_raise('mail', 'notice', 'flood.test', NULL, '{}', NULL); END LOOP;
  PERFORM pg_temp.ad3_ok(desk.fadm_alert_raise('mail', 'notice', 'flood.test', NULL, '{}', NULL) IS NULL, 'the 301st alert of a kind in a day is not created');
  -- service state is honest: unknown, then operational, degraded, outage, recovery
  PERFORM pg_temp.ad3_ok(desk.fadm_service_state('clamav') = 'unknown', 'a service with no probe is unknown, never green');
  PERFORM pg_temp.ad3_ok(desk.fadm_probe_record('clamav', true, 40) = 'operational', 'a fast pass is operational');
  PERFORM pg_temp.ad3_ok(desk.fadm_probe_record('clamav', true, 5000) = 'degraded', 'a slow pass is degraded');
  PERFORM desk.fadm_probe_record('clamav', false, NULL, '{"err":"timeout"}'); PERFORM desk.fadm_probe_record('clamav', false);
  PERFORM pg_temp.ad3_ok(desk.fadm_probe_record('clamav', false) = 'outage', 'three failures in a row is an outage');
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert WHERE source = 'service' AND dedupe_key = 'svc:clamav' AND severity = 'critical') = 1, 'one critical alert for the outage (clamav is a critical service)');
  PERFORM desk.fadm_probe_record('clamav', false);
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert WHERE source = 'service' AND dedupe_key = 'svc:clamav') = 1, 'a longer outage does not raise a second alert');
  r := desk.fadm_bridge_summary(s);
  PERFORM pg_temp.ad3_ok((r->>'p1_open')::int >= 1 AND (r->'services'->>'clamav') = 'outage' AND (r->>'ledger_ok')::boolean, 'the command bar summary shows the P1 and the outage');
  PERFORM pg_temp.ad3_ok(desk.fadm_probe_record('clamav', true, 30) <> 'outage', 'the first pass after an outage leaves the outage');
  PERFORM pg_temp.ad3_ok((SELECT closed_at IS NOT NULL FROM desk.fadm_alert_state s2 JOIN desk.fadm_alert x ON x.id = s2.alert_id WHERE x.dedupe_key = 'svc:clamav'), 'the outage alert closes itself on recovery');
  BEGIN PERFORM desk.fadm_probe_record('nosuch', true); RAISE EXCEPTION 'no refusal 12' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN foreign_key_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_probe SET ok = true; RAISE EXCEPTION 'no refusal 13' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_probe; RAISE EXCEPTION 'no refusal 14' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad3_ok(desk.fadm_probe_prune() = 0, 'pruning keeps everything younger than 30 days');
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_bridge_services(s) WHERE service = 'clamav' AND state <> 'unknown' AND probes_24h = 7) = 1, 'the services table shows the live state and the 24 hour count');
  -- incidents: opened by a supervisor, updates append, closing is final except for the report
  BEGIN PERFORM desk.fadm_incident_open(l, 'dns', 'advisory', 'selftest'); RAISE EXCEPTION 'no refusal 15' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  i := desk.fadm_incident_open(o, 'dns', 'incident', 'DNS answers slow');
  PERFORM desk.fadm_incident_update_add(o, i, 'restoring', 'fix rolled out');
  PERFORM desk.fadm_incident_update_add(o, i, 'restored', 'all clear');
  PERFORM pg_temp.ad3_ok((SELECT closed_at IS NOT NULL FROM desk.fadm_incident WHERE id = i), 'restored closes the incident');
  BEGIN PERFORM desk.fadm_incident_update_add(o, i, 'restoring', 'again'); RAISE EXCEPTION 'no refusal 16' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM desk.fadm_incident_update_add(o, i, 'post_report_published', 'root cause: selftest');
  BEGIN PERFORM desk.fadm_incident_update_add(o, i, 'post_report_published', 'second'); RAISE EXCEPTION 'no refusal 17' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_incident_update WHERE incident_id = i; RAISE EXCEPTION 'no refusal 18' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_incident_update WHERE incident_id = i) = 4, 'the incident update feed has every step');
  -- watches feed the inbox
  PERFORM desk.fadm_watch_set(s, 'service', 'critical');
  a3 := desk.fadm_alert_raise('service', 'critical', 'service.outage', NULL, '{}', 'selftest2:' || sfx);
  PERFORM desk.fadm_alert_raise('mail', 'notice', 'inbox.test', NULL, '{}', 'x' || sfx);
  PERFORM pg_temp.ad3_ok((SELECT count(*) FROM desk.fadm_alert_list(s, true, 50, true)) = 1 AND (SELECT id FROM desk.fadm_alert_list(s, true, 50, true)) = a3, 'the inbox shows only what the watch asks for');
  -- zero-trust: a joiner and a suspended person see nothing
  BEGIN PERFORM desk.fadm_bridge_summary(gen_random_uuid()); RAISE EXCEPTION 'no refusal 19' USING ERRCODE = 'P0AD3'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- closed ledger and privileges
  PERFORM desk.fadm_audit(o, 'ad3.selftest', '{}'::jsonb);
  PERFORM pg_temp.ad3_ok(desk.fadm_ledger_verify(), 'the ledger chain still verifies');
  PERFORM pg_temp.ad3_ok(NOT has_table_privilege('desk_app', 'desk.fadm_alert_state', 'UPDATE') AND NOT has_table_privilege('desk_app', 'desk.fadm_probe', 'INSERT') AND NOT has_table_privilege('desk_app', 'desk.fadm_incident', 'INSERT')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_alert', 'DELETE'), 'desk_app has no direct write on any Bridge table');
  PERFORM pg_temp.ad3_ok(has_function_privilege('desk_app', 'desk.fadm_bridge_summary(uuid,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_burst_hit(uuid,text)', 'EXECUTE')
    AND has_function_privilege('desk_app', 'desk.fadm_session_lookup(bytea)', 'EXECUTE'), 'the doors are granted, the older doors kept their grant');
  RAISE EXCEPTION 'AD3 selftest passed, rolling back' USING ERRCODE = 'P0AD4';
EXCEPTION WHEN SQLSTATE 'P0AD4' THEN RAISE NOTICE 'AD3 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
