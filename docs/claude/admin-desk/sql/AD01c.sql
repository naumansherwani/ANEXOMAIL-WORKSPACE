-- ==============================================================================================================================
-- AD1c (ADMIN DESK SQL, repair, 23 Nov 2026 PKT): HOTFIX for AD9 on a database where AD9 already ran. Found by his server: ad-auto re-ran AD2 because the AD2 and AD3 CHECK rule
-- "no PUBLIC execute on Desk functions" had turned false: AD9's helper fadm_runbook_clean(text) was executable by PUBLIC. This file takes that right away.
-- It is named AD1c ONLY so that ad-auto (number order, sort -V) runs it BEFORE AD2; on a fresh database the function does not exist yet and this file does nothing (AD9 itself now revokes it).
-- BUILT ON (SCHEMA-FIRST LAW): AD2 CHECK rule 'no PUBLIC execute on Desk functions', AD9 (fadm_runbook_clean). Idempotent, ONE transaction, no superuser, Desk objects only.
-- ==============================================================================================================================
BEGIN;
DO $$ BEGIN
  IF to_regprocedure('desk.fadm_runbook_clean(text)') IS NOT NULL THEN REVOKE ALL ON FUNCTION desk.fadm_runbook_clean(text) FROM PUBLIC; END IF;
END $$;
COMMIT;
