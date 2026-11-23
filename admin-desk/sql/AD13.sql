-- AD13 (phase 1m-3, card B8 Staff online and shifts), 23 Nov 2026 06:2x PKT.
-- SCHEMA-FIRST: AD01 (fadm_owner, fadm_session), AD02 (fadm_shift, fadm_in_shift, fadm_rel with source elevation/breakglass, fadm_unit, fadm_elevation, fadm_authorize + staff.read, fadm_access_grant), AD12 (the hourly series pattern: chain trigger, frozen triggers, lazy advisory-lock sampler, BRIN) and the E-series telemetry files. Nothing of those is changed.
-- ADVANCE-RESEARCH: [1m] presence from live sessions once per person, coverage via the person's own shift in his own time zone, JIT elevation and break-glass countdown (zero standing privilege made visible), staff-only view (docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md T1..T7)
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD13-check.sql
-- WHAT IT ADDS:
--   1. fadm_staff_counts(): the raw facts (counts only) from the real tables: active staff, ONLINE (a live session: not revoked, not expired; counted once per person), SCHEDULED (has shift rows), ON SHIFT now (fadm_in_shift in his own time zone), COVERED (on shift AND online), GAP (on shift, not online), EXTRA (online while scheduled but outside the shift), live elevations, live break-glass.
--   2. fadm_staff_sample: an APPEND-ONLY HOURLY series of those counts (own SHA-256 chain gapless under an advisory lock, forced RLS, frozen triggers, BRIN, one row per hour); fadm_staff_sample_take(): the lazy sampler (the first reader of an hour writes it, pg_try_advisory_xact_lock, never two writers).
--   3. fadm_staff_board(): the door. Only a person who may list staff (action staff.read on the Desk department) gets an answer, everyone else NULL. People rows carry display name, role, online, scheduled, on shift, minutes since the newest live sign-in (max 50). Elevation rows carry who, relation, unit, source and MINUTES LEFT (max 20). NO e-mail, IP, device, token or key anywhere. 24-point sparkline of "online" + trend vs 24 hours ago.
--   4. fadm_staff_sample_chain_verify().
-- No money. Every helper is REVOKEd from PUBLIC (the AD1c lesson). desk_app gets the door and the verify, never a table, never the sampler.

CREATE TABLE IF NOT EXISTS desk.fadm_staff_sample (
  id          bigserial PRIMARY KEY,
  bucket      timestamptz NOT NULL UNIQUE CHECK (bucket = date_trunc('hour', bucket)),
  staff_n     int NOT NULL CHECK (staff_n >= 0),
  online_n    int NOT NULL CHECK (online_n >= 0),
  scheduled_n int NOT NULL CHECK (scheduled_n >= 0),
  on_shift_n  int NOT NULL CHECK (on_shift_n >= 0),
  covered_n   int NOT NULL CHECK (covered_n >= 0),
  elev_n      int NOT NULL CHECK (elev_n >= 0),
  glass_n     int NOT NULL CHECK (glass_n >= 0),
  prev_hash   bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash        bytea NOT NULL DEFAULT sha256('x'::bytea),
  CHECK (online_n <= staff_n AND scheduled_n <= staff_n AND on_shift_n <= scheduled_n AND covered_n <= on_shift_n AND covered_n <= online_n)
);
CREATE INDEX IF NOT EXISTS fadm_staff_sample_brin ON desk.fadm_staff_sample USING brin (bucket);
CREATE OR REPLACE FUNCTION desk.fadm_staff_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_staff_sample'));
  SELECT hash INTO p FROM desk.fadm_staff_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-staff-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || NEW.staff_n || '|' || NEW.online_n || '|' || NEW.scheduled_n || '|' || NEW.on_shift_n || '|' || NEW.covered_n || '|' || NEW.elev_n || '|' || NEW.glass_n, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_staff_sample_chain ON desk.fadm_staff_sample;
CREATE TRIGGER fadm_staff_sample_chain BEFORE INSERT ON desk.fadm_staff_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_staff_sample_chain();
DROP TRIGGER IF EXISTS fadm_staff_sample_frozen ON desk.fadm_staff_sample;
CREATE TRIGGER fadm_staff_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_staff_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_staff_sample_frozen();
DROP TRIGGER IF EXISTS fadm_staff_sample_frozen_t ON desk.fadm_staff_sample;
CREATE TRIGGER fadm_staff_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_staff_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_staff_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_staff_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_staff_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_staff_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_staff_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_staff_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_staff_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_staff_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_staff_sample_chain(), desk.fadm_staff_sample_frozen() FROM PUBLIC;

-- 1) the raw facts, counts only (one row per active person first, then the counts)
CREATE OR REPLACE FUNCTION desk.fadm_staff_counts() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  WITH s AS (
    SELECT o.id,
      EXISTS (SELECT 1 FROM desk.fadm_session x WHERE x.owner_id = o.id AND x.revoked_at IS NULL AND x.expires_at > now()) AS online,
      EXISTS (SELECT 1 FROM desk.fadm_shift h WHERE h.owner_id = o.id) AS scheduled
    FROM desk.fadm_owner o WHERE o.active AND o.status = 'active'),
  t AS (SELECT s.*, (s.scheduled AND desk.fadm_in_shift(s.id)) AS on_shift FROM s)
  SELECT jsonb_build_object(
    'staff',     (SELECT count(*) FROM t),
    'online',    (SELECT count(*) FROM t WHERE online),
    'scheduled', (SELECT count(*) FROM t WHERE scheduled),
    'on_shift',  (SELECT count(*) FROM t WHERE on_shift),
    'covered',   (SELECT count(*) FROM t WHERE on_shift AND online),
    'gap',       (SELECT count(*) FROM t WHERE on_shift AND NOT online),
    'extra',     (SELECT count(*) FROM t WHERE online AND scheduled AND NOT on_shift),
    'elevations',(SELECT count(*) FROM desk.fadm_rel WHERE source = 'elevation' AND revoked_at IS NULL AND expires_at > now()),
    'breakglass',(SELECT count(*) FROM desk.fadm_rel WHERE source = 'breakglass' AND revoked_at IS NULL AND expires_at > now())) $f$;

-- 2) the lazy hourly sampler (never two writers, never twice in one hour, restricted to its own caller)
CREATE OR REPLACE FUNCTION desk.fadm_staff_sample_take() RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE b timestamptz := date_trunc('hour', now()); c jsonb;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('desk.fadm_staff_sample.take')) THEN RETURN 0; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_staff_sample WHERE bucket = b) THEN RETURN 0; END IF;
  c := desk.fadm_staff_counts();
  INSERT INTO desk.fadm_staff_sample (bucket, staff_n, online_n, scheduled_n, on_shift_n, covered_n, elev_n, glass_n)
  VALUES (b, (c->>'staff')::int, (c->>'online')::int, (c->>'scheduled')::int, (c->>'on_shift')::int, (c->>'covered')::int, (c->>'elevations')::int, (c->>'breakglass')::int);
  RETURN 1;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_staff_sample_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea := sha256('anexomail-desk-staff-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_staff_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || r.staff_n || '|' || r.online_n || '|' || r.scheduled_n || '|' || r.on_shift_n || '|' || r.covered_n || '|' || r.elev_n || '|' || r.glass_n, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

-- 3) the door: only a person who may list staff
CREATE OR REPLACE FUNCTION desk.fadm_staff_board(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE c jsonb; sp jsonb; ppl jsonb; el jsonb; cur int; prv int; tr text; hb timestamptz := date_trunc('hour', now());
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  IF NOT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'staff.read', desk.fadm_unit_id('department','desk'), NULL)), false) THEN RETURN NULL; END IF;
  PERFORM desk.fadm_staff_sample_take();
  c := desk.fadm_staff_counts(); cur := (c->>'online')::int;
  SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.online_n FROM desk.fadm_staff_sample s WHERE s.bucket = hb - make_interval(hours => 23 - g)) AS v FROM generate_series(0, 23) g) z;
  SELECT s.online_n INTO prv FROM desk.fadm_staff_sample s WHERE s.bucket BETWEEN hb - interval '25 hours' AND hb - interval '23 hours' ORDER BY abs(extract(epoch FROM s.bucket - (hb - interval '24 hours'))) LIMIT 1;
  tr := CASE WHEN prv IS NULL THEN 'unknown' WHEN cur > prv THEN 'up' WHEN cur < prv THEN 'down' ELSE 'steady' END;
  SELECT COALESCE(jsonb_agg(q.j ORDER BY q.online DESC, q.nm), '[]'::jsonb) INTO ppl FROM (
    SELECT o.display_name AS nm,
      EXISTS (SELECT 1 FROM desk.fadm_session x WHERE x.owner_id = o.id AND x.revoked_at IS NULL AND x.expires_at > now()) AS online,
      jsonb_build_object('name', o.display_name, 'role', o.role,
        'online', EXISTS (SELECT 1 FROM desk.fadm_session x WHERE x.owner_id = o.id AND x.revoked_at IS NULL AND x.expires_at > now()),
        'scheduled', EXISTS (SELECT 1 FROM desk.fadm_shift h WHERE h.owner_id = o.id),
        'on_shift', (EXISTS (SELECT 1 FROM desk.fadm_shift h WHERE h.owner_id = o.id) AND desk.fadm_in_shift(o.id)),
        'signed_in_minutes', (SELECT floor(extract(epoch FROM now() - max(x.created_at)) / 60)::int FROM desk.fadm_session x WHERE x.owner_id = o.id AND x.revoked_at IS NULL AND x.expires_at > now())) AS j
    FROM desk.fadm_owner o WHERE o.active AND o.status = 'active' ORDER BY 2 DESC, 1 LIMIT 50) q;
  SELECT COALESCE(jsonb_agg(e.j ORDER BY e.left_m), '[]'::jsonb) INTO el FROM (
    SELECT ceil(extract(epoch FROM r.expires_at - now()) / 60)::int AS left_m,
      jsonb_build_object('who', o.display_name, 'relation', r.relation, 'unit', u.name, 'source', r.source, 'minutes_left', ceil(extract(epoch FROM r.expires_at - now()) / 60)::int) AS j
    FROM desk.fadm_rel r JOIN desk.fadm_owner o ON o.id = r.subject_id JOIN desk.fadm_unit u ON u.id = r.object_id
    WHERE r.source IN ('elevation','breakglass') AND r.revoked_at IS NULL AND r.expires_at > now() AND r.subject_type = 'owner' AND r.object_type = 'unit'
    ORDER BY r.expires_at LIMIT 20) e;
  RETURN jsonb_build_object('generated_at', now(), 'counts', c, 'people', ppl, 'elevations', el, 'spark', sp, 'trend', tr);
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_staff_counts(), desk.fadm_staff_sample_take(), desk.fadm_staff_sample_chain_verify(), desk.fadm_staff_board(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_staff_board(uuid), desk.fadm_staff_sample_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AM2). It runs on the LIVE database too, so it only tests DELTAS of the real counts, never exact totals. ------------------------
CREATE FUNCTION pg_temp.ad13_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD13 selftest: %', msg USING ERRCODE = 'P0AM1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; a2 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('team','support');
  c0 jsonb; c1 jsonb; r jsonb; b0 timestamptz := date_trunc('hour', now()); d int := extract(dow FROM now() AT TIME ZONE 'UTC')::int;
BEGIN
  c0 := desk.fadm_staff_counts();
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, timezone) VALUES ('o13-' || sfx || '@selftest.invalid', 'AD13 Owner', 'owner', h, 'UTC') RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a13-' || sfx || '@selftest.invalid', 'AD13 Agent', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('b13-' || sfx || '@selftest.invalid', 'AD13 Agent two', 'agent', NULL, true, 'UTC') RETURNING id INTO a2;
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'staff')::int - (c0->>'staff')::int = 3 AND (c1->>'online')::int = (c0->>'online')::int AND (c1->>'scheduled')::int = (c0->>'scheduled')::int, 'three new people: staff +3, nobody online or scheduled yet');
  -- a1 online with TWO live sessions counts once; a2 has only a revoked and an expired session and counts as offline
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (a1, sha256(convert_to('s1-' || sfx, 'UTF8')), now() + interval '1 hour'), (a1, sha256(convert_to('s2-' || sfx, 'UTF8')), now() + interval '2 hours');
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at, revoked_at) VALUES (a2, sha256(convert_to('s3-' || sfx, 'UTF8')), now() + interval '1 hour', now());
  INSERT INTO desk.fadm_session (owner_id, token_hash, created_at, expires_at) VALUES (a2, sha256(convert_to('s4-' || sfx, 'UTF8')), now() - interval '2 hours', now() - interval '1 hour');
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'online')::int - (c0->>'online')::int = 1, 'two live sessions count the person once; a revoked and an expired session count as offline');
  -- shifts in his own time zone: a1 works every day all day (on shift), a2 works only tomorrow (scheduled, not on shift now)
  INSERT INTO desk.fadm_shift (owner_id, dow, start_min, end_min) SELECT a1, g, 0, 1440 FROM generate_series(0, 6) g;
  INSERT INTO desk.fadm_shift (owner_id, dow, start_min, end_min) VALUES (a2, (d + 1) % 7, 0, 1440);
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'scheduled')::int - (c0->>'scheduled')::int = 2 AND (c1->>'on_shift')::int - (c0->>'on_shift')::int = 1, 'scheduled +2, on shift +1 (only the all-day person)');
  PERFORM pg_temp.ad13_ok((c1->>'covered')::int - (c0->>'covered')::int = 1 AND (c1->>'gap')::int = (c0->>'gap')::int AND (c1->>'extra')::int = (c0->>'extra')::int, 'covered +1; no new gap, no new extra');
  INSERT INTO desk.fadm_session (owner_id, token_hash, expires_at) VALUES (a2, sha256(convert_to('s5-' || sfx, 'UTF8')), now() + interval '1 hour');
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'extra')::int - (c0->>'extra')::int = 1 AND (c1->>'online')::int - (c0->>'online')::int = 2, 'a2 signs in outside his shift: extra +1, online +2');
  UPDATE desk.fadm_session SET revoked_at = now() WHERE owner_id = a1;
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'gap')::int - (c0->>'gap')::int = 1 AND (c1->>'covered')::int = (c0->>'covered')::int, 'a1 signs out while on shift: gap +1, covered back to the start');
  -- elevation and break-glass countdown
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, source, created_by, expires_at) VALUES ('unit', sup, 'agent', 'owner', a2, 'elevation', o, now() + interval '30 minutes');
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, source, created_by, expires_at) VALUES ('unit', sup, 'lead', 'owner', a1, 'breakglass', o, now() + interval '10 minutes');
  c1 := desk.fadm_staff_counts();
  PERFORM pg_temp.ad13_ok((c1->>'elevations')::int - (c0->>'elevations')::int = 1 AND (c1->>'breakglass')::int - (c0->>'breakglass')::int = 1, 'one live elevation and one live break-glass counted');
  -- the door: staff.read only, NULL for everyone else; no e-mail, ip, device, token or key
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent');
  PERFORM pg_temp.ad13_ok(desk.fadm_staff_board(a1) IS NULL AND desk.fadm_staff_board(gen_random_uuid()) IS NULL, 'a support agent and an unknown person get nothing (NULL)');
  r := desk.fadm_staff_board(o);
  PERFORM pg_temp.ad13_ok(r IS NOT NULL AND jsonb_array_length(r->'spark') = 24 AND r->>'trend' IN ('up','steady','down','unknown') AND jsonb_array_length(r->'people') BETWEEN 3 AND 50, 'an owner gets the board: 24-point sparkline, a trend, 3 to 50 people');
  PERFORM pg_temp.ad13_ok(r::text !~* '(@selftest|token|argon|cred|public_key|aaguid|"ip"|user_agent)', 'no e-mail, token, hash, key, ip or device in the answer');
  PERFORM pg_temp.ad13_ok((SELECT count(*) FROM jsonb_array_elements(r->'elevations') e WHERE e->>'source' = 'breakglass' AND (e->>'minutes_left')::int BETWEEN 9 AND 10) >= 1 AND (SELECT count(*) FROM jsonb_array_elements(r->'elevations') e WHERE e->>'source' = 'elevation' AND (e->>'minutes_left')::int BETWEEN 29 AND 30) >= 1, 'elevation and break-glass show their minutes left');
  PERFORM pg_temp.ad13_ok((SELECT count(*) FROM jsonb_array_elements(r->'people') p WHERE p->>'name' = 'AD13 Agent two' AND (p->>'online')::boolean AND (p->>'scheduled')::boolean AND NOT (p->>'on_shift')::boolean) = 1, 'the person who signed in outside his shift is online, scheduled and not on shift');
  -- the series: one row per hour, append-only, chain verifies
  PERFORM pg_temp.ad13_ok(desk.fadm_staff_sample_take() = 0 AND (SELECT count(*) FROM desk.fadm_staff_sample WHERE bucket = b0) = 1, 'the first reader wrote this hour once, the second wrote nothing');
  BEGIN UPDATE desk.fadm_staff_sample SET online_n = 1; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AM1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_staff_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AM1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_staff_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AM1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_staff_sample (bucket, staff_n, online_n, scheduled_n, on_shift_n, covered_n, elev_n, glass_n) VALUES (b0 - interval '90 minutes', 1, 0, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AM1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_staff_sample (bucket, staff_n, online_n, scheduled_n, on_shift_n, covered_n, elev_n, glass_n) VALUES (b0 - interval '3 hours', 1, 2, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AM1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad13_ok(desk.fadm_staff_sample_chain_verify(), 'the staff series chain verifies');
  PERFORM pg_temp.ad13_ok(has_function_privilege('desk_app', 'desk.fadm_staff_board(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_staff_sample_take()', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_staff_counts()', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_staff_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_staff_sample', 'INSERT'), 'desk_app has the door and the verify, never the sampler, the counts or the series table');
  PERFORM pg_temp.ad13_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD13 selftest passed, rolling back' USING ERRCODE = 'P0AM2';
EXCEPTION WHEN SQLSTATE 'P0AM2' THEN RAISE NOTICE 'AD13 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
