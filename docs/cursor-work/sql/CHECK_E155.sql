
-- CHECK E155 - reads only (the selftest rolls back). 5 checks.
select item, ok from (
select 'E155 posture: tables closed to direct writes + RLS on, ledger append-only triggers, doors service_role only + definer + pinned search_path, helpers closed' as item,
       (p ->> 'tables_rls_on')::boolean and (p ->> 'tables_closed_to_direct_writes')::boolean and (p ->> 'ledger_append_only_triggers')::boolean and (p ->> 'doors_service_role_only')::boolean
       and (p ->> 'doors_definer')::boolean and (p ->> 'doors_search_path_pinned')::boolean and (p ->> 'internal_helpers_closed')::boolean as ok, 1 as ord
  from (select public.founder_session_posture155() as p) x
union all select 'E155 the session ledger chain verifies (' || (public.founder_session_ledger_verify(100000) ->> 'checked') || ' rows)', (public.founder_session_ledger_verify(100000) ->> 'ok')::boolean, 2
union all select 'E155 selftest: ' || public.founder_session_selftest155(), public.founder_session_selftest155() ~ '^E155 selftest (PASS|SKIP)', 3
union all select 'E155 the earlier selftests (E151, E152, E153, E154) still pass', public.founder_signin_selftest() like 'E151 selftest PASS%' and public.founder_signin_selftest152() ~ '^E152 selftest (PASS|SKIP)'
       and public.founder_signin_selftest153() ~ '^E153 selftest (PASS|SKIP)' and public.founder_passkey_selftest154() ~ '^E154 selftest (PASS|SKIP)', 4
union all select 'E155 a malformed session is refused and a non-founder cannot register',
       public.founder_session_register(null, 'x', 'x', 'x', 'password', 'quic', 'k', 'none', null, 'chrome', 'chrome', null) ->> 'ok' = 'false', 5
) t order by ord;
