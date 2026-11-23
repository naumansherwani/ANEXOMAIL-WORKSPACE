-- AD17 (phase 1m-7, card B6b Own-domain mail posture, list BL-26), 23 Nov 2026 10:1x PKT. THE ADVANCED VERSION (world-class SQL every time).
-- SCHEMA-FIRST: AD01 (fadm_owner, fadm_ledger + chain, fadm_ledger_verify), AD02 (fadm_authorize, fadm_unit_id, fadm_audit, right customer.lookup), AD15 (the hourly hash-chained series pattern: sample table, chain trigger under advisory lock, frozen triggers, BRIN, doors with timeouts).
-- ADVANCE-RESEARCH: [1m] 1m-7 own-domain mail posture as Postmaster Tools / dmarcian / EasyDMARC show it (MX, SPF, DKIM, DMARC, MTA-STS RFC 8461, TLS-RPT RFC 8460, DANE TLSA RFC 7672, DNSSEC): hourly append-only SHA-256 chained series so a record that VANISHES is seen with its time; the door returns which checks changed since the previous hour; same right as the plan lookup; one throttled ledger line per ten minutes; statement/lock timeouts; forced RLS; rolled-back selftest.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD17-check.sql
-- WHAT IT ADDS (nothing older is changed):
--   1. fadm_mailposture_sample: APPEND-ONLY HOURLY series of the eight own-domain checks (boolean each), own SHA-256 chain gapless under an advisory lock, one row per hour, frozen against UPDATE/DELETE/TRUNCATE, forced RLS, BRIN. desk_app has no right on it.
--   2. fadm_mailposture_record(actor, d): re-checks the right (customer.lookup on the Desk department), validates the answer the Desk probed (exactly the eight known keys, each ok / missing / bogus), writes this hour once, writes ONE ledger line per ten minutes, returns the 24-hour line of passing checks, the trend and the names of checks that WORSENED since the previous sample.
--   3. fadm_mailposture_chain_verify().
-- No customer data: own domain only. Every helper is REVOKEd from PUBLIC. desk_app gets the record door and the verify, never a table.

CREATE TABLE IF NOT EXISTS desk.fadm_mailposture_sample (
  id         bigserial PRIMARY KEY,
  bucket     timestamptz NOT NULL UNIQUE CHECK (bucket = date_trunc('hour', bucket)),
  mx_ok      boolean NOT NULL, spf_ok boolean NOT NULL, dkim_ok boolean NOT NULL, dmarc_ok boolean NOT NULL,
  mta_sts_ok boolean NOT NULL, tls_rpt_ok boolean NOT NULL, dane_ok boolean NOT NULL, dnssec_ok boolean NOT NULL,
  ok_n       int NOT NULL CHECK (ok_n BETWEEN 0 AND 8),
  prev_hash  bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash       bytea NOT NULL DEFAULT sha256('x'::bytea),
  CHECK (ok_n = mx_ok::int + spf_ok::int + dkim_ok::int + dmarc_ok::int + mta_sts_ok::int + tls_rpt_ok::int + dane_ok::int + dnssec_ok::int),
  CHECK (octet_length(prev_hash) = 32 AND octet_length(hash) = 32)
);
CREATE INDEX IF NOT EXISTS fadm_mailposture_sample_brin ON desk.fadm_mailposture_sample USING brin (bucket);
CREATE OR REPLACE FUNCTION desk.fadm_mailposture_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_mailposture_sample'));
  SELECT hash INTO p FROM desk.fadm_mailposture_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-mailposture-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || NEW.mx_ok::int || NEW.spf_ok::int || NEW.dkim_ok::int || NEW.dmarc_ok::int || NEW.mta_sts_ok::int || NEW.tls_rpt_ok::int || NEW.dane_ok::int || NEW.dnssec_ok::int, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_mailposture_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_mailposture_sample_chain ON desk.fadm_mailposture_sample;
CREATE TRIGGER fadm_mailposture_sample_chain BEFORE INSERT ON desk.fadm_mailposture_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_mailposture_sample_chain();
DROP TRIGGER IF EXISTS fadm_mailposture_sample_frozen ON desk.fadm_mailposture_sample;
CREATE TRIGGER fadm_mailposture_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_mailposture_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_mailposture_sample_frozen();
DROP TRIGGER IF EXISTS fadm_mailposture_sample_frozen_t ON desk.fadm_mailposture_sample;
CREATE TRIGGER fadm_mailposture_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_mailposture_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_mailposture_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_mailposture_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_mailposture_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_mailposture_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_mailposture_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_mailposture_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_mailposture_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_mailposture_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_mailposture_sample_chain(), desk.fadm_mailposture_sample_frozen() FROM PUBLIC;

CREATE OR REPLACE FUNCTION desk.fadm_mailposture_allowed(p_actor uuid) RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'customer.lookup', desk.fadm_unit_id('department','desk'), NULL)), false)
$f$;

CREATE OR REPLACE FUNCTION desk.fadm_mailposture_record(p_actor uuid, p_d jsonb) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE hb timestamptz := date_trunc('hour', now()); k text; v text; ok boolean[] := ARRAY[]::boolean[]; keys text[] := ARRAY['mx','spf','dkim','dmarc','mta_sts','tls_rpt','dane','dnssec'];
  sp jsonb; cur int; prv int; tr text; prev desk.fadm_mailposture_sample%ROWTYPE; worse jsonb := '[]'::jsonb; flags boolean[];
BEGIN
  IF NOT desk.fadm_mailposture_allowed(p_actor) THEN RETURN NULL; END IF;
  IF p_d IS NULL OR jsonb_typeof(p_d) <> 'object' OR (SELECT count(*) FROM jsonb_object_keys(p_d)) <> 8 THEN RAISE EXCEPTION 'AD17: the answer must hold exactly the eight checks' USING ERRCODE = 'check_violation'; END IF;
  FOREACH k IN ARRAY keys LOOP
    v := p_d->>k;
    IF v IS NULL OR v NOT IN ('ok','missing','bogus') THEN RAISE EXCEPTION 'AD17: check % must be ok, missing or bogus', k USING ERRCODE = 'check_violation'; END IF;
    ok := ok || (v = 'ok');
  END LOOP;
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE actor = p_actor AND kind = 'lookup.company' AND detail->>'company' = '(mail posture)' AND ts > now() - interval '10 minutes') THEN
    PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', '(mail posture)', 'reason', 'own-domain mail posture opened', 'fields', '[]'::jsonb));
  END IF;
  SELECT * INTO prev FROM desk.fadm_mailposture_sample WHERE bucket < hb ORDER BY bucket DESC LIMIT 1;
  IF pg_try_advisory_xact_lock(hashtext('desk.fadm_mailposture_sample.take')) AND NOT EXISTS (SELECT 1 FROM desk.fadm_mailposture_sample WHERE bucket = hb) THEN
    INSERT INTO desk.fadm_mailposture_sample (bucket, mx_ok, spf_ok, dkim_ok, dmarc_ok, mta_sts_ok, tls_rpt_ok, dane_ok, dnssec_ok, ok_n)
    VALUES (hb, ok[1], ok[2], ok[3], ok[4], ok[5], ok[6], ok[7], ok[8], (SELECT count(*) FROM unnest(ok) x WHERE x)::int);
  END IF;
  IF prev.id IS NOT NULL THEN
    flags := ARRAY[prev.mx_ok, prev.spf_ok, prev.dkim_ok, prev.dmarc_ok, prev.mta_sts_ok, prev.tls_rpt_ok, prev.dane_ok, prev.dnssec_ok];
    FOR i IN 1..8 LOOP IF flags[i] AND NOT ok[i] THEN worse := worse || to_jsonb(keys[i]); END IF; END LOOP;
  END IF;
  SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.ok_n FROM desk.fadm_mailposture_sample s WHERE s.bucket = hb - make_interval(hours => 23 - g)) AS v FROM generate_series(0, 23) g) z;
  cur := (SELECT count(*) FROM unnest(ok) x WHERE x)::int;
  SELECT s.ok_n INTO prv FROM desk.fadm_mailposture_sample s WHERE s.bucket BETWEEN hb - interval '25 hours' AND hb - interval '23 hours' ORDER BY abs(extract(epoch FROM s.bucket - (hb - interval '24 hours'))) LIMIT 1;
  tr := CASE WHEN prv IS NULL THEN 'unknown' WHEN cur > prv THEN 'up' WHEN cur < prv THEN 'down' ELSE 'steady' END;
  RETURN jsonb_build_object('spark', sp, 'trend', tr, 'worsened', worse);
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_mailposture_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '15s' AS $f$
DECLARE p bytea := sha256('anexomail-desk-mailposture-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_mailposture_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || r.mx_ok::int || r.spf_ok::int || r.dkim_ok::int || r.dmarc_ok::int || r.mta_sts_ok::int || r.tls_rpt_ok::int || r.dane_ok::int || r.dnssec_ok::int, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

COMMENT ON TABLE desk.fadm_mailposture_sample IS 'AD17: append-only hourly own-domain mail posture (eight checks), SHA-256 chained under an advisory lock; frozen against UPDATE, DELETE and TRUNCATE; forced RLS; desk_app has no right on it.';
COMMENT ON FUNCTION desk.fadm_mailposture_record(uuid, jsonb) IS 'AD17 door: customer.lookup right, validates the eight checks, one ledger line per ten minutes, writes this hour once, returns 24-hour line, trend and the checks that worsened; 5 s statement / 2 s lock timeout.';
COMMENT ON FUNCTION desk.fadm_mailposture_chain_verify() IS 'AD17: re-walks the SHA-256 chain of the series; false on any broken link.';
REVOKE ALL ON FUNCTION desk.fadm_mailposture_allowed(uuid), desk.fadm_mailposture_record(uuid, jsonb), desk.fadm_mailposture_chain_verify() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_mailposture_record(uuid, jsonb), desk.fadm_mailposture_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AQ2). Runs on the LIVE database too: only deltas and its own synthetic rows.
CREATE FUNCTION pg_temp.ad17_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD17 selftest: %', msg USING ERRCODE = 'P0AQ1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
  d jsonb := '{"mx":"ok","spf":"ok","dkim":"missing","dmarc":"ok","mta_sts":"missing","tls_rpt":"missing","dane":"bogus","dnssec":"ok"}'; r jsonb; b0 timestamptz := date_trunc('hour', now()); led0 bigint; led1 bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o17-' || sfx || '@selftest.invalid', 'AD17 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a17-' || sfx || '@selftest.invalid', 'AD17 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  PERFORM pg_temp.ad17_ok(desk.fadm_mailposture_record(a1, d) IS NULL AND desk.fadm_mailposture_record(gen_random_uuid(), d) IS NULL, 'a person without the right and an unknown person get NULL');
  SELECT count(*) INTO led0 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(mail posture)';
  r := desk.fadm_mailposture_record(o, d); PERFORM desk.fadm_mailposture_record(o, d);
  SELECT count(*) INTO led1 FROM desk.fadm_ledger WHERE kind = 'lookup.company' AND detail->>'company' = '(mail posture)';
  PERFORM pg_temp.ad17_ok(led1 - led0 = 1, 'two openings inside ten minutes write ONE ledger line');
  PERFORM pg_temp.ad17_ok(r IS NOT NULL AND jsonb_array_length(r->'spark') = 24 AND r->>'trend' IN ('up','steady','down','unknown') AND jsonb_typeof(r->'worsened') = 'array', 'the owner gets a 24-point line, a trend and a worsened list');
  PERFORM pg_temp.ad17_ok((SELECT count(*) FROM desk.fadm_mailposture_sample WHERE bucket = b0) = 1, 'this hour holds exactly ONE row');
  BEGIN PERFORM desk.fadm_mailposture_record(o, d - 'mx'); RAISE EXCEPTION 'no refusal 0' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_mailposture_record(o, jsonb_set(d, '{spf}', '"fine"')); RAISE EXCEPTION 'no refusal 00' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_mailposture_record(o, d || '{"extra":"ok"}'); RAISE EXCEPTION 'no refusal 000' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.fadm_mailposture_sample SET mx_ok = false; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_mailposture_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_mailposture_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_mailposture_sample (bucket, mx_ok, spf_ok, dkim_ok, dmarc_ok, mta_sts_ok, tls_rpt_ok, dane_ok, dnssec_ok, ok_n) VALUES (b0 - interval '3 hours', true, true, true, true, true, true, true, true, 5); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AQ1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad17_ok(desk.fadm_mailposture_chain_verify(), 'the series chain verifies');
  PERFORM pg_temp.ad17_ok(has_function_privilege('desk_app', 'desk.fadm_mailposture_record(uuid,jsonb)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_mailposture_chain_verify()', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_mailposture_allowed(uuid)', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_mailposture_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_mailposture_sample', 'INSERT'), 'desk_app has the door and the verify, never the right check, never the series');
  PERFORM pg_temp.ad17_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD17 selftest passed, rolling back' USING ERRCODE = 'P0AQ2';
EXCEPTION WHEN SQLSTATE 'P0AQ2' THEN RAISE NOTICE 'AD17 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
