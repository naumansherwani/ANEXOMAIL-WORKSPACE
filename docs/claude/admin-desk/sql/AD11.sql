-- AD11 (phase 1m-1, cards B1 Queue pressure + B2 SLA at risk), 23 Nov 2026 05:3x PKT. THE ADVANCED VERSION (his order 05:18: read ALL old SQL first, then write world-class).
-- BUILT ON (SCHEMA-FIRST LAW, read in full before writing): AD01 (forced RLS + p_installer, gapless SHA-256 chain under an advisory lock), AD02 (fadm_alert, closed ledger kinds, burst ceilings), AD03 (alert after-insert feed to the Bridge, service-health model),
--   AD07 (fadm_case, fadm_case_can, fadm_queue_unit, the Priority clock fadm_case_due index), AD09/AD09b (fadm_runbook_staff, tick chain), AD10 (event chain + frozen triggers pattern); the E-series (E111 1-minute telemetry buckets, advisory-lock sampling, retention note; E113 time machine).
-- WHAT IT ADDS (nothing of AD07 is changed):
--   1. fadm_queue_sample: an APPEND-ONLY 1-minute time series per queue (new/open/waiting/at_risk/oldest/arrived/answered), forced RLS, frozen triggers, its OWN SHA-256 hash chain (gapless under an advisory lock), BRIN index on the bucket, one row per queue per minute (UNIQUE).
--   2. fadm_queue_sample_take(): LAZY SAMPLER, no cron: the first reader of a minute writes the minute (pg_try_advisory_xact_lock, so two readers never double-write; a minute nobody read is an honest GAP, never back-filled). Restricted security cases are NOT in the series
--      (so a trend can never leak a case the reader may not see); billing is counted whole because the billing queue itself is gated.
--   3. fadm_queue_can(): queue-level read right = fadm_case_can without the per-case restricted clause (proved equal in the selftest). A queue the reader may not read is readable=false, level 'none', never a fake zero.
--   4. fadm_queue_level(): the team signal calm / busy / strained / overloaded from ONE documented IMMUTABLE rule (tested at every edge). It is a signal for the team, never a promise to a customer.
--   5. fadm_queue_pressure(): per queue live counts (permission per case), aging buckets (<15 min, <1 h, <4 h, <24 h, older), arrivals and first answers in the last hour, a 12-point sparkline (5-minute steps from the series, null = gap),
--      the trend (growing / steady / shrinking / unknown from the series), and an ESTIMATED clear time from the pace of the last hour (only when at least 3 answers happened; an estimate, never a promise).
--   6. fadm_sla_risk(): the Priority clock ends in under 15 minutes or has passed AND nobody answered; max 20, most urgent first; same permission per case.
--   7. OVERLOAD ALERT: when a queue becomes 'overloaded' the sampler raises ONE high alert 'queue.overload' (at most once per queue per 30 minutes); the existing AD03 feed carries it to the Urgent alerts card (the Bridge), no new plumbing.
--   8. fadm_queue_sample_chain_verify(): recomputes the whole series chain.
-- METADATA ONLY everywhere (counts, case references). No subject, address, company or thread. No money. Every helper is REVOKEd from PUBLIC (the AD1c lesson); desk_app gets the doors and the verify, never a table.
-- HONEST NOTE: about 5,760 rows a day (4 queues x 1,440 minutes) at most; BRIN keeps it light; a retention/roll-up step (E111 style prune) is a later, separate decision because the series is hash-chained.

CREATE TABLE IF NOT EXISTS desk.fadm_queue_sample (
  id         bigserial PRIMARY KEY,
  bucket     timestamptz NOT NULL CHECK (bucket = date_trunc('minute', bucket)),
  queue      text NOT NULL CHECK (queue IN ('general','support','movein','billing')),
  new_n      int NOT NULL CHECK (new_n >= 0),
  open_n     int NOT NULL CHECK (open_n >= 0),
  waiting_n  int NOT NULL CHECK (waiting_n >= 0),
  at_risk_n  int NOT NULL CHECK (at_risk_n >= 0),
  oldest_min int CHECK (oldest_min IS NULL OR oldest_min >= 0),
  arrived_n  int NOT NULL CHECK (arrived_n >= 0),
  answered_n int NOT NULL CHECK (answered_n >= 0),
  prev_hash  bytea NOT NULL DEFAULT sha256('x'::bytea),
  hash       bytea NOT NULL DEFAULT sha256('x'::bytea),
  UNIQUE (bucket, queue)
);
CREATE INDEX IF NOT EXISTS fadm_queue_sample_brin ON desk.fadm_queue_sample USING brin (bucket);
CREATE INDEX IF NOT EXISTS fadm_queue_sample_q ON desk.fadm_queue_sample (queue, bucket DESC);

CREATE OR REPLACE FUNCTION desk.fadm_queue_sample_chain() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_queue_sample'));
  SELECT hash INTO p FROM desk.fadm_queue_sample ORDER BY id DESC LIMIT 1;
  IF p IS NULL THEN p := sha256('anexomail-desk-queue-genesis'::bytea); END IF;
  NEW.prev_hash := p;
  NEW.hash := sha256(p || convert_to(NEW.bucket::text || '|' || NEW.queue || '|' || NEW.new_n || '|' || NEW.open_n || '|' || NEW.waiting_n || '|' || NEW.at_risk_n || '|' || COALESCE(NEW.oldest_min::text, '-') || '|' || NEW.arrived_n || '|' || NEW.answered_n, 'UTF8'));
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_queue_sample_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS fadm_queue_sample_chain ON desk.fadm_queue_sample;
CREATE TRIGGER fadm_queue_sample_chain BEFORE INSERT ON desk.fadm_queue_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_queue_sample_chain();
DROP TRIGGER IF EXISTS fadm_queue_sample_frozen ON desk.fadm_queue_sample;
CREATE TRIGGER fadm_queue_sample_frozen BEFORE UPDATE OR DELETE ON desk.fadm_queue_sample FOR EACH ROW EXECUTE FUNCTION desk.fadm_queue_sample_frozen();
DROP TRIGGER IF EXISTS fadm_queue_sample_frozen_t ON desk.fadm_queue_sample;
CREATE TRIGGER fadm_queue_sample_frozen_t BEFORE TRUNCATE ON desk.fadm_queue_sample FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_queue_sample_frozen();
DO $$ BEGIN
  ALTER TABLE desk.fadm_queue_sample ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.fadm_queue_sample FORCE ROW LEVEL SECURITY;
  REVOKE ALL ON desk.fadm_queue_sample FROM PUBLIC; REVOKE ALL ON desk.fadm_queue_sample FROM desk_app;
  DROP POLICY IF EXISTS p_installer ON desk.fadm_queue_sample; EXECUTE format('CREATE POLICY p_installer ON desk.fadm_queue_sample FOR ALL TO %I USING (true) WITH CHECK (true)', current_user);
END $$;
REVOKE ALL ON SEQUENCE desk.fadm_queue_sample_id_seq FROM PUBLIC;
REVOKE ALL ON FUNCTION desk.fadm_queue_sample_chain(), desk.fadm_queue_sample_frozen() FROM PUBLIC;

-- the team signal, ONE rule (IMMUTABLE, tested at every edge). p_open = cases that still need a first answer (new + open).
CREATE OR REPLACE FUNCTION desk.fadm_queue_level(p_open int, p_at_risk int, p_oldest int, p_arrived int, p_answered int) RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  SELECT CASE
    WHEN p_at_risk >= 3 OR COALESCE(p_oldest, 0) >= 1440 THEN 'overloaded'
    WHEN p_at_risk >= 1 OR COALESCE(p_oldest, 0) >= 240 OR (p_open >= 5 AND p_arrived > 2 * p_answered) THEN 'strained'
    WHEN p_open >= 5 OR COALESCE(p_oldest, 0) >= 60 THEN 'busy'
    ELSE 'calm' END $f$;

-- queue-level read right: fadm_case_can minus the per-case restricted clause (proved equal in the selftest)
CREATE OR REPLACE FUNCTION desk.fadm_queue_can(p_actor uuid, p_queue text) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE u uuid := desk.fadm_queue_unit(p_queue);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.fadm_owner o WHERE o.id = p_actor AND o.status = 'active') THEN RETURN false; END IF;
  IF p_queue = 'billing' THEN RETURN desk.fadm_mailbox_can_read(p_actor, 'billing') AND (SELECT allowed FROM desk.fadm_authorize(p_actor, 'case.read', desk.fadm_unit_id('department','desk'), NULL)); END IF;
  IF u IS NULL THEN RETURN false; END IF;
  RETURN (SELECT allowed FROM desk.fadm_authorize(p_actor, 'case.read', u, NULL));
END $f$;

-- the lazy sampler: the first reader of a minute writes it; nobody waits for anybody
CREATE OR REPLACE FUNCTION desk.fadm_queue_sample_take() RETURNS int LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE b timestamptz := date_trunc('minute', now()); q text; n int := 0; r record;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('desk.fadm_queue_sample.take')) THEN RETURN 0; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_queue_sample WHERE bucket = b) THEN RETURN 0; END IF;
  FOREACH q IN ARRAY ARRAY['general','support','movein','billing'] LOOP
    INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, oldest_min, arrived_n, answered_n)
    SELECT b, q,
      count(*) FILTER (WHERE c.status = 'new'), count(*) FILTER (WHERE c.status = 'open'), count(*) FILTER (WHERE c.status = 'waiting'),
      count(*) FILTER (WHERE c.status IN ('new','open','waiting') AND c.sla_due_at IS NOT NULL AND c.first_reply_at IS NULL AND c.sla_due_at < now() + interval '15 minutes'),
      floor(extract(epoch FROM now() - min(c.created_at) FILTER (WHERE c.status IN ('new','open'))) / 60)::int,
      count(*) FILTER (WHERE c.created_at > now() - interval '1 hour'), count(*) FILTER (WHERE c.first_reply_at > now() - interval '1 hour')
    FROM desk.fadm_case c WHERE c.queue = q AND (q = 'billing' OR NOT c.restricted) AND (c.status IN ('new','open','waiting') OR c.created_at > now() - interval '1 hour' OR c.first_reply_at > now() - interval '1 hour');
    n := n + 1;
  END LOOP;
  -- ONE overload alert per queue per 30 minutes (the AD03 feed carries it to the Urgent alerts card)
  FOR r IN SELECT s.queue, s.new_n + s.open_n AS need, s.at_risk_n, s.oldest_min FROM desk.fadm_queue_sample s WHERE s.bucket = b
            AND desk.fadm_queue_level(s.new_n + s.open_n, s.at_risk_n, s.oldest_min, s.arrived_n, s.answered_n) = 'overloaded' LOOP
    IF NOT EXISTS (SELECT 1 FROM desk.fadm_alert a WHERE a.kind = 'queue.overload' AND a.detail->>'queue' = r.queue AND a.at > now() - interval '30 minutes') THEN
      INSERT INTO desk.fadm_alert (severity, kind, detail) VALUES ('high', 'queue.overload', jsonb_build_object('queue', r.queue, 'waiting', r.need, 'at_risk', r.at_risk_n, 'oldest_minutes', r.oldest_min));
    END IF;
  END LOOP;
  RETURN n;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_queue_sample_chain_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE p bytea := sha256('anexomail-desk-queue-genesis'::bytea); r record;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_queue_sample ORDER BY id LOOP
    IF r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.bucket::text || '|' || r.queue || '|' || r.new_n || '|' || r.open_n || '|' || r.waiting_n || '|' || r.at_risk_n || '|' || COALESCE(r.oldest_min::text, '-') || '|' || r.arrived_n || '|' || r.answered_n, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_queue_pressure(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE q text; res jsonb := '[]'::jsonb; nn int; oo int; ww int; rk int; old int; arr int; ans int; a0 int; a1 int; a2 int; a3 int; a4 int; sp jsonb; tr text; clr int; cur int; prv int; need int; nowb timestamptz := date_trunc('minute', now());
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  PERFORM desk.fadm_queue_sample_take();
  FOREACH q IN ARRAY ARRAY['general','support','movein','billing'] LOOP
    IF NOT desk.fadm_queue_can(p_actor, q) THEN
      res := res || jsonb_build_array(jsonb_build_object('queue', q, 'readable', false, 'new', 0, 'open', 0, 'waiting', 0, 'at_risk', 0, 'oldest_minutes', NULL, 'arrived_60m', 0, 'answered_60m', 0,
        'ages', jsonb_build_array(0,0,0,0,0), 'spark', jsonb_build_array(NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL), 'trend', 'unknown', 'clear_minutes', NULL, 'level', 'none'));
      CONTINUE;
    END IF;
    SELECT count(*) FILTER (WHERE v.status = 'new'), count(*) FILTER (WHERE v.status = 'open'), count(*) FILTER (WHERE v.status = 'waiting'),
           count(*) FILTER (WHERE v.sla_due_at IS NOT NULL AND v.first_reply_at IS NULL AND v.sla_due_at < now() + interval '15 minutes'),
           count(*) FILTER (WHERE v.status IN ('new','open') AND v.age_m < 15), count(*) FILTER (WHERE v.status IN ('new','open') AND v.age_m >= 15 AND v.age_m < 60),
           count(*) FILTER (WHERE v.status IN ('new','open') AND v.age_m >= 60 AND v.age_m < 240), count(*) FILTER (WHERE v.status IN ('new','open') AND v.age_m >= 240 AND v.age_m < 1440),
           count(*) FILTER (WHERE v.status IN ('new','open') AND v.age_m >= 1440),
           floor(max(v.age_m) FILTER (WHERE v.status IN ('new','open')))::int
      INTO nn, oo, ww, rk, a0, a1, a2, a3, a4, old
      FROM (SELECT c.status, c.sla_due_at, c.first_reply_at, extract(epoch FROM now() - c.created_at) / 60 AS age_m FROM desk.fadm_case c
             WHERE c.queue = q AND c.status IN ('new','open','waiting') AND desk.fadm_case_can(p_actor, c, 'case.read', NULL)) v;
    SELECT count(*) FILTER (WHERE x.created_at > now() - interval '1 hour'), count(*) FILTER (WHERE x.first_reply_at > now() - interval '1 hour') INTO arr, ans
      FROM desk.fadm_case x WHERE x.queue = q AND (x.created_at > now() - interval '1 hour' OR x.first_reply_at > now() - interval '1 hour') AND desk.fadm_case_can(p_actor, x, 'case.read', NULL);
    SELECT COALESCE(jsonb_agg(z.v ORDER BY z.g), '[]'::jsonb) INTO sp FROM (SELECT g, (SELECT s.new_n + s.open_n + s.waiting_n FROM desk.fadm_queue_sample s WHERE s.queue = q
        AND s.bucket <= nowb - make_interval(mins => (11 - g) * 5) AND s.bucket > nowb - make_interval(mins => (11 - g) * 5 + 5) ORDER BY s.bucket DESC LIMIT 1) AS v FROM generate_series(0, 11) g) z;
    SELECT s.new_n + s.open_n + s.waiting_n INTO cur FROM desk.fadm_queue_sample s WHERE s.queue = q AND s.bucket > nowb - interval '5 minutes' ORDER BY s.bucket DESC LIMIT 1;
    SELECT s.new_n + s.open_n + s.waiting_n INTO prv FROM desk.fadm_queue_sample s WHERE s.queue = q AND s.bucket BETWEEN nowb - interval '65 minutes' AND nowb - interval '55 minutes' ORDER BY abs(extract(epoch FROM s.bucket - (nowb - interval '60 minutes'))) LIMIT 1;
    tr := CASE WHEN cur IS NULL OR prv IS NULL THEN 'unknown' WHEN cur - prv >= 2 THEN 'growing' WHEN cur - prv <= -2 THEN 'shrinking' ELSE 'steady' END;
    need := nn + oo;
    clr := CASE WHEN need > 0 AND ans >= 3 THEN least(ceil(need * 60.0 / ans)::int, 10080) ELSE NULL END;
    res := res || jsonb_build_array(jsonb_build_object('queue', q, 'readable', true, 'new', nn, 'open', oo, 'waiting', ww, 'at_risk', rk, 'oldest_minutes', old, 'arrived_60m', arr, 'answered_60m', ans,
      'ages', jsonb_build_array(a0, a1, a2, a3, a4), 'spark', sp, 'trend', tr, 'clear_minutes', clr, 'level', desk.fadm_queue_level(need, rk, old, arr, ans)));
  END LOOP;
  RETURN jsonb_build_object('generated_at', now(), 'risk_window_minutes', 15, 'queues', res);
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_sla_risk(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('generated_at', now(), 'risk_window_minutes', 15, 'cases', COALESCE((SELECT jsonb_agg(jsonb_build_object('ref', x.ref, 'queue', x.queue, 'minutes_left', x.mins, 'overdue', x.mins < 0) ORDER BY x.mins, x.ref)
    FROM (SELECT c.ref, c.queue, floor(extract(epoch FROM c.sla_due_at - now()) / 60)::int AS mins FROM desk.fadm_case c
           WHERE c.status IN ('new','open','waiting') AND c.sla_due_at IS NOT NULL AND c.first_reply_at IS NULL AND c.sla_due_at < now() + interval '15 minutes'
             AND desk.fadm_case_can(p_actor, c, 'case.read', NULL) ORDER BY c.sla_due_at LIMIT 20) x), '[]'::jsonb));
END $f$;

REVOKE ALL ON FUNCTION desk.fadm_queue_level(int,int,int,int,int), desk.fadm_queue_can(uuid,text), desk.fadm_queue_sample_take(), desk.fadm_queue_sample_chain_verify(), desk.fadm_queue_pressure(uuid), desk.fadm_sla_risk(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_queue_pressure(uuid), desk.fadm_sla_risk(uuid), desk.fadm_queue_sample_chain_verify() TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AK2) -------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad11_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD11 selftest: %', msg USING ERRCODE = 'P0AK1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; m1 uuid; sfx text := substr(md5(random()::text), 1, 8); sup uuid := desk.fadm_unit_id('team','support'); mig uuid := desk.fadm_unit_id('team','migration');
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; cs uuid; cp uuid; cp2 uuid; cp3 uuid; cm uuid; cb uuid; r jsonb; s jsonb; n0 int; sq jsonb; c0 int; ca uuid; nsamp int; nal int; rowc record; b0 timestamptz := date_trunc('minute', now());
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o11-' || sfx || '@selftest.invalid', 'AD11 Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a11-' || sfx || '@selftest.invalid', 'AD11 Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('m11-' || sfx || '@selftest.invalid', 'AD11 Move', 'agent', NULL, true, 'active', true) RETURNING id INTO m1;
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent'); PERFORM desk.fadm_access_grant(o, m1, mig, 'agent');
  -- the team signal: every edge of the ONE rule
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_level(0,0,NULL,0,0) = 'calm' AND desk.fadm_queue_level(4,0,59,0,0) = 'calm', 'level calm');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_level(5,0,10,0,0) = 'busy' AND desk.fadm_queue_level(1,0,60,0,0) = 'busy', 'level busy (5 waiting or 1 hour old)');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_level(1,1,5,0,0) = 'strained' AND desk.fadm_queue_level(1,0,240,0,0) = 'strained' AND desk.fadm_queue_level(5,0,10,3,1) = 'strained' AND desk.fadm_queue_level(5,0,10,2,1) = 'busy', 'level strained (one at risk, 4 hours, arrivals over twice the answers)');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_level(1,3,5,0,0) = 'overloaded' AND desk.fadm_queue_level(1,2,5,0,0) = 'strained' AND desk.fadm_queue_level(1,0,1440,0,0) = 'overloaded', 'level overloaded (three at risk or a day old)');
  -- cases: support (new), a Priority one, a move-in one, a billing one (restricted by the AD07 rule)
  cs := desk.fadm_case_ingest('resolved', 'ad11-thread-1', 'I cannot sign in', 'co_selftest_11');
  cp := desk.fadm_case_ingest('resolved', 'ad11-thread-2', 'Urgent mail problem', 'co_selftest_12', true);
  cp2 := desk.fadm_case_ingest('resolved', 'ad11-thread-5', 'Urgent two', 'co_selftest_14', true);
  cp3 := desk.fadm_case_ingest('resolved', 'ad11-thread-6', 'Urgent three', 'co_selftest_15', true);
  cm := desk.fadm_case_ingest('moveyourbusiness', 'ad11-thread-3', 'Move 12 mailboxes', 'co_selftest_13');
  cb := desk.fadm_case_ingest('billing', 'ad11-thread-4', 'A question about my account');
  ca := desk.fadm_case_ingest('abuse', 'ad11-thread-7', 'Phishing report');                       -- restricted security label in the support queue
  -- queue-level right equals the per-case right on an ordinary case, and is false where the person has no grant
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_can(a1, 'support') = desk.fadm_case_can(a1, (SELECT c FROM desk.fadm_case c WHERE id = cs), 'case.read', NULL) AND desk.fadm_queue_can(a1, 'support'), 'queue right = case right (support agent)');
  PERFORM pg_temp.ad11_ok(NOT desk.fadm_queue_can(a1, 'movein') AND NOT desk.fadm_queue_can(a1, 'billing') AND desk.fadm_queue_can(m1, 'movein') AND NOT desk.fadm_queue_can(m1, 'support') AND NOT desk.fadm_queue_can(gen_random_uuid(), 'support'), 'queue right: no grant, no right; unknown person, no right');
  -- three Priority cases close to their target -> the support queue is OVERLOADED -> the first reader writes the minute and ONE alert
  UPDATE desk.fadm_case SET sla_due_at = now() + interval '10 minutes' WHERE id IN (cp, cp2, cp3);
  nal := (SELECT count(*) FROM desk.fadm_alert WHERE kind = 'queue.overload');
  nsamp := desk.fadm_queue_sample_take();
  PERFORM pg_temp.ad11_ok(nsamp = 4 AND (SELECT count(*) FROM desk.fadm_queue_sample WHERE bucket = b0) = 4, 'the sampler writes the four queues of this minute');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_sample_take() = 0, 'the second reader of the same minute writes nothing');
  PERFORM pg_temp.ad11_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'queue.overload') = nal + 1 AND EXISTS (SELECT 1 FROM desk.fadm_alert WHERE kind = 'queue.overload' AND severity = 'high' AND detail->>'queue' = 'support' AND (detail->>'at_risk')::int >= 3), 'an overloaded queue raised ONE high alert for the Urgent alerts card');
  PERFORM pg_temp.ad11_ok((SELECT new_n + open_n + waiting_n FROM desk.fadm_queue_sample WHERE bucket = b0 AND queue = 'support') = 4, 'the series leaves out the restricted security case (4 support cases, not 5)');
  PERFORM pg_temp.ad11_ok((SELECT new_n FROM desk.fadm_queue_sample WHERE bucket = b0 AND queue = 'billing') >= 1, 'the billing queue is counted whole');
  -- who sees what in the answer
  r := desk.fadm_queue_pressure(a1);
  PERFORM pg_temp.ad11_ok(jsonb_array_length(r->'queues') = 4 AND r->'queues'->0->>'queue' = 'general' AND r->'queues'->3->>'queue' = 'billing', 'four queues, fixed order');
  PERFORM pg_temp.ad11_ok((r->'queues'->1->>'readable')::boolean AND (r->'queues'->1->>'level') = 'overloaded' AND (r->'queues'->1->>'at_risk')::int = 3, 'a support agent reads support: overloaded, 3 at risk');
  PERFORM pg_temp.ad11_ok(NOT (r->'queues'->2->>'readable')::boolean AND r->'queues'->2->>'level' = 'none' AND NOT (r->'queues'->3->>'readable')::boolean, 'a queue the person may not read is readable=false and level none (never a fake zero)');
  PERFORM pg_temp.ad11_ok((r->'queues'->1->>'new')::int + (r->'queues'->1->>'open')::int >= 4 AND (SELECT sum(x::int) FROM jsonb_array_elements_text(r->'queues'->1->'ages') x) = (r->'queues'->1->>'new')::int + (r->'queues'->1->>'open')::int, 'the aging buckets add up to the cases that need an answer');
  PERFORM pg_temp.ad11_ok(jsonb_array_length(r->'queues'->1->'spark') = 12 AND (r->'queues'->1->'spark'->>11)::int = 4 AND r->'queues'->1->>'trend' = 'unknown', 'sparkline has 12 points, the latest is this minute, the trend is unknown with no history');
  PERFORM pg_temp.ad11_ok(r::text !~* '(subject|address|company|thread|sign in|mailboxes|phishing)', 'metadata only: no subject, address, company or thread in the answer');
  PERFORM pg_temp.ad11_ok((desk.fadm_queue_pressure(m1)->'queues'->2->>'readable')::boolean AND NOT (desk.fadm_queue_pressure(m1)->'queues'->1->>'readable')::boolean, 'a move-in agent reads move-in only');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_pressure(gen_random_uuid()) IS NULL AND desk.fadm_sla_risk(gen_random_uuid()) IS NULL, 'an unknown person gets nothing (NULL)');
  -- the trend: a history of the support queue an hour ago (rows inserted through the chain) -> growing / shrinking / steady
  INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, oldest_min, arrived_n, answered_n) VALUES (b0 - interval '60 minutes', 'support', 0, 0, 0, 0, NULL, 0, 0);
  r := desk.fadm_queue_pressure(a1);
  PERFORM pg_temp.ad11_ok(r->'queues'->1->>'trend' = 'growing', '4 now, 0 an hour ago: growing');
  -- an older, bigger history row (61 minutes ago): the nearest row to 60 minutes ago still decides the trend
  INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, oldest_min, arrived_n, answered_n) VALUES (b0 - interval '61 minutes', 'support', 9, 0, 0, 0, 9, 0, 0);
  -- the clear-time estimate needs at least 3 answers in the last hour
  PERFORM pg_temp.ad11_ok(r->'queues'->1->'clear_minutes' = 'null'::jsonb, 'no estimate with fewer than 3 answers (nothing invented)');
  -- a first answer takes the case off the at-risk list and off the queue count that needs an answer
  PERFORM desk.fadm_case_assign(a1, cp, a1); PERFORM desk.fadm_case_reply(a1, cp);
  s := desk.fadm_sla_risk(a1);
  PERFORM pg_temp.ad11_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp)) AND jsonb_array_length(s->'cases') = 2, 'the first answer takes the case off the at-risk list');
  UPDATE desk.fadm_case SET sla_due_at = now() - interval '5 minutes' WHERE id = cp2;
  s := desk.fadm_sla_risk(a1);
  PERFORM pg_temp.ad11_ok((SELECT count(*) FROM jsonb_array_elements(s->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp2) AND (e->>'overdue')::boolean) = 1 AND s->'cases'->0->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp2), 'a passed clock is overdue and listed first');
  PERFORM pg_temp.ad11_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(desk.fadm_sla_risk(m1)->'cases') e WHERE e->>'queue' = 'support'), 'a move-in agent does not see support at-risk cases');
  -- the series is append-only and its chain verifies
  BEGIN UPDATE desk.fadm_queue_sample SET new_n = 99; RAISE EXCEPTION 'no refusal 1' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_queue_sample; RAISE EXCEPTION 'no refusal 2' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_queue_sample; RAISE EXCEPTION 'no refusal 3' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, arrived_n, answered_n) VALUES (b0 + interval '1 second' + interval '3 minutes', 'support', 0, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 4' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, arrived_n, answered_n) VALUES (b0, 'support', 0, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 5' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, arrived_n, answered_n) VALUES (b0 - interval '90 minutes', 'other', 0, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 6' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO desk.fadm_queue_sample (bucket, queue, new_n, open_n, waiting_n, at_risk_n, arrived_n, answered_n) VALUES (b0 - interval '91 minutes', 'support', -1, 0, 0, 0, 0, 0); RAISE EXCEPTION 'no refusal 7' USING ERRCODE = 'P0AK1'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_sample_chain_verify(), 'the series chain verifies');
  PERFORM pg_temp.ad11_ok(has_function_privilege('desk_app', 'desk.fadm_queue_pressure(uuid)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_sla_risk(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_queue_sample_take()', 'EXECUTE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_queue_sample', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_case', 'SELECT'), 'desk_app has the doors and the verify, never the sampler or a table');
  PERFORM pg_temp.ad11_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD11 selftest passed, rolling back' USING ERRCODE = 'P0AK2';
EXCEPTION WHEN SQLSTATE 'P0AK2' THEN RAISE NOTICE 'AD11 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
