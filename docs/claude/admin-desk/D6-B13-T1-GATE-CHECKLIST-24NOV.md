# B13 STEP T1 GATE CHECK LIST (24 Nov 2026 07:3x PKT; his 07:25 word: write the points first, tell the gates, follow the rules that already exist). Written BEFORE any T1 code. T1 = the TENANT REGISTRY CHECK + VERSIONED DOMAIN OWNERSHIP (awam database, schema cp, file docs/claude/admin-desk/sql/AD26.sql).
## A. THE RULES THAT ALREADY EXIST AND T1 FOLLOWS (each is a gate or a law; where it is checked)
| # | Rule | Where | How T1 meets it |
|---|---|---|---|
| 1 | SQL WORLD-CLASS (his 23 Nov 06:01): web research, list, ADVANCE-RESEARCH, CURRENT.md, read older SQL, header SCHEMA-FIRST / ADVANCE-RESEARCH / CHECK-FILE, selftest, forced RLS, REVOKE PUBLIC | gate "SQL WORLD-CLASS" | headers + selftest + check file in AD26.sql |
| 2 | SQL SCHEMA-FIRST (20 Nov 20:35) | docs/claude/SQL-SCHEMA-FIRST-LAW-20NOV.md | header names AD07 (fadm_case), public.org_domains (+ its unique index org_domains_domain_active_uq), public.orgs, CP4/CP5 |
| 3 | RESEARCH IN BLUEPRINT (23 Nov 03:1x) | gate "RESEARCH IN BLUEPRINT" | ADVANCE-RESEARCH line written in the blueprint BEFORE the commit |
| 4 | FUTURE-PROOF (23 Nov 06:42): no "not measured", real signal from real tables, zero is data | gate "FUTURE-PROOF" | counts come from the real tables; zero rows is a number |
| 5 | NO INCOMPLETE WORK (22 Nov 20:36): every listed advance technology IN CODE before commit | gate "INCOMPLETE ADVANCE" | every technology in the contract row below is in AD26.sql |
| 6 | NO TEST NO COMMIT (23 Nov) | gate | scratch PostgreSQL 16 selftest + check run; ledger line says TESTED |
| 7 | PHASE FILES: contract names SQL, Rust and screen files that exist | gate "PHASE FILES" | T1 is SQL only; the Rust and screen files named are the existing ones and are marked unchanged |
| 8 | BILLIONAIRE LIST + ORDER-LOCK + DASHBOARD-FIRST | gate | heading names BL-46 (B13) and BL-28 only |
| 9 | DESK ISOLATION (21 Nov): nothing of the founder in the Desk | gate | T1 lives in the awam database schema cp, read-only for the Desk through the Control Plane; no founder table, key or door |
| 10 | EDIT ONLY docs/claude/admin-desk/ for Desk scripts (root admin-desk/ is a mirror) | README rule 24 Nov | installer edit goes in the source folder, sync checked after |
| 11 | Server command = ONE line, plain ASCII, no quotes | founder law | one desk-install line |
| 12 | Rule 52, HTTP/3 only, no vendor, no WebSocket | founder law | no new transport in T1 |
## B. T1 POINTS (what AD26.sql must contain; every point is checked by the CHECK file)
1. cp.domain_ownership: append-only history, one row per (org_id, domain, valid_from) with valid_to NULL while current, source ('org_domains.verified' only), evidence (verified_at copied, never a token), forced RLS no policy, REVOKE PUBLIC.
2. Closed rule by EXCLUDE USING gist (domain WITH =, tstzrange(valid_from, valid_to) WITH &&): one domain can never belong to two tenants at the same time; ranges of one domain can follow each other (a domain moves) but never overlap.
3. FK to the registry: org_id REFERENCES public.orgs(id) (canonical tenant UUID decided in T0); a domain of an org that is not in orgs is refused.
4. cp.domain_ownership_sync(): reads public.org_domains (status verified, not removed) and APPENDS history: opens a row for a newly verified domain, closes (valid_to = now) the row of a domain that is removed or moved. No trigger on any awam table (awam schema untouched, additive only). Idempotent. Ledger line before each change (reuse the CP5 hash-chain pattern in its own ledger cp.tenant_ledger).
5. Shared / free mail domains list (closed table cp.shared_domain, seeded with the well-known free providers, forced RLS): a domain on it can NEVER be opened as an ownership row (CHECK by trigger). Reason: shared domains never auto-match (decision rule 4).
6. cp.tenant_of_domain(p_domain text, p_at timestamptz): returns the ONE tenant UUID that owned the domain at that moment, or NULL (unknown, shared, two claimants impossible by point 2). STABLE SECURITY DEFINER, fixed search_path, shape check on the domain, no other output.
7. cp.tenant_registry_check(): read-only report (counts only): orgs, organisations, account_organisations, orgs missing in organisations, orgs missing in account_organisations, domains verified, domains with an open history row, domains verified but missing history, overlapping ranges (must be 0). The proof that the three company tables do not disagree.
8. Roles: cp_lookup (the Control Plane) may EXECUTE tenant_of_domain and tenant_registry_check only; the sync runs as the owner (installer) and by a Control Plane timer door later; PUBLIC nothing; the Desk never touches these tables.
9. Selftest inside the file (rolled back, ALL RULES PASSED): moves a domain, refuses overlap, refuses shared domain, refuses unknown org, tenant_of_domain at two moments gives two tenants, sync idempotent, ledger chain verifies.
10. CHECK file docs/claude/admin-desk/sql/checks/AD26-check.sql: every row true on his real database; one FACT row prints the real counts.
11. Installer step 3f in docs/claude/admin-desk/scripts/cp-install.sh (source folder) + synced mirror; WARN (not stop) if CP6 fails; tenant binding then stays closed.
## C. WHAT T1 DOES NOT DO
No case binding (T2), no automatic resolution of a sender (T3), no Rust, no screen, no awam trigger or awam table change, no consent push. B13 and Z4b-3 stay NOT green.
## D. PROOF TO COLLECT
Scratch PostgreSQL 16: selftest ALL RULES PASSED + CHECK all true; then his desk-install paste (CP6 selftest + CHECK rows) and the FACT counts line. GREEN only after that paste.
