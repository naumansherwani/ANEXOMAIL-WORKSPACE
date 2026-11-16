
-- CHECK E180 - the discard door for outgoing mail exists, is service_role only and VOLATILE, the outbox state machine allows exactly the discard moves, the E179 door audit stays clean. Writes nothing.
select item, ok from (
select 'E180 discard door is volatile' as item, (select provolatile = 'v' from pg_proc where oid = 'public.fmail_discard180(uuid,uuid,uuid)'::regprocedure) as ok, 1 as n
union all select 'E180 discard door is service_role only', has_function_privilege('service_role','public.fmail_discard180(uuid,uuid,uuid)','execute') and not has_function_privilege('anon','public.fmail_discard180(uuid,uuid,uuid)','execute'), 2
union all select 'E180 failed/queued may be cancelled, sent/sending may not', public.fmail_outbox_transition_ok_167('failed','cancelled') and public.fmail_outbox_transition_ok_167('queued','cancelled') and not public.fmail_outbox_transition_ok_167('sent','cancelled') and not public.fmail_outbox_transition_ok_167('sending','cancelled'), 3
union all select 'E180 door audit (E179) still clean', not exists (select 1 from public.fmail_door_audit179()), 4
union all select 'E180 selftest 4 ok', public.fmail_selftest180() like 'E180 selftest: 4 ok, 0 failed', 5
) t order by n;
