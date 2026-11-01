-- CHECK E116 — kuch persist nahi karta (selftest rollback). Har row ok = true. 6 checks.
select item, ok from (
select 'E116 baseline mein teen rules: set 2, max 3, value 5; value rule ke liye safe_value zaroori aur recommended null' as item,
       (select count(*) from public.founder_settings_baseline where rule = 'set') = 2 and (select count(*) from public.founder_settings_baseline where rule = 'max') = 3
       and (select count(*) from public.founder_settings_baseline where rule = 'value') = 5
       and not exists (select 1 from public.founder_settings_baseline where rule = 'value' and (safe_value is null or recommended is not null)) as ok, 1 as ord
union all select 'E116 paanch value rows: passkey (risky agar off), external flag, send check, quiet hours, trackers (loose agar off); undo window / retention / only VIPs measure nahi hote',
       (select count(*) from public.founder_settings_baseline where key in ('workspace.require_passkey','workspace.flag_external','personal.send_check','notifications.quiet_hours','privacy.block_trackers') and rule = 'value') = 5
       and (select if_off from public.founder_settings_baseline where key = 'workspace.require_passkey') = 'risky'
       and not exists (select 1 from public.founder_settings_baseline where key in ('personal.undo_send','workspace.retention_days','notifications.only_vips')), 2
union all select 'E116 har value row registry ki key hai aur safe value us key ke liye valid hai',
       not exists (select 1 from public.founder_settings_baseline b where b.rule = 'value' and (not exists (select 1 from public.founder_setting_registry r where r.key = b.key) or not public._founder_setting_valid(b.key, b.safe_value))), 3
union all select 'E116 behaviour selftest (defaults aligned, off -> risky/loose, score girta hai, null se wapas aligned, explain recommended dikhata hai)',
       coalesce((select public.founder_drift_value_selftest() like 'E116 selftest OK%' or public.founder_drift_value_selftest() like 'E116 selftest SKIP%'), false), 4
union all select 'E116 E113 + E115 selftests ab bhi green',
       coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest() like 'E115 selftest OK%' or public.founder_settings_s1c_selftest() like 'E115 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest2() like 'E115 selftest2 OK%'), false), 5
union all select 'E116 privileges: drift/explain/selftest anon aur authenticated ke liye band, service_role ke liye khule; audit chain saaf',
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
          from unnest(array['public.founder_settings_drift(uuid)','public.founder_setting_explain(text)','public.founder_drift_value_selftest()']) f)
       and public.founder_audit_verify(1) is null, 6
) t order by ord;
