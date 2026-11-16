
-- CHECK E177B (diagnostic, writes nothing): which E177 selftest check fails on his server.
select 'ledger row policy_change require_touch_send exists' as item, exists (select 1 from public.fmail_ledger where action = 'policy_change' and target = 'require_touch_send') as ok
union all select 'E167 selftest says: ' || left(public.fmail_selftest167()::text, 600), true;
