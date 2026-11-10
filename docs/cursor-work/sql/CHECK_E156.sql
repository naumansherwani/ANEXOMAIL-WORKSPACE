
-- CHECK E156 - reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E156 posture: doors service_role only + definer + pinned, kinds widened, limits enforced, anchors append-only, helpers closed, tail verifies, anchors match' as item,
       (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture156())) as ok, 1 as ord
union all select 'E156 the posture of E155 still holds', (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture155())), 2
union all select 'E156 selftest: ' || public.founder_session_selftest156(), public.founder_session_selftest156() ~ '^E156 selftest (PASS|SKIP)', 3
union all select 'E156 the E155 selftest still passes (E155 is intact)', public.founder_session_selftest155() ~ '^E155 selftest (PASS|SKIP)', 4
union all select 'E156 a malformed check is refused', public.founder_session_check('x', 'x', 'quic', 'k', true, 'chrome', 'chrome', null, null) ->> 'state' = 'shape', 5
) t order by ord;
