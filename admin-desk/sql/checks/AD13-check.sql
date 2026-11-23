-- AD13 CHECK (phase 1m-3 B8 Staff online and shifts): every row must be true
SELECT 'the staff series has forced RLS, no right for desk_app, three triggers (chain, frozen, frozen-truncate) and a BRIN index' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_staff_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_staff_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_staff_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_staff_sample'::regclass AND NOT tgisinternal) = 3
  AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_staff_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the door and the helpers are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 4 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_staff_board','fadm_staff_counts','fadm_staff_sample_take','fadm_staff_sample_chain_verify'))
UNION ALL SELECT 'desk_app may run the door and the verify, never the sampler or the counts',
  has_function_privilege('desk_app','desk.fadm_staff_board(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_staff_sample_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_staff_sample_take()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_staff_counts()','EXECUTE')
UNION ALL SELECT 'no AD13 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_staff_board','fadm_staff_counts','fadm_staff_sample_take','fadm_staff_sample_chain_verify','fadm_staff_sample_chain','fadm_staff_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from the door', desk.fadm_staff_board(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the staff series chain verifies', desk.fadm_staff_sample_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
