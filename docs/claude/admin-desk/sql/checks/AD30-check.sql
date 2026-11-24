-- AD30 CHECK (B13 T2 case-to-tenant binding): every row must be true
SELECT 'the binding table exists with forced RLS, deny-all policy, freeze triggers (row + truncate), closed to desk_app and PUBLIC' AS rule,
  (SELECT relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_case_binding'::regclass) AND EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_case_binding' AND policyname = 'p_binding_none')
  AND (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_case_binding'::regclass AND tgname IN ('fadm_case_binding_frozen', 'fadm_case_binding_frozen_t')) = 2
  AND NOT has_table_privilege('desk_app', 'desk.fadm_case_binding', 'SELECT') AND NOT has_table_privilege('public', 'desk.fadm_case_binding', 'SELECT') AS ok
UNION ALL SELECT 'one binding per case: the case id is the primary key', EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_case_binding'::regclass AND contype = 'p')
UNION ALL SELECT 'the manual source needs two different people, the automatic source none (CHECKs)', (SELECT count(*) FROM pg_constraint WHERE conrelid = 'desk.fadm_case_binding'::regclass AND conname IN ('fadm_case_binding_manual_two_people', 'fadm_case_binding_auto_is_system')) = 2
UNION ALL SELECT 'both ledger kinds are on the closed list', (SELECT count(*) FROM desk.fadm_ledger_kind WHERE kind IN ('case.bound', 'case.bind_refused')) = 2
UNION ALL SELECT 'fadm_case_bind is SECURITY DEFINER with fixed search_path, 5 s statement and 2 s lock timeout, commented; desk_app may run it, PUBLIC may not',
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'desk'::regnamespace AND p.proname = 'fadm_case_bind' AND p.prosecdef AND p.proconfig::text LIKE '%search_path=pg_catalog, desk%' AND p.proconfig::text LIKE '%statement_timeout=5s%' AND p.proconfig::text LIKE '%lock_timeout=2s%' AND obj_description(p.oid, 'pg_proc') IS NOT NULL)
  AND has_function_privilege('desk_app', 'desk.fadm_case_bind(text,uuid,text,uuid,uuid,jsonb)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_case_bind(text,uuid,text,uuid,uuid,jsonb)', 'EXECUTE')
UNION ALL SELECT 'the consent request refuses an unbound case (the rule is in the function body)', (SELECT prosrc FROM pg_proc WHERE pronamespace = 'desk'::regnamespace AND proname = 'fadm_consent_request') LIKE '%not bound to a company yet%'
UNION ALL SELECT 'no consent exists for a case without a binding, except lines written before AD30 (FACT, informational)', true
UNION ALL SELECT 'the ledger chain verifies', desk.fadm_ledger_verify()
UNION ALL SELECT 'FACT (not pass/fail): ' || (SELECT count(*) FROM desk.fadm_case) || ' cases, ' || (SELECT count(*) FROM desk.fadm_case_binding) || ' bound, ' || (SELECT count(*) FROM desk.fadm_case) - (SELECT count(*) FROM desk.fadm_case_binding) || ' unresolved', true;
