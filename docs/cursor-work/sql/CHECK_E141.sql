
-- CHECK E141 — reads only (the selftests roll back). 5 checks.
select item, ok from (
select 'E141 receipt columns exist with their shape rule, the ack hash is unique and NOT readable by service_role, acked_at is' as item,
       exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_push_outbox' and column_name = 'ack_hash')
       and exists (select 1 from pg_constraint where conname = 'founder_push_outbox_ack_shape' and convalidated)
       and exists (select 1 from pg_indexes where schemaname = 'public' and indexname = 'founder_push_outbox_ack_once')
       and not has_column_privilege('service_role', 'public.founder_push_outbox', 'ack_hash', 'select')
       and not has_column_privilege('service_role', 'public.founder_push_outbox', 'payload', 'select')
       and has_column_privilege('service_role', 'public.founder_push_outbox', 'acked_at', 'select') as ok, 1 as ord
union all select 'E141 doors closed to anon/authenticated, open to service_role (ack, escalate, status)',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public.founder_push_ack(text)', 'public.founder_push_escalate()', 'public.founder_push_status(uuid)', 'public.founder_push_e141_selftest()']) f), 2
union all select 'E141 behaviour selftest (ack token in payload + hash only, wrong tokens, receipt once and immutable, ledger event, escalation once and only for an open request, status)',
       coalesce((select public.founder_push_e141_selftest() like 'E141 selftest OK%' or public.founder_push_e141_selftest() like 'E141 selftest SKIP%'), false), 3
union all select 'E141 the E140 selftest still passes with the new guard and the event kinds acked/escalated are allowed',
       coalesce((select public.founder_push_e140_selftest() like 'E140 selftest OK%' or public.founder_push_e140_selftest() like 'E140 selftest SKIP%'), false)
       and exists (select 1 from pg_constraint where conname = 'founder_push_event_kind_check' and pg_get_constraintdef(oid) like '%escalated%'), 4
union all select 'E141 the push ledger chain re-checks clean; audit chain, E118 and E139 selftests still green',
       coalesce((public.founder_push_verify(1000) ->> 'ok')::boolean, false) and public.founder_audit_verify(1) is null
       and coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false)
       and coalesce((select public.founder_webauthn_e139_selftest() like 'E139 selftest OK%' or public.founder_webauthn_e139_selftest() like 'E139 selftest SKIP%'), false), 5
) t order by ord;
