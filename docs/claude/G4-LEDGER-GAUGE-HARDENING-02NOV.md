> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# G4: Ledger seal gauge hardening (E120), 2 Nov 2026

Founder 2 Nov 03:14: "haan ... pehle super advance codes socho ... her ek choti si choti loophole cover ho jaye. technology read kero."
**Repo read first (no duplicate):** the Dashboard gauge "Ledger seal" already exists and has been GREEN in his Chrome since 1 Nov 09:00 (step 5a). So G4 is not a new gauge. It closes the gauge's own loopholes.

| # | Loophole found in the existing gauge | Fix (technology) | Proof |
|---|---|---|---|
| 1 | A dead automatic sealer was invisible when the ledger was quiet | `sealer_stalled` = a seal is DUE and the oldest unsealed entry is older than `stall_secs` (SQL). A quiet ledger below the seal size is NOT a stall: no false alarm | E120 selftest (both directions) |
| 2 | The full chain + seal re-hash ran only when someone opened the Audit page | Rust tick runs `founder_audit_verify_record` when the last full check is older than `verify_every_secs`; SQL records the real result; the gauge shows it and its age; never-run / stale checker = warn; broken chain or seal = fail | selftest + Rust `verify_due` test |
| 3 | A server rolled back to an old backup, or with rewritten history, looked fine | The browser pins the newest seal `{id, upto_seq, root, cp_hash}`; on every load it checks the server still shows the same seal (`/founder/v1/audit/seal?id=`). Fewer seals = ROLLBACK, different content = REWRITTEN, both turn the gauge to fail and the pin never moves forward after them | 11 `sealpin.test.ts` tests |
| 4 | Ages came from the browser clock | The pulse carries `now_ms`; ages are computed on the server clock | selftest |
| 5 | If the browser proof failed to load, the gauge silently said nothing | Shows "browser proof unavailable just now" and warns | test |
| 6 | Only the 5 newest entries were proven in the browser | 2 random OLDER entries are also proven against the root stored in the seal itself (`/audit/merkle/proof?seq=&upto=`) | test + Chrome |
| 7 | A policy typo could switch the alarm off | DB constraint `founder_audit_policy_g4` (stall 60 s..24 h, check interval 5 min..24 h, stale >= 2x interval) | selftest |
| 8 | A flood of ticks could hammer the database | `founder_audit_verify_record` allows one Rust run per 60 s and one at a time (advisory lock) | selftest |

## Honest limits (NOT closed, so never claimed on any page)
- The pin lives in one browser's local storage. It protects against changes AFTER the browser first saw a seal; clearing site data starts the pin again.
- The server still produces both the roots and the proofs. A fully compromised server could show a brand-new browser a consistent fake. The real fix is an EXTERNAL anchor (publish each seal root to a witness the server cannot edit). Needs the founder's decision on which witness. Planned as G5.
- The kernel `merkle@1` proves inclusion paths only. A real consistency proof between two roots (RFC 6962) needs a kernel bump (`merkle@2`), which also moves the awam pin (Rule 52). Planned as G5, needs his haan.

## Files (technology)
`docs/cursor-work/sql/E120_founder_ledger_gauge_hardening.sql` + `CHECK_E120.sql` (SQL) · `server/founder/src/ledger.rs`, `live.rs`, `main.rs` (Rust: `verify_due`, `auto_verify`, `parse_seal`, route `/founder/v1/audit/seal`; 122 tests) · `founder-web/src/sealpin.ts`, `sealpin.test.ts`, `Surface.tsx` (React-TS UI; 34 tests; CINEMATIC look untouched).

## Status
Written and tested in the sandbox (SQL CHECK 4/4, Rust 122, UI 34, tsc 0, build OK). **NOT GREEN** until: `sql-run.sh` E120 + CHECK on the server, `founder-install.sh`, and the gauge shown in his Chrome.
