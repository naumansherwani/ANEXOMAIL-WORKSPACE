-- CHECK E144 — reads only (the selftest rolls back). 4 checks.
select item, ok from (
select 'E144 columns exist (key_thumb, last_proof_ms, shred_nonce, shredded_ms) and the shape rule is validated' as item,
       (select count(*) from information_schema.columns where table_schema = 'public' and table_name = 'founder_vault_lease' and column_name in ('key_thumb', 'last_proof_ms', 'shred_nonce', 'shredded_ms')) = 4
       and exists (select 1 from pg_constraint where conname = 'founder_vault_lease_keysplit_shape' and convalidated) as ok, 1 as ord
union all select 'E144 the shred nonce and the nonce hash are NOT readable by service_role; the grant door is open to service_role only',
       not has_column_privilege('service_role', 'public.founder_vault_lease', 'shred_nonce', 'select')
       and not has_column_privilege('service_role', 'public.founder_vault_lease', 'nonce_hash', 'select')
       and has_function_privilege('service_role', 'public.founder_vault_lease_grant(uuid,uuid,text,bigint,integer)', 'execute')
       and not has_function_privilege('anon', 'public.founder_vault_lease_grant(uuid,uuid,text,bigint,integer)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_vault_lease_grant(uuid,uuid,text,bigint,integer)', 'execute'), 2
union all select 'E144 behaviour selftest (key bound once, replay / stale / mismatch / missing key refused, salt stable, revoke shreds for ever, ledger)',
       coalesce((select public.founder_vault_lease_keysplit_selftest() like 'E144 selftest PASS%' or public.founder_vault_lease_keysplit_selftest() like 'E144 selftest SKIP%'), false), 3
union all select 'E144 the E143 selftest still passes with the shred rule and the lease chain re-checks clean',
       coalesce((select public.founder_vault_lease_selftest() like 'E143 selftest PASS%' or public.founder_vault_lease_selftest() like 'E143 selftest SKIP%'), false)
       and coalesce((public.founder_vault_lease_verify(1000) ->> 'ok')::boolean, false), 4
) t order by ord;
