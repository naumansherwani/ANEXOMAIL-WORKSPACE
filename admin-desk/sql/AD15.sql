-- AD15 (phase 1m-5, card B6 Deliverability), 23 Nov 2026 08:5x PKT.
-- SCHEMA-FIRST: AD01 (fadm_owner, fadm_ledger + chain), AD02 (fadm_authorize, fadm_need, fadm_audit, fadm_unit_id, action customer.lookup), AD04 (the plan lookup right), AD13 + AD14 (the hourly hash-chained series pattern: advisory lock, frozen triggers, BRIN, chain verify), CP3 cp.deliverability (the shape this file stores).
-- ADVANCE-RESEARCH: [1m] hourly append-only SHA-256 chained deliverability series so the card shows a real line from day one, door with the SAME right as the plan lookup, one throttled ledger line per ten minutes, forced RLS, REVOKE PUBLIC, selftest that rolls back (list D6-CARDS-LIST-23NOV.md section B6 U7, U8).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD15-check.sql
-- WHAT IT ADDS:
--   1. fadm_deliv_sample: APPEND-ONLY HOURLY series of the deliverability totals (own SHA-256 chain gapless under an advisory lock, forced RLS, frozen triggers, BRIN, one row per hour). desk_app has no right on it.
--   2. fadm_deliv_begin(actor): the first half of the door. Only a person who may open a customer (customer.lookup on the Desk department) gets an answer ('{}'), everyone else NULL. It writes ONE ledger line (kind lookup.company, company "(deliverability)") at most every ten minutes per person.
--   3. fadm_deliv_record(actor, d): the second half. Re-checks the right, validates the signed answer the Desk already verified (non-negative, verified + pending = domains, fully authenticated <= verified, failing companies <= companies), writes this hour once, returns the 24-hour line (fully authenticated domains) and a trend word.
--   4. fadm_deliv_chain_verify().
-- No domain name, no company id, no person: counts only. Every helper is REVOKEd from PUBLIC. desk_app gets the two doors and the verify, never a table, never the writer.

CREATE TABLE IF NOT EXISTS desk.fadm_deliv_sample (
  id          bigserial PRIMARY KEY,
  bucket      timestamptz NOT NULL UNIQUE CHECK (bucket = date_trunc('hour', bucket)),
  domains_n   int NOT NULL CHECK (domains_n >= 0),
  companies_n int NOT NULL CHECK (companies_n >= 0),
  verified_n  int NOT NULL CHECK (verified_n >= 0),
  pending_n   int NOT NULL CHECK (pending_n >= 0),
  all_ok_n    int NOT NULL CHECK (all_ok_n >= 0),
  failing_n   int NOT NULL CHECK (failing_n >= 0),
  prev_hash   bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash        bytea NOT NULL DEFAULT sha256('x'::bytea),
  CHECK (verified_n + pending_n = domains_n AND all_ok_n <= verified_n AND failing_n <= companies_n)
);
CREATE INDEX IF NOT EXISTS fadm_deliv_sample_brin ON desk.fadm_deliv_sample USING brin (bucket);
CREATE OR REPLACE FUNCTION desk.fadm_deliv_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_deliv_sample'));
  SELECT hash INTO p FROM desk.fadm_deliv_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-deliv-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || NEW.domains_n || '|' || NEW.companies_n || '|' || NEW.verified_n || '|' || NEW.pending_n || '|' || NEW.all_ok_n || '|' || NEW.failing_n, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_deliv_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_deliv_sample_chain ON desk.fadm_deliv_sample;
CREATE TRIGGER fadm_deliv_sample_chain BEFORE INSERT ON desk.fadm_deliv_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_deliv_sample_chain();
DROP TRIGGER IF EXISTS fadm_deliv_sample_frozen ON desk.fadm_deliv_sample;
CREATE TRIGGER fadm_deliv_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_deliv_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_deliv_sample_frozen();
DROP TRIGGER IF EXISTS fadm_deliv_sample_frozen_t ON desk.fadm_deliv_sample;
CREATE TRIGGER fadm_deliv_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_deliv_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_deliv_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_deliv_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_deliv_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_deliv_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_deliv_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_deliv_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_deliv_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_deliv_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_deliv_sample_chain(), desk.fadm_deliv_sample_frozen() FROM PUBLIC;

-- the right: the SAME as the plan lookup (customer.lookup on the Desk department)
CREATE OR REPLACE FUNCTION desk.fadm_deliv_allowed(p_actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'customer.lookup', desk.fadm_unit_id('department','desk'), NULL)), false)
$f$;

-- 2) first half of the door: right check and ONE throttled ledger line
CREATE OR REPLACE FUNCTION desk.fadm_deliv_begin(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_deliv_allowed(p_actor) THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE actor = p_actor AND kind = 'lookup.company' AND detail->>'company' = '(deliverability)' AND ts > now() - interval '10 minutes') THEN
    PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', '(deliverability)', 'reason', 'deliverability board opened', 'fields', '[]'::jsonb));
  END IF;
  RETURN '{}'::jsonb;
END $f$;

-- 3) second half: validate the answer the Desk already verified, write this hour once, answer the 24-hour line
CREATE OR REPLACE FUNCTION desk.fadm_deliv_record(p_actor uuid, p_d jsonb) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE hb timestamptz := date_trunc('hour', now()); n int[]; sp jsonb; cur int; prv int; tr text;
BEGIN
  IF NOT desk.fadm_deliv_allowed(p_actor) THEN RETURN NULL; END IF;
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' THEN RAISE EXCEPTION 'AD15: the answer is not an object' USING ERRCODE = 'check_violation'; END IF;
  n := ARRAY[(p_d->>'domains')::int, (p_d->>'companies')::int, (p_d->'status'->>'verified')::int, (p_d->'status'->>'pending')::int, (p_d->'posture'->>'all_ok')::int, (p_d->>'companies_failing')::int];
  IF EXISTS (SELECT 1 FROM unnest(n) x WHERE x IS NULL OR x < 0) OR n[3] + n[4] <> n[1] OR n[5] > n[3] OR n[6] > n[2] THEN RAISE EXCEPTION 'AD15: the answer is not a valid count set (missing, negative, verified + pending <> domains, or a part above its whole)' USING ERRCODE = 'check_violation'; END IF;
  IF pg_try_advisory_xact_lock(hashtext('desk.fadm_deliv_sample.take')) AND NOT EXISTS (SELECT 1 FROM desk.fadm_deliv_sample WHERE bucket = hb) THEN
    INSERT INTO desk.fadm_deliv_sample (bucket, domains_n, companies_n, verified_n, pending_n, all_ok_n, failing_n) VALUES (hb, n[1], n[2], n[3], n[4], n[5], n[6]);
  END IF;
  SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.all_ok_n FROM desk.fadm_deliv_sample s WHERE s.bucket = hb - make_interval(hours => 23 - g)) AS v FROM generate_series(0, 23) g) z;
  cur := n[5];
  SELECT s.all_ok_n INTO prv FROM desk.fadm_deliv_sample s WHERE s.bucket BETWEEN hb - interval '25 hours' AND hb - interval '23 hours' ORDER BY abs(extract(epoch FROM s.bucket - (hb - interval '24 hours'))) LIMIT 1;
  tr := CASE WHEN prv IS NULL THEN 'unknown' WHEN cur > prv THEN 'up' WHEN cur < prv THEN 'down' ELSE 'steady' END;
  RETURN jsonb_build_object('spark', sp, 'trend', tr);
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_deliv_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea := sha256('anexomail-desk-deliv-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_deliv_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || r.domains_n || '|' || r.companies_n || '|' || r.verified_n || '|' || r.pending_n || '|' || r.all_ok_n || '|' || r.failing_n, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_deliv_allowed(uuid), desk.fadm_deliv_begin(uuid), desk.fadm_deliv_record(uuid, jsonb), desk.fadm_deliv_chain_verify() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_deliv_begin(uuid), desk.fadm_deliv_record(uuid, jsonb), desk.fadm_deliv_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AO2). It runs on the LIVE database too, so it only tests DELTAS and its own synthetic rows.
CREATE FUNCTION pg_temp.ad15_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD15 selftest: %', msg USING ERRCODE = 'P0AO1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
  d jsonb; r jsonb; r2 jsonb; b0 timestamptz := date_trunc('hour', now()); led0 bigint; led1 bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o15-' || sfx || '@selftest.invalid', 'AD15 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a15-' || sfx || '@selftest.invalid', 'AD15 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  PERFORM pg_temp.ad15_ok(desk.fadm_deliv_begin(a1) IS NULL AND desk.fadm_deliv_begin(gen_random_uuid()) IS NULL, 'a person without the lookup right and an unknown person get NULL');
  SELECT count(*) INTO led0 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(deliverability)';
  r := desk.fadm_deliv_begin(o);
  PERFORM pg_temp.ad15_ok(r = '{}'::jsonb, 'an owner gets the empty input object');
  PERFORM desk.fadm_deliv_begin(o);
  SELECT count(*) INTO led1 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(deliverability)';
  PERFORM pg_temp.ad15_ok(led1 - led0 = 1, 'two openings inside ten minutes write ONE ledger line');
  d := jsonb_build_object('domains', 5, 'companies', 3, 'status', jsonb_build_object('verified', 4, 'pending', 1), 'posture', jsonb_build_object('all_ok', 2), 'companies_failing', 2);
  PERFORM pg_temp.ad15_ok(desk.fadm_deliv_record(a1, d) IS NULL AND desk.fadm_deliv_record(gen_random_uuid(), d) IS NULL, 'record: a person without the right and an unknown person get NULL');
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_deliv_sample WHERE bucket = b0) THEN
    r2 := desk.fadm_deliv_record(o, d);
    PERFORM pg_temp.ad15_ok(r2 IS NOT NULL AND jsonb_array_length(r2->'spark') = 24 AND r2->>'trend' IN ('up','steady','down','unknown') AND (r2->'spark'->23)::int = 2, 'the owner gets a 24-point line whose last point is this hour (2) and a trend word');
    PERFORM pg_temp.ad15_ok((SELECT count(*) FROM desk.fadm_deliv_sample WHERE bucket = b0) = 1 AND (SELECT all_ok_n FROM desk.fadm_deliv_sample WHERE bucket = b0) = 2, 'this hour holds exactly ONE row and the first value stays');
  END IF;
  BEGIN PERFORM desk.fadm_deliv_record(o, jsonb_set(d, '{status,pending}', '3')); RAISE EXCEPTION 'no refusal 0' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_deliv_record(o, jsonb_set(d, '{posture,all_ok}', '9')); RAISE EXCEPTION 'no refusal 00' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_deliv_record(o, '{"domains": -1}'::jsonb); RAISE EXCEPTION 'no refusal 000' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_deliv_sample SET domains_n = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_deliv_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_deliv_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_deliv_sample (bucket, domains_n, companies_n, verified_n, pending_n, all_ok_n, failing_n) VALUES (b0 - interval '90 minutes', 1, 1, 1, 0, 0, 0); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_deliv_sample (bucket, domains_n, companies_n, verified_n, pending_n, all_ok_n, failing_n) VALUES (b0 - interval '3 hours', 2, 1, 1, 0, 0, 0); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AO1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad15_ok(desk.fadm_deliv_chain_verify(), 'the deliverability series chain verifies');
  PERFORM pg_temp.ad15_ok(has_function_privilege('desk_app', 'desk.fadm_deliv_begin(uuid)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_deliv_record(uuid,jsonb)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_deliv_allowed(uuid)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_deliv_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_deliv_sample', 'INSERT'), 'desk_app has the two doors and the verify, never the right check, never the series table');
  PERFORM pg_temp.ad15_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD15 selftest passed, rolling back' USING ERRCODE = 'P0AO2';
EXCEPTION WHEN SQLSTATE 'P0AO2' THEN RAISE NOTICE 'AD15 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
