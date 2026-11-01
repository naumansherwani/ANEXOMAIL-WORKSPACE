-- CHECK E113 — kuch persist nahi karta (selftest rollback). Har row ok = true.
select item, ok from (
select 'E113 tables maujood + RLS on + anon/authenticated ko access nahi' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select'))
          from unnest(array['public.founder_settings_revert_log','public.founder_settings_schedule','public.founder_settings_info','public.founder_settings_baseline']) t) as ok, 1 as ord
union all select 'E113 RPC maujood, anon/authenticated execute nahi, service_role hai',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_settings_history_list(uuid,text,bigint,integer)','public.founder_setting_revert(uuid,bigint,text)','public.founder_settings_at(uuid,timestamptz)',
                            'public.founder_settings_diff(uuid,timestamptz,timestamptz)','public.founder_settings_replay_check(uuid)','public.founder_settings_timeline(uuid,integer)',
                            'public.founder_settings_drift(uuid)','public.founder_setting_explain(text)','public.founder_setting_blast(uuid,text)',
                            'public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)','public.founder_settings_schedule_cancel(uuid,uuid,text)',
                            'public.founder_settings_schedule_confirm(uuid,uuid,text)','public.founder_settings_schedule_tick(timestamptz)','public.founder_settings_schedule_preview(timestamptz)',
                            'public.founder_settings_schedule_list(uuid,integer)','public.founder_settings_pulse(uuid)','public.founder_settings_crosscheck(uuid)']) f), 2
union all select 'E113 revert log + schedule triggers chalu (append-only / state machine)',
       (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_revert_log') and tgname in ('founder_settings_revert_log_no_upd','founder_settings_revert_log_no_trunc')) = 2
       and (select count(*) from pg_trigger where tgrelid = to_regclass('public.founder_settings_schedule') and tgname in ('founder_settings_schedule_guard','founder_settings_schedule_no_trunc')) = 2, 3
union all select 'E113 service_role: registries read-only, revert log append-only, schedule bina delete',
       not has_table_privilege('service_role', 'public.founder_settings_info', 'insert') and not has_table_privilege('service_role', 'public.founder_settings_baseline', 'update')
       and not has_table_privilege('service_role', 'public.founder_settings_revert_log', 'update') and not has_table_privilege('service_role', 'public.founder_settings_revert_log', 'delete')
       and not has_table_privilege('service_role', 'public.founder_settings_schedule', 'delete'), 4
union all select 'E113 security definer RPC par search_path + statement_timeout pinned',
       (select bool_and(exists (select 1 from unnest(proconfig) c where c like 'search_path=%') and exists (select 1 from unnest(proconfig) c where c like 'statement_timeout=%'))
          from pg_proc where oid in (to_regprocedure('public.founder_setting_revert(uuid,bigint,text)'), to_regprocedure('public.founder_settings_schedule_tick(timestamptz)'),
                                     to_regprocedure('public.founder_settings_drift(uuid)'), to_regprocedure('public.founder_settings_history_list(uuid,text,bigint,integer)'),
                                     to_regprocedure('public.founder_settings_schedule_create(uuid,text,jsonb,timestamptz,integer,text)'))), 5
union all select 'E113 info registry: E108 ki har key ke liye plain-words row (5 after E113; every registry key after E114)', (select count(*) from public.founder_settings_info) >= 5 and not exists (select 1 from public.founder_settings_info i where to_regclass('public.founder_setting_registry') is not null and not exists (select 1 from public.founder_setting_registry r where r.key = i.key)), 6
union all select 'E113 baseline registry maujood (set + ledger policy rows)', (select count(*) from public.founder_settings_baseline) >= 5, 7
union all select 'E113 behaviour selftest (undo, replay, time travel, drift, schedule, auto-rollback, superseded, limits, guards)',
       coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false), 8
union all select 'E113 selftest2 (privileges, hygiene, coverage)', coalesce((select public.founder_settings_s2_selftest2() like 'E113 selftest2 OK%'), false), 9
union all select 'E113 crosscheck: history replay == live settings (second derivation)', public.founder_settings_crosscheck() like 'E113 crosscheck OK%', 10
union all select 'E113 har founder par history replay == live table (null = saaf)',
       coalesce((select bool_and(public.founder_settings_replay_check(user_id) is null) from public.founder_accounts), true), 11
union all select 'E113 asli founder par drift score 0..100 deta hai',
       coalesce((select bool_and((public.founder_settings_drift(user_id) ->> 'score')::integer between 0 and 100) from public.founder_accounts), true), 12
union all select 'E113 live source settings_history register', exists (select 1 from public.founder_live_sources where key = 'settings_history'), 13
union all select 'E113 audit chain saaf (E102)', public.founder_audit_verify(1) is null, 14
) t order by ord;
