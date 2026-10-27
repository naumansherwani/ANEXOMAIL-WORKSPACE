
-- CHECK E101 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E101 trigger mail_messages par laga hai' as item,
       exists (select 1 from pg_trigger where tgrelid = 'public.mail_messages'::regclass and tgname = 'mail_messages_activity' and not tgisinternal) as ok, 1 as n
union all select 'E101 trigger function anon/authenticated se band',
       not has_function_privilege('anon', 'public.activity_from_message()', 'execute')
       and not has_function_privilege('authenticated', 'public.activity_from_message()', 'execute'), 2
union all select 'E101 activity_log RLS on',
       (select relrowsecurity from pg_class where oid = 'public.activity_log'::regclass), 3
union all select 'E101 jin orgs mein pichle 30 din mail hai, un sab ki activity hai',
       not exists (select 1 from public.mail_messages m
                    where m.org_id is not null and m.sent_at > now() - interval '30 days' and m.direction::text in ('in','out')
                      and not exists (select 1 from public.activity_log a where a.org_id = m.org_id and a.kind in ('message_received','message_sent'))), 4
) t order by n;
