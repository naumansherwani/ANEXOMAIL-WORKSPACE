
-- CHECK E81 — Calendar link (feed). Sirf padhta hai (kuch likhta nahi). Har row ok = true.
select item, ok from (
  select 'E81 kind column + constraint (dav|feed) VALIDATED' as item,
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'caldav_app_passwords' and column_name = 'kind' and is_nullable = 'NO')
         and exists (select 1 from pg_constraint c where c.conname = 'caldav_app_passwords_kind' and c.convalidated
                       and pg_get_constraintdef(c.oid) like '%dav%' and pg_get_constraintdef(c.oid) like '%feed%') as ok, 1 as o
  union all select 'E81 RLS abhi bhi on + anon/authenticated ko table par koi haq nahi',
         (select c.relrowsecurity from pg_class c where c.oid = 'public.caldav_app_passwords'::regclass)
         and not has_table_privilege('anon', 'public.caldav_app_passwords', 'select') and not has_table_privilege('authenticated', 'public.caldav_app_passwords', 'select'), 2
  union all select 'E81 naye/badle functions: service_role ke ilawa kisi ko execute nahi',
         has_function_privilege('service_role', 'public.caldav_feed_lookup(text)', 'execute')
         and has_function_privilege('service_role', 'public.caldav_feed_create(uuid,uuid,text,text,text,text)', 'execute')
         and has_function_privilege('service_role', 'public.caldav_feed_list(uuid)', 'execute')
         and not has_function_privilege('anon', 'public.caldav_feed_lookup(text)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_feed_lookup(text)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_feed_create(uuid,uuid,text,text,text,text)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_feed_list(uuid)', 'execute')
         and not has_function_privilege('authenticated', 'public.caldav_auth_lookup(text)', 'execute'), 3
  union all select 'E81 pinned search_path (6 function)',
         (select count(*) = 6 and bool_and(coalesce(p.proconfig::text, '') like '%search_path%') from pg_proc p where p.oid in (
            'public.caldav_apppw_create(uuid,uuid,text,text,text,text)'::regprocedure, 'public.caldav_apppw_list(uuid)'::regprocedure, 'public.caldav_auth_lookup(text)'::regprocedure,
            'public.caldav_feed_create(uuid,uuid,text,text,text,text)'::regprocedure, 'public.caldav_feed_list(uuid)'::regprocedure, 'public.caldav_feed_lookup(text)'::regprocedure)), 4
  union all select 'E81 kind-ki-hifazat: Basic lookup sirf dav, feed lookup sirf feed (function ka asli matn)',
         pg_get_functiondef('public.caldav_auth_lookup(text)'::regprocedure) like '%kind = ''dav''%'
         and pg_get_functiondef('public.caldav_feed_lookup(text)'::regprocedure) like '%kind = ''feed''%'
         and pg_get_functiondef('public.caldav_apppw_list(uuid)'::regprocedure) like '%kind = ''dav''%'
         and pg_get_functiondef('public.caldav_feed_list(uuid)'::regprocedure) like '%kind = ''feed''%', 5
  union all select 'E81 behaviour: anjaan token par dono lookup null, anjaan user ki dono list khali',
         public.caldav_feed_lookup('zzzzzzzzzz') is null and public.caldav_auth_lookup('zzzzzzzzzz') is null
         and public.caldav_feed_list('00000000-0000-0000-0000-000000000000'::uuid) = '[]'::jsonb
         and public.caldav_apppw_list('00000000-0000-0000-0000-000000000000'::uuid) = '[]'::jsonb, 6
) t order by o;
