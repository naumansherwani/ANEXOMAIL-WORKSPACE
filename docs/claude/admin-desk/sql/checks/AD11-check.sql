-- AD11 CHECK (phase 1m-1 B1 + B2, advanced): every row must be true
SELECT 'the sample table has forced RLS, no right for desk_app, and three triggers (chain, frozen, frozen-truncate)' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_queue_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_queue_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_queue_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_queue_sample'::regclass AND NOT tgisinternal) = 3
UNION ALL SELECT 'one row per queue per minute (unique) and a BRIN index on the bucket',
  EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_queue_sample'::regclass AND contype = 'u') AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_queue_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the doors are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 5 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_queue_pressure','fadm_sla_risk','fadm_queue_can','fadm_queue_sample_take','fadm_queue_sample_chain_verify'))
UNION ALL SELECT 'desk_app may run the two doors and the verify, never the sampler',
  has_function_privilege('desk_app','desk.fadm_queue_pressure(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_sla_risk(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_queue_sample_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_queue_sample_take()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_queue_can(uuid,text)','EXECUTE')
UNION ALL SELECT 'no AD11 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_queue_pressure','fadm_sla_risk','fadm_queue_can','fadm_queue_sample_take','fadm_queue_sample_chain_verify','fadm_queue_level','fadm_queue_sample_chain','fadm_queue_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from both doors', desk.fadm_queue_pressure(gen_random_uuid()) IS NULL AND desk.fadm_sla_risk(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the team signal rule holds at its edges', desk.fadm_queue_level(0,0,NULL,0,0) = 'calm' AND desk.fadm_queue_level(5,0,0,0,0) = 'busy' AND desk.fadm_queue_level(1,1,0,0,0) = 'strained' AND desk.fadm_queue_level(1,3,0,0,0) = 'overloaded'
UNION ALL SELECT 'the sample series chain verifies', desk.fadm_queue_sample_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
