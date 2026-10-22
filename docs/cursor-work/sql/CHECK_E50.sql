
-- CHECK E50 (aane wali mail ke attachments) — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E50 mail_attach_org_limit' as item, to_regprocedure('public.mail_attach_org_limit(uuid)') is not null as ok, 1 as o
  union all select 'E50 mail_attach_inbound_register', to_regprocedure('public.mail_attach_inbound_register(uuid,uuid,int,text,text,bigint,text,text,jsonb)') is not null, 2
  union all select 'E50 band: anon/authenticated nahi chala sakte',
         not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                     where n.nspname = 'public' and p.proname in ('mail_attach_org_limit','mail_attach_inbound_register')
                       and (has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute'))), 3
  union all select 'E50 ceiling 18 MB (E49)', coalesce((select value from public.mail_attach_limits where key = 'server_ceiling_bytes'), 0) = 18874368, 4
) t order by o;
