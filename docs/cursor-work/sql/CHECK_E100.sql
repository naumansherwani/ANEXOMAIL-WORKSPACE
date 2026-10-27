
-- CHECK E100 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E100 plan_interop 180 row (6x6x5)' as item, (select count(*) from public.plan_interop) >= 180 as ok, 1 as n
union all select 'E100 koi plan-to-plan contact band nahi', not exists (select 1 from public.plan_interop_audit()), 2
union all select 'E100 basic -> business_pro mail allowed', public.plan_interop_allowed('basic','business_pro','mail'), 3
union all select 'E100 business_pro -> basic booking allowed', public.plan_interop_allowed('business_pro','basic','booking'), 4
union all select 'E100 RLS on + anon band', (select relrowsecurity from pg_class where oid='public.plan_interop'::regclass)
       and not has_table_privilege('anon','public.plan_interop','select'), 5
) t order by n;
