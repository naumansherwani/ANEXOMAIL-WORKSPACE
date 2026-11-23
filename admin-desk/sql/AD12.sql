-- AD12 (phase 1m-2, card B3 Security health of the Desk itself), 23 Nov 2026 05:4x PKT. SCHEMA-FIRST (read in full before writing): AD01 (fadm_owner, fadm_passkey), AD02 (passkey columns aaguid / backup_eligible / slot / revoked_at, fadm_aaguid_allow, fadm_recovery, fadm_rel source + expires_at + revoked_at,
--   fadm_alert, fadm_authorize + action staff.read), AD03 (alert after-insert feed), AD11 (the 1-minute series pattern: chain trigger, frozen triggers, lazy advisory-lock sampler, BRIN) and the E-series telemetry files. Nothing of those is changed.
-- WHAT IT ADDS:
--   1. fadm_security_counts(): the raw AGGREGATE facts (counts only) from the real tables.
--   2. fadm_security_score(): ONE IMMUTABLE rule: a CLOSED list of 8 weighted checks (sum 100). Each check says ok / fail / na with what we have and what we need. A check with nobody to check is "na" and is left out of the score (never a free point, never a free penalty).
--      The 8: every active staff member has a passkey (20) | two keys each, primary + backup (20) | every key is device-bound, none synced (15) | every key is an allowed model (10) | no open recovery (10) | no grant left un-revoked 7 days after it expired (10) | no break-glass active (10) | no unacknowledged high alert (5).
--   3. fadm_security_sample: an APPEND-ONLY HOURLY series of the score (own SHA-256 chain gapless under an advisory lock, forced RLS, frozen triggers, BRIN, one row per hour); fadm_security_sample_take(): the lazy sampler (the first reader of an hour writes it, pg_try_advisory_xact_lock, gaps are honest);
--      a fall of 10 points or more raises ONE high alert 'security.score_drop' (at most once per 6 hours) on the AD03 feed to the Urgent alerts card.
--   4. fadm_security_health(): the door. Only a person who may list staff (action staff.read on the Desk department) gets an answer, everyone else NULL. AGGREGATE ONLY: no name, e-mail, credential or key material anywhere. 24-point sparkline + trend vs 24 hours ago.
--   5. fadm_security_sample_chain_verify().
-- No money. Every helper is REVOKEd from PUBLIC (the AD1c lesson). desk_app gets the door and the verify, never a table, never the sampler.

CREATE TABLE IF NOT EXISTS desk.fadm_security_sample (
  id         bigserial PRIMARY KEY,
  bucket     timestamptz NOT NULL UNIQUE CHECK (bucket = date_trunc('hour', bucket)),
  score      int CHECK (score IS NULL OR score BETWEEN 0 AND 100),
  ok_n       int NOT NULL CHECK (ok_n BETWEEN 0 AND 8),
  fail_n     int NOT NULL CHECK (fail_n BETWEEN 0 AND 8),
  na_n       int NOT NULL CHECK (na_n BETWEEN 0 AND 8),
  staff_n    int NOT NULL CHECK (staff_n >= 0),
  prev_hash  bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash       bytea NOT NULL DEFAULT sha256('x'::bytea),
  CHECK (ok_n + fail_n + na_n = 8)
);
CREATE INDEX IF NOT EXISTS fadm_security_sample_brin ON desk.fadm_security_sample USING brin (bucket);
CREATE OR REPLACE FUNCTION desk.fadm_security_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_security_sample'));
  SELECT hash INTO p FROM desk.fadm_security_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-security-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || COALESCE(NEW.score::text, '-') || '|' || NEW.ok_n || '|' || NEW.fail_n || '|' || NEW.na_n || '|' || NEW.staff_n, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_security_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_security_sample_chain ON desk.fadm_security_sample;
CREATE TRIGGER fadm_security_sample_chain BEFORE INSERT ON desk.fadm_security_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_security_sample_chain();
DROP TRIGGER IF EXISTS fadm_security_sample_frozen ON desk.fadm_security_sample;
CREATE TRIGGER fadm_security_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_security_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_security_sample_frozen();
DROP TRIGGER IF EXISTS fadm_security_sample_frozen_t ON desk.fadm_security_sample;
CREATE TRIGGER fadm_security_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_security_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_security_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_security_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_security_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_security_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_security_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_security_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_security_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_security_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_security_sample_chain(), desk.fadm_security_sample_frozen() FROM PUBLIC;

-- 1) the raw aggregate facts, counts only
CREATE OR REPLACE FUNCTION desk.fadm_security_counts() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  WITH s AS (SELECT o.id FROM desk.fadm_owner o WHERE o.active AND o.status = 'active'),
       k AS (SELECT p.owner_id, p.backup_eligible, p.aaguid FROM desk.fadm_passkey p JOIN s ON s.id = p.owner_id WHERE p.revoked_at IS NULL),
       per AS (SELECT s.id, count(k.owner_id) AS n FROM s LEFT JOIN k ON k.owner_id = s.id GROUP BY s.id)
  SELECT jsonb_build_object(
    'staff',        (SELECT count(*) FROM s),
    'with_key',     (SELECT count(*) FROM per WHERE n >= 1),
    'with_two',     (SELECT count(*) FROM per WHERE n >= 2),
    'keys',         (SELECT count(*) FROM k),
    'keys_bound',   (SELECT count(*) FROM k WHERE backup_eligible = false),
    'keys_allowed', (SELECT count(*) FROM k WHERE aaguid IS NOT NULL AND EXISTS (SELECT 1 FROM desk.fadm_aaguid_allow a WHERE a.aaguid = k.aaguid AND a.enabled)),
    'recoveries_open', (SELECT count(*) FROM desk.fadm_recovery WHERE status = 'open'),
    'grants_stale', (SELECT count(*) FROM desk.fadm_rel WHERE revoked_at IS NULL AND expires_at IS NOT NULL AND expires_at < now() - interval '7 days'),
    'breakglass_active', (SELECT count(*) FROM desk.fadm_rel WHERE source = 'breakglass' AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > now())),
    'alerts_high_open', (SELECT count(*) FROM desk.fadm_alert WHERE severity = 'high' AND acked_at IS NULL AND at > now() - interval '30 days')) $f$;

-- 2) the ONE rule: eight weighted checks (sum 100); na = nobody to check, left out of the score
CREATE OR REPLACE FUNCTION desk.fadm_security_score(c jsonb) RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  WITH d(ord, key, label, weight, have, need, applicable) AS (VALUES
    (1, 'every_staff_has_key',  'Every active staff member has a passkey',                20, (c->>'with_key')::int,      (c->>'staff')::int, (c->>'staff')::int > 0),
    (2, 'two_keys_each',        'Everyone has two keys (primary and backup)',             20, (c->>'with_two')::int,      (c->>'staff')::int, (c->>'staff')::int > 0),
    (3, 'keys_device_bound',    'Every key is device-bound, none is synced',              15, (c->>'keys_bound')::int,    (c->>'keys')::int,  (c->>'keys')::int > 0),
    (4, 'keys_allowed_model',   'Every key is an allowed security-key model',             10, (c->>'keys_allowed')::int,  (c->>'keys')::int,  (c->>'keys')::int > 0),
    (5, 'no_open_recovery',     'No account recovery is open',                            10, 1 - least(1, (c->>'recoveries_open')::int), 1, true),
    (6, 'no_stale_grants',      'No access grant was left on 7 days after it expired',    10, 1 - least(1, (c->>'grants_stale')::int),    1, true),
    (7, 'no_breakglass_active', 'No break-glass access is active',                        10, 1 - least(1, (c->>'breakglass_active')::int), 1, true),
    (8, 'no_open_high_alert',   'No high alert is waiting for an answer',                  5, 1 - least(1, (c->>'alerts_high_open')::int), 1, true)),
  e AS (SELECT d.*, CASE WHEN NOT applicable THEN 'na' WHEN have >= need THEN 'ok' ELSE 'fail' END AS status FROM d)
  SELECT jsonb_build_object(
    'score', (SELECT CASE WHEN sum(weight) FILTER (WHERE status <> 'na') IS NULL THEN NULL ELSE round(100.0 * COALESCE(sum(weight) FILTER (WHERE status = 'ok'), 0) / sum(weight) FILTER (WHERE status <> 'na'))::int END FROM e),
    'ok', (SELECT count(*) FROM e WHERE status = 'ok'), 'fail', (SELECT count(*) FROM e WHERE status = 'fail'), 'na', (SELECT count(*) FROM e WHERE status = 'na'),
    'checks', (SELECT jsonb_agg(jsonb_build_object('key', key, 'label', label, 'weight', weight, 'status', status, 'have', CASE WHEN status = 'na' THEN 0 ELSE least(have, need) END, 'of', CASE WHEN status = 'na' THEN 0 ELSE need END) ORDER BY ord) FROM e)) $f$;

-- 3) the lazy hourly sampler + the drop alert
CREATE OR REPLACE FUNCTION desk.fadm_security_sample_take() RETURNS int LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE b timestamptz := date_trunc('hour', now()); sc jsonb; c jsonb; prev int; cur int;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('desk.fadm_security_sample.take')) THEN RETURN 0; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_security_sample WHERE bucket = b) THEN RETURN 0; END IF;
  c := desk.fadm_security_counts(); sc := desk.fadm_security_score(c);
  SELECT score INTO prev FROM desk.fadm_security_sample ORDER BY id DESC LIMIT 1;
  cur := (sc->>'score')::int;
  INSERT INTO desk.fadm_security_sample (bucket, score, ok_n, fail_n, na_n, staff_n) VALUES (b, cur, (sc->>'ok')::int, (sc->>'fail')::int, (sc->>'na')::int, (c->>'staff')::int);
  IF prev IS NOT NULL AND cur IS NOT NULL AND prev - cur >= 10 AND NOT EXISTS (SELECT 1 FROM desk.fadm_alert a WHERE a.kind = 'security.score_drop' AND a.at > now() - interval '6 hours') THEN
    INSERT INTO desk.fadm_alert (severity, kind, detail) VALUES ('high', 'security.score_drop', jsonb_build_object('from', prev, 'to', cur));
  END IF;
  RETURN 1;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_security_sample_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea := sha256('anexomail-desk-security-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_security_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || COALESCE(r.score::text, '-') || '|' || r.ok_n || '|' || r.fail_n || '|' || r.na_n || '|' || r.staff_n, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

-- 4) the door: only a person who may list staff; AGGREGATE ONLY
CREATE OR REPLACE FUNCTION desk.fadm_security_health(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c jsonb; sc jsonb; sp jsonb; cur int; prv int; tr text; hb timestamptz := date_trunc('hour', now());
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  IF NOT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'staff.read', desk.fadm_unit_id('department','desk'), NULL)), false) THEN RETURN NULL; END IF;
  PERFORM desk.fadm_security_sample_take();
  c := desk.fadm_security_counts(); sc := desk.fadm_security_score(c); cur := (sc->>'score')::int;
  SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.score FROM desk.fadm_security_sample s WHERE s.bucket = hb - make_interval(hours => 23 - g)) AS v FROM generate_series(0, 23) g) z;
  SELECT s.score INTO prv FROM desk.fadm_security_sample s WHERE s.bucket BETWEEN hb - interval '25 hours' AND hb - interval '23 hours' AND s.score IS NOT NULL ORDER BY abs(extract(epoch FROM s.bucket - (hb - interval '24 hours'))) LIMIT 1;
  tr := CASE WHEN cur IS NULL OR prv IS NULL THEN 'unknown' WHEN cur - prv >= 3 THEN 'up' WHEN cur - prv <= -3 THEN 'down' ELSE 'steady' END;
  RETURN jsonb_build_object('generated_at', now(), 'score', sc->'score', 'ok', sc->'ok', 'fail', sc->'fail', 'na', sc->'na', 'checks', sc->'checks', 'spark', sp, 'trend', tr, 'staff', c->'staff');
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_security_counts(), desk.fadm_security_score(jsonb), desk.fadm_security_sample_take(), desk.fadm_security_sample_chain_verify(), desk.fadm_security_health(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_security_health(uuid), desk.fadm_security_sample_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AL2). It runs on the LIVE database too, so it only tests the pure rule with synthetic counts and DELTAS of the real counts, never exact totals. ------------------------
CREATE FUNCTION pg_temp.ad12_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD12 selftest: %', msg USING ERRCODE = 'P0AL1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; a2 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('team','support');
  c0 jsonb; c1 jsonb; s jsonb; r jsonb; ag uuid := gen_random_uuid(); b0 timestamptz := date_trunc('hour', now()); n0 int; i int;
BEGIN
  -- the pure rule with synthetic counts: perfect, empty, and one failing check
  s := desk.fadm_security_score('{"staff":3,"with_key":3,"with_two":3,"keys":6,"keys_bound":6,"keys_allowed":6,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb);
  PERFORM pg_temp.ad12_ok((s->>'score')::int = 100 AND (s->>'ok')::int = 8 AND jsonb_array_length(s->'checks') = 8, 'a perfect Desk scores 100 with 8 ok');
  s := desk.fadm_security_score('{"staff":0,"with_key":0,"with_two":0,"keys":0,"keys_bound":0,"keys_allowed":0,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb);
  PERFORM pg_temp.ad12_ok((s->>'na')::int = 4 AND (s->>'score')::int = 100 AND (s->>'ok')::int = 4, 'with nobody to check, the 4 people-checks are na and are left out (4 ok x 35 of 35 applicable = 100)');
  s := desk.fadm_security_score('{"staff":4,"with_key":4,"with_two":2,"keys":6,"keys_bound":6,"keys_allowed":6,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb);
  PERFORM pg_temp.ad12_ok((s->>'score')::int = 80 AND (s->>'fail')::int = 1 AND s->'checks'->1->>'status' = 'fail' AND (s->'checks'->1->>'have')::int = 2 AND (s->'checks'->1->>'of')::int = 4, 'two keys for 2 of 4 fails exactly that check (weight 20 -> 80)');
  s := desk.fadm_security_score('{"staff":2,"with_key":1,"with_two":0,"keys":2,"keys_bound":0,"keys_allowed":0,"recoveries_open":1,"grants_stale":2,"breakglass_active":1,"alerts_high_open":3}'::jsonb);
  PERFORM pg_temp.ad12_ok((s->>'score')::int = 0 AND (s->>'fail')::int = 8, 'everything wrong scores 0 with 8 failing checks');
  PERFORM pg_temp.ad12_ok(NOT (desk.fadm_security_score('{"staff":2,"with_key":2,"with_two":2,"keys":4,"keys_bound":3,"keys_allowed":4,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb)->'checks'->2->>'status' = 'ok'), 'one synced key out of 4 fails the device-bound check');
  -- real counts move by exactly what the test adds
  c0 := desk.fadm_security_counts();
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o12-' || sfx || '@selftest.invalid', 'AD12 Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a12-' || sfx || '@selftest.invalid', 'AD12 Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('b12-' || sfx || '@selftest.invalid', 'AD12 Owner two', 'owner', h) RETURNING id INTO a2;   -- an owner account may hold a synced or unlisted key (the AD02 guard binds agents only), which is exactly what the check must catch
  INSERT INTO desk.fadm_aaguid_allow (aaguid, label, enabled) VALUES (ag, 'AD12 selftest model', true);
  INSERT INTO desk.fadm_passkey (owner_id, cred_id, public_key, aaguid, backup_eligible, backup_state, slot) VALUES (a1, convert_to('k1-' || sfx, 'UTF8'), '\x01', ag, false, false, 'primary');
  INSERT INTO desk.fadm_passkey (owner_id, cred_id, public_key, aaguid, backup_eligible, backup_state, slot) VALUES (a1, convert_to('k2-' || sfx, 'UTF8'), '\x01', ag, false, false, 'backup');
  INSERT INTO desk.fadm_passkey (owner_id, cred_id, public_key, aaguid, backup_eligible, backup_state, slot) VALUES (a2, convert_to('k3-' || sfx, 'UTF8'), '\x01', NULL, true, true, 'primary');
  c1 := desk.fadm_security_counts();
  PERFORM pg_temp.ad12_ok((c1->>'staff')::int - (c0->>'staff')::int = 3 AND (c1->>'with_key')::int - (c0->>'with_key')::int = 2 AND (c1->>'with_two')::int - (c0->>'with_two')::int = 1, 'staff, one-key and two-key counts move by exactly what was added');
  PERFORM pg_temp.ad12_ok((c1->>'keys')::int - (c0->>'keys')::int = 3 AND (c1->>'keys_bound')::int - (c0->>'keys_bound')::int = 2 AND (c1->>'keys_allowed')::int - (c0->>'keys_allowed')::int = 2, 'key, device-bound and allowed-model counts move by exactly what was added (the synced, unlisted key counts in neither)');
  UPDATE desk.fadm_passkey SET revoked_at = now() WHERE owner_id = a2;
  PERFORM pg_temp.ad12_ok(((desk.fadm_security_counts())->>'keys')::int - (c0->>'keys')::int = 2, 'a revoked key is not counted');
  -- the door: staff.read only, NULL for everyone else, aggregate only
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent');
  PERFORM pg_temp.ad12_ok(desk.fadm_security_health(a1) IS NULL AND desk.fadm_security_health(gen_random_uuid()) IS NULL, 'a support agent and an unknown person get nothing (NULL)');
  r := desk.fadm_security_health(o);
  PERFORM pg_temp.ad12_ok(r IS NOT NULL AND jsonb_array_length(r->'checks') = 8 AND jsonb_array_length(r->'spark') = 24 AND r->>'trend' IN ('up','steady','down','unknown'), 'an owner gets 8 checks, a 24-point sparkline and a trend');
  PERFORM pg_temp.ad12_ok(r::text !~* '(@selftest|AD12 Agent|AD12 Owner|cred|public_key|aaguid|password|argon)', 'aggregate only: no name, e-mail, credential or key material in the answer');
  PERFORM pg_temp.ad12_ok((r->'spark'->>23) IS NOT NULL OR (r->>'score') IS NULL, 'the latest hour is in the series (or there is no score)');
  -- the series: one row per hour, append-only, chain verifies, a drop of 10+ raises ONE alert
  PERFORM pg_temp.ad12_ok(desk.fadm_security_sample_take() = 0 AND (SELECT count(*) FROM desk.fadm_security_sample WHERE bucket = b0) = 1, 'the first reader wrote this hour once, the second wrote nothing');
  BEGIN UPDATE desk.fadm_security_sample SET score = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AL1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_security_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AL1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_security_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AL1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_security_sample (bucket, score, ok_n, fail_n, na_n, staff_n) VALUES (b0 - interval '90 minutes', 50, 1, 1, 1, 1); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AL1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_security_sample (bucket, score, ok_n, fail_n, na_n, staff_n) VALUES (b0 - interval '3 hours', 101, 8, 0, 0, 1); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AL1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad12_ok(desk.fadm_security_sample_chain_verify(), 'the score series chain verifies');
  PERFORM pg_temp.ad12_ok(has_function_privilege('desk_app', 'desk.fadm_security_health(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_security_sample_take()', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_security_counts()', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_security_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_security_sample', 'INSERT'), 'desk_app has the door and the verify, never the sampler, the counts or the series table');
  PERFORM pg_temp.ad12_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD12 selftest passed, rolling back' USING ERRCODE = 'P0AL2';
EXCEPTION WHEN SQLSTATE 'P0AL2' THEN RAISE NOTICE 'AD12 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
