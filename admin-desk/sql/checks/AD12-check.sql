-- AD12 CHECK (phase 1m-2 B3 Security health): every row must be true
SELECT 'the score series has forced RLS, no right for desk_app, three triggers (chain, frozen, frozen-truncate) and a BRIN index' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_security_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_security_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_security_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_security_sample'::regclass AND NOT tgisinternal) = 3
  AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_security_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the door and the helpers are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 4 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_security_health','fadm_security_counts','fadm_security_sample_take','fadm_security_sample_chain_verify'))
UNION ALL SELECT 'desk_app may run the door and the verify, never the sampler or the counts',
  has_function_privilege('desk_app','desk.fadm_security_health(uuid)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_security_sample_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_security_sample_take()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_security_counts()','EXECUTE')
UNION ALL SELECT 'no AD12 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_security_health','fadm_security_counts','fadm_security_score','fadm_security_sample_take','fadm_security_sample_chain_verify','fadm_security_sample_chain','fadm_security_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from the door', desk.fadm_security_health(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the rule has exactly 8 checks with weights summing to 100',
  jsonb_array_length(desk.fadm_security_score('{"staff":1,"with_key":1,"with_two":1,"keys":2,"keys_bound":2,"keys_allowed":2,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb)->'checks') = 8
  AND (SELECT sum((e->>'weight')::int) FROM jsonb_array_elements(desk.fadm_security_score('{"staff":1,"with_key":1,"with_two":1,"keys":2,"keys_bound":2,"keys_allowed":2,"recoveries_open":0,"grants_stale":0,"breakglass_active":0,"alerts_high_open":0}'::jsonb)->'checks') e) = 100
UNION ALL SELECT 'the score series chain verifies', desk.fadm_security_sample_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
