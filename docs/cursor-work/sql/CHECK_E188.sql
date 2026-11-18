
-- CHECK E188 - live drafts. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E188 the 2 draft triggers exist' as item, (public.fmail_posture188() ->> 'draft_triggers') = '2' as ok, 1 as n
union all select 'E188 trigger functions are closed to anon / authenticated', (public.fmail_posture188() ->> 'trigger_fns_closed')::boolean, 2
union all select 'E188 door audit (E179) clean', (public.fmail_posture188() ->> 'door_audit_clean')::boolean, 3
union all select 'E188 selftest all ok (' || (public.fmail_selftest188() ->> 'passed') || ' passed)', (public.fmail_selftest188() ->> 'ok')::boolean, 4
union all select 'E187 chain of every mailbox still verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_change_verify187(m.id) ->> 'ok')::boolean, false)), 5
) t order by n;
