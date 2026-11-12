
-- CHECK E168 - founder mailbox keys + RCPT door + bridge feed. Writes nothing that stays (the selftest rolls itself back). 7 checks.
select item, ok from (
select 'E168 fmail_keys: RLS enabled + forced, anon/authenticated cannot read' as item,
       ((public.fmail_posture168() ->> 'keys_rls')::boolean and not (public.fmail_posture168() ->> 'anon_can_read')::boolean) as ok, 1 as ord
union all select 'E168 both guard triggers present (key rows + mailbox key columns)', (public.fmail_posture168() ->> 'guard_triggers')::int = 2, 2
union all select 'E168 no mailbox has two active keys, no mailbox public key differs from its active key row',
       (public.fmail_posture168() ->> 'mailboxes_with_two_active_keys')::int = 0 and (public.fmail_posture168() ->> 'mailbox_pub_mismatch')::int = 0, 3
union all select 'E168 selftest: ' || (public.fmail_selftest168() ->> 'passed') || ' passed, ' || (public.fmail_selftest168() ->> 'failed') || ' failed',
       coalesce((public.fmail_selftest168() ->> 'ok')::boolean, false), 4
union all select 'E168 every new fmail_ door is service_role only',
       not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname in ('fmail_key_register','fmail_key_revoke','fmail_rcpt_resolve','fmail_key_history','fmail_bridge_feed','fmail_posture168','fmail_selftest168')
                      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 5
union all select 'E168 the E167 ledger still verifies, head seq ' || (public.fmail_posture167() ->> 'ledger_head'), (public.fmail_posture167() ->> 'ledger_ok')::boolean, 6
union all select 'E168 active pq mailboxes without a key (info, must be 0 before real mail is switched on): ' || (public.fmail_posture168() ->> 'active_pq_mailboxes_without_key'), true, 7
) t order by ord;
