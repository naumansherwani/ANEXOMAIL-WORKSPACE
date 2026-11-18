
-- CHECK E189 - domain TLS facts (QC1cF7). Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E189 read doors are STABLE and service_role only' as item, (public.fmail_posture189() ->> 'read_doors_stable_service_only')::boolean as ok, 1 as n
union all select 'E189 write doors (claim, finish, real, forget) are VOLATILE and service_role only', (public.fmail_posture189() ->> 'write_doors_volatile_service_only')::boolean, 2
union all select 'E189 the ledger writer is closed to every role but the doors', (public.fmail_posture189() ->> 'ledger_writer_closed')::boolean, 3
union all select 'E189 RLS forced on the 3 tables', (public.fmail_posture189() ->> 'rls_forced')::boolean, 4
union all select 'E189 service_role can only read the tables (every write is a door)', (public.fmail_posture189() ->> 'service_role_read_only')::boolean, 5
union all select 'E189 anon / authenticated have no access', (public.fmail_posture189() ->> 'anon_no_access')::boolean, 6
union all select 'E189 the 6 guard triggers exist', (public.fmail_posture189() ->> 'guards') = '6', 7
union all select 'E189 the 9 evidence constraints exist', (public.fmail_posture189() ->> 'constraints') = '9', 8
union all select 'E189 door audit (E179) clean', (public.fmail_posture189() ->> 'door_audit_clean')::boolean, 9
union all select 'E189 selftest all ok (' || (public.fmail_selftest189() ->> 'passed') || ' passed)', (public.fmail_selftest189() ->> 'ok')::boolean, 10
union all select 'E189 every mailbox chain verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_dtls_verify189(m.id) ->> 'ok')::boolean, false)), 11
) t order by n;
