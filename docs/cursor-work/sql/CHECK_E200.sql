
-- CHECK E200 - one-letter key audit log. Writes nothing (the selftest rolls itself back).
select item, ok from (
select 'E200 log table has forced RLS' as item, (public.fmail_keys_posture200() ->> 'rls_forced')::boolean as ok, 1 as n
union all select 'E200 no grants for anon / authenticated / PUBLIC', (public.fmail_keys_posture200() ->> 'no_client_grants')::boolean, 2
union all select 'E200 log is append-only (row guard + truncate guard)', (public.fmail_keys_posture200() ->> 'append_only')::boolean, 3
union all select 'E200 doors are service_role only', (public.fmail_keys_posture200() ->> 'doors_service_only')::boolean, 4
union all select 'E200 write door is VOLATILE', (public.fmail_keys_posture200() ->> 'doors_volatile')::boolean, 5
union all select 'E200 no mail content columns (privacy)', (public.fmail_keys_posture200() ->> 'no_content_columns')::boolean, 6
union all select 'E200 selftest all ok (' || (public.fmail_keys_selftest200() ->> 'passed') || ' of ' || (public.fmail_keys_selftest200() ->> 'total') || ')', (public.fmail_keys_selftest200() ->> 'ok')::boolean, 7
union all select 'E200 live: ' || (select count(*) from public.fmail_keys_events200) || ' key actions logged so far, every founder chain verifies', not exists (select 1 from public.founder_accounts a where (public.fmail_keys_verify200(a.user_id) ->> 'ok')::boolean is not true), 8
) t order by n;
