-- AD6c CHECK (read-only): every published package carries the 48 hour trial (trial_days 2) in its current version, grace stays 3.
SELECT 'all seven packages: current version has trial_days 2 and grace 3' AS rule, (SELECT count(*) FROM unnest(ARRAY['basic','pro','business','business_pro','ai_pro','ai_business','ai_executive']) p(id) WHERE EXISTS (SELECT 1 FROM desk.fadm_pkg_current(p.id) c WHERE c.trial_days = 2 AND c.grace_days = 3)) = 7 AS ok
UNION ALL SELECT 'older versions are kept (append-only history)', (SELECT count(*) FROM desk.fadm_pkg_version WHERE version = 1) >= 7
UNION ALL SELECT 'ledger hash chain still verifies', desk.fadm_ledger_verify();
