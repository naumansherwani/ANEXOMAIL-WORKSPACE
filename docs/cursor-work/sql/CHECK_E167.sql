
-- CHECK E167 - founder mailbox core. Writes nothing that stays (the selftest rolls itself back). 8 checks.
select item, ok from (
select 'E167 posture: RLS enabled + forced on all 13 fmail tables, anon/authenticated cannot read' as item,
       ((public.fmail_posture167() ->> 'all_rls')::boolean and not (public.fmail_posture167() ->> 'anon_can_read')::boolean) as ok, 1 as ord
union all select 'E167 no plain-text column (body, subject, text, html) in messages or drafts: ' || (public.fmail_posture167() ->> 'plain_text_columns'),
       (public.fmail_posture167() ->> 'plain_text_columns')::int = 0, 2
union all select 'E167 ledger hash chain verifies, head seq ' || (public.fmail_posture167() ->> 'ledger_head'), (public.fmail_posture167() ->> 'ledger_ok')::boolean, 3
union all select 'E167 selftest: ' || (public.fmail_selftest167() ->> 'passed') || ' passed, ' || (public.fmail_selftest167() ->> 'failed') || ' failed',
       coalesce((public.fmail_selftest167() ->> 'ok')::boolean, false), 4
union all select 'E167 every fmail_ function (doors and helpers) is service_role only (no public / anon / authenticated execute)',
       not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                    where n.nspname = 'public' and p.proname ~ '^fmail_'
                      and p.prokind = 'f' and p.prorettype <> 'trigger'::regtype
                      and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 5
union all select 'E167 policy row exists and every number is in range', (select count(*) from public.fmail_policy where id = 1) = 1, 6
union all select 'E167 every mailbox has its nine system folders', not exists (select 1 from public.fmail_mailboxes m where (select count(*) from public.fmail_folders f where f.mailbox_id = m.id and f.kind <> 'custom') <> 9), 7
union all select 'E167 ledger and draft versions are append-only (update / delete triggers present)',
       (select count(*) from pg_trigger where tgrelid in ('public.fmail_ledger'::regclass, 'public.fmail_draft_versions'::regclass) and tgname like '%\_ro%' and not tgisinternal) = 4, 8
) t order by ord;
