-- AD28 (phase 1m-L2, ledger flood guard), 24 Nov 2026 PKT. FOUND BY THE LEDGER CARD (his 08:34 order wired it, my live look 08:51): 42,563 'dbsc.refused' lines in the last 24 hours, one every 2-3 seconds, against 1 'dbsc.refreshed': a refused device-bound refresh repeats forever and every repeat is a new ledger line. Desk database ONLY (schema desk).
-- SCHEMA-FIRST: read before writing: AD01 (desk.fadm_ledger + trigger fadm_ledger_chain, three freeze triggers), AD02 (fadm_ledger_kind + trigger fadm_ledger_00kind: closed kind list), AD08 (every desk.fadm_dbsc_* function that writes 'dbsc.refused': why replay / window_closed / key_reused / already_bound / ..., step, session), AD27 (the Ledger card that shows it).
-- ADVANCE-RESEARCH: [1m] ledger flood (24 Nov 2026): audit systems (syslog rate limiting, journald RateLimit, Falco / auditd rate limits, OWASP Logging Cheat Sheet "protect against log flooding") keep the FIRST event of a repeated identical event, count the repeats, and write ONE summary line with the repeat count when the window ends, so the evidence stays and the log cannot be used to fill the disk or bury other events; the rule is per (who, what, step, session) and applies only to notice-level repeats, never to a different event.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD28-check.sql
-- WHAT IT ADDS (nothing of AD01..AD27 is changed): desk.fadm_ledger_flood (one small state row per repeated refusal: key, last write, repeats held back; FORCE RLS, no right for desk_app) and the trigger fadm_ledger_01flood (BEFORE INSERT, after the kind check, before the hash chain): for kind 'dbsc.refused' only, an identical refusal (same actor, why, step, session) inside 60 seconds is NOT written as a new line, it is counted; the first line after the window carries "repeats": N, so nothing is lost and the count is in the ledger. Every other kind is untouched.
-- HONEST LIMITS: this stops the ledger from filling, it does not by itself stop the browser from asking again; the cause of the repeated refusal is read by scripts/desk-dbsc-look.sh (read only) and fixed as its own step.
CREATE TABLE IF NOT EXISTS desk.fadm_ledger_flood (
  k          text PRIMARY KEY CHECK (length(k) BETWEEN 3 AND 300),
  last_at    timestamptz NOT NULL DEFAULT now(),
  held       integer NOT NULL DEFAULT 0 CHECK (held >= 0)
);
ALTER TABLE desk.fadm_ledger_flood ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_ledger_flood FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_ledger_flood FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_ledger_flood' AND policyname = 'p_flood_none') THEN
    CREATE POLICY p_flood_none ON desk.fadm_ledger_flood FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;

CREATE OR REPLACE FUNCTION desk.fadm_ledger_flood_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE kk text; r record;
BEGIN
  IF NEW.kind <> 'dbsc.refused' THEN RETURN NEW; END IF;
  kk := concat_ws('|', COALESCE(NEW.actor::text, '-'), COALESCE(NEW.detail->>'why', '-'), COALESCE(NEW.detail->>'step', '-'), COALESCE(NEW.detail->>'session', '-'));
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_ledger_flood', 28));
  SELECT * INTO r FROM desk.fadm_ledger_flood WHERE k = kk;
  IF FOUND AND r.last_at > now() - interval '60 seconds' THEN
    UPDATE desk.fadm_ledger_flood SET held = held + 1 WHERE k = kk;
    RETURN NULL;                                                     -- the repeat is counted, not written
  END IF;
  IF FOUND AND r.held > 0 THEN NEW.detail := NEW.detail || jsonb_build_object('repeats', r.held); END IF;
  INSERT INTO desk.fadm_ledger_flood (k, last_at, held) VALUES (kk, now(), 0) ON CONFLICT (k) DO UPDATE SET last_at = now(), held = 0;
  DELETE FROM desk.fadm_ledger_flood WHERE k IN (SELECT k FROM desk.fadm_ledger_flood WHERE last_at < now() - interval '1 day' LIMIT 50);   -- the state stays small
  RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION desk.fadm_ledger_flood_guard() FROM PUBLIC;
DROP TRIGGER IF EXISTS fadm_ledger_01flood ON desk.fadm_ledger;
CREATE TRIGGER fadm_ledger_01flood BEFORE INSERT ON desk.fadm_ledger FOR EACH ROW EXECUTE FUNCTION desk.fadm_ledger_flood_guard();
COMMENT ON FUNCTION desk.fadm_ledger_flood_guard() IS 'AD28: identical dbsc.refused inside 60 s are counted, not written; the next line carries repeats. Other kinds untouched.';

-- SELFTEST (rolls back; success is the exception P0AR2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad28_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD28 selftest: %', msg USING ERRCODE = 'P0AR1'; END IF; END $f$;
DO $$
DECLARE s0 bigint; n0 bigint; sfx text := substr(md5(random()::text), 1, 8); i int; last_detail jsonb;
BEGIN
  SELECT count(*) INTO n0 FROM desk.fadm_ledger;
  FOR i IN 1..50 LOOP INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'dbsc.refused', jsonb_build_object('why', 'bad_challenge', 'step', 'refresh', 'session', sfx)); END LOOP;
  PERFORM pg_temp.ad28_ok((SELECT count(*) FROM desk.fadm_ledger) = n0 + 1, '50 identical refusals write exactly ONE line');
  PERFORM pg_temp.ad28_ok((SELECT held FROM desk.fadm_ledger_flood WHERE k = concat_ws('|', '-', 'bad_challenge', 'refresh', sfx)) = 49, 'the other 49 are counted');
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'dbsc.refused', jsonb_build_object('why', 'bad_signature', 'step', 'refresh', 'session', sfx));
  PERFORM pg_temp.ad28_ok((SELECT count(*) FROM desk.fadm_ledger) = n0 + 2, 'a DIFFERENT refusal is written at once');
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', '{}'::jsonb);
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', '{}'::jsonb);
  PERFORM pg_temp.ad28_ok((SELECT count(*) FROM desk.fadm_ledger) = n0 + 4, 'other kinds are never held back');
  UPDATE desk.fadm_ledger_flood SET last_at = now() - interval '61 seconds' WHERE k = concat_ws('|', '-', 'bad_challenge', 'refresh', sfx);
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'dbsc.refused', jsonb_build_object('why', 'bad_challenge', 'step', 'refresh', 'session', sfx));
  SELECT detail INTO last_detail FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 1;
  PERFORM pg_temp.ad28_ok((SELECT count(*) FROM desk.fadm_ledger) = n0 + 5 AND (last_detail->>'repeats')::int = 49, 'after the window the next line carries repeats = 49');
  PERFORM pg_temp.ad28_ok((SELECT held FROM desk.fadm_ledger_flood WHERE k = concat_ws('|', '-', 'bad_challenge', 'refresh', sfx)) = 0, 'the counter starts again');
  PERFORM pg_temp.ad28_ok(desk.fadm_ledger_verify(), 'the hash chain verifies after all of it');
  PERFORM pg_temp.ad28_ok(NOT has_table_privilege('desk_app', 'desk.fadm_ledger_flood', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger_flood', 'INSERT')
    AND NOT has_function_privilege('desk_app', 'desk.fadm_ledger_flood_guard()', 'EXECUTE') AND (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_ledger_flood'::regclass), 'the state table is forced RLS and desk_app has no right on it');
  RAISE EXCEPTION 'AD28 selftest passed, rolling back' USING ERRCODE = 'P0AR2';
EXCEPTION WHEN SQLSTATE 'P0AR2' THEN RAISE NOTICE 'AD28 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
