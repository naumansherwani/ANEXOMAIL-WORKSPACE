
-- CHECK E164 - reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E164 posture: RLS on, no client grants, one active key per device, guard trigger, service_role only, event kinds' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_proofkey_posture164())) as ok, 1 as ord
union all select 'E164 selftest: ' || public.founder_proofkey_selftest164(), public.founder_proofkey_selftest164() ~ '^E164 selftest (PASS|SKIP)', 2
union all select 'E162 + E161 + E158 selftests still pass: ' || public.founder_dbsc_selftest162() || ' / ' || public.founder_dbsc_selftest161() || ' / ' || public.founder_session_selftest158(), public.founder_dbsc_selftest162() ~ '^E162 selftest (PASS|SKIP)' and public.founder_dbsc_selftest161() ~ '^E161 selftest (PASS|SKIP)' and public.founder_session_selftest158() ~ '^E158 selftest (PASS|SKIP)', 3
) t order by ord;
