
-- CHECK E169 - founder mailbox read doors + touch gates + ledger proof. Writes nothing that stays (the selftest rolls itself back). 7 checks.
select item, ok from (
select 'E169 the five mail actions are T2 in the action registry' as item, (public.fmail_posture169() ->> 'tiers')::int = 5 as ok, 1 as ord
union all select 'E169 ledger action list has inbound_ok, unseal_gated, vault_set, mailbox_seed', (public.fmail_posture169() ->> 'ledger_has_new_actions')::boolean, 2
union all select 'E169 threads have the vault column and the founder mailbox exists', (public.fmail_posture169() ->> 'vault_column')::boolean and (public.fmail_posture169() ->> 'founder_mailbox')::boolean, 3
union all select 'E169 selftest: ' || (public.fmail_selftest169() ->> 'passed') || ' passed, ' || (public.fmail_selftest169() ->> 'failed') || ' failed',
       coalesce((public.fmail_selftest169() ->> 'ok')::boolean, false), 4
union all select 'E169 every new fmail_ door is service_role only',
       not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname ~ '(169)$' and p.prokind = 'f'
                      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 5
union all select 'E169 the E167 ledger still verifies, head seq ' || (public.fmail_posture167() ->> 'ledger_head'), (public.fmail_posture167() ->> 'ledger_ok')::boolean, 6
union all select 'E169 the E168 key tables still agree (no mailbox with two active keys)', (public.fmail_posture168() ->> 'mailboxes_with_two_active_keys')::int = 0, 7
) t order by ord;
