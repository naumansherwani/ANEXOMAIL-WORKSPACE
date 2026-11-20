
-- CHECK E194 - sealed signatures + snippets. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E194 five write doors exist, VOLATILE, service_role only' as item, (public.fmail_posture194() ->> 'doors_exist')::boolean and (public.fmail_posture194() ->> 'doors_volatile')::boolean and (public.fmail_posture194() ->> 'doors_service_only')::boolean as ok, 1 as n
union all select 'E194 both list doors are STABLE and service_role only', (public.fmail_posture194() ->> 'lists_stable_service_only')::boolean, 2
union all select 'E194 RLS forced on both tables', (public.fmail_posture194() ->> 'rls_forced')::boolean, 3
union all select 'E194 service_role can only read the tables (every write is a door)', (public.fmail_posture194() ->> 'service_role_read_only')::boolean, 4
union all select 'E194 anon / authenticated have no access', (public.fmail_posture194() ->> 'anon_no_access')::boolean, 5
union all select 'E194 ledger knows signature_set / clear and snippet_put / delete (and the contact actions stay)', (public.fmail_posture194() ->> 'ledger_knows_rich_actions')::boolean, 6
union all select 'E194 one fallback signature per mailbox (partial unique index) and 4 guard triggers', (public.fmail_posture194() ->> 'one_fallback_index')::boolean and (public.fmail_posture194() ->> 'guard_triggers')::int = 4, 7
union all select 'E194 door audit (E179) clean', (public.fmail_posture194() ->> 'door_audit_clean')::boolean, 8
union all select 'E194 selftest all ok (' || (public.fmail_selftest194() ->> 'passed') || ' passed)', (public.fmail_selftest194() ->> 'ok')::boolean, 9
) t order by n;
