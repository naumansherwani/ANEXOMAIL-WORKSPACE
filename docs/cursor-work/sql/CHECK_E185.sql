
-- CHECK E185 - Send now door. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E185 door exists, VOLATILE, service_role only' as item, (public.fmail_posture185() ->> 'door_volatile')::boolean and (public.fmail_posture185() ->> 'door_service_only')::boolean as ok, 1 as n
union all select 'E185 ledger knows send_release', (public.fmail_posture185() ->> 'ledger_knows_send_release')::boolean, 2
union all select 'E185 outbox RLS forced', (public.fmail_posture185() ->> 'rls_forced')::boolean, 3
union all select 'E185 door audit (E179) clean', (public.fmail_posture185() ->> 'door_audit_clean')::boolean, 4
union all select 'E185 selftest all ok (' || (public.fmail_selftest185() ->> 'passed') || ' passed)', (public.fmail_selftest185() ->> 'ok')::boolean, 5
) t order by n;
