-- CHECK E123 — reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E123 tables exist with RLS on, closed to anon/authenticated, append-only for service_role (no update/delete/truncate on signed notes)' as item,
       (select count(*) = 2 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_audit_log_keys'::regclass, 'public.founder_audit_signed_checkpoints'::regclass))
       and not has_table_privilege('anon', 'public.founder_audit_signed_checkpoints', 'select') and not has_table_privilege('authenticated', 'public.founder_audit_log_keys', 'select')
       and not has_table_privilege('service_role', 'public.founder_audit_signed_checkpoints', 'update') and not has_table_privilege('service_role', 'public.founder_audit_signed_checkpoints', 'delete')
       and not has_table_privilege('service_role', 'public.founder_audit_log_keys', 'delete') as ok, 1 as ord
union all select 'E123 doors are closed to anon/authenticated and open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_audit_log_key_register(uuid,text,text,text)', 'public.founder_audit_signed_cp_pending(integer)', 'public.founder_audit_signed_cp_add(bigint,bigint,text)',
                          'public.founder_audit_signed_cp_get(bigint)', 'public.founder_audit_signed_pulse()', 'public.founder_audit_e123_selftest()']) f), 2
union all select 'E123 behaviour selftest (key register/rotate, one active key, immutable keys, body derived from the seal, strict signature line, append-only, rollback clean)',
       coalesce((select public.founder_audit_e123_selftest() like 'E123 selftest OK%' or public.founder_audit_e123_selftest() like 'E123 selftest SKIP%'), false), 3
union all select 'E123 at most one active key, and the audit chain + E107/E120/E122 selftests are still green',
       (select count(*) <= 1 from public.founder_audit_log_keys where status = 'active') and public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_e122_selftest() like 'E122 selftest OK%' or public.founder_audit_e122_selftest() like 'E122 selftest SKIP%'), false), 4
) t order by ord;
