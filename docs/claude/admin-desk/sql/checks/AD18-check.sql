-- AD18 CHECK (phase 1m-9 B9c Plan catalogue + live plan updates): every row must be true
SELECT 'the release trigger exists on the version table and the notify function is SECURITY DEFINER with a fixed search_path' AS rule,
  EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = 'desk.fadm_pkg_version'::regclass AND tgname = 'fadm_pkg_release_notify' AND NOT tgisinternal)
  AND (SELECT count(*) = 4 AND bool_and(prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_pkg_fingerprint','fadm_pkg_release_notify','fadm_plans_allowed','fadm_plans_digest'))
UNION ALL SELECT 'desk_app may run the digest only; no AD18 function is executable by PUBLIC',
  has_function_privilege('desk_app','desk.fadm_plans_digest(uuid)','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_plans_allowed(uuid)','EXECUTE') AND NOT has_function_privilege('desk_app','desk.fadm_pkg_fingerprint(text,int)','EXECUTE')
  AND NOT EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname IN ('fadm_pkg_fingerprint','fadm_pkg_release_notify','fadm_plans_allowed','fadm_plans_digest') AND has_function_privilege('public', p.oid, 'EXECUTE'))
UNION ALL SELECT 'an unknown person gets NULL from the digest', desk.fadm_plans_digest(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the digest door carries a statement timeout and is commented',
  (SELECT bool_and(proconfig::text LIKE '%statement_timeout=%') FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname IN ('fadm_plans_digest','fadm_pkg_fingerprint'))
  AND obj_description('desk.fadm_plans_digest(uuid)'::regprocedure, 'pg_proc') IS NOT NULL
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
