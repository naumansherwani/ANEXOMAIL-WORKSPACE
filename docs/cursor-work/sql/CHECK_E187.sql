
-- CHECK E187 - mail change log (live mail). Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E187 read doors are STABLE and service_role only' as item, (public.fmail_posture187() ->> 'read_doors_stable_service_only')::boolean as ok, 1 as n
union all select 'E187 write doors (note, prune) are VOLATILE and service_role only', (public.fmail_posture187() ->> 'write_doors_volatile_service_only')::boolean, 2
union all select 'E187 RLS forced on both tables', (public.fmail_posture187() ->> 'rls_forced')::boolean, 3
union all select 'E187 service_role can only read the tables (every write is a door)', (public.fmail_posture187() ->> 'service_role_read_only')::boolean, 4
union all select 'E187 anon / authenticated have no access', (public.fmail_posture187() ->> 'anon_no_access')::boolean, 5
union all select 'E187 the 7 triggers exist (3 on mail tables, 4 guards)', (public.fmail_posture187() ->> 'triggers_on_mail_tables') = '7', 6
union all select 'E187 door audit (E179) clean', (public.fmail_posture187() ->> 'door_audit_clean')::boolean, 7
union all select 'E187 selftest all ok (' || (public.fmail_selftest187() ->> 'passed') || ' passed)', (public.fmail_selftest187() ->> 'ok')::boolean, 8
union all select 'E187 every mailbox chain verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_change_verify187(m.id) ->> 'ok')::boolean, false)), 9
) t order by n;
