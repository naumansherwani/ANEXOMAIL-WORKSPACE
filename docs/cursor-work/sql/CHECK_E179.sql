
-- CHECK E179 - the DKIM send gate is VOLATILE (PostgREST then runs it read-write), no door anywhere is STABLE/IMMUTABLE while it writes, selftest 5/5. Writes nothing.
select item, ok from (
select 'E179 gate is volatile (not stable)' as item, (select provolatile = 'v' from pg_proc where oid = 'public.fmail_dkim_send_gate175(uuid)'::regprocedure) as ok, 1 as n
union all select 'E179 gate answers for every mailbox', coalesce((select bool_and((public.fmail_dkim_send_gate175(id) ->> 'ok') is not null) from public.fmail_mailboxes), true), 2
union all select 'E179 gate is service_role only', has_function_privilege('service_role','public.fmail_dkim_send_gate175(uuid)','execute') and not has_function_privilege('anon','public.fmail_dkim_send_gate175(uuid)','execute'), 3
union all select 'E179 door audit: no STABLE/IMMUTABLE door writes' || coalesce(' (OFFENDERS: ' || (select string_agg(door || ' ' || volatility || ' ' || coalesce(why, ''), '; ') from public.fmail_door_audit179()) || ')', ''), not exists (select 1 from public.fmail_door_audit179()), 4
union all select 'E179 selftest 5 ok', public.fmail_selftest179() like 'E179 selftest: 5 ok, 0 failed', 5
) t order by n;
