-- AD20 CHECK (phase 1m card B13, BL-46 consent + timer access): every row must be true
SELECT 'the consent table is forced-RLS, has no policy, and neither PUBLIC nor desk_app can touch it' AS rule,
  (SELECT relrowsecurity AND relforcerowsecurity FROM pg_class WHERE oid = 'desk.fadm_consent'::regclass)
  AND NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'fadm_consent')
  AND NOT has_table_privilege('desk_app', 'desk.fadm_consent', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_consent', 'UPDATE')
UNION ALL SELECT 'timers are 60 / 30 / 15 minutes and the window can never exceed them (CHECK present)',
  desk.fadm_consent_minutes('metadata') = 60 AND desk.fadm_consent_minutes('headers') = 30 AND desk.fadm_consent_minutes('content') = 15
  AND EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_consent'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) LIKE '%fadm_consent_minutes%')
UNION ALL SELECT 'one live grant per person + case + scope is enforced by the database (EXCLUDE or the unique-index fallback)',
  EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fadm_consent_no_overlap') OR EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'desk' AND indexname = 'fadm_consent_one_live')
UNION ALL SELECT 'the five doors are SECURITY DEFINER with a fixed search_path, executable by desk_app and not by PUBLIC',
  (SELECT count(*) = 5 FROM pg_proc WHERE oid IN ('desk.fadm_consent_request(uuid,text,text,text)'::regprocedure,'desk.fadm_consent_decide(uuid,text,text,text)'::regprocedure,'desk.fadm_consent_revoke(uuid,text)'::regprocedure,'desk.fadm_consent_open(uuid,uuid)'::regprocedure,'desk.fadm_consent_board(uuid)'::regprocedure) AND prosecdef AND proconfig::text LIKE '%search_path=pg_catalog, desk%')
  AND has_function_privilege('desk_app', 'desk.fadm_consent_open(uuid,uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'desk.fadm_consent_open(uuid,uuid)', 'EXECUTE')
  AND NOT has_function_privilege('desk_app', 'desk.fadm_consent_sweep()', 'EXECUTE')
UNION ALL SELECT 'there is no break-glass and no auto-approval: no function or kind mentions them for consent',
  NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname LIKE 'fadm_consent%' AND (prosrc ILIKE '%breakglass%' OR prosrc ILIKE '%auto_approve%')) AND NOT EXISTS (SELECT 1 FROM desk.fadm_ledger_kind WHERE kind LIKE 'consent.%' AND (kind LIKE '%auto%' OR kind LIKE '%break%'))
UNION ALL SELECT 'all nine B13 ledger kinds are on the closed list', (SELECT count(*) = 9 FROM desk.fadm_ledger_kind WHERE kind IN ('consent.requested','consent.approved','consent.denied','consent.revoked','consent.expired','consent.cancelled','consent.opened','consent.refused','ad20.selftest'))
UNION ALL SELECT 'an unknown person gets NULL from the board', desk.fadm_consent_board(gen_random_uuid()) IS NULL
UNION ALL SELECT 'the main ledger hash chain still verifies', desk.fadm_ledger_verify();
