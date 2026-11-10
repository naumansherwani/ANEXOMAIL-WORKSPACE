> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Endpoint migration hisaab — 24 Oct 2026 (latest technology: Rust primary, Bun fallback)

Banaya: Claude CEO-agent, Nauman bhai ke hukm par. Ginti repo ke code se nikali gayi (script), andaza nahi. Poori list: `ENDPOINT-MIGRATION-24OCT.csv`.

## SQL numbering sawal (E83 -> E85)
E84 asli mein Rust-only kaam tha (repeat-series room check); founder ke hukm par 24 Oct ko E84_room_series_note.sql banayi gayi, ab SQL tarteeb E83, E84, E85, E86 poori hai.

## Kul hisaab (script: docs/cursor-work/server/count-endpoints.py)
| Cheez | Ginti |
|---|---|
| Bun REST endpoints (server/routes) | 523 |
| Client Rust-first (`rpcOrRest`, Bun sirf fallback) | 187 |
| Baqi (Bun-only ya client wiring saabit nahi) | 336 |
| Rust procs repo mein | 338 |

## File-wise (Bun file: kul / Rust-first / baqi)
| Bun file | Kul | Rust-first | Baqi |
|---|---|---|---|
| chat.ts | 141 | 0 | 141 |
| org.ts | 27 | 3 | 24 |
| auth.ts | 25 | 2 | 23 |
| crm.ts | 24 | 13 | 11 |
| ai.ts | 21 | 0 | 21 |
| calendar.ts | 17 | 17 | 0 |
| mail-compose.ts | 17 | 17 | 0 |
| movein.ts | 16 | 5 | 11 |
| ai-automation.ts | 14 | 0 | 14 |
| mail.ts | 14 | 13 | 1 |
| integrations.ts | 13 | 11 | 2 |
| release.ts | 13 | 13 | 0 |
| security.ts | 13 | 11 | 2 |
| settings.ts | 13 | 7 | 6 |
| billing-sync.ts | 12 | 7 | 5 |
| admin.ts | 11 | 0 | 11 |
| ai-credits.ts | 11 | 0 | 11 |
| files.ts | 11 | 0 | 11 |
| contacts.ts | 10 | 10 | 0 |
| storage.ts | 10 | 6 | 4 |
| ai-studio.ts | 9 | 0 | 9 |
| auth-passkey.ts | 9 | 9 | 0 |
| perf.ts | 9 | 0 | 9 |
| trial.ts | 9 | 7 | 2 |
| polar.ts | 7 | 2 | 5 |
| founder.ts | 6 | 0 | 6 |
| dashboard.ts | 5 | 5 | 0 |
| handoff.ts | 5 | 5 | 0 |
| glitch.ts | 4 | 0 | 4 |
| locale.ts | 4 | 4 | 0 |
| workspace.ts | 4 | 4 | 0 |
| account-deletion.ts | 3 | 3 | 0 |
| analytics.ts | 3 | 3 | 0 |
| mail-predict.ts | 3 | 3 | 0 |
| people-import.ts | 3 | 3 | 0 |
| support.ts | 3 | 3 | 0 |
| billing-support.ts | 2 | 0 | 2 |
| revenue.ts | 2 | 1 | 1 |

## Rust procs prefix-wise
chat: 102, mail: 39, calendar: 28, account: 18, call: 17, file: 17, founder: 15, crm: 14, team: 14, migration: 7, security: 7, auth: 6, caldav: 6, work: 5, appeal: 4, billing: 4, booking: 4, dashboard: 4, locale: 4, org: 2, movein: 1, outbox: 1, people: 1

## Baqi kaam (phase order, locked)
- M2b: handoff (5) | M3: contacts 10, workspace 4, storage 10, dashboard 5, support 3, billing-sync 12, polar 7
- M4: auth 19 (+1 done), trial 9 | M5: org 27, crm 24, calendar 3, settings 13, security 13, integrations 13, admin 11, perf 9
- L: WebTransport live push (23 polling jahan `refetchInterval`) | M6: chat 141 (Rust mein 102 chat.* procs maujood, client/Bun cutover alag saabit karna hai), ai-credits 11, files 11, ai 21
- F: founder batch alag | B8: tokio 1.54, Bun 1.4.3, Brain -> Rust
Har phase: plan gate (resolve_plan, sab account kinds ek code path), Basic-user 403 test, live Chrome 1440/820/390, Bun fallback, aur technology-wise deploy commands.
