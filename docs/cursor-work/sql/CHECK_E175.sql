
-- CHECK E175 - DKIM key lifecycle, signature log, DNS confirmation, outside-receiver proof, policy ratchets (Q1d-1a). Writes nothing (the selftest rolls itself back). 7 checks.
select item, ok from (
select 'E175 the four tables exist, RLS forced, nothing readable by anon or authenticated' as item,
       (select count(*) from pg_class c where c.oid in ('public.fmail_dkim_policy'::regclass, 'public.fmail_dkim_dns_obs'::regclass, 'public.fmail_dkim_sign_log'::regclass, 'public.fmail_dkim_proof'::regclass) and c.relforcerowsecurity) = 4
       and not exists (select 1 from unnest(array['fmail_dkim_policy', 'fmail_dkim_dns_obs', 'fmail_dkim_sign_log', 'fmail_dkim_proof']) t where has_table_privilege('anon', 'public.' || t, 'select') or has_table_privilege('authenticated', 'public.' || t, 'select')) as ok, 1 as ord
union all select 'E175 the three evidence tables refuse UPDATE, DELETE and TRUNCATE (6 triggers)',
       (select count(*) from pg_trigger where tgfoid = 'public.fmail_dkim_immutable175()'::regprocedure and not tgisinternal) = 6, 2
union all select 'E175 the policy ratchet trigger is installed and the overlap CHECK holds',
       (select count(*) from pg_trigger where tgname = 'fmail_dkim_policy_guard' and not tgisinternal) = 1
       and (select count(*) from pg_constraint where conrelid = 'public.fmail_dkim_policy'::regclass and conname = 'fmail_dkim_policy_overlap_ck') = 1, 3
union all select 'E175 every door is service_role only with a fixed search_path',
       not exists (select 1 from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname in ('fmail_dkim_policy_set175', 'fmail_dkim_dns_record175', 'fmail_dkim_sign_record175', 'fmail_dkim_proof175', 'fmail_dkim_health175', 'fmail_dkim_send_gate175', 'fmail_dkim_rotation175', 'fmail_dkim_selector175', 'fmail_dkim_chain_verify175')
                   and (not p.prosecdef or p.proconfig is null or has_function_privilege('anon', p.oid, 'execute') or has_function_privilege('authenticated', p.oid, 'execute') or not has_function_privilege('service_role', p.oid, 'execute'))), 4
union all select 'E175 the ledger action list holds dkim_policy, dkim_dns_check and dkim_proof',
       exists (select 1 from pg_constraint where conrelid = 'public.fmail_ledger'::regclass and contype = 'c' and pg_get_constraintdef(oid) like '%dkim_policy%' and pg_get_constraintdef(oid) like '%dkim_dns_check%' and pg_get_constraintdef(oid) like '%dkim_proof%'), 5
union all select 'E175 the three hash chains verify (' || (public.fmail_dkim_chain_verify175() ->> 'checked') || ' rows checked, ' || (public.fmail_dkim_chain_verify175() ->> 'broken') || ' broken)',
       (public.fmail_dkim_chain_verify175() ->> 'broken') = '0', 6
union all select 'E175 selftest: ' || public.fmail_dkim_selftest175(), public.fmail_dkim_selftest175() = 'E175 selftest: 28 ok, 0 failed', 7
) t order by ord;
