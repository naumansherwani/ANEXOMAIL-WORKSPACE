# RULE 52 + THE ADVANCE TECHNOLOGY RUNNING ON THE ADMIN DESK (updated 23 Nov 2026 02:3x PKT, his order 02:20)
Rule 52 (unchanged in meaning, extended today): EVERY Desk answer, stream frame and lookup is Desk-signed (Ed25519) and verified by the Desk's OWN Rust WASM kernel in the browser; requests carry the HKDF/HMAC MAC + replay nonce; since D5a-5 a customer lookup reaches a screen only through the kernel's `lookup_view` (fresh 15 s vs the Desk's signed time, this request id, this company, HTTP 200). Any doubt = "Data unavailable", never an old answer.

## What is REALLY running on the Desk today (each line has its proof; nothing here is a wish)
| Layer | Technology | Proof |
|---|---|---|
| Backend | Rust 2024, Tokio, Axum 0.8, own binary `anexomail-desk`, systemd-hardened | live on his server |
| Network | HTTP/3 (quinn + h3) on UDP 4400, TLS 1.3, AES-256-GCM only, X25519MLKEM768 hybrid post-quantum key exchange; WebTransport (QUIC) /wt/bridge | his server H3CHECK OK; browser page still h2 (phase 1a open, browser side) |
| Rule 52 | Ed25519-signed answers + frames, HKDF/HMAC request MAC, replay nonce, Desk-own Rust WASM kernel (verify_answer, verify_frame, lookup_view) | live kernel sha 6dc834aa... = repo build, 23 Nov 02:3x |
| Sessions | Argon2id, constant-time, HttpOnly cookie, DBSC device binding (observe mode) | live; DBSC signed-in proof open |
| Database | PostgreSQL 16, row-level security, role `desk_app` with EXECUTE only, append-only ledgers, SHA-256 hash chains, RFC 6962 Merkle checkpoints, audit-first lookup (AD4b) | his CHECK 21/21 |
| Outside copy | Ed25519-signed checkpoint files on disk AND his Hetzner Storage Box, verified without the database, timer every 10 min | his paste: AUDIT EXPORT OK on both |
| Control Plane | own process UDP 127.0.0.1:4410, signed answers, replay/wrong-key refused | LOOKUP SELFTEST OK |
| Fail-closed (D5a-5) | 6 s deadline, 15 s freshness, circuit breaker, no-store, one unavailable shape, D20 DB-down tests | 62 server + 9 kernel tests; live bundle + kernel = repo |
| Web | React 19, TypeScript, Tailwind 4, Three.js (lazy), Framer Motion, Vite 8, one build for 390/820/1200+ | live bundle desk-C-GRp42D.js |
## Listed for the Desk but NOT yet in code (open gaps, never called green)
- Browser HTTP/3 page load (phase 1a): Alt-Svc is live, Chrome still shows h2.
- ML-DSA + Ed25519 hybrid signatures and OpenPGP PQC on the Desk: not built.
- MoQ stream infrastructure (phase 1n F).
- DBSC enforce mode (observe only today).
