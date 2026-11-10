
-- CHECK E158 - reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E158 posture: key_attach door service_role only + definer + pinned, ledger kind widened, guard allows only none -> key' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture158())) as ok, 1 as ord
union all select 'E158 selftest: ' || public.founder_session_selftest158(), public.founder_session_selftest158() ~ '^E158 selftest (PASS|SKIP)', 2
union all select 'E158 the E156 posture still holds', (select bool_and(value::boolean) from jsonb_each_text(public.founder_session_posture156())), 3
union all select 'E158 the E150 device-key selftest still passes: ' || left(public.founder_devicekey_selftest(), 160), public.founder_devicekey_selftest() ~ '^E150 selftest (OK|SKIP)', 4
) t order by ord;
