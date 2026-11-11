
-- CHECK E160 - reads only (the selftest rolls back). 2 checks.
select item, ok from (
select 'E160 posture: helper, both patched functions use it, still flags other keys, service_role only' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture160())) as ok, 1 as ord
union all select 'E160 selftest: ' || public.founder_session_selftest160(), public.founder_session_selftest160() ~ '^E160 selftest (PASS|SKIP)', 2
) t order by ord;
