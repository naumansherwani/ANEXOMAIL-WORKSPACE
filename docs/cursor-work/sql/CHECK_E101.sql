
-- CHECK E101 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E101 activity_log naye columns (source_id, thread_id, source, meta)' as item,
       (select count(*) from information_schema.columns where table_schema='public' and table_name='activity_log' and column_name in ('source_id','thread_id','source','meta')) = 4 as ok, 1 as n
union all select 'E101 exact dedupe index (org, kind, source_id)',
       exists (select 1 from pg_indexes where schemaname='public' and indexname='activity_log_source_uq'), 2
union all select 'E101 mail_messages trigger laga hai',
       exists (select 1 from pg_trigger where tgname='mail_messages_activity' and not tgisinternal), 3
union all select 'E101 sab 9 functions maujood',
       (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
         and p.proname in ('activity_record','activity_feed','activity_heal','activity_prune','activity_health','activity_summary','activity_anomalies','activity_search','activity_daily_refresh')) = 9, 4
union all select 'E101 functions anon/authenticated se band',
       not has_function_privilege('anon','public.activity_record(uuid,text,text,text,uuid,text,uuid,uuid,timestamptz,jsonb,text)','execute')
       and not has_function_privilege('authenticated','public.activity_feed(uuid,integer,timestamptz,text[])','execute')
       and not has_function_privilege('authenticated','public.activity_heal(integer,uuid)','execute'), 5
union all select 'E101 authenticated activity_log mein likh nahi sakta (sirf padh)',
       not has_table_privilege('authenticated','public.activity_log','insert')
       and not has_table_privilege('authenticated','public.activity_log','delete')
       and not has_table_privilege('anon','public.activity_log','select'), 6
union all select 'E101 RLS on (activity_log + activity_daily)',
       (select count(*) from pg_class where oid in ('public.activity_log'::regclass,'public.activity_daily'::regclass) and relrowsecurity) = 2, 7
union all select 'E101 pichle 7 din ki koi mail bina activity ke nahi',
       coalesce((public.activity_health(7)->>'ok')::boolean, false), 8
union all select 'E101 feed jawab deta hai',
       coalesce((public.activity_feed('00000000-0000-4000-8000-0000000e1010'::uuid, 5, null, null)->>'ok')::boolean, false)
       and jsonb_array_length(public.activity_feed('00000000-0000-4000-8000-0000000e1010'::uuid, 5, null, null)->'items') = 0, 9
) t order by n;
