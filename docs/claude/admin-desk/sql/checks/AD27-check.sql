-- AD27 CHECK (phase 1m-L Ledger card): every row must be true
SELECT 'fadm_ledger_board is SECURITY DEFINER, fixed search_path, 8 s statement and 2 s lock timeout, commented' AS rule,
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_ledger_board' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%' AND p.proconfig::text LIKE '%statement_timeout=8s%' AND p.proconfig::text LIKE '%lock_timeout=2s%' AND obj_description(p.oid, 'pg_proc') IS NOT NULL) AS ok
UNION ALL SELECT 'the window helper is SECURITY DEFINER with fixed search_path and a 6 s limit',
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_ledger_window_ok' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%' AND p.proconfig::text LIKE '%statement_timeout=6s%')
UNION ALL SELECT 'desk_app may run the door, PUBLIC may not, desk_app cannot run the helper and cannot write the ledger',
  has_function_privilege('desk_app', 'desk.fadm_ledger_board(uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_ledger_board(uuid)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_ledger_window_ok(integer)', 'EXECUTE') AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger', 'UPDATE') AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger', 'DELETE')
UNION ALL SELECT 'the window check of the real ledger passes', desk.fadm_ledger_window_ok(2000)
UNION ALL SELECT 'the whole chain still verifies', desk.fadm_ledger_verify()
UNION ALL SELECT 'FACT (not pass/fail): ' || (SELECT count(*) FROM desk.fadm_ledger) || ' ledger lines, newest sequence ' || COALESCE((SELECT max(seq) FROM desk.fadm_ledger)::text, 'none'), true;
