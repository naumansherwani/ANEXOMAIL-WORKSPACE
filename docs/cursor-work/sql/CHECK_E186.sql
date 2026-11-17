
-- CHECK E186 - sealed address book. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E186 four write doors exist, VOLATILE, service_role only' as item, (public.fmail_posture186() ->> 'doors_exist')::boolean and (public.fmail_posture186() ->> 'doors_volatile')::boolean and (public.fmail_posture186() ->> 'doors_service_only')::boolean as ok, 1 as n
union all select 'E186 top door is STABLE and service_role only', (public.fmail_posture186() ->> 'top_door_stable_service_only')::boolean, 2
union all select 'E186 RLS forced on all three tables', (public.fmail_posture186() ->> 'rls_forced')::boolean, 3
union all select 'E186 service_role can only read the tables (every write is a door)', (public.fmail_posture186() ->> 'service_role_read_only')::boolean, 4
union all select 'E186 anon / authenticated have no access', (public.fmail_posture186() ->> 'anon_no_access')::boolean, 5
union all select 'E186 ledger knows contact_add / forget / pin / evict', (public.fmail_posture186() ->> 'ledger_knows_contact_actions')::boolean, 6
union all select 'E186 door audit (E179) clean', (public.fmail_posture186() ->> 'door_audit_clean')::boolean, 7
union all select 'E186 selftest all ok (' || (public.fmail_selftest186() ->> 'passed') || ' passed)', (public.fmail_selftest186() ->> 'ok')::boolean, 8
) t order by n;
