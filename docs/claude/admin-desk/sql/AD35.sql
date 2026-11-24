-- AD35 (phase 1m B13 steps T4h + T4i, 25 Nov 2026 PKT): SIGNED LEDGER CHECKPOINTS, COMPANY IDENTIFIERS WITH FULL HISTORY, PROVEN REGISTER SHAPES. It carries AD34 forward: AD34 made a manual company exception need two different people and gave the Desk the GLEIF register list (desk.registry_kind, desk.registry_check); AD35 makes that exception leave a durable, checkable identity trail (the company's own registry number, per register, with history) and makes the ledger that records it provable from OUTSIDE the database.
-- SCHEMA-FIRST: read before writing: AD01 (desk.fadm_ledger: seq, ts, kind, detail, prev_hash, hash; the chain trigger computes seq and both hashes, three freeze triggers; fadm_ledger_verify walks from the genesis hash with sha256(prev || seq|ts|kind|detail)), AD02 (desk.fadm_audit, fadm_ledger_kind guard, fadm_authorize, fadm_rel), AD29 (desk.fadm_ledger_anchor: DB-internal anchors; AD35 does not replace them, it adds SIGNED ones), AD30 (desk.fadm_case_binding, the ONE binding writer), AD34 (desk.fadm_bind_proposal, desk.fadm_bind_may = case.assign on the desk department, desk_bind_owner pattern, desk.registry_kind, desk.registry_check, the P0AW* error codes). Nothing of AD01..AD34 is changed except two additive guards on desk.registry_kind (frozen identity columns).
-- ADVANCE-RESEARCH: [1m] B13 T4h + T4i (25 Nov 2026 web search; plan docs/claude/admin-desk/D6-B13-T4I-REGISTRATION-NUMBERS-PLAN-25NOV.md): (1) C2SP tlog-checkpoint + tlog-cosignature (https://github.com/C2SP/C2SP/blob/main/tlog-cosignature.md): a transparency-log checkpoint is a small text body of origin line, tree size in ASCII decimal and the base64 root hash, each line ending in a newline, signed with Ed25519 (RFC 8032); a cosigner adds a timestamp and signs the same body; ML-DSA-44 is recommended for new deployments. AD35 stores exactly that body format and the signature the Rust signer makes, binds the body to the ledger line it claims, and records off-box witnesses. (2) RFC 9162 Certificate Transparency 2.0 (https://www.rfc-editor.org/rfc/rfc9162.html): an append-only log is audited by signed tree heads plus consistency checks between two heads, so a monitor verifies only what was added since its last head; AD35 verifies the ledger between two checkpoints with a ranged walk. (3) PostgreSQL temporal constraints (https://www.postgresql.org/docs/current/ddl-temporal-tables.html): WITHOUT OVERLAPS needs btree_gist and a newer PostgreSQL than this server is proven to run, so the same guarantee (one live holder per company number, no overlapping periods) is built with PARTIAL UNIQUE INDEXES plus an advisory-lock trigger that works on PostgreSQL 16. (4) Bitemporal history (valid time + recorded time): a company identifier is never overwritten; it is closed with a reason and a new row opened, so what was true when, and who recorded it, is answerable years later. (5) GLEIF Registration Authorities List v1.9: the list names the register, not the number shape, so a shape enters the table only through a PROOF function with its source page and sample numbers; the database refuses a shape without its source (AD34 CHECK) and refuses a pattern that can run away (nested quantifiers) or that fails its own samples. (6) OWASP Logging: ledger lines carry closed words and ids, never a company number (only a 12-character hash of it) and never free text.
-- DECISION-READ: docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (a company is tied to a case only by a controlled path: two authorised staff, a reason, a ledger line, never a silent guess; AD35 adds the company's registry identity as evidence, it never binds a case by itself).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD35-check.sql
-- WHAT IT ADDS (AD01..AD34 unchanged, no table of an earlier phase is rewritten):
--   A) desk.ledger_checkpoint (append-only signed checkpoints: C2SP body, Ed25519 signature made by the Rust signer, key id), desk.ledger_checkpoint_witness (off-box copies, append-only), the doors desk.ledger_checkpoint_head (what to sign), desk.ledger_checkpoint_put (store a signature, binding refused when it does not match the ledger), desk.ledger_checkpoint_witnessed, desk.ledger_checkpoint_status (closed state words for the Systems card), desk.ledger_range_ok (ranged chain walk) and desk.ledger_checkpoint_verify (per-checkpoint result).
--   B) desk.company_identifier (bitemporal: a company's registry number per register, valid time + recorded time, two different confirmers, one live holder per number, one live number per company per register), desk.registry_normalise, and the doors desk.company_identifier_set, desk.company_identifier_end, desk.company_identifier_lookup, desk.company_identifier_history.
--   C) desk.registry_shape_prove (migration-only: a register's number shape enters only with source, date, valid samples and invalid samples; a runaway pattern is refused), a guard that freezes every identity column of desk.registry_kind, and the picker readers desk.registry_countries and desk.registry_pick.
--   D) ledger kinds ckpt.recorded, ckpt.refused, ident.recorded, ident.superseded, ident.ended, ident.refused; the NOLOGIN owner role desk_proof_owner (NOSUPERUSER, NOBYPASSRLS) that owns the AD35 doors.
-- WHO MAY DO WHAT: the checkpoint doors are called by the Desk service role (desk_app): the Rust signer reads the head body, signs it with the Desk's own key (never inside the database) and stores the signature; company_identifier_set and company_identifier_end need TWO DIFFERENT active staff who both hold case.assign on the desk department (the right AD34 uses) and answer closed words; company_identifier_lookup and company_identifier_history need staff.read; registry_shape_prove has no client grant at all (migration or a reviewed SQL file only).
-- IDEMPOTENT + CONCURRENCY-SAFE: rerunning this file changes nothing (IF NOT EXISTS, CREATE OR REPLACE, DROP TRIGGER IF EXISTS); the same checkpoint twice answers 'already'; the same identifier twice answers 'already'; two staff racing on one company number queue on a per-number advisory lock, two racing on one company queue on a per-company advisory lock, locks are always taken number first then company so they cannot deadlock each other; the partial unique indexes are the last line when a lock is bypassed.
-- HONEST LIMITS: (1) PostgreSQL 16 has no Ed25519 verify, so the database stores the signature and proves the body matches the ledger line, the key id and size order; the Rust verifier (T4h Rust side, not in this file) checks the signature and the off-box copy (needs the Storage Box credentials, his hands). (2) The database cannot know that a tenant UUID is a real company: the Rust door asks the Control Plane first (T4e); this file refuses nil/null only. (3) A register whose shape is not proven stays 'shape_unproven': the number is accepted as typed after normalisation and the row says so; it is never presented as verified. (4) The ranged chain walk is capped (20,000 lines per call); a larger gap answers 'range_too_large' and the daily full verification (AD29) remains the authority.

-- A0) owner role, ledger kinds ------------------------------------------------------------------------------------------------------------------------------------------------
DO $o$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_proof_owner') THEN CREATE ROLE desk_proof_owner NOLOGIN NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION; END IF;
  BEGIN EXECUTE format('GRANT desk_proof_owner TO %I', current_user); EXCEPTION WHEN OTHERS THEN NULL; END;   -- the installer must be a member to hand functions over
END $o$;
GRANT USAGE, CREATE ON SCHEMA desk TO desk_proof_owner;

INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ckpt.recorded', 'info',   'B13 T4h: a signed ledger checkpoint was stored (tree size and key id only)'),
  ('ckpt.refused',  'high',   'B13 T4h: a checkpoint was refused (closed reason word)'),
  ('ident.recorded', 'notice', 'B13 T4i: a company registry identifier was recorded by two people (ids and a 12-character hash, never the number)'),
  ('ident.superseded', 'notice', 'B13 T4i: a live company identifier was closed because a new one replaced it'),
  ('ident.ended',   'notice', 'B13 T4i: a live company identifier was ended (withdrawn or wrong)'),
  ('ident.refused', 'high',   'B13 T4i: an identifier call was refused (closed reason word)')
ON CONFLICT (kind) DO NOTHING;

-- A1) the origin: one constant, so a checkpoint body can never claim another log ---------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_origin() RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $f$ SELECT 'admindesk.anexomail.com/ledger'::text $f$;
COMMENT ON FUNCTION desk.ledger_origin() IS 'AD35: the C2SP checkpoint origin line of the Admin Desk ledger.';

-- A2) the checkpoint table ----------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.ledger_checkpoint (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  origin     text   NOT NULL CHECK (origin = 'admindesk.anexomail.com/ledger'),
  tree_size  bigint NOT NULL CHECK (tree_size >= 1),
  root_hash  bytea  NOT NULL CHECK (octet_length(root_hash) = 32),
  body       text   NOT NULL CHECK (char_length(body) BETWEEN 40 AND 400 AND right(body, 1) = E'\n'),
  key_id     text   NOT NULL CHECK (key_id ~ '^[0-9a-f]{16}$'),
  sig        bytea  NOT NULL CHECK (octet_length(sig) = 64),
  signed_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT ledger_checkpoint_one_per_key UNIQUE (origin, tree_size, key_id)
);
CREATE INDEX IF NOT EXISTS ledger_checkpoint_newest ON desk.ledger_checkpoint (tree_size DESC, id DESC);
ALTER TABLE desk.ledger_checkpoint ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.ledger_checkpoint FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.ledger_checkpoint FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'ledger_checkpoint' AND policyname = 'p_ckpt_none') THEN
    CREATE POLICY p_ckpt_none ON desk.ledger_checkpoint FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;

CREATE TABLE IF NOT EXISTS desk.ledger_checkpoint_witness (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  checkpoint_id bigint NOT NULL REFERENCES desk.ledger_checkpoint(id),
  witness       text   NOT NULL CHECK (witness IN ('storage_box', 'second_server', 'external_log')),
  cosig         bytea  CHECK (cosig IS NULL OR octet_length(cosig) BETWEEN 8 AND 4627),   -- C2SP cosignature: 8-byte time + signature (Ed25519 = 72 bytes, ML-DSA-44 = 2428 bytes + 8)
  recorded_at   timestamptz NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT ledger_checkpoint_witness_once UNIQUE (checkpoint_id, witness)
);
ALTER TABLE desk.ledger_checkpoint_witness ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.ledger_checkpoint_witness FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.ledger_checkpoint_witness FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'ledger_checkpoint_witness' AND policyname = 'p_ckpt_witness_none') THEN
    CREATE POLICY p_ckpt_witness_none ON desk.ledger_checkpoint_witness FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;

-- A3) append-only: neither table can be updated, deleted or truncated, by anyone (the owner role included) ------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN RAISE EXCEPTION '% is append-only (% refused)', TG_TABLE_NAME, TG_OP USING ERRCODE = 'insufficient_privilege'; END $f$;
DROP TRIGGER IF EXISTS ledger_checkpoint_frozen ON desk.ledger_checkpoint;
CREATE TRIGGER ledger_checkpoint_frozen BEFORE UPDATE OR DELETE ON desk.ledger_checkpoint FOR EACH ROW EXECUTE FUNCTION desk.ledger_checkpoint_frozen();
DROP TRIGGER IF EXISTS ledger_checkpoint_frozen_t ON desk.ledger_checkpoint;
CREATE TRIGGER ledger_checkpoint_frozen_t BEFORE TRUNCATE ON desk.ledger_checkpoint FOR EACH STATEMENT EXECUTE FUNCTION desk.ledger_checkpoint_frozen();
DROP TRIGGER IF EXISTS ledger_checkpoint_witness_frozen ON desk.ledger_checkpoint_witness;
CREATE TRIGGER ledger_checkpoint_witness_frozen BEFORE UPDATE OR DELETE ON desk.ledger_checkpoint_witness FOR EACH ROW EXECUTE FUNCTION desk.ledger_checkpoint_frozen();
DROP TRIGGER IF EXISTS ledger_checkpoint_witness_frozen_t ON desk.ledger_checkpoint_witness;
CREATE TRIGGER ledger_checkpoint_witness_frozen_t BEFORE TRUNCATE ON desk.ledger_checkpoint_witness FOR EACH STATEMENT EXECUTE FUNCTION desk.ledger_checkpoint_frozen();

-- A4) the body is DERIVED, never typed: origin LF size LF base64(root) LF (C2SP tlog-checkpoint) ----------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_body(p_size bigint, p_root bytea) RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $f$
  SELECT desk.ledger_origin() || E'\n' || p_size::text || E'\n' || encode(p_root, 'base64') || E'\n'
$f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_body(bigint, bytea) IS 'AD35: the exact C2SP checkpoint body (origin, tree size, base64 root hash, each line ending in LF) the signer signs.';

-- the insert guard: the body equals the derived body, the root equals the hash of the ledger line it names, sizes never go backwards for one origin ---------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE h bytea; newest bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.ledger_checkpoint'));
  SELECT hash INTO h FROM desk.fadm_ledger WHERE seq = NEW.tree_size;
  IF h IS NULL THEN RAISE EXCEPTION 'AD35: checkpoint names a ledger line that does not exist' USING ERRCODE = 'P0AX1'; END IF;
  IF NEW.root_hash <> h THEN RAISE EXCEPTION 'AD35: checkpoint root is not the hash of that ledger line' USING ERRCODE = 'P0AX1'; END IF;
  IF NEW.body <> desk.ledger_checkpoint_body(NEW.tree_size, NEW.root_hash) THEN RAISE EXCEPTION 'AD35: checkpoint body is not the derived C2SP body' USING ERRCODE = 'P0AX1'; END IF;
  SELECT max(tree_size) INTO newest FROM desk.ledger_checkpoint WHERE origin = NEW.origin;
  IF newest IS NOT NULL AND NEW.tree_size < newest THEN RAISE EXCEPTION 'AD35: a checkpoint can not go back to a smaller tree size' USING ERRCODE = 'P0AX1'; END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS ledger_checkpoint_guard ON desk.ledger_checkpoint;
CREATE TRIGGER ledger_checkpoint_guard BEFORE INSERT ON desk.ledger_checkpoint FOR EACH ROW EXECUTE FUNCTION desk.ledger_checkpoint_guard();

-- A5) ranged chain walk: lines a+1..b are recomputed from the hash of line a (the consistency check between two signed heads) -------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_range_ok(p_from bigint, p_to bigint) RETURNS text LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '20s' SET lock_timeout = '2s' AS $f$
DECLARE r record; p bytea; n bigint;
BEGIN
  IF p_from IS NULL OR p_to IS NULL OR p_from < 0 OR p_to < p_from THEN RETURN 'bad_range'; END IF;
  IF p_to - p_from > 20000 THEN RETURN 'range_too_large'; END IF;
  IF p_from = 0 THEN p := sha256('anexomail-desk-genesis'::bytea);
  ELSE SELECT hash INTO p FROM desk.fadm_ledger WHERE seq = p_from; IF p IS NULL THEN RETURN 'no_line'; END IF; END IF;
  n := p_from;
  FOR r IN SELECT * FROM desk.fadm_ledger WHERE seq > p_from AND seq <= p_to ORDER BY seq LOOP
    n := n + 1;
    IF r.seq <> n OR r.prev_hash <> p OR r.hash <> sha256(p || convert_to(r.seq::text || '|' || r.ts::text || '|' || r.kind || '|' || r.detail::text, 'UTF8')) THEN RETURN 'chain_broken'; END IF;
    p := r.hash;
  END LOOP;
  IF n <> p_to THEN RETURN 'no_line'; END IF;
  RETURN 'ok';
END $f$;
COMMENT ON FUNCTION desk.ledger_range_ok(bigint, bigint) IS 'AD35: recompute the ledger hashes of lines from+1..to starting at the stored hash of line from; closed words ok, chain_broken, no_line, bad_range, range_too_large.';

-- A6) the doors the Rust signer and the Systems card use ------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_head() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
DECLARE l record;
BEGIN
  SELECT seq, hash INTO l FROM desk.fadm_ledger ORDER BY seq DESC LIMIT 1;
  IF l.seq IS NULL THEN RETURN NULL; END IF;
  RETURN jsonb_build_object('origin', desk.ledger_origin(), 'tree_size', l.seq, 'root_b64', encode(l.hash, 'base64'), 'body', desk.ledger_checkpoint_body(l.seq, l.hash));
END $f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_head() IS 'AD35: the newest ledger line as a C2SP checkpoint body for the Rust signer to sign with the Desk key (the key never enters the database).';

CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_refuse(p_word text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN PERFORM desk.fadm_audit(NULL, 'ckpt.refused', jsonb_build_object('why', p_word)); RETURN p_word; END $f$;

CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_put(p_size bigint, p_key_id text, p_sig bytea) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE h bytea; cid bigint; newest bigint;
BEGIN
  IF p_size IS NULL OR p_size < 1 THEN RETURN desk.ledger_checkpoint_refuse('bad_size'); END IF;
  IF p_key_id IS NULL OR p_key_id !~ '^[0-9a-f]{16}$' THEN RETURN desk.ledger_checkpoint_refuse('bad_key'); END IF;
  IF p_sig IS NULL OR octet_length(p_sig) <> 64 THEN RETURN desk.ledger_checkpoint_refuse('bad_sig'); END IF;
  PERFORM pg_advisory_xact_lock(hashtext('desk.ledger_checkpoint_put'));
  SELECT hash INTO h FROM desk.fadm_ledger WHERE seq = p_size;
  IF h IS NULL THEN RETURN desk.ledger_checkpoint_refuse('no_line'); END IF;
  IF EXISTS (SELECT 1 FROM desk.ledger_checkpoint WHERE origin = desk.ledger_origin() AND tree_size = p_size AND key_id = p_key_id) THEN RETURN 'already'; END IF;
  SELECT max(tree_size) INTO newest FROM desk.ledger_checkpoint WHERE origin = desk.ledger_origin();
  IF newest IS NOT NULL AND p_size < newest THEN RETURN desk.ledger_checkpoint_refuse('stale'); END IF;
  INSERT INTO desk.ledger_checkpoint (origin, tree_size, root_hash, body, key_id, sig) VALUES (desk.ledger_origin(), p_size, h, desk.ledger_checkpoint_body(p_size, h), p_key_id, p_sig) RETURNING id INTO cid;
  PERFORM desk.fadm_audit(NULL, 'ckpt.recorded', jsonb_build_object('tree_size', p_size, 'key_id', p_key_id));
  RETURN 'recorded';
END $f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_put(bigint, text, bytea) IS 'AD35: store the Desk signer''s Ed25519 signature over the derived checkpoint body of ledger line p_size. Closed words recorded, already, bad_size, bad_key, bad_sig, no_line, stale. The database proves the binding to the ledger; the Rust verifier proves the signature.';

CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_witnessed(p_checkpoint bigint, p_witness text, p_cosig bytea) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
BEGIN
  IF p_witness IS NULL OR p_witness NOT IN ('storage_box', 'second_server', 'external_log') THEN RETURN 'bad_witness'; END IF;
  IF NOT EXISTS (SELECT 1 FROM desk.ledger_checkpoint WHERE id = p_checkpoint) THEN RETURN 'no_checkpoint'; END IF;
  IF p_cosig IS NOT NULL AND octet_length(p_cosig) NOT BETWEEN 8 AND 4627 THEN RETURN 'bad_cosig'; END IF;
  INSERT INTO desk.ledger_checkpoint_witness (checkpoint_id, witness, cosig) VALUES (p_checkpoint, p_witness, p_cosig) ON CONFLICT (checkpoint_id, witness) DO NOTHING;
  RETURN CASE WHEN FOUND THEN 'recorded' ELSE 'already' END;
END $f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_witnessed(bigint, text, bytea) IS 'AD35: record that an off-box witness (Storage Box, a second server, an external log) holds a checkpoint. Closed words recorded, already, bad_witness, no_checkpoint, bad_cosig.';

CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_verify(p_limit integer DEFAULT 20) RETURNS TABLE(checkpoint_id bigint, tree_size bigint, outcome text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '25s' AS $f$
DECLARE r record; prev bigint := NULL; lim integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 200);
BEGIN
  FOR r IN SELECT c.id, c.tree_size AS ts, c.root_hash FROM desk.ledger_checkpoint c ORDER BY c.tree_size DESC, c.id DESC LIMIT lim LOOP
    checkpoint_id := r.id; tree_size := r.ts;
    IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l WHERE l.seq = r.ts AND l.hash = r.root_hash) THEN outcome := 'root_mismatch';
    ELSIF prev IS NOT NULL AND prev > r.ts THEN outcome := ledger_range_check(r.ts, prev);
    ELSE outcome := 'ok'; END IF;
    prev := r.ts;
    RETURN NEXT;
  END LOOP;
END $f$;
-- the helper above is a thin wrapper so the loop reads clearly
CREATE OR REPLACE FUNCTION desk.ledger_range_check(p_from bigint, p_to bigint) RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$ SELECT desk.ledger_range_ok(p_from, p_to) $f$;
CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_verify(p_limit integer DEFAULT 20) RETURNS TABLE(checkpoint_id bigint, tree_size bigint, outcome text) LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '25s' AS $f$
DECLARE r record; prev bigint := NULL; lim integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 200);
BEGIN
  FOR r IN SELECT c.id, c.tree_size AS ts, c.root_hash FROM desk.ledger_checkpoint c ORDER BY c.tree_size DESC, c.id DESC LIMIT lim LOOP
    checkpoint_id := r.id; tree_size := r.ts;
    IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l WHERE l.seq = r.ts AND l.hash = r.root_hash) THEN outcome := 'root_mismatch';
    ELSIF prev IS NOT NULL AND prev > r.ts THEN outcome := desk.ledger_range_check(r.ts, prev);
    ELSE outcome := 'ok'; END IF;
    prev := r.ts;
    RETURN NEXT;
  END LOOP;
END $f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_verify(integer) IS 'AD35: for the newest checkpoints (default 20, cap 200): the root equals the stored ledger line, and the ledger between two consecutive checkpoints recomputes (consistency). Closed outcomes ok, root_mismatch, chain_broken, no_line, range_too_large.';

CREATE OR REPLACE FUNCTION desk.ledger_checkpoint_status() RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '25s' AS $f$
DECLARE c record; head bigint; bad integer; since bigint; age_s numeric; st text; witnessed integer; total integer;
BEGIN
  SELECT id, tree_size, signed_at INTO c FROM desk.ledger_checkpoint ORDER BY tree_size DESC, id DESC LIMIT 1;
  SELECT max(seq) INTO head FROM desk.fadm_ledger;
  SELECT count(*) INTO total FROM desk.ledger_checkpoint;
  IF c.id IS NULL THEN RETURN jsonb_build_object('state', 'none', 'checkpoints', 0, 'ledger_lines', COALESCE(head, 0)); END IF;
  SELECT count(*) INTO bad FROM desk.ledger_checkpoint_verify(20) v WHERE v.outcome NOT IN ('ok', 'range_too_large');
  since := COALESCE(head, 0) - c.tree_size; age_s := EXTRACT(epoch FROM (clock_timestamp() - c.signed_at));
  SELECT count(*) INTO witnessed FROM desk.ledger_checkpoint_witness w WHERE w.checkpoint_id = c.id;
  st := CASE WHEN bad > 0 THEN 'broken' WHEN age_s > 1200 OR since > 10000 THEN 'stale' ELSE 'fresh' END;
  RETURN jsonb_build_object('state', st, 'checkpoints', total, 'latest_tree_size', c.tree_size, 'lines_since', since, 'age_seconds', round(age_s), 'off_box_copies', witnessed, 'problems', bad);
END $f$;
COMMENT ON FUNCTION desk.ledger_checkpoint_status() IS 'AD35: closed state word for the Systems card: none (no checkpoint yet), fresh, stale (older than 20 minutes or more than 10,000 lines behind), broken (a checkpoint does not match the ledger). Numbers only, never the signature or the body.';

-- B0) normalisation, one definition for the whole Desk ----------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.registry_normalise(p_number text) RETURNS text LANGUAGE sql IMMUTABLE PARALLEL SAFE SET search_path = pg_catalog AS $f$
  SELECT upper(regexp_replace(coalesce(p_number, ''), '[[:space:][:cntrl:]\\-]', '', 'g'))
$f$;
COMMENT ON FUNCTION desk.registry_normalise(text) IS 'AD35: upper-case and remove spaces, control characters, backslashes and dashes. Same rule as desk.registry_check (AD34), written once.';

-- B1) company identifiers, bitemporal ---------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.company_identifier (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id    uuid   NOT NULL CHECK (tenant_id <> '00000000-0000-0000-0000-000000000000'::uuid),
  registry_id  bigint NOT NULL REFERENCES desk.registry_kind(id),
  number_norm  text   NOT NULL CHECK (number_norm ~ '^[A-Z0-9./_:()+&#@]{1,64}$'),
  shape_state  text   NOT NULL CHECK (shape_state IN ('shape_ok', 'shape_unproven')),
  recorded_by  uuid   NOT NULL REFERENCES desk.fadm_owner(id),
  confirmed_by uuid   NOT NULL REFERENCES desk.fadm_owner(id),
  recorded_at  timestamptz NOT NULL DEFAULT clock_timestamp(),
  valid_from   timestamptz NOT NULL DEFAULT clock_timestamp(),
  valid_to     timestamptz,
  ended_by     uuid REFERENCES desk.fadm_owner(id),
  ended_why    text CHECK (ended_why IS NULL OR ended_why IN ('replaced', 'withdrawn', 'wrong')),
  CONSTRAINT company_identifier_two_people CHECK (recorded_by <> confirmed_by),
  CONSTRAINT company_identifier_period CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT company_identifier_end_pair CHECK ((valid_to IS NULL) = (ended_why IS NULL) AND (valid_to IS NULL) = (ended_by IS NULL))
);
-- one LIVE holder per company number per register, and one LIVE number per company per register (the PostgreSQL 16 form of WITHOUT OVERLAPS)
CREATE UNIQUE INDEX IF NOT EXISTS company_identifier_live_number ON desk.company_identifier (registry_id, number_norm) WHERE valid_to IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS company_identifier_live_tenant ON desk.company_identifier (tenant_id, registry_id) WHERE valid_to IS NULL;
CREATE INDEX IF NOT EXISTS company_identifier_history ON desk.company_identifier (tenant_id, valid_from DESC, id DESC);
CREATE INDEX IF NOT EXISTS company_identifier_by_number ON desk.company_identifier (registry_id, number_norm, valid_from DESC);
ALTER TABLE desk.company_identifier ENABLE ROW LEVEL SECURITY;
ALTER TABLE desk.company_identifier FORCE ROW LEVEL SECURITY;
REVOKE ALL ON desk.company_identifier FROM PUBLIC;
DO $p$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'desk' AND tablename = 'company_identifier' AND policyname = 'p_ident_none') THEN
    CREATE POLICY p_ident_none ON desk.company_identifier FOR ALL USING (false) WITH CHECK (false);
  END IF;
END $p$;

-- the only legal update: close a live row once (valid_to, ended_by, ended_why); nothing else ever changes; nothing is deleted
CREATE OR REPLACE FUNCTION desk.company_identifier_guard() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN
  IF TG_OP <> 'UPDATE' THEN RAISE EXCEPTION 'desk.company_identifier is history (% refused)', TG_OP USING ERRCODE = 'insufficient_privilege'; END IF;
  IF OLD.valid_to IS NOT NULL THEN RAISE EXCEPTION 'desk.company_identifier: an ended period is final' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF NEW.valid_to IS NULL OR NEW.ended_by IS NULL OR NEW.ended_why IS NULL THEN RAISE EXCEPTION 'desk.company_identifier: a close needs valid_to, ended_by and ended_why' USING ERRCODE = 'insufficient_privilege'; END IF;
  IF (NEW.id, NEW.tenant_id, NEW.registry_id, NEW.number_norm, NEW.shape_state, NEW.recorded_by, NEW.confirmed_by, NEW.recorded_at, NEW.valid_from)
     IS DISTINCT FROM (OLD.id, OLD.tenant_id, OLD.registry_id, OLD.number_norm, OLD.shape_state, OLD.recorded_by, OLD.confirmed_by, OLD.recorded_at, OLD.valid_from) THEN
    RAISE EXCEPTION 'desk.company_identifier: only the end of the period may change' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS company_identifier_guard ON desk.company_identifier;
CREATE TRIGGER company_identifier_guard BEFORE UPDATE OR DELETE ON desk.company_identifier FOR EACH ROW EXECUTE FUNCTION desk.company_identifier_guard();
DROP TRIGGER IF EXISTS company_identifier_guard_t ON desk.company_identifier;
CREATE TRIGGER company_identifier_guard_t BEFORE TRUNCATE ON desk.company_identifier FOR EACH STATEMENT EXECUTE FUNCTION desk.company_identifier_guard();

-- B2) the doors -------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.company_identifier_refuse(p_actor uuid, p_word text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN PERFORM desk.fadm_audit(p_actor, 'ident.refused', jsonb_build_object('why', p_word)); RETURN p_word; END $f$;

CREATE OR REPLACE FUNCTION desk.company_identifier_set(p_actor uuid, p_second uuid, p_tenant uuid, p_registry bigint, p_number text)
RETURNS TABLE(outcome text, identifier_id bigint) LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE n text; chk text; st text; holder uuid; hid bigint; cur record; nid bigint; h12 text;
BEGIN
  identifier_id := NULL;
  IF p_actor IS NULL OR p_second IS NULL THEN outcome := 'bad_actor'; RETURN NEXT; RETURN; END IF;
  IF p_actor = p_second THEN outcome := desk.company_identifier_refuse(p_actor, 'same_person'); RETURN NEXT; RETURN; END IF;
  IF NOT desk.fadm_bind_may(p_actor) OR NOT desk.fadm_bind_may(p_second) THEN outcome := desk.company_identifier_refuse(p_actor, 'no_right'); RETURN NEXT; RETURN; END IF;
  IF p_tenant IS NULL OR p_tenant = '00000000-0000-0000-0000-000000000000'::uuid THEN outcome := desk.company_identifier_refuse(p_actor, 'bad_tenant'); RETURN NEXT; RETURN; END IF;
  IF p_registry IS NULL OR NOT EXISTS (SELECT 1 FROM desk.registry_kind WHERE id = p_registry) THEN outcome := desk.company_identifier_refuse(p_actor, 'no_register'); RETURN NEXT; RETURN; END IF;
  chk := desk.registry_check(p_registry, p_number);
  IF chk = 'bad_number' THEN outcome := desk.company_identifier_refuse(p_actor, 'bad_number'); RETURN NEXT; RETURN; END IF;
  IF chk = 'wrong_shape' THEN outcome := desk.company_identifier_refuse(p_actor, 'wrong_shape'); RETURN NEXT; RETURN; END IF;
  n := desk.registry_normalise(p_number);
  IF n !~ '^[A-Z0-9./_:()+&#@]{1,64}$' THEN outcome := desk.company_identifier_refuse(p_actor, 'bad_number'); RETURN NEXT; RETURN; END IF;
  st := CASE WHEN chk = 'ok' THEN 'shape_ok' ELSE 'shape_unproven' END;
  -- lock order: the number first, then the company, always
  PERFORM pg_advisory_xact_lock(hashtext('ident-number:' || p_registry::text || ':' || n));
  PERFORM pg_advisory_xact_lock(hashtext('ident-tenant:' || p_tenant::text || ':' || p_registry::text));
  SELECT c.tenant_id, c.id INTO holder, hid FROM desk.company_identifier c WHERE c.registry_id = p_registry AND c.number_norm = n AND c.valid_to IS NULL;
  IF holder IS NOT NULL AND holder = p_tenant THEN outcome := 'already'; identifier_id := hid; RETURN NEXT; RETURN; END IF;
  IF holder IS NOT NULL THEN outcome := desk.company_identifier_refuse(p_actor, 'taken'); RETURN NEXT; RETURN; END IF;
  SELECT * INTO cur FROM desk.company_identifier c WHERE c.tenant_id = p_tenant AND c.registry_id = p_registry AND c.valid_to IS NULL FOR UPDATE;
  h12 := left(encode(sha256(convert_to(n, 'UTF8')), 'hex'), 12);
  IF FOUND THEN
    UPDATE desk.company_identifier SET valid_to = clock_timestamp(), ended_by = p_actor, ended_why = 'replaced' WHERE id = cur.id;
    PERFORM desk.fadm_audit(p_actor, 'ident.superseded', jsonb_build_object('identifier_id', cur.id, 'registry_id', p_registry));
  END IF;
  INSERT INTO desk.company_identifier (tenant_id, registry_id, number_norm, shape_state, recorded_by, confirmed_by) VALUES (p_tenant, p_registry, n, st, p_actor, p_second) RETURNING id INTO nid;
  PERFORM desk.fadm_audit(p_actor, 'ident.recorded', jsonb_build_object('identifier_id', nid, 'registry_id', p_registry, 'shape_state', st, 'number_hash', h12));
  outcome := 'recorded'; identifier_id := nid; RETURN NEXT;
END $f$;
COMMENT ON FUNCTION desk.company_identifier_set(uuid, uuid, uuid, bigint, text) IS 'AD35: record a company''s registry number. Two DIFFERENT active staff with case.assign; the number is normalised and checked against a proven shape when one exists; one live holder per number (taken), one live number per company per register (the old one is closed as replaced). Closed words recorded, already, bad_actor, same_person, no_right, bad_tenant, no_register, bad_number, wrong_shape, taken. The ledger carries ids and a 12-character hash, never the number.';

CREATE OR REPLACE FUNCTION desk.company_identifier_end(p_actor uuid, p_second uuid, p_id bigint, p_why text) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '5s' SET lock_timeout = '2s' AS $f$
DECLARE cur record;
BEGIN
  IF p_actor IS NULL OR p_second IS NULL THEN RETURN 'bad_actor'; END IF;
  IF p_actor = p_second THEN RETURN desk.company_identifier_refuse(p_actor, 'same_person'); END IF;
  IF NOT desk.fadm_bind_may(p_actor) OR NOT desk.fadm_bind_may(p_second) THEN RETURN desk.company_identifier_refuse(p_actor, 'no_right'); END IF;
  IF p_why IS NULL OR p_why NOT IN ('withdrawn', 'wrong') THEN RETURN desk.company_identifier_refuse(p_actor, 'bad_reason'); END IF;
  SELECT * INTO cur FROM desk.company_identifier WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RETURN desk.company_identifier_refuse(p_actor, 'no_identifier'); END IF;
  IF cur.valid_to IS NOT NULL THEN RETURN 'already'; END IF;
  UPDATE desk.company_identifier SET valid_to = clock_timestamp(), ended_by = p_actor, ended_why = p_why WHERE id = p_id;
  PERFORM desk.fadm_audit(p_actor, 'ident.ended', jsonb_build_object('identifier_id', p_id, 'registry_id', cur.registry_id, 'reason', p_why));
  RETURN 'ended';
END $f$;
COMMENT ON FUNCTION desk.company_identifier_end(uuid, uuid, bigint, text) IS 'AD35: end a live identifier as withdrawn or wrong (two different staff with case.assign). Closed words ended, already, bad_actor, same_person, no_right, bad_reason, no_identifier. History is kept; nothing is deleted.';

CREATE OR REPLACE FUNCTION desk.company_identifier_lookup(p_actor uuid, p_registry bigint, p_number text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
DECLARE n text; r record;
BEGIN
  IF NOT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'staff.read', desk.fadm_unit_id('department', 'desk'), NULL)), false) THEN RETURN jsonb_build_object('state', 'no_right'); END IF;
  IF p_registry IS NULL OR NOT EXISTS (SELECT 1 FROM desk.registry_kind WHERE id = p_registry) THEN RETURN jsonb_build_object('state', 'no_register'); END IF;
  n := desk.registry_normalise(p_number);
  IF n = '' OR char_length(n) > 64 THEN RETURN jsonb_build_object('state', 'bad_number'); END IF;
  SELECT c.tenant_id, c.valid_from, c.shape_state INTO r FROM desk.company_identifier c WHERE c.registry_id = p_registry AND c.number_norm = n AND c.valid_to IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('state', 'none'); END IF;
  RETURN jsonb_build_object('state', 'found', 'tenant_id', r.tenant_id, 'since', r.valid_from, 'shape_state', r.shape_state);
END $f$;
COMMENT ON FUNCTION desk.company_identifier_lookup(uuid, bigint, text) IS 'AD35: which company holds this registry number now (staff.read). Closed states found, none, no_right, no_register, bad_number.';

CREATE OR REPLACE FUNCTION desk.company_identifier_history(p_actor uuid, p_tenant uuid) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
BEGIN
  IF NOT COALESCE((SELECT allowed FROM desk.fadm_authorize(p_actor, 'staff.read', desk.fadm_unit_id('department', 'desk'), NULL)), false) THEN RETURN NULL; END IF;
  IF p_tenant IS NULL THEN RETURN '[]'::jsonb; END IF;
  RETURN COALESCE((SELECT jsonb_agg(x ORDER BY x->>'valid_from' DESC) FROM (
    SELECT jsonb_build_object('id', c.id, 'register', k.register_name, 'country', k.country_code, 'ra_code', k.ra_code, 'number', c.number_norm, 'shape_state', c.shape_state,
           'valid_from', c.valid_from, 'valid_to', c.valid_to, 'ended_why', c.ended_why) AS x
    FROM desk.company_identifier c JOIN desk.registry_kind k ON k.id = c.registry_id WHERE c.tenant_id = p_tenant ORDER BY c.valid_from DESC, c.id DESC LIMIT 100) q), '[]'::jsonb);
END $f$;
COMMENT ON FUNCTION desk.company_identifier_history(uuid, uuid) IS 'AD35: every registry number a company ever held, newest first (staff.read), at most 100. Names and numbers of public registers only; no person ids.';

-- C1) registry_kind: identity columns are frozen; only the proof triple may change ---------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.registry_kind_cols_frozen() RETURNS trigger LANGUAGE plpgsql SET search_path = pg_catalog AS $f$
BEGIN
  IF (NEW.id, NEW.ra_code, NEW.country, NEW.country_code, NEW.jurisdiction, NEW.register_name, NEW.local_name, NEW.authority, NEW.local_authority, NEW.website, NEW.comment)
     IS DISTINCT FROM (OLD.id, OLD.ra_code, OLD.country, OLD.country_code, OLD.jurisdiction, OLD.register_name, OLD.local_name, OLD.authority, OLD.local_authority, OLD.website, OLD.comment) THEN
    RAISE EXCEPTION 'desk.registry_kind: only number_shape, shape_source and shape_checked_on may change' USING ERRCODE = 'P0AW5';
  END IF;
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS registry_kind_cols_frozen ON desk.registry_kind;
CREATE TRIGGER registry_kind_cols_frozen BEFORE UPDATE ON desk.registry_kind FOR EACH ROW EXECUTE FUNCTION desk.registry_kind_cols_frozen();

-- C2) the shape proof: source + date + valid samples + invalid samples, and a pattern that cannot run away ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.registry_shape_prove(p_registry bigint, p_shape text, p_source text, p_checked_on date, p_good text[], p_bad text[]) RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' SET lock_timeout = '2s' AS $f$
DECLARE s text; ok boolean := true;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM desk.registry_kind WHERE id = p_registry) THEN RETURN 'no_register'; END IF;
  IF p_shape IS NULL OR char_length(p_shape) NOT BETWEEN 4 AND 200 OR left(p_shape, 1) <> '^' OR right(p_shape, 1) <> '$' THEN RETURN 'bad_shape'; END IF;
  IF p_shape ~ '\)[*+{]' OR p_shape ~ '\\[0-9]' OR p_shape ~ '\(\?' OR p_shape ~ '\.[*+]' THEN RETURN 'runaway_shape'; END IF;   -- no repeated groups, no back-references, no look-around, no open-ended wildcards
  IF p_source IS NULL OR p_source !~ '^https://[^ ]{4,255}$' THEN RETURN 'bad_source'; END IF;
  IF p_checked_on IS NULL OR p_checked_on > CURRENT_DATE OR p_checked_on < DATE '2020-01-01' THEN RETURN 'bad_date'; END IF;
  IF p_good IS NULL OR p_bad IS NULL OR cardinality(p_good) < 2 OR cardinality(p_bad) < 1 OR cardinality(p_good) > 20 OR cardinality(p_bad) > 20 THEN RETURN 'need_samples'; END IF;
  BEGIN
    FOREACH s IN ARRAY p_good LOOP IF desk.registry_normalise(s) !~ p_shape THEN ok := false; END IF; END LOOP;
    FOREACH s IN ARRAY p_bad LOOP IF desk.registry_normalise(s) ~ p_shape THEN ok := false; END IF; END LOOP;
  EXCEPTION WHEN OTHERS THEN RETURN 'bad_shape';
  END;
  IF NOT ok THEN RETURN 'samples_disagree'; END IF;
  UPDATE desk.registry_kind SET number_shape = p_shape, shape_source = p_source, shape_checked_on = p_checked_on WHERE id = p_registry;
  RETURN 'proven';
END $f$;
COMMENT ON FUNCTION desk.registry_shape_prove(bigint, text, text, date, text[], text[]) IS 'AD35: the ONLY way a number shape enters desk.registry_kind: anchored pattern, https source page, check date, at least 2 valid and 1 invalid sample that the pattern really separates, no repeated groups or open wildcards. Closed words proven, no_register, bad_shape, runaway_shape, bad_source, bad_date, need_samples, samples_disagree. No client grant.';

-- C3) picker readers (read-only, for the Company confirmation screen) -----------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.registry_countries() RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
  SELECT COALESCE(jsonb_agg(jsonb_build_object('code', x.country_code, 'country', x.country, 'registers', x.n) ORDER BY x.country), '[]'::jsonb)
  FROM (SELECT country_code, min(country) AS country, count(*) AS n FROM desk.registry_kind WHERE country_code <> '' GROUP BY country_code) x
$f$;
CREATE OR REPLACE FUNCTION desk.registry_pick(p_country text) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk SET statement_timeout = '3s' AS $f$
BEGIN
  IF p_country IS NULL OR p_country !~ '^[A-Z]{2}$' THEN RETURN '[]'::jsonb; END IF;
  RETURN COALESCE((SELECT jsonb_agg(jsonb_build_object('id', k.id, 'ra_code', k.ra_code, 'name', COALESCE(NULLIF(k.register_name, ''), NULLIF(k.authority, ''), k.ra_code), 'authority', k.authority, 'website', k.website, 'shape_known', k.number_shape IS NOT NULL) ORDER BY k.ra_code, k.id)
    FROM desk.registry_kind k WHERE k.country_code = p_country LIMIT 100), '[]'::jsonb);
END $f$;
COMMENT ON FUNCTION desk.registry_countries() IS 'AD35: jurisdictions with how many registers each, for the country picker.';
COMMENT ON FUNCTION desk.registry_pick(text) IS 'AD35: the registers of one country (two-letter code, at most 100) with whether a number shape is proven, for the register picker.';

-- D) hand the AD35 doors to the NOLOGIN owner and open exactly what each needs --------------------------------------------------------------------------------------------------------
GRANT SELECT ON desk.fadm_ledger TO desk_proof_owner;
GRANT INSERT ON desk.fadm_ledger TO desk_proof_owner;
GRANT SELECT, INSERT ON desk.ledger_checkpoint TO desk_proof_owner;
GRANT SELECT, INSERT ON desk.ledger_checkpoint_witness TO desk_proof_owner;
GRANT SELECT, INSERT, UPDATE ON desk.company_identifier TO desk_proof_owner;
GRANT SELECT ON desk.registry_kind TO desk_proof_owner;
GRANT UPDATE (number_shape, shape_source, shape_checked_on) ON desk.registry_kind TO desk_proof_owner;
GRANT SELECT ON desk.fadm_owner, desk.fadm_unit TO desk_proof_owner;
GRANT EXECUTE ON FUNCTION desk.registry_check(bigint, text) TO desk_proof_owner;
GRANT EXECUTE ON FUNCTION desk.fadm_audit(uuid, text, jsonb), desk.fadm_authorize(uuid, text, uuid, inet, timestamptz), desk.fadm_unit_id(text, text), desk.fadm_bind_may(uuid) TO desk_proof_owner;
DO $q$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_ledger', 'ledger_checkpoint', 'ledger_checkpoint_witness', 'company_identifier', 'registry_kind', 'fadm_owner', 'fadm_unit'] LOOP
    EXECUTE format('DROP POLICY IF EXISTS p_proof_owner ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_proof_owner ON desk.%I FOR ALL TO desk_proof_owner USING (true) WITH CHECK (true)', t);
  END LOOP;
END $q$;
DO $a$ DECLARE f text; BEGIN
  FOREACH f IN ARRAY ARRAY[
    'desk.ledger_checkpoint_guard()', 'desk.ledger_range_ok(bigint, bigint)', 'desk.ledger_range_check(bigint, bigint)', 'desk.ledger_checkpoint_head()', 'desk.ledger_checkpoint_refuse(text)',
    'desk.ledger_checkpoint_put(bigint, text, bytea)', 'desk.ledger_checkpoint_witnessed(bigint, text, bytea)', 'desk.ledger_checkpoint_verify(integer)', 'desk.ledger_checkpoint_status()',
    'desk.company_identifier_refuse(uuid, text)', 'desk.company_identifier_set(uuid, uuid, uuid, bigint, text)', 'desk.company_identifier_end(uuid, uuid, bigint, text)',
    'desk.company_identifier_lookup(uuid, bigint, text)', 'desk.company_identifier_history(uuid, uuid)', 'desk.registry_shape_prove(bigint, text, text, date, text[], text[])',
    'desk.registry_countries()', 'desk.registry_pick(text)'] LOOP
    EXECUTE format('ALTER FUNCTION %s OWNER TO desk_proof_owner', f);
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f);
  END LOOP;
END $a$;
-- the internal helpers (guard, refuse, range_check) and the migration-only prove function have NO client grant; the signer, the Systems card and the Company confirmation screen get only these:
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'desk_app') THEN
  GRANT EXECUTE ON FUNCTION desk.ledger_checkpoint_head(), desk.ledger_checkpoint_put(bigint, text, bytea), desk.ledger_checkpoint_witnessed(bigint, text, bytea), desk.ledger_checkpoint_verify(integer), desk.ledger_checkpoint_status(),
    desk.company_identifier_set(uuid, uuid, uuid, bigint, text), desk.company_identifier_end(uuid, uuid, bigint, text), desk.company_identifier_lookup(uuid, bigint, text), desk.company_identifier_history(uuid, uuid),
    desk.registry_countries(), desk.registry_pick(text), desk.registry_normalise(text), desk.ledger_origin(), desk.ledger_checkpoint_body(bigint, bytea) TO desk_app;
END IF; END $g$;

-- SELFTEST (rolls back; success is the exception P0AX4) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad35_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD35 selftest: %', msg USING ERRCODE = 'P0AX3'; END IF; END $f$;
DO $$
DECLARE sfx text := substr(md5(random()::text), 1, 8); a1 uuid; a2 uuid; a3 uuid; unit uuid := desk.fadm_unit_id('department', 'desk'); t1 uuid := gen_random_uuid(); t2 uuid := gen_random_uuid();
  hd jsonb; sz bigint; sg bytea := decode(repeat('ab', 64), 'hex'); w text; r record; k1 bigint; k2 bigint; i1 bigint; i2 bigint; j jsonb; n0 bigint; marker text := 'AD35-' || substr(md5(random()::text), 1, 8); fk bigint;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a35a-' || sfx || '@selftest.invalid', 'AD35 A', 'agent', NULL, true, 'UTC') RETURNING id INTO a1;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a35b-' || sfx || '@selftest.invalid', 'AD35 B', 'agent', NULL, true, 'UTC') RETURNING id INTO a2;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, timezone) VALUES ('a35c-' || sfx || '@selftest.invalid', 'AD35 C', 'agent', NULL, true, 'UTC') RETURNING id INTO a3;
  INSERT INTO desk.fadm_rel (object_type, object_id, relation, subject_type, subject_id, created_by) VALUES ('unit', unit, 'lead', 'owner', a1, a1), ('unit', unit, 'lead', 'owner', a2, a1);   -- a1 and a2 hold case.assign; a3 does not
  -- A) checkpoints
  PERFORM pg_temp.ad35_ok(desk.ledger_origin() = 'admindesk.anexomail.com/ledger', 'the origin is one constant');
  hd := desk.ledger_checkpoint_head(); sz := (hd->>'tree_size')::bigint;
  PERFORM pg_temp.ad35_ok(sz >= 1 AND hd->>'body' = desk.ledger_origin() || E'\n' || sz::text || E'\n' || (hd->>'root_b64') || E'\n', 'the head body is origin LF size LF base64 LF');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_put(0, '0123456789abcdef', sg) = 'bad_size' AND desk.ledger_checkpoint_put(sz, 'XYZ', sg) = 'bad_key' AND desk.ledger_checkpoint_put(sz, '0123456789abcdef', '\x00'::bytea) = 'bad_sig' AND desk.ledger_checkpoint_put(sz + 1000000, '0123456789abcdef', sg) = 'no_line', 'bad input is refused with closed words');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_status()->>'state' IN ('none', 'fresh', 'stale', 'broken'), 'status answers a closed state word');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_put(sz, '0123456789abcdef', sg) = 'recorded', 'a checkpoint of the head is stored');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_put(sz, '0123456789abcdef', sg) = 'already', 'the same checkpoint twice answers already');
  PERFORM pg_temp.ad35_ok((SELECT count(*) FROM desk.ledger_checkpoint WHERE tree_size = sz) = 1 AND (SELECT root_hash FROM desk.ledger_checkpoint WHERE tree_size = sz LIMIT 1) = (SELECT hash FROM desk.fadm_ledger WHERE seq = sz), 'the stored root is the hash of the ledger line');
  PERFORM pg_temp.ad35_ok(desk.ledger_range_ok(sz, sz) = 'ok' AND desk.ledger_range_ok(0, sz) IN ('ok', 'range_too_large') AND desk.ledger_range_ok(5, 3) = 'bad_range' AND desk.ledger_range_ok(sz, sz + 5000000) IN ('range_too_large', 'no_line'), 'the ranged walk answers closed words');
  PERFORM pg_temp.ad35_ok(EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'ckpt.recorded' AND (detail->>'tree_size')::bigint = sz) AND EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'ckpt.refused'), 'recorded and refused are ledger lines');
  PERFORM pg_temp.ad35_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l, jsonb_object_keys(l.detail) k WHERE l.kind LIKE 'ckpt.%' AND k NOT IN ('tree_size', 'key_id', 'why')), 'ckpt ledger lines carry only the closed keys');
  BEGIN UPDATE desk.ledger_checkpoint SET key_id = 'ffffffffffffffff'; PERFORM pg_temp.ad35_ok(false, 'a checkpoint can not be updated'); EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.ledger_checkpoint; PERFORM pg_temp.ad35_ok(false, 'a checkpoint can not be deleted'); EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN INSERT INTO desk.ledger_checkpoint (origin, tree_size, root_hash, body, key_id, sig) VALUES ('admindesk.anexomail.com/ledger', sz, decode(repeat('00', 32), 'hex'), 'x' || repeat('y', 60) || E'\n', 'aaaaaaaaaaaaaaaa', sg); PERFORM pg_temp.ad35_ok(false, 'a wrong root or body is refused by the guard'); EXCEPTION WHEN SQLSTATE 'P0AX1' THEN NULL; END;
  BEGIN INSERT INTO desk.ledger_checkpoint (origin, tree_size, root_hash, body, key_id, sig) VALUES ('another.example/log', sz, (SELECT hash FROM desk.fadm_ledger WHERE seq = sz), repeat('z', 60) || E'\n', 'bbbbbbbbbbbbbbbb', sg); PERFORM pg_temp.ad35_ok(false, 'another origin is refused'); EXCEPTION WHEN check_violation OR SQLSTATE 'P0AX1' THEN NULL; END;
  k1 := (SELECT id FROM desk.ledger_checkpoint WHERE tree_size = sz LIMIT 1);
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_witnessed(k1, 'storage_box', NULL) = 'recorded' AND desk.ledger_checkpoint_witnessed(k1, 'storage_box', NULL) = 'already' AND desk.ledger_checkpoint_witnessed(k1, 'nowhere', NULL) = 'bad_witness' AND desk.ledger_checkpoint_witnessed(-5, 'storage_box', NULL) = 'no_checkpoint' AND desk.ledger_checkpoint_witnessed(k1, 'external_log', '\x01'::bytea) = 'bad_cosig', 'witnesses are recorded once, with closed words');
  hd := desk.ledger_checkpoint_head(); sz := (hd->>'tree_size')::bigint;
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_put(sz, '0123456789abcdef', sg) = 'recorded', 'a later checkpoint is stored');
  PERFORM pg_temp.ad35_ok((SELECT bool_and(outcome = 'ok') FROM desk.ledger_checkpoint_verify(20)), 'every checkpoint is bound to the ledger and the ledger between two checkpoints recomputes');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_status()->>'state' IN ('fresh', 'stale') AND (desk.ledger_checkpoint_status()->>'checkpoints')::int >= 2 AND (desk.ledger_checkpoint_status()->>'off_box_copies')::int >= 0, 'status after two checkpoints');
  -- B) registry + identifiers
  PERFORM pg_temp.ad35_ok(desk.registry_normalise(' ab-12 3 ') = 'AB123' AND desk.registry_normalise(NULL) = '' AND desk.registry_normalise(E'a\tb') = 'AB', 'normalisation removes spaces, dashes and control characters');
  k1 := (SELECT id FROM desk.registry_kind WHERE ra_code = 'RA000475' AND country_code = 'PK' LIMIT 1);
  k2 := (SELECT id FROM desk.registry_kind WHERE ra_code = 'RA001111' AND country_code = 'PK' LIMIT 1);
  PERFORM pg_temp.ad35_ok(k1 IS NOT NULL AND k2 IS NOT NULL, 'the Pakistan registers are loaded (AD34)');
  PERFORM pg_temp.ad35_ok(desk.registry_shape_prove(-1, '^[0-9]{7}$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456', '7654321'], ARRAY['12']) = 'no_register'
    AND desk.registry_shape_prove(k1, '[0-9]{7}', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456', '7654321'], ARRAY['12']) = 'bad_shape'
    AND desk.registry_shape_prove(k1, '^(a+)+$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['a', 'aa'], ARRAY['b']) = 'runaway_shape'
    AND desk.registry_shape_prove(k1, '^[0-9]+.*$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['1', '2'], ARRAY['b']) = 'runaway_shape'
    AND desk.registry_shape_prove(k1, '^[0-9]{7}$', 'http://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456', '7654321'], ARRAY['12']) = 'bad_source'
    AND desk.registry_shape_prove(k1, '^[0-9]{7}$', 'https://www.secp.gov.pk/', CURRENT_DATE + 3, ARRAY['0123456', '7654321'], ARRAY['12']) = 'bad_date'
    AND desk.registry_shape_prove(k1, '^[0-9]{7}$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456'], ARRAY['12']) = 'need_samples'
    AND desk.registry_shape_prove(k1, '^[0-9]{7}$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456', 'abc'], ARRAY['12']) = 'samples_disagree'
    AND (SELECT number_shape FROM desk.registry_kind WHERE id = k1) IS NULL, 'a shape is refused unless it is anchored, safe, sourced, dated and separated by its own samples');
  w := desk.registry_shape_prove(k1, '^[0-9]{7}$', 'https://www.secp.gov.pk/', CURRENT_DATE, ARRAY['0123456', '765 4321'], ARRAY['12', 'ABC1234']);
  PERFORM pg_temp.ad35_ok(w = 'proven' AND (SELECT number_shape FROM desk.registry_kind WHERE id = k1) = '^[0-9]{7}$', 'a shape with its proof is stored (rolled back here; the real Pakistan shape waits for the SECP page)');
  PERFORM pg_temp.ad35_ok(desk.registry_check(k1, '012 3456') = 'ok' AND desk.registry_check(k1, '12345') = 'wrong_shape', 'registry_check now uses the proven shape');
  BEGIN UPDATE desk.registry_kind SET country_code = 'XX' WHERE id = k1; PERFORM pg_temp.ad35_ok(false, 'identity columns are frozen'); EXCEPTION WHEN SQLSTATE 'P0AW5' THEN NULL; END;
  -- doors: refusals first
  n0 := (SELECT count(*) FROM desk.fadm_ledger);
  SELECT * INTO r FROM desk.company_identifier_set(a1, a1, t1, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'same_person' AND r.identifier_id IS NULL, 'one person can not confirm himself');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a3, t1, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'no_right', 'both people need case.assign');
  SELECT * INTO r FROM desk.company_identifier_set(a3, a1, t1, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'no_right', 'the first person needs case.assign too');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, NULL, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'bad_tenant', 'no tenant is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, '00000000-0000-0000-0000-000000000000'::uuid, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'bad_tenant', 'the nil UUID is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, -9, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'no_register', 'an unknown register is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, k1, '   '); PERFORM pg_temp.ad35_ok(r.outcome = 'bad_number', 'an empty number is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, k1, '12345'); PERFORM pg_temp.ad35_ok(r.outcome = 'wrong_shape', 'a number that fails a proven shape is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, k2, repeat('9', 65)); PERFORM pg_temp.ad35_ok(r.outcome = 'bad_number', 'a number over 64 characters is refused');
  PERFORM pg_temp.ad35_ok((SELECT count(*) FROM desk.company_identifier WHERE tenant_id IN (t1, t2)) = 0 AND (SELECT count(*) FROM desk.fadm_ledger) >= n0 + 7, 'refusals wrote no identifier and each wrote a ledger line');
  -- record, repeat, conflict, replace
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, k1, '012-3456'); i1 := r.identifier_id; PERFORM pg_temp.ad35_ok(r.outcome = 'recorded' AND i1 IS NOT NULL, 'two people record a company number');
  PERFORM pg_temp.ad35_ok((SELECT shape_state FROM desk.company_identifier WHERE id = i1) = 'shape_ok' AND (SELECT number_norm FROM desk.company_identifier WHERE id = i1) = '0123456', 'the number is stored normalised with its shape state');
  SELECT * INTO r FROM desk.company_identifier_set(a2, a1, t1, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'already' AND r.identifier_id = i1, 'the same number for the same company twice answers already');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t2, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'taken' AND r.identifier_id IS NULL, 'a number already live for another company is refused');
  SELECT * INTO r FROM desk.company_identifier_set(a2, a1, t1, k1, '7654321'); i2 := r.identifier_id; PERFORM pg_temp.ad35_ok(r.outcome = 'recorded' AND i2 <> i1, 'a new number for the same company replaces the old one');
  PERFORM pg_temp.ad35_ok((SELECT valid_to IS NOT NULL AND ended_why = 'replaced' AND ended_by = a2 FROM desk.company_identifier WHERE id = i1) AND (SELECT valid_to IS NULL FROM desk.company_identifier WHERE id = i2) AND (SELECT count(*) FROM desk.company_identifier WHERE tenant_id = t1 AND valid_to IS NULL) = 1, 'the old row is closed as replaced, exactly one live row remains');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t2, k1, '0123456'); PERFORM pg_temp.ad35_ok(r.outcome = 'recorded', 'a closed number can be held by another company later (history, not a lock)');
  SELECT * INTO r FROM desk.company_identifier_set(a1, a2, t1, k2, 'ntn-4567890-1'); PERFORM pg_temp.ad35_ok(r.outcome = 'recorded' AND (SELECT shape_state FROM desk.company_identifier WHERE id = r.identifier_id) = 'shape_unproven', 'a register without a proven shape records the number as shape_unproven, never as verified');
  PERFORM pg_temp.ad35_ok((SELECT count(*) FROM desk.company_identifier WHERE tenant_id = t1 AND valid_to IS NULL) = 2, 'one company may hold one live number in each register');
  BEGIN INSERT INTO desk.company_identifier (tenant_id, registry_id, number_norm, shape_state, recorded_by, confirmed_by) VALUES (t2, k1, '0123456', 'shape_ok', a1, a2); PERFORM pg_temp.ad35_ok(false, 'the unique live index refuses a second live holder'); EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO desk.company_identifier (tenant_id, registry_id, number_norm, shape_state, recorded_by, confirmed_by) VALUES (t2, k1, '5555555', 'shape_ok', a1, a1); PERFORM pg_temp.ad35_ok(false, 'two different people are a table rule'); EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE desk.company_identifier SET number_norm = '9999999' WHERE id = i2; PERFORM pg_temp.ad35_ok(false, 'a live number can not be rewritten'); EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.company_identifier SET ended_why = 'wrong' WHERE id = i1; PERFORM pg_temp.ad35_ok(false, 'an ended period is final'); EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.company_identifier WHERE id = i1; PERFORM pg_temp.ad35_ok(false, 'history is never deleted'); EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- end
  PERFORM pg_temp.ad35_ok(desk.company_identifier_end(a1, a1, i2, 'wrong') = 'same_person' AND desk.company_identifier_end(a1, a3, i2, 'wrong') = 'no_right' AND desk.company_identifier_end(a1, a2, i2, 'because') = 'bad_reason' AND desk.company_identifier_end(a1, a2, -4, 'wrong') = 'no_identifier', 'ending needs two different people, a closed reason and a real identifier');
  w := desk.company_identifier_end(a1, a2, i2, 'wrong');
  PERFORM pg_temp.ad35_ok(w = 'ended', 'two people end a live identifier');
  w := desk.company_identifier_end(a1, a2, i2, 'wrong');
  PERFORM pg_temp.ad35_ok(w = 'already' AND (SELECT ended_why FROM desk.company_identifier WHERE id = i2) = 'wrong', 'ending is idempotent');
  -- lookup + history
  PERFORM pg_temp.ad35_ok(desk.company_identifier_lookup(a3, k1, '0123456')->>'state' = 'no_right', 'a person without staff.read gets no_right');
  j := desk.company_identifier_lookup(a1, k1, '012 3456');
  PERFORM pg_temp.ad35_ok(j->>'state' IN ('found', 'no_right'), 'lookup answers closed states');
  PERFORM pg_temp.ad35_ok(desk.company_identifier_lookup(a1, -1, '1')->>'state' IN ('no_register', 'no_right') AND desk.company_identifier_lookup(a1, k1, '---')->>'state' IN ('bad_number', 'no_right'), 'lookup refuses bad input in closed words');
  j := desk.company_identifier_history(a1, t1);
  PERFORM pg_temp.ad35_ok(j IS NULL OR (jsonb_typeof(j) = 'array' AND jsonb_array_length(j) >= 2), 'history lists every number the company ever held');
  PERFORM pg_temp.ad35_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l WHERE l.kind LIKE 'ident.%' AND (l.detail::text LIKE '%0123456%' OR l.detail::text LIKE '%7654321%')), 'the ledger never holds a company number');
  PERFORM pg_temp.ad35_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_ledger l, jsonb_object_keys(l.detail) k WHERE l.kind LIKE 'ident.%' AND k NOT IN ('identifier_id', 'registry_id', 'shape_state', 'number_hash', 'reason', 'why')), 'ident ledger lines carry only the closed keys');
  PERFORM pg_temp.ad35_ok(desk.ledger_checkpoint_status() IS NOT NULL AND desk.fadm_ledger_verify(), 'the ledger chain still verifies after everything above');
  -- C3 pickers
  j := desk.registry_countries(); PERFORM pg_temp.ad35_ok(jsonb_typeof(j) = 'array' AND jsonb_array_length(j) >= 234, 'the picker lists every jurisdiction');
  j := desk.registry_pick('PK'); PERFORM pg_temp.ad35_ok(jsonb_array_length(j) >= 2 AND j::text LIKE '%RA000475%' AND j::text LIKE '%RA001111%', 'the picker lists the registers of Pakistan');
  PERFORM pg_temp.ad35_ok(desk.registry_pick('pk') = '[]'::jsonb AND desk.registry_pick(NULL) = '[]'::jsonb AND desk.registry_pick('PKX') = '[]'::jsonb, 'the picker takes only a two-letter upper-case code');
  RAISE EXCEPTION 'AD35 selftest passed, rolling back' USING ERRCODE = 'P0AX4';
EXCEPTION WHEN SQLSTATE 'P0AX4' THEN RAISE NOTICE 'AD35 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
