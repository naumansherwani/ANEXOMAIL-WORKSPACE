> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# NOT-GREEN 2 — TODO (bana hi nahi)

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

Technology migration order (founder 05:53): B4→B5→B6→B7→B8, phir Pro→Business→Business Pro.

| Item | Kaam | Note |
|---|---|---|
| Plan P3 | Split inbox (Priority vs Other) | build |
| Plan P3 | Focus mode (ek thread, baqi fade) | build |
| Plan P4 | Inline image paste | build |
| Plan P5 | Link preview cards | build |
| Plan P7 | Availability sharing link / scheduling link | B7 |
| Plan P9 | ANEXOChat live proof (status board 'P9') | D10 |

| G | Kaam | Note |
|---|---|---|
| G2 | Admin ke baqi 9 pages + Chat harness | D9; Basic sweep mein Admin plan-gated dikha |
| G6 | IMAP phone sync (Dovecot, 8 KB store) | audit baqi (D9) |
| G7 | catch-all/forwarding/vacation/signature verify | C9 8-series NEXT; audit baqi |
| G9 | Plan-promise audit (plans.ts har line) | D9; Basic card/real product match ho chuka (04:30), Pro+ baqi |
| G11 | Bun 1.4.0→1.4.3 | B8 |
| G12 | Rust restarts=48 wajah | pm2 ↺ ab 73 (rust) / 215 (web): wajah audit nahi hui — har installer restart hai, panic count dekhna |
| G15 | CRM SPA Link (full reload hataana) + useAssignShared body | code audit baqi |
| G16 | Self-serve billing (cancel/card/VAT via Polar portal) | B6 (Polar :3400 NO-TOUCH) |
| G20 | Plan-wise baqi (Business Pro data/entitlement bpro.test) | D7 |
| G21 | Baqi Brain routers authz audit | D7 |
| G22 | org.ts sach-jhooth (workspacePlanOf, compliance) | D7 |
| G24 | Personal Premium claims live test (8K relay, 40-person group) | D8 |
| G25 | founderworkspace host par public site aaya (WebFetch) | edge/redirect check baqi |
| G26 | Calendar guest iMIP reply | B7 (production mail path: founder 'haan' chahiye) |
| G27 | Recurrence / scheduling link / 2-way sync / CalDAV | B7 |

| Tech | Note |
|---|---|
| B6 G16 self-serve billing Rust | Polar :3400 NO-TOUCH |
| B7 G26/G27 calendar iMIP/recurrence/link/CalDAV |  |
| B8 Brain 38 files/504 endpoints -> Rust, Bun 1.4.3, tokio 1.54 |  |
| R3 typed contract |  |
| R4 direct DB pool |  |

| Ops | Note |
|---|---|
| Bun /api/billing/subscription bug | D11 |
| E24 email_hash HMAC migrate run | D11 |
| E52 alias fair-use SQL (cap 25) server par | sql-run.sh E52_alias_fair_use CHECK_E52 |
| A5 FOUNDER_PASSWORD plain env compare (auth.ts:631) | G35 passkey/2FA ke baad hatana |
| repo main.rs live ke barabar mirror | installers live patch karte hain; A1 gap |
| Cron anexomail-sync-domains/maps duplicate (crontab + /etc/cron.d) + script repo mein nahi | A4 |
| Login-loop live verify (founder sign-out/login) | recorder |
| BUG mojibake '5:31â¯AM' preview/ingest charset | ledger |
| BUG thread card sender line clip | ledger |
| Plan docs ka 10 s undo-send -> 30 s | MASTER-BUILD-PLAN/package maps |
