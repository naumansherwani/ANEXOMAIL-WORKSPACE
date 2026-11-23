-- AD16 CHECK (phase 1m-6 B10 Reports): every row must be true
SELECT 'fadm_reports is SECURITY DEFINER, fixed search_path, 8 s statement and 2 s lock timeout, commented' AS rule,
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_reports' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%' AND p.proconfig::text LIKE '%statement_timeout=8s%' AND p.proconfig::text LIKE '%lock_timeout=2s%' AND obj_description(p.oid, 'pg_proc') IS NOT NULL)
UNION ALL SELECT 'desk_app may run it, PUBLIC may not, desk_app still has no right on the case tables',
  has_function_privilege('desk_app', 'desk.fadm_reports(uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_reports(uuid)', 'EXECUTE') AND NOT has_table_privilege('desk_app', 'desk.fadm_case', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_case_event', 'SELECT')
UNION ALL SELECT 'the two read indexes exist', EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_case_created') AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_case_event_kind_at')
UNION ALL SELECT 'an unknown person gets NULL', desk.fadm_reports(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the case events are still frozen against update and delete', (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_case_event'::regclass AND NOT tgisinternal AND tgname LIKE 'fadm_case_event_frozen%') = 2
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
