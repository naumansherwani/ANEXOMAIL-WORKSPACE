
-- CHECK E74 — meeting par files. Har row ok = true. (sirf padhta hai; behaviour proof: proofs/E74_proof.sql sandbox mein)
select item, ok from (
  select 'E74 table calendar_event_files + RLS ON + anon/authenticated ko koi haq nahi' as item,
         exists (select 1 from pg_class where relname = 'calendar_event_files' and relnamespace = 'public'::regnamespace and relrowsecurity)
         and not has_table_privilege('anon', 'public.calendar_event_files', 'select')
         and not has_table_privilege('authenticated', 'public.calendar_event_files', 'select')
         and not has_table_privilege('authenticated', 'public.calendar_event_files', 'insert') as ok, 1 as o
  union all select 'E74 functions: execute sirf service_role',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array['public._cal_file_gate(uuid,uuid,uuid,boolean)', 'public.cal_file_attach(uuid,uuid,uuid,uuid)', 'public.cal_file_list(uuid,uuid,uuid)',
                              'public.cal_file_remove(uuid,uuid,uuid,uuid)', 'public.mail_attach_resolve(uuid,uuid)', 'public.mail_attach_gc()']) f), 2
  union all select 'E74 meeting delete par rows apne-aap (FK cascade) + blob par restrict + ek file ek meeting par ek baar',
         (select count(*) from pg_constraint where conrelid = 'public.calendar_event_files'::regclass and contype = 'f' and confdeltype = 'c') = 1
         and (select count(*) from pg_constraint where conrelid = 'public.calendar_event_files'::regclass and contype = 'f' and confdeltype = 'r') = 1
         and exists (select 1 from pg_constraint where conrelid = 'public.calendar_event_files'::regclass and contype = 'u'), 3
  union all select 'E74 GC ab meeting ki files ko bhi dekhta hai (yateem samajh kar mitata nahi)',
         position('calendar_event_files' in pg_get_functiondef('public.mail_attach_gc()'::regprocedure)) > 0, 4
  union all select 'E74 download (mail_attach_resolve) meeting ki file ko jaanta hai',
         position('calendar_event_files' in pg_get_functiondef('public.mail_attach_resolve(uuid,uuid)'::regprocedure)) > 0, 5
  union all select 'E74 pinned search_path (sab security definer functions)',
         (select bool_and(coalesce(p.proconfig::text, '') like '%search_path%')
            from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('_cal_file_gate', 'cal_file_attach', 'cal_file_list', 'cal_file_remove')), 6
) t order by o;
