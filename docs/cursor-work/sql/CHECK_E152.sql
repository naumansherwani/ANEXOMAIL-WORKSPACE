
-- CHECK E152 - reads only (the selftests roll back). 6 checks.
select item, ok from (
select 'E152 the policy word exists, is checked, and defaults to one factor' as item,
       exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'founder_signin_policy' and column_name = 'second_step' and column_default like '%off%')
       and exists (select 1 from pg_constraint where conname = 'founder_signin_policy_second_step_words' and conrelid = 'public.founder_signin_policy'::regclass) as ok, 1 as ord
union all select 'E152 tickets and hand-offs accept the method passkey; the ledger accepts policy',
       (select pg_get_constraintdef(oid) like '%passkey%' from pg_constraint where conname = 'founder_signin_tickets_method_check' and conrelid = 'public.founder_signin_tickets'::regclass)
       and (select pg_get_constraintdef(oid) like '%passkey%' from pg_constraint where conname = 'founder_signin_handoffs_method_check' and conrelid = 'public.founder_signin_handoffs'::regclass)
       and (select pg_get_constraintdef(oid) like '%policy%' from pg_constraint where conname = 'founder_signin_events_kind_check' and conrelid = 'public.founder_signin_events'::regclass), 2
union all select 'E152 every change of the word is chained (audit trigger) and a passkey ticket must carry the passkey',
       exists (select 1 from pg_trigger where tgname = 'founder_signin_policy_audit' and tgrelid = 'public.founder_signin_policy'::regclass and not tgisinternal)
       and exists (select 1 from pg_constraint where conname = 'founder_signin_passkey_needs_passkey' and conrelid = 'public.founder_signin_tickets'::regclass), 3
union all select 'E152 the doors stay for service_role only',
       has_function_privilege('service_role', 'public.founder_signin_open(uuid,text,text,text,text,boolean)', 'execute')
       and not has_function_privilege('anon', 'public.founder_signin_open(uuid,text,text,text,text,boolean)', 'execute')
       and not has_function_privilege('authenticated', 'public.founder_signin_selftest152()', 'execute'), 4
union all select 'E152 selftest (one factor, passkey alone, magic never alone, word chained): ' || coalesce(public.founder_signin_selftest152(), 'null'),
       coalesce(public.founder_signin_selftest152(), '') ~ '^E152 selftest (PASS|SKIP)', 5
union all select 'E151 selftests still pass on the new rules: ' || coalesce(public.founder_signin_selftest(), 'null'),
       coalesce(public.founder_signin_selftest(), '') like 'E151 selftest PASS%' and coalesce(public.founder_signin_selftest2(), '') like 'E151 selftest2 PASS%', 6
) t order by ord;
