-- AD14 CHECK (phase 1m-4 B9 Customers and Plans): every row must be true
SELECT 'the census series has forced RLS, no right for desk_app, three triggers (chain, frozen, frozen-truncate) and a BRIN index' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_census_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_census_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_census_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_census_sample'::regclass AND NOT tgisinternal) = 3
  AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_census_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the doors and helpers are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 4 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_census_allowed','fadm_customers_begin','fadm_census_record','fadm_census_chain_verify'))
UNION ALL SELECT 'desk_app may run the two doors and the verify, never the right check',
  has_function_privilege('desk_app','desk.fadm_customers_begin(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_census_record(uuid,jsonb)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_census_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_census_allowed(uuid)','EXECUTE')
UNION ALL SELECT 'no AD14 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_census_allowed','fadm_customers_begin','fadm_census_record','fadm_census_chain_verify','fadm_census_sample_chain','fadm_census_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from both doors', desk.fadm_customers_begin(gen_random_uuid()) IS NULL AND desk.fadm_census_record(gen_random_uuid(), '{}'::jsonb) IS NULL
UNION ALL SELECT 'the census series chain verifies', desk.fadm_census_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
