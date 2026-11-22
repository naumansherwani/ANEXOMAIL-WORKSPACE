# GREEN TABLE (his 20:23 order "GREEN LIKHO"; refreshed 22 Nov 2026 21:05 PKT). Two honest levels, never mixed
- SQL GREEN = the SQL file ran on his server and its CHECK printed every row true (his own paste).
- CODE GREEN = Rust / TS code written, tests pass in my sandbox, committed and pushed (not yet on his server until his desk-install + desk-restart).
- PHASE GREEN = WIRED: YES / REAL: YES / TECH-LAW CHECKED after my live Chrome look at 390 / 820 / 1200+ (his standing law). Only then the word GREEN stands alone.
| Item | Advance technology | SQL | CODE | PHASE |
|---|---|---|---|---|
| AD1 identity, units, sessions | PostgreSQL 16 forced RLS, Argon2id, hash-chained ledger | GREEN (live, CHECK OK) | GREEN (login, me, logout doors) | live, in use |
| AD2 actions + policies | deny-by-default fadm_need / fadm_authorize | GREEN | GREEN (via doors) | live, in use |
| AD3 alerts + bridge data | SECURITY DEFINER doors, pinned search_path | GREEN | GREEN (bridge.rs) | Dashboard first cuts live |
| AD4 lookup audit + burst breaker | append-only lookup ledger, burst limit | GREEN | GREEN since 20:42 (lookup.rs, step D5a-3) | NOT GREEN: Control Plane address + key not given |
| AD5 addresses + mailbox roles | PostgreSQL trigger guards, grants | GREEN | none (Mailboxes folder FROZEN) | NOT GREEN |
| AD6 package registry | versioned, frozen rows, no money columns | registry SQL live; D5a-2 seed AD6b + Rust doors installed (his pastes 22 Nov ~21:45 PKT) | none (his count paste 21:54 PKT: 7 packages, v1, grace 3; sealed door live in my Chrome); first on-screen use = D5 screen | GREEN (D5a-2, 22 Nov 21:54 PKT: WIRED: YES / REAL: YES / TECH-LAW CHECKED); D5a list as a whole still open (3, 4, 5) |
| AD7 cases | state machine trigger, append-only events | GREEN | none (Cases folder FROZEN) | NOT GREEN |
| D5a-3 signed lookup door (client side in the Desk) | Rust Tokio axum 0.8, quinn + h3 client (TLS 1.3, AES-256-GCM, X25519MLKEM768), ed25519-dalek, Rule 52, fail closed | no new SQL | GREEN: cargo 41 passed; LIVE on his server since his install paste 20:5x (kid e92a4cb169d466a2, same build as origin/main); my Chrome look 20:54: route exists, no session = 400 unsigned_request | NOT GREEN: no responder to ask (D5a-3b) |
| D5a-3b Control Plane lookup responder (the other end) | Rust Tokio axum 0.8, quinn + h3 server, ed25519-dalek, own key | read-only view, schema-first | NOT WRITTEN (contract written, all rows no) | NOT GREEN: needs his fresh ss -ulnp paste for the UDP port |
| Desk page protocol | HTTP/3 only (his 21 Nov law) | | Chrome 20:54 shows h2 for the Desk (public curl HTTP/2 via Caddy TCP 443, Alt-Svc h3=:4400 set, DNS HTTPS record empty) | OLD GAP, not part of D5a-3, stays open |
| DASHBOARD FOLDER as a whole | see DASHBOARD-FOLDER-ORDER-22NOV.md | | | NOT GREEN: steps 2..9 open |
