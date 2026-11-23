-- AD17 CHECK (phase 1m-7 B6b Own-domain mail posture): every row must be true
SELECT 'the mail posture series has forced RLS, no right for desk_app, three triggers (chain, frozen, frozen-truncate) and a BRIN index' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_mailposture_sample'::regclass) AND NOT has_table_privilege('desk_app','desk.fadm_mailposture_sample','SELECT') AND NOT has_table_privilege('desk_app','desk.fadm_mailposture_sample','INSERT')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_mailposture_sample'::regclass AND NOT tgisinternal) = 3
  AND EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_mailposture_sample_brin' AND indexdef ILIKE '%brin%')
UNION ALL SELECT 'the door and helpers are SECURITY DEFINER with a fixed search_path',
  (SELECT count(*) = 3 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_mailposture_allowed','fadm_mailposture_record','fadm_mailposture_chain_verify'))
UNION ALL SELECT 'desk_app may run the door and the verify, never the right check',
  has_function_privilege('desk_app','desk.fadm_mailposture_record(uuid,jsonb)','EXECUTE') AND has_function_privilege('desk_app','desk.fadm_mailposture_chain_verify()','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_mailposture_allowed(uuid)','EXECUTE')
UNION ALL SELECT 'no AD17 function is executable by PUBLIC',
  NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_mailposture_allowed','fadm_mailposture_record','fadm_mailposture_chain_verify','fadm_mailposture_sample_chain','fadm_mailposture_sample_frozen') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from the door', desk.fadm_mailposture_record(gen_random_uuid(), '{}'::jsonb) IS NULL
UNION ALL SELECT 'the mail posture series chain verifies', desk.fadm_mailposture_chain_verify()
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify()
UNION ALL SELECT 'the door carries statement and lock timeouts, the series has a hash length CHECK, and table and door are commented',
  (SELECT count(*) = 2 AND bool_and(proconfig::text LIKE '%statement_timeout=%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_mailposture_record','fadm_mailposture_chain_verify'))
  AND EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_mailposture_sample'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%octet_length(hash) = 32%')
  AND obj_description('desk.fadm_mailposture_sample'::regclass, 'pg_class') IS NOT NULL;
