-- AD11 CHECK (phase 1m B1 + B2): every row must be true
SELECT 'the queue pressure and SLA at risk doors exist and run as SECURITY DEFINER with a fixed search_path' AS rule,
  (SELECT count(*) = 2 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_queue_pressure','fadm_sla_risk'))
UNION ALL SELECT 'desk_app may run the two doors and has no right on the case tables',
  has_function_privilege('desk_app','desk.fadm_queue_pressure(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_sla_risk(uuid)','EXECUTE') AND NOT has_table_privilege('desk_app','desk.fadm_case','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_case_event','SELECT')
UNION ALL SELECT 'PUBLIC cannot run either door',
  NOT has_function_privilege('public','desk.fadm_queue_pressure(uuid)','EXECUTE') AND NOT has_function_privilege('public','desk.fadm_sla_risk(uuid)','EXECUTE')
UNION ALL SELECT 'an unknown person gets NULL from both doors',
  desk.fadm_queue_pressure(gen_random_uuid()) IS NULL AND desk.fadm_sla_risk(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
