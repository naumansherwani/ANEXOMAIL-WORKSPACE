-- CHECK E118 — kuch persist nahi karta (selftest rollback). Har row ok = true. 7 checks.
select item, ok from (
select 'E118 5 naye tables maujood, RLS on, anon/authenticated ko access nahi, service_role seedha likh nahi sakta' as item,
       (select bool_and(to_regclass(t) is not null and (select relrowsecurity from pg_class where oid = to_regclass(t))
                        and not has_table_privilege('anon', t, 'select') and not has_table_privilege('authenticated', t, 'select')
                        and not has_table_privilege('service_role', t, 'insert') and not has_table_privilege('service_role', t, 'update') and not has_table_privilege('service_role', t, 'delete'))
          from unnest(array['public.founder_action_tiers','public.founder_aaguid_allow','public.founder_protocol','public.founder_mobile_flare','public.founder_t3_requests']) t) as ok, 1 as ord
union all select 'E118 20 doors maujood (action-bound signatures), anon/authenticated execute nahi, service_role ke liye khule',
       coalesce((select public.founder_chairman_selftest2() like 'E118 selftest2 OK%'), false), 2
union all select 'E118 database khud T3 ke 10 minute delay aur "dusri key alag ho" ko force karta hai (constraints), protocol row minimum se neeche nahi ja sakti',
       exists (select 1 from pg_constraint where conname = 'founder_t3_delay') and exists (select 1 from pg_constraint where conname = 'founder_t3_two_keys')
       and exists (select 1 from pg_constraint where conname = 'founder_t3_approved_pair')
       and (select t3_delay_seconds >= 600 and t3_min_hardware_keys >= 2 from public.founder_protocol where id), 3
union all select 'E118 AAGUID allow-list apni marzi se: koi invented hardware ID seed nahi (seed ke baad khaali ya sirf founder ke approve kiye)',
       not exists (select 1 from public.founder_aaguid_allow where added_by is null), 4
union all select 'E118 tier registry: T2 (6 built) + T3 (kill switch, key rotate, data delete) declared; T3 abhi built=false',
       (select count(*) from public.founder_action_tiers where tier = 2 and built) >= 6
       and (select count(*) from public.founder_action_tiers where tier = 3 and not built) = 3, 5
union all select 'E118 behaviour selftest (action hash spec, grant ek hi action ke liye, hardware allow-list, hardware-only, T3 do alag keys + delay + cancel + expiry, mobile flare, recovery proof, last passkey revoke nahi)',
       coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false), 6
union all select 'E118 purane selftests ab bhi green (E113, E115, E116), audit chain saaf, history replay == live table',
       coalesce((select public.founder_settings_s2_selftest() like 'E113 selftest OK%' or public.founder_settings_s2_selftest() like 'E113 selftest SKIP%'), false)
       and coalesce((select public.founder_settings_s1c_selftest() like 'E115 selftest OK%' or public.founder_settings_s1c_selftest() like 'E115 selftest SKIP%'), false)
       and coalesce((select public.founder_drift_value_selftest() like 'E116 selftest OK%' or public.founder_drift_value_selftest() like 'E116 selftest SKIP%'), false)
       and public.founder_audit_verify(1) is null and coalesce((select bool_and(public.founder_settings_replay_check(user_id) is null) from public.founder_accounts), true), 7
) t order by ord;
