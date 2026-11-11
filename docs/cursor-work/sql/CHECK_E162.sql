
-- CHECK E162 - reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E162 posture: pq columns + shape check + immutable trigger + device_state pq + wrapper + service_role only' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_dbsc_posture162())) as ok, 1 as ord
union all select 'E162 selftest: ' || public.founder_dbsc_selftest162(), public.founder_dbsc_selftest162() ~ '^E162 selftest (PASS|SKIP)', 2
union all select 'E161 + E158 selftests still pass: ' || public.founder_dbsc_selftest161() || ' / ' || public.founder_session_selftest158(), public.founder_dbsc_selftest161() ~ '^E161 selftest (PASS|SKIP)' and public.founder_session_selftest158() ~ '^E158 selftest (PASS|SKIP)', 3
) t order by ord;
