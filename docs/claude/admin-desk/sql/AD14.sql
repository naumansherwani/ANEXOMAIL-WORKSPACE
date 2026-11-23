-- AD14 (phase 1m-4, card B9 Customers and Plans), 23 Nov 2026 08:3x PKT.
-- SCHEMA-FIRST: AD01 (fadm_owner, fadm_ledger + chain), AD02 (fadm_authorize, fadm_need, fadm_audit, fadm_unit_id, fadm_action/fadm_policy customer.lookup), AD04 (fadm_lookup_begin: the plan lookup right = action customer.lookup on the Desk department), AD06 (fadm_pkg_current: the package seat promise), AD13 (the hourly hash-chained series pattern: advisory lock, frozen triggers, BRIN, chain verify), CP2 cp.census (the shape this file stores).
-- ADVANCE-RESEARCH: [1m] hourly append-only SHA-256 chained census series so the card shows a real growth line from day one, door with the SAME right as the plan lookup, seat promise of each package passed to the Control Plane (counts only), one throttled ledger line per ten minutes instead of one per poll, forced RLS, REVOKE PUBLIC, selftest that rolls back (list D6-CARDS-LIST-23NOV.md U7..U9, U11).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD14-check.sql
-- WHAT IT ADDS:
--   1. fadm_census_sample: APPEND-ONLY HOURLY series of the census totals (own SHA-256 chain gapless under an advisory lock, forced RLS, frozen triggers, BRIN, one row per hour). desk_app has no right on it.
--   2. fadm_customers_begin(actor): the first half of the door. Only a person who may open a customer (customer.lookup on the Desk department) gets an answer, everyone else NULL. It returns the seat promise of each package (counts only, from the published package versions) for the Control Plane, and writes ONE ledger line (existing kind lookup.company, company "(census)") at most every ten minutes per person.
--   3. fadm_census_record(actor, census): the second half. It re-checks the right, validates the signed census the Desk already verified (closed shape, no negative number, the five states add up to the companies), writes this hour once, and returns the 24-hour line and a trend word.
--   4. fadm_census_chain_verify().
-- No money, no company id, no person: counts and package seat numbers only. Every helper is REVOKEd from PUBLIC. desk_app gets the two doors and the verify, never a table, never the writer.

CREATE TABLE IF NOT EXISTS desk.fadm_census_sample (
  id           bigserial PRIMARY KEY,
  bucket       timestamptz NOT NULL UNIQUE CHECK (bucket = date_trunc('hour', bucket)),
  companies_n  int NOT NULL CHECK (companies_n >= 0),
  seats_n      int NOT NULL CHECK (seats_n >= 0),
  active_n     int NOT NULL CHECK (active_n >= 0),
  trialing_n   int NOT NULL CHECK (trialing_n >= 0),
  grace_n      int NOT NULL CHECK (grace_n >= 0),
  not_active_n int NOT NULL CHECK (not_active_n >= 0),
  ended_n      int NOT NULL CHECK (ended_n >= 0),
  prev_hash    bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash         bytea NOT NULL DEFAULT sha256('x'::bytea),
  CHECK (active_n + trialing_n + grace_n + not_active_n + ended_n = companies_n)
);
CREATE INDEX IF NOT EXISTS fadm_census_sample_brin ON desk.fadm_census_sample USING brin (bucket);
CREATE OR REPLACE FUNCTION desk.fadm_census_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_census_sample'));
  SELECT hash INTO p FROM desk.fadm_census_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-census-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || NEW.companies_n || '|' || NEW.seats_n || '|' || NEW.active_n || '|' || NEW.trialing_n || '|' || NEW.grace_n || '|' || NEW.not_active_n || '|' || NEW.ended_n, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_census_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_census_sample_chain ON desk.fadm_census_sample;
CREATE TRIGGER fadm_census_sample_chain BEFORE INSERT ON desk.fadm_census_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_census_sample_chain();
DROP TRIGGER IF EXISTS fadm_census_sample_frozen ON desk.fadm_census_sample;
CREATE TRIGGER fadm_census_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_census_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_census_sample_frozen();
DROP TRIGGER IF EXISTS fadm_census_sample_frozen_t ON desk.fadm_census_sample;
CREATE TRIGGER fadm_census_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_census_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_census_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_census_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_census_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_census_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_census_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_census_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_census_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_census_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_census_sample_chain(), desk.fadm_census_sample_frozen() FROM PUBLIC;

-- the right: the SAME as the plan lookup (customer.lookup on the Desk department)
CREATE OR REPLACE FUNCTION desk.fadm_census_allowed(p_actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'customer.lookup', desk.fadm_unit_id('department','desk'), NULL)), false)
$f$;

-- 2) first half of the door: right check, ONE throttled ledger line, the seat promise of each package
CREATE OR REPLACE FUNCTION desk.fadm_customers_begin(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r jsonb := '{}'::jsonb; k text; s text;
BEGIN
  IF NOT desk.fadm_census_allowed(p_actor) THEN RETURN NULL; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE actor = p_actor AND kind = 'lookup.company' AND detail->>'company' = '(census)' AND ts > now() - interval '10 minutes') THEN
    PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', '(census)', 'reason', 'customers and plans board opened', 'fields', '[]'::jsonb));
  END IF;
  FOREACH k IN ARRAY ARRAY['basic','pro','business','business_pro'] LOOP
    SELECT c.limits->>'seats' INTO s FROM desk.fadm_pkg_current(k) c;
    IF s IS NOT NULL AND s ~ '^[0-9]{1,6}$' THEN r := r || jsonb_build_object(k, s::int); END IF;
  END LOOP;
  RETURN r;
END $f$;

-- 3) second half: validate the census the Desk already verified, write this hour once, answer the 24-hour line
CREATE OR REPLACE FUNCTION desk.fadm_census_record(p_actor uuid, p_census jsonb) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE hb timestamptz := date_trunc('hour', now()); n int[]; sp jsonb; cur int; prv int; tr text; st jsonb;
BEGIN
  IF NOT desk.fadm_census_allowed(p_actor) THEN RETURN NULL; END IF;
  IF p_census IS NULL OR jsonb_typeof(p_census) <> 'object' THEN RAISE EXCEPTION 'AD14: the census is not an object' USING ERRCODE = 'check_violation'; END IF;
  st := p_census->'states';
  n := ARRAY[(p_census->>'companies')::int, (p_census->>'seats_in_use')::int, (st->>'active')::int, (st->>'trialing')::int, (st->>'grace_period')::int, (st->>'not_active_yet')::int, (st->>'ended')::int];
  IF EXISTS (SELECT 1 FROM unnest(n) x WHERE x IS NULL OR x < 0) OR n[3] + n[4] + n[5] + n[6] + n[7] <> n[1] THEN RAISE EXCEPTION 'AD14: the census is not a valid count set (missing, negative, or the five states do not add up to the companies)' USING ERRCODE = 'check_violation'; END IF;
  IF pg_try_advisory_xact_lock(hashtext('desk.fadm_census_sample.take')) AND NOT EXISTS (SELECT 1 FROM desk.fadm_census_sample WHERE bucket = hb) THEN
    INSERT INTO desk.fadm_census_sample (bucket, companies_n, seats_n, active_n, trialing_n, grace_n, not_active_n, ended_n) VALUES (hb, n[1], n[2], n[3], n[4], n[5], n[6], n[7]);
  END IF;
  SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.companies_n FROM desk.fadm_census_sample s WHERE s.bucket = hb - make_interval(hours => 23 - g)) AS v FROM generate_series(0, 23) g) z;
  cur := n[1];
  SELECT s.companies_n INTO prv FROM desk.fadm_census_sample s WHERE s.bucket BETWEEN hb - interval '25 hours' AND hb - interval '23 hours' ORDER BY abs(extract(epoch FROM s.bucket - (hb - interval '24 hours'))) LIMIT 1;
  tr := CASE WHEN prv IS NULL THEN 'unknown' WHEN cur > prv THEN 'up' WHEN cur < prv THEN 'down' ELSE 'steady' END;
  RETURN jsonb_build_object('spark', sp, 'trend', tr);
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_census_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea := sha256('anexomail-desk-census-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_census_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || r.companies_n || '|' || r.seats_n || '|' || r.active_n || '|' || r.trialing_n || '|' || r.grace_n || '|' || r.not_active_n || '|' || r.ended_n, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_census_allowed(uuid), desk.fadm_customers_begin(uuid), desk.fadm_census_record(uuid, jsonb), desk.fadm_census_chain_verify() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_customers_begin(uuid), desk.fadm_census_record(uuid, jsonb), desk.fadm_census_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AN2). It runs on the LIVE database too, so it only tests DELTAS and its own synthetic rows.
CREATE FUNCTION pg_temp.ad14_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD14 selftest: %', msg USING ERRCODE = 'P0AN1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
  c jsonb; r jsonb; r2 jsonb; b0 timestamptz := date_trunc('hour', now()); led0 bigint; led1 bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o14-' || sfx || '@selftest.invalid', 'AD14 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a14-' || sfx || '@selftest.invalid', 'AD14 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  PERFORM pg_temp.ad14_ok(desk.fadm_customers_begin(a1) IS NULL AND desk.fadm_customers_begin(gen_random_uuid()) IS NULL, 'a person without the lookup right and an unknown person get NULL');
  SELECT count(*) INTO led0 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(census)';
  r := desk.fadm_customers_begin(o);
  PERFORM pg_temp.ad14_ok(r IS NOT NULL AND jsonb_typeof(r) = 'object' AND NOT EXISTS (SELECT 1 FROM jsonb_each(r) e WHERE e.key NOT IN ('basic','pro','business','business_pro') OR jsonb_typeof(e.value) <> 'number'), 'an owner gets the seat promise object: only the four package keys, numbers only');
  PERFORM desk.fadm_customers_begin(o);
  SELECT count(*) INTO led1 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(census)';
  PERFORM pg_temp.ad14_ok(led1 - led0 = 1, 'two openings inside ten minutes write ONE ledger line');
  c := jsonb_build_object('companies', 7, 'seats_in_use', 31, 'states', jsonb_build_object('active', 3, 'trialing', 1, 'grace_period', 1, 'not_active_yet', 1, 'ended', 1));
  PERFORM pg_temp.ad14_ok(desk.fadm_census_record(a1, c) IS NULL AND desk.fadm_census_record(gen_random_uuid(), c) IS NULL, 'record: a person without the right and an unknown person get NULL');
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_census_sample WHERE bucket = b0) THEN
    r2 := desk.fadm_census_record(o, c);
    PERFORM pg_temp.ad14_ok(r2 IS NOT NULL AND jsonb_array_length(r2->'spark') = 24 AND r2->>'trend' IN ('up','steady','down','unknown') AND (r2->'spark'->23)::int = 7, 'the owner gets a 24-point line whose last point is this hour (7) and a trend word');
    PERFORM pg_temp.ad14_ok((SELECT count(*) FROM desk.fadm_census_sample WHERE bucket = b0) = 1 AND (SELECT companies_n FROM desk.fadm_census_sample WHERE bucket = b0) = 7, 'this hour holds exactly ONE row and the first value stays');
  END IF;
  BEGIN PERFORM desk.fadm_census_record(o, jsonb_set(c, '{states,ended}', '5')); RAISE EXCEPTION 'no refusal 0' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_census_record(o, '{"companies": -1}'::jsonb); RAISE EXCEPTION 'no refusal 00' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_census_sample SET companies_n = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_census_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_census_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_census_sample (bucket, companies_n, seats_n, active_n, trialing_n, grace_n, not_active_n, ended_n) VALUES (b0 - interval '90 minutes', 1, 0, 1, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_census_sample (bucket, companies_n, seats_n, active_n, trialing_n, grace_n, not_active_n, ended_n) VALUES (b0 - interval '3 hours', 2, 0, 1, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AN1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad14_ok(desk.fadm_census_chain_verify(), 'the census series chain verifies');
  PERFORM pg_temp.ad14_ok(has_function_privilege('desk_app', 'desk.fadm_customers_begin(uuid)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_census_record(uuid,jsonb)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_census_allowed(uuid)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_census_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_census_sample', 'INSERT'), 'desk_app has the two doors and the verify, never the right check, never the series table');
  PERFORM pg_temp.ad14_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD14 selftest passed, rolling back' USING ERRCODE = 'P0AN2';
EXCEPTION WHEN SQLSTATE 'P0AN2' THEN RAISE NOTICE 'AD14 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
