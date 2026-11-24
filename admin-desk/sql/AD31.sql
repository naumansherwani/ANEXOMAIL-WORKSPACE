-- TARGET-DB: AWAM DATABASE (schema cp). NOT the Desk database: scripts/cp-install.sh runs this file on the awam database; ad-auto.sh and ad-sql-run.sh skip every file with this line.
-- ANEXOMAIL CONTROL PLANE AD31 (phase 1m, card B13 step T3a, list BL-46: SENDER -> ONE TENANT VERDICT), 24 Nov 2026 PKT. The pure resolver: given the sender's domain, local part and whether the message authenticated as that domain, answer ONE closed verdict word and, only when conclusive, ONE tenant UUID. Nothing else leaves the database.
-- SCHEMA-FIRST: read before writing: AD26 (cp.domain_ownership with valid_from / valid_to, cp.shared_domain, cp.tenant_of_domain, role cp_lookup, forced RLS pattern, TARGET-DB marker), AD25 (cp schema, SECURITY DEFINER rules), AD30 (the Desk side binding this verdict feeds: source verified_domain / verified_member), public.orgs (the canonical tenant UUID), public.org_members (org_id, email, status; the member list the awam site keeps), E15 org_domains (verified status that AD26 mirrors).
-- DECISION-READ: docs/claude/admin-desk/TENANT-IDENTITY-CONSENT-DECISION-24NOV.md (read in full; rows 1, 4, 5, 6, 7 and 8 of his advisor text are this function; list: docs/claude/admin-desk/D6-B13-T3-RESOLUTION-LIST-24NOV.md)
-- ADVANCE-RESEARCH: [T3] B13 T3a (24 Nov 2026 web search + advisor text): a tenant is chosen from a VERIFIED domain whose ownership period covers the arrival time, and a sender is believed only when the message authenticated as that domain (DMARC identifier alignment, RFC 7489) AND the sender is an active member of that tenant; free/shared providers never resolve; two claimants or several memberships are ambiguous and stay pending; only a closed verdict word and a UUID leave the database (data minimisation).
-- CHECK-FILE: docs/claude/admin-desk/sql/checks/AD31-check.sql
-- WHAT IT ADDS (nothing of AD01..AD30 is changed): cp.resolve_sender(domain, local_part, aligned, at) -> jsonb {verdict, tenant}. Verdicts (closed list): resolved, shared, unknown, ambiguous, multi_member, unaligned. tenant is set ONLY for resolved. STABLE reader, no table written; the Control Plane door (T3b) writes the ledger line for every attempt.
-- DECISION TABLE (first match wins): bad input -> unknown; not aligned -> unaligned; shared provider -> shared; domain has two open owners at that time -> ambiguous; no owner -> unknown; sender not an ACTIVE member of the owner tenant -> unknown (pending, fail closed); sender an active member of more than one tenant -> multi_member; otherwise resolved.
-- HONEST LIMITS: aliases are not modelled yet (a sender must be a member by exact address); that is the safe side (pending, never a wrong company). The ALIGNED flag is supplied by the mail door in Folder 2 (it reads SPF / DKIM / DMARC results); until that door exists the live call is T4 manual.
CREATE OR REPLACE FUNCTION cp.resolve_sender(p_domain text, p_local text, p_aligned boolean, p_at timestamptz DEFAULT now()) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
DECLARE owners uuid[]; o uuid; addr text; n int;
BEGIN
  IF p_domain IS NULL OR p_local IS NULL OR p_aligned IS NULL OR p_at IS NULL
     OR p_domain <> lower(p_domain) OR p_domain !~ '^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$'
     OR p_local <> lower(p_local) OR p_local !~ '^[a-z0-9][a-z0-9._+-]{0,63}$' THEN
    RETURN jsonb_build_object('verdict', 'unknown', 'tenant', NULL);
  END IF;
  IF NOT p_aligned THEN RETURN jsonb_build_object('verdict', 'unaligned', 'tenant', NULL); END IF;
  IF EXISTS (SELECT 1 FROM cp.shared_domain s WHERE s.domain = p_domain) THEN RETURN jsonb_build_object('verdict', 'shared', 'tenant', NULL); END IF;
  SELECT array_agg(DISTINCT d.org_id) INTO owners FROM cp.domain_ownership d WHERE d.domain = p_domain AND d.valid_from <= p_at AND (d.valid_to IS NULL OR d.valid_to > p_at);
  IF owners IS NOT NULL AND array_length(owners, 1) > 1 THEN RETURN jsonb_build_object('verdict', 'ambiguous', 'tenant', NULL); END IF;
  IF owners IS NULL THEN RETURN jsonb_build_object('verdict', 'unknown', 'tenant', NULL); END IF;
  o := owners[1]; addr := p_local || '@' || p_domain;
  IF NOT EXISTS (SELECT 1 FROM public.orgs t WHERE t.id = o) THEN RETURN jsonb_build_object('verdict', 'unknown', 'tenant', NULL); END IF;
  IF NOT EXISTS (SELECT 1 FROM public.org_members m WHERE m.org_id = o AND lower(m.email) = addr AND m.status = 'active') THEN RETURN jsonb_build_object('verdict', 'unknown', 'tenant', NULL); END IF;
  SELECT count(DISTINCT m.org_id) INTO n FROM public.org_members m WHERE lower(m.email) = addr AND m.status = 'active' AND EXISTS (SELECT 1 FROM public.orgs t WHERE t.id = m.org_id);
  IF n > 1 THEN RETURN jsonb_build_object('verdict', 'multi_member', 'tenant', NULL); END IF;
  RETURN jsonb_build_object('verdict', 'resolved', 'tenant', o);
END $f$;
COMMENT ON FUNCTION cp.resolve_sender(text, text, boolean, timestamptz) IS 'AD31: sender -> closed verdict (+ tenant only when resolved). Verified domain at arrival time AND active member AND aligned. Fail closed everywhere.';
REVOKE ALL ON FUNCTION cp.resolve_sender(text, text, boolean, timestamptz) FROM PUBLIC;
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cp_lookup') THEN
  GRANT EXECUTE ON FUNCTION cp.resolve_sender(text, text, boolean, timestamptz) TO cp_lookup;
END IF; END $g$;

-- T4e (his 25 Nov 2026 03:13 order, edit of THIS file, no new SQL file): READ DOOR 3, the tenant registry answer for the Desk: "is this company UUID real, and what is its display NAME?". Read only, one row at most, never cached by the caller for an approval.
-- ADVANCE-RESEARCH (T4e): tenant registry as the single source of existence + display name (big multi-tenant SaaS pattern); least privilege (OWASP ASVS V4): one closed read-only function, nothing else is exposed; the name is cleaned (control characters out, 120 characters max) because it is shown to a human reviewer and must never carry markup tricks. Fail closed: bad input answers exists=false.
CREATE OR REPLACE FUNCTION cp.tenant_info(p_tenant uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, pg_temp SET statement_timeout = '5s' AS $f$
  SELECT CASE WHEN p_tenant IS NULL OR p_tenant = '00000000-0000-0000-0000-000000000000'::uuid THEN jsonb_build_object('exists', false, 'name', NULL)
    ELSE coalesce((SELECT jsonb_build_object('exists', true, 'name', left(regexp_replace(coalesce(o.name, ''), '[[:cntrl:]]', '', 'g'), 120)) FROM public.orgs o WHERE o.id = p_tenant), jsonb_build_object('exists', false, 'name', NULL)) END
$f$;
COMMENT ON FUNCTION cp.tenant_info(uuid) IS 'AD31 T4e: company UUID -> {exists, name}; read only; name cleaned and cut at 120; unknown, nil or null UUID = exists false.';
REVOKE ALL ON FUNCTION cp.tenant_info(uuid) FROM PUBLIC;
DO $g$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'cp_lookup') THEN
  GRANT EXECUTE ON FUNCTION cp.tenant_info(uuid) TO cp_lookup;
END IF; END $g$;

-- SELFTEST (rolls back; success is the exception P0AU2) ------------------------------------------------------------------------------------------------------------------------------
CREATE FUNCTION pg_temp.cp7_ok(c boolean, msg text) RETURNS void LANGUAGE plpgsql AS $f$ BEGIN IF c IS NOT TRUE THEN RAISE EXCEPTION 'AD31 selftest: %', msg USING ERRCODE = 'P0AU1'; END IF; END $f$;
DO $$
DECLARE o1 uuid; o2 uuid; u1 uuid; u2 uuid; u3 uuid; u4 uuid; t0 timestamptz := clock_timestamp(); sfx text := substr(md5(random()::text), 1, 8); d1 text; d2 text; dd text; r jsonb;
BEGIN
  d1 := 'ad31a' || sfx || '.example'; d2 := 'ad31b' || sfx || '.example'; dd := 'ad31c' || sfx || '.example';
  -- the live schema (schema-public.sql): org_members.org_id -> organisations(id) and org_members.user_id -> auth.users(id), so the test uses two EXISTING tenants (public.orgs rows that are also in organisations; AD26 FACT: none missing) and four EXISTING auth users that are not yet members of them; only org_members rows are added, all rolled back
  SELECT (array_agg(x.id))[1], (array_agg(x.id))[2] INTO o1, o2 FROM (SELECT t.id FROM public.orgs t WHERE EXISTS (SELECT 1 FROM public.organisations g WHERE g.id = t.id) ORDER BY t.id LIMIT 2) x;
  IF o1 IS NULL OR o2 IS NULL OR o1 = o2 THEN RAISE EXCEPTION 'AD31 selftest: needs two existing tenants (public.orgs rows that are also in public.organisations)' USING ERRCODE = 'P0AU1'; END IF;
  SELECT (array_agg(a.id))[1], (array_agg(a.id))[2], (array_agg(a.id))[3], (array_agg(a.id))[4] INTO u1, u2, u3, u4 FROM (SELECT au.id FROM auth.users au WHERE NOT EXISTS (SELECT 1 FROM public.org_members m WHERE m.user_id = au.id AND m.org_id IN (o1, o2)) ORDER BY au.id LIMIT 4) a;
  IF u4 IS NULL THEN RAISE EXCEPTION 'AD31 selftest: needs four existing auth users that are not members of the two test tenants' USING ERRCODE = 'P0AU1'; END IF;
  INSERT INTO cp.domain_ownership (org_id, domain, valid_from) VALUES (o1, d1, t0 - interval '10 days'), (o2, d2, t0 - interval '10 days');
  INSERT INTO public.org_members (org_id, user_id, email, status) VALUES (o1, u1, 'ann@' || d1, 'active'), (o1, u2, 'gone@' || d1, 'removed'), (o2, u3, 'bob@' || d2, 'active');
  r := cp.resolve_sender(d1, 'ann', true, t0);
  PERFORM pg_temp.cp7_ok(r ->> 'verdict' = 'resolved' AND (r ->> 'tenant')::uuid = o1, 'an active member at a verified domain, aligned, resolves to ITS tenant');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender(d1, 'ann', false, t0) ->> 'verdict' = 'unaligned' AND (cp.resolve_sender(d1, 'ann', false, t0) -> 'tenant') = 'null'::jsonb, 'a sender that did not authenticate as the domain is never resolved');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender('gmail.com', 'ann', true, t0) ->> 'verdict' = 'shared', 'a shared provider never resolves');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender(d1, 'stranger', true, t0) ->> 'verdict' = 'unknown', 'a verified domain but NOT a member = pending (unknown)');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender(d1, 'gone', true, t0) ->> 'verdict' = 'unknown', 'a removed member is not a member');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender('nobody' || sfx || '.example', 'ann', true, t0) ->> 'verdict' = 'unknown', 'a domain nobody owns is unknown');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender(d1, 'ann', true, t0 - interval '20 days') ->> 'verdict' = 'unknown', 'before the ownership period began: unknown (history respected)');
  -- two claimants at the same time (the EXCLUDE normally forbids it; the verdict still has to fail closed). The exclusion is switched off for this rolled-back test only.
  BEGIN
    ALTER TABLE cp.domain_ownership DISABLE TRIGGER USER;
    INSERT INTO cp.domain_ownership (org_id, domain, valid_from) VALUES (o2, dd, t0 - interval '5 days'), (o1, dd, t0 - interval '5 days');
    PERFORM pg_temp.cp7_ok(cp.resolve_sender(dd, 'ann', true, t0) ->> 'verdict' = 'ambiguous', 'two open claimants = ambiguous, never a guess');
    ALTER TABLE cp.domain_ownership ENABLE TRIGGER USER;
  EXCEPTION WHEN exclusion_violation OR unique_violation THEN
    ALTER TABLE cp.domain_ownership ENABLE TRIGGER USER;
    PERFORM pg_temp.cp7_ok(true, 'the database itself forbids two claimants (exclusion), the stronger guarantee');
  END;
  INSERT INTO public.org_members (org_id, user_id, email, status) VALUES (o2, u4, 'ann@' || d1, 'active');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender(d1, 'ann', true, t0) ->> 'verdict' = 'multi_member', 'the same address active in two tenants = multi_member (pending until a person chooses)');
  PERFORM pg_temp.cp7_ok(cp.resolve_sender('Bad Domain', 'ann', true, t0) ->> 'verdict' = 'unknown' AND cp.resolve_sender(NULL, 'ann', true, t0) ->> 'verdict' = 'unknown' AND cp.resolve_sender(d1, NULL, true, t0) ->> 'verdict' = 'unknown' AND cp.resolve_sender(d1, 'ann', NULL, t0) ->> 'verdict' = 'unknown' AND cp.resolve_sender(d1, 'Ann', true, t0) ->> 'verdict' = 'unknown', 'odd input answers unknown');
  PERFORM pg_temp.cp7_ok(NOT EXISTS (SELECT 1 FROM (VALUES ('ann'), ('stranger'), ('gone')) v(l) WHERE NOT (cp.resolve_sender(d1, v.l, true, t0) ->> 'verdict' = ANY (ARRAY['resolved','shared','unknown','ambiguous','multi_member','unaligned']))), 'every answer is a word of the closed list');
  PERFORM pg_temp.cp7_ok(has_function_privilege('cp_lookup', 'cp.resolve_sender(text,text,boolean,timestamptz)', 'EXECUTE') AND NOT has_function_privilege('public', 'cp.resolve_sender(text,text,boolean,timestamptz)', 'EXECUTE'), 'cp_lookup may run it, PUBLIC may not');
  PERFORM pg_temp.cp7_ok((cp.tenant_info(o1) ->> 'exists')::boolean AND cp.tenant_info(o1) ->> 'name' = (SELECT left(regexp_replace(coalesce(n.name, ''), '[[:cntrl:]]', '', 'g'), 120) FROM public.orgs n WHERE n.id = o1), 'T4e: a real company answers exists + its name');
  PERFORM pg_temp.cp7_ok(NOT (cp.tenant_info(gen_random_uuid()) ->> 'exists')::boolean AND NOT (cp.tenant_info(NULL) ->> 'exists')::boolean AND NOT (cp.tenant_info('00000000-0000-0000-0000-000000000000'::uuid) ->> 'exists')::boolean, 'T4e: unknown, null and nil UUIDs answer exists = false');
  PERFORM pg_temp.cp7_ok(has_function_privilege('cp_lookup', 'cp.tenant_info(uuid)', 'EXECUTE') AND NOT has_function_privilege('public', 'cp.tenant_info(uuid)', 'EXECUTE'), 'T4e: only cp_lookup may ask');
  RAISE EXCEPTION 'AD31 selftest passed, rolling back' USING ERRCODE = 'P0AU2';
EXCEPTION WHEN SQLSTATE 'P0AU2' THEN RAISE NOTICE 'AD31 selftest: ALL RULES PASSED (rows rolled back)';
END $$;
