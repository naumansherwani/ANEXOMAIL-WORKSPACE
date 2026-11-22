-- AD6b CHECK (read-only): one row per rule, ok must be true on every row. Run through ad-auto.sh before AD6b.sql (all true = skipped).
SELECT 'all seven published packages have a current version' AS rule, (SELECT count(DISTINCT pkg_id) FROM desk.fadm_pkg_version WHERE pkg_id IN ('basic','pro','business','business_pro','ai_pro','ai_business','ai_executive')) = 7 AS ok
UNION ALL SELECT 'every version carries features and the 3 day grace', NOT EXISTS (SELECT 1 FROM desk.fadm_pkg_version WHERE pkg_id IN ('basic','pro','business','business_pro','ai_pro','ai_business','ai_executive') AND (jsonb_array_length(features) = 0 OR grace_days <> 3))
UNION ALL SELECT 'Business Pro seat limit is 570 and Basic is 5', (SELECT (limits->>'seats')::int FROM desk.fadm_pkg_current('business_pro')) = 570 AND (SELECT (limits->>'seats')::int FROM desk.fadm_pkg_current('basic')) = 5
UNION ALL SELECT 'AI Executive has no seat cap', (SELECT limits->'seats' = 'null'::jsonb FROM desk.fadm_pkg_current('ai_executive'))
UNION ALL SELECT 'ledger hash chain still verifies', desk.fadm_ledger_verify();
