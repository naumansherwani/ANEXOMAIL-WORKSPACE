
-- CHECK E165 - reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E165 posture: both pq_src columns + checks, label guard trigger, service_role only' as item, (select bool_and(value::boolean) from jsonb_each_text(public.founder_pqsrc_posture165())) as ok, 1 as ord
union all select 'E165 selftest: ' || public.founder_pqsrc_selftest165(), public.founder_pqsrc_selftest165() ~ '^E165 selftest (PASS|SKIP)', 2
union all select 'E164 + E162 selftests still pass: ' || public.founder_proofkey_selftest164() || ' / ' || public.founder_dbsc_selftest162(), public.founder_proofkey_selftest164() ~ '^E164 selftest (PASS|SKIP)' and public.founder_dbsc_selftest162() ~ '^E162 selftest (PASS|SKIP)', 3
) t order by ord;
