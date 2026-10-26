
select bool_and(ok) as ok from (
  select to_regclass('public.crm_pipelines') is not null and to_regclass('public.crm_pipeline_stages') is not null
     and to_regclass('public.crm_field_defs') is not null and to_regclass('public.crm_forms') is not null
     and to_regclass('public.crm_merge_log') is not null as ok
  union all
  select (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relname in ('crm_pipelines','crm_pipeline_stages','crm_field_defs','crm_forms','crm_merge_log') and c.relrowsecurity) = 5
  union all
  select not has_table_privilege('anon', 'public.crm_forms', 'select') and not has_table_privilege('authenticated', 'public.crm_forms', 'select')
  union all
  select has_function_privilege('service_role', 'public.crm_form_submit(text,jsonb,int)', 'execute')
     and not has_function_privilege('anon', 'public.crm_form_submit(text,jsonb,int)', 'execute')
     and not has_function_privilege('authenticated', 'public.crm_merge(text,uuid,uuid[],text,text)', 'execute')
  union all
  select (select count(*) from pg_proc p where p.proname in ('crm_form_submit','crm_form_public','crm_merge') and p.prosecdef
          and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')) = 3
  union all
  select exists (select 1 from information_schema.columns where table_name = 'crm_deals' and column_name = 'pipeline_id')
     and exists (select 1 from information_schema.columns where table_name = 'crm_leads' and column_name = 'custom')
  union all
  select (select count(*) from pg_proc p where p.proname in ('crm_pipeline_save','crm_pipeline_delete','crm_field_save','crm_field_delete','crm_form_save','crm_form_delete','crm_ensure_default_pipeline') and p.prosecdef and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')) = 7
     and not has_function_privilege('authenticated', 'public.crm_pipeline_save(text,uuid,text,jsonb,text,int)', 'execute')
  union all
  select (select count(*) from pg_trigger where tgname in ('crm_pipelines_ceiling','crm_fields_ceiling','crm_forms_ceiling')) = 3
) q;
