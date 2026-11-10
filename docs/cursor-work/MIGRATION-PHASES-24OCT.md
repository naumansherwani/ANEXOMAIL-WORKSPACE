> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Migration phases — whole website to latest technology (24 Oct 2026)

Founder rules (locked 24 Oct):
- Rust PRIMARY. Bun = permanent EMERGENCY fallback (never deleted; `rpcOrRest` falls back on 404/501/502/503).
- Website must never break: one batch at a time, each with a plan gate + Basic-user test + live re-test.
- No mixed code: three LANES, each its own batch and its own glue file. Plan rules live in ONE place (SQL `resolve_plan` = canonical; Rust `pro_plan_ok`; Bun `resolvePlan`). No copied plan tables.
- No duplicate code: shared helpers only (`mail_thread_owned`, `mail_pct`, `pro_plan_ok`, `sb_*`). A proc is written once in Rust; the Bun route stays untouched as fallback.
- Per technology, the founder gets its own command (SQL / Rust / Web / crates / Bun runtime / events).

## Lanes (by account kind; each endpoint is confirmed against its `kind` at batch start)
- **Lane A — workspace plans:** Basic, Pro, Business, Business Pro (kind business).
- **Lane B — personal:** Personal Basic/Pro/Premium + Family accounts (kind personal / family).
- **Lane C — Founder:** founder command centre (founder.ts, release, admin, perf, revenue, glitch). Never mixed into A/B batches.

## Phases
| Ph | Technology | Scope | Lane | Founder commands |
|----|-----------|-------|------|------------------|
| P0 | DONE | tokio 1.53.3, axum 0.8.9, tRPC-style /rpc, WebTransport events, mail.send/schedule, passkey, calendar+rooms, M1 thread actions | A | — |
| P1 | crates + Bun runtime | tokio 1.54 (`rust-crate-upgrade.sh`), Bun 1.4.0 -> 1.4.3 (T3 first half) — small, measured, rollback ready | all | Rust + Web |
| P2 | axum + /rpc (M2) | Pro mail: templates list, snippets, drafts, follow-up, handoff, send-confidence, thread note | A | Rust + restart + Web |
| P3 | axum + /rpc (M3) | contacts, companies, workspace, storage, billing STATE (polar :3400 untouched) | A | Rust + restart + Web |
| P4 | axum + /rpc (M5) | org, crm, calendar rest, settings, integrations, security, dashboard | A | Rust + restart + Web (+SQL only if an E-file) |
| P5 | axum + /rpc | trial, personal workspace, family accounts, account-deletion, locale | B | Rust + restart + Web |
| P6 | axum + /rpc | auth (18 routes; AUTH-MIGRATION-PLAN.md; differential tests; highest risk) | A+B | Rust + restart + Web |
| P7 | axum + /rpc | founder.ts, release, admin, perf, revenue, glitch | C | Rust + restart + Web |
| P8 | axum + tokio + WebTransport | chat (141 routes) + ai (44); chat realtime on WT | A | Rust + restart + Web |
| P9 | WebTransport events | replace the 23 `refetchInterval` polls: snooze wake-up, scheduled-send status, calendar/crm/work/people topics | A+B+C | Rust (events) + Web |
| P10 | sqlx direct Postgres pool (T1), ts types (T2), speed (T4) | after endpoints are on Rust; measure first | all | new scripts |

Phase count: 11 (P0 done, P1..P10 left). P1 and P10 are engine upgrades; P2..P8 are endpoint batches; P9 is live push.

## Commands per technology (founder runs)
- **SQL (only when a batch ships an E-file):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
- **Rust (axum/tokio/tRPC procs):** `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)` then `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
- **Rust crates (P1):** `rust-crate-upgrade.sh` (same fetch+show pattern; exact line given at P1).
- **Web (Bun SSR + client):** `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
- **WebTransport events (P9):** `rust-events-install.sh` (+ `rust-deliver-install.sh` if mail delivery hook changes).
- **sqlx pool (P10):** new installer, written in that phase.

## Emergency-fallback guarantee
Bun routes stay. Each phase ends with a fallback drill: stop the Rust proc for that area in staging/live-safe way and confirm the Bun route still serves.
