-- ANEXOMAIL ADMIN DESK AD1b (21 Nov 2026): the session lookup the Rust door needs BEFORE it knows who the owner is. Reads AD1 (fadm_session, fadm_owner). Desk tables only, no superuser, idempotent, one transaction.
begin;
-- Returns the owner of a LIVE session (not revoked, not expired, audience desk) from the SHA-256 of the token; nothing else. SECURITY DEFINER with a fixed search_path, executable by desk_app alone.
CREATE OR REPLACE FUNCTION desk.fadm_session_lookup(p_token_hash bytea) RETURNS TABLE (session_id uuid, owner_id uuid, email text, display_name text, role text, expires_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT s.id, o.id, o.email, o.display_name, o.role, s.expires_at
    FROM desk.fadm_session s JOIN desk.fadm_owner o ON o.id = s.owner_id
   WHERE s.token_hash = p_token_hash AND s.aud = 'desk' AND s.revoked_at IS NULL AND s.expires_at > now() AND o.active
$f$;
REVOKE ALL ON FUNCTION desk.fadm_session_lookup(bytea) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_session_lookup(bytea) TO desk_app;

-- Session create and revoke as ONE call each (fast: one round trip, no SET LOCAL, safe on a shared connection and on a transaction-mode pooler).
CREATE OR REPLACE FUNCTION desk.fadm_session_create(p_owner uuid, p_token_hash bytea, p_ttl_secs integer) RETURNS timestamptz
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE e timestamptz;
BEGIN
  IF p_ttl_secs < 60 OR p_ttl_secs > 86400 THEN RAISE EXCEPTION 'ttl out of range'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner WHERE id = p_owner AND active) THEN RAISE EXCEPTION 'no such active owner'; END IF;
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (p_owner, p_token_hash, now() + make_interval(secs => p_ttl_secs)) RETURNING expires_at INTO e;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (p_owner, 'login.ok', '{}'::jsonb);
  RETURN e;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_session_revoke(p_token_hash bytea) RETURNS void
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  UPDATE desk.fadm_session SET revoked_at = now() WHERE token_hash = p_token_hash AND revoked_at IS NULL
$f$;
REVOKE ALL ON FUNCTION desk.fadm_session_create(uuid, bytea, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_session_revoke(bytea) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_session_create(uuid, bytea, integer) TO desk_app;
GRANT EXECUTE ON FUNCTION desk.fadm_session_revoke(bytea) TO desk_app;
do $t$ begin
  if not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'desk' and p.proname = 'fadm_session_lookup' and p.prosecdef) then raise exception 'AD1b selftest: fadm_session_lookup missing or not SECURITY DEFINER'; end if;
  if has_function_privilege('public', 'desk.fadm_session_create(uuid,bytea,integer)', 'execute') or has_function_privilege('public', 'desk.fadm_session_revoke(bytea)', 'execute') then raise exception 'AD1b selftest: PUBLIC can execute a session function'; end if;
  if has_function_privilege('public', 'desk.fadm_session_lookup(bytea)', 'execute') then raise exception 'AD1b selftest: PUBLIC can execute fadm_session_lookup'; end if;
end $t$;
commit;
