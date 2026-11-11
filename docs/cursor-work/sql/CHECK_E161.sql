
-- CHECK E161 - reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E161 posture: device_state has idle_s, key attach heals only the two missing-key reasons, service_role only' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_dbsc_posture161())) as ok, 1 as ord
union all select 'E161 selftest: ' || public.founder_dbsc_selftest161(), public.founder_dbsc_selftest161() ~ '^E161 selftest (PASS|SKIP)', 2
union all select 'E161 the E158 selftest still passes: ' || public.founder_session_selftest158(), public.founder_session_selftest158() ~ '^E158 selftest (PASS|SKIP)', 3
) t order by ord;
