-- CHECK E147 — reads only (the selftest rolls back). 2 checks.
select item, ok from (
select 'E147 the pending-key list is open to service_role only' as item,
       has_function_privilege('service_role', 'public.founder_passkey_pending(uuid)', 'execute') and not has_function_privilege('anon', 'public.founder_passkey_pending(uuid)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_passkey_pending(uuid)', 'execute') as ok, 1 as ord
union all select 'E147 behaviour selftest (only the parked registration is listed, no key body, a used request disappears)',
       coalesce((select public.founder_passkey_pending_selftest() like 'E147 selftest PASS%' or public.founder_passkey_pending_selftest() like 'E147 selftest SKIP%'), false), 2
) t order by ord;
