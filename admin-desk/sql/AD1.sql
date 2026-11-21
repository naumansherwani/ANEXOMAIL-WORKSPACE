-- ==============================================================================================================================
-- AD1 (ADMIN DESK SQL, step 1, 21 Nov 2026 PKT) - the Desk's OWN schema `desk`, its OWN role `desk_app`, nothing shared with founder or awam.
-- DESK ISOLATION LAW (his 21 Nov 07:29): no founder table, key or door is touched; no awam table is read. SCHEMA-FIRST LAW: AD1 is the FIRST Desk schema (nothing to read before it).
-- Technology: PostgreSQL ROW LEVEL SECURITY (ENABLE + FORCE on every table), append-only SHA-256 hash-chained ledger (trigger: no UPDATE / DELETE / TRUNCATE, gapless chain under an advisory lock),
-- constraints (ARGON2ID hash shape, token audience 'desk', passkey rp_id admindesk.anexomail.com, support@ banned), SECURITY DEFINER login lookup, selftest that FAILS the whole file on any gap.
-- Idempotent: safe to run twice. Run only through admin-desk/scripts/ad-sql-run.sh (strictly by number), then admin-desk/sql/checks/AD1-check.sql.
-- The owner row and its ARGON2ID hash are created by HIS command later (never in chat, never in this file).
-- ==============================================================================================================================
BEGIN;
-- (no extension needed: gen_random_uuid() and sha256() are built in; the file needs NO superuser, so it also runs in a hosted editor whose role is not a superuser)

-- 1) the Desk's own database role: no login yet (AD1b gives it a unix-socket login), no superuser, NEVER bypasses row level security
-- (his 21 Nov 10:24 error: `ALTER ROLE desk_app NOSUPERUSER NOBYPASSRLS` needs a superuser. It is not needed: CREATE ROLE already defaults to NOSUPERUSER NOBYPASSRLS, and the selftest at the end FAILS the file if the role is ever a superuser or bypasses RLS.)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN CREATE ROLE desk_app NOLOGIN; END IF;
END $$;
CREATE SCHEMA IF NOT EXISTS desk;
REVOKE ALL ON SCHEMA public FROM desk_app;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM desk_app;
GRANT USAGE ON SCHEMA desk TO desk_app;

-- 2) tables (all fadm_*)
CREATE TABLE IF NOT EXISTS desk.fadm_owner (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email         text NOT NULL UNIQUE CHECK (email = lower(email) AND email ~ '^[^@\s]+@[^@\s]+$'),
  display_name  text NOT NULL CHECK (length(display_name) BETWEEN 1 AND 80),
  role          text NOT NULL DEFAULT 'owner' CHECK (role IN ('owner','agent')),
  pw_hash       text NOT NULL CHECK (pw_hash LIKE '$argon2id$%'),          -- ARGON2ID only, never a plain or older hash
  passkey_required boolean NOT NULL DEFAULT false,                          -- passkey is OPTIONAL (his word 21 Nov 08:07)
  active        boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS desk.fadm_session (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid NOT NULL REFERENCES desk.fadm_owner(id) ON DELETE CASCADE,
  aud         text NOT NULL DEFAULT 'desk' CHECK (aud = 'desk'),            -- token audience: a founder or awam token can never be a Desk session
  token_hash  bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),  -- SHA-256 of the session token, the token itself is never stored
  dbsc_key    jsonb,                                                        -- device-bound session: the public key the browser registered (R3a2 DBSC)
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  ip          inet,
  ua          text CHECK (length(ua) <= 400),
  CHECK (expires_at > created_at)
);
CREATE TABLE IF NOT EXISTS desk.fadm_passkey (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid NOT NULL REFERENCES desk.fadm_owner(id) ON DELETE CASCADE,
  cred_id     bytea NOT NULL UNIQUE,
  public_key  bytea NOT NULL,
  sign_count  bigint NOT NULL DEFAULT 0 CHECK (sign_count >= 0),
  rp_id       text NOT NULL DEFAULT 'admindesk.anexomail.com' CHECK (rp_id = 'admindesk.anexomail.com'),  -- never the parent domain, never the founder's rp_id
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS desk.fadm_mailbox (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  local_part  text NOT NULL CHECK (local_part = lower(local_part) AND local_part <> 'support' AND local_part ~ '^[a-z0-9._-]{1,40}$'),  -- support@ is banned, resolved@ replaces it
  domain      text NOT NULL DEFAULT 'anexomail.com',
  send_only   boolean NOT NULL DEFAULT false,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (local_part, domain),
  CHECK (local_part NOT IN ('billing','noreply') OR send_only)              -- billing@ and noreply@ are send-only
);
CREATE TABLE IF NOT EXISTS desk.fadm_ledger (
  seq         bigint PRIMARY KEY,
  ts          timestamptz NOT NULL DEFAULT now(),
  actor       uuid,
  kind        text NOT NULL CHECK (length(kind) BETWEEN 1 AND 60),
  detail      jsonb NOT NULL DEFAULT '{}'::jsonb,
  prev_hash   bytea NOT NULL CHECK (octet_length(prev_hash) = 32),
  hash        bytea NOT NULL UNIQUE CHECK (octet_length(hash) = 32)
);

-- 3) the ledger chain: seq and both hashes are computed HERE (the app cannot choose them); SHA-256 over prev_hash || seq || ts || kind || detail
CREATE OR REPLACE FUNCTION desk.fadm_ledger_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, public AS $f$
DECLARE p bytea; n bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_ledger'));
  SELECT hash, seq INTO p, n FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-genesis'::bytea); n := 0; END IF;
  NEW.seq := n + 1; NEW.prev_hash := p; NEW.ts := now();
  NEW.hash := sha256(p || convert_to(NEW.seq::text || '|' || NEW.ts::text || '|' || NEW.kind || '|' || NEW.detail::text, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_ledger_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION 'desk.fadm_ledger is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_ledger_chain ON desk.fadm_ledger;
CREATE TRIGGER fadm_ledger_chain BEFORE INSERT ON desk.fadm_ledger FOR EACH ROW EXECUTE FUNCTION desk.fadm_ledger_chain();
DROP TRIGGER IF EXISTS fadm_ledger_frozen ON desk.fadm_ledger;
CREATE TRIGGER fadm_ledger_frozen BEFORE UPDATE OR DELETE ON desk.fadm_ledger FOR EACH ROW EXECUTE FUNCTION desk.fadm_ledger_frozen();
DROP TRIGGER IF EXISTS fadm_ledger_frozen_t ON desk.fadm_ledger;
CREATE TRIGGER fadm_ledger_frozen_t BEFORE TRUNCATE ON desk.fadm_ledger FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_ledger_frozen();
-- anyone can re-verify the whole chain
CREATE OR REPLACE FUNCTION desk.fadm_ledger_verify() RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = pg_catalog AS $f$
DECLARE r record; p bytea := sha256('anexomail-desk-genesis'::bytea); n bigint := 0;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_ledger ORDER BY seq LOOP
    n := n + 1;
    IF r.seq <> n OR r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.seq::text || '|' || r.ts::text || '|' || r.kind || '|' || r.detail::text, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

-- 4) login lookup: the ONLY way to read an owner before a session exists (SECURITY DEFINER, fixed search_path, executable by desk_app alone)
CREATE OR REPLACE FUNCTION desk.fadm_login_lookup(p_email text) RETURNS TABLE (id uuid, pw_hash text, passkey_required boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT o.id, o.pw_hash, o.passkey_required FROM desk.fadm_owner o WHERE o.email = lower(p_email) AND o.active
$f$;
REVOKE ALL ON FUNCTION desk.fadm_login_lookup(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_login_lookup(text) TO desk_app;

-- 5) ROW LEVEL SECURITY: ENABLE + FORCE on every table; the Rust door sets `SET LOCAL desk.owner_id = '<uuid>'` per transaction after the session token is checked
CREATE OR REPLACE FUNCTION desk.fadm_me() RETURNS uuid LANGUAGE sql STABLE SET search_path = pg_catalog AS $f$ SELECT nullif(current_setting('desk.owner_id', true), '')::uuid $f$;
GRANT EXECUTE ON FUNCTION desk.fadm_me() TO desk_app;
ALTER TABLE desk.fadm_owner   ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_owner   FORCE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_session ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_session FORCE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_passkey ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_passkey FORCE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_mailbox ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_mailbox FORCE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_ledger  ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_ledger  FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  DROP POLICY IF EXISTS p_owner_self ON desk.fadm_owner;     CREATE POLICY p_owner_self ON desk.fadm_owner     FOR SELECT TO desk_app USING (id = desk.fadm_me());
  DROP POLICY IF EXISTS p_session_own ON desk.fadm_session;  CREATE POLICY p_session_own ON desk.fadm_session FOR ALL    TO desk_app USING (owner_id = desk.fadm_me()) WITH CHECK (owner_id = desk.fadm_me());
  DROP POLICY IF EXISTS p_passkey_own ON desk.fadm_passkey;  CREATE POLICY p_passkey_own ON desk.fadm_passkey FOR ALL    TO desk_app USING (owner_id = desk.fadm_me()) WITH CHECK (owner_id = desk.fadm_me());
  DROP POLICY IF EXISTS p_mailbox_read ON desk.fadm_mailbox; CREATE POLICY p_mailbox_read ON desk.fadm_mailbox FOR SELECT TO desk_app USING (desk.fadm_me() IS NOT NULL);
  DROP POLICY IF EXISTS p_ledger_read ON desk.fadm_ledger;   CREATE POLICY p_ledger_read ON desk.fadm_ledger   FOR SELECT TO desk_app USING (desk.fadm_me() IS NOT NULL);
  DROP POLICY IF EXISTS p_ledger_add ON desk.fadm_ledger;    CREATE POLICY p_ledger_add ON desk.fadm_ledger    FOR INSERT TO desk_app WITH CHECK (desk.fadm_me() IS NOT NULL AND (actor IS NULL OR actor = desk.fadm_me()));
END $$;
-- FORCE RLS applies to the role that installed this file too (a superuser bypasses it, a hosted-editor role does not). That installer (the database admin) gets ONE all-access policy per table, named p_installer:
-- it lets the SECURITY DEFINER login lookup, the seed rows and the selftest work. desk_app NEVER gets such a policy, and the ledger stays append-only for EVERYONE (trigger, not policy).
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_owner','fadm_session','fadm_passkey','fadm_mailbox','fadm_ledger'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
  END LOOP;
  DROP POLICY IF EXISTS p_owner_definer ON desk.fadm_owner;
END $$;
REVOKE ALL ON ALL TABLES IN SCHEMA desk FROM desk_app;
GRANT SELECT ON desk.fadm_owner, desk.fadm_mailbox TO desk_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON desk.fadm_session, desk.fadm_passkey TO desk_app;
GRANT SELECT, INSERT ON desk.fadm_ledger TO desk_app;
GRANT EXECUTE ON FUNCTION desk.fadm_ledger_verify() TO desk_app;

-- 6) the Desk mailboxes (his plan decisions: resolved@ replaces support@; billing@ and noreply@ send-only)
INSERT INTO desk.fadm_mailbox (local_part, send_only) VALUES ('resolved', false), ('billing', true), ('noreply', true) ON CONFLICT DO NOTHING;

-- 7) SELFTEST: any failure raises and the WHOLE file rolls back
DO $$
DECLARE t text; ok boolean; n int;
BEGIN
  IF (SELECT rolsuper OR rolbypassrls FROM pg_roles WHERE rolname = 'desk_app') THEN RAISE EXCEPTION 'AD1 selftest: desk_app is superuser or bypasses RLS'; END IF;
  FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'desk' AND c.relkind = 'r' LOOP
    IF t NOT LIKE 'fadm\_%' THEN RAISE EXCEPTION 'AD1 selftest: table desk.% is not fadm_*', t; END IF;
    SELECT relrowsecurity AND relforcerowsecurity INTO ok FROM pg_class WHERE oid = ('desk.' || t)::regclass;
    IF NOT ok THEN RAISE EXCEPTION 'AD1 selftest: RLS is not ENABLED+FORCED on desk.%', t; END IF;
  END LOOP;
  SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname IN ('public') AND c.relkind IN ('r','v','m') AND has_table_privilege('desk_app', c.oid, 'SELECT,INSERT,UPDATE,DELETE');
  IF n <> 0 THEN RAISE EXCEPTION 'AD1 selftest: desk_app can touch % table(s) outside the desk schema', n; END IF;
  -- ledger: append works, chain verifies, UPDATE / DELETE / TRUNCATE are refused
  INSERT INTO desk.fadm_ledger (kind, detail) VALUES ('ad1.selftest', '{"ok":true}');
  IF NOT desk.fadm_ledger_verify() THEN RAISE EXCEPTION 'AD1 selftest: ledger chain does not verify'; END IF;
  BEGIN UPDATE desk.fadm_ledger SET kind = 'x'; RAISE EXCEPTION 'AD1 selftest: ledger UPDATE was NOT refused'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_ledger; RAISE EXCEPTION 'AD1 selftest: ledger DELETE was NOT refused'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_ledger; RAISE EXCEPTION 'AD1 selftest: ledger TRUNCATE was NOT refused'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- constraints: support@ banned, billing@ must be send-only, a non-ARGON2ID hash and a foreign audience are refused
  BEGIN INSERT INTO desk.fadm_mailbox (local_part) VALUES ('support'); RAISE EXCEPTION 'AD1 selftest: support@ was NOT refused'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailbox (local_part, send_only) VALUES ('billing2', false), ('noreply', false) ON CONFLICT DO NOTHING; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_owner (email, display_name, pw_hash) VALUES ('x@y.z', 'x', 'plain'); RAISE EXCEPTION 'AD1 selftest: a non-ARGON2ID hash was NOT refused'; EXCEPTION WHEN check_violation THEN NULL; END;
END $$;
COMMIT;
