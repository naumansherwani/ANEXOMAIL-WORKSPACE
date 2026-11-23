-- AD19 CHECK (phase 1m-9 B9c step Y5, Premium and Max seat promises in the over-limit count): every row must be true
SELECT 'the six package keys exist in one immutable function, SECURITY DEFINER, fixed search_path, not executable by PUBLIC or desk_app' AS rule,
  desk.fadm_pkg_keys() = ARRAY['basic','pro','business','business_pro','business_premium','business_max']::text[]
  AND (SELECT prosecdef AND provolatile = 'i' AND proconfig::text LIKE '%search_path=pg_catalog, desk%' FROM pg_proc WHERE oid = 'desk.fadm_pkg_keys()'::regprocedure)
  AND NOT has_function_privilege('desk_app', 'desk.fadm_pkg_keys()', 'EXECUTE')
UNION ALL SELECT 'business_premium and business_max each have a published version with a whole-number seat promise',
  (SELECT count(*) = 2 FROM unnest(ARRAY['business_premium','business_max']) k, LATERAL desk.fadm_pkg_current(k) c WHERE c.limits->>'seats' ~ '^[0-9]{1,6}$')
UNION ALL SELECT 'version 1 of Premium is 7000 seats and version 1 of Max is 125000 seats (his finalised values), never edited',
  (SELECT (limits->>'seats')::int FROM desk.fadm_pkg_version WHERE pkg_id = 'business_premium' AND version = 1) = 7000
  AND (SELECT (limits->>'seats')::int FROM desk.fadm_pkg_version WHERE pkg_id = 'business_max' AND version = 1) = 125000
UNION ALL SELECT 'the customers door reads the six keys from the one list, keeps its statement timeout and stays executable by desk_app only as the door',
  (SELECT prosrc LIKE '%fadm_pkg_keys()%' AND proconfig::text LIKE '%statement_timeout=%' AND prosecdef FROM pg_proc WHERE oid = 'desk.fadm_customers_begin(uuid)'::regprocedure)
  AND has_function_privilege('desk_app', 'desk.fadm_customers_begin(uuid)', 'EXECUTE')
  AND NOT has_function_privilege('public', 'desk.fadm_customers_begin(uuid)', 'EXECUTE')
UNION ALL SELECT 'an unknown person gets NULL from the customers door', desk.fadm_customers_begin(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
