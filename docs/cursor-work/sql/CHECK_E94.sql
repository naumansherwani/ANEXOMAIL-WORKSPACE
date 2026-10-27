
-- CHECK E94 — sirf padhta hai. Har row ok = true.
select item, ok from (
select 'E94 plan_promises registry + RLS' as item,
       to_regclass('public.plan_promises') is not null
       and (select relrowsecurity from pg_class where oid = 'public.plan_promises'::regclass) as ok, 1 as n
union all select 'E94 audit/snapshot/ok functions',
       to_regprocedure('public.plan_promise_audit(text)') is not null and to_regprocedure('public.plan_promise_snapshot()') is not null
       and to_regprocedure('public.plan_promise_ok(text)') is not null, 2
union all select 'E94 seeded basic+pro (16 vaade)',
       (select count(*) from public.plan_promises where plan in ('basic','pro')) >= 16, 3
union all select 'E94 BASIC vaade server par poore (koi broken nahi)',
       public.plan_promise_ok('basic'), 4
union all select 'E94 PRO vaade server par poore (koi broken nahi)',
       public.plan_promise_ok('pro'), 5
union all select 'E94 basic: 5 users/15GB/3 mbx/1 domain/1 link/2 devices',
       (select count(*) from public.plan_promise_audit('basic') where status = 'ok') = 7, 6
union all select 'E94 pro: 7 server vaade ok',
       (select count(*) from public.plan_promise_audit('pro') where status = 'ok') = 7, 7
union all select 'E94 business/business_pro abhi todo (jhoot nahi)',
       not exists (select 1 from public.plan_promises where plan in ('business','business_pro') and enforcement = 'server'), 8
) t order by n;
