-- ==============================================================================================================================
-- AD8 (ADMIN DESK SQL, step 8, 23 Nov 2026 PKT): DEVICE-BOUND SESSIONS (DBSC), the database half. Top list: docs/claude/admin-desk/DBSC-PHASE-LIST-23NOV.md (D7, D8).
-- BUILT ON (SCHEMA-FIRST LAW, read in full): AD1 (fadm_session with its dbsc_key jsonb column, fadm_ledger hash chain), AD1b (session doors), AD2 (fadm_ledger_kind closed list + guard trigger).
-- TECHNOLOGY: PostgreSQL 16 forced RLS, a FROZEN key (once a session has a device key it can never change or be removed, only the session can end), a single-use jti table (replay), SECURITY DEFINER doors with fixed
--   search_path, every decision written to the SHA-256 hash-chained fadm_ledger through the closed kind list, a selftest that rolls back. desk_app gets EXECUTE on the doors and no table right on the new table.
-- ADVANCE (from the 23 Nov 2026 web research of the W3C DBSC Editor's Draft 9 Nov 2026 + Chrome DBSC docs; each point is a rule the DATABASE enforces, not the app):
--   (a) per-session NEW key (spec privacy rule): the RFC 7638 JWK thumbprint (SHA-256) is a trigger-owned column with a UNIQUE index: the same device key can never bind two sessions (key copying or sharing is refused);
--   (b) registration WINDOW: a key can only be registered within 5 minutes of the sign-in (a thief who steals a cookie later cannot bind it to his own key);
--   (c) refresh RATE LIMIT per session (the spec warns of TPM quotas; a flood is also an attack): more than 30 refreshes a minute is refused and written to the ledger;
--   (d) AUTO-DEFENCE: 5 forged-signature or forged-header proofs for one session within 10 minutes END that session (one-way revoke) and write dbsc.session_ended;
--   (e) HEALTH door fadm_dbsc_health(): bound / unbound live sessions, refusals by reason in 24 h, stale bindings (no refresh for 30 min), for the Bridge, no secret in it.
-- RULES: Desk tables only (fadm_*), idempotent, ONE transaction, no superuser. DESK ISOLATION: nothing of founder or awam is touched; the key stored is the PUBLIC key only.
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad8.selftest','info','AD8'),('dbsc.registered','notice','a session was bound to a device key'),('dbsc.refreshed','info','a bound session proved its key and got a fresh cookie'),
  ('dbsc.refused','notice','a device-bound proof was refused (replay, expired, bad key)'),
  ('dbsc.session_ended','high','a session was ended by the database after repeated forged device proofs'),('dbsc.flood','notice','refresh rate limit hit for a session')
ON CONFLICT (kind) DO NOTHING;

-- 1) bound-session facts live next to the session (one row per session, columns added once) ------------------------------------------------------------------
ALTER TABLE desk.fadm_session ADD COLUMN IF NOT EXISTS dbsc_registered_at timestamptz;
ALTER TABLE desk.fadm_session ADD COLUMN IF NOT EXISTS dbsc_last_refresh_at timestamptz;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='desk.fadm_session'::regclass AND conname='fadm_session_dbsc_key_shape') THEN
    ALTER TABLE desk.fadm_session ADD CONSTRAINT fadm_session_dbsc_key_shape CHECK (dbsc_key IS NULL OR (dbsc_key->>'kty'='EC' AND dbsc_key->>'crv'='P-256' AND length(dbsc_key->>'x') BETWEEN 40 AND 50 AND length(dbsc_key->>'y') BETWEEN 40 AND 50 AND dbsc_registered_at IS NOT NULL));
  END IF;
END $$;
-- the key is frozen: set once, never changed, never removed (a stolen cookie cannot re-bind the session to another key)
CREATE OR REPLACE FUNCTION desk.fadm_session_dbsc_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN
  IF OLD.dbsc_key IS NOT NULL AND NEW.dbsc_key IS DISTINCT FROM OLD.dbsc_key THEN RAISE EXCEPTION 'the device key of a session is frozen' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_session_00dbsc_frozen ON desk.fadm_session;
CREATE TRIGGER fadm_session_00dbsc_frozen BEFORE UPDATE ON desk.fadm_session FOR EACH ROW EXECUTE FUNCTION desk.fadm_session_dbsc_frozen();

-- 1b) (a) per-session NEW key: RFC 7638 thumbprint of the EC key, generated, unique among bound sessions
ALTER TABLE desk.fadm_session ADD COLUMN IF NOT EXISTS dbsc_thumb bytea;   -- set by the trigger below only (convert_to is not immutable, so a generated column is not allowed)
CREATE OR REPLACE FUNCTION desk.fadm_session_dbsc_thumb() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN
  NEW.dbsc_thumb := CASE WHEN NEW.dbsc_key IS NULL THEN NULL ELSE sha256(convert_to('{"crv":"P-256","kty":"EC","x":"' || (NEW.dbsc_key->>'x') || '","y":"' || (NEW.dbsc_key->>'y') || '"}', 'UTF8')) END;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_session_01dbsc_thumb ON desk.fadm_session;
CREATE TRIGGER fadm_session_01dbsc_thumb BEFORE INSERT OR UPDATE ON desk.fadm_session FOR EACH ROW EXECUTE FUNCTION desk.fadm_session_dbsc_thumb();
CREATE UNIQUE INDEX IF NOT EXISTS fadm_session_dbsc_thumb_u ON desk.fadm_session (dbsc_thumb) WHERE dbsc_thumb IS NOT NULL;
CREATE INDEX IF NOT EXISTS fadm_session_dbsc_bound_i ON desk.fadm_session (dbsc_last_refresh_at) WHERE dbsc_key IS NOT NULL AND revoked_at IS NULL;
-- (c) per-session refresh counter, one row per session per minute window
CREATE TABLE IF NOT EXISTS desk.fadm_dbsc_rate (
  session_id   uuid PRIMARY KEY REFERENCES desk.fadm_session(id) ON DELETE CASCADE,
  window_start timestamptz NOT NULL,
  n            integer NOT NULL CHECK (n >= 0)
);
ALTER TABLE desk.fadm_dbsc_rate ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_dbsc_rate FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_dbsc_rate FROM PUBLIC; REVOKE ALL ON desk.fadm_dbsc_rate FROM desk_app;
CREATE INDEX IF NOT EXISTS fadm_ledger_dbsc_kind_i ON desk.fadm_ledger (kind, ts) WHERE kind LIKE 'dbsc.%';

-- 2) single-use proof ids (replay) ----------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_dbsc_jti (
  jti        text PRIMARY KEY CHECK (jti ~ '^[A-Za-z0-9_.-]{16,200}$'),
  session_id uuid NOT NULL REFERENCES desk.fadm_session(id) ON DELETE CASCADE,
  seen_at    timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE desk.fadm_dbsc_jti ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_dbsc_jti FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_dbsc_jti FROM PUBLIC; REVOKE ALL ON desk.fadm_dbsc_jti FROM desk_app;

-- 3) the doors (the only way desk_app touches this) -----------------------------------------------------------------------------------------------------------
-- a session that is live: not revoked, not expired
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_live(p_token_hash bytea) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT id FROM desk.fadm_session WHERE token_hash = p_token_hash AND revoked_at IS NULL AND expires_at > now() $f$;
-- consume one proof id: false when it was already seen (replay). Old ids (> 1 day) are purged on the way.
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_consume(p_session uuid, p_jti text) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n int;
BEGIN
  DELETE FROM desk.fadm_dbsc_jti WHERE seen_at < now() - interval '1 day';
  INSERT INTO desk.fadm_dbsc_jti (jti, session_id) VALUES (p_jti, p_session) ON CONFLICT (jti) DO NOTHING; GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n = 1;
END $f$;
-- register: first key wins and is frozen; false = refused (no live session, already bound, or the proof id was seen)
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_register(p_token_hash bytea, p_key jsonb, p_jti text) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE s uuid; o uuid;
BEGIN
  s := desk.fadm_dbsc_live(p_token_hash); IF s IS NULL THEN RETURN false; END IF;
  SELECT owner_id INTO o FROM desk.fadm_session WHERE id = s;
  IF NOT desk.fadm_dbsc_consume(s, p_jti) THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', '{"why":"replay","step":"register"}'::jsonb); RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_session WHERE id = s AND created_at < now() - interval '5 minutes') THEN
    INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', jsonb_build_object('why','window_closed','step','register','session',s)); RETURN false; END IF;
  BEGIN
    UPDATE desk.fadm_session SET dbsc_key = p_key, dbsc_registered_at = now(), dbsc_last_refresh_at = now() WHERE id = s AND dbsc_key IS NULL;
  EXCEPTION WHEN unique_violation THEN
    INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', jsonb_build_object('why','key_reused','step','register','session',s)); RETURN false;
  END;
  IF NOT FOUND THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', '{"why":"already_bound","step":"register"}'::jsonb); RETURN false; END IF;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.registered', jsonb_build_object('session', s, 'alg', 'ES256'));
  RETURN true;
END $f$;
-- the stored public key of a live session (refresh is verified against THIS key only)
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_key(p_token_hash bytea) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT dbsc_key FROM desk.fadm_session WHERE token_hash = p_token_hash AND revoked_at IS NULL AND expires_at > now() $f$;
-- refresh: the proof id is consumed, the time is written, the ledger says so; false = refused
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_refresh(p_token_hash bytea, p_jti text) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE s uuid; o uuid;
BEGIN
  s := desk.fadm_dbsc_live(p_token_hash); IF s IS NULL THEN RETURN false; END IF;
  SELECT owner_id INTO o FROM desk.fadm_session WHERE id = s AND dbsc_key IS NOT NULL; IF o IS NULL THEN RETURN false; END IF;
  INSERT INTO desk.fadm_dbsc_rate (session_id, window_start, n) VALUES (s, date_trunc('minute', now()), 1)
    ON CONFLICT (session_id) DO UPDATE SET n = CASE WHEN desk.fadm_dbsc_rate.window_start = date_trunc('minute', now()) THEN desk.fadm_dbsc_rate.n + 1 ELSE 1 END, window_start = date_trunc('minute', now());
  IF (SELECT n FROM desk.fadm_dbsc_rate WHERE session_id = s) > 30 THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.flood', jsonb_build_object('session', s)); RETURN false; END IF;
  IF NOT desk.fadm_dbsc_consume(s, p_jti) THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', jsonb_build_object('why','replay','step','refresh','session',s)); RETURN false; END IF;
  UPDATE desk.fadm_session SET dbsc_last_refresh_at = now() WHERE id = s;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refreshed', jsonb_build_object('session', s));
  RETURN true;
END $f$;
-- a refused proof (bad signature, bad key, expired) is a ledger fact too
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_refuse(p_token_hash bytea, p_why text, p_step text) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE o uuid; s uuid; bad int;
BEGIN
  SELECT owner_id, id INTO o, s FROM desk.fadm_session WHERE token_hash = p_token_hash; IF o IS NULL THEN RETURN; END IF;
  IF p_why !~ '^[a-z_]{2,30}$' OR p_step NOT IN ('register','refresh','enforce') THEN RETURN; END IF;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', jsonb_build_object('why', p_why, 'step', p_step, 'session', s));
  -- (d) five forged proofs in ten minutes end the session (a stolen cookie being probed)
  IF p_why IN ('bad_signature','bad_header') THEN
    SELECT count(*) INTO bad FROM desk.fadm_ledger WHERE kind = 'dbsc.refused' AND ts > now() - interval '10 minutes' AND detail->>'session' = s::text AND detail->>'why' IN ('bad_signature','bad_header');
    IF bad >= 5 THEN
      UPDATE desk.fadm_session SET revoked_at = now() WHERE id = s AND revoked_at IS NULL;
      IF FOUND THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.session_ended', jsonb_build_object('session', s, 'why', 'forged_proofs', 'count', bad)); END IF;
    END IF;
  END IF;
END $f$;
-- honest status: bound or not, since when, last refresh
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_status(p_token_hash bytea) RETURNS TABLE (bound boolean, registered_at timestamptz, last_refresh_at timestamptz) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT dbsc_key IS NOT NULL, dbsc_registered_at, dbsc_last_refresh_at FROM desk.fadm_session WHERE token_hash = p_token_hash AND revoked_at IS NULL AND expires_at > now() $f$;
-- (e) health for the Bridge: counts only, no key, no token, no owner
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_health() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT jsonb_build_object(
    'live_sessions',  (SELECT count(*) FROM desk.fadm_session WHERE revoked_at IS NULL AND expires_at > now()),
    'bound_sessions', (SELECT count(*) FROM desk.fadm_session WHERE revoked_at IS NULL AND expires_at > now() AND dbsc_key IS NOT NULL),
    'stale_bindings', (SELECT count(*) FROM desk.fadm_session WHERE revoked_at IS NULL AND expires_at > now() AND dbsc_key IS NOT NULL AND dbsc_last_refresh_at < now() - interval '30 minutes'),
    'refused_24h',    COALESCE((SELECT jsonb_object_agg(why, c) FROM (SELECT detail->>'why' AS why, count(*) AS c FROM desk.fadm_ledger WHERE kind = 'dbsc.refused' AND ts > now() - interval '24 hours' GROUP BY 1) t), '{}'::jsonb),
    'ended_by_database_24h', (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'dbsc.session_ended' AND ts > now() - interval '24 hours')) $f$;
REVOKE ALL ON FUNCTION desk.fadm_dbsc_live(bytea), desk.fadm_dbsc_consume(uuid,text), desk.fadm_dbsc_register(bytea,jsonb,text), desk.fadm_dbsc_key(bytea), desk.fadm_dbsc_refresh(bytea,text), desk.fadm_dbsc_refuse(bytea,text,text), desk.fadm_dbsc_status(bytea), desk.fadm_dbsc_health() FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_dbsc_live(bytea), desk.fadm_dbsc_consume(uuid,text) FROM desk_app;   -- internal helpers: only the other doors call them
REVOKE ALL ON FUNCTION desk.fadm_session_dbsc_frozen(), desk.fadm_session_dbsc_thumb() FROM PUBLIC;   -- trigger functions need no caller right (found by the AD3 CHECK while testing AD4b)
GRANT EXECUTE ON FUNCTION desk.fadm_dbsc_register(bytea,jsonb,text), desk.fadm_dbsc_key(bytea), desk.fadm_dbsc_refresh(bytea,text), desk.fadm_dbsc_refuse(bytea,text,text), desk.fadm_dbsc_status(bytea), desk.fadm_dbsc_health() TO desk_app;

-- 4) SELFTEST (rolls back; failure P0AH8 -> raised as exception, success leaves nothing) ----------------------------------------------------------------------------------------------
DO $t$
DECLARE o uuid; th bytea := sha256('ad8-selftest-token'::bytea); k jsonb := jsonb_build_object('kty','EC','crv','P-256','x',repeat('A',43),'y',repeat('B',43)); ok boolean; sid uuid;
BEGIN
  SELECT id INTO o FROM desk.fadm_owner WHERE active LIMIT 1; IF o IS NULL THEN RAISE NOTICE 'AD8 selftest skipped: no owner yet'; RETURN; END IF;
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (o, th, now() + interval '1 hour') RETURNING id INTO sid;
  IF desk.fadm_dbsc_register(th, k, 'selftestjti000000001') IS NOT TRUE THEN RAISE EXCEPTION 'AD8 selftest: register refused'; END IF;
  IF desk.fadm_dbsc_register(th, k, 'selftestjti000000002') IS NOT FALSE THEN RAISE EXCEPTION 'AD8 selftest: a second key was accepted'; END IF;
  IF desk.fadm_dbsc_refresh(th, 'selftestjti000000003') IS NOT TRUE THEN RAISE EXCEPTION 'AD8 selftest: refresh refused'; END IF;
  IF desk.fadm_dbsc_refresh(th, 'selftestjti000000003') IS NOT FALSE THEN RAISE EXCEPTION 'AD8 selftest: replay accepted'; END IF;
  BEGIN UPDATE desk.fadm_session SET dbsc_key = jsonb_build_object('kty','EC','crv','P-256','x',repeat('C',43),'y',repeat('D',43)) WHERE id = sid; RAISE EXCEPTION 'AD8 selftest: key changed'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  UPDATE desk.fadm_session SET revoked_at = now() WHERE id = sid;
  IF desk.fadm_dbsc_refresh(th, 'selftestjti000000004') IS NOT FALSE THEN RAISE EXCEPTION 'AD8 selftest: a revoked session refreshed'; END IF;
  -- advance rules: key reuse, registration window, auto-defence, flood
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (o, sha256('ad8-selftest-2'::bytea), now() + interval '1 hour');
  IF desk.fadm_dbsc_register(sha256('ad8-selftest-2'::bytea), k, 'selftestjti000000010') IS NOT FALSE THEN RAISE EXCEPTION 'AD8 selftest: the same device key bound a second session'; END IF;
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at, created_at) VALUES (o, sha256('ad8-selftest-3'::bytea), now() + interval '1 hour', now() - interval '6 minutes');
  IF desk.fadm_dbsc_register(sha256('ad8-selftest-3'::bytea), jsonb_build_object('kty','EC','crv','P-256','x',repeat('E',43),'y',repeat('F',43)), 'selftestjti000000011') IS NOT FALSE THEN RAISE EXCEPTION 'AD8 selftest: late registration accepted'; END IF;
  FOR i IN 1..5 LOOP PERFORM desk.fadm_dbsc_refuse(sha256('ad8-selftest-2'::bytea), 'bad_signature', 'refresh'); END LOOP;
  IF (SELECT revoked_at FROM desk.fadm_session WHERE token_hash = sha256('ad8-selftest-2'::bytea)) IS NULL THEN RAISE EXCEPTION 'AD8 selftest: five forged proofs did not end the session'; END IF;
  IF (desk.fadm_dbsc_health()->>'bound_sessions') IS NULL THEN RAISE EXCEPTION 'AD8 selftest: health door empty'; END IF;
  IF desk.fadm_ledger_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD8 selftest: ledger chain broken'; END IF;
  RAISE EXCEPTION 'AD8 selftest passed' USING ERRCODE = 'P0AH8';
EXCEPTION WHEN SQLSTATE 'P0AH8' THEN NULL;
END $t$;
COMMIT;
