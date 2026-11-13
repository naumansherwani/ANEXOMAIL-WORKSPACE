
-- CHECK E171 - quarantine ledger + scan state 'opaque'. Writes nothing that stays (the selftest rolls itself back). 5 checks.
select item, ok from (
select 'E171 scan state opaque is allowed' as item, coalesce((public.fmail_posture171() ->> 'opaque_allowed')::boolean, false) as ok, 1 as ord
union all select 'E171 every quarantined inbound mail has its quarantine_in ledger row (' || (public.fmail_posture171() ->> 'quarantined_without_ledger') || ' without)', (public.fmail_posture171() ->> 'quarantined_without_ledger')::int = 0, 2
union all select 'E171 selftest: ' || (public.fmail_selftest171() ->> 'passed') || ' passed, ' || (public.fmail_selftest171() ->> 'failed') || ' failed', coalesce((public.fmail_selftest171() ->> 'ok')::boolean, false), 3
union all select 'E171 every new fmail_ door is service_role only',
       not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname ~ '171$' and p.prokind = 'f'
                      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 4
union all select 'E171 the E167 ledger still verifies, head seq ' || (public.fmail_posture167() ->> 'ledger_head'), (public.fmail_posture167() ->> 'ledger_ok')::boolean, 5
) t order by ord;
