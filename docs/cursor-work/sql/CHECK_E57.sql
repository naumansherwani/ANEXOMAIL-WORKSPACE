
-- CHECK E57 — sirf padhta hai. Har row ok = true.
select item, ok from (
  select 'E57 awam_ui_pref table' as item, to_regclass('public.awam_ui_pref') is not null as ok, 1 as o
  union all select 'E57 chaaron columns (clock, cal_layout, extra, updated_at)',
         (select count(*) from information_schema.columns where table_schema='public' and table_name='awam_ui_pref'
            and column_name in ('clock','cal_layout','extra','updated_at')) = 4, 2
  union all select 'E57 teeno check constraints (clock/layout/extra)',
         (select count(*) from pg_constraint where conname in ('awam_ui_pref_clock_ck','awam_ui_pref_layout_ck','awam_ui_pref_extra_ck')) = 3, 3
  union all select 'E57 account-delete FK (ya auth.users nahi)',
         to_regclass('auth.users') is null or exists (select 1 from pg_constraint where conname = 'awam_ui_pref_user_fk' and convalidated), 4
  union all select 'E57 updated_at trigger', exists (select 1 from pg_trigger where tgname = 'awam_ui_pref_touch' and not tgisinternal), 5
  union all select 'E57 RLS on', coalesce((select relrowsecurity from pg_class where oid = to_regclass('public.awam_ui_pref')), false), 6
  union all select 'E57 anon/authenticated band',
         not (has_table_privilege('anon','public.awam_ui_pref','select') or has_table_privilege('authenticated','public.awam_ui_pref','select')), 7
  union all select 'E57 service_role chala sakta hai',
         has_table_privilege('service_role','public.awam_ui_pref','select') and has_table_privilege('service_role','public.awam_ui_pref','insert'), 8
) t order by o;
