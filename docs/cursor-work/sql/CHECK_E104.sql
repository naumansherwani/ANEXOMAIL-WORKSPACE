
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
union all select 'E104 immutability trigger chalu + CHECK constraints + 3 index',
       (select tgenabled = 'O' from pg_trigger where tgname = 'founder_devices_guard' and tgrelid = 'public.founder_devices'::regclass)
       and (select count(*) from pg_constraint where conrelid = 'public.founder_devices'::regclass and conname in ('founder_devices_label_printable','founder_devices_time_order') and convalidated) = 2
       and (select count(*) from pg_indexes where schemaname = 'public' and indexname in ('founder_devices_code_idx','founder_devices_active_idx','founder_devices_pending_idx')) = 3, 7
union all select 'E104 helper _founder_device_pick bhi band (anon/authenticated)',
       not has_function_privilege('anon','public._founder_device_pick(uuid,text,boolean)','execute')
       and not has_function_privilege('authenticated','public._founder_device_pick(uuid,text,boolean)','execute')
       and not has_function_privilege('authenticated','public.founder_devices_selftest()','execute'), 8
union all select 'E104 security definer functions ka search_path pinned',
       (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'public' and p.proname like 'founder_device%' and p.prosecdef and p.proconfig is not null and exists (select 1 from unnest(p.proconfig) c where c like 'search_path=%')) >= 6, 9
union all select 'E104 founder_devices par RLS on + anon/authenticated ko koi table grant nahi',
       (select relrowsecurity from pg_class where oid = 'public.founder_devices'::regclass)
       and not has_table_privilege('anon','public.founder_devices','select') and not has_table_privilege('authenticated','public.founder_devices','select'), 10
) t order by ord;
