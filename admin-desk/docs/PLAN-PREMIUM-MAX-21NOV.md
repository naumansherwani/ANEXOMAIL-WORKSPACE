# PLAN R3p: Business Premium + Business Max support lanes in the Admin Desk (written 21 Nov 2026 09:10 PKT, his word 09:02)
His words: "yeh mix nahi ho jaye awam ke saath, is ka plan bana lete hain, pehle Business Premium aur Business Max, is pe sirf FOUNDER wali advance technology aur ..." (the sentence ended there in his message; waits for the rest).
## NO MIX WITH AWAM (the rule for this whole plan)
- The Desk never reads awam tables, never imports awam code, never shares an awam key. A company's plan reaches the Desk ONLY through the Polar signed webhook (Rust door in the Desk, own secret) and is stored in the Desk's own tables (fadm_*).
- Awam files stay frozen. The isolation gate (lanes/lane-sync.py) and the Desk tech gate (admin-desk/gates) fail the commit on any mix.
## TECHNOLOGY = ONLY THE FOUNDER STACK (no awam technology)
RUST + TOKIO + AXUM (webhook door, SLA engine), HMAC-SHA256 signed webhook check in constant time, POSTGRESQL RLS + hash-chained append-only ledger (SQL AD series), REACT 19 + TANSTACK VIRTUAL + KERNEL RPC (Rule 52: every browser call signed and verified in the one Rust WASM kernel), ARGON2ID + DBSC for sessions, HTTP/3 + X25519MLKEM768 at stage 2. Time clocks are server-side Rust (business days), never browser time.
## WHAT THE TWO PLANS ARE (from docs/claude/AWAM-PACKAGES-PROPOSAL-07NOV.md; recommendations, his call): Business Premium GBP 21,000 / month, 7,000 seats; Business Max GBP 125,000 / month, "unlimited" seats with a hard cap of 125,000 users per company (alert at 90% / 95%, no block).
## SUBPHASES (each row: FEATURE / CODE / TECHNOLOGY / HAAN)
| Sub | Feature | Code | Technology | Haan |
|---|---|---|---|---|
| R3p0 | Support terms for Premium and Max (first-response hours, named contact, escalation path, emergency cover, quarterly review) | admin-desk/docs (his words, not invented) | his decision | NO: needs HIS terms |
| R3p1 | Plans as data + company plan record + plan-change history | admin-desk/sql/AD2.sql (fadm_plans, fadm_company_plan; after AD1; schema-first) | POSTGRESQL RLS, APPEND-ONLY SHA-256 HASH CHAIN, desk_app grants only | NO |
| R3p2 | Polar signed webhook door: plan start / change / cancel for a company | admin-desk/server/src/polar.rs | RUST TOKIO AXUM, HMAC-SHA256 constant-time, replay window | NO |
| R3p3 | Premium and Max lanes in the shared inbox (label, priority above lower plans, named contact shown) | founder-web/src/desk (lane list) | REACT 19, TANSTACK VIRTUAL, KERNEL RPC | NO |
| R3p4 | SLA clock per plan (starts at the customer's message, stops only on a human reply or resolve) | admin-desk/server/src/sla.rs | RUST TOKIO timers, business-day calendar | NO |
| R3p5 | Named-contact record + quarterly service/security review record (due dates, proof) | AD2 + Desk screen | POSTGRESQL, hash-chained ledger | NO |
| R3p6 | The other four plans (Basic, Pro, Business, Business Pro) = more rows in fadm_plans, no new code | AD2 rows | data only | NO (after Premium/Max are real) |
Order: after R3a2 (AD1 + login door). Gate rows added in admin-desk/gates/DESK-FEATURES.json (planned, FAIL from 24 Nov 2026 if the technology is still missing).
