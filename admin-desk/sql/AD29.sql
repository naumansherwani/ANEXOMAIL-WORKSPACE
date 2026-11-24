-- AD29 (phase 1m-L3, ledger check that scales), 24 Nov 2026 PKT. FOUND BY THE LEDGER CARD + his dashboard (09:0x): the 'ledger' probe walks the WHOLE chain every 60 seconds (desk.fadm_ledger_verify), the ledger grew to 44,000 lines, so the probe is slow and the Systems page keeps saying "Audit trail" is degraded. Desk database ONLY (schema desk). FUTURE-PROOF: built for a ledger of millions of lines, once.
-- SCHEMA-FIRST: read before writing: AD01 (desk.fadm_ledger: seq, ts, kind, detail, prev_hash, hash; fadm_ledger_verify walks from the genesis hash; freeze triggers), AD03 (desk.fadm_service 'ledger' row, desk.fadm_probe), AD27 (fadm_ledger_window_ok, the Ledger card), AD28 (ledger flood guard).
-- ADVANCE-RESEARCH: [1m] scalable tamper-evident verification (24 Nov 2026): Certificate Transparency and Trillian / Sigstore Rekor keep SIGNED CHECKPOINTS (tree size + root hash) so a monitor only verifies the part of the log added since its last checkpoint and re-checks the whole log on a slower schedule; Merkle Tree Ladder / incremental-audit literature (Crosby-Wallach) says the same: verification cost must follow the NEW entries, not the total. This file does exactly that on a hash chain: an append-only anchor (sequence + hash of the last verified line), each run verifies only the lines after the newest anchor and checks the anchor still equals the stored line, and the whole chain from the genesis is re-walked at least once every 24 hours.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD29-check.sql
-- WHAT IT ADDS (nothing of AD01..AD28 is changed): desk.fadm_ledger_anchor (append-only: seq, hash, at, how = 'full' or 'incremental'; FORCE RLS, deny-all, three freeze triggers) and desk.fadm_ledger_verify_fast() = true only when (1) the newest anchor still equals the stored line at its sequence, (2) every line after it links to the one before and hashes correctly, and (3) a full walk from the genesis ran within the last 24 hours (it runs it itself when due). On success a new anchor is written. Any failure returns false and writes no anchor, so a broken ledger can never be "anchored". The probe now calls this function.
-- HONEST LIMITS: a line altered BEFORE the newest anchor is caught by the daily full walk (and by the outside audit copy), not by every incremental run; the card says so in words.
CREATE TABLE IF NOT EXISTS desk.fadm_ledger_anchor (
  id    bigserial PRIMARY KEY,
  seq   bigint NOT NULL CHECK (seq >= 0),
  hash  bytea NOT NULL CHECK (octet_length(hash) = 32),
  at    timestamptz NOT NULL DEFAULT now(),
  how   text NOT NULL CHECK (how IN ('full', 'incremental'))
);
CREATE INDEX IF NOT EXISTS fadm_ledger_anchor_at ON desk.fadm_ledger_anchor (how, at DESC);
ALTER TABLE desk.fadm_ledger_anchor ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.fadm_ledger_anchor FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.fadm_ledger_anchor FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_ledger_anchor' AND policyname = 'p_anchor_none') THEN
    CREATE POLICY p_anchor_none ON desk.fadm_ledger_anchor FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;
CREATE OR REPLACE FUNCTION desk.fadm_ledger_anchor_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION 'desk.fadm_ledger_anchor is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_ledger_anchor_frozen ON desk.fadm_ledger_anchor;
CREATE TRIGGER fadm_ledger_anchor_frozen BEFORE UPDATE OR DELETE ON desk.fadm_ledger_anchor FOR EACH ROW EXECUTE FUNCTION desk.fadm_ledger_anchor_frozen();
DROP TRIGGER IF EXISTS fadm_ledger_anchor_frozen_t ON desk.fadm_ledger_anchor;
CREATE TRIGGER fadm_ledger_anchor_frozen_t BEFORE TRUNCATE ON desk.fadm_ledger_anchor FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_ledger_anchor_frozen();

CREATE OR REPLACE FUNCTION desk.fadm_ledger_verify_fast() RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '30s' SET lock_timeout = '2s' AS $f$
DECLARE a record; r record; p bytea; head record; full_due boolean;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('desk.fadm_ledger_verify_fast', 29));
  SELECT seq, hash INTO head FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 1;
  IF head.seq IS NULL THEN RETURN true; END IF;
  SELECT * INTO a FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1;
  full_due := a.id IS NULL OR NOT EXISTS (SELECT 1 FROM desk.fadm_ledger_anchor WHERE how = 'full' AND at > now() - interval '24 hours');
  IF full_due THEN
    IF NOT desk.fadm_ledger_verify() THEN RETURN false; END IF;
    INSERT INTO desk.fadm_ledger_anchor (seq, hash, how) VALUES (head.seq, head.hash, 'full');
    RETURN true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l WHERE l.seq = a.seq AND l.hash = a.hash AND l.hash = sha256(l.prev_hash || convert_to(l.seq::text || '|' || l.ts::text || '|' || l.kind || '|' || l.detail::text, 'UTF8'))) THEN RETURN false; END IF;     -- the anchored line was changed, removed or its content no longer matches its hash
  p := a.hash;
  FOR r IN SELECT * FROM desk.fadm_ledger WHERE seq > a.seq ORDER BY seq LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.seq::text || '|' || r.ts::text || '|' || r.kind || '|' || r.detail::text, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  IF head.seq > a.seq THEN INSERT INTO desk.fadm_ledger_anchor (seq, hash, how) VALUES (head.seq, head.hash, 'incremental'); END IF;
  RETURN true;
END $f$;
COMMENT ON FUNCTION desk.fadm_ledger_verify_fast() IS 'AD29: verify only the lines after the newest anchor, full walk from the genesis at least every 24 hours, an anchor is written only after a pass.';
REVOKE ALL ON FUNCTION desk.fadm_ledger_verify_fast() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_ledger_verify_fast() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AS2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad29_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD29 selftest: %', msg USING ERRCODE = 'P0AS1'; END IF; END $f$;
DO $$
DECLARE n0 bigint; a0 bigint; h0 bigint; i int; s1 bigint;
BEGIN
  PERFORM pg_temp.ad29_ok(desk.fadm_ledger_verify_fast(), 'a healthy ledger passes (the first run is a full walk)');
  SELECT count(*) INTO a0 FROM desk.fadm_ledger_anchor;
  PERFORM pg_temp.ad29_ok((SELECT how FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1) = 'full' AND (SELECT seq FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1) = (SELECT max(seq) FROM desk.fadm_ledger), 'a full anchor sits on the newest line');
  FOR i IN 1..30 LOOP INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', jsonb_build_object('i', i)); END LOOP;
  PERFORM pg_temp.ad29_ok(desk.fadm_ledger_verify_fast(), 'new lines pass incrementally');
  PERFORM pg_temp.ad29_ok((SELECT how FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1) = 'incremental' AND (SELECT count(*) FROM desk.fadm_ledger_anchor) = a0 + 1, 'the incremental run wrote ONE new anchor');
  PERFORM pg_temp.ad29_ok(desk.fadm_ledger_verify_fast() AND (SELECT count(*) FROM desk.fadm_ledger_anchor) = a0 + 1, 'with nothing new no anchor is written');
  -- tamper 1: a line AFTER the anchor is edited (triggers switched off inside this rolled-back test)
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', '{"x":1}'::jsonb);
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', '{"x":2}'::jsonb);
  SELECT max(seq) INTO s1 FROM desk.fadm_ledger;
  ALTER TABLE desk.fadm_ledger DISABLE TRIGGER fadm_ledger_frozen;
  UPDATE desk.fadm_ledger SET kind = 'ad1.selftest' WHERE seq = s1 - 1;
  PERFORM pg_temp.ad29_ok(NOT desk.fadm_ledger_verify_fast(), 'an edited line after the anchor is caught');
  PERFORM pg_temp.ad29_ok((SELECT count(*) FROM desk.fadm_ledger_anchor) = a0 + 1, 'a broken ledger is never anchored');
  UPDATE desk.fadm_ledger SET kind = 'package.publish' WHERE seq = s1 - 1;
  -- tamper 2: the ANCHORED line itself is edited
  PERFORM pg_temp.ad29_ok(desk.fadm_ledger_verify_fast(), 'repaired, it passes again');
  UPDATE desk.fadm_ledger SET kind = 'ad1.selftest' WHERE seq = (SELECT seq FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1);
  PERFORM pg_temp.ad29_ok(NOT desk.fadm_ledger_verify_fast(), 'an edited anchored line is caught');
  ALTER TABLE desk.fadm_ledger ENABLE TRIGGER fadm_ledger_frozen;
  -- the anchor table is append-only and closed
  BEGIN UPDATE desk.fadm_ledger_anchor SET seq = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_ledger_anchor; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_ledger_anchor; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AS1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM pg_temp.ad29_ok(has_function_privilege('desk_app', 'desk.fadm_ledger_verify_fast()', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_ledger_verify_fast()', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger_anchor', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger_anchor', 'INSERT')
    AND (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_ledger_anchor'::regclass), 'desk_app can run the check only; the anchor table is forced RLS and closed to it');
  RAISE EXCEPTION 'AD29 selftest passed, rolling back' USING ERRCODE = 'P0AS2';
EXCEPTION WHEN SQLSTATE 'P0AS2' THEN RAISE NOTICE 'AD29 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
