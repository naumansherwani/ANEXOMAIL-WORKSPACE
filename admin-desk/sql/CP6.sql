-- ANEXOMAIL CONTROL PLANE CP6 (phase 1m, card B13 step T1, list BL-46: TENANT REGISTRY CHECK + VERSIONED DOMAIN OWNERSHIP), 24 Nov 2026 PKT.
-- SCHEMA-FIRST: read before writing: AD07 (desk.fadm_case: company_ref is free text, no tenant UUID), CP5 (cp.consent_inbox / cp.consent_ledger, hash-chain pattern, roles cp_lookup and cp_consent_customer), CP4 (cp schema, SECURITY DEFINER with search_path = pg_catalog, pg_temp), the live awam schema docs/cursor-work/live-snapshot/sql/schema-public.sql: public.orgs (id, name), public.org_domains (org_id -> organisations(id) ON DELETE CASCADE, domain, status pending|verified|removed, verified_at, UNIQUE index org_domains_domain_active_uq on domain WHERE status <> 'removed'), public.organisations, public.account_organisations. Nothing is renamed, copied or changed in any awam table.
-- ADVANCE-RESEARCH: [1m] B13 T1 (24 Nov 2026): outside advisor review saved verbatim in docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (verified-domain registry as the automatic source, versioned domain ownership with effective dates, shared domains never auto-match, a domain claimed by two tenants is rejected); PostgreSQL range exclusion constraints (tstzrange + EXCLUDE USING gist) for non-overlapping validity periods.
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/CP6-check.sql
-- WHAT IT ADDS (nothing else): cp.tenant_ledger (append-only SHA-256 chain), cp.shared_domain (closed list of free mail providers), cp.domain_ownership (append-only history, one row per owner period of a domain, EXCLUDE: a domain never belongs to two tenants at the same time), cp.domain_ownership_sync() (owner/installer only), cp.tenant_of_domain(domain, moment), cp.tenant_registry_check().
-- DECISION NOTE (deviation from the T1 checklist point 3, stated openly): the checklist said FOREIGN KEY to orgs(id). A foreign key from this table to the awam table would BLOCK the awam account deletion flow (E24) and nFADP erasure. So the tenant must exist in public.orgs at INSERT time (trigger check), and history rows are never cascaded or deleted. Same safety, no effect on awam deletes.
-- No domain token, DKIM key, e-mail address or money is stored: domain name, tenant UUID, times only.
BEGIN;
CREATE SCHEMA IF NOT EXISTS cp;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cp_lookup') THEN CREATE ROLE cp_lookup NOLOGIN; END IF;
  BEGIN CREATE EXTENSION IF NOT EXISTS btree_gist; EXCEPTION WHEN OTHERS THEN RAISE NOTICE 'CP6: btree_gist cannot be created here (%), the unique-open-period index fallback is used', SQLERRM; END;
END $$;

CREATE TABLE IF NOT EXISTS cp.tenant_ledger (
  id bigserial PRIMARY KEY,
  at timestamptz NOT NULL DEFAULT now(),
  kind text NOT NULL CHECK (kind IN ('domain_opened','domain_closed','sync','refused','selftest')),
  org_id uuid,
  domain text CHECK (domain IS NULL OR length(domain) <= 253),
  note text NOT NULL DEFAULT '' CHECK (length(note) <= 300),
  prev bytea NOT NULL,
  hash bytea NOT NULL
);
CREATE OR REPLACE FUNCTION cp.tenant_line_hash(p_prev bytea, p_kind text, p_org uuid, p_domain text, p_note text, p_at timestamptz) RETURNS bytea LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = pg_catalog, pg_temp AS $f$
  SELECT sha256(p_prev || convert_to(concat_ws('|', p_kind, coalesce(p_org::text, ''), coalesce(p_domain, ''), p_note, to_char(p_at AT TIME ZONE 'utc', 'YYYY-MM-DD"T"HH24:MI:SS.US')), 'UTF8'))
$f$;
CREATE OR REPLACE FUNCTION cp.tenant_ledger_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $f$
DECLARE v_prev bytea;
BEGIN
  IF TG_OP IN ('UPDATE', 'DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'cp.tenant_ledger is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  PERFORM pg_advisory_xact_lock(hashtext('cp.tenant_ledger'));
  SELECT l.hash INTO v_prev FROM cp.tenant_ledger l ORDER BY l.id DESC LIMIT 1;
  NEW.prev := coalesce(v_prev, decode(repeat('00', 32), 'hex'));
  NEW.hash := cp.tenant_line_hash(NEW.prev, NEW.kind, NEW.org_id, NEW.domain, NEW.note, NEW.at);
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS tenant_ledger_chain ON cp.tenant_ledger;
CREATE TRIGGER tenant_ledger_chain BEFORE INSERT ON cp.tenant_ledger FOR EACH ROW EXECUTE FUNCTION cp.tenant_ledger_guard();
DROP TRIGGER IF EXISTS tenant_ledger_frozen ON cp.tenant_ledger;
CREATE TRIGGER tenant_ledger_frozen BEFORE UPDATE OR DELETE ON cp.tenant_ledger FOR EACH ROW EXECUTE FUNCTION cp.tenant_ledger_guard();
DROP TRIGGER IF EXISTS tenant_ledger_nottruncate ON cp.tenant_ledger;
CREATE TRIGGER tenant_ledger_nottruncate BEFORE TRUNCATE ON cp.tenant_ledger FOR EACH STATEMENT EXECUTE FUNCTION cp.tenant_ledger_guard();

CREATE TABLE IF NOT EXISTS cp.shared_domain (
  domain text PRIMARY KEY CHECK (domain = lower(domain) AND domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
  note text NOT NULL DEFAULT 'free mail provider: never matches a tenant by domain'
);
INSERT INTO cp.shared_domain (domain) VALUES ('gmail.com'),('googlemail.com'),('yahoo.com'),('yahoo.co.uk'),('ymail.com'),('outlook.com'),('hotmail.com'),('hotmail.co.uk'),('live.com'),('msn.com'),('icloud.com'),('me.com'),('mac.com'),('aol.com'),
  ('proton.me'),('protonmail.com'),('pm.me'),('gmx.com'),('gmx.net'),('gmx.de'),('mail.com'),('yandex.com'),('yandex.ru'),('zoho.com'),('fastmail.com'),('tutanota.com'),('tuta.com'),('qq.com'),('163.com'),('126.com'),('web.de'),('hey.com')
  ON CONFLICT (domain) DO NOTHING;
CREATE OR REPLACE FUNCTION cp.shared_domain_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $f$
BEGIN IF TG_OP IN ('UPDATE', 'DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'cp.shared_domain is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF; RETURN NEW; END $f$;
DROP TRIGGER IF EXISTS shared_domain_guard ON cp.shared_domain;
CREATE TRIGGER shared_domain_guard BEFORE UPDATE OR DELETE ON cp.shared_domain FOR EACH ROW EXECUTE FUNCTION cp.shared_domain_guard();
DROP TRIGGER IF EXISTS shared_domain_nottruncate ON cp.shared_domain;
CREATE TRIGGER shared_domain_nottruncate BEFORE TRUNCATE ON cp.shared_domain FOR EACH STATEMENT EXECUTE FUNCTION cp.shared_domain_guard();

CREATE TABLE IF NOT EXISTS cp.domain_ownership (
  id bigserial PRIMARY KEY,
  org_id uuid NOT NULL,
  domain text NOT NULL CHECK (domain = lower(domain) AND domain ~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'),
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  source text NOT NULL DEFAULT 'org_domains.verified' CHECK (source = 'org_domains.verified'),
  evidence_verified_at timestamptz,
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);
CREATE INDEX IF NOT EXISTS domain_ownership_domain ON cp.domain_ownership (domain, valid_from);
CREATE INDEX IF NOT EXISTS domain_ownership_org ON cp.domain_ownership (org_id);
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'btree_gist') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'domain_ownership_no_overlap') THEN
      ALTER TABLE cp.domain_ownership ADD CONSTRAINT domain_ownership_no_overlap EXCLUDE USING gist (domain WITH =, tstzrange(valid_from, valid_to, '[)') WITH &&);
    END IF;
  ELSE
    CREATE UNIQUE INDEX IF NOT EXISTS domain_ownership_one_open ON cp.domain_ownership (domain) WHERE valid_to IS NULL;
  END IF;
END $$;
CREATE OR REPLACE FUNCTION cp.domain_ownership_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog, pg_temp AS $f$
BEGIN
  IF TG_OP IN ('DELETE', 'TRUNCATE') THEN RAISE EXCEPTION 'cp.domain_ownership is append-only (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  IF TG_OP = 'INSERT' THEN
    IF EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = NEW.domain) THEN RAISE EXCEPTION 'a shared mail domain can never be owned by a tenant' USING ERRCODE = 'insufficient_privilege'; END IF;
    IF NOT EXISTS (SELECT 1 FROM public.orgs o WHERE o.id = NEW.org_id) THEN RAISE EXCEPTION 'the tenant is not in the registry (public.orgs)' USING ERRCODE = 'foreign_key_violation'; END IF;
    RETURN NEW;
  END IF;
  IF (NEW.id, NEW.org_id, NEW.domain, NEW.valid_from, NEW.source, NEW.evidence_verified_at) IS DISTINCT FROM (OLD.id, OLD.org_id, OLD.domain, OLD.valid_from, OLD.source, OLD.evidence_verified_at) THEN RAISE EXCEPTION 'ownership facts are frozen' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF OLD.valid_to IS NOT NULL THEN RAISE EXCEPTION 'a closed ownership period cannot change' USING ERRCODE = 'insufficient_privilege'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS domain_ownership_guard ON cp.domain_ownership;
CREATE TRIGGER domain_ownership_guard BEFORE INSERT OR UPDATE OR DELETE ON cp.domain_ownership FOR EACH ROW EXECUTE FUNCTION cp.domain_ownership_guard();
DROP TRIGGER IF EXISTS domain_ownership_nottruncate ON cp.domain_ownership;
CREATE TRIGGER domain_ownership_nottruncate BEFORE TRUNCATE ON cp.domain_ownership FOR EACH STATEMENT EXECUTE FUNCTION cp.domain_ownership_guard();

ALTER TABLE cp.tenant_ledger ENABLE ROW LEVEL SECURITY; ALTER TABLE cp.tenant_ledger FORCE ROW LEVEL SECURITY;
ALTER TABLE cp.shared_domain ENABLE ROW LEVEL SECURITY; ALTER TABLE cp.shared_domain FORCE ROW LEVEL SECURITY;
ALTER TABLE cp.domain_ownership ENABLE ROW LEVEL SECURITY; ALTER TABLE cp.domain_ownership FORCE ROW LEVEL SECURITY;
REVOKE ALL ON cp.tenant_ledger, cp.shared_domain, cp.domain_ownership FROM PUBLIC;
REVOKE ALL ON cp.tenant_ledger, cp.shared_domain, cp.domain_ownership FROM cp_lookup;
REVOKE ALL ON SEQUENCE cp.tenant_ledger_id_seq, cp.domain_ownership_id_seq FROM PUBLIC;

CREATE OR REPLACE FUNCTION cp.tenant_note(p_kind text, p_org uuid, p_domain text, p_note text) RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
  INSERT INTO cp.tenant_ledger (kind, org_id, domain, note) VALUES (p_kind, p_org, p_domain, p_note)
$f$;

-- SYNC (owner / installer only, never granted to cp_lookup): brings the history in line with public.org_domains. Closes periods of domains no longer verified or now held by another org, opens periods for verified domains of tenants in public.orgs. Ledger line BEFORE every change. Idempotent. No trigger on any awam table.
CREATE OR REPLACE FUNCTION cp.domain_ownership_sync() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '20s' AS $f$
DECLARE v_now timestamptz := clock_timestamp(); r record; n_closed int := 0; n_opened int := 0; n_skipped int := 0;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('cp.domain_ownership_sync'));
  FOR r IN SELECT o.id, o.org_id, o.domain FROM cp.domain_ownership o
           WHERE o.valid_to IS NULL AND NOT EXISTS (SELECT 1 FROM public.org_domains d WHERE d.domain = o.domain AND d.org_id = o.org_id AND d.status = 'verified') LOOP
    PERFORM cp.tenant_note('domain_closed', r.org_id, r.domain, 'no longer verified for this tenant');
    UPDATE cp.domain_ownership SET valid_to = greatest(v_now, valid_from + interval '1 microsecond') WHERE id = r.id; n_closed := n_closed + 1;
  END LOOP;
  FOR r IN SELECT d.org_id, d.domain, d.verified_at FROM public.org_domains d
           WHERE d.status = 'verified' AND NOT EXISTS (SELECT 1 FROM cp.domain_ownership o WHERE o.domain = d.domain AND o.valid_to IS NULL) ORDER BY d.domain LOOP
    IF EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = r.domain) OR NOT EXISTS (SELECT 1 FROM public.orgs t WHERE t.id = r.org_id) THEN n_skipped := n_skipped + 1; CONTINUE; END IF;
    PERFORM cp.tenant_note('domain_opened', r.org_id, r.domain, 'verified domain, new owner period');
    INSERT INTO cp.domain_ownership (org_id, domain, valid_from, evidence_verified_at) VALUES (r.org_id, r.domain, greatest(v_now, coalesce((SELECT max(c.valid_to) FROM cp.domain_ownership c WHERE c.domain = r.domain), v_now)), r.verified_at); n_opened := n_opened + 1;
  END LOOP;
  IF n_closed + n_opened > 0 THEN PERFORM cp.tenant_note('sync', NULL, NULL, 'closed ' || n_closed || ' opened ' || n_opened || ' skipped ' || n_skipped); END IF;
  RETURN jsonb_build_object('closed', n_closed, 'opened', n_opened, 'skipped_shared_or_not_a_tenant', n_skipped);
END $f$;

-- READ DOOR 1: which ONE tenant owned this domain at this moment. NULL = unknown, shared, bad shape. Two owners at once cannot exist (EXCLUDE).
CREATE OR REPLACE FUNCTION cp.tenant_of_domain(p_domain text, p_at timestamptz DEFAULT now()) RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
  SELECT CASE WHEN p_domain IS NULL OR p_at IS NULL OR p_domain <> lower(p_domain) OR p_domain !~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$' OR EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = p_domain) THEN NULL
    ELSE (SELECT o.org_id FROM cp.domain_ownership o WHERE o.domain = p_domain AND o.valid_from <= p_at AND (o.valid_to IS NULL OR o.valid_to > p_at) LIMIT 1) END
$f$;

-- READ DOOR 2: counts only. Proves the company tables do not disagree and the history is complete.
CREATE OR REPLACE FUNCTION cp.tenant_registry_check() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '8s' AS $f$
DECLARE v_orgs int; v_organisations int := -1; v_account int := -1; v_miss_a int := -1; v_miss_b int := -1;
BEGIN
  SELECT count(*) INTO v_orgs FROM public.orgs;
  IF to_regclass('public.organisations') IS NOT NULL THEN SELECT count(*) INTO v_organisations FROM public.organisations; SELECT count(*) INTO v_miss_a FROM public.orgs o WHERE NOT EXISTS (SELECT 1 FROM public.organisations x WHERE x.id = o.id); END IF;
  IF to_regclass('public.account_organisations') IS NOT NULL THEN SELECT count(*) INTO v_account FROM public.account_organisations; SELECT count(*) INTO v_miss_b FROM public.orgs o WHERE NOT EXISTS (SELECT 1 FROM public.account_organisations x WHERE x.id = o.id); END IF;
  RETURN jsonb_build_object('orgs', v_orgs, 'organisations', v_organisations, 'account_organisations', v_account, 'orgs_missing_in_organisations', v_miss_a, 'orgs_missing_in_account_organisations', v_miss_b,
    'domains_verified', (SELECT count(*) FROM public.org_domains d WHERE d.status = 'verified'),
    'verified_domains_shared', (SELECT count(*) FROM public.org_domains d JOIN cp.shared_domain s ON s.domain = d.domain WHERE d.status = 'verified'),
    'verified_domains_of_a_non_tenant', (SELECT count(*) FROM public.org_domains d WHERE d.status = 'verified' AND NOT EXISTS (SELECT 1 FROM public.orgs o WHERE o.id = d.org_id)),
    'domains_with_open_history', (SELECT count(*) FROM cp.domain_ownership o WHERE o.valid_to IS NULL),
    'verified_missing_history', (SELECT count(*) FROM public.org_domains d WHERE d.status = 'verified' AND EXISTS (SELECT 1 FROM public.orgs o WHERE o.id = d.org_id) AND NOT EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = d.domain) AND NOT EXISTS (SELECT 1 FROM cp.domain_ownership h WHERE h.domain = d.domain AND h.org_id = d.org_id AND h.valid_to IS NULL)),
    'history_rows', (SELECT count(*) FROM cp.domain_ownership),
    'overlapping_periods', (SELECT count(*) FROM cp.domain_ownership a JOIN cp.domain_ownership b ON a.domain = b.domain AND a.id < b.id AND tstzrange(a.valid_from, a.valid_to, '[)') && tstzrange(b.valid_from, b.valid_to, '[)')));
END $f$;

CREATE OR REPLACE FUNCTION cp.tenant_ledger_verify() RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp AS $f$
DECLARE r record; p bytea := decode(repeat('00', 32), 'hex');
BEGIN
  FOR r IN SELECT * FROM cp.tenant_ledger ORDER BY id LOOP
    IF r.prev <> p OR r.hash <> cp.tenant_line_hash(r.prev, r.kind, r.org_id, r.domain, r.note, r.at) THEN RETURN false; END IF; p := r.hash;
  END LOOP; RETURN true;
END $f$;

REVOKE ALL ON FUNCTION cp.tenant_line_hash(bytea, text, uuid, text, text, timestamptz), cp.tenant_ledger_guard(), cp.shared_domain_guard(), cp.domain_ownership_guard(), cp.tenant_note(text, uuid, text, text),
  cp.domain_ownership_sync(), cp.tenant_of_domain(text, timestamptz), cp.tenant_registry_check(), cp.tenant_ledger_verify() FROM PUBLIC;
GRANT USAGE ON SCHEMA cp TO cp_lookup;
GRANT EXECUTE ON FUNCTION cp.tenant_of_domain(text, timestamptz), cp.tenant_registry_check(), cp.tenant_ledger_verify() TO cp_lookup;

-- SELFTEST (rolled back). The real org_domains query is run on the live schema; the move/overlap rules use test rows only.
CREATE FUNCTION pg_temp.cp6_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'CP6 selftest: %', msg USING ERRCODE = 'P0AS1'; END IF; END $f$;
DO $$
DECLARE o1 uuid := gen_random_uuid(); o2 uuid := gen_random_uuid(); ghost uuid := gen_random_uuid(); t0 timestamptz := clock_timestamp(); s1 jsonb; s2 jsonb; failed boolean; v_real int;
BEGIN
  INSERT INTO public.orgs (id, name) VALUES (o1, 'cp6-a-' || o1), (o2, 'cp6-b-' || o2);
  s1 := cp.domain_ownership_sync(); s2 := cp.domain_ownership_sync();
  PERFORM pg_temp.cp6_ok((s2 ->> 'opened')::int = 0 AND (s2 ->> 'closed')::int = 0, 'the sync is idempotent (second run changes nothing)');
  SELECT count(*) INTO v_real FROM public.org_domains d WHERE d.status = 'verified' AND EXISTS (SELECT 1 FROM public.orgs o WHERE o.id = d.org_id) AND NOT EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = d.domain);
  PERFORM pg_temp.cp6_ok((SELECT count(*) FROM cp.domain_ownership WHERE valid_to IS NULL) = v_real, 'every real verified domain of a tenant has exactly one open ownership period');
  PERFORM pg_temp.cp6_ok((cp.tenant_registry_check() ->> 'verified_missing_history')::int = 0 AND (cp.tenant_registry_check() ->> 'overlapping_periods')::int = 0, 'the registry check finds no gap and no overlap');
  INSERT INTO cp.domain_ownership (org_id, domain, valid_from, valid_to) VALUES (o1, 'cp6-test.example', t0 - interval '10 days', t0 - interval '5 days');
  INSERT INTO cp.domain_ownership (org_id, domain, valid_from) VALUES (o2, 'cp6-test.example', t0 - interval '5 days');
  PERFORM pg_temp.cp6_ok(cp.tenant_of_domain('cp6-test.example', t0 - interval '7 days') = o1, 'seven days ago the domain belonged to tenant 1');
  PERFORM pg_temp.cp6_ok(cp.tenant_of_domain('cp6-test.example', t0) = o2, 'now the domain belongs to tenant 2 (a domain can move)');
  PERFORM pg_temp.cp6_ok(cp.tenant_of_domain('cp6-test.example', t0 - interval '20 days') IS NULL, 'before anyone owned it: nobody');
  failed := false; BEGIN INSERT INTO cp.domain_ownership (org_id, domain, valid_from) VALUES (o1, 'cp6-test.example', t0 - interval '1 day'); EXCEPTION WHEN exclusion_violation OR unique_violation THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'a domain can never belong to two tenants at the same time');
  failed := false; BEGIN INSERT INTO cp.domain_ownership (org_id, domain) VALUES (o1, 'gmail.com'); EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'a shared mail domain can never be owned');
  PERFORM pg_temp.cp6_ok(cp.tenant_of_domain('gmail.com') IS NULL, 'a shared domain never resolves to a tenant');
  failed := false; BEGIN INSERT INTO cp.domain_ownership (org_id, domain) VALUES (ghost, 'cp6-ghost.example'); EXCEPTION WHEN foreign_key_violation THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'a tenant that is not in public.orgs is refused');
  PERFORM pg_temp.cp6_ok(cp.tenant_of_domain('Bad Domain') IS NULL AND cp.tenant_of_domain(NULL) IS NULL AND cp.tenant_of_domain('CP6-TEST.EXAMPLE') IS NULL, 'odd input answers nothing');
  failed := false; BEGIN UPDATE cp.domain_ownership SET org_id = o2 WHERE domain = 'cp6-test.example' AND org_id = o1; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'ownership facts are frozen');
  failed := false; BEGIN UPDATE cp.domain_ownership SET valid_to = t0 WHERE domain = 'cp6-test.example' AND org_id = o1; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'a closed period cannot change');
  failed := false; BEGIN DELETE FROM cp.domain_ownership; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'history DELETE refused');
  PERFORM cp.tenant_note('selftest', NULL, NULL, 'cp6 ledger row');   -- a fresh install has an empty ledger: make sure one row exists, or the UPDATE below would touch nothing and prove nothing
  failed := false; BEGIN UPDATE cp.tenant_ledger SET note = 'x'; EXCEPTION WHEN insufficient_privilege THEN failed := true; END; PERFORM pg_temp.cp6_ok(failed, 'ledger UPDATE refused');
  PERFORM pg_temp.cp6_ok(cp.tenant_ledger_verify(), 'the ledger chain verifies');
  PERFORM pg_temp.cp6_ok(NOT has_function_privilege('cp_lookup', 'cp.domain_ownership_sync()', 'execute') AND has_function_privilege('cp_lookup', 'cp.tenant_of_domain(text, timestamptz)', 'execute') AND NOT has_table_privilege('cp_lookup', 'cp.domain_ownership', 'select'), 'the Control Plane role can read the answer, never the table, never run the sync');
  PERFORM cp.tenant_note('selftest', NULL, NULL, 'cp6');
  RAISE EXCEPTION 'CP6 selftest done' USING ERRCODE = 'P0AS2';
EXCEPTION WHEN SQLSTATE 'P0AS2' THEN RAISE NOTICE 'CP6 selftest: ALL RULES PASSED (selftest rows rolled back)';
END $$;
COMMIT;
-- first fill (outside the selftest, owner only): the real history starts here
SELECT cp.domain_ownership_sync()::text;
