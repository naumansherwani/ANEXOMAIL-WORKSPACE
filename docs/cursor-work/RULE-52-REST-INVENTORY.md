> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# RULE 52 — poori website ka asli naap (26 Oct 2026 20:35 PKT, Chrome, Pro account, 35 /app routes, iframe-crawl 5 s/route)
Maqsad (founder): har route ka har call kernel (WebTransport) se; `anexoKernel.stats.fetch` = 0, `fallbackProcs` khali. Tareeqa: iframe crawl (`window.__crawl(routes, ms)` Chrome console mein), `api()` har REST call `fallbackProcs["METHOD /api/..."]="rest"` mein ginta hai (commit c82eb17).

## Nateeja (35 routes): kernel 214 / fetch 100 => 68% kernel. Baaqi 100 fetch ka hisaab:
| # | Call | Kitni routes par | Rust proc status | Plan |
|---|---|---|---|---|
| 1 | `GET /api/auth/session` | har route (33) | NAHI (Bun auth.ts sessionResult, bada, login-critical) | `auth.session` Rust — Bun se baraabari ka saboot PEHLE, phir UI `rpc()` |
| 2 | `GET /api/trial/state` | har route (33) | NAHI (Bun trial.ts) | `trial.state` Rust |
| 3 | `GET /api/auth/mfa`, `/api/auth/sessions`, `/api/auth/recovery` | /account | NAHI | account module |
| 4 | `GET /api/companies` | 2 | NAHI | |
| 5 | `GET /api/contacts`, `/api/contacts/tags` | /people | NAHI | |
| 6 | `GET /api/storage/state` | /storage | NAHI | |
| 7 | `integrations.providers`, `integrations.connections` (kernel_status_404) + REST `/api/integrations/*` | /integrations | Rust proc maujood nahi (404) | port |
| 8 | `crm.leads` (kernel_status_404) + `GET /api/crm/leads` | /crm/leads | NAHI | port |
| 9 | kernel_not_used: locale.*, calendar.events, account.integrity.me, auth.passkey.status, work.promises/tasks, chat.*.board | /safety, /work (0 kernel) | proc Rust par HAIN | in 2 routes kernel uthi hi nahi — pehle yeh dekho (crawl artefact: IP session guard?) |
## Abhi tak NAAPE NAHI GAYE: /app/mail (inbox/thread), /app/settings/*, /app/org/*, /app/security/*, /app/admin/*, /app/perf/*, /app/founder/* (alag account chahiye), public pages (landing, /auth, /f/<slug>, /book/<handle>), seedha `fetch()` (uploads: attach/evidence/ai-workspace/chat-files/org-export; telemetry; clock-sync).
## Rule 56: har REST endpoint ka Rust proc (X_core std-only tests + X_glue), installer, contract, Basic probe; UI `rpc()`; Bun route tab hat'ta hai jab Rust live green + Bun barabari saboot.
