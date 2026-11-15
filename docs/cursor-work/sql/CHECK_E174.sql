
-- CHECK E174 - the mail speed ledger (QPERF-1). Writes nothing (the selftest rolls itself back). 6 checks.
select item, ok from (
select 'E174 the sample table is day-partitioned, RLS forced, append-only triggers on every partition (' || (select count(*) from pg_inherits where inhparent = 'public.fmail_perf_sample'::regclass) || ' partitions)' as item,
       (select relforcerowsecurity from pg_class where oid = 'public.fmail_perf_sample'::regclass)
       and (select count(*) from pg_inherits where inhparent = 'public.fmail_perf_sample'::regclass) >= 1
       and public.fmail_perf_partitions_ok174()
       and not exists (select 1 from pg_inherits i join pg_class c on c.oid = i.inhrelid where i.inhparent = 'public.fmail_perf_sample'::regclass
                       and (not c.relforcerowsecurity or (select count(*) from pg_trigger t where t.tgrelid = c.oid and not t.tgisinternal and t.tgfoid = 'public._fp_immutable()'::regprocedure) < 2)) as ok, 1 as ord
union all select 'E174 the closed lists hold (stage, outcome, size, duration range) as CHECK constraints',
       (select count(*) from pg_constraint where conrelid = 'public.fmail_perf_sample'::regclass and contype = 'c') >= 4, 2
union all select 'E174 the daily seal chain verifies (' || public.fmail_perf_seal_verify174() || ' seals)', public.fmail_perf_seal_verify174() >= 0, 3
union all select 'E174 every door and writer is service_role only, security definer with a fixed search_path',
       not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('fmail_perf_ingest174', 'fmail_perf_seal174', 'fmail_perf_seal_verify174', 'fmail_perf_rollup174', 'fmail_perf_pct174', 'fmail_perf_burn174', 'fmail_perf_door174', 'fmail_perf_partitions174', 'fmail_perf_partitions_ok174', 'fmail_perf_selftest174')
                   and (not p.prosecdef or p.proconfig is null or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute') or not has_function_privilege('service_role', p.oid, 'execute'))), 4
union all select 'E174 the SLO table holds all five stages (' || (select count(*) from public.fmail_perf_slo) || ' rows)', (select count(*) from public.fmail_perf_slo) = 5, 5
union all select 'E174 selftest: ' || public.fmail_perf_selftest174(), public.fmail_perf_selftest174() = 'E174 selftest: 12 ok, 0 failed', 6
) t order by ord;
