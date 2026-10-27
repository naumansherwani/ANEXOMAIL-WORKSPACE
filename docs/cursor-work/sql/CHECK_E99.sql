
-- CHECK E99 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E99 functions maujood' as item,
       to_regprocedure('public.file_context_find(uuid,text,integer)') is not null
       and to_regprocedure('public.file_stem(text)') is not null and to_regprocedure('public.file_kind_exts(text)') is not null as ok, 1 as n
union all select 'E99 file_stem naam ki family sahi',
       public.file_stem('CRM Sheet v2.xlsx') = 'crm sheet' and public.file_stem('CRM_sheet_FINAL (1).xlsx') = 'crm sheet', 2
union all select 'E99 anon/authenticated chala nahi sakte',
       not has_function_privilege('anon','public.file_context_find(uuid,text,integer)','execute')
       and not has_function_privilege('authenticated','public.file_context_find(uuid,text,integer)','execute'), 3
union all select 'E99 khali org par jawab ok + khali',
       coalesce((public.file_context_find('00000000-0000-4000-8000-0000000e9900'::uuid,'crm sheet',3)->>'ok')::boolean, false)
       and jsonb_array_length(public.file_context_find('00000000-0000-4000-8000-0000000e9900'::uuid,'crm sheet',3)->'files') = 0, 4
union all select 'E99 mail_attachments.sha256 column',
       exists (select 1 from information_schema.columns where table_schema='public' and table_name='mail_attachments' and column_name='sha256'), 5
) t order by n;
