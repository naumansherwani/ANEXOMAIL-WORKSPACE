-- AD6d CHECK (read-only): the registry lists exactly the landing page plans (Basic, Pro, Business, Business Pro); AI packages retired.
SELECT 'the list is exactly the four packages the landing page offers' AS rule, (SELECT array_agg(pkg_id ORDER BY ord) FROM (SELECT pkg_id, row_number() OVER () ord FROM desk.fadm_pkg_list()) t) = ARRAY['basic','pro','business','business_pro'] AS ok
UNION ALL SELECT 'AI packages are retired, not deleted', (SELECT count(*) FROM desk.fadm_pkg_version WHERE pkg_id IN ('ai_pro','ai_business','ai_executive')) >= 3 AND NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_list() WHERE pkg_id LIKE 'ai\_%')
UNION ALL SELECT 'Business Pro attachment is 60 MB', (SELECT (limits->>'attachment_mb')::int = 60 FROM desk.fadm_pkg_current('business_pro'))
UNION ALL SELECT 'ledger hash chain still verifies', desk.fadm_ledger_verify();
