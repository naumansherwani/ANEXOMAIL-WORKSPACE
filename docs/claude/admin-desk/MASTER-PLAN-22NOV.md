# ADMIN DESK MASTER PLAN: POINTS -> PHASES -> TECHNOLOGY -> CODE (22 Nov 2026 01:15 PKT, his 01:14 order)
Order he gave: research -> points in blueprint + ledger -> phases with advance technology -> codes. Sources are in the three design docs: SCALE-50K-DESIGN-22NOV.md (S1..S11), WORLD-ADVANCE-DESK-22NOV.md (W1..W10), EMPLOYEE-ACCOUNTS-PLAN-22NOV.md (ON1..ON8). Rule 52 on every row. Desk isolated from founder/awam. Vendor ban. HTTP/3 only.

## Points (one line each)
P1 Every Desk answer signed + kernel-verified (Rule 52). P2 Authorization by relations (Zanzibar-style) with deny-by-default, forbid-wins policy data. P3 Audit = Merkle transparency log, browsers remember the root. P4 Staff = device-bound passkeys only, own keys, no passwords, no fallback. P5 Zero standing privilege, two-person approval, loud break-glass. P6 Awam data masked, reveals ledgered. P7 Team key on every row, partition-ready, RLS as second wall. P8 Cases: queue+skill+priority+SLA, ack-driven reassignment, end-to-end tracing. P9 Live fan-out over WebTransport/HTTP/3 (MoQ model), SSE fallback. P10 Hybrid PQ signing (Ed25519 + ML-DSA-65) after his haan. P11 UI clean: technology invisible. P12 Proof: published load numbers + my live Chrome look 390/820/1200+.

## Build order (each phase: feature | advance technology | his haan)
| # | Phase | Technology | Haan |
|---|---|---|---|
| 1 | R3d: Rule 52 plumbing: Desk Ed25519 signer, Desk-OWN WASM kernel crate, deskCall(), request HMAC, tests (good ok, tampered refused) | Rust axum, ed25519-dalek, hmac/sha2, wasm-bindgen | given (contract in CURRENT.md) |
| 2 | R4-1 shell + dashboard + bridge: clean 3-pane, only REAL data (my identity, sessions, ledger) | React 19, TS, Tailwind 4, own design | given |
| 3 | S1+S2+W2 org + relations + policy engine, SQL E201+ written schema-first | Postgres tuples, RLS, Rust evaluator | needed |
| 4 | ON1-ON4 staff, enrollment code, device-bound passkeys, leaver | webauthn-rs, Argon2id, DBSC | needed (4 questions) |
| 5 | R3b/R4-2 inboxes (hello, moveyourbusiness, resolved...) with team key | Postgres fadm_mailbox, Rust | given |
| 6 | S6/W8 routing + SLA + tracing; auto mail RFC 3834 | Rust routers, SKIP LOCKED | needs his support terms |
| 7 | W1 transparent log; S9 audit | Merkle tiles, signed tree head | needed |
| 8 | S7/W4 live fan-out; browser HTTP/3 gate first | quinn/wtransport | needed |
| 9 | W3 hybrid PQ, W5/W6, ON5-ON7 recovery/review/SCIM | ml-dsa, Rust | needed |
| 10 | compose..shortcuts, attachments, outbound TLS, final audit + S10 load proof | Rust, Storage Box | needed |
Dashboard + bridge are order 2 (his 01:05 word); they use only data that exists.

## ADDED 22 Nov 2026 01:55 PKT (his 01:54 word): CRM INSIDE THE DESK
| # | Phase | What | Technology |
|---|---|---|---|
| CRM1 | R-CRM | The Desk gets a CRM with everything the awam user's CRM has (accounts, leads, pipeline, relationships, tasks, activity, collab, reports, setup: matched to lovable-gold/awam app.crm.* routes) but in COMPANY style: accounts = companies on Anexomail (hello, moveyourbusiness, Premium/Max, axonetis ...), their cases, plan, onboarding/migration pipeline, owner staff, SLA. Written NEW for the Desk (no copy, no import), his Desk isolation + vendor ban. | Rust axum + Postgres (team key + relation tuples S1/S2, RLS), Desk WASM kernel (Rule 52), React 19, Tailwind 4, hash-chained ledger |
Order: after inboxes + case routing (needs real accounts and cases to hang on). Not in code.
