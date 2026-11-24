# B13: HIS ADVISOR'S DECISION (verbatim in TENANT-IDENTITY-CONSENT-DECISION-24NOV.md) vs THE CODE, line by line (24 Nov 2026 09:2x PKT, his order 09:20: "is phase ke related ChatGPT ki baatein likhi hain repo read kero")
Status words: DONE = in code and tested; WRITTEN = in code, tested on scratch, not installed; STEP = its own later step (T3..T6), not forgotten.

| Advisor point | Where it lives | Status |
|---|---|---|
| Verified domain = the automatic source; sender membership/alias also verified | T1 AD26 (domain ownership history, GREEN on his server); T3 resolution function | T1 DONE, T3 STEP |
| Case binds ONE immutable canonical tenant UUID, NOT NULL for resolved | AD30 desk.fadm_case_binding (case = primary key, tenant_id NOT NULL, three freeze triggers) | WRITTEN |
| Foreign key to tenant registry | Deviation stated openly in AD26/AD30: the registry is in the AWAM database, a cross-database key is impossible and would block account erasure; the Rust door proves the UUID against the Control Plane before it calls fadm_case_bind | WRITTEN (T3 adds the proof call) |
| Source, actor, timestamp, evidence on every resolution | AD30 columns source, actor, reviewer, evidence (closed object, 2,000 bytes), bound_at + ledger line 'case.bound' | WRITTEN |
| Unresolved case stays PENDING_TENANT_RESOLUTION; no consent request | AD30: no binding row = unresolved (fadm_case_tenant returns NULL); fadm_consent_request refuses it; Rust door answers not_bound; screen says it in words | WRITTEN |
| Case creation is NOT blocked when unresolved | Nothing in AD30 touches case creation | DONE |
| Manual exception by authorized staff, SECOND reviewer, independent verification against the registry | AD30 CHECK + function: two different active staff, both with case.assign; registry proof = T4 Rust door + screen | SQL WRITTEN, T4 STEP |
| Shared/free domains never auto-match | AD26 cp.shared_domain (GREEN) used by T3 | T1 DONE, T3 STEP |
| Domain claimed by two tenants: reject and quarantine | AD26 EXCLUDE (never two owners at once, GREEN); quarantine list = T3 | T1 DONE, T3 STEP |
| Sender in several tenants: explicit verified selection | T3 + T4 | STEP |
| Tenant changes domain: versioned history, old cases never change | AD26 history (GREEN) + AD30 immutability (a bound case never moves) | DONE / WRITTEN |
| Correction of a wrong binding: separate dual-approved audited procedure, never silent | T5 (new row type, never UPDATE; AD30 trigger refuses UPDATE and DELETE on purpose) | STEP |
| Consent bound to case_id, tenant_id, company admin identity, scope, issue time, expiry, unique id | CP5 consent inbox already binds org + case + scope + window + passkey digest + ledger hash (GREEN); Desk side: consent request needs a binding (AD30); the push carries fadm_case_tenant(case) in Z4b-3; "same tenant and case on both databases" test = T6 | PARTLY DONE, T6 STEP |
| Every data access re-checks consent, tenant match, scope, expiry, revocation | AD20 fadm_consent_open (existing); the tenant-match re-check on open = T6 | STEP |
| Idempotent and concurrency-safe operations | AD30 fadm_case_bind: same answer twice = success, writes nothing; per-case advisory lock; another tenant refused (added 09:2x after reading the advisor text) | WRITTEN |
| Append-only security audit | AD30 ledger lines case.bound / case.bind_refused on the SHA-256 chain | WRITTEN |
| Fail closed on database, identity or authorization failure | AD30 refusal paths; Rust door 503 data_unavailable on any other error; Z4b-2 client Reject::Unavailable | WRITTEN |
| No fuzzy matching, no cross-tenant fallback, free-text company_ref is a hint only | AD30 never reads company_ref | WRITTEN |
| Migration plan, threat model, rollback plan, automated cross-tenant isolation tests | D6-B13-T0-SCHEMA-THREAT-ROLLBACK-24NOV.md (plan, threat model, rollback, GREEN as document); isolation TESTS = T6 | T0 DONE, T6 STEP |
| Not-yet-tested in AD30 (honest): the positive manual path needs a granted case.assign right | T4 | STEP |
