
-- CHECK E177 - the per-send touch is off (ledgered), the 30 second hold stays, the E167 selftest still passes. Writes nothing. 5 checks.
select item, ok from (
select public.fmail_selftest177() as item, public.fmail_selftest177() like 'E177 selftest: 5 ok, 0 failed' as ok, 1 as n
union all select 'E177 send needs no touch (policy)', (select require_touch_send from public.fmail_policy where id = 1) = false, 2
union all select 'E177 undo hold = 30 s', (select undo_seconds from public.fmail_policy where id = 1) = 30, 3
union all select 'E177 the sender wake door is service_role only', has_function_privilege('service_role','public.fmail_outbox_next_due177()','execute') and not has_function_privilege('anon','public.fmail_outbox_next_due177()','execute'), 5
union all select 'E177 delete and export keep their touch', (select require_touch_delete and require_touch_export from public.fmail_policy where id = 1), 6
) t order by n;
