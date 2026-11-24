# B13 T4: MANUAL COMPANY EXCEPTION WITH A SECOND REVIEWER, POINT LIST BEFORE CODE (25 Nov 2026 02:0x PKT, his 01:54 order "B13 T4: pehle web research aur plan, phir SQL AD34, Rust aur screen")
ADVANCE TECHNOLOGY (his law, DUNIYA KA ADVANCE SQL + ADVANCE CODE): PostgreSQL 16 proposal-and-decision state machine (SECURITY DEFINER, fixed search_path, forced RLS, REVOKE PUBLIC, one open proposal per case by partial unique index, advisory transaction lock per case, requester <> decider by CHECK and by function, 24 h expiry, append-only decisions with SHA-256 hash chain through the existing ledger kinds, selftest + CHECK); Rust Tokio + Axum staff doors over HTTP/3 (TLS 1.3 AES-256-GCM, X25519MLKEM768), passkey-bound staff session (webauthn-rs, DBSC), Rule 52 signed request RFC 9421 + IETF WIMSE where a call leaves the Desk; React 19 + TypeScript screen through the Rust WASM kernel verify (same words on 390 / 820 / 1200+).
RULE 52 COMBO: S= every door answer carries the request id and is verified by the kernel (RFC 9421 style signed envelope as in T3b) | M= not touched (no mail path; the sender evidence of T3 stays the only mail input) | L= OWASP Logging: every proposal, approval, denial, expiry and refusal is a ledger line (who by role, case ref, tenant UUID, closed reason word, never free text content).

## WEB RESEARCH (25 Nov 2026, two searches; conclusions kept to what the standards say)
Sources looked at: NIST SP 800-53 AC-5 Separation of Duties (UpGuard control page); NHIMG guides "dual control and four-eyes approval" and "what breaks when a single approver can complete a sensitive identity action" and "who is accountable when a user can both request and approve privileged access"; thoughtbot "Inserting State Transitions in Postgres"; AppMaster "tamper-evident audit trails in PostgreSQL".
POINTS TAKEN INTO T4:
1. AC-5: the person who proposes a manual company binding can never be the person who approves it; enforced in the DATABASE (CHECK + function), not only in the screen. (T4a)
2. Four-eyes means TWO different ACTIVE staff, EACH holding case.assign at decision time (AD30 fadm_case_bind already re-checks both; T4 re-checks at propose time and at decide time). (T4a)
3. A proposal is a state machine: pending -> approved | denied | expired | withdrawn; every state change is an append-only decision row; no UPDATE of a decided proposal. One open proposal per case (partial unique index) so two people cannot race two different tenants. (T4a)
4. A proposal expires (24 h): an old approval request cannot be rubber-stamped days later; expiry is evaluated by the database clock when a decision arrives and by a read-only sweep. (T4a)
5. The proposer must give a reason from a CLOSED list (customer_emailed_from_other_domain, new_domain_not_yet_verified, forwarded_mail, staff_checked_contract, other_with_note) plus a short note (<= 200 chars); the note is stored but NEVER written into the ledger line (data minimisation). (T4a)
6. The tenant UUID must exist in the Control Plane (T1 registry); the Rust door asks the signed lookup before calling the proposal function, and the database refuses a UUID that is NULL or nil. (T4b)
7. The decision binds through the EXISTING writer desk.fadm_case_bind(..., 'manual_exception', proposer, decider, evidence) so there is ONE writer of bindings (AD30 stays the only door; T4 never inserts into fadm_case_binding). (T4a)
8. Idempotent + concurrency-safe decision: the same approve twice is a success that writes nothing; approve and deny racing on one proposal queue on the per-proposal advisory lock, the first wins, the second gets 'already_decided'. (T4a)
9. Staff screen shows ONLY: case ref, proposed company UUID short form + the company name AS THE CONTROL PLANE ANSWERED, reason word, proposer role, time left; no customer data, no mail text. (T4c)
10. Rollback: all additive (new table + functions + two ledger kinds); flag DESK_TENANT_BIND already gates the whole B13 family; dropping AD34 objects leaves AD30..AD33 working.

## SUB-STEPS (each its own step, gate checked, GREEN only with proof)
| Sub-step | What | Where | State |
|---|---|---|---|
| T4a | AD34 SQL: desk.fadm_bind_proposal (+ decisions), fadm_bind_propose, fadm_bind_decide, fadm_bind_withdraw, fadm_bind_pending reader, ledger kinds, selftest, CHECK | docs/claude/admin-desk/sql/AD34.sql + checks/AD34-check.sql | NEXT (scratch PostgreSQL 16 twice) |
| T4b | Rust staff doors (propose, decide, withdraw, list) + Control Plane tenant existence check + unit tests | docs/claude/admin-desk/server/src (new bind_exception.rs, route in main.rs) | after T4a |
| T4c | Screen: "Company confirmation" panel (propose form, pending list, approve / deny), words file + bun tests | founder-web/src/desk (new DeskBindException.tsx, desk_bind_pure.ts) | after T4b |
| T4d | install + his desk-install paste + my live Chrome look (desktop + phone 390 / tablet 820) | scripts | after T4c |
