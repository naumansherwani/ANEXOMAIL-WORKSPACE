-- CHECK E115 — kuch persist nahi karta (selftest rollback). Har row ok = true. 8 checks.
select item, ok from (
select 'E115 registry mein 22 keys: personal 5, workspace 3, notifications 2, privacy 1, appearance 11; har key ka info row hai aur har info row ki key registry mein hai' as item,
       (select count(*) from public.founder_setting_registry) = 22
       and (select count(*) from public.founder_setting_registry where area = 'personal') = 5 and (select count(*) from public.founder_setting_registry where area = 'workspace') = 3
       and (select count(*) from public.founder_setting_registry where area = 'notifications') = 2 and (select count(*) from public.founder_setting_registry where area = 'privacy') = 1
       and (select count(*) from public.founder_setting_registry where area = 'appearance') = 11
       and not exists (select 1 from public.founder_setting_registry r where not exists (select 1 from public.founder_settings_info i where i.key = r.key))
       and not exists (select 1 from public.founder_settings_info i where not exists (select 1 from public.founder_setting_registry r where r.key = i.key)) as ok, 1 as ord
union all select 'E115 awam ki 8 rows maujood: undo_send, send_check, retention_days, require_passkey, flag_external, quiet_hours, only_vips, block_trackers; read receipts ki koi key nahi',
       (select count(*) from public.founder_setting_registry where key in ('personal.undo_send','personal.send_check','workspace.retention_days','workspace.require_passkey','workspace.flag_external','notifications.quiet_hours','notifications.only_vips','privacy.block_trackers')) = 8
       and not exists (select 1 from public.founder_setting_registry where key like '%read_receipt%'), 2
union all select 'E115 har default valid hai aur defaults awam jaise hain (undo 30, retention 0 = forever, send check / passkey / external flag / quiet hours / trackers on, only VIPs off)',
       (select bool_and(public._founder_setting_valid(key, default_value)) from public.founder_setting_registry where default_value is not null and default_value <> 'null'::jsonb)
       and (select default_value from public.founder_setting_registry where key = 'personal.undo_send') = '30'::jsonb
       and (select default_value from public.founder_setting_registry where key = 'workspace.retention_days') = '0'::jsonb
       and (select default_value from public.founder_setting_registry where key = 'notifications.only_vips') = 'false'::jsonb
       and (select bool_and(default_value = 'true'::jsonb) from public.founder_setting_registry where key in ('personal.send_check','workspace.require_passkey','workspace.flag_external','notifications.quiet_hours','privacy.block_trackers')), 3
union all select 'E115 retention aur passkey high severity hain aur schedule nahi ho sakte; baqi 6 naye keys schedulable',
       (select count(*) from public.founder_settings_info where key in ('workspace.retention_days','workspace.require_passkey') and severity = 'high' and not schedulable) = 2
       and (select count(*) from public.founder_settings_info where key in ('personal.undo_send','personal.send_check','workspace.flag_external','notifications.quiet_hours','notifications.only_vips','privacy.block_trackers') and schedulable) = 6, 4
union all select 'E115 validator band: undo_send aur retention sirf band list ke integers, toggles sirf boolean',
       public._founder_setting_valid('personal.undo_send', '60'::jsonb) and not public._founder_setting_valid('personal.undo_send', '15'::jsonb) and not public._founder_setting_valid('personal.undo_send', '"30"'::jsonb)
       and public._founder_setting_valid('workspace.retention_days', '1825'::jsonb) and not public._founder_setting_valid('workspace.retention_days', '45'::jsonb)
       and public._founder_setting_valid('privacy.block_trackers', 'false'::jsonb) and not public._founder_setting_valid('privacy.block_trackers', '"false"'::jsonb), 5
union all select 'E115 behaviour selftest (22 keys, store, null-to-default, history + undo, explain + blast, schedule + rollback, replay, chain) + selftest2 (privileges, hygiene)',
       coalesce((select public.founder_settings_s1c_selftest() like 'E115 selftest OK%' or public.founder_settings_s1c_selftest() like 'E115 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest2() like 'E115 selftest2 OK%'), false), 6
union all select 'E115 E113 selftest + selftest2 + crosscheck ab bhi green, E114 ke fixed-count selftests hat gaye',
       coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s2_selftest2() like 'E113 selftest2 OK%'), false)
       and public.founder_settings_crosscheck() like 'E113 crosscheck OK%'
       and to_regprocedure('public.founder_appearance_selftest()') is null, 7
union all select 'E115 audit chain saaf (E102) aur har founder par history replay == live table',
       public.founder_audit_verify(1) is null and coalesce((select bool_and(public.founder_settings_replay_check(user_id) is null) from public.founder_accounts), true), 8
) t order by ord;
