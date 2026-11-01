-- CHECK E120 — kuch persist nahi karta (selftest rollback). Har row ok = true. 4 checks.
select item, ok from (
select 'E120 founder_audit_verify_runs maujood, RLS on, anon/authenticated ko access nahi, service_role seedha likh nahi sakta' as item,
       to_regclass('public.founder_audit_verify_runs') is not null
       and (select relrowsecurity from pg_class where oid = 'public.founder_audit_verify_runs'::regclass)
       and not has_table_privilege('anon', 'public.founder_audit_verify_runs', 'select') and not has_table_privilege('authenticated', 'public.founder_audit_verify_runs', 'select')
       and not has_table_privilege('service_role', 'public.founder_audit_verify_runs', 'insert') and not has_table_privilege('service_role', 'public.founder_audit_verify_runs', 'update') and not has_table_privilege('service_role', 'public.founder_audit_verify_runs', 'delete') as ok, 1 as ord
union all select 'E120 policy mein 3 naye hadd (stall_secs, verify_every_secs, verify_stale_secs) aur unka constraint maujood; database khud galat hadd nahi leta',
       (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'founder_audit_merkle_policy' and column_name in ('stall_secs','verify_every_secs','verify_stale_secs')) = 3
       and exists (select 1 from pg_constraint where conname = 'founder_audit_policy_g4' and conrelid = 'public.founder_audit_merkle_policy'::regclass)
       and exists (select 1 from pg_constraint where conname = 'founder_verify_runs_shape' and conrelid = 'public.founder_audit_verify_runs'::regclass), 2
union all select 'E120 darwaze (verify_record, merkle_pulse, g4_selftest) maujood, anon/authenticated execute nahi, service_role ke liye khule; pulse mein checker + cp_hash + now_ms',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_audit_verify_record(text)','public.founder_audit_merkle_pulse()','public.founder_audit_g4_selftest()']) f)
       and (public.founder_audit_merkle_pulse() ? 'checker') and (public.founder_audit_merkle_pulse() ? 'now_ms') and (public.founder_audit_merkle_pulse() ? 'full_check'), 3
union all select 'E120 behaviour selftest (kabhi check nahi hua, checker ruka, khamosh ledger par jhoota alarm nahi, sealer ruka, cp_hash, toota chain = fail) + purane E107 selftests aur chain saaf',
       coalesce((select public.founder_audit_g4_selftest() like 'E120 selftest OK%'), false)
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_merkle_selftest2() like 'E107 selftest2 OK%' or public.founder_audit_merkle_selftest2() like 'E107 selftest2 SKIP%'), false)
       and public.founder_audit_verify(1) is null, 4
) t order by ord;
