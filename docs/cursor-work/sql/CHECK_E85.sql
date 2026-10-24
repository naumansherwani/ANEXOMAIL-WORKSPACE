-- CHECK E85 — mail_thread_assign. Sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E85 mail_thread_assign: sirf EK function (uuid,uuid,uuid)' as item,
         (select count(*) from pg_proc where proname = 'mail_thread_assign' and pronamespace = 'public'::regnamespace) = 1
         and to_regprocedure('public.mail_thread_assign(uuid,uuid,uuid)') is not null as ok, 1 as o
  union all select 'E85 anon/authenticated execute nahi, service_role hai',
         not has_function_privilege('anon', 'public.mail_thread_assign(uuid,uuid,uuid)', 'execute')
         and not has_function_privilege('authenticated', 'public.mail_thread_assign(uuid,uuid,uuid)', 'execute')
         and has_function_privilege('service_role', 'public.mail_thread_assign(uuid,uuid,uuid)', 'execute'), 2
  union all select 'E85 member check + search_path pinned',
         pg_get_functiondef('public.mail_thread_assign(uuid,uuid,uuid)'::regprocedure) like '%assignee_not_member%'
         and coalesce((select proconfig::text from pg_proc where oid = 'public.mail_thread_assign(uuid,uuid,uuid)'::regprocedure), '') like '%search_path%', 3
) t order by o;
