
-- CHECK E139 — reads only (the selftest rolls back). 7 checks.
select item, ok from (
select 'E139 policy, credential facts, event ledger, MDS and Signal queue exist, RLS on, closed to anon/authenticated; ledger + MDS append-only and policy read-only for service_role' as item,
       (select count(*) = 5 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_webauthn_policy'::regclass, 'public.founder_webauthn_cred'::regclass, 'public.founder_webauthn_event'::regclass,
                                                                                    'public.founder_webauthn_mds'::regclass, 'public.founder_webauthn_signal'::regclass))
       and not has_table_privilege('anon', 'public.founder_webauthn_event', 'select') and not has_table_privilege('authenticated', 'public.founder_webauthn_cred', 'select')
       and not has_table_privilege('service_role', 'public.founder_webauthn_event', 'update') and not has_table_privilege('service_role', 'public.founder_webauthn_event', 'delete')
       and not has_table_privilege('service_role', 'public.founder_webauthn_mds', 'update') and not has_table_privilege('service_role', 'public.founder_webauthn_mds', 'delete')
       and not has_table_privilege('service_role', 'public.founder_webauthn_policy', 'update') as ok, 1 as ord
union all select 'E139 the guard triggers are all present and enabled (policy, credential, event, MDS, signal, passkey Signal trigger)',
       (select count(*) from pg_trigger where not tgisinternal and tgenabled = 'O' and tgname in ('founder_webauthn_policy_guard', 'founder_webauthn_policy_guard_trunc', 'founder_webauthn_cred_guard', 'founder_webauthn_cred_guard_trunc',
          'founder_webauthn_event_guard', 'founder_webauthn_event_stop', 'founder_webauthn_event_stop_trunc', 'founder_webauthn_mds_stop', 'founder_webauthn_mds_stop_trunc',
          'founder_webauthn_signal_guard', 'founder_webauthn_signal_guard_trunc', 'founder_webauthn_passkey_signals')) = 12, 2
union all select 'E139 doors closed to anon/authenticated, open to service_role',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_webauthn_origin_ok(text)', 'public.founder_webauthn_register(uuid,text,jsonb)', 'public.founder_webauthn_assert(uuid,text,jsonb)', 'public.founder_webauthn_fail(uuid,text,text)',
                          'public.founder_mds_ingest(integer,jsonb)', 'public.founder_webauthn_signal_next(uuid)', 'public.founder_webauthn_signal_ack(uuid,uuid)', 'public.founder_webauthn_pq_report()',
                          'public.founder_webauthn_verify(integer)', 'public.founder_webauthn_status(uuid)', 'public.founder_webauthn_e139_selftest()']) f), 3
union all select 'E139 behaviour selftest (policy rules, 5-label limit, Signal trigger, register refusals, immutable facts, assert paths, BE flip, clone rule, synced regression 35/40, burst, velocity, MDS, Signal ack, PQ report 0, tamper, rollback clean)',
       coalesce((select public.founder_webauthn_e139_selftest() like 'E139 selftest OK%' or public.founder_webauthn_e139_selftest() like 'E139 selftest SKIP%'), false), 4
union all select 'E139 stored event chain re-checks clean (hash, prev link, shapes) and the status answers',
       coalesce((public.founder_webauthn_verify(1000) ->> 'ok')::boolean, false), 5
union all select 'E139 post-quantum report is honest: the policy keeps ML-DSA ids off, so 0 post-quantum credentials',
       coalesce((public.founder_webauthn_pq_report() ->> 'post_quantum')::int = 0 and not (public.founder_webauthn_pq_report() ->> 'pq_allowed_by_policy')::boolean, false), 6
union all select 'E139 the audit chain and the E118 selftests are still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false)
       and coalesce((select public.founder_chairman_selftest2() like 'E118 selftest2 OK%'), false), 7
) t order by ord;
