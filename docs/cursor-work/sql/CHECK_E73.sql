-- CHECK E73 — sirf padhta hai. Har row ok = true. (calendar subscriptions)
select item, ok from (
  select 'E73 2 tables + RLS ON + anon/authenticated ko koi haq nahi' as item,
         (select count(*) from pg_class where relname in ('calendar_subscriptions', 'calendar_subscription_events') and relnamespace = 'public'::regnamespace and relrowsecurity) = 2
         and not has_table_privilege('anon', 'public.calendar_subscriptions', 'select') and not has_table_privilege('authenticated', 'public.calendar_subscriptions', 'select')
         and not has_table_privilege('authenticated', 'public.calendar_subscription_events', 'insert') as ok, 1 as o
  union all select 'E73 sab functions: execute sirf service_role',
         (select bool_and(has_function_privilege('service_role', f, 'execute') and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute'))
            from unnest(array['public.cal_sub_add(uuid,text,text,text,text,integer)', 'public.cal_sub_list(uuid)', 'public.cal_sub_update(uuid,uuid,text,text,boolean,integer)',
                              'public.cal_sub_remove(uuid,uuid)', 'public.cal_sub_due(uuid,uuid,integer)', 'public.cal_sub_apply(uuid,uuid,text,text,text,jsonb,jsonb)',
                              'public.cal_sub_notmodified(uuid,uuid)', 'public.cal_sub_fail(uuid,uuid,text,integer)', 'public.cal_sub_events(uuid,bigint,bigint)',
                              'public.calendar_sub_purge_deleted(integer)']) f), 2
  union all select 'E73 har cal_sub_* function ka search_path pinned',
         not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and (p.proname like 'cal\_sub\_%' or p.proname = 'calendar_sub_purge_deleted') and p.proconfig is null), 3
  union all select 'E73 URL https ke siwa nahi (check constraint)',
         exists (select 1 from pg_constraint where conrelid = 'public.calendar_subscriptions'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%https://%'), 4
  union all select 'E73 invariant: har feed ka event_count <= 2000 aur har user ke <= 10 subscriptions',
         not exists (select 1 from public.calendar_subscriptions where event_count > 2000)
         and not exists (select 1 from public.calendar_subscriptions group by user_id having count(*) > 10), 5
) q order by o;
