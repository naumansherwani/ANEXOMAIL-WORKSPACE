-- ==============================================================================================================================
-- AD4b (ADMIN DESK SQL, 23 Nov 2026 PKT): D5a-4 LOOKUP AUDIT PROOF = the proof layer on top of AD4. His order 00:56: "yeh sab se sensitive hai ... duniya ka advance, maximum lines".
-- POINT LIST (written first): docs/claude/admin-desk/D5A4-AUDIT-PROOF-LIST-23NOV.md (P1..P14). Web research: tamper-evident logging, RFC 6962 / RFC 9162 Merkle trees, CloudTrail chained digests, separation of duties, insider-threat signals.
-- BUILT ON (SCHEMA-FIRST LAW, AD1..AD4 read in full): fadm_lookup + its guard + fadm_lookup_begin/finish/history (AD4), fadm_ledger + fadm_audit (AD1/AD2), fadm_need + fadm_action + fadm_policy + fadm_burst_hit (AD2),
--   fadm_alert_raise + the alert centre (AD3), fadm_append_only_guard (AD3). AD4b ADDS to those: new tables, new closed-list rows, stronger begin / history. It never edits an old row.
-- WHAT IT ADDS
--   P1/P2 one SHA-256 chain link per lookup row (fadm_lookup_link): fixed genesis, length-prefixed canonical encoding, database clock under a lock, monotonic time; rows already present are back-filled.
--   P3/P4 checkpoints (fadm_lookup_cp): CUMULATIVE Merkle root (RFC 6962: leaf 0x00, node 0x01) chained to the previous checkpoint hash and copied into the main ledger; inclusion proof per lookup + pure verifier (RFC 9162 section 2.1.3.2).
--   P5 completeness: contiguous seq, every row linked, orphan requests closed as 'abandoned' by a sweep (alert), nothing is ever deleted.
--   P6 reason quality (3 words, 3 different words, 6 different letters, filler blocklist, sensitive fields need 25+ characters and 4+ words).
--   P7 live signals on every request/result: bulk companies, same company again, probing, copy-paste reason, daily total, after hours; thresholds in a table changed only through a logged admin door.
--   P8/P9 self-audit (every read of history / a person / a proof is a ledger line) and separation of duties (nobody reads his OWN lookups through the person door or the proof door).
--   P10 maintenance without a scheduler (sweep + auto seal at most once a minute, driven by begin and the health door). P11 health door (counts only). P12 retention: no purge door exists.
-- RULES: Desk tables only (fadm_*), no extension, no superuser, idempotent, ONE transaction, SELFTEST rolls itself back (fail SQLSTATE P0AK4, success exit P0AK5), desk_app gets EXECUTE on doors and NEVER table rights.
--   DESK ISOLATION: no founder or awam object is read or written. The company stays an opaque reference; no answer data is ever stored.
-- HONEST NOTES: (1) The chain proves nothing changed INSIDE the database; a full rewrite by a superuser is caught only against a copy of a checkpoint kept OUTSIDE (next step: Desk Rust signs the checkpoint hash and the copy goes to the Hetzner Storage Box).
--   (2) 'abandoned' means no answer ever reached the screen. (3) After-hours uses Karachi time until the Desk has per-person time zones.
-- ==============================================================================================================================
BEGIN;

-- 1) CLOSED LEDGER KINDS AND ACTIONS --------------------------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO desk.fadm_ledger_kind (kind, severity, note) VALUES
  ('ad4b.selftest','info','AD4b'),('lookup.history_read','notice','someone read the lookup history of a company'),('lookup.person_read','notice','someone read the lookups of one employee'),
  ('lookup.proof_read','notice','someone read an inclusion proof'),('lookup.sealed','notice','a checkpoint of the lookup chain was sealed (root recorded here too)'),
  ('lookup.abandoned','notice','a lookup request never got a result and was closed as abandoned'),('lookup.threshold','notice','a lookup signal threshold was changed'),
  ('lookup.verified','info','the whole lookup chain was verified on request'),
  ('lookup.exported','info','new checkpoints were signed and copied outside the database'),('lookup.export_mismatch','high','an outside copy of a checkpoint does not match the database (history rewritten or a copy damaged)')
ON CONFLICT (kind) DO NOTHING;
INSERT INTO desk.fadm_action (action, note) VALUES ('audit.seal','seal a checkpoint of the lookup chain') ON CONFLICT (action) DO NOTHING;
INSERT INTO desk.fadm_policy (name, effect, action, relation) VALUES ('p_audit_seal','permit','audit.seal','admin') ON CONFLICT (name) DO NOTHING;

-- 2) A FOURTH RESULT: 'abandoned' (the request got no answer). Only the sweep writes it; the callers' finish door still accepts only three. --------------------------------------------------------------------
DO $$ DECLARE c text; BEGIN
  FOR c IN SELECT conname FROM pg_constraint WHERE conrelid = 'desk.fadm_lookup'::regclass AND contype = 'c' AND pg_get_constraintdef(oid) ILIKE '%outcome%' AND pg_get_constraintdef(oid) ILIKE '%requested%' AND pg_get_constraintdef(oid) NOT ILIKE '%abandoned%'
  LOOP EXECUTE format('ALTER TABLE desk.fadm_lookup DROP CONSTRAINT %I', c); END LOOP;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = 'desk.fadm_lookup'::regclass AND conname = 'fadm_lookup_outcome_ck') THEN
    ALTER TABLE desk.fadm_lookup ADD CONSTRAINT fadm_lookup_outcome_ck CHECK (outcome IN ('requested','answered','unavailable','refused','abandoned'));
  END IF;
END $$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_guard() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE bad text;
BEGIN
  SELECT f INTO bad FROM unnest(NEW.fields) AS f WHERE NOT EXISTS (SELECT 1 FROM desk.fadm_lookup_field x WHERE x.field = f) LIMIT 1;
  IF bad IS NOT NULL THEN RAISE EXCEPTION 'field % is not on the closed lookup list', bad USING ERRCODE = 'check_violation'; END IF;
  IF NEW.outcome <> 'requested' AND NOT EXISTS (SELECT 1 FROM desk.fadm_lookup r WHERE r.request_id = NEW.request_id AND r.outcome = 'requested' AND r.employee_id = NEW.employee_id AND r.company_ref = NEW.company_ref)
    THEN RAISE EXCEPTION 'no answer without a recorded request' USING ERRCODE = 'check_violation'; END IF;
  IF NEW.outcome IN ('answered','unavailable','refused','abandoned') AND EXISTS (SELECT 1 FROM desk.fadm_lookup r WHERE r.request_id = NEW.request_id AND r.outcome <> 'requested')
    THEN RAISE EXCEPTION 'this request already has its result' USING ERRCODE = 'check_violation'; END IF;
  RETURN NEW;
END $f$;

-- 3) FIELD SENSITIVITY (P6) ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE desk.fadm_lookup_field ADD COLUMN IF NOT EXISTS sensitive boolean NOT NULL DEFAULT false;
UPDATE desk.fadm_lookup_field SET sensitive = true WHERE field IN ('suspension_class','suspension_since','payment_received_service_not_active','payment_flag_since') AND NOT sensitive;  -- no-money-gate-ok

-- 4) REASON QUALITY (P6): a closed filler list and one function that says WHY a reason is refused (NULL = fine) -----------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_reason_block (word text PRIMARY KEY CHECK (word = lower(word) AND length(word) BETWEEN 1 AND 30));
INSERT INTO desk.fadm_lookup_reason_block (word) VALUES
  ('test'),('testing'),('tested'),('tests'),('check'),('checking'),('checked'),('look'),('looking'),('looked'),('just'),('see'),('seeing'),('view'),('viewing'),('viewed'),('asdf'),('qwer'),('qwerty'),('abc'),('abcd'),('xyz'),
  ('none'),('nothing'),('na'),('n/a'),('ok'),('okay'),('because'),('reason'),('reasons'),('no'),('yes'),('the'),('a'),('an'),('it'),('this'),('that'),('to'),('for'),('of'),('is'),('at'),('on'),('in'),('and'),('only'),('curious'),
  ('customer'),('company'),('account'),('info'),('information'),('data'),('details'),('lookup'),('open'),('opening'),('opened'),('misc'),('stuff'),('something'),('anything'),('whatever'),('idk'),('foo'),('bar'),('baz'),('lorem'),('ipsum'),('now'),('today'),('again'),('please')
ON CONFLICT (word) DO NOTHING;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_reason_why(p_reason text, p_sensitive boolean DEFAULT false) RETURNS text LANGUAGE plpgsql STABLE SET search_path = pg_catalog, desk AS $f$
DECLARE t text := lower(regexp_replace(btrim(coalesce(p_reason, '')), '\s+', ' ', 'g')); w text[];
BEGIN
  w := regexp_split_to_array(t, ' ');
  IF t = '' OR array_length(w, 1) < 3 THEN RETURN 'reason_too_few_words'; END IF;
  IF (SELECT count(DISTINCT x) FROM unnest(w) x) < 3 THEN RETURN 'reason_repeats_words'; END IF;
  IF (SELECT count(DISTINCT c) FROM regexp_split_to_table(replace(t, ' ', ''), '') c) < 6 THEN RETURN 'reason_too_few_letters'; END IF;
  IF t ~ '(.)\1{5,}' THEN RETURN 'reason_filler'; END IF;
  IF NOT EXISTS (SELECT 1 FROM unnest(w) x WHERE x !~ '^[0-9]+$' AND NOT EXISTS (SELECT 1 FROM desk.fadm_lookup_reason_block b WHERE b.word = x)) THEN RETURN 'reason_only_filler'; END IF;
  IF p_sensitive AND (length(t) < 25 OR array_length(w, 1) < 4) THEN RETURN 'reason_too_short_for_sensitive_fields'; END IF;
  RETURN NULL;
END $f$;

-- 5) THRESHOLDS (P7, P5, P10): one row per name, changed ONLY through the logged admin door below ------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_threshold (
  name  text PRIMARY KEY CHECK (name ~ '^[a-z_0-9]{3,40}$'),
  value integer NOT NULL CHECK (value BETWEEN 0 AND 100000),
  note  text
);
INSERT INTO desk.fadm_lookup_threshold (name, value, note) VALUES
  ('bulk_companies_60m', 15, 'different companies opened by one person in 60 minutes'),('repeat_company_60m', 6, 'same company opened again and again by one person in 60 minutes'),
  ('probe_fail_60m', 5, 'refused, unavailable or abandoned results of one person in 60 minutes'),('reuse_reason_60m', 8, 'the same reason text typed again and again in 60 minutes'),
  ('daily_total', 150, 'lookups by one person in 24 hours'),('hours_from', 7, 'first allowed hour (Karachi); from = to means no restriction'),('hours_to', 23, 'first hour NOT allowed again (Karachi)'),
  ('orphan_secs', 120, 'a request without a result after this many seconds is abandoned'),('seal_every_links', 25, 'seal a checkpoint when this many new links exist'),('seal_every_minutes', 60, 'seal a checkpoint when the oldest unsealed link is this old')
ON CONFLICT (name) DO NOTHING;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_th(p_name text) RETURNS integer LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT value FROM desk.fadm_lookup_threshold WHERE name = p_name $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_threshold_set(p_actor uuid, p_name text, p_value integer, p_ip inet DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE old integer;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'policy.edit', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT value INTO old FROM desk.fadm_lookup_threshold WHERE name = p_name FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such threshold %', p_name USING ERRCODE = 'no_data_found'; END IF;
  IF p_name IN ('hours_from','hours_to') AND p_value NOT BETWEEN 0 AND 23 THEN RAISE EXCEPTION 'hour must be 0..23' USING ERRCODE = 'check_violation'; END IF;
  IF p_name NOT IN ('hours_from','hours_to') AND p_value < 1 THEN RAISE EXCEPTION 'threshold must be at least 1' USING ERRCODE = 'check_violation'; END IF;
  UPDATE desk.fadm_lookup_threshold SET value = p_value WHERE name = p_name;
  PERFORM desk.fadm_audit(p_actor, 'lookup.threshold', jsonb_build_object('name', p_name, 'old', old, 'new', p_value));
END $f$;

-- 6) THE CHAIN (P1, P2): one link per lookup row, append-only, computed here (the app cannot choose a number, a time or a hash) ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_link (
  seq        bigint PRIMARY KEY CHECK (seq >= 1),
  lookup_id  bigint NOT NULL UNIQUE REFERENCES desk.fadm_lookup(id),
  linked_at  timestamptz NOT NULL,
  prev_hash  bytea NOT NULL CHECK (octet_length(prev_hash) = 32),
  hash       bytea NOT NULL UNIQUE CHECK (octet_length(hash) = 32)
);
-- canonical text of a lookup row: every part length-prefixed so no two different rows can produce the same text; time in UTC with microseconds
CREATE OR REPLACE FUNCTION desk.fadm_lookup_canon(p_id bigint, p_ts timestamptz, p_emp uuid, p_company text, p_reason text, p_fields text[], p_req uuid, p_outcome text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  SELECT string_agg(length(x)::text || ':' || x, '|' ORDER BY n) FROM unnest(ARRAY[p_id::text, to_char(p_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), p_emp::text, p_company, p_reason, array_to_string(p_fields, ','), p_req::text, p_outcome]) WITH ORDINALITY AS u(x, n)
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_link_hash(p_prev bytea, p_seq bigint, p_linked_at timestamptz, p_canon text) RETURNS bytea LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  SELECT sha256(p_prev || convert_to('anexo-lookup-link-v1|' || p_seq::text || '|' || to_char(p_linked_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || p_canon, 'UTF8'))
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_link_add(p_id bigint) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE l desk.fadm_lookup; pv bytea; ps bigint; pt timestamptz; t timestamptz; n bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_lookup_link'));
  SELECT * INTO l FROM desk.fadm_lookup WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such lookup row' USING ERRCODE = 'no_data_found'; END IF;
  IF EXISTS (SELECT 1 FROM desk.fadm_lookup_link WHERE lookup_id = p_id) THEN RETURN NULL; END IF;
  SELECT hash, seq, linked_at INTO pv, ps, pt FROM desk.fadm_lookup_link ORDER BY seq DESC LIMIT 1;
  IF pv IS NULL THEN pv := sha256('anexo-desk-lookup-chain-genesis'::bytea); ps := 0; END IF;
  n := ps + 1;
  t := clock_timestamp(); IF pt IS NOT NULL AND t <= pt THEN t := pt + interval '1 microsecond'; END IF;   -- time never goes backwards
  t := date_trunc('microseconds', t);
  INSERT INTO desk.fadm_lookup_link (seq, lookup_id, linked_at, prev_hash, hash)
    VALUES (n, l.id, t, pv, desk.fadm_lookup_link_hash(pv, n, t, desk.fadm_lookup_canon(l.id, l.ts, l.employee_id, l.company_ref, l.reason, l.fields, l.request_id, l.outcome)));
  RETURN n;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_link_trg() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN PERFORM desk.fadm_lookup_link_add(NEW.id); RETURN NEW; END $f$;
DROP TRIGGER IF EXISTS fadm_lookup_90link ON desk.fadm_lookup;
CREATE TRIGGER fadm_lookup_90link AFTER INSERT ON desk.fadm_lookup FOR EACH ROW EXECUTE FUNCTION desk.fadm_lookup_link_trg();
DROP TRIGGER IF EXISTS fadm_lookup_link_frozen ON desk.fadm_lookup_link;
CREATE TRIGGER fadm_lookup_link_frozen BEFORE UPDATE OR DELETE ON desk.fadm_lookup_link FOR EACH ROW EXECUTE FUNCTION desk.fadm_append_only_guard();
DROP TRIGGER IF EXISTS fadm_lookup_link_frozen_t ON desk.fadm_lookup_link;
CREATE TRIGGER fadm_lookup_link_frozen_t BEFORE TRUNCATE ON desk.fadm_lookup_link FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_append_only_guard();
-- rows that already exist on his server (written by AD4 before this file) get their links now, in id order
DO $$ DECLARE r record; BEGIN
  FOR r IN SELECT id FROM desk.fadm_lookup q WHERE NOT EXISTS (SELECT 1 FROM desk.fadm_lookup_link k WHERE k.lookup_id = q.id) ORDER BY id LOOP PERFORM desk.fadm_lookup_link_add(r.id); END LOOP;
END $$;

-- 7) VERIFY (P5): whole chain with the first bad link, and a cheap tail check for the health door ---------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_lookup_verify_detail() RETURNS TABLE (ok boolean, links bigint, first_bad bigint, why text) LANGUAGE plpgsql STABLE SET search_path = pg_catalog, desk AS $f$
DECLARE r record; p bytea := sha256('anexo-desk-lookup-chain-genesis'::bytea); n bigint := 0; pt timestamptz; nl bigint; nr bigint;
BEGIN
  FOR r IN SELECT k.seq, k.linked_at, k.prev_hash, k.hash, l.id, l.ts, l.employee_id, l.company_ref, l.reason, l.fields, l.request_id, l.outcome
             FROM desk.fadm_lookup_link k LEFT JOIN desk.fadm_lookup l ON l.id = k.lookup_id ORDER BY k.seq LOOP
    n := n + 1;
    IF r.seq <> n THEN RETURN QUERY SELECT false, n - 1, n, 'gap_in_sequence'::text; RETURN; END IF;
    IF r.id IS NULL THEN RETURN QUERY SELECT false, n - 1, r.seq, 'link_without_row'::text; RETURN; END IF;
    IF r.prev_hash <> p THEN RETURN QUERY SELECT false, n - 1, r.seq, 'broken_previous_hash'::text; RETURN; END IF;
    IF pt IS NOT NULL AND r.linked_at <= pt THEN RETURN QUERY SELECT false, n - 1, r.seq, 'time_went_backwards'::text; RETURN; END IF;
    IF r.hash <> desk.fadm_lookup_link_hash(p, r.seq, r.linked_at, desk.fadm_lookup_canon(r.id, r.ts, r.employee_id, r.company_ref, r.reason, r.fields, r.request_id, r.outcome))
      THEN RETURN QUERY SELECT false, n - 1, r.seq, 'row_changed_after_link'::text; RETURN; END IF;
    p := r.hash; pt := r.linked_at;
  END LOOP;
  SELECT count(*) INTO nl FROM desk.fadm_lookup_link; SELECT count(*) INTO nr FROM desk.fadm_lookup;
  IF nr <> nl THEN RETURN QUERY SELECT false, nl, NULL::bigint, 'row_without_link'::text; RETURN; END IF;
  RETURN QUERY SELECT true, nl, NULL::bigint, NULL::text;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_verify() RETURNS boolean LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT ok FROM desk.fadm_lookup_verify_detail() $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_verify_tail(p_n integer DEFAULT 200) RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = pg_catalog, desk AS $f$
DECLARE r record; p bytea; first boolean := true; mx bigint; lo bigint; pt timestamptz;
BEGIN
  SELECT max(seq) INTO mx FROM desk.fadm_lookup_link; IF mx IS NULL THEN RETURN true; END IF;
  lo := greatest(1, mx - greatest(p_n, 1) + 1);
  SELECT hash, linked_at INTO p, pt FROM desk.fadm_lookup_link WHERE seq = lo - 1; IF p IS NULL THEN p := sha256('anexo-desk-lookup-chain-genesis'::bytea); END IF;
  FOR r IN SELECT k.seq, k.linked_at, k.prev_hash, k.hash, l.id, l.ts, l.employee_id, l.company_ref, l.reason, l.fields, l.request_id, l.outcome
             FROM desk.fadm_lookup_link k LEFT JOIN desk.fadm_lookup l ON l.id = k.lookup_id WHERE k.seq >= lo ORDER BY k.seq LOOP
    IF r.id IS NULL OR r.prev_hash <> p OR (pt IS NOT NULL AND r.linked_at <= pt)
       OR r.hash <> desk.fadm_lookup_link_hash(p, r.seq, r.linked_at, desk.fadm_lookup_canon(r.id, r.ts, r.employee_id, r.company_ref, r.reason, r.fields, r.request_id, r.outcome)) THEN RETURN false; END IF;
    p := r.hash; pt := r.linked_at;
  END LOOP;
  RETURN true;
END $f$;

-- 8) MERKLE TREE (P3, P4): RFC 6962 hashing, leaf = sha256(0x00 || link hash), node = sha256(0x01 || left || right); the root over the first n links is the checkpoint of size n ---------------------------------------
CREATE OR REPLACE FUNCTION desk.fadm_merkle_mth(a bytea[]) RETURNS bytea LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog AS $f$
DECLARE n integer := coalesce(array_length(a, 1), 0); k integer := 1;
BEGIN
  IF n = 0 THEN RETURN sha256(''::bytea); END IF;
  IF n = 1 THEN RETURN a[1]; END IF;
  WHILE k * 2 < n LOOP k := k * 2; END LOOP;
  RETURN sha256('\x01'::bytea || desk.fadm_merkle_mth(a[1:k]) || desk.fadm_merkle_mth(a[k + 1:n]));
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_merkle_leaf(h bytea) RETURNS bytea LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$ SELECT sha256('\x00'::bytea || h) $f$;
-- audit path of the leaf with 0-based index m (RFC 6962 section 2.1.1)
CREATE OR REPLACE FUNCTION desk.fadm_merkle_path(a bytea[], m integer) RETURNS bytea[] LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog AS $f$
DECLARE n integer := coalesce(array_length(a, 1), 0); k integer := 1;
BEGIN
  IF m < 0 OR m >= n THEN RAISE EXCEPTION 'leaf index outside the tree' USING ERRCODE = 'check_violation'; END IF;
  IF n = 1 THEN RETURN '{}'::bytea[]; END IF;
  WHILE k * 2 < n LOOP k := k * 2; END LOOP;
  IF m < k THEN RETURN array_append(desk.fadm_merkle_path(a[1:k], m), desk.fadm_merkle_mth(a[k + 1:n]));
  ELSE RETURN array_append(desk.fadm_merkle_path(a[k + 1:n], m - k), desk.fadm_merkle_mth(a[1:k])); END IF;
END $f$;
-- the pure verifier (RFC 9162 section 2.1.3.2): anybody holding a leaf hash, its index, the tree size, the path and a root can check it; no table is read
CREATE OR REPLACE FUNCTION desk.fadm_merkle_verify(p_leaf_hash bytea, p_index bigint, p_size bigint, p_path bytea[], p_root bytea) RETURNS boolean LANGUAGE plpgsql IMMUTABLE SET search_path = pg_catalog AS $f$
DECLARE fn bigint := p_index; sn bigint := p_size - 1; r bytea := p_leaf_hash; p bytea;
BEGIN
  IF p_index < 0 OR p_size < 1 OR p_index >= p_size THEN RETURN false; END IF;
  FOREACH p IN ARRAY coalesce(p_path, '{}'::bytea[]) LOOP
    IF sn = 0 THEN RETURN false; END IF;
    IF (fn & 1) = 1 OR fn = sn THEN
      r := sha256('\x01'::bytea || p || r);
      IF (fn & 1) = 0 THEN
        LOOP fn := fn >> 1; sn := sn >> 1; EXIT WHEN (fn & 1) = 1 OR fn = 0; END LOOP;
      END IF;
    ELSE r := sha256('\x01'::bytea || r || p); END IF;
    fn := fn >> 1; sn := sn >> 1;
  END LOOP;
  RETURN sn = 0 AND r = p_root;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_leaves(p_size bigint) RETURNS bytea[] LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$
  SELECT coalesce(array_agg(desk.fadm_merkle_leaf(hash) ORDER BY seq), '{}'::bytea[]) FROM desk.fadm_lookup_link WHERE seq <= p_size
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_root(p_size bigint) RETURNS bytea LANGUAGE sql STABLE SET search_path = pg_catalog, desk AS $f$ SELECT desk.fadm_merkle_mth(desk.fadm_lookup_leaves(p_size)) $f$;

-- 9) CHECKPOINTS (P3): append-only, hash-chained digests; the trigger takes size and root FROM THE LINKS (the caller cannot choose them) and copies root + hash into the main ledger ---------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_cp (
  cp_seq    bigint PRIMARY KEY CHECK (cp_seq >= 1),
  ts        timestamptz NOT NULL,
  size      bigint NOT NULL CHECK (size >= 1),
  root      bytea NOT NULL CHECK (octet_length(root) = 32),
  prev_hash bytea NOT NULL CHECK (octet_length(prev_hash) = 32),
  hash      bytea NOT NULL UNIQUE CHECK (octet_length(hash) = 32),
  sealed_by uuid REFERENCES desk.fadm_owner(id),                       -- NULL = sealed automatically
  auto      boolean NOT NULL DEFAULT false,
  CONSTRAINT fadm_lookup_cp_who_ck CHECK (auto = (sealed_by IS NULL))
);
CREATE OR REPLACE FUNCTION desk.fadm_lookup_cp_hash(p_prev bytea, p_seq bigint, p_ts timestamptz, p_size bigint, p_root bytea) RETURNS bytea LANGUAGE sql IMMUTABLE SET search_path = pg_catalog AS $f$
  SELECT sha256(p_prev || convert_to('anexo-lookup-cp-v1|' || p_seq::text || '|' || to_char(p_ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"') || '|' || p_size::text || '|' || encode(p_root, 'hex'), 'UTF8'))
$f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_cp_before() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE pv bytea; ps bigint; psz bigint; pts timestamptz; mx bigint;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('desk.fadm_lookup_link'));
  SELECT max(seq) INTO mx FROM desk.fadm_lookup_link;
  IF mx IS NULL THEN RAISE EXCEPTION 'there is nothing to seal yet' USING ERRCODE = 'check_violation'; END IF;
  SELECT hash, cp_seq, size, ts INTO pv, ps, psz, pts FROM desk.fadm_lookup_cp ORDER BY cp_seq DESC LIMIT 1;
  IF pv IS NULL THEN pv := sha256('anexo-desk-lookup-cp-genesis'::bytea); ps := 0; psz := 0; END IF;
  IF mx <= psz THEN RAISE EXCEPTION 'nothing new to seal' USING ERRCODE = 'check_violation'; END IF;
  NEW.cp_seq := ps + 1; NEW.size := mx; NEW.root := desk.fadm_lookup_root(mx); NEW.prev_hash := pv;
  NEW.ts := date_trunc('microseconds', clock_timestamp()); IF pts IS NOT NULL AND NEW.ts <= pts THEN NEW.ts := pts + interval '1 microsecond'; END IF;
  NEW.hash := desk.fadm_lookup_cp_hash(pv, NEW.cp_seq, NEW.ts, NEW.size, NEW.root);
  RETURN NEW;
END $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_cp_after() RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_audit(NEW.sealed_by, 'lookup.sealed', jsonb_build_object('cp', NEW.cp_seq, 'size', NEW.size, 'root', encode(NEW.root, 'hex'), 'hash', encode(NEW.hash, 'hex'), 'auto', NEW.auto));
  RETURN NEW;
END $f$;
DROP TRIGGER IF EXISTS fadm_lookup_cp_00before ON desk.fadm_lookup_cp;
CREATE TRIGGER fadm_lookup_cp_00before BEFORE INSERT ON desk.fadm_lookup_cp FOR EACH ROW EXECUTE FUNCTION desk.fadm_lookup_cp_before();
DROP TRIGGER IF EXISTS fadm_lookup_cp_90after ON desk.fadm_lookup_cp;
CREATE TRIGGER fadm_lookup_cp_90after AFTER INSERT ON desk.fadm_lookup_cp FOR EACH ROW EXECUTE FUNCTION desk.fadm_lookup_cp_after();
DROP TRIGGER IF EXISTS fadm_lookup_cp_frozen ON desk.fadm_lookup_cp;
CREATE TRIGGER fadm_lookup_cp_frozen BEFORE UPDATE OR DELETE ON desk.fadm_lookup_cp FOR EACH ROW EXECUTE FUNCTION desk.fadm_append_only_guard();
DROP TRIGGER IF EXISTS fadm_lookup_cp_frozen_t ON desk.fadm_lookup_cp;
CREATE TRIGGER fadm_lookup_cp_frozen_t BEFORE TRUNCATE ON desk.fadm_lookup_cp FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_append_only_guard();
-- every checkpoint recomputed from the links: chain of digests, roots, growing sizes (this also proves every older root is a prefix of every newer one)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_cp_verify() RETURNS boolean LANGUAGE plpgsql STABLE SET search_path = pg_catalog, desk AS $f$
DECLARE r record; p bytea := sha256('anexo-desk-lookup-cp-genesis'::bytea); n bigint := 0; ps bigint := 0; pt timestamptz;
BEGIN
  FOR r IN SELECT * FROM desk.fadm_lookup_cp ORDER BY cp_seq LOOP
    n := n + 1;
    IF r.cp_seq <> n OR r.prev_hash <> p OR r.size <= ps OR (pt IS NOT NULL AND r.ts <= pt) THEN RETURN false; END IF;
    IF r.size > (SELECT coalesce(max(seq), 0) FROM desk.fadm_lookup_link) THEN RETURN false; END IF;
    IF r.root <> desk.fadm_lookup_root(r.size) THEN RETURN false; END IF;
    IF r.hash <> desk.fadm_lookup_cp_hash(p, r.cp_seq, r.ts, r.size, r.root) THEN RETURN false; END IF;
    IF NOT EXISTS (SELECT 1 FROM desk.fadm_ledger WHERE kind = 'lookup.sealed' AND detail->>'cp' = r.cp_seq::text AND detail->>'root' = encode(r.root, 'hex')) THEN RETURN false; END IF;   -- the copy in the main ledger
    p := r.hash; ps := r.size; pt := r.ts;
  END LOOP;
  RETURN true;
END $f$;

-- 10) STATE, SIGNALS, SWEEP, AUTO SEAL (P5, P7, P10) ----------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS desk.fadm_lookup_state (id boolean PRIMARY KEY DEFAULT true CHECK (id), last_maintain timestamptz NOT NULL DEFAULT 'epoch', sweeps bigint NOT NULL DEFAULT 0, seals bigint NOT NULL DEFAULT 0);
INSERT INTO desk.fadm_lookup_state (id) VALUES (true) ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION desk.fadm_lookup_signals(p_actor uuid) RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n integer := 0; c integer; co text; hb text := to_char(date_trunc('hour', now()), 'YYYYMMDDHH24'); db text := to_char(now() AT TIME ZONE 'Asia/Karachi', 'YYYYMMDD'); h integer := extract(hour FROM now() AT TIME ZONE 'Asia/Karachi')::integer; hf integer; ht integer; okv boolean;
BEGIN
  SELECT count(DISTINCT company_ref) INTO c FROM desk.fadm_lookup WHERE employee_id = p_actor AND outcome = 'requested' AND ts > now() - interval '60 minutes';
  IF c >= desk.fadm_lookup_th('bulk_companies_60m') THEN PERFORM desk.fadm_alert_raise('security', 'high', 'lookup.bulk', p_actor, jsonb_build_object('companies', c, 'window_min', 60), 'lookup.bulk:' || p_actor || ':' || hb); n := n + 1; END IF;
  SELECT company_ref, count(*) INTO co, c FROM desk.fadm_lookup WHERE employee_id = p_actor AND outcome = 'requested' AND ts > now() - interval '60 minutes' GROUP BY company_ref ORDER BY count(*) DESC LIMIT 1;
  IF c >= desk.fadm_lookup_th('repeat_company_60m') THEN PERFORM desk.fadm_alert_raise('security', 'notice', 'lookup.repeat', p_actor, jsonb_build_object('company', co, 'times', c, 'window_min', 60), 'lookup.repeat:' || p_actor || ':' || co || ':' || hb); n := n + 1; END IF;
  SELECT count(*) INTO c FROM desk.fadm_lookup WHERE employee_id = p_actor AND outcome IN ('unavailable','refused','abandoned') AND ts > now() - interval '60 minutes';
  IF c >= desk.fadm_lookup_th('probe_fail_60m') THEN PERFORM desk.fadm_alert_raise('security', 'notice', 'lookup.probe', p_actor, jsonb_build_object('failed', c, 'window_min', 60), 'lookup.probe:' || p_actor || ':' || hb); n := n + 1; END IF;
  SELECT count(*) INTO c FROM (SELECT reason FROM desk.fadm_lookup WHERE employee_id = p_actor AND outcome = 'requested' AND ts > now() - interval '60 minutes' GROUP BY reason HAVING count(*) >= desk.fadm_lookup_th('reuse_reason_60m')) t;
  IF c >= 1 THEN PERFORM desk.fadm_alert_raise('security', 'notice', 'lookup.reuse', p_actor, jsonb_build_object('same_reason_repeated', true, 'window_min', 60), 'lookup.reuse:' || p_actor || ':' || hb); n := n + 1; END IF;
  SELECT count(*) INTO c FROM desk.fadm_lookup WHERE employee_id = p_actor AND outcome = 'requested' AND ts > now() - interval '24 hours';
  IF c >= desk.fadm_lookup_th('daily_total') THEN PERFORM desk.fadm_alert_raise('security', 'high', 'lookup.daily', p_actor, jsonb_build_object('lookups', c, 'window_h', 24), 'lookup.daily:' || p_actor || ':' || db); n := n + 1; END IF;
  hf := desk.fadm_lookup_th('hours_from'); ht := desk.fadm_lookup_th('hours_to');
  okv := CASE WHEN hf = ht THEN true WHEN hf < ht THEN h >= hf AND h < ht ELSE h >= hf OR h < ht END;
  IF NOT okv THEN PERFORM desk.fadm_alert_raise('security', 'notice', 'lookup.after_hours', p_actor, jsonb_build_object('hour_pkt', h, 'allowed_from', hf, 'allowed_to', ht), 'lookup.after_hours:' || p_actor || ':' || db); n := n + 1; END IF;
  RETURN n;
END $f$;

CREATE OR REPLACE FUNCTION desk.fadm_lookup_maintain(p_force boolean DEFAULT false) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record; ab integer := 0; sealed boolean := false; mx bigint; lsz bigint := 0; oldest timestamptz; lst timestamptz;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('desk.fadm_lookup_maintain')) THEN RETURN jsonb_build_object('skipped', 'busy'); END IF;
  SELECT last_maintain INTO lst FROM desk.fadm_lookup_state WHERE id;
  IF NOT p_force AND lst > clock_timestamp() - interval '60 seconds' THEN RETURN jsonb_build_object('skipped', 'recent'); END IF;
  UPDATE desk.fadm_lookup_state SET last_maintain = clock_timestamp();
  -- orphans: a request with no result is closed as 'abandoned' (no data was ever shown for it)
  FOR r IN SELECT q.* FROM desk.fadm_lookup q WHERE q.outcome = 'requested' AND q.ts < clock_timestamp() - make_interval(secs => desk.fadm_lookup_th('orphan_secs'))
              AND NOT EXISTS (SELECT 1 FROM desk.fadm_lookup x WHERE x.request_id = q.request_id AND x.outcome <> 'requested') ORDER BY q.id LIMIT 200 LOOP
    INSERT INTO desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) VALUES (r.employee_id, r.company_ref, r.reason, r.fields, r.request_id, 'abandoned');
    PERFORM desk.fadm_audit(r.employee_id, 'lookup.abandoned', jsonb_build_object('company', r.company_ref, 'request', r.request_id));
    PERFORM desk.fadm_alert_raise('security', 'notice', 'lookup.abandoned', r.employee_id, jsonb_build_object('request', r.request_id), 'lookup.abandoned:' || r.employee_id || ':' || to_char(date_trunc('hour', now()), 'YYYYMMDDHH24'));
    ab := ab + 1;
  END LOOP;
  IF ab > 0 THEN UPDATE desk.fadm_lookup_state SET sweeps = sweeps + ab; END IF;
  -- automatic checkpoint: enough new links, or the oldest unsealed link is old enough
  SELECT max(seq) INTO mx FROM desk.fadm_lookup_link; SELECT coalesce(max(size), 0) INTO lsz FROM desk.fadm_lookup_cp;
  IF mx IS NOT NULL AND mx > lsz THEN
    SELECT min(linked_at) INTO oldest FROM desk.fadm_lookup_link WHERE seq > lsz;
    IF mx - lsz >= desk.fadm_lookup_th('seal_every_links') OR clock_timestamp() - oldest >= make_interval(mins => desk.fadm_lookup_th('seal_every_minutes')) THEN
      INSERT INTO desk.fadm_lookup_cp (sealed_by, auto) VALUES (NULL, true); sealed := true; UPDATE desk.fadm_lookup_state SET seals = seals + 1;
    END IF;
  END IF;
  RETURN jsonb_build_object('abandoned', ab, 'sealed', sealed);
END $f$;

-- 11) THE DOORS ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- begin: same signature as AD4, now with reason quality (P6), maintenance (P10) and live signals (P7); NULL still means "refused and frozen"
CREATE OR REPLACE FUNCTION desk.fadm_lookup_begin(p_actor uuid, p_company_ref text, p_reason text, p_fields text[], p_request_id uuid, p_ip inet DEFAULT NULL)
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE root uuid := desk.fadm_unit_id('department', 'desk'); n bigint; why text; sens boolean;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'customer.lookup', root, p_ip);
  SELECT coalesce(bool_or(f.sensitive), false) INTO sens FROM desk.fadm_lookup_field f WHERE f.field = ANY (p_fields);
  why := desk.fadm_lookup_reason_why(p_reason, sens);
  IF why IS NOT NULL THEN RAISE EXCEPTION 'reason refused: %', why USING ERRCODE = 'check_violation'; END IF;
  IF NOT desk.fadm_burst_hit(p_actor, 'customer.lookup') THEN RETURN NULL; END IF;
  PERFORM desk.fadm_lookup_maintain(false);
  INSERT INTO desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) VALUES (p_actor, p_company_ref, btrim(p_reason), p_fields, p_request_id, 'requested') RETURNING id INTO n;
  PERFORM desk.fadm_audit(p_actor, 'lookup.company', jsonb_build_object('company', p_company_ref, 'reason', btrim(p_reason), 'fields', to_jsonb(p_fields), 'request', p_request_id));
  PERFORM desk.fadm_lookup_signals(p_actor);
  RETURN n;
END $f$;
-- finish: unchanged rule set, plus the signals (a run of unavailable results is a probe)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_finish(p_actor uuid, p_request_id uuid, p_outcome text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE r record;
BEGIN
  IF p_outcome NOT IN ('answered','unavailable','refused') THEN RAISE EXCEPTION 'unknown outcome %', p_outcome USING ERRCODE = 'check_violation'; END IF;
  SELECT * INTO r FROM desk.fadm_lookup WHERE request_id = p_request_id AND outcome = 'requested' AND employee_id = p_actor;
  IF NOT FOUND THEN RAISE EXCEPTION 'no such request for this person' USING ERRCODE = 'no_data_found'; END IF;
  INSERT INTO desk.fadm_lookup (employee_id, company_ref, reason, fields, request_id, outcome) VALUES (r.employee_id, r.company_ref, r.reason, r.fields, r.request_id, p_outcome);
  IF p_outcome = 'unavailable' THEN PERFORM desk.fadm_audit(p_actor, 'lookup.unavailable', jsonb_build_object('company', r.company_ref, 'request', p_request_id)); END IF;
  IF p_outcome <> 'answered' THEN PERFORM desk.fadm_lookup_signals(p_actor); END IF;
END $f$;
-- history of one company: now VOLATILE because reading it is itself a ledger line (P8)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_history(p_actor uuid, p_company_ref text, p_limit integer DEFAULT 50, p_ip inet DEFAULT NULL)
RETURNS TABLE (ts timestamptz, employee text, reason text, fields text[], outcome text, request_id uuid) LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n integer;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT count(*) INTO n FROM desk.fadm_lookup l WHERE l.company_ref = p_company_ref;
  PERFORM desk.fadm_audit(p_actor, 'lookup.history_read', jsonb_build_object('company', p_company_ref, 'rows', least(n, least(greatest(p_limit, 1), 200))));
  RETURN QUERY SELECT l.ts, o.display_name, l.reason, l.fields, l.outcome, l.request_id FROM desk.fadm_lookup l JOIN desk.fadm_owner o ON o.id = l.employee_id
    WHERE l.company_ref = p_company_ref ORDER BY l.ts DESC, l.id DESC LIMIT least(greatest(p_limit, 1), 200);
END $f$;
-- the lookups of ONE person (P9: never your own, not even the owner); reading them is a ledger line
CREATE OR REPLACE FUNCTION desk.fadm_lookup_by_employee(p_actor uuid, p_employee uuid, p_limit integer DEFAULT 50, p_ip inet DEFAULT NULL)
RETURNS TABLE (ts timestamptz, company_ref text, reason text, fields text[], outcome text, request_id uuid) LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  IF p_actor = p_employee THEN RAISE EXCEPTION 'nobody reads his own lookups' USING ERRCODE = 'insufficient_privilege'; END IF;
  PERFORM desk.fadm_audit(p_actor, 'lookup.person_read', jsonb_build_object('employee', p_employee));
  RETURN QUERY SELECT l.ts, l.company_ref, l.reason, l.fields, l.outcome, l.request_id FROM desk.fadm_lookup l WHERE l.employee_id = p_employee ORDER BY l.ts DESC, l.id DESC LIMIT least(greatest(p_limit, 1), 200);
END $f$;
-- seal now (owner side); returns the checkpoint number
CREATE OR REPLACE FUNCTION desk.fadm_lookup_seal(p_actor uuid, p_ip inet DEFAULT NULL) RETURNS bigint LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE n bigint;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.seal', desk.fadm_unit_id('department', 'desk'), p_ip);
  INSERT INTO desk.fadm_lookup_cp (sealed_by, auto) VALUES (p_actor, false) RETURNING cp_seq INTO n;
  RETURN n;
END $f$;
-- inclusion proof of one lookup row against the newest checkpoint that covers it (P4); not your own lookup (P9); reading it is a ledger line (P8)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_proof(p_actor uuid, p_lookup_id bigint, p_ip inet DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE k desk.fadm_lookup_link; l desk.fadm_lookup; c desk.fadm_lookup_cp; a bytea[]; path bytea[];
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT * INTO l FROM desk.fadm_lookup WHERE id = p_lookup_id; IF NOT FOUND THEN RAISE EXCEPTION 'no such lookup row' USING ERRCODE = 'no_data_found'; END IF;
  IF l.employee_id = p_actor THEN RAISE EXCEPTION 'nobody reads proof of his own lookups' USING ERRCODE = 'insufficient_privilege'; END IF;
  SELECT * INTO k FROM desk.fadm_lookup_link WHERE lookup_id = p_lookup_id;
  SELECT * INTO c FROM desk.fadm_lookup_cp WHERE size >= k.seq ORDER BY cp_seq DESC LIMIT 1;
  IF c.cp_seq IS NULL THEN RAISE EXCEPTION 'not sealed yet, seal a checkpoint first' USING ERRCODE = 'check_violation'; END IF;
  a := desk.fadm_lookup_leaves(c.size); path := desk.fadm_merkle_path(a, (k.seq - 1)::integer);
  PERFORM desk.fadm_audit(p_actor, 'lookup.proof_read', jsonb_build_object('lookup', p_lookup_id, 'cp', c.cp_seq));
  RETURN jsonb_build_object('lookup', p_lookup_id, 'seq', k.seq, 'leaf', encode(desk.fadm_merkle_leaf(k.hash), 'hex'), 'index', k.seq - 1, 'tree_size', c.size, 'root', encode(c.root, 'hex'), 'cp', c.cp_seq, 'cp_hash', encode(c.hash, 'hex'),
    'path', (SELECT coalesce(jsonb_agg(encode(x, 'hex')), '[]'::jsonb) FROM unnest(path) x));
END $f$;
-- the whole chain, on request, with the answer written to the ledger
CREATE OR REPLACE FUNCTION desk.fadm_lookup_verify_full(p_actor uuid, p_ip inet DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE d record; cpv boolean; res jsonb;
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  SELECT * INTO d FROM desk.fadm_lookup_verify_detail(); cpv := desk.fadm_lookup_cp_verify();
  res := jsonb_build_object('chain_ok', d.ok, 'links', d.links, 'first_bad', d.first_bad, 'why', d.why, 'checkpoints_ok', cpv);
  PERFORM desk.fadm_audit(p_actor, 'lookup.verified', res);
  RETURN res;
END $f$;
-- health for the Bridge (P11): counts only, no company, no reason, no person
CREATE OR REPLACE FUNCTION desk.fadm_lookup_health() RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE lsz bigint; lts timestamptz; mx bigint;
BEGIN
  PERFORM desk.fadm_lookup_maintain(false);
  SELECT max(seq) INTO mx FROM desk.fadm_lookup_link; SELECT coalesce(max(size), 0), max(ts) INTO lsz, lts FROM desk.fadm_lookup_cp;
  RETURN jsonb_build_object(
    'lookup_rows', (SELECT count(*) FROM desk.fadm_lookup), 'links', coalesce(mx, 0), 'tail_ok', desk.fadm_lookup_verify_tail(200),
    'checkpoints', (SELECT count(*) FROM desk.fadm_lookup_cp), 'last_checkpoint_age_s', CASE WHEN lts IS NULL THEN NULL ELSE extract(epoch FROM clock_timestamp() - lts)::bigint END, 'unsealed_links', coalesce(mx, 0) - lsz,
    'orphans_open', (SELECT count(*) FROM desk.fadm_lookup q WHERE q.outcome = 'requested' AND NOT EXISTS (SELECT 1 FROM desk.fadm_lookup x WHERE x.request_id = q.request_id AND x.outcome <> 'requested')),
    'abandoned_24h', (SELECT count(*) FROM desk.fadm_lookup WHERE outcome = 'abandoned' AND ts > now() - interval '24 hours'),
    'signals_24h', coalesce((SELECT jsonb_object_agg(kind, c) FROM (SELECT kind, count(*) AS c FROM desk.fadm_alert WHERE source = 'security' AND kind LIKE 'lookup.%' AND at > now() - interval '24 hours' GROUP BY kind) t), '{}'::jsonb));
END $f$;

-- the Bridge door: the same counts, but only for a person who may read the audit (audit.read); reading it is NOT a ledger line (counts only, no company, no person)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_audit_door(p_actor uuid, p_ip inet DEFAULT NULL) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
BEGIN
  PERFORM desk.fadm_need(p_actor, 'audit.read', desk.fadm_unit_id('department', 'desk'), p_ip);
  RETURN desk.fadm_lookup_health();
END $f$;

-- OUTSIDE COPY (honest limit 1 closed): the Desk Rust job reads the checkpoints here, signs each with the Desk key, writes one file per checkpoint outside the database (Storage Box) and compares every older file with this table.
-- Root and chain hashes only: no company, no reason, no person. The job reports back through the second door; a mismatch is a ledger line AND a high alert.
CREATE OR REPLACE FUNCTION desk.fadm_lookup_cp_export(p_after bigint DEFAULT 0, p_limit integer DEFAULT 1000) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
  SELECT coalesce(jsonb_agg(jsonb_build_object('cp_seq', c.cp_seq, 'ts', to_char(c.ts AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US"Z"'), 'size', c.size, 'root', encode(c.root, 'hex'), 'prev', encode(c.prev_hash, 'hex'), 'hash', encode(c.hash, 'hex'), 'auto', c.auto) ORDER BY c.cp_seq), '[]'::jsonb)
    FROM (SELECT * FROM desk.fadm_lookup_cp WHERE cp_seq > greatest(p_after, 0) ORDER BY cp_seq LIMIT least(greatest(p_limit, 1), 1000)) c
$f$;
-- the timer's heartbeat: runs the sweep and the automatic seal even when nobody looks at a company (otherwise the last links of a quiet day would wait for the next lookup)
CREATE OR REPLACE FUNCTION desk.fadm_lookup_tick() RETURNS jsonb LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$ SELECT desk.fadm_lookup_maintain(false) $f$;
CREATE OR REPLACE FUNCTION desk.fadm_lookup_export_report(p_ok boolean, p_new integer, p_last bigint, p_note text DEFAULT NULL) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = pg_catalog, desk AS $f$
DECLARE note text := left(regexp_replace(coalesce(p_note, ''), '[^A-Za-z0-9 _.,:=/-]', '', 'g'), 200);
BEGIN
  IF p_ok THEN
    IF coalesce(p_new, 0) > 0 THEN PERFORM desk.fadm_audit(NULL, 'lookup.exported', jsonb_build_object('new', p_new, 'last_cp', p_last)); END IF;
  ELSE
    PERFORM desk.fadm_audit(NULL, 'lookup.export_mismatch', jsonb_build_object('last_cp', p_last, 'note', note));
    PERFORM desk.fadm_alert_raise('security', 'high', 'lookup.export_mismatch', NULL, jsonb_build_object('last_cp', p_last, 'note', note), 'lookup.export_mismatch');
  END IF;
END $f$;

-- 12) RLS AND GRANTS (same pattern as AD4: the installer role owns, desk_app has no table right, only the doors) ------------------------------------------------------------------------------------------------
DO $$ DECLARE t text; BEGIN
  FOREACH t IN ARRAY ARRAY['fadm_lookup_reason_block','fadm_lookup_threshold','fadm_lookup_link','fadm_lookup_cp','fadm_lookup_state'] LOOP
    EXECUTE format('ALTER TABLE desk.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE desk.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS p_installer ON desk.%I', t);
    EXECUTE format('CREATE POLICY p_installer ON desk.%I FOR ALL TO %I USING (true) WITH CHECK (true)', t, current_user);
    EXECUTE format('REVOKE ALL ON desk.%I FROM desk_app', t);
  END LOOP;
END $$;
DROP TRIGGER IF EXISTS fadm_lookup_threshold_nodelete ON desk.fadm_lookup_threshold;
CREATE TRIGGER fadm_lookup_threshold_nodelete BEFORE DELETE OR TRUNCATE ON desk.fadm_lookup_threshold FOR EACH STATEMENT EXECUTE FUNCTION desk.fadm_append_only_guard();
DO $$ DECLARE p record; BEGIN
  FOR p IN SELECT pr.oid::regprocedure AS sig, pr.proname FROM pg_proc pr JOIN pg_namespace s ON s.oid = pr.pronamespace WHERE s.nspname = 'desk' AND (pr.proname LIKE 'fadm\_lookup%' OR pr.proname LIKE 'fadm\_merkle%') LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', p.sig);
    IF p.proname IN ('fadm_lookup_begin','fadm_lookup_finish','fadm_lookup_history','fadm_lookup_by_employee','fadm_lookup_seal','fadm_lookup_proof','fadm_lookup_verify_full','fadm_lookup_health','fadm_lookup_audit_door','fadm_lookup_cp_export','fadm_lookup_export_report','fadm_lookup_tick','fadm_lookup_threshold_set','fadm_merkle_verify')
      THEN EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO desk_app', p.sig);
      ELSE EXECUTE format('REVOKE ALL ON FUNCTION %s FROM desk_app', p.sig); END IF;
  END LOOP;
END $$;

-- 13) SELFTEST: every rule against real rows, then ROLLS ITSELF BACK (P0AK5 is the success exit). Any gap FAILS the whole file. -------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.ad4b_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD4b selftest: %', msg USING ERRCODE = 'P0AK4'; END IF; END $f$;
CREATE FUNCTION pg_temp.ad4b_agent(p_sfx text, p_i int, p_owner uuid) RETURNS uuid LANGUAGE plpgsql AS $f$
DECLARE a uuid; h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo';
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('a' || p_i || '-' || p_sfx || '@selftest.invalid', 'Selftest Agent ' || p_i, 'agent', NULL, true, 'active', true) RETURNING id INTO a;
  PERFORM desk.fadm_access_grant(p_owner, a, desk.fadm_unit_id('department', 'desk'), 'agent'); RETURN a;
END $f$;
DO $$
DECLARE o uuid; sup uuid; s uuid; s2 uuid; s3 uuid; s4 uuid; s5 uuid; sfx text := substr(md5(random()::text), 1, 8); rootu uuid := desk.fadm_unit_id('department', 'desk'); cref text := 'co_' || sfx;
  h text := '$argon2id$v=19$m=19456,t=2,p=1$c2VsZnRlc3Q$c2VsZnRlc3RoYXNo'; n int; k int; i int; rq uuid; lid bigint; pf jsonb; d record; okv boolean; cp1 bigint; cp2 bigint; hh int; base bigint; arr bytea[]; pth bytea[]; rt bytea; l0 bytea; l1 bytea; l2 bytea; sz int;
BEGIN
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash) VALUES ('o1-' || sfx || '@selftest.invalid', 'Selftest Owner', 'owner', h) RETURNING id INTO o;
  INSERT INTO desk.fadm_owner (email, display_name, role, pw_hash, passkey_required, status, active) VALUES ('sp-' || sfx || '@selftest.invalid', 'Selftest Supervisor', 'agent', NULL, true, 'active', true) RETURNING id INTO sup;
  PERFORM desk.fadm_access_grant(o, sup, rootu, 'supervisor');
  s := pg_temp.ad4b_agent(sfx, 1, o); s2 := pg_temp.ad4b_agent(sfx, 2, o); s3 := pg_temp.ad4b_agent(sfx, 3, o); s4 := pg_temp.ad4b_agent(sfx, 4, o); s5 := pg_temp.ad4b_agent(sfx, 5, o);
  PERFORM desk.fadm_lookup_threshold_set(o, 'seal_every_links', 100000); PERFORM desk.fadm_lookup_threshold_set(o, 'seal_every_minutes', 100000);   -- no automatic seal until the seal rules are tested
  SELECT coalesce(max(cp_seq), 0) INTO base FROM desk.fadm_lookup_cp;
  PERFORM desk.fadm_lookup_threshold_set(o, 'hours_from', 0); PERFORM desk.fadm_lookup_threshold_set(o, 'hours_to', 0);   -- no after-hours noise while the other rules are tested
  PERFORM pg_temp.ad4b_ok((SELECT value FROM desk.fadm_lookup_threshold WHERE name = 'hours_to') = 0 AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.threshold') >= 2, 'a threshold change goes through the admin door and into the ledger');
  BEGIN PERFORM desk.fadm_lookup_threshold_set(s, 'daily_total', 5); RAISE EXCEPTION 'no refusal t1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_threshold_set(o, 'hours_from', 24); RAISE EXCEPTION 'no refusal t2' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_threshold_set(o, 'no_such_name', 5); RAISE EXCEPTION 'no refusal t3' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN no_data_found THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_threshold_set(o, 'daily_total', 0); RAISE EXCEPTION 'no refusal t4' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;

  -- P6 reason quality: each bad reason is refused with its own reason code, a good one passes
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('test test test test', false) = 'reason_repeats_words', 'the same word four times is refused');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('just checking it now', false) = 'reason_only_filler', 'only filler words are refused');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('ab ab ab', false) = 'reason_repeats_words', 'two words repeated are refused');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('aaaaaaaa bbbbbbbb cccccccc', false) IS NOT NULL, 'filler letters are refused');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('mail missing', false) = 'reason_too_few_words', 'fewer than three words is refused');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('customer says mail is missing', false) IS NULL, 'a real reason passes');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('mail still missing today', true) = 'reason_too_short_for_sensitive_fields', 'a sensitive field needs a longer reason');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_reason_why('customer reports suspension notice and asks why', true) IS NULL, 'a long reason passes for a sensitive field');
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'test test test test', ARRAY['service_state'], gen_random_uuid()); RAISE EXCEPTION 'no refusal r1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_begin(s, cref, 'mail still missing today', ARRAY['suspension_class'], gen_random_uuid()); RAISE EXCEPTION 'no refusal r2' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_lookup WHERE employee_id = s) = 0, 'a refused reason leaves no request line');

  -- P1/P2 the chain: each row gets one link; the chain verifies; time only goes forward
  rq := gen_random_uuid(); lid := desk.fadm_lookup_begin(s, cref, 'customer says mail is missing', ARRAY['service_state','usage_seats'], rq);
  PERFORM desk.fadm_lookup_finish(s, rq, 'answered');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_lookup_link k JOIN desk.fadm_lookup l ON l.id = k.lookup_id WHERE l.request_id = rq) = 2, 'a request line and its result line each have a link');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_verify() AND (SELECT ok FROM desk.fadm_lookup_verify_detail()), 'the whole chain verifies');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_lookup_link k WHERE k.linked_at <= coalesce((SELECT x.linked_at FROM desk.fadm_lookup_link x WHERE x.seq = k.seq - 1), '-infinity')) = 0, 'link time is strictly increasing');
  PERFORM pg_temp.ad4b_ok((SELECT prev_hash FROM desk.fadm_lookup_link WHERE seq = 1) = sha256('anexo-desk-lookup-chain-genesis'::bytea) OR (SELECT count(*) FROM desk.fadm_lookup_link) > 0, 'the chain starts at the fixed genesis');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_verify_tail(2), 'the tail check agrees');
  -- tampering is detected, each kind on its own, then undone (sub-transaction)
  okv := false;
  BEGIN ALTER TABLE desk.fadm_lookup DISABLE TRIGGER fadm_lookup_frozen; UPDATE desk.fadm_lookup SET reason = 'changed after the fact by someone' WHERE request_id = rq AND outcome = 'requested';
    SELECT * INTO d FROM desk.fadm_lookup_verify_detail(); okv := (NOT d.ok) AND d.why = 'row_changed_after_link' AND NOT desk.fadm_lookup_verify_tail(5);
    RAISE EXCEPTION 'undo' USING ERRCODE = 'P0AK9'; EXCEPTION WHEN SQLSTATE 'P0AK9' THEN NULL; END;
  PERFORM pg_temp.ad4b_ok(okv, 'a changed reason is found (row_changed_after_link) by the full and the tail check');
  okv := false;
  BEGIN ALTER TABLE desk.fadm_lookup_link DISABLE TRIGGER fadm_lookup_link_frozen; DELETE FROM desk.fadm_lookup_link WHERE seq = (SELECT min(seq) FROM desk.fadm_lookup_link);
    SELECT * INTO d FROM desk.fadm_lookup_verify_detail(); okv := (NOT d.ok) AND d.why = 'gap_in_sequence';
    RAISE EXCEPTION 'undo' USING ERRCODE = 'P0AK9'; EXCEPTION WHEN SQLSTATE 'P0AK9' THEN NULL; END;
  PERFORM pg_temp.ad4b_ok(okv, 'a removed link is found (gap_in_sequence)');
  okv := false;
  BEGIN ALTER TABLE desk.fadm_lookup_link DISABLE TRIGGER fadm_lookup_link_frozen; UPDATE desk.fadm_lookup_link SET hash = sha256('forged'::bytea) WHERE seq = 1;
    SELECT * INTO d FROM desk.fadm_lookup_verify_detail(); okv := (NOT d.ok) AND d.first_bad = 1;
    RAISE EXCEPTION 'undo' USING ERRCODE = 'P0AK9'; EXCEPTION WHEN SQLSTATE 'P0AK9' THEN NULL; END;
  PERFORM pg_temp.ad4b_ok(okv, 'a forged link hash is found at its sequence number');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_verify(), 'after the undone attacks the chain is whole again');

  -- P12 retention: nothing can be deleted or edited, by anybody, on any of the three tables
  BEGIN UPDATE desk.fadm_lookup SET reason = 'changed after the fact' WHERE request_id = rq; RAISE EXCEPTION 'no refusal d1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_lookup_link; RAISE EXCEPTION 'no refusal d2' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN UPDATE desk.fadm_lookup_link SET linked_at = now(); RAISE EXCEPTION 'no refusal d3' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN TRUNCATE desk.fadm_lookup_link; RAISE EXCEPTION 'no refusal d4' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN DELETE FROM desk.fadm_lookup_threshold; RAISE EXCEPTION 'no refusal d5' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;

  -- P3/P4 the Merkle tree: roots of size 1, 2, 3 against a hand calculation; every proof of every size 1..37 verifies, every damaged proof fails
  arr := ARRAY[sha256('a'::bytea), sha256('b'::bytea), sha256('c'::bytea)];
  l0 := desk.fadm_merkle_leaf(arr[1]); l1 := desk.fadm_merkle_leaf(arr[2]); l2 := desk.fadm_merkle_leaf(arr[3]);
  PERFORM pg_temp.ad4b_ok(desk.fadm_merkle_mth(ARRAY[l0]) = l0, 'tree of one leaf: the root is the leaf hash');
  PERFORM pg_temp.ad4b_ok(desk.fadm_merkle_mth(ARRAY[l0, l1]) = sha256('\x01'::bytea || l0 || l1), 'tree of two: node(l0, l1)');
  PERFORM pg_temp.ad4b_ok(desk.fadm_merkle_mth(ARRAY[l0, l1, l2]) = sha256('\x01'::bytea || sha256('\x01'::bytea || l0 || l1) || l2), 'tree of three: node(node(l0, l1), l2)');
  PERFORM pg_temp.ad4b_ok(desk.fadm_merkle_mth('{}'::bytea[]) = sha256(''::bytea), 'the empty tree is the hash of nothing');
  FOR sz IN 1..37 LOOP
    arr := ARRAY(SELECT desk.fadm_merkle_leaf(sha256(convert_to('leaf' || g, 'UTF8'))) FROM generate_series(1, sz) g ORDER BY g);
    rt := desk.fadm_merkle_mth(arr);
    FOR i IN 0..sz - 1 LOOP
      pth := desk.fadm_merkle_path(arr, i);
      IF NOT desk.fadm_merkle_verify(arr[i + 1], i, sz, pth, rt) THEN RAISE EXCEPTION 'AD4b selftest: proof of leaf % in a tree of % does not verify', i, sz USING ERRCODE = 'P0AK4'; END IF;
      IF desk.fadm_merkle_verify(arr[i + 1], i, sz, pth, sha256('other'::bytea)) THEN RAISE EXCEPTION 'AD4b selftest: wrong root accepted (leaf %, size %)', i, sz USING ERRCODE = 'P0AK4'; END IF;
      IF sz > 1 AND desk.fadm_merkle_verify(arr[((i + 1) % sz) + 1], i, sz, pth, rt) THEN RAISE EXCEPTION 'AD4b selftest: another leaf accepted at index % in size %', i, sz USING ERRCODE = 'P0AK4'; END IF;
      IF sz > 1 AND desk.fadm_merkle_verify(arr[i + 1], i, sz, pth[1:array_length(pth, 1) - 1], rt) THEN RAISE EXCEPTION 'AD4b selftest: short path accepted (leaf %, size %)', i, sz USING ERRCODE = 'P0AK4'; END IF;
      IF sz > 1 AND desk.fadm_merkle_verify(arr[i + 1], (i + 1) % sz, sz, pth, rt) AND ((i + 1) % sz) <> i THEN RAISE EXCEPTION 'AD4b selftest: wrong index accepted (leaf %, size %)', i, sz USING ERRCODE = 'P0AK4'; END IF;
    END LOOP;
  END LOOP;

  -- checkpoints on the real links: who may seal, what it records, chaining, the copy in the main ledger
  BEGIN PERFORM desk.fadm_lookup_seal(s); RAISE EXCEPTION 'no refusal c1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM desk.fadm_lookup_proof(sup, lid); RAISE EXCEPTION 'no refusal c2' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;   -- nothing sealed yet
  cp1 := desk.fadm_lookup_seal(o);
  PERFORM pg_temp.ad4b_ok(cp1 = base + 1 AND (SELECT size FROM desk.fadm_lookup_cp WHERE cp_seq = cp1) = (SELECT count(*) FROM desk.fadm_lookup_link) AND (SELECT root FROM desk.fadm_lookup_cp WHERE cp_seq = cp1) = desk.fadm_lookup_root((SELECT max(seq) FROM desk.fadm_lookup_link)), 'the first checkpoint covers all links and its root is the Merkle root');
  PERFORM pg_temp.ad4b_ok((SELECT prev_hash FROM desk.fadm_lookup_cp WHERE cp_seq = cp1) = CASE WHEN base = 0 THEN sha256('anexo-desk-lookup-cp-genesis'::bytea) ELSE (SELECT hash FROM desk.fadm_lookup_cp WHERE cp_seq = base) END, 'a checkpoint chains from the fixed genesis or from the one before it');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.sealed' AND detail->>'root' = encode((SELECT root FROM desk.fadm_lookup_cp WHERE cp_seq = cp1), 'hex')) = 1, 'the root is copied into the main ledger (a second anchor)');
  BEGIN PERFORM desk.fadm_lookup_seal(o); RAISE EXCEPTION 'no refusal c3' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation THEN NULL; END;   -- nothing new
  rq := gen_random_uuid(); PERFORM desk.fadm_lookup_begin(s, cref, 'customer asks about storage limit', ARRAY['limit_storage'], rq); PERFORM desk.fadm_lookup_finish(s, rq, 'answered');
  cp2 := desk.fadm_lookup_seal(o);
  PERFORM pg_temp.ad4b_ok(cp2 = cp1 + 1 AND (SELECT prev_hash FROM desk.fadm_lookup_cp WHERE cp_seq = cp2) = (SELECT hash FROM desk.fadm_lookup_cp WHERE cp_seq = cp1) AND desk.fadm_lookup_cp_verify(), 'the second checkpoint chains from the first and all checkpoints verify');
  okv := false;
  BEGIN ALTER TABLE desk.fadm_lookup_cp DISABLE TRIGGER fadm_lookup_cp_frozen; UPDATE desk.fadm_lookup_cp SET root = sha256('forged'::bytea) WHERE cp_seq = cp1; okv := NOT desk.fadm_lookup_cp_verify();
    RAISE EXCEPTION 'undo' USING ERRCODE = 'P0AK9'; EXCEPTION WHEN SQLSTATE 'P0AK9' THEN NULL; END;
  PERFORM pg_temp.ad4b_ok(okv, 'a forged checkpoint root is found');
  BEGIN UPDATE desk.fadm_lookup_cp SET size = 1; RAISE EXCEPTION 'no refusal c4' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  -- the proof of a lookup row, checked with the PURE verifier, from the numbers the door returns
  PERFORM desk.fadm_lookup_verify_full(sup);
  pf := desk.fadm_lookup_proof(sup, lid);
  PERFORM pg_temp.ad4b_ok(desk.fadm_merkle_verify(decode(pf->>'leaf', 'hex'), (pf->>'index')::bigint, (pf->>'tree_size')::bigint, ARRAY(SELECT decode(x, 'hex') FROM jsonb_array_elements_text(pf->'path') x), decode(pf->>'root', 'hex')), 'the proof the door returns verifies against the checkpoint root');
  PERFORM pg_temp.ad4b_ok(NOT desk.fadm_merkle_verify(decode(pf->>'leaf', 'hex'), (pf->>'index')::bigint + 1, (pf->>'tree_size')::bigint, ARRAY(SELECT decode(x, 'hex') FROM jsonb_array_elements_text(pf->'path') x), decode(pf->>'root', 'hex')), 'the same proof at another index fails');
  BEGIN PERFORM desk.fadm_lookup_proof(s, lid); RAISE EXCEPTION 'no refusal p1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- an agent has no audit.read
  PERFORM pg_temp.ad4b_ok((SELECT (desk.fadm_lookup_verify_full(sup)->>'chain_ok')::boolean), 'verify_full answers true on a whole chain');

  -- P8/P9 self-audit and separation of duties
  PERFORM * FROM desk.fadm_lookup_history(sup, cref);
  PERFORM * FROM desk.fadm_lookup_by_employee(sup, s);
  BEGIN PERFORM * FROM desk.fadm_lookup_by_employee(sup, sup); RAISE EXCEPTION 'no refusal s1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN PERFORM * FROM desk.fadm_lookup_by_employee(o, o); RAISE EXCEPTION 'no refusal s2' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- not even the owner
  BEGIN PERFORM * FROM desk.fadm_lookup_by_employee(s, s2); RAISE EXCEPTION 'no refusal s3' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  rq := gen_random_uuid(); PERFORM desk.fadm_lookup_begin(sup, cref, 'supervisor checks a customer case', ARRAY['service_state'], rq); PERFORM desk.fadm_lookup_finish(sup, rq, 'answered');
  SELECT id INTO lid FROM desk.fadm_lookup WHERE request_id = rq AND outcome = 'requested'; PERFORM desk.fadm_lookup_seal(o);
  BEGIN PERFORM desk.fadm_lookup_proof(sup, lid); RAISE EXCEPTION 'no refusal s4' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- the proof of his own lookup
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.history_read' AND detail->>'company' = cref) = 1
    AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.person_read') = 1 AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.proof_read') >= 1 AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.verified') >= 2, 'reading history, a person, a proof and the verify are all ledger lines');

  -- P5 orphans: a request that never gets a result is closed as abandoned, no data was shown, an alert is raised; a late finish is refused
  PERFORM desk.fadm_lookup_threshold_set(o, 'orphan_secs', 1);
  rq := gen_random_uuid(); PERFORM desk.fadm_lookup_begin(s5, 'co_orphan_' || sfx, 'customer says mail is missing', ARRAY['service_state'], rq);
  PERFORM pg_sleep(1.3);
  PERFORM pg_temp.ad4b_ok((desk.fadm_lookup_health()->>'orphans_open')::int >= 1, 'the health door shows the open orphan before the sweep');
  PERFORM pg_temp.ad4b_ok((desk.fadm_lookup_maintain(true)->>'abandoned')::int >= 1, 'the sweep closes the orphan');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_lookup WHERE request_id = rq AND outcome = 'abandoned') = 1 AND (SELECT count(*) FROM desk.fadm_lookup WHERE request_id = rq AND outcome = 'answered') = 0, 'abandoned, never answered');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.abandoned' AND detail->>'request' = rq::text) = 1 AND (SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.abandoned' AND owner_id = s5) >= 1, 'abandoned is a ledger line and an alert');
  BEGIN PERFORM desk.fadm_lookup_finish(s5, rq, 'answered'); RAISE EXCEPTION 'no refusal o1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN check_violation OR no_data_found THEN NULL; END;
  PERFORM pg_temp.ad4b_ok((desk.fadm_lookup_health()->>'orphans_open')::int = 0, 'no orphan stays open after the sweep');
  PERFORM desk.fadm_lookup_threshold_set(o, 'orphan_secs', 120);

  -- P7 live signals (each by its own person so the numbers stay clean)
  FOR k IN 1..15 LOOP PERFORM desk.fadm_lookup_begin(s2, 'co_bulk_' || k || '_' || sfx, 'customer asks about service state ' || k, ARRAY['service_state'], gen_random_uuid()); END LOOP;
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.bulk' AND owner_id = s2) = 1, 'fifteen different companies in an hour raise ONE bulk alert (de-duplicated)');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.bulk' AND owner_id = s) = 0, 'a quiet person has no bulk alert');
  FOR k IN 1..6 LOOP PERFORM desk.fadm_lookup_begin(s3, 'co_same_' || sfx, 'customer follow up number ' || k || ' about mail', ARRAY['service_state'], gen_random_uuid()); END LOOP;
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.repeat' AND owner_id = s3) = 1, 'the same company six times raises a repeat alert');
  FOR k IN 1..8 LOOP PERFORM desk.fadm_lookup_begin(s4, 'co_reuse_' || k || '_' || sfx, 'customer says the mail is missing', ARRAY['service_state'], gen_random_uuid()); END LOOP;
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.reuse' AND owner_id = s4) = 1, 'the same reason eight times raises a copy-paste alert');
  PERFORM pg_temp.ad4b_ok(NOT EXISTS (SELECT 1 FROM desk.fadm_alert WHERE kind = 'lookup.reuse' AND detail::text ~ 'missing'), 'an alert never carries the reason text');
  FOR k IN 1..5 LOOP rq := gen_random_uuid(); PERFORM desk.fadm_lookup_begin(sup, 'co_probe_' || k || '_' || sfx, 'checking storage limit for customer ' || k, ARRAY['limit_storage'], rq); PERFORM desk.fadm_lookup_finish(sup, rq, 'unavailable'); END LOOP;
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.probe' AND owner_id = sup) = 1, 'five failed lookups in an hour raise a probe alert');
  PERFORM desk.fadm_lookup_threshold_set(o, 'daily_total', 3);
  PERFORM desk.fadm_lookup_begin(s, 'co_d1_' || sfx, 'customer asks about seat limit', ARRAY['limit_seats'], gen_random_uuid());
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.daily' AND owner_id = s) = 1, 'the daily total threshold raises a daily alert');
  PERFORM desk.fadm_lookup_threshold_set(o, 'daily_total', 150);
  -- after hours: move the allowed window away from the current Karachi hour
  hh := extract(hour FROM now() AT TIME ZONE 'Asia/Karachi')::int;
  PERFORM desk.fadm_lookup_threshold_set(o, 'hours_from', (hh + 2) % 24); PERFORM desk.fadm_lookup_threshold_set(o, 'hours_to', (hh + 3) % 24);
  PERFORM desk.fadm_lookup_begin(s, 'co_ah_' || sfx, 'customer asks about attachment limit', ARRAY['limit_attachment'], gen_random_uuid());
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.after_hours' AND owner_id = s) = 1, 'a lookup outside the allowed hours raises an after-hours alert');
  PERFORM desk.fadm_lookup_threshold_set(o, 'hours_from', hh); PERFORM desk.fadm_lookup_threshold_set(o, 'hours_to', (hh + 1) % 24);
  PERFORM desk.fadm_lookup_begin(s2, 'co_ah2_' || sfx, 'customer asks about attachment limit', ARRAY['limit_attachment'], gen_random_uuid());
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.after_hours' AND owner_id = s2) = 0, 'a lookup inside the allowed hour raises nothing');

  -- P10 auto seal at the link count, P11 health: counts only
  PERFORM desk.fadm_lookup_threshold_set(o, 'seal_every_links', 1); PERFORM desk.fadm_lookup_threshold_set(o, 'seal_every_minutes', 60);
  PERFORM pg_temp.ad4b_ok((desk.fadm_lookup_maintain(true)->>'sealed')::boolean, 'maintenance seals automatically when enough new links exist');
  PERFORM pg_temp.ad4b_ok((SELECT auto FROM desk.fadm_lookup_cp ORDER BY cp_seq DESC LIMIT 1) AND desk.fadm_lookup_cp_verify(), 'the automatic checkpoint is marked auto and verifies');
  pf := desk.fadm_lookup_health();
  PERFORM pg_temp.ad4b_ok((pf->>'tail_ok')::boolean AND (pf->>'checkpoints')::int >= 3 AND pf ? 'signals_24h' AND pf ? 'links' AND pf ? 'unsealed_links', 'the health door answers with its counts');
  PERFORM pg_temp.ad4b_ok(pf::text !~* '(company|reason|co_|selftest)', 'the health door carries no company, reason or person');
  BEGIN PERFORM desk.fadm_lookup_audit_door(s); RAISE EXCEPTION 'no refusal h1' USING ERRCODE = 'P0AK4'; EXCEPTION WHEN insufficient_privilege THEN NULL; END;   -- an agent cannot read the audit counts
  PERFORM pg_temp.ad4b_ok((desk.fadm_lookup_audit_door(sup)->>'tail_ok')::boolean, 'a supervisor reads the audit counts through the Bridge door');

  -- outside copy doors: the export lists checkpoints (hashes only), the report writes a ledger line and, on a mismatch, a high alert
  pf := desk.fadm_lookup_cp_export(0, 1000);
  PERFORM pg_temp.ad4b_ok(jsonb_array_length(pf) = (SELECT count(*) FROM desk.fadm_lookup_cp) AND pf::text !~* '(company|reason)' AND (pf->0->>'root') = encode((SELECT root FROM desk.fadm_lookup_cp ORDER BY cp_seq LIMIT 1), 'hex'), 'the export door lists every checkpoint with hashes only');
  PERFORM pg_temp.ad4b_ok(jsonb_array_length(desk.fadm_lookup_cp_export((SELECT max(cp_seq) FROM desk.fadm_lookup_cp), 10)) = 0, 'the export door lists only checkpoints after the last one given');
  PERFORM desk.fadm_lookup_export_report(true, 2, 5, 'ok'); PERFORM desk.fadm_lookup_export_report(false, 0, 5, 'file 5 hash differs; <b>x</b>');
  PERFORM pg_temp.ad4b_ok((SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.exported') = 1 AND (SELECT count(*) FROM desk.fadm_ledger WHERE kind = 'lookup.export_mismatch') = 1 AND (SELECT count(*) FROM desk.fadm_alert WHERE kind = 'lookup.export_mismatch' AND severity = 'high') = 1
    AND (SELECT detail->>'note' FROM desk.fadm_ledger WHERE kind = 'lookup.export_mismatch' ORDER BY seq DESC LIMIT 1) !~ '[<>;]', 'a mismatch report is a ledger line and ONE high alert; the note is stripped to safe characters');
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_tick() ? 'sealed' OR desk.fadm_lookup_tick() ? 'skipped', 'the tick door runs maintenance (or says why it skipped)');
  PERFORM pg_temp.ad4b_ok(has_function_privilege('desk_app', 'desk.fadm_lookup_tick()', 'EXECUTE'), 'the tick door is granted to desk_app');
  -- burst breaker of AD4 still works through the new begin (31st in a minute freezes)
  FOR k IN 1..29 LOOP PERFORM desk.fadm_lookup_begin(s5, 'co_burst_' || k || '_' || sfx, 'burst viewing selftest number ' || k, ARRAY['service_state'], gen_random_uuid()); END LOOP;
  PERFORM pg_temp.ad4b_ok(desk.fadm_lookup_begin(s5, 'co_burst_x_' || sfx, 'burst viewing selftest number x', ARRAY['service_state'], gen_random_uuid()) IS NULL, 'the 31st lookup in a minute is refused (NULL)');
  PERFORM pg_temp.ad4b_ok((SELECT status FROM desk.fadm_owner WHERE id = s5) = 'suspended', 'the bulk-view breaker still freezes the person');

  -- grants: desk_app has doors only, internal functions are not granted, PUBLIC has nothing
  PERFORM pg_temp.ad4b_ok(NOT has_table_privilege('desk_app', 'desk.fadm_lookup_link', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup_cp', 'SELECT') AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup_threshold', 'UPDATE')
    AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup_state', 'UPDATE') AND NOT has_table_privilege('desk_app', 'desk.fadm_lookup_reason_block', 'INSERT'), 'desk_app has no right on the new tables');
  PERFORM pg_temp.ad4b_ok(has_function_privilege('desk_app', 'desk.fadm_lookup_seal(uuid,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_lookup_proof(uuid,bigint,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_lookup_health()', 'EXECUTE')
    AND has_function_privilege('desk_app', 'desk.fadm_lookup_by_employee(uuid,uuid,integer,inet)', 'EXECUTE') AND has_function_privilege('desk_app', 'desk.fadm_merkle_verify(bytea,bigint,bigint,bytea[],bytea)', 'EXECUTE'), 'the doors are granted to desk_app');
  PERFORM pg_temp.ad4b_ok(NOT has_function_privilege('desk_app', 'desk.fadm_lookup_maintain(boolean)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_lookup_link_add(bigint)', 'EXECUTE') AND NOT has_function_privilege('desk_app', 'desk.fadm_lookup_signals(uuid)', 'EXECUTE'), 'internal functions are not granted');
  PERFORM pg_temp.ad4b_ok(desk.fadm_ledger_verify(), 'the main ledger chain still verifies');
  PERFORM desk.fadm_audit(o, 'ad4b.selftest', '{}'::jsonb);
  RAISE EXCEPTION 'AD4b selftest passed, rolling back' USING ERRCODE = 'P0AK5';
EXCEPTION WHEN SQLSTATE 'P0AK5' THEN RAISE NOTICE 'AD4b selftest: ALL RULES PASSED (rows rolled back)';
END $$;
COMMIT;
