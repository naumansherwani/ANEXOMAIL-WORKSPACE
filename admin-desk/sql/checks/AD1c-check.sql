-- AD1c CHECK (read-only): ok must be true. Run through ad-sql-run.sh after AD1c.sql.
SELECT 'no AD9 helper is executable by PUBLIC (or AD9 is not in the database yet)' AS rule, to_regprocedure('desk.fadm_runbook_clean(text)') IS NULL OR NOT has_function_privilege('public', to_regprocedure('desk.fadm_runbook_clean(text)'), 'execute') AS ok;
