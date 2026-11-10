> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Founder Finance: live Polar events (PLAN ONLY, nothing built) - founder order 2 Nov 11:53
Letter O (Finance deck). Belongs to the founder lane; awam is parked.

## What exists on the server (his pastes 11:49 / 11:50)
- `/opt/polar-rust-payment` (pm2 `polar-rust-payment`, :3400, Rust axum 0.8 + tokio + sqlx/Postgres + hmac/sha2). main.rs 1407 lines, pcp.rs 329. Migrated Rust: Rule 35 (surgical edits only).
- Routes: POST `/api/v1/polar-webhook`, `/api/v1/replay`, `/api/v1/reconcile`, `/api/v1/checkout`, GET `/api/v1/checkout/{id}`, `/api/v1/billing/{user_id}`, POST `/api/v1/portal`, `/health`, `/ready`, `/metrics`.
- Events handled today: subscription.active / past_due / canceled / revoked / updated. Write-ahead log dirs: pending, done, dead, rejects.
- Polar side (his message): two production webhook URLs, API version 2026-10: `https://anexomail.com/api/v1/polar-webhook` and `https://polarpayments.anexomail.com/api/v1/polar-webhook`.
- NOT yet read: the handler body (what it writes to the DB per event).

## The way (flow)
Polar -> Caddy -> Rust :3400 verifies the signature (HMAC-SHA256, Standard Webhooks headers) -> existing WAL -> existing plan update (unchanged) AND one NEW step: append the event to a finance ledger -> founder Rust `anexomail-founder` reads it -> `/founder/v1/finance/*` signed envelope -> WASM kernel verifies in the browser -> React-TS card (CINEMATIC).

## Phases (one at a time; each GREEN only with his pastes + my Chrome look)
- O-P1 SQL: append-only `polar_events` ledger (unique on the webhook-id so a repeated delivery is stored once; no foreign key; hash-chained like org_events; RLS on, founder/service only) + a view for "who came" and "who left". CHECK file.
- O-P2 Rust in `polar-rust-payment`: ONLY add the ledger insert and the extra events (subscription.created, subscription.uncanceled, customer.created, order.created/paid/refunded). Existing handling untouched. Unit tests. Plan shown to him before the edit.
- O-P3 Rust in `anexomail-founder`: `/founder/v1/finance/customers`, `/churn`, `/events` (read-only).
- O-P4 UI card: new customers, leaving (cancelled, access until period end), gone (revoked), churn %, MRR. Real data only, empty state when none.
- O-P5 live push: first refresh by short polling; true live push over WebTransport after K6.
- Backfill: use the existing `/reconcile` pull so history is real from day one. No mock data.

## Churn words (so the numbers are honest)
- Cancelled = will leave at period end, still paying/active now. Revoked = access ended = churned. Churn % = revoked in period / active at period start. Cancel reason shown when the customer gave one.

## Safety
- Customer emails only on the founder screen. Webhook secret and Polar token never printed or committed. Duplicate delivery (two URLs) handled by the unique webhook-id.

## His answer 11:56 (question 1)
Both webhook URLs return 200 OK. `anexomail.com/api/v1/polar-webhook` = PRIMARY (the real one he controls, the one that will connect); `polarpayments.anexomail.com/api/v1/polar-webhook` = FALLBACK. Both real. The ledger keeps one row per webhook-id, so a double delivery is harmless. Still unproven: that both land on the same :3400 service (a `/health` check on both hosts shows it).

## Questions for him (answers needed before O-P1)
1. Both webhook URLs go to the same :3400 service? If both are live, every event arrives twice (the ledger de-duplicates, but one URL may be removable).
2. Does the existing Polar token read customers and subscriptions, or metrics only? (check on the server, no printing)
3. Is O moved ahead of G5b/I2, or does it wait in letter order?
4. Payload shape under API version 2026-10 must be checked against Polar's docs before O-P2.

## DECISION LOCKED (founder 3 Nov 12:31 PKT, verbatim in founder-commands.md; he had said it before 3 Nov 05:20 and 2 Nov 11:53-11:56)
- C1 (a Polar Metrics API token) is **DROPPED**. Nobody asks for a token. `polar.rs` + `FOUNDER_POLAR_READ_TOKEN` + `founder-polar.sh` stay in the repo as dormant code and are NOT to be offered again.
- Method = use the **existing endpoint** (the two webhook URLs above; Polar engine :3400 is NO-TOUCH except the one ledger insert in O-P2) and build **one layer on top with the most advanced technology**.
- That layer (to be designed in O, with the 2026 technology chart, before any code): Standard Webhooks signature + replay window, append-only hash-chained `polar_events` ledger (unique webhook-id), Merkle + signed checkpoints through the existing kernel (`merkle@2`) so the browser verifies the finance numbers, reconcile-based backfill, WebTransport live push after K6. Nothing starts before letter O (it is the LAST founder letter).
