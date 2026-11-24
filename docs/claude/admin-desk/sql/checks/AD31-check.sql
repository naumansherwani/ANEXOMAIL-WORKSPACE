-- AD31 CHECK (B13 T3a sender -> tenant verdict, AWAM DATABASE): every row must be true
SELECT 'cp.resolve_sender exists, SECURITY DEFINER, STABLE, fixed search_path, 5 s statement timeout, commented' AS rule,
  EXISTS (SELECT 1 FROM pg_proc p WHERE p.pronamespace = 'cp'::regnamespace AND p.proname = 'resolve_sender' AND p.prosecdef AND p.provolatile = 's' AND p.proconfig::text LIKE '%search_path=pg_catalog, pg_temp%' AND p.proconfig::text LIKE '%statement_timeout=5s%' AND obj_description(p.oid, 'pg_proc') IS NOT NULL) AS ok
UNION ALL SELECT 'cp_lookup may run it, PUBLIC may not', has_function_privilege('cp_lookup', 'cp.resolve_sender(text,text,boolean,timestamptz)', 'EXECUTE') AND NOT has_function_privilege('public', 'cp.resolve_sender(text,text,boolean,timestamptz)', 'EXECUTE')
UNION ALL SELECT 'cp_lookup can NOT decide or revoke a consent (earlier phases untouched)', NOT has_function_privilege('cp_lookup', 'cp.consent_decide(uuid,uuid,text,text)', 'EXECUTE') OR to_regprocedure('cp.consent_decide(uuid,uuid,text,text)') IS NULL
UNION ALL SELECT 'a shared provider never resolves', cp.resolve_sender('gmail.com', 'anyone', true) ->> 'verdict' = 'shared'
UNION ALL SELECT 'an unaligned sender is never resolved', cp.resolve_sender('example.com', 'anyone', false) ->> 'verdict' = 'unaligned'
UNION ALL SELECT 'odd input answers unknown', cp.resolve_sender('Bad Domain', 'x', true) ->> 'verdict' = 'unknown'
UNION ALL SELECT 'no real verified domain resolves for a stranger address (fail closed)', NOT EXISTS (SELECT 1 FROM cp.domain_ownership d WHERE d.valid_to IS NULL AND cp.resolve_sender(d.domain, 'ad31-no-such-person', true) ->> 'verdict' = 'resolved')
UNION ALL SELECT 'FACT (not pass/fail): ' || (SELECT count(*) FROM cp.domain_ownership WHERE valid_to IS NULL) || ' open domain periods, ' || (SELECT count(*) FROM public.org_members WHERE status = 'active') || ' active members', true;
