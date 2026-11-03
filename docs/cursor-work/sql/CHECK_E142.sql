-- CHECK E142 — reads only (the selftests roll back). 4 checks.
select item, ok from (
select 'E142 truth rule + readiness exist, closed to anon/authenticated, open to service_role' as item,
       (select bool_and(not has_function_privilege('anon', f, 'execute') and not has_function_privilege('authenticated', f, 'execute') and has_function_privilege('service_role', f, 'execute'))
        from unnest(array['public._fh_hw_facts_ok(boolean,text)', 'public._fh_reclassify(uuid)', 'public.founder_hardware_readiness(uuid)', 'public.founder_hardware_e142_selftest()']) f) as ok, 1 as ord
union all select 'E142 triggers installed: key class re-decided when a key''s facts arrive and when the trusted-model list changes',
       exists (select 1 from pg_trigger where tgname = 'founder_hw_truth_cred' and not tgisinternal and tgenabled <> 'D')
       and exists (select 1 from pg_trigger where tgname = 'founder_hw_truth_allow' and not tgisinternal and tgenabled <> 'D'), 2
union all select 'E142 no active key is hardware unless its model is trusted AND its facts say device-bound (BE=0, not platform) — real data, right now',
       not exists (select 1 from public.founder_passkeys k join public.founder_webauthn_cred c on c.credential_id = k.credential_id
                    where k.revoked_at is null and k.kind = 'hardware' and not (public._fh_hw_facts_ok(c.be, c.attachment) and exists (select 1 from public.founder_aaguid_allow a where a.aaguid = c.aaguid and a.enabled))), 3
union all select 'E142 behaviour selftest (synced/platform claimants never count, trust upgrades only real keys, switch ON with 2 keys, un-trust demotes, ledger + chain) and E118 still green',
       coalesce((select public.founder_hardware_e142_selftest() like 'E142 selftest OK%' or public.founder_hardware_e142_selftest() like 'E142 selftest SKIP%'), false)
       and coalesce((select public.founder_chairman_selftest() like 'E118 selftest OK%' or public.founder_chairman_selftest() like 'E118 selftest SKIP%'), false), 4
) t order by ord;
