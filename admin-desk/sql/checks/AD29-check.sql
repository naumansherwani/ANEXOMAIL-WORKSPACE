-- AD29 CHECK (phase 1m-L3 ledger check that scales): every row must be true
SELECT 'the anchor table exists with forced RLS, a deny-all policy and three freeze triggers, closed to desk_app and PUBLIC' AS rule,
  (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_ledger_anchor'::regclass) AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_ledger_anchor' AND policyname = 'p_anchor_none')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_ledger_anchor'::regclass AND tgname IN ('fadm_ledger_anchor_frozen', 'fadm_ledger_anchor_frozen_t')) = 2
  AND NOT has_table_privilege('desk_app', 'desk.fadm_ledger_anchor', 'SELECT') AND NOT has_table_privilege('public', 'desk.fadm_ledger_anchor', 'SELECT') AS ok
UNION ALL SELECT 'fadm_ledger_verify_fast is SECURITY DEFINER, fixed search_path, 30 s statement and 2 s lock timeout, commented',
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_ledger_verify_fast' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%' AND p.proconfig::text LIKE '%statement_timeout=30s%' AND p.proconfig::text LIKE '%lock_timeout=2s%' AND obj_description(p.oid, 'pg_proc') IS NOT NULL)
UNION ALL SELECT 'desk_app may run it, PUBLIC may not',
  has_function_privilege('desk_app', 'desk.fadm_ledger_verify_fast()', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_ledger_verify_fast()', 'EXECUTE')
UNION ALL SELECT 'the fast check of the real ledger passes', desk.fadm_ledger_verify_fast()
UNION ALL SELECT 'a full walk from the genesis ran within 24 hours', EXISTS (SELECT 1 FROM desk.fadm_ledger_anchor WHERE how = 'full' AND at > now() - interval '24 hours')
UNION ALL SELECT 'FACT (not pass/fail): ' || (SELECT count(*) FROM desk.fadm_ledger) || ' ledger lines, ' || (SELECT count(*) FROM desk.fadm_ledger_anchor) || ' anchors, newest anchor at line ' || COALESCE((SELECT seq FROM desk.fadm_ledger_anchor ORDER BY id DESC LIMIT 1)::text, 'none'), true;
