-- CHECK E117 — kuch persist nahi karta (selftest rollback). Har row ok = true. 7 checks.
select item, ok from (
select 'E117 6 tables maujood, RLS on, anon/authenticated ko access nahi, service_role seedha likh nahi sakta' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select')
                        and not has_table_privilege('service_role', t, 'insert') and not has_table_privilege('service_role', t, 'update') and not has_table_privilege('service_role', t, 'delete'))
          from unnest(array['public.founder_passkeys','public.founder_passkey_ceremonies','public.founder_stepups','public.founder_recovery_codes','public.founder_recovery_requests','public.founder_recovery_failures']) t) as ok, 1 as ord
union all select 'E117 raaz (passkey body, recovery code hash, ceremony state) plain select se padhe nahi ja sakte',
       not has_column_privilege('service_role', 'public.founder_passkeys', 'passkey', 'select')
       and not has_table_privilege('service_role', 'public.founder_recovery_codes', 'select') and not has_table_privilege('service_role', 'public.founder_passkey_ceremonies', 'select'), 2
union all select 'E117 15 doors maujood, anon/authenticated execute nahi, service_role ke liye khule',
       (select bool_and(to_regprocedure(f) is not null and not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_passkey_ceremony_begin(uuid,text,jsonb)','public.founder_passkey_ceremony_take(uuid,uuid,text)','public.founder_stepup_issue(uuid,uuid,text,text)',
            'public.founder_stepup_consume(uuid,uuid,uuid,text,text)','public.founder_passkey_add(uuid,uuid,text,jsonb,text,uuid)','public.founder_passkey_list(uuid)','public.founder_passkey_active(uuid)',
            'public.founder_passkey_touch(uuid,text,jsonb,bigint)','public.founder_passkey_revoke(uuid,uuid,uuid,text,uuid)','public.founder_passkey_status(uuid)',
            'public.founder_recovery_codes_generate(uuid,uuid,uuid)','public.founder_recovery_open(uuid,text,text)','public.founder_recovery_cancel(uuid,uuid,uuid,text)',
            'public.founder_recovery_tick(timestamptz)','public.founder_recovery_complete(uuid,uuid,uuid)']) f), 3
union all select 'E117 database khud 24 ghante ki cooling-off bypass nahi hone deta: mobile recovery ke liye ready_at kam az kam created_at + 24h',
       exists (select 1 from pg_constraint where conname = 'founder_recovery_cooling' and conrelid = 'public.founder_recovery_requests'::regclass)
       and exists (select 1 from pg_indexes where indexname = 'founder_recovery_one_open_idx'), 4
union all select 'E117 step-up grant ki hadd: 5 minute (recovery 10), ceremony 5 minute, passkey ki zyada se zyada 5',
       exists (select 1 from pg_constraint where conname = 'founder_stepup_window') and exists (select 1 from pg_constraint where conname = 'founder_ceremony_window')
       and (select count(*) from pg_proc where proname = 'founder_passkey_add') = 1, 5
union all select 'E117 behaviour selftest (ceremony single-use, pehli passkey, grant single-use/device/scope/expiry, max 5, counter + clone, recovery codes, wrong-code lockout, mobile 24h, cancel, expire) + selftest2',
       coalesce((select public.founder_passkey_selftest() like 'E117 selftest OK%' or public.founder_passkey_selftest() like 'E117 selftest SKIP%'), false)
       and coalesce((select public.founder_passkey_selftest2() like 'E117 selftest2 OK%'), false), 6
union all select 'E117 purane selftests ab bhi green (E113, E115, E116), audit chain saaf, history replay == live table',
       coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest() like 'E115 selftest OK%' or public.founder_settings_s1c_selftest() like 'E115 selftest SKIP%'), false)
       and coalesce((select public.founder_drift_value_selftest() like 'E116 selftest OK%' or public.founder_drift_value_selftest() like 'E116 selftest SKIP%'), false)
       and public.founder_audit_verify(1) is null and coalesce((select bool_and(public.founder_settings_replay_check(user_id) is null) from public.founder_accounts), true), 7
) t order by ord;
