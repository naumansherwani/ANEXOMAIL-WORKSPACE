
-- CHECK E195 - Delivery timeline doors. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E195 doors are STABLE, security definer, fixed search_path' as item, coalesce((public.fmail_posture195() ->> 'doors_stable')::boolean and (public.fmail_posture195() ->> 'doors_security_definer')::boolean and (public.fmail_posture195() ->> 'doors_fixed_search_path')::boolean, false) as ok, 1 as n
union all select 'E195 doors + helpers: service_role only', (public.fmail_posture195() ->> 'doors_service_only')::boolean, 2
union all select 'E195 phase / backoff / meta filter are immutable (pure)', (public.fmail_posture195() ->> 'pure_are_immutable')::boolean, 3
union all select 'E195 ledger timeline index exists', (public.fmail_posture195() ->> 'timeline_index')::boolean, 4
union all select 'E195 outbox + ledger RLS forced', (public.fmail_posture195() ->> 'outbox_rls_forced')::boolean and (public.fmail_posture195() ->> 'ledger_rls_forced')::boolean, 5
union all select 'E195 door audit (E179) clean', (public.fmail_posture195() ->> 'door_audit_clean')::boolean, 6
union all select 'E195 selftest all ok (' || (public.fmail_selftest195() ->> 'passed') || ' passed)', (public.fmail_selftest195() ->> 'ok')::boolean, 7
) t order by n;
