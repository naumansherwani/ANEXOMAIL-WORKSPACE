-- LEGACY RENAME (25 Nov 2026 05:5x PKT, his server paste: "AD1 selftest: table desk.registry_kind is not fadm_*"). NOT an AD file: ad-auto never runs it by number; desk-sql-install.sh runs it BEFORE ad-auto, and editor/AD34-editor.sql starts with it.
-- SCHEMA-FIRST: read before writing: AD01 (law: every table in schema desk is named fadm_*, with RLS enabled and forced; its selftest and CHECK refuse any other table), AD34 (desk.fadm_registry_kind, was registry_kind), AD35 (desk.fadm_ledger_checkpoint, fadm_ledger_checkpoint_witness, fadm_ledger_merkle_root, fadm_company_identifier, were named without the prefix).
-- ADVANCE-RESEARCH: [1m] B13 T4i (25 Nov 2026): PostgreSQL ALTER TABLE ... RENAME keeps the OID, so rows, indexes, constraints, triggers, row-level-security policies, grants and foreign keys follow the table (nothing is copied, nothing is deleted); a guarded, idempotent DO block with to_regclass checks is the standard zero-downtime way to migrate a name; the selftest proves it on a throw-away table and rolls back.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/legacy-rename-check.sql
-- WHY: an earlier run of AD34/AD35 created five tables WITHOUT the prefix; after the rename inside AD34/AD35 they would stay behind as orphans and fail AD01 for ever. WHAT: renames each old table to its fadm_ name ONLY when the old one exists and the new one does not. IDEMPOTENT: nothing to rename = nothing happens.
CREATE FUNCTION pg_temp.legacy_rename(p_names text[]) RETURNS integer LANGUAGE plpgsql AS $f$
DECLARE nm text; n integer := 0;
BEGIN
  FOREACH nm IN ARRAY p_names LOOP
    IF to_regclass('desk.' || nm) IS NOT NULL AND to_regclass('desk.fadm_' || nm) IS NULL THEN
      EXECUTE format('ALTER TABLE desk.%I RENAME TO %I', nm, 'fadm_' || nm);
      n := n + 1;
    END IF;
  END LOOP;
  RETURN n;
END $f$;
REVOKE ALL ON FUNCTION pg_temp.legacy_rename(text[]) FROM PUBLIC;
DO $m$ DECLARE n integer;
BEGIN
  n := pg_temp.legacy_rename(ARRAY['registry_kind', 'ledger_checkpoint', 'ledger_checkpoint_witness', 'ledger_merkle_root', 'company_identifier']);
  RAISE NOTICE 'LEGACY RENAME: % table(s) renamed', n;
END $m$;
-- SELFTEST (rolls back; success is the exception P0AY4): a throw-away table is renamed, rows follow, a second run renames nothing, and an existing target is never overwritten
DO $t$ DECLARE c integer;
BEGIN
  CREATE TABLE desk.zz_selftest_legacy (id integer PRIMARY KEY, v text); ALTER TABLE desk.zz_selftest_legacy ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.zz_selftest_legacy FORCE ROW LEVEL SECURITY; INSERT INTO desk.zz_selftest_legacy VALUES (1, 'kept');
  IF pg_temp.legacy_rename(ARRAY['zz_selftest_legacy']) <> 1 THEN RAISE EXCEPTION 'legacy rename selftest: first run must rename one table' USING ERRCODE = 'P0AY3'; END IF;
  IF to_regclass('desk.zz_selftest_legacy') IS NOT NULL OR to_regclass('desk.fadm_zz_selftest_legacy') IS NULL THEN RAISE EXCEPTION 'legacy rename selftest: the table did not move' USING ERRCODE = 'P0AY3'; END IF;
  SELECT count(*) INTO c FROM desk.fadm_zz_selftest_legacy WHERE v = 'kept'; IF c <> 1 THEN RAISE EXCEPTION 'legacy rename selftest: the row did not follow the table' USING ERRCODE = 'P0AY3'; END IF;
  IF pg_temp.legacy_rename(ARRAY['zz_selftest_legacy']) <> 0 THEN RAISE EXCEPTION 'legacy rename selftest: second run must rename nothing' USING ERRCODE = 'P0AY3'; END IF;
  CREATE TABLE desk.zz_selftest_legacy (id integer); ALTER TABLE desk.zz_selftest_legacy ENABLE ROW LEVEL SECURITY; ALTER TABLE desk.zz_selftest_legacy FORCE ROW LEVEL SECURITY;
  IF pg_temp.legacy_rename(ARRAY['zz_selftest_legacy']) <> 0 OR to_regclass('desk.zz_selftest_legacy') IS NULL THEN RAISE EXCEPTION 'legacy rename selftest: an existing target must never be overwritten' USING ERRCODE = 'P0AY3'; END IF;
  RAISE EXCEPTION 'legacy rename selftest passed, rolling back' USING ERRCODE = 'P0AY4';
EXCEPTION WHEN SQLSTATE 'P0AY4' THEN RAISE NOTICE 'LEGACY RENAME selftest: ALL RULES PASSED (rows rolled back)';
END $t$;
