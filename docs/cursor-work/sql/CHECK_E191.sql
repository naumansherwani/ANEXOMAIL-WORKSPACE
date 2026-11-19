
-- CHECK E191 - TLS-RPT counters + report ledger + the strict "send only if TLS" ratchet. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E191 six tables exist with forced row level security' as item, (public.fmail_posture191() ->> 'tables_forced_rls')::int = 6 as ok, 1 as n
union all select 'E191 six guard triggers (only the doors write)', (public.fmail_posture191() ->> 'guards')::int = 6, 2
union all select 'E191 service_role can only SELECT the tables', (public.fmail_posture191() ->> 'service_role_select_only')::boolean, 3
union all select 'E191 the ledger writer is closed to every role', (public.fmail_posture191() ->> 'writer_closed')::boolean, 4
union all select 'E191 doors closed to anon / authenticated', (public.fmail_posture191() ->> 'doors_closed_to_anon')::boolean, 5
union all select 'E179 door audit still clean', (public.fmail_posture191() ->> 'door_audit_clean')::boolean, 6
union all select 'E191 selftest all ok (' || coalesce(public.fmail_selftest191() ->> 'passed', '0') || ' of ' || coalesce(public.fmail_selftest191() ->> 'total', '?') || ') ' || coalesce('error: ' || left(public.fmail_selftest191() ->> 'error', 200), '') || coalesce((select ' failing: ' || string_agg(left(e ->> 'name', 120), ' // ') from jsonb_array_elements(public.fmail_selftest191() -> 'checks') e where (e ->> 'ok') is distinct from 'true'), ''), coalesce((public.fmail_selftest191() ->> 'ok')::boolean, false), 7
union all select 'E191 chain of every mailbox verifies', not exists (select 1 from public.fmail_mailboxes m where not coalesce((public.fmail_tlsx_verify191(m.id) ->> 'ok')::boolean, false)), 8
union all select 'E191 no mailbox is loosened without a remembered grant', not exists (select 1 from public.fmail_tls_policy191 p where p.loosened_until is not null and not exists (select 1 from public.fmail_tls_grant191 g where g.grant_id = p.grant_id)), 9
) t order by n;
