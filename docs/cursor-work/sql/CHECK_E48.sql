-- CHECK E48 (attachments bhejna) — sirf padhta hai, kuch badalta nahi. Supabase SQL editor mein paste, Run. Har row ka ok = true hona chahiye.
select item, ok from (
  select 'E48 mail_attach_limits (1 row: ceiling 7000000)' as item,
         coalesce((select count(*) >= 1 from public.mail_attach_limits), false) as ok, 1 as o
  union all select 'E48 org_attachment_blobs',        to_regclass('public.org_attachment_blobs') is not null, 2
  union all select 'E48 mail_outbound_attachments',   to_regclass('public.mail_outbound_attachments') is not null, 3
  union all select 'E48 mail_attachments.sha256/scan/org_id',
         (select count(*) = 3 from information_schema.columns where table_schema = 'public' and table_name = 'mail_attachments' and column_name in ('sha256','scan','org_id')), 4
  union all select 'E48 mail_scheduled.attachment_ids',
         exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'mail_scheduled' and column_name = 'attachment_ids'), 5
  union all select 'E48 functions (register/remove/stage_check/commit/resolve/gc/ctx)',
         (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in
             ('mail_attach_register','mail_attach_remove','mail_attach_stage_check','mail_attach_commit','mail_attach_resolve','mail_attach_gc','mail_attach_ctx')) = 7, 6
  union all select 'E48 band: anon/authenticated koi function nahi chala sakta',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'public' and p.proname like 'mail_attach\_%'
                       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 7
  union all select 'E48 band: tables par anon/authenticated haq nahi',
         not exists (select 1 from information_schema.role_table_grants
                     where table_schema = 'public' and table_name in ('mail_attach_limits','org_attachment_blobs','mail_outbound_attachments')
                       and grantee in ('anon','authenticated','PUBLIC')), 8
) t order by o;
