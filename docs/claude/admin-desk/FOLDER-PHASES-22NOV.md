# FOLDER PHASES: THE DASHBOARD PHASES ON THEIR OWN, THEN EVERY OTHER FOLDER IN RAIL ORDER (his 22 Nov 2026 23:3x PKT: "dashboard ke phases alag karo, folder jo account mein hai us ki tarteeb se phases banao"). Written 22 Nov 2026 23:4x PKT.
Rule (DESK-PHASES rule 11, unchanged): rail order = 1 Dashboard, 2 Mailboxes, 3 Cases, 4 Replies, 5 Routing, 6 SLA clocks, 7 Automations, 8 Admin Desk group, 9 Company group. A folder opens only when the one before is whole. Mailboxes onward are FROZEN until Dashboard is whole. The folder of each older phase letter is MY mapping (he corrects me); letters and old ids stay.
## FOLDER 1: DASHBOARD (the only folder open now)
| Step | Phase (old ids) | ADVANCE TECHNOLOGY | State 22 Nov 23:4x PKT |
|---|---|---|---|
| 1a | A Browser HTTP/3 page load | HTTP/3, Alt-Svc, DNS HTTPS record (his Namecheap) | OPEN: Chrome shows h2 |
| 1b | B Bridge doors, C WebTransport stream | Rust axum, Rule 52, h3-webtransport, kernel verify_frame | LIVE |
| 1c | D Command bar, D1, D1c..D1f, D2 alert actions, D3, D3b, D4, D7 Systems, D8 colours, D9 brand link, D10 glow | React 19 + TS, Framer Motion, kernel stream | LIVE / looked |
| 1d | D5a-1 lookup contract + NO-MONEY gate | commit gate, JSON contract | GREEN |
| 1e | D5a-2 package registry (AD6, AD6b, AD6c, AD6d) + Rust read doors | PostgreSQL 16 append-only, Rust axum, Rule 52 | GREEN 22 Nov 22:5x |
| 1f | D5a-3 signed lookup door (Desk side) | Rust, ed25519-dalek, HTTP/3 client, PQ + AES-256 | GREEN 23 Nov 00:5x (his selftest paste) |
| 1g | D5a-3b Control Plane responder (other end) | Rust axum, quinn + h3 server, own Ed25519 key | GREEN 23 Nov 00:5x: his server paste 'LOOKUP SELFTEST OK' (signed answer verified, replay, wrong key, unknown company refused), UDP 4410 live, CP1 CHECK 8/8. WIRED: YES / REAL: YES / TECH-LAW CHECKED. Honest data: package null, service_state not_active_yet, seats 2 (no subscription rows exist yet) |
| 1h | D5a-4 lookup audit proof (AD4) | PostgreSQL audit-first, hash chain | after 1g |
| 1i | D5a-5 fail-closed proof | Rust, test double, kernel stale check | after 1g |
| 1j | D5 Plan context screen | React 19 + TS + Tailwind 4, kernel-verified | after 1h, 1i |
| 1k | D5b runbooks (b1 nine, b2 checklist, b3 say-this + no-promise gate) | React, PostgreSQL versioned runbooks (AD9 planned) | after 1j |
| 1l | D5c Escalate + D6 card | Rust signed hand-over, PostgreSQL (AD10 planned) | after 1k |
| 1m | D6 cards B1..B13, one by one (thin Dashboard data doors) | Rust read doors, PostgreSQL views, kernel stream | after 1l |
| 1n | E Team fan-out, F MoQ (stream infrastructure of the Dashboard) | Tokio broadcast, WebTransport, MoQ tracks | not written |
| 1o | DASHBOARD FINAL | all of the above, look 390 / 820 / 1200+ | closes folder 1 |
## FOLDERS 2 TO 9 (FROZEN, written in rail order, built only after folder 1 is whole)
| Folder | Phases (old ids) | ADVANCE TECHNOLOGY | SQL | State |
|---|---|---|---|---|
| 2 Mailboxes | I Mailboxes (R3b, R4-2): hello, moveyourbusiness, resolved, billing (restricted), leo, noreply; N Mail craft + attachments (R4-3..R4-10): compose, Tiptap 3, undo/schedule, attachments, outbound TLS policy | PostgreSQL RLS, Rust, React virtual list, Tiptap 3, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | AD5 live | frozen |
| 3 Cases | K Cases (R3e): assign, reply, My Work, All Cases, root-cause note | PostgreSQL SKIP LOCKED, Rust, React | AD7 live | frozen |
| 4 Replies | reply templates + say-this text for customers (from N and D5b runbooks) | React, PostgreSQL versioned text | AD8+ | frozen |
| 5 Routing | inbound routing by address role (AD5 fadm_route_inbound) + case assignment | PostgreSQL, Rust SKIP LOCKED | AD5 live | frozen |
| 6 SLA clocks | K SLA (R3f): clock stops only on a human reply or resolve | PostgreSQL SLA engine (AD4 and AD7), Rust | AD7 live | frozen |
| 7 Automations | J Auto mail (R3c): RFC 3834 Auto-Submitted, 7-day per-sender gate | Rust, PostgreSQL | not written | frozen |
| 8 Admin Desk group | P Managed Move-In (R4-11), O CRM (R-CRM), M Hybrid post-quantum (W3), Quality | Rust async IMAP migrator, React, ML-DSA + Ed25519, ML-KEM | not written | frozen |
| 9 Company group | G Org + policy (AD2), H Staff accounts (ON1..ON12), L Transparency log (W1), Audit, and last R Feature release feed + employee accounts (his 22 Nov 22:41) | PostgreSQL tuples + RLS, webauthn-rs, Argon2id, DBSC, Merkle tiles, Rust, React | AD2 live | frozen |
| End | Q Final audit + load proof (re-run after R) | Rust, React | | last |
