-- CHECK E108 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E108 founder_settings + history tables, RLS on, anon/authenticated ko koi access nahi' as item,
       to_regclass('public.founder_settings') is not null and to_regclass('public.founder_settings_history') is not null
       and (select relrowsecurity from pg_class where oid = 'public.founder_settings'::regclass)
       and (select relrowsecurity from pg_class where oid = 'public.founder_settings_history'::regclass)
       and not has_table_privilege('anon','public.founder_settings','select') and not has_table_privilege('authenticated','public.founder_settings','select')
       and not has_table_privilege('authenticated','public.founder_settings_history','select') as ok, 1 as n
union all select 'E108 RPC maujood, anon/authenticated execute nahi, service_role hai',
       to_regprocedure('public.founder_setting_set(uuid,text,jsonb)') is not null and to_regprocedure('public.founder_settings_get(uuid)') is not null
       and not has_function_privilege('anon','public.founder_setting_set(uuid,text,jsonb)','execute') and not has_function_privilege('authenticated','public.founder_setting_set(uuid,text,jsonb)','execute')
       and has_function_privilege('service_role','public.founder_setting_set(uuid,text,jsonb)','execute'), 2
union all select 'E108 registry CHECK + value size CHECK',
       exists (select 1 from pg_constraint where conname='founder_settings_key_registry' and conrelid='public.founder_settings'::regclass)
       and exists (select 1 from pg_constraint where conname='founder_settings_value_size' and conrelid='public.founder_settings'::regclass), 3
union all select 'E108 history append-only triggers chalu',
       (select count(*) from pg_trigger where tgrelid='public.founder_settings_history'::regclass and tgname in ('founder_settings_history_no_upd','founder_settings_history_no_trunc') and tgenabled='O') = 2, 4
union all select 'E108 behaviour selftest (har key, invalid, null=default, history, audit, rollback)',
       coalesce((select public.founder_settings_selftest() like 'E108 selftest OK%' or public.founder_settings_selftest() like 'E108 selftest SKIP%'), false), 5
union all select 'E108 audit chain saaf', public.founder_audit_verify(1) is null, 6
) t order by n;
