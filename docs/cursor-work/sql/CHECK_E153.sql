
-- CHECK E153 - reads only (the selftest rolls back). 3 checks.
select item, ok from (
select 'E153 the password-fail door exists and is for service_role only' as item,
       to_regprocedure('public.founder_signin_password_fail(text)') is not null
       and has_function_privilege('service_role', 'public.founder_signin_password_fail(text)', 'execute')
       and not has_function_privilege('anon', 'public.founder_signin_password_fail(text)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_signin_password_fail(text)', 'execute') as ok, 1 as ord
union all select 'E153 selftest (5 wrong passwords lock the network only, founder never locked by a stranger, nothing identifying stored): ' || public.founder_signin_selftest153(),
       public.founder_signin_selftest153() ~ '^E153 selftest (PASS|SKIP)', 2
union all select 'E153 the earlier selftests (E151, E152) still pass',
       public.founder_signin_selftest() like 'E151 selftest PASS%' and public.founder_signin_selftest152() ~ '^E152 selftest (PASS|SKIP)', 3
) t order by ord;
