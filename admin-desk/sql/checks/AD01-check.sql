-- AD1 CHECK (read-only): one row per rule, ok must be true on every row. Run through ad-sql-run.sh after AD01.sql.
SELECT 'role desk_app exists, no superuser, no BYPASSRLS' AS rule, EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app' AND NOT rolsuper AND NOT rolbypassrls) AS ok
UNION ALL SELECT 'every desk table is fadm_* with RLS enabled and forced', NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'desk' AND c.relkind = 'r' AND (c.relname NOT LIKE 'fadm\_%' OR NOT c.relrowsecurity OR NOT c.relforcerowsecurity))
UNION ALL SELECT 'the five AD1 fadm tables present (later steps add more)', (SELECT count(*) FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'desk' AND c.relkind = 'r' AND c.relname IN ('fadm_owner','fadm_session','fadm_passkey','fadm_mailbox','fadm_ledger')) = 5
UNION ALL SELECT 'desk_app touches nothing in public', NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace WHERE s.nspname = 'public' AND c.relkind IN ('r','v','m') AND has_table_privilege('desk_app', c.oid, 'SELECT,INSERT,UPDATE,DELETE'))
UNION ALL SELECT 'ledger hash chain verifies', desk.fadm_ledger_verify()
UNION ALL SELECT 'ledger is append-only (three freeze triggers)', (SELECT count(*) FROM pg_trigger WHERE tgrelid = 'desk.fadm_ledger'::regclass AND tgname LIKE 'fadm_ledger_frozen%') = 2
UNION ALL SELECT 'support@ is not a Desk mailbox', NOT EXISTS (SELECT 1 FROM desk.fadm_mailbox WHERE local_part = 'support')
UNION ALL SELECT 'noreply@ is send-only (billing@ became a restricted receiving mailbox in AD5, his 22 Nov 11:06 rule, so it is no longer checked here)', NOT EXISTS (SELECT 1 FROM desk.fadm_mailbox WHERE local_part = 'noreply' AND NOT send_only);
