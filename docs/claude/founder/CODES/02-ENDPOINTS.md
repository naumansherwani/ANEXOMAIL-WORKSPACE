> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 02 ENDPOINTS — founder ke raaste (code se nikale, 28 Oct)
## NAYA (Rust, 127.0.0.1:3210) — rakhna hai
GET /healthz · POST /founder/v1/login · GET /founder/v1/me · /bridge · /actions · /audit · POST /founder/v1/action
## PURANA (Bun) — `app.use("/api/founder", founderGate)` ke peeche (server/index.ts:127)
| File | Route |
|---|---|
| routes/founder.ts | GET mailboxes, overview, ai-agents, ai-mail (+6 handlers: provision, ai-mail/approve) |
| integrations.ts:337 | GET /integrations/overview |
| settings.ts:517 | GET /settings/overview |
| analytics.ts:93,108 | GET /analytics/overview, /billing/revenue |
| admin.ts:748 | GET /admin/overview |
| security.ts:685 | GET /security/overview |
| perf.ts:548 | GET /perf/overview |
| revenue.ts:160 | GET /revenue/overview |
| ai-credits.ts:398 | GET /ai/credits/overview |
| release.ts | POST /release/run · GET checks, overview, checklist, deployments, lock, roadmap, revenue/pipeline · POST checklist/item, lock, roadmap |
| billing-support.ts:52,75 | GET /support/replies · POST /support/replies/:id/replied |
| movein.ts:167-396 | GET cockpit, deal/:id · POST transition, schedule, arm, mailbox, dns, runbook, exception, rollback, invoice |
| glitch.ts:314 | GET /glitch/health |
| storage.ts:218,250 | GET /storage/volumes · POST /storage/volume |
## PURANA — gate ke BAGHAIR mount (alag path, alag guard)
| org.ts:494-551 | GET /founder/org/state, /list · POST /founder/org/kill-switch, /impersonate (founderGuard, email+founder_accounts) |
| crm.ts:1367,1395 | GET /founder/crm/state · POST /founder/crm/toggle (founderOnly) |
Note: org/crm app.use("/api") se mount hain; index.order.test.ts guard karta hai ki founderGate unse PEHLE mount ho.
