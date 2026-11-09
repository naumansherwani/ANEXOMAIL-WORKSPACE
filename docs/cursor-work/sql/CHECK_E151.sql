
-- CHECK E151 - reads only (both selftests roll back). 6 checks.
select item, ok from (
select 'E151 the seven tables exist with RLS on' as item,
       (select count(*) = 7 from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public'
         and c.relname in ('founder_signin_policy','founder_signin_tickets','founder_signin_factors','founder_magic_links','founder_signin_events','founder_signin_nets','founder_signin_handoffs')
         and c.relrowsecurity) as ok, 1 as ord
union all select 'E151 the doors are open to service_role only',
       has_function_privilege('service_role', 'public.founder_signin_open(uuid,text,text,text,text,boolean)', 'execute')
       and has_function_privilege('service_role', 'public.founder_signin_release_v2(text,text)', 'execute')
       and not has_function_privilege('anon', 'public.founder_signin_open(uuid,text,text,text,text,boolean)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_signin_release_v2(text,text)', 'execute'), 2
union all select 'E151 the policy has exactly one row and magic_needs_second is TRUE',
       (select count(*) = 1 and bool_and(magic_needs_second) from public.founder_signin_policy), 3
union all select 'E151 behaviour selftest 1 (open, factor, release once, magic never alone, single-use link, frozen cores, lockout, chain)',
       coalesce((select public.founder_signin_selftest() like 'E151 selftest PASS%' or public.founder_signin_selftest() like 'E151 selftest SKIP%'), false), 4
union all select 'E151 behaviour selftest 2 (shapes, hand-off, new network, risk, label, recovery path, denial, tick, chain)',
       coalesce((select public.founder_signin_selftest2() like 'E151 selftest2 PASS%' or public.founder_signin_selftest2() like 'E151 selftest2 SKIP%'), false), 5
union all select 'E151 the hash chain verifies',
       coalesce((select (public.founder_signin_verify(100000) ->> 'ok')::boolean), false), 6
) t order by ord;
