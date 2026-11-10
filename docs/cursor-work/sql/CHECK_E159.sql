
-- CHECK E159 - reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E159 posture: head by time, verify by links, head index, append-only triggers, the live chain verifies NOW' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_dbsc_posture159())) as ok, 1 as ord
union all select 'E159 selftest: ' || public.founder_dbsc_selftest159(), public.founder_dbsc_selftest159() ~ '^E159 selftest (PASS|SKIP)', 2
union all select 'E159 live chain: ' || public.founder_dbsc_verify(20000)::text, (public.founder_dbsc_verify(20000) ->> 'ok')::boolean, 3
union all select 'E159 the E150 device-key selftest passes: ' || left(public.founder_devicekey_selftest(), 120), public.founder_devicekey_selftest() ~ '^E150 selftest (OK|SKIP)', 4
) t order by ord;
