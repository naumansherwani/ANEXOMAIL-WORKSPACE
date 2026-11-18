
-- CHECK E190 - the chip updates by itself. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E190 the tls trigger exists on the E189 table' as item, (public.fmail_posture190() ->> 'tls_trigger') = '1' as ok, 1 as n
union all select 'E190 the E187 kind list allows tls', (public.fmail_posture190() ->> 'kind_tls_allowed')::boolean, 2
union all select 'E190 trigger function closed to anon / authenticated', (public.fmail_posture190() ->> 'trigger_fn_closed')::boolean, 3
union all select 'E190 selftest all ok (' || (public.fmail_selftest190() ->> 'passed') || ' passed)', (public.fmail_selftest190() ->> 'ok')::boolean, 4
union all select 'E187 chain of every mailbox still verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_change_verify187(m.id) ->> 'ok')::boolean, false)), 5
union all select 'E189 chain of every mailbox still verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_dtls_verify189(m.id) ->> 'ok')::boolean, false)), 6
) t order by n;
