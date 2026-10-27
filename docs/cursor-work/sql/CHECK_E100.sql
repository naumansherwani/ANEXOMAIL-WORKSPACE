
-- CHECK E100 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E100 plan_catalog 6 plan' as item, (select count(*) from public.plan_catalog) = 6 as ok, 1 as n
union all select 'E100 plan_interop 180 cell (6x6x5)', (select count(*) from public.plan_interop) >= 180, 2
union all select 'E100 audit khali (contact khula, gate sahi, ladder seedhi, chain theek)', not exists (select 1 from public.plan_interop_audit()), 3
union all select 'E100 basic -> business_pro mail allowed', public.plan_interop_allowed('basic','business_pro','mail'), 4
union all select 'E100 business_pro -> basic booking allowed', public.plan_interop_allowed('business_pro','basic','booking'), 5
union all select 'E100 Pro ka 4th booking link refuse (apni limit)',
       not coalesce((public.plan_interop_decide(null,'pro','basic','booking','{"booking_links":4}'::jsonb,false)->>'allowed')::boolean, true), 6
union all select 'E100 Pro ka 3rd booking link ok',
       coalesce((public.plan_interop_decide(null,'pro','basic','booking','{"booking_links":3}'::jsonb,false)->>'allowed')::boolean, false), 7
union all select 'E100 Pro 21st user refuse, 20th ok',
       not coalesce((public.plan_interop_decide(null,'pro','pro','share_thread','{"users":21}'::jsonb,false)->>'allowed')::boolean, true)
       and coalesce((public.plan_interop_decide(null,'pro','pro','share_thread','{"users":20}'::jsonb,false)->>'allowed')::boolean, false), 8
union all select 'E100 ANEXOChat badi file: Business 3GB refuse, Enterprise 7GB ok',
       not coalesce((public.plan_interop_decide(null,'business','basic','chat','{"chat_file_gb":3}'::jsonb,false)->>'allowed')::boolean, true)
       and coalesce((public.plan_interop_decide(null,'enterprise','pro','chat','{"chat_file_gb":7}'::jsonb,false)->>'allowed')::boolean, false), 14
union all select 'E100 recipient ka plan jawab mein nahi',
       (public.plan_interop_decide(null,'basic','business_pro','invite','{}'::jsonb,false))::text not ilike '%business_pro%', 9
union all select 'E100 log chain verify ok', coalesce((public.plan_interop_log_verify()->>'ok')::boolean, false), 10
union all select 'E100 log append-only trigger laga hai',
       (select count(*) from pg_trigger where tgrelid='public.plan_interop_log'::regclass and not tgisinternal) = 2, 11
union all select 'E100 RLS on 5 table + anon band',
       (select count(*) from pg_class where oid in ('public.plan_catalog'::regclass,'public.plan_interop'::regclass,'public.plan_interop_gate_map'::regclass,'public.plan_interop_keys'::regclass,'public.plan_interop_log'::regclass) and relrowsecurity) = 5
       and not has_table_privilege('anon','public.plan_interop_keys','select') and not has_table_privilege('authenticated','public.plan_interop_log','select'), 12
union all select 'E100 decide/log_write anon se band',
       not has_function_privilege('anon','public.plan_interop_decide(uuid,text,text,text,jsonb,boolean)','execute')
       and not has_function_privilege('authenticated','public.plan_interop_log_write(uuid,text,text,text,boolean,text,integer,integer,text)','execute'), 13
) t order by n;
