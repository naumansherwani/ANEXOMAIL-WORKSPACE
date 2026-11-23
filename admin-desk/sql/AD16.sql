-- AD16 (phase 1m-6, card B10 Reports), 23 Nov 2026 09:2x PKT. THE ADVANCED VERSION (his 09:09 order: world-class SQL every time).
-- SCHEMA-FIRST: (read in full before writing) AD07 (fadm_case: queue, status, priority, restricted, created_at, first_reply_at, sla_due_at; fadm_case_event: append-only, kind status with detail from/to, kind reply), AD11 (fadm_queue_can: the queue-level read right; restricted cases are never counted in a series, billing is counted whole because the billing queue itself is gated), AD01/AD02 (fadm_authorize, fadm_owner).
-- ADVANCE-RESEARCH: [1m] support reporting as the best desks define it (Zendesk Explore / Front / Intercom: tickets created, solved, backlog, first reply time, full resolution time, reopens, priority target hit rate; medians and p90, never averages that one slow case can ruin), computed from the append-only event history so a number is always re-derivable, set-based single pass, permission per queue, counts and minutes only (list D6-CARDS-LIST-23NOV.md section B10 V1..V8).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD16-check.sql
-- WHAT IT ADDS (nothing of AD07 or AD11 is changed):
--   1. Two read indexes (fadm_case(created_at), fadm_case_event(kind, at)) so a 30-day report is an index range scan, never a table scan, when the desk is big.
--   2. fadm_reports(actor) -> jsonb: ONLY the queues the person may read (fadm_queue_can); a person who may read none gets NULL (the door answers 403, never a fake zero). Restricted cases are left out except in the billing queue, exactly like AD11.
--      Content: backlog now (new / open / waiting); 14 UTC days of created, solved (moves to resolved) and end-of-day backlog (rebuilt from the event history); first reply time (cases, replied, unanswered, median and p90 minutes);
--      full resolution time (cases first resolved in 30 days, median and p90 minutes); reopened in 30 days; Priority target (total, answered in time, late, still inside the target); and per readable queue created / solved / backlog. queues_counted and queues_hidden say how much the reader sees.
--   No case reference, subject, company, address or person ever leaves this function: counts and minutes only. median/p90 are NULL only when no case exists to measure (the counts beside them say 0); a zero count is always a real 0.
--   CSAT is NOT in this step: no survey table exists yet, so nothing is invented (step B10b when the survey exists).
CREATE INDEX IF NOT EXISTS fadm_case_created ON desk.fadm_case (created_at);
CREATE INDEX IF NOT EXISTS fadm_case_event_kind_at ON desk.fadm_case_event (kind, at);

CREATE OR REPLACE FUNCTION desk.fadm_reports(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '8s' SET lock_timeout = '2s' AS $f$
DECLARE qs text[]; d0 date := (now() AT TIME ZONE 'utc')::date; r jsonb;
BEGIN
  SELECT COALESCE(array_agg(q ORDER BY array_position(ARRAY['general','support','movein','billing'], q)), '{}') INTO qs FROM unnest(ARRAY['general','support','movein','billing']) q WHERE desk.fadm_queue_can(p_actor, q);
  IF cardinality(qs) = 0 THEN RETURN NULL; END IF;
  WITH
  c AS (SELECT id, queue, priority, status, created_at, first_reply_at, sla_due_at FROM desk.fadm_case WHERE queue = ANY (qs) AND (NOT restricted OR queue = 'billing')),
  days AS (SELECT g::date AS d FROM generate_series(d0 - 13, d0, interval '1 day') g),
  stc AS (SELECT e.case_id, e.at, e.detail->>'from' AS f, e.detail->>'to' AS t FROM desk.fadm_case_event e JOIN c ON c.id = e.case_id WHERE e.kind = 'status'),
  res1 AS (SELECT case_id, min(at) AS at FROM stc WHERE t = 'resolved' GROUP BY case_id),
  daily AS (
    SELECT dd.d,
      (SELECT count(*) FROM c WHERE c.created_at >= dd.d::timestamptz AND c.created_at < (dd.d + 1)::timestamptz)::int AS created,
      (SELECT count(*) FROM stc WHERE stc.t = 'resolved' AND stc.at >= dd.d::timestamptz AND stc.at < (dd.d + 1)::timestamptz)::int AS solved,
      (SELECT count(*) FROM c WHERE c.created_at < (dd.d + 1)::timestamptz
          AND COALESCE((SELECT s2.t FROM stc s2 WHERE s2.case_id = c.id AND s2.at < (dd.d + 1)::timestamptz ORDER BY s2.at DESC LIMIT 1), 'new') NOT IN ('resolved', 'closed'))::int AS backlog
    FROM days dd),
  fr AS (SELECT count(*)::int AS n, count(first_reply_at)::int AS replied,
           percentile_cont(ARRAY[0.5, 0.9]) WITHIN GROUP (ORDER BY extract(epoch FROM first_reply_at - created_at) / 60) AS p
         FROM c WHERE created_at >= now() - interval '30 days'),
  rs AS (SELECT count(*)::int AS n, percentile_cont(ARRAY[0.5, 0.9]) WITHIN GROUP (ORDER BY extract(epoch FROM r1.at - c.created_at) / 60) AS p
         FROM res1 r1 JOIN c ON c.id = r1.case_id WHERE r1.at >= now() - interval '30 days'),
  pr AS (SELECT count(*)::int AS total,
           count(*) FILTER (WHERE first_reply_at IS NOT NULL AND first_reply_at <= sla_due_at)::int AS in_time,
           count(*) FILTER (WHERE (first_reply_at IS NOT NULL AND first_reply_at > sla_due_at) OR (first_reply_at IS NULL AND now() > sla_due_at))::int AS late
         FROM c WHERE priority AND created_at >= now() - interval '30 days')
  SELECT jsonb_build_object(
    'generated_at', to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'queues_counted', cardinality(qs), 'queues_hidden', 4 - cardinality(qs),
    'backlog', jsonb_build_object('new', (SELECT count(*) FROM c WHERE status = 'new')::int, 'open', (SELECT count(*) FROM c WHERE status = 'open')::int, 'waiting', (SELECT count(*) FROM c WHERE status = 'waiting')::int),
    'daily', jsonb_build_object('created', (SELECT jsonb_agg(created ORDER BY d) FROM daily), 'solved', (SELECT jsonb_agg(solved ORDER BY d) FROM daily), 'backlog', (SELECT jsonb_agg(backlog ORDER BY d) FROM daily)),
    'first_reply', (SELECT jsonb_build_object('cases', n, 'replied', replied, 'unanswered', n - replied, 'median_min', CASE WHEN replied > 0 THEN round((p)[1])::int END, 'p90_min', CASE WHEN replied > 0 THEN round((p)[2])::int END) FROM fr),
    'resolution', (SELECT jsonb_build_object('solved', n, 'median_min', CASE WHEN n > 0 THEN round((p)[1])::int END, 'p90_min', CASE WHEN n > 0 THEN round((p)[2])::int END) FROM rs),
    'reopened_30d', (SELECT count(*) FROM stc WHERE f = 'resolved' AND t = 'open' AND at >= now() - interval '30 days')::int,
    'priority', (SELECT jsonb_build_object('total', total, 'in_time', in_time, 'late', late, 'waiting', total - in_time - late) FROM pr),
    'queues', (SELECT COALESCE(jsonb_agg(jsonb_build_object('queue', q,
        'created', (SELECT count(*) FROM c WHERE c.queue = q AND c.created_at >= now() - interval '30 days')::int,
        'solved', (SELECT count(*) FROM res1 r1 JOIN c ON c.id = r1.case_id WHERE c.queue = q AND r1.at >= now() - interval '30 days')::int,
        'backlog', (SELECT count(*) FROM c WHERE c.queue = q AND c.status IN ('new', 'open', 'waiting'))::int) ORDER BY array_position(qs, q)), '[]'::jsonb) FROM unnest(qs) q))
  INTO r;
  RETURN r;
END $f$;

COMMENT ON FUNCTION desk.fadm_reports(uuid) IS 'AD16 (B10 Reports): counts and minutes only, per readable queue (fadm_queue_can), restricted cases left out except billing, 14 UTC days rebuilt from the append-only event history, medians and p90, 8 s statement / 2 s lock timeout. NULL when the person may read no queue.';
REVOKE ALL ON FUNCTION desk.fadm_reports(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_reports(uuid) TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AP2). It runs on the LIVE database too, so every count is a DELTA of what the test adds.
CREATE FUNCTION pg_temp.ad16_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD16 selftest: %', msg USING ERRCODE = 'P0AP1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; a2 uuid; sfx text := substr(md5(random()::text), 1, 8); sup uuid := desk.fadm_unit_id('team','support'); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
  cs uuid; cs2 uuid; cs3 uuid; cp uuid; cm uuid; ca uuid; r0 jsonb; r1 jsonb;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o16-' || sfx || '@selftest.invalid', 'AD16 Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a16-' || sfx || '@selftest.invalid', 'AD16 Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('b16-' || sfx || '@selftest.invalid', 'AD16 NoGrant', 'agent', NULL, true, 'active', true) RETURNING id INTO a2;
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent');
  PERFORM pg_temp.ad16_ok(desk.fadm_reports(a2) IS NULL AND desk.fadm_reports(gen_random_uuid()) IS NULL, 'a person with no queue right and an unknown person get NULL, never a fake zero');
  r0 := desk.fadm_reports(a1);
  PERFORM pg_temp.ad16_ok(r0 IS NOT NULL AND (r0->>'queues_counted')::int = 2 AND (r0->>'queues_hidden')::int = 2 AND jsonb_array_length(r0->'daily'->'created') = 14 AND jsonb_array_length(r0->'daily'->'solved') = 14 AND jsonb_array_length(r0->'daily'->'backlog') = 14, 'a support agent reads two queues (general, support), hides two, and gets three 14-day lines');
  -- four support cases (one Priority), a move-in case and a restricted security case that must NOT be counted for this reader
  cs := desk.fadm_case_ingest('resolved', 'ad16-thread-1', 'Sign in problem one', 'co_selftest_16');
  cs2 := desk.fadm_case_ingest('resolved', 'ad16-thread-2', 'Sign in problem two', 'co_selftest_17');
  cs3 := desk.fadm_case_ingest('resolved', 'ad16-thread-3', 'Sign in problem three', 'co_selftest_18');
  cp := desk.fadm_case_ingest('resolved', 'ad16-thread-4', 'Urgent problem', 'co_selftest_19', true);
  cm := desk.fadm_case_ingest('moveyourbusiness', 'ad16-thread-5', 'Move mailboxes', 'co_selftest_20');
  ca := desk.fadm_case_ingest('abuse', 'ad16-thread-6', 'Phishing report');
  PERFORM desk.fadm_case_assign(a1, cs, a1); PERFORM desk.fadm_case_reply(a1, cs);
  PERFORM desk.fadm_case_status(a1, cs, 'resolved'); PERFORM desk.fadm_case_status(a1, cs, 'open'); PERFORM desk.fadm_case_status(a1, cs, 'resolved');
  PERFORM desk.fadm_case_assign(a1, cs2, a1); PERFORM desk.fadm_case_reply(a1, cs2);
  PERFORM desk.fadm_case_assign(a1, cp, a1); PERFORM desk.fadm_case_reply(a1, cp);
  r1 := desk.fadm_reports(a1);
  PERFORM pg_temp.ad16_ok((r1->'daily'->'created'->>13)::int - (r0->'daily'->'created'->>13)::int = 4, 'created today +4: the move-in case (no right) and the restricted security case are NOT counted');
  PERFORM pg_temp.ad16_ok((r1->'daily'->'solved'->>13)::int - (r0->'daily'->'solved'->>13)::int = 2 AND (r1->'resolution'->>'solved')::int - (r0->'resolution'->>'solved')::int = 1 AND (r1->>'reopened_30d')::int - (r0->>'reopened_30d')::int = 1, 'two moves to resolved today, ONE case first resolved, ONE reopen');
  PERFORM pg_temp.ad16_ok((r1->'backlog'->>'new')::int - (r0->'backlog'->>'new')::int = 1 AND (r1->'backlog'->>'open')::int = (r0->'backlog'->>'open')::int AND (r1->'backlog'->>'waiting')::int - (r0->'backlog'->>'waiting')::int = 2, 'backlog now: one new, two waiting (a staff reply moves a case to waiting), the resolved one is gone');
  PERFORM pg_temp.ad16_ok((r1->'daily'->'backlog'->>13)::int - (r0->'daily'->'backlog'->>13)::int = 3, 'the end-of-day backlog rebuilt from the event history is +3');
  PERFORM pg_temp.ad16_ok((r1->'first_reply'->>'cases')::int - (r0->'first_reply'->>'cases')::int = 4 AND (r1->'first_reply'->>'replied')::int - (r0->'first_reply'->>'replied')::int = 3 AND (r1->'first_reply'->>'unanswered')::int - (r0->'first_reply'->>'unanswered')::int = 1, 'first reply: four cases, three replied, one unanswered');
  PERFORM pg_temp.ad16_ok((r1->'first_reply'->>'median_min') IS NOT NULL AND (r1->'first_reply'->>'p90_min')::int >= (r1->'first_reply'->>'median_min')::int AND (r1->'resolution'->>'median_min') IS NOT NULL, 'medians exist once a case was measured, and p90 is never below the median');
  PERFORM pg_temp.ad16_ok((r1->'priority'->>'total')::int - (r0->'priority'->>'total')::int = 1 AND (r1->'priority'->>'in_time')::int - (r0->'priority'->>'in_time')::int = 1 AND (r1->'priority'->>'late')::int = (r0->'priority'->>'late')::int AND (r1->'priority'->>'total')::int = (r1->'priority'->>'in_time')::int + (r1->'priority'->>'late')::int + (r1->'priority'->>'waiting')::int, 'Priority: one case, answered in time; total = in time + late + waiting');
  PERFORM pg_temp.ad16_ok(r1->'queues'->0->>'queue' = 'general' AND r1->'queues'->1->>'queue' = 'support' AND jsonb_array_length(r1->'queues') = 2 AND (r1->'queues'->1->>'created')::int - (r0->'queues'->1->>'created')::int = 4 AND (r1->'queues'->1->>'backlog')::int - (r0->'queues'->1->>'backlog')::int = 3, 'per queue: only the two readable queues, in fixed order, support +4 created and +3 backlog');
  PERFORM pg_temp.ad16_ok(r1::text !~* '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|@|ad16-thread|selftest|C-[0-9]{6}|Sign in problem|Urgent problem|Phishing)', 'counts and minutes only: no case reference, subject, company, address or id in the answer');
  PERFORM pg_temp.ad16_ok(has_function_privilege('desk_app', 'desk.fadm_reports(uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_reports(uuid)', 'EXECUTE') AND NOT has_table_privilege('desk_app', 'desk.fadm_case', 'SELECT'), 'desk_app may run the report, PUBLIC may not, and desk_app still has no table right');
  PERFORM pg_temp.ad16_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  RAISE EXCEPTION 'AD16 selftest passed, rolling back' USING ERRCODE = 'P0AP2';
EXCEPTION WHEN SQLSTATE 'P0AP2' THEN RAISE NOTICE 'AD16 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
