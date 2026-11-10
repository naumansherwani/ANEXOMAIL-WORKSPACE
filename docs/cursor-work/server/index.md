> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Server — docs/cursor-work/server/

**Rule (locked):** Jo bhi server par chalna hai — bash command README ya yahan likhni hai.
Alag file nahi. Pull command ek. Sirf yeh:

```bash
cd /opt/anexomail-web && git restore src/routeTree.gen.ts && git pull --rebase origin main && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save && curl -s -o /dev/null -w "web /health %{http_code}\n" --max-time 5 http://127.0.0.1:3000/health
```

**Locked:** ALWAYS `git pull --rebase origin main`. NEVER `--no-rebase`. One `&&` block only.

---

## PM2 services (reference)
| Service | Port | Runtime | Status |
|---|---|---|---|
| anexomail-web | 3000 | bun | Frontend SSR |
| anexomail-brain | 3100 | bun | Brain API |
| anexomail-rust | 3200 | rust binary | PRIMARY backend |
| anexochat-fallback | 3300 | bun | ANEXOChat fallback |

---

Frontend pull 21 Sep 2026: **DONE** — `web /health 200`. Proof: `docs/cursor-work/server/pull-20260921-web.md`.

Ab se har server-side script yahan track hoga.

Security blueprint (TODO, no code): `docs/anexomail-security-blueprint.md`

Test ka tareeqa (AGENTS.md Rule 17): `t7-send-identity-test.sh` — browser nahi; login token -> Rust/Brain curl -> logs/DB. Test account: `docs/cursor-work/sql/E28_seed_buyer_test_account.sql`.
