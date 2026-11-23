-- AD15 CHECK (phase 1m-5 B6 Deliverability): every row must be true
SELECT 'the deliverability series has forced RLS, no right for desk_app, three triggers (chain, frozen, frozen-truncate) and a BRIN index' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_deliv_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_deliv_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_deliv_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_deliv_sample'::regclass AND NOT tgisinternal) = 3
  AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_deliv_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the doors and helpers are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 4 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_deliv_allowed','fadm_deliv_begin','fadm_deliv_record','fadm_deliv_chain_verify'))
UNION ALL SELECT 'desk_app may run the two doors and the verify, never the right check',
  has_function_privilege('desk_app','desk.fadm_deliv_begin(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_deliv_record(uuid,jsonb)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_deliv_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_deliv_allowed(uuid)','EXECUTE')
UNION ALL SELECT 'no AD15 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_deliv_allowed','fadm_deliv_begin','fadm_deliv_record','fadm_deliv_chain_verify','fadm_deliv_sample_chain','fadm_deliv_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from both doors', desk.fadm_deliv_begin(gen_random_uuid()) IS NULL AND desk.fadm_deliv_record(gen_random_uuid(), '{}'::jsonb) IS NULL
UNION ALL SELECT 'the deliverability series chain verifies', desk.fadm_deliv_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
