-- AD11 (phase 1m, cards B1 Queue pressure + B2 SLA at risk), 23 Nov 2026 05:2x PKT. SCHEMA-FIRST: AD07 (fadm_case, fadm_case_can, fadm_case_list, fadm_queue_unit) was read first; nothing of it is changed.
-- Two READ-ONLY doors for the Dashboard: counts and a short list. They show ONLY what the asking person may already read (fadm_case_can per case), and METADATA only (no subject, no address, no company).
-- At risk = the Priority clock (sla_due_at) ends in under 15 minutes or has passed, and nobody has answered. 15 minutes is a WARNING WINDOW, never a promise to a customer.
-- No money anywhere. The helper is REVOKEd from PUBLIC (the AD1c lesson); desk_app gets the two doors only.
CREATE OR REPLACE FUNCTION desk.fadm_queue_pressure(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE j jsonb;
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  WITH v AS (SELECT c.* FROM desk.fadm_case c WHERE c.status IN ('new','open','waiting') AND desk.fadm_case_can(p_actor, c, 'case.read', NULL)),
       q AS (SELECT unnest(ARRAY['general','support','movein','billing']) AS queue, generate_series(1,4) AS sort)
  SELECT jsonb_build_object('generated_at', now(), 'risk_window_minutes', 15, 'queues', COALESCE(jsonb_agg(jsonb_build_object(
      'queue', q.queue,
      'new',      (SELECT count(*) FROM v WHERE v.queue = q.queue AND v.status = 'new'),
      'open',     (SELECT count(*) FROM v WHERE v.queue = q.queue AND v.status = 'open'),
      'waiting',  (SELECT count(*) FROM v WHERE v.queue = q.queue AND v.status = 'waiting'),
      'at_risk',  (SELECT count(*) FROM v WHERE v.queue = q.queue AND v.sla_due_at IS NOT NULL AND v.first_reply_at IS NULL AND v.sla_due_at < now() + interval '15 minutes'),
      'oldest_minutes', (SELECT floor(extract(epoch FROM now() - min(v.created_at)) / 60)::int FROM v WHERE v.queue = q.queue AND v.status IN ('new','open'))
    ) ORDER BY q.sort), '[]'::jsonb)) INTO j FROM q;
  RETURN j;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_sla_risk(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('generated_at', now(), 'risk_window_minutes', 15, 'cases', COALESCE((SELECT jsonb_agg(jsonb_build_object('ref', x.ref, 'queue', x.queue, 'minutes_left', x.mins, 'overdue', x.mins < 0) ORDER BY x.mins, x.ref)
    FROM (SELECT c.ref, c.queue, floor(extract(epoch FROM c.sla_due_at - now()) / 60)::int AS mins FROM desk.fadm_case c
           WHERE c.status IN ('new','open','waiting') AND c.sla_due_at IS NOT NULL AND c.first_reply_at IS NULL AND c.sla_due_at < now() + interval '15 minutes'
             AND desk.fadm_case_can(p_actor, c, 'case.read', NULL) ORDER BY c.sla_due_at LIMIT 20) x), '[]'::jsonb));
END $f$;
REVOKE ALL ON FUNCTION desk.fadm_queue_pressure(uuid), desk.fadm_sla_risk(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_queue_pressure(uuid), desk.fadm_sla_risk(uuid) TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AK2) -------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad11_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD11 selftest: %', msg USING ERRCODE = 'P0AK1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; m1 uuid; sfx text := substr(md5(random()::text), 1, 8); sup uuid := desk.fadm_unit_id('team','support'); mig uuid := desk.fadm_unit_id('team','migration');
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; cs uuid; cp uuid; cm uuid; cb uuid; r jsonb; s jsonb; n0 int;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o11-' || sfx || '@selftest.invalid', 'AD11 Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a11-' || sfx || '@selftest.invalid', 'AD11 Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('m11-' || sfx || '@selftest.invalid', 'AD11 Move', 'agent', NULL, true, 'active', true) RETURNING id INTO m1;
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent'); PERFORM desk.fadm_access_grant(o, m1, mig, 'agent');
  n0 := COALESCE((desk.fadm_queue_pressure(a1)->'queues'->1->>'new')::int, 0);                      -- support "new" before our cases (the scratch may hold other rows)
  cs := desk.fadm_case_ingest('resolved', 'ad11-thread-1', 'I cannot sign in', 'co_selftest_11');
  cp := desk.fadm_case_ingest('resolved', 'ad11-thread-2', 'Urgent mail problem', 'co_selftest_12', true);
  cm := desk.fadm_case_ingest('moveyourbusiness', 'ad11-thread-3', 'Move 12 mailboxes', 'co_selftest_13');
  cb := desk.fadm_case_ingest('billing', 'ad11-thread-4', 'A question about my account');
  r := desk.fadm_queue_pressure(a1);
  PERFORM pg_temp.ad11_ok(jsonb_array_length(r->'queues') = 4 AND r->'queues'->0->>'queue' = 'general' AND r->'queues'->3->>'queue' = 'billing', 'four queues, fixed order');
  PERFORM pg_temp.ad11_ok((r->'queues'->1->>'new')::int = n0 + 2, 'a support agent counts the two new support cases');
  PERFORM pg_temp.ad11_ok((r->'queues'->2->>'new')::int = 0 AND (r->'queues'->3->>'new')::int = 0, 'a support agent sees nothing of move-in or billing (permission per case)');
  PERFORM pg_temp.ad11_ok((desk.fadm_queue_pressure(m1)->'queues'->2->>'new')::int = 1, 'a move-in agent counts the move-in case');
  PERFORM pg_temp.ad11_ok(desk.fadm_queue_pressure(gen_random_uuid()) IS NULL AND desk.fadm_sla_risk(gen_random_uuid()) IS NULL, 'an unknown person gets nothing (NULL)');
  PERFORM pg_temp.ad11_ok(r::text !~* '(subject|address|company|thread|sign in|mailboxes)', 'metadata only: no subject, address, company or thread in the answer');
  -- the Priority clock: far away = not at risk; 10 minutes left = at risk; already passed = overdue
  s := desk.fadm_sla_risk(a1);
  PERFORM pg_temp.ad11_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(s->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp)), 'a 2-business-day clock is not at risk');
  UPDATE desk.fadm_case SET sla_due_at = now() + interval '10 minutes' WHERE id = cp;
  s := desk.fadm_sla_risk(a1);
  PERFORM pg_temp.ad11_ok((SELECT bool_and(e->>'ref' <> '') AND count(*) >= 1 FROM jsonb_array_elements(s->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp) AND (e->>'minutes_left')::int BETWEEN 8 AND 10 AND (e->>'overdue')::boolean = false), '10 minutes left is at risk, not overdue');
  PERFORM pg_temp.ad11_ok((desk.fadm_queue_pressure(a1)->'queues'->1->>'at_risk')::int >= 1, 'the queue count shows the at-risk case');
  UPDATE desk.fadm_case SET sla_due_at = now() - interval '5 minutes' WHERE id = cp;
  s := desk.fadm_sla_risk(a1);
  PERFORM pg_temp.ad11_ok((SELECT count(*) FROM jsonb_array_elements(s->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp) AND (e->>'overdue')::boolean) = 1, 'a passed clock is overdue');
  PERFORM pg_temp.ad11_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(desk.fadm_sla_risk(m1)->'cases') e WHERE e->>'queue' = 'support'), 'a move-in agent does not see support at-risk cases');
  PERFORM desk.fadm_case_assign(a1, cp, a1); PERFORM desk.fadm_case_reply(a1, cp);
  PERFORM pg_temp.ad11_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(desk.fadm_sla_risk(a1)->'cases') e WHERE e->>'ref' = (SELECT ref FROM desk.fadm_case WHERE id = cp)), 'the first answer takes the case off the at-risk list');
  PERFORM pg_temp.ad11_ok(has_function_privilege('desk_app', 'desk.fadm_queue_pressure(uuid)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_sla_risk(uuid)', 'EXECUTE') AND NOT has_table_privilege('desk_app', 'desk.fadm_case', 'SELECT'), 'desk_app has the two doors and no table right');
  RAISE EXCEPTION 'AD11 selftest passed, rolling back' USING ERRCODE = 'P0AK2';
EXCEPTION WHEN SQLSTATE 'P0AK2' THEN RAISE NOTICE 'AD11 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
