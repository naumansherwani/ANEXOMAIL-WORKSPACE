
-- CHECK E179 - the DKIM send gate is VOLATILE (PostgREST then runs it read-write) and still answers for every mailbox. Writes nothing.
select item, ok from (
select 'E179 gate is volatile (not stable)' as item, (select provolatile = 'v' from pg_proc where oid = 'public.fmail_dkim_send_gate175(uuid)'::regprocedure) as ok, 1 as n
union all select 'E179 gate answers ok:true for every mailbox', coalesce((select bool_and((public.fmail_dkim_send_gate175(id) ->> 'ok')::boolean) from public.fmail_mailboxes), false), 2
union all select 'E179 gate is service_role only', has_function_privilege('service_role','public.fmail_dkim_send_gate175(uuid)','execute') and not has_function_privilege('anon','public.fmail_dkim_send_gate175(uuid)','execute'), 3
) t order by n;
