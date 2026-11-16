
-- CHECK E175G (diagnostic, writes nothing): what the DKIM send gate says for every mailbox, and the blockers inside the health report.
select 'gate: ' || left(public.fmail_dkim_send_gate175(id)::text, 700) as item, true as ok from public.fmail_mailboxes
union all select 'blockers: ' || left((public.fmail_dkim_health175(id) -> 'blockers')::text, 500), true from public.fmail_mailboxes;
