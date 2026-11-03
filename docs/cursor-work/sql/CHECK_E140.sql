
-- CHECK E140 — reads only (the selftest rolls back). 6 checks.
select item, ok from (
select 'E140 subscription, outbox and event ledger exist, RLS on, closed to anon/authenticated; ledger has no update/delete and no table is writable by service_role directly' as item,
       (select count(*) = 3 and bool_and(relrowsecurity) from pg_class where oid in ('public.founder_push_sub'::regclass, 'public.founder_push_outbox'::regclass, 'public.founder_push_event'::regclass))
       and not has_table_privilege('anon', 'public.founder_push_event', 'select') and not has_table_privilege('authenticated', 'public.founder_push_sub', 'select')
       and not has_table_privilege('service_role', 'public.founder_push_event', 'insert') and not has_table_privilege('service_role', 'public.founder_push_event', 'update')
       and not has_table_privilege('service_role', 'public.founder_push_outbox', 'insert') and not has_table_privilege('service_role', 'public.founder_push_outbox', 'update')
       and not has_table_privilege('service_role', 'public.founder_push_sub', 'insert') and not has_column_privilege('service_role', 'public.founder_push_sub', 'p256dh', 'select')
       and not has_column_privilege('service_role', 'public.founder_push_sub', 'auth', 'select') and not has_column_privilege('service_role', 'public.founder_push_outbox', 'payload', 'select') as ok, 1 as ord
union all select 'E140 the guard triggers are present and enabled (subscription, outbox, ledger, truncate stops, T3 alert)',
       (select count(*) from pg_trigger where not tgisinternal and tgenabled = 'O' and tgname in ('founder_push_sub_guard', 'founder_push_sub_stop_trunc', 'founder_push_outbox_guard', 'founder_push_outbox_stop_trunc',
          'founder_push_event_guard', 'founder_push_event_stop', 'founder_push_event_stop_trunc', 'founder_push_t3_alert')) = 8, 2
union all select 'E140 doors closed to anon/authenticated, open to service_role; flare.push is a built T2 action',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_push_subscribe(uuid,uuid,text,text,text,text,uuid,text)', 'public.founder_push_confirm(uuid,uuid,text)', 'public.founder_push_remove(uuid,uuid,uuid,uuid,text)',
                          'public.founder_push_test(uuid,uuid)', 'public.founder_push_claim(integer)', 'public.founder_push_report(uuid,integer,integer)', 'public.founder_push_status(uuid)',
                          'public.founder_push_verify(integer)', 'public.founder_push_e140_selftest()']) f)
       and exists (select 1 from public.founder_action_tiers where action = 'flare.push' and tier = 2 and built), 3
union all select 'E140 behaviour selftest (endpoint shapes, T2-bound subscribe, confirm token, 5 wrong tokens, T3 alerts, claim lease, 503 backoff, 201 final, 410 removes, owner remove, state machine, tamper)',
       coalesce((select public.founder_push_e140_selftest() like 'E140 selftest OK%' or public.founder_push_e140_selftest() like 'E140 selftest SKIP%'), false), 4
union all select 'E140 stored ledger chain re-checks clean and the status answers',
       coalesce((public.founder_push_verify(1000) ->> 'ok')::boolean, false), 5
union all select 'E140 the audit chain, E118 and E139 selftests are still green',
       public.founder_audit_verify(1) is null
       and coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false)
       and coalesce((select public.founder_webauthn_e139_selftest() like 'E139 selftest OK%' or public.founder_webauthn_e139_selftest() like 'E139 selftest SKIP%'), false), 6
) t order by ord;
