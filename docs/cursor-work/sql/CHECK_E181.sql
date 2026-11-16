
-- CHECK E181 - the send ledger text no longer claims a touch that did not happen; the 30 s hold rules are still in the enqueue door. Writes nothing.
select item, ok from (
select 'E181 enqueue ledger text is truthful (touch / no touch)' as item, (select pg_get_functiondef('public.fmail_outbox_enqueue(uuid,uuid,uuid,bytea[],timestamptz,text)'::regprocedure) like '%normal send, no touch needed by policy%') as ok, 1 as n
union all select 'E181 undo hold is 30 s', (select undo_seconds from public.fmail_policy where id = 1) = 30, 2
union all select 'E181 door audit (E179) clean', not exists (select 1 from public.fmail_door_audit179()), 3
union all select 'E181 selftest 4 ok', public.fmail_selftest181() like 'E181 selftest: 4 ok, 0 failed', 4
) t order by n;
