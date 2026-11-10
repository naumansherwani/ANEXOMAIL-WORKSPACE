# D2b PLAN: Devices & Sessions, the Rust half (11 Nov 2026 00:50 PKT; founder order 00:44: technology at the repo top first, world-advanced code, SQL only if needed, then code)
SQL: NONE needed. E155 + E156 are GREEN on his server and carry every door. This phase is Rust only (server/founder). No SQL number is used; next free stays E157.
## Technology (written BEFORE the code)
- Rust, axum 0.8 + tokio, `ring` (SHA-256), reqwest to the existing PostgREST RPC doors (`Sb::rpc_msg`). No Bun, no Node, no WebSocket.
- Session id is never stored: only SHA-256 of the minted session id (sid_hash). Device hash from K7 (DBSC/webcrypto device key), key proof fingerprint from E150.
- Per-request gate: `founder_session_check` cached 3 s per sid_hash in an in-memory map (bounded size, entries dropped on revoke/tick); a closed state (revoked, expired, drift_revoked, geo_outside, flapping_revoked, integrity_revoked) ends the request with the SAME generic refusal as a bad session.
- Country: local MaxMind-format file read once at start (path env FOUNDER_GEOIP, optional); no file = country null, no per-request network call. SQL then fails closed for new devices under enforce, admitted sessions are never killed by an unresolved country (proved in the E156 selftest).
- Protocol badge from the connection (quic via the WebTransport front / h2 / h1), kernel from the SPA header X-Founder-Kernel, UA family from User-Agent, engine hint from Sec-CH-UA: families only, raw strings never stored.
- Policy change needs a fresh passkey touch (same ceremony as sign-in); everything else is session-authenticated.
- Hourly tick: `founder_session_tick` then `founder_session_anchor` (ledger head into the audit chain).
- Tests: cargo test with a loopback World stand-in that models REAL column/function grants (lesson of the passkey 503).
## Loopholes to close in this phase (R1-R8)
R1 register failure must not leave a half-signed-in session (refuse + end identity session). R2 cache must never outlive a revoke (drop on revoke/revoke-others/policy change). R3 trusting a client header for kernel/UA is fine only as a CLAIM (drift detection), never as proof. R4 key fingerprint passed to check ONLY when Rust verified the key proof. R5 rate: one RPC per sid per 3 s max. R6 policy endpoint refuses without a fresh passkey touch and without a reason. R7 errors never leak sid_hash or SQL text. R8 tick/anchor failures logged as journald stage lines, never crash the server.
## Order: D2b-1 module `sessions.rs` + stand-in tests -> D2b-2 wire register into signin.rs release -> D2b-3 gate + cache -> D2b-4 endpoints + tick -> cargo all green -> his founder-install line -> D3 UI -> D4 live 390/820/1200+.
## AWAM line (moulded later, never mixed): see AP9 in AWAM-PASSKEY-ONLY-PLAN-10NOV.md. The Rust module is written generic over "who is the principal" so the awam copy only swaps table names, plan caps and wording.
