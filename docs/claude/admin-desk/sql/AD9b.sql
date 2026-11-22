-- ==============================================================================================================================
-- AD9b (ADMIN DESK SQL, step 9b, 23 Nov 2026 PKT): RUNBOOK CHECKLIST TICKS. Phase 1k (D5b-2). List: docs/claude/admin-desk/D5B-RUNBOOKS-LIST-23NOV.md (R8).
-- BUILT ON (SCHEMA-FIRST LAW, read in full): AD9 (fadm_runbook_version, doors pattern, fadm_runbook_frozen), AD1 (fadm_owner staff, forced RLS + p_installer pattern, fadm_ledger).
-- TECHNOLOGY: append-only tick ledger with its OWN SHA-256 hash chain (like AD4b and AD9), latest row wins (a tick can be undone by a newer row, history stays),
--   SECURITY DEFINER doors only (desk_app has no table right), forced RLS, rate limit in the database, a selftest that rolls back.
-- ADVANCE (web research 23 Nov 2026, R8): each tick records WHO, WHEN, which runbook VERSION and which company, so "step skip rate" and "which step is always unticked" can be measured later;
--   only the CURRENT version can be ticked; the step number must exist in that version; staff only; 60 ticks a minute per person is the ceiling (a script loop is refused and counted).
-- RULES: Desk tables only (fadm_*), idempotent, ONE transaction, no superuser. No customer data beyond the company reference the employee already typed on the lookup screen. No money.
-- ==============================================================================================================================
BEGIN;
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES ('ad9b.selftest','info','AD9b'),('runbook.tick_flood','notice','a person ticked checklist steps faster than the ceiling')
ON CONFLICT (kind) DO NOTHING;

CREATE TABLE IF NOT EXISTS desk.fadm_runbook_tick (
  id          bigserial PRIMARY KEY,
  version_id  bigint NOT NULL REFERENCES desk.fadm_runbook_version(id),
  company_ref text   NOT NULL CHECK (company_ref ~ '^[A-Za-z0-9_.:-]{3,64}$'),
  step        integer NOT NULL CHECK (step BETWEEN 0 AND 11),
  done        boolean NOT NULL,
  actor       uuid   NOT NULL REFERENCES desk.fadm_owner(id),
  at          timestamptz NOT NULL DEFAULT now(),
  prev_hash   bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash        bytea NOT NULL DEFAULT sha256('x'::bytea)
);
CREATE INDEX IF NOT EXISTS fadm_runbook_tick_look_i ON desk.fadm_runbook_tick (version_id, company_ref, step, id DESC);
CREATE INDEX IF NOT EXISTS fadm_runbook_tick_rate_i ON desk.fadm_runbook_tick (actor, at DESC);

CREATE OR REPLACE FUNCTION desk.fadm_runbook_tick_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_runbook_tick'));
  SELECT hash INTO p FROM desk.fadm_runbook_tick ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-tick-genesis'::bytea); END IF;
  NEW.at := now(); NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.version_id || '|' || NEW.company_ref || '|' || NEW.step || '|' || NEW.done || '|' || NEW.actor || '|' || NEW.at::text, 'UTF8'));
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_runbook_tick_chain ON desk.fadm_runbook_tick;
CREATE TRIGGER fadm_runbook_tick_chain BEFORE INSERT ON desk.fadm_runbook_tick FOR EACH ROW EXECUTE FUNCTION desk.fadm_runbook_tick_chain();
DROP TRIGGER IF EXISTS fadm_runbook_tick_frozen ON desk.fadm_runbook_tick;
CREATE TRIGGER fadm_runbook_tick_frozen BEFORE UPDATE OR DELETE ON desk.fadm_runbook_tick FOR EACH ROW EXECUTE FUNCTION desk.fadm_runbook_frozen();
DROP TRIGGER IF EXISTS fadm_runbook_tick_frozen_t ON desk.fadm_runbook_tick;
CREATE TRIGGER fadm_runbook_tick_frozen_t BEFORE TRUNCATE ON desk.fadm_runbook_tick FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_runbook_frozen();
ALTER TABLE desk.fadm_runbook_tick ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_runbook_tick FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_runbook_tick FROM PUBLIC; REVOKE ALL ON desk.fadm_runbook_tick FROM desk_app;
DO $$ BEGIN EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.fadm_runbook_tick'); EXECUTE format('CREATE POLICY p_installer ON desk.fadm_runbook_tick FOR ALL TO %I USING (true) WITH CHECK (true)', current_user); END $$;
REVOKE ALL ON SEQUENCE desk.fadm_runbook_tick_id_seq FROM PUBLIC;

-- the door: tick (done=true) or untick (done=false) one step. false = refused, never an exception text to the screen.
CREATE OR REPLACE FUNCTION desk.fadm_runbook_tick(p_owner uuid, p_version_id bigint, p_company text, p_step int, p_done boolean) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE k text; n int; recent int;
BEGIN
  IF NOT desk.fadm_runbook_staff(p_owner) THEN RETURN false; END IF;
  IF p_company IS NULL OR p_company !~ '^[A-Za-z0-9_.:-]{3,64}$' OR p_done IS NULL THEN RETURN false; END IF;
  SELECT runbook_key, jsonb_array_length(steps) INTO k, n FROM desk.fadm_runbook_version WHERE id = p_version_id; IF k IS NULL THEN RETURN false; END IF;
  IF p_version_id <> (SELECT id FROM desk.fadm_runbook_version WHERE runbook_key = k ORDER BY major DESC, minor DESC, patch DESC LIMIT 1) THEN RETURN false; END IF;   -- only the current version
  IF p_step IS NULL OR p_step < 0 OR p_step >= n THEN RETURN false; END IF;
  SELECT count(*) INTO recent FROM desk.fadm_runbook_tick WHERE actor = p_owner AND at > now() - interval '1 minute';
  IF recent >= 60 THEN INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (p_owner, 'runbook.tick_flood', jsonb_build_object('per_minute', recent)); RETURN false; END IF;
  INSERT INTO desk.fadm_runbook_tick (version_id, company_ref, step, done, actor) VALUES (p_version_id, p_company, p_step, p_done, p_owner);
  RETURN true;
END $f$;
-- the latest state of every step for one company and one runbook version, with who and when (an array, step order)
CREATE OR REPLACE FUNCTION desk.fadm_runbook_ticks(p_owner uuid, p_version_id bigint, p_company text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_runbook_staff(p_owner) OR p_company IS NULL OR p_company !~ '^[A-Za-z0-9_.:-]{3,64}$' THEN RETURN NULL; END IF;
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object('step', t.step, 'done', t.done, 'by', o.display_name, 'at', t.at) ORDER BY t.step)
    FROM (SELECT DISTINCT ON (step) * FROM desk.fadm_runbook_tick WHERE version_id = p_version_id AND company_ref = p_company ORDER BY step, id DESC) t JOIN desk.fadm_owner o ON o.id = t.actor), '[]'::jsonb);
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_runbook_tick_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record; p bytea := sha256('anexomail-desk-tick-genesis'::bytea);
BEGIN
  FOR r IN SELECT * FROM desk.fadm_runbook_tick ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.version_id || '|' || r.company_ref || '|' || r.step || '|' || r.done || '|' || r.actor || '|' || r.at::text, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;
REVOKE ALL ON FUNCTION desk.fadm_runbook_tick(uuid,bigint,text,int,boolean), desk.fadm_runbook_ticks(uuid,bigint,text), desk.fadm_runbook_tick_chain_verify(), desk.fadm_runbook_tick_chain() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_runbook_tick(uuid,bigint,text,int,boolean), desk.fadm_runbook_ticks(uuid,bigint,text), desk.fadm_runbook_tick_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AHB) ------------------------------------------------------------------------------------------------------
DO $t$
DECLARE ow uuid; ag uuid; vid bigint; old_vid bigint; r jsonb; i int; ok boolean; nx int;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('ad9b-selftest-owner@example.test','AD9b owner','owner','$argon2id$selftest') RETURNING id INTO ow;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('ad9b-selftest-agent@example.test','AD9b agent','agent',NULL,true,'active',true) RETURNING id INTO ag;
  SELECT id INTO vid FROM desk.fadm_runbook_version WHERE runbook_key = 'R1' ORDER BY major DESC, minor DESC, patch DESC LIMIT 1;
  IF vid IS NULL THEN RAISE EXCEPTION 'AD9b selftest: R1 is missing (run AD9 first)'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'TESTCO001', 0, true) IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: staff could not tick'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'TESTCO001', 1, true) IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: second tick refused'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'TESTCO001', 1, false) IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: untick refused'; END IF;
  r := desk.fadm_runbook_ticks(ow, vid, 'TESTCO001');
  IF jsonb_array_length(r) <> 2 OR (r->0->>'done')::boolean IS NOT TRUE OR (r->1->>'done')::boolean IS NOT FALSE OR r->0->>'by' <> 'AD9b agent' THEN RAISE EXCEPTION 'AD9b selftest: latest tick did not win: %', r; END IF;
  IF jsonb_array_length(desk.fadm_runbook_ticks(ow, vid, 'OTHERCO002')) <> 0 THEN RAISE EXCEPTION 'AD9b selftest: ticks leaked to another company'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'TESTCO001', 99, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: a step that does not exist was ticked'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'bad company!', 0, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: a bad company reference was accepted'; END IF;
  IF desk.fadm_runbook_tick(gen_random_uuid(), vid, 'TESTCO001', 0, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: a stranger ticked'; END IF;
  IF desk.fadm_runbook_tick(ag, -5, 'TESTCO001', 0, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: a missing version was ticked'; END IF;
  -- only the current version: add a newer one, the old one is refused
  old_vid := vid; SELECT COALESCE(max(major), 0) + 1 INTO nx FROM desk.fadm_runbook_version WHERE runbook_key = 'R1';
  vid := desk.fadm_runbook_add_version(ow,'R1',nx,0,0,(SELECT parts FROM desk.fadm_runbook_version WHERE id = old_vid),'["one","two"]'::jsonb,'I can see it clearly','AD9b selftest version');
  IF desk.fadm_runbook_tick(ag, old_vid, 'TESTCO001', 0, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: an old version was ticked'; END IF;
  IF desk.fadm_runbook_tick(ag, vid, 'TESTCO001', 1, true) IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: the new version could not be ticked'; END IF;
  -- rate ceiling
  FOR i IN 1..70 LOOP PERFORM desk.fadm_runbook_tick(ow, vid, 'FLOODCO', 0, (i % 2 = 0)); END LOOP;
  IF desk.fadm_runbook_tick(ow, vid, 'FLOODCO', 0, true) IS NOT FALSE THEN RAISE EXCEPTION 'AD9b selftest: the rate ceiling did not stop a flood'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'runbook.tick_flood') THEN RAISE EXCEPTION 'AD9b selftest: the flood was not written to the ledger'; END IF;
  -- frozen + chains
  BEGIN UPDATE desk.fadm_runbook_tick SET done = true; RAISE EXCEPTION 'AD9b selftest: a tick was edited'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_runbook_tick; RAISE EXCEPTION 'AD9b selftest: ticks deleted'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  IF desk.fadm_runbook_tick_chain_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: tick chain broken'; END IF;
  IF desk.fadm_runbook_chain_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: version chain broken'; END IF;
  IF desk.fadm_ledger_verify() IS NOT TRUE THEN RAISE EXCEPTION 'AD9b selftest: ledger chain broken'; END IF;
  RAISE EXCEPTION 'AD9b selftest passed' USING ERRCODE = 'P0AHB';
EXCEPTION WHEN SQLSTATE 'P0AHB' THEN NULL;
END $t$;
COMMIT;
