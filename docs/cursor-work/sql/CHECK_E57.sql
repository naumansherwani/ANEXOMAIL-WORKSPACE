-- CHECK E57 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E57 awam_ui_pref table' as item, to_regclass('public.awam_ui_pref') is not null as ok, 1 as o
  union all select 'E57 teeno columns',
         (select count(*) from information_schema.columns where table_schema='public' and table_name='awam_ui_pref'
            and column_name in ('clock','cal_layout','updated_at')) = 3, 2
  union all select 'E57 clock/layout check constraints',
         (select count(*) from pg_constraint where conname in ('awam_ui_pref_clock_ck','awam_ui_pref_layout_ck')) = 2, 3
  union all select 'E57 RLS on', coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.awam_ui_pref')), false), 4
  union all select 'E57 anon/authenticated band',
         not (has_table_privilege('anon','public.awam_ui_pref','select') or has_table_privilege('authenticated','public.awam_ui_pref','select')), 5
  union all select 'E57 service_role chala sakta hai',
         has_table_privilege('service_role','public.awam_ui_pref','select') and has_table_privilege('service_role','public.awam_ui_pref','insert'), 6
) t order by o;
