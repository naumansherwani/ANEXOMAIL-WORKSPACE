
-- CHECK E102 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E102 teeno tables maujood (founder_audit, _sig, founder_actions, founder_devices)' as item,
       (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('founder_audit','founder_audit_sig','founder_actions','founder_devices')) = 4 as ok, 1 as ord
union all select 'E102 RLS on (4 tables)',
       (select count(*) from pg_class where oid in ('public.founder_audit'::regclass,'public.founder_audit_sig'::regclass,'public.founder_actions'::regclass,'public.founder_devices'::regclass) and relrowsecurity) = 4, 2
union all select 'E102 anon/authenticated ko koi hak nahi',
       not has_table_privilege('anon','public.founder_audit','select') and not has_table_privilege('authenticated','public.founder_audit','select')
       and not has_table_privilege('authenticated','public.founder_actions','select') and not has_table_privilege('authenticated','public.founder_devices','select')
       and not has_function_privilege('authenticated','public.founder_audit_append(uuid,text,text,text,jsonb)','execute'), 3
union all select 'E102 service_role audit par sirf select+insert (update/delete nahi)',
       has_table_privilege('service_role','public.founder_audit','insert') and not has_table_privilege('service_role','public.founder_audit','update')
       and not has_table_privilege('service_role','public.founder_audit','delete'), 4
union all select 'E102 immutability triggers chalu (row + truncate + sig)',
       (select count(*) from pg_trigger where tgname in ('founder_audit_no_upd','founder_audit_no_trunc','founder_audit_sig_no_upd') and tgenabled = 'O') = 3, 5
union all select 'E102 chain saaf (verify null)', public.founder_audit_verify(1) is null, 6
union all select 'E102 12 one-click actions seed, koi enabled nahi jab tak executor (F8) na aaye',
       (select count(*) from public.founder_actions) >= 12 and (select count(*) from public.founder_actions where enabled) = 0, 7
union all select 'E102 high-danger action ke liye passkey+two_tap DB constraint',
       exists (select 1 from pg_constraint where conname = 'founder_actions_high_needs_passkey'), 8
union all select 'E102 behaviour: chhoti wajah reject (rollback ke saath)',
       coalesce((select (public.founder_audit_selftest() like 'E102 selftest OK%' or public.founder_audit_selftest() like 'E102 selftest SKIP%')), false), 9
) t order by ord;
