
-- CHECK E176 - the DKIM health read works for a mailbox with no key, and the E175 chains still verify. Writes nothing (the selftest rolls itself back). 3 checks.
select item, ok from (
select 'E176 selftest: ' || public.fmail_dkim_selftest176() as item, public.fmail_dkim_selftest176() like 'E176 selftest: % ok, 0 failed' as ok, 1 as n
union all select 'E176 the health read is service_role only', has_function_privilege('service_role', 'public.fmail_dkim_health175(uuid)', 'execute') and not has_function_privilege('anon', 'public.fmail_dkim_health175(uuid)', 'execute') and not has_function_privilege('authenticated', 'public.fmail_dkim_health175(uuid)', 'execute'), 2
union all select 'E176 the three E175 hash chains still verify (' || (public.fmail_dkim_chain_verify175() ->> 'broken') || ' broken)', (public.fmail_dkim_chain_verify175() ->> 'broken') = '0', 3
) t order by n;
