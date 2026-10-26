
select 'E91 kernel_session_key exists' as check_name,
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname = 'kernel_session_key') as ok
union all
select 'E91 service_role only (anon/authenticated no execute)',
       not has_function_privilege('anon', 'public.kernel_session_key(text,text)', 'execute')
       and not has_function_privilege('authenticated', 'public.kernel_session_key(text,text)', 'execute')
       and has_function_privilege('service_role', 'public.kernel_session_key(text,text)', 'execute')
union all
select 'E91 security definer + pinned search_path',
       exists (select 1 from pg_proc p where p.proname = 'kernel_session_key' and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%'))
union all
select 'E91 ticket -> session key -> tag verify (live)',
       (select public.kernel_request_verify(t->>'ticket', 'anexomail.com', 'x.1.y',
          encode(extensions.hmac(convert_to('x.1.y', 'UTF8'), convert_to((public.kernel_session_key(t->>'ticket', 'anexomail.com'))->>'session_key', 'UTF8'), 'sha256'), 'hex'))
        from (select public.kernel_ticket_issue('00000000-0000-4000-8000-000000000e91', 'anexomail.com', 60) as t) q)
