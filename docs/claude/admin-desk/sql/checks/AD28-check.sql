-- AD28 CHECK (phase 1m-L2 ledger flood guard): every row must be true
SELECT 'the state table exists with forced RLS and a deny-all policy, no right for desk_app or PUBLIC' AS rule,
  (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_ledger_flood'::regclass) AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_ledger_flood' AND policyname = 'p_flood_none')
  AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger_flood', 'SELECT') AND NOT has_table_privilege('public', 'desk.fadm_ledger_flood', 'SELECT') AS ok
UNION ALL SELECT 'the guard is SECURITY DEFINER with fixed search_path, PUBLIC and desk_app cannot run it',
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_ledger_flood_guard' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%')
  AND NOT has_function_privilege('public', 'desk.fadm_ledger_flood_guard()', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_ledger_flood_guard()', 'EXECUTE')
UNION ALL SELECT 'the trigger fires after the kind check and before the chain (00kind < 01flood < chain)',
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'desk.fadm_ledger'::regclass AND tgname = 'fadm_ledger_01flood' AND tgenabled = 'O')
UNION ALL SELECT 'the whole ledger chain still verifies', desk.fadm_ledger_verify()
UNION ALL SELECT 'FACT (not pass/fail): ' || (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'dbsc.refused') || ' dbsc.refused lines in the ledger, ' || (SELECT count(*) FROM desk.fadm_ledger_flood) || ' repeat states held', true;
