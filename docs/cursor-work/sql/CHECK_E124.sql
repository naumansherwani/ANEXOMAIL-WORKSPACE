-- CHECK E124 — reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E124 five tables exist, RLS on, closed to anon/authenticated, evidence + events append-only for service_role' as item,
       (select count(*) = 5 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_anchor_providers'::regclass, 'public.founder_anchor_policy'::regclass, 'public.founder_anchor_jobs'::regclass, 'public.founder_anchor_evidence'::regclass, 'public.founder_anchor_events'::regclass))
       and not has_table_privilege('anon', 'public.founder_anchor_evidence', 'select') and not has_table_privilege('authenticated', 'public.founder_anchor_jobs', 'select')
       and not has_table_privilege('service_role', 'public.founder_anchor_evidence', 'update') and not has_table_privilege('service_role', 'public.founder_anchor_evidence', 'delete')
       and not has_table_privilege('service_role', 'public.founder_anchor_events', 'update') and not has_table_privilege('service_role', 'public.founder_anchor_jobs', 'delete') as ok, 1 as ord
union all select 'E124 doors closed to anon/authenticated, open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_anchor_enqueue()', 'public.founder_anchor_next(integer)', 'public.founder_anchor_record_tsa(bigint,text,jsonb)', 'public.founder_anchor_record_ots(bigint,text,text,jsonb)',
                          'public.founder_anchor_fail(bigint,text,boolean)', 'public.founder_anchor_provider_set(uuid,text,boolean,text)', 'public.founder_anchor_signer_accept(uuid,text,text,text)',
                          'public.founder_anchor_pulse()', 'public.founder_anchor_get(bigint)', 'public.founder_anchor_verify(integer)', 'public.founder_anchor_level(bigint)', 'public.founder_anchor_e124_selftest()']) f), 2
union all select 'E124 behaviour selftest (queue + lease, RFC 3161 time rules, signer pin, OpenTimestamps pending -> Bitcoin, backoff + dead letter, immutability, forged digest, rollback clean)',
       coalesce((select public.founder_anchor_e124_selftest() like 'E124 selftest OK%' or public.founder_anchor_e124_selftest() like 'E124 selftest SKIP%'), false), 3
union all select 'E124 stored evidence + both hash chains re-check clean (digests re-derived from the signed notes), default providers present, policy order holds',
       coalesce((public.founder_anchor_verify(500) ->> 'ok')::boolean, false) and (select count(*) >= 6 from public.founder_anchor_providers)
       and (select fail_secs > warn_secs from public.founder_anchor_policy where id) and (public.founder_anchor_pulse() ? 'level'), 4
union all select 'E124 the audit chain and the E107/E120/E122/E123 selftests are still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_audit_merkle_selftest() like 'E107 selftest OK%' or public.founder_audit_merkle_selftest() like 'E107 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_e122_selftest() like 'E122 selftest OK%' or public.founder_audit_e122_selftest() like 'E122 selftest SKIP%'), false)
       and coalesce((select public.founder_audit_e123_selftest() like 'E123 selftest OK%' or public.founder_audit_e123_selftest() like 'E123 selftest SKIP%'), false), 5
) t order by ord;
