> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# F2c — Audit Merkle (E107) — design note (master order step 5, founder order 1 Nov 08:11)

Master order: `FOUNDER-MASTER-ORDER-28OCT.md` step 5. Nothing is inserted before or after it. This note is Rule 63's "design first".

## What exists (do not rebuild)
- E102: `founder_audit` (seq, hash, prev_hash, append-only trigger), `founder_audit_append`, `founder_audit_verify`, `founder_audit_head`. Hash v1 = sha256 of length-prefixed fields.
- Rust `audit.rs`: chain + HMAC. WASM kernel `web-wasm/`: `hash.rs`, `ed.rs` (verify), no Merkle yet.

## What F2c adds
1. **SQL E107 (>=800 lines, + CHECK_E107):** `founder_audit_merkle_root(p_from,p_to)`, `founder_audit_merkle_proof(p_seq)` (inclusion path), `founder_audit_checkpoint` (append-only table of signed roots per N rows, hash-chained), `founder_audit_export(p_from,p_to)` (rows + root + proof set), selftest. RLS on, service_role only, pinned search_path.
2. **Tree rule (RFC 6962 style):** leaf = sha256(0x00 || row_hash bytes), node = sha256(0x01 || left || right); odd node promoted, not duplicated (no second-preimage ambiguity).
3. **Rust:** `merkle.rs` (same rule, tests incl. tamper, odd sizes, proof round-trip), routes `/founder/v1/audit/root`, `/audit/proof/:seq`, `/audit/export` (read-only, Ed25519-signed envelope).
4. **WASM kernel `merkle` (Rule 52, one kernel):** verify inclusion proof + root signature in the browser; cargo tests, no JS test runner.
5. **UI:** Dashboard "Ledger Integrity Gauge" (live numbers: rows, last checkpoint, proof verified in this browser) and Audit ledger page row "Verify this entry".
6. **Done = green:** E107 CHECK all OK on server, `cargo test` pass, Chrome shows gauge with a real verified root.

## Out of scope here
S2 (step 6), passkey (7), Decide (8). Mail/People/Systems etc. follow in master-order sequence after step 5 (steps 9–13).

## Order of work
SQL E107 + CHECK -> Rust merkle.rs -> kernel merkle -> UI gauge -> pull commands (sql-run.sh first, then founder-install.sh).
