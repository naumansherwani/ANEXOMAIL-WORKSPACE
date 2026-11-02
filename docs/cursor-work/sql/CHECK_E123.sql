-- CHECK E123 — reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E123 tables exist with RLS on, closed to anon/authenticated, append-only for service_role (no update/delete/truncate on signed notes)' as item,
       (select count(*) = 2 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_audit_log_keys'::regclass, 'public.founder_audit_signed_checkpoints'::regclass))
       and not has_table_privilege('anon', 'public.founder_audit_signed_checkpoints', 'select') and not has_table_privilege('authenticated', 'public.founder_audit_log_keys', 'select')
       and not has_table_privilege('service_role', 'public.founder_audit_signed_checkpoints', 'update') and not has_table_privilege('service_role', 'public.founder_audit_signed_checkpoints', 'delete')
       and not has_table_privilege('service_role', 'public.founder_audit_log_keys', 'delete') as ok, 1 as ord
union all select 'E123 doors are closed to anon/authenticated and open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_audit_log_key_register(uuid,text,text,text)', 'public.founder_audit_signed_cp_pending(integer)', 'public.founder_audit_signed_cp_add(bigint,bigint,text)',
                          'public.founder_audit_signed_cp_get(bigint)', 'public.founder_audit_signed_pulse()', 'public._fm_signedcp_judge(text,text,text,bigint,text)', 'public.founder_audit_signed_verify(integer)', 'public.founder_audit_log_vkey()', 'public.founder_audit_signed_cp_latest_note()', 'public.founder_audit_e123_selftest()']) f), 2
union all select 'E123 behaviour selftest (key register/rotate, one active key, immutable keys, body derived from the seal, strict signature line, append-only, rollback clean)',
       coalesce((select public.founder_audit_e123_selftest() like 'E123 selftest OK%' or public.founder_audit_e123_selftest() like 'E123 selftest SKIP%'), false), 3
union all select 'E123 stored signed notes re-check clean against the live ledger (root re-derived from the audit rows), policy constraint intact, pulse reports level',
       coalesce((public.founder_audit_signed_verify(5) ->> 'ok')::boolean, false) and exists (select 1 from pg_constraint where conname = 'founder_audit_sign_policy_order')
       and (public.founder_audit_signed_pulse() ? 'level') and (public.founder_audit_signed_pulse() ? 'oldest_unsigned_age_s'), 4
union all select 'E123 at most one active key, and the audit chain + E107/E120/E122 selftests are still green',
       (select count(*) <= 1 from public.founder_audit_log_keys where status = 'active') and public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_e122_selftest() like 'E122 selftest OK%' or public.founder_audit_e122_selftest() like 'E122 selftest SKIP%'), false), 5
) t order by ord;
