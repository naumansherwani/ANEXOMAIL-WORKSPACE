-- ==============================================================================================================================
-- AD8 (ADMIN DESK SQL, step 8, 23 Nov 2026 PKT): DEVICE-BOUND SESSIONS (DBSC), the database half. Top list: docs/claude/admin-desk/DBSC-PHASE-LIST-23NOV.md (D7, D8).
-- BUILT ON (SCHEMA-FIRST LAW, read in full): AD1 (fadm_session with its dbsc_key jsonb column, fadm_ledger hash chain), AD1b (session doors), AD2 (fadm_ledger_kind closed list + guard trigger).
-- TECHNOLOGY: PostgreSQL 16 forced RLS, a FROZEN key (once a session has a device key it can never change or be removed, only the session can end), a single-use jti table (replay), SECURITY DEFINER doors with fixed
--   search_path, every decision written to the SHA-256 hash-chained fadm_ledger through the closed kind list, a selftest that rolls back. desk_app gets EXECUTE on the doors and no table right on the new table.
-- RULES: Desk tables only (fadm_*), idempotent, ONE transaction, no superuser. DESK ISOLATION: nothing of founder or awam is touched; the key stored is the PUBLIC key only.
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad8.selftest','info','AD8'),('dbsc.registered','notice','a session was bound to a device key'),('dbsc.refreshed','info','a bound session proved its key and got a fresh cookie'),
  ('dbsc.refused','notice','a device-bound proof was refused (replay, expired, bad key)')
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
  UPDATE desk.fadm_session SET dbsc_key = p_key, dbsc_registered_at = now(), dbsc_last_refresh_at = now() WHERE id = s AND dbsc_key IS NULL;
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
  IF NOT desk.fadm_dbsc_consume(s, p_jti) THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', '{"why":"replay","step":"refresh"}'::jsonb); RETURN false; END IF;
  UPDATE desk.fadm_session SET dbsc_last_refresh_at = now() WHERE id = s;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refreshed', jsonb_build_object('session', s));
  RETURN true;
END $f$;
-- a refused proof (bad signature, bad key, expired) is a ledger fact too
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_refuse(p_token_hash bytea, p_why text, p_step text) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE o uuid;
BEGIN
  SELECT owner_id INTO o FROM desk.fadm_session WHERE token_hash = p_token_hash; IF o IS NULL THEN RETURN; END IF;
  IF p_why !~ '^[a-z_]{2,30}$' OR p_step NOT IN ('register','refresh','enforce') THEN RETURN; END IF;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'dbsc.refused', jsonb_build_object('why', p_why, 'step', p_step));
END $f$;
-- honest status: bound or not, since when, last refresh
CREATE OR REPLACE FUNCTION desk.fadm_dbsc_status(p_token_hash bytea) RETURNS TABLE (bound boolean, registered_at timestamptz, last_refresh_at timestamptz) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT dbsc_key IS NOT NULL, dbsc_registered_at, dbsc_last_refresh_at FROM desk.fadm_session WHERE token_hash = p_token_hash AND revoked_at IS NULL AND expires_at > now() $f$;
REVOKE ALL ON FUNCTION desk.fadm_dbsc_live(bytea), desk.fadm_dbsc_consume(uuid,text), desk.fadm_dbsc_register(bytea,jsonb,text), desk.fadm_dbsc_key(bytea), desk.fadm_dbsc_refresh(bytea,text), desk.fadm_dbsc_refuse(bytea,text,text), desk.fadm_dbsc_status(bytea) FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_dbsc_live(bytea), desk.fadm_dbsc_consume(uuid,text) FROM desk_app;   -- internal helpers: only the other doors call them
GRANT EXECUTE ON FUNCTION desk.fadm_dbsc_register(bytea,jsonb,text), desk.fadm_dbsc_key(bytea), desk.fadm_dbsc_refresh(bytea,text), desk.fadm_dbsc_refuse(bytea,text,text), desk.fadm_dbsc_status(bytea) TO desk_app;

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
  IF desk.fadm_ledger_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD8 selftest: ledger chain broken'; END IF;
  RAISE EXCEPTION 'AD8 selftest passed' USING ERRCODE = 'P0AH8';
EXCEPTION WHEN SQLSTATE 'P0AH8' THEN NULL;
END $t$;
COMMIT;
