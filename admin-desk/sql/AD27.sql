-- AD27 (phase 1m-L, card Ledger, list BL-28 follow-up of the Command Bar ledger seal), 24 Nov 2026 PKT. His order 08:34: "Ledger card wire kero abhi ke abhi". Desk database ONLY (schema desk), no awam table, no founder table.
-- SCHEMA-FIRST: read before writing: AD01 (desk.fadm_ledger: seq, ts, actor, kind, detail, prev_hash, hash; SHA-256 over prev_hash || seq || ts || kind || detail; three freeze triggers; fadm_ledger_verify), AD02 (desk.fadm_owner: role), AD12 (the door pattern: fadm_runbook_staff + fadm_authorize staff.read, SECURITY DEFINER, REVOKE PUBLIC, GRANT desk_app, selftest rolled back), AD03/AD05 (desk.fadm_probe: service, at, ok, latency_ms; the 'ledger' probe row).
-- ADVANCE-RESEARCH: [1m] Ledger card (24 Nov 2026): tamper-evident audit logs are shown the way Certificate Transparency and immutable audit trails show them: the newest entries, the head (sequence number), a hash-chain check, and an independent re-check; a viewer sees what happened and when and by which ROLE, never the entry's private detail; verification of a very long chain is done as a bounded window (the last 2,000 lines, each hash recomputed and each link checked) while the periodic probe walks the whole chain, and both results are shown honestly (window size stated, nothing claimed that was not checked).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD27-check.sql
-- WHAT IT ADDS (nothing of AD01..AD26 is changed): desk.fadm_ledger_window_ok(p_lines) = the hash chain of the newest p_lines lines (bounded 1..5000) recomputed and linked; desk.fadm_ledger_board(p_actor) = ONE door for the Ledger card: only a person who may list staff (staff.read, the same right as Security health) gets an answer, everyone else NULL (the Rust door answers 403). Answer: line count, newest sequence and time, chain check of the newest window, last ledger probe result, the last 20 lines (sequence, time, kind, role of the actor: owner / agent / system / unknown) and the kinds of the last 24 hours with their counts.
-- WHAT IT NEVER SHOWS: the detail column, any e-mail, name, case reference, company or address: kind and role only. Zero lines of a kind or a quiet day are real answers, never "not measured".
-- HONEST LIMIT: the window check proves the newest lines chain to each other and that no line was edited after it was written; the whole chain from the first line is walked by the ledger probe (fadm_probe, service ledger) and by the audit-verify copy outside the database, both shown beside it.
CREATE OR REPLACE FUNCTION desk.fadm_ledger_window_ok(p_lines integer) RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '6s' AS $f$
DECLARE r record; p bytea := NULL; n integer := LEAST(GREATEST(COALESCE(p_lines, 2000), 1), 5000);
BEGIN
  FOR r IN SELECT * FROM (SELECT * FROM desk.fadm_ledger ORDER BY seq DESC LIMIT n) w ORDER BY seq LOOP
    IF p IS NOT NULL AND r.prev_hash <> p THEN RETURN false; END IF;
    IF r.hash <> sha256(r.prev_hash || convert_to(r.seq::text || '|' || r.ts::text || '|' || r.kind || '|' || r.detail::text, 'UTF8')) THEN RETURN false; END IF;
    p := r.hash;
  END LOOP;
  RETURN true;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_ledger_board(p_actor uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '8s' SET lock_timeout = '2s' AS $f$
DECLARE head record; win integer := 2000; cnt bigint; pr record; tail jsonb; kinds jsonb;
BEGIN
  IF NOT desk.fadm_runbook_staff(p_actor) THEN RETURN NULL; END IF;
  IF NOT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'staff.read', desk.fadm_unit_id('department','desk'), NULL)), false) THEN RETURN NULL; END IF;
  SELECT seq, ts INTO head FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 1;
  SELECT count(*) INTO cnt FROM desk.fadm_ledger;
  SELECT p.ok, p.at INTO pr FROM desk.fadm_probe p WHERE p.service = 'ledger' ORDER BY p.at DESC, p.id DESC LIMIT 1;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('seq', t.seq, 'at', to_char(t.ts AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), 'kind', t.kind,
           'role', CASE WHEN t.actor IS NULL THEN 'system' ELSE COALESCE((SELECT o.role FROM desk.fadm_owner o WHERE o.id = t.actor), 'unknown') END) ORDER BY t.seq DESC), '[]'::jsonb)
    INTO tail FROM (SELECT seq, ts, actor, kind FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 20) t;
  SELECT COALESCE(jsonb_agg(jsonb_build_object('kind', k.kind, 'n', k.n) ORDER BY k.n DESC, k.kind), '[]'::jsonb)
    INTO kinds FROM (SELECT kind, count(*)::int AS n FROM desk.fadm_ledger WHERE ts >= now() - interval '24 hours' GROUP BY kind ORDER BY count(*) DESC, kind LIMIT 8) k;
  RETURN jsonb_build_object(
    'generated_at', to_char(now() AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'lines', cnt, 'newest_seq', head.seq, 'newest_at', to_char(head.ts AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'window_lines', LEAST(win, cnt), 'chain_ok', desk.fadm_ledger_window_ok(win),
    'probe', jsonb_build_object('ok', pr.ok, 'at', CASE WHEN pr.at IS NULL THEN NULL ELSE to_char(pr.at AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END),
    'tail', tail, 'kinds_24h', kinds);
END $f$;

COMMENT ON FUNCTION desk.fadm_ledger_board(uuid) IS 'AD27 (Ledger card): staff.read only, kind + role + time only (never the detail), chain check of the newest 2,000 lines, last ledger probe, last 20 lines, kinds of 24 hours.';
REVOKE ALL ON FUNCTION desk.fadm_ledger_window_ok(integer), desk.fadm_ledger_board(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION desk.fadm_ledger_board(uuid) TO desk_app;

-- SELFTEST (rolls back; success is the exception P0AQ2). Runs on the live database too: it tests DELTAS of the real ledger, never exact totals. ------------------------
CREATE FUNCTION pg_temp.ad27_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD27 selftest: %', msg USING ERRCODE = 'P0AQ1'; END IF; END $f$;
DO $$
DECLARE o uuid; a1 uuid; sfx text := substr(md5(random()::text), 1, 8); h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; sup uuid := desk.fadm_unit_id('team','support');
  r0 jsonb; r1 jsonb; n0 bigint; s0 bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o27-' || sfx || '@selftest.invalid', 'AD27 Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a27-' || sfx || '@selftest.invalid', 'AD27 Agent', 'agent', NULL, true, 'active', true) RETURNING id INTO a1;
  PERFORM desk.fadm_access_grant(o, a1, sup, 'agent');
  PERFORM pg_temp.ad27_ok(desk.fadm_ledger_board(a1) IS NULL AND desk.fadm_ledger_board(gen_random_uuid()) IS NULL, 'a support agent and an unknown person get nothing (NULL)');
  r0 := desk.fadm_ledger_board(o);
  PERFORM pg_temp.ad27_ok(r0 IS NOT NULL AND (r0->>'chain_ok')::boolean AND jsonb_array_length(r0->'tail') BETWEEN 1 AND 20 AND (r0->>'lines')::bigint >= 1, 'an owner gets the board and the chain of the newest window verifies');
  n0 := (r0->>'lines')::bigint; s0 := (r0->>'newest_seq')::bigint;
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (o, 'ad1.selftest', jsonb_build_object('secret', 'SECRETVALUE-' || sfx || '@leak.invalid'));
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (NULL, 'package.publish', '{}'::jsonb);
  INSERT INTO desk.fadm_ledger (actor, kind, detail) VALUES (gen_random_uuid(), 'ad1.selftest', '{}'::jsonb);
  r1 := desk.fadm_ledger_board(o);
  PERFORM pg_temp.ad27_ok((r1->>'lines')::bigint = n0 + 3 AND (r1->>'newest_seq')::bigint = s0 + 3, 'three new lines move the count and the newest sequence by exactly three');
  PERFORM pg_temp.ad27_ok(r1->'tail'->0->>'kind' = 'ad1.selftest' AND r1->'tail'->1->>'kind' = 'package.publish' AND r1->'tail'->0->>'role' = 'unknown' AND r1->'tail'->1->>'role' = 'system' AND r1->'tail'->2->>'role' = 'owner' AND (r1->'tail'->0->>'seq')::bigint = s0 + 3, 'the tail is newest first and the role is owner / system / unknown, never a name');
  PERFORM pg_temp.ad27_ok(r1::text !~* '(SECRETVALUE|@|AD27 Owner|AD27 Agent|detail|pw_hash|argon)', 'kind and role only: the detail, e-mail and name never leave the function');
  PERFORM pg_temp.ad27_ok((SELECT COALESCE(sum((e->>'n')::int),0) FROM jsonb_array_elements(r1->'kinds_24h') e WHERE e->>'kind' = 'ad1.selftest') >= 2 AND jsonb_array_length(r1->'kinds_24h') <= 8, 'the kinds of the last 24 hours are counted and capped at 8');
  PERFORM pg_temp.ad27_ok((r1->'probe') ? 'ok' AND (r1->'probe') ? 'at', 'the last ledger probe result is part of the answer (null only when the probe never ran)');
  PERFORM pg_temp.ad27_ok(desk.fadm_ledger_window_ok(5) AND desk.fadm_ledger_window_ok(0) AND desk.fadm_ledger_window_ok(NULL) AND desk.fadm_ledger_window_ok(99999), 'a window is bounded 1..5000 and a healthy chain passes at every size');
  -- tamper test: switch the freeze trigger off INSIDE this rolled-back test, edit one line, the window check must fail, then it must fail on the full verify too
  ALTER TABLE desk.fadm_ledger DISABLE TRIGGER fadm_ledger_frozen;
  UPDATE desk.fadm_ledger SET kind = 'ad1.selftest' WHERE seq = s0 + 2;
  PERFORM pg_temp.ad27_ok(NOT desk.fadm_ledger_window_ok(5) AND NOT desk.fadm_ledger_verify() AND NOT (desk.fadm_ledger_board(o)->>'chain_ok')::boolean, 'an edited line is caught by the window check and by the full verify');
  ALTER TABLE desk.fadm_ledger ENABLE TRIGGER fadm_ledger_frozen;
  PERFORM pg_temp.ad27_ok(has_function_privilege('desk_app', 'desk.fadm_ledger_board(uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_ledger_board(uuid)', 'EXECUTE')
    AND NOT has_function_privilege('desk_app', 'desk.fadm_ledger_window_ok(integer)', 'EXECUTE') AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger', 'UPDATE'), 'desk_app has the door only, never the window helper and never a write right on the ledger');
  RAISE EXCEPTION 'AD27 selftest passed, rolling back' USING ERRCODE = 'P0AQ2';
EXCEPTION WHEN SQLSTATE 'P0AQ2' THEN RAISE NOTICE 'AD27 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
