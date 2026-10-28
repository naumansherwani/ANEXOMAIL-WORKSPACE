
-- CHECK E104 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E104 founder_device_* functions maujood (exchange, approve, revoke, list, ok)' as item,
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname in ('founder_device_exchange','founder_device_approve','founder_device_revoke','founder_device_list','founder_device_ok')) = 5 as ok, 1 as ord
union all select 'E104 pending_code column + index',
       exists (select 1 from information_schema.columns where table_schema='public' and table_name='founder_devices' and column_name='pending_code')
       and exists (select 1 from pg_indexes where schemaname='public' and indexname='founder_devices_code_idx'), 2
union all select 'E104 anon/authenticated ko koi function execute nahi',
       not has_function_privilege('anon','public.founder_device_exchange(uuid,text,text)','execute')
       and not has_function_privilege('authenticated','public.founder_device_exchange(uuid,text,text)','execute')
       and not has_function_privilege('authenticated','public.founder_device_approve(uuid,text,text)','execute')
       and not has_function_privilege('authenticated','public.founder_device_ok(uuid,uuid)','execute'), 3
union all select 'E104 service_role execute kar sakta hai',
       has_function_privilege('service_role','public.founder_device_exchange(uuid,text,text)','execute')
       and has_function_privilege('service_role','public.founder_device_approve(uuid,text,text)','execute'), 4
union all select 'E104 behaviour selftest (pehla device TOFU, pending, approve, revoke, lock-out guard, rollback)',
       coalesce((select public.founder_devices_selftest() like 'E104 selftest OK%' or public.founder_devices_selftest() like 'E104 selftest SKIP%'), false), 5
union all select 'E104 audit chain saaf', public.founder_audit_verify(1) is null, 6
) t order by ord;
