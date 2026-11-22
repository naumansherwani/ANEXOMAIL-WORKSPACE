# RULE 52 = ADVANCE TECHNOLOGY FOR ANEXOMAIL (his order 23 Nov 2026 02:38 PKT; the rule's NAME is now "ADVANCE TECHNOLOGY FOR ANEXOMAIL")
His text, kept as he wrote it: **A Rust WebAssembly Kernel, one kernel for the whole site.** Backend engine: Rust, Tokio async runtime, Axum. Advance network layer: live WebTransport over UDP, QUIC native pipeline, HTTP/3, Media over QUIC (MoQ, IETF standards track) with seamless cross-protocol HTTP fallback. Website: React 19, TypeScript, TanStack Start and Router, Vite 8, Tailwind CSS 4, Radix / shadcn, Framer Motion, GSAP, Three.js with 3D cinematic frontend. Data and files: PostgreSQL with row-level security, Hetzner Storage Box for attachments, ClamAV virus scanning. Encryption: AES-256-GCM only (TLS 1.3 suite TLS_AES_256_GCM_SHA384; SHA-256 is the hash of every chain, HMAC and HKDF).
Rule 52 in one sentence: every answer, frame and lookup is signed by the server (Ed25519) and verified in the browser by the Rust WASM kernel; a requests carries an HKDF/HMAC MAC + replay nonce; any doubt = refused, never an old or unverified answer.
Notes: HTTP/3 is the ONLY HTTP protocol (no h2, no HTTP/1.1; his 13 Nov 20:30 word). No WebSocket, no Bun/Node in any server runtime, no third-party vendor (Caddy, Namecheap by his hands, Hetzner, his own Rust only). A listed technology missing from code = OPEN GAP, never GREEN.

## Everything advance that the repo lists (law = his word; "Desk today" = what runs on the Admin Desk with proof, 23 Nov 2026)
| Layer | Technology (law) | Admin Desk today | Where else (see its phase file) |
|---|---|---|---|
| Kernel | One Rust WebAssembly kernel per site, verifies in the browser (Rule 52) | LIVE: Desk-own kernel (verify_answer, verify_frame, lookup_view), live sha 6dc834aa... = repo | founder + awam: own kernels |
| Backend | Rust, Tokio, Axum 0.8, systemd-hardened own binary | LIVE `anexomail-desk` | founder `anexomail-founder`, awam `anexomail-rust` |
| Network | HTTP/3 (quinn + h3) + QUIC native pipeline | LIVE on UDP 4400 (server proof); browser page still h2 = phase 1a OPEN | founder UDP 443 |
| Network | WebTransport live over UDP | LIVE /wt/bridge (QUIC, signed frames, seq, 12 s stale) | founder K6 |
| Network | Media over QUIC (MoQ) | NOT built (phase 1n F) | later phases |
| Transport crypto | TLS 1.3, AES-256-GCM only, X25519MLKEM768 hybrid post-quantum key exchange on every TLS/QUIC listener | LIVE (Desk listener + Control Plane client) | founder K4, awam K5 |
| Signatures | Ed25519 now; ML-DSA hybrid with Ed25519 next | Ed25519 LIVE; ML-DSA hybrid NOT built | founder GAP 2 |
| Mail crypto | OpenPGP PQC (RFC 9980), MTA-STS, DANE | not in Desk scope | founder/awam mail phases |
| Sessions | Argon2id, passkeys/WebAuthn, DBSC device-bound sessions | Argon2id LIVE; DBSC observe mode (enforce OPEN) | founder passkey LIVE |
| Website | React 19, TypeScript, TanStack Start + Router, Vite 8, Tailwind 4, Radix/shadcn, Framer Motion, GSAP, Three.js | LIVE React 19 + TS + Tailwind 4 + Vite + Three.js + Framer Motion (one build 390/820/1200+) | founder/awam UIs |
| Data | PostgreSQL 16 with row-level security, append-only ledgers, SHA-256 hash chains, RFC 6962 Merkle checkpoints, role with EXECUTE only | LIVE (AD1..AD8, AD4b, CHECK 21/21) | founder + awam schemas |
| Files | Hetzner Storage Box, ClamAV virus scanning | Storage Box LIVE (signed audit copies); ClamAV not in Desk scope | attachments: founder/awam |
| Fail-closed | deadline, freshness, breaker, no-store, D20 DB-down | LIVE (D5a-5, 1i GREEN) | Desk only |
Dated proof table for the Desk: docs/claude/admin-desk/RULE-52-LIVE-TECHNOLOGY-23NOV.md. Update both files after every GREEN phase.

## Which primitive is the strongest? (his question 23 Nov 2026 02:46; web search + standards knowledge, honest)
- Cipher: AES-256-GCM is a top-tier NIST/CNSA 2.0 approved standard (quantum-safe at 256-bit: Grover only halves it to ~128-bit). ChaCha20-Poly1305 is equally secure (better without AES hardware). AES-256-GCM-SIV / XChaCha20-Poly1305 add nonce-misuse safety for STORED data. No cipher is "more secure" in a practical sense; the risks are nonce reuse and key handling, not the cipher.
- Hash: SHA-256 is unbroken (collision 128-bit, quantum collision still strong). Stronger-by-margin: SHA-384/512 (CNSA 2.0 asks for SHA-384+ for top secret, and the TLS suite we use already uses SHA-384) or SHA3-256/SHAKE256 (different design, hedge). BLAKE3 = fast, not NIST. Changing our audit chain hash would break every existing chain, so it stays SHA-256 unless he orders a versioned chain.
- Key exchange: X25519MLKEM768 (ML-KEM-768, NIST FIPS 203) is what we run. The highest category is ML-KEM-1024 (CNSA 2.0); browser support for a hybrid with it is limited, so NOT in code.
- Signatures: Ed25519 today (not quantum-safe). The advance step is ML-DSA (FIPS 204) hybrid with Ed25519, and SLH-DSA (FIPS 205) as the conservative hash-based option: OPEN GAP (GAP 2).
