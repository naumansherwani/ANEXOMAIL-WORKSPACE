# NEXT PHASE: 1m-4 B9 Customers and Plans (written 23 Nov 2026 08:2x PKT; plan = docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md section 1m-4, U1..U12; contract = top block of docs/claude/tech-contracts/CURRENT.md)
Laws that bind it: Rule 52 (Ed25519-signed, kernel-verified, fail-closed "Data unavailable"), FUTURE-PROOF (built once for a big business, never "Not measured", zero is data), SQL WORLD-CLASS (schema-first headers, forced RLS, selftest, REVOKE PUBLIC), no money, Desk isolation (nothing from founder/awam code; awam database read ONLY through the Control Plane read-only role), HTTP/3 only, schema-first.
| Step | What | Advance technology | State |
|---|---|---|---|
| 1 | CP2 SQL: cp.census() counts per package / state / interval / size band, 12-month growth, 6 real "needing you now" signals | PostgreSQL SECURITY DEFINER, read-only role | DONE, installed, CHECK 8 of 8 on his server |
| 2 | Control Plane Rust census method: Ed25519-signed answer, replay nonce, 60 s cache, p_limits pass-through | Rust, Tokio, quinn + h3 (HTTP/3 UDP 4410), Ed25519 | NEXT |
| 3 | AD14 SQL: fadm_census_sample hourly append-only hash-chained series, fadm_census_record, door fadm_customers_board (same right as plan lookup) | PostgreSQL forced RLS, frozen triggers, BRIN, SHA-256 chain | after 2 |
| 4 | server/src/customers.rs + route /desk/v1/customers/census: fresh 15 s, deadline 6 s, breaker, shape check | Rust + Axum 0.8 over sealed HTTP/3 | after 3 |
| 5 | desk_customers_pure.ts (+ tests) and DeskCustomers.tsx, card wired, Ice-blue, small-group note | React 19 + TypeScript, kernel-verified read | after 4 |
| 6 | Proof: cargo + bun tests, tsc, vite build, scratch PG; his ad-auto + desk-install pastes (PROOF census CP2 stays in the last lines); my Chrome look; GREEN | | last |
One commit for steps 2-5 (the gate stops a half-built commit). After B9: B6, B7, B10..B13, then 1n, 1o, 1a, phone 390 / tablet 820, Founder Escalation Inbox, S4 Overview.
