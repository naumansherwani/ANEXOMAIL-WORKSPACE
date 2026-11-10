> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# STEP 4b - Rust /founder/v1/live + SSE + Dashboard auto-update (design note, Rule 63; 1 Nov 2026 05:50 PKT)
Founder order 30 Oct 22:17 (founder-commands.md): everything live, page updates by itself, no mock. SQL half is GREEN on the server (E109, CHECK 9/9): `founder_live_snapshot()`, `founder_live_tick()`, `founder_live_since(after, limit)`, `founder_live_series`, `founder_live_anomalies`, tables `founder_live_sources/state/events/metric_points`. This note is the Rust + UI half. Docs only; nothing built yet.

## Technology (Rule 61/62)
Postgres E109 -> Rust `anexomail-founder` (axum 0.8 + tokio, async 24 h) -> signed frames (Ed25519, same `signed()` as every endpoint) -> browser, verified by the ONE WASM kernel in the Web Worker -> React-TS Dashboard re-renders. No Bun, no Node on the server, no mock data, no AI.

## Why fetch-stream, not EventSource
`EventSource` cannot send the Authorization header (the founder token) and cannot be signed-request enforced. The SPA opens `fetch("/founder/v1/live/stream")` with the token and reads the response body as an SSE text stream. Same wire format (`id:` / `event:` / `data:`), reconnect logic written in the SPA with `Last-Event-ID`.

## Pieces
| Part | What | Tech |
|---|---|---|
| L1 | `GET /founder/v1/live` = signed `founder_live_snapshot()` (one RPC, all numbers, version = last event id). Dashboard uses it instead of 8 calls (also helps the F5 refresh time) | Rust, 1 RPC |
| L2 | ONE background tokio task per process: every 5 s calls `founder_live_tick(true)` (records points, appends changes to the append-only feed). It publishes the new version on a `tokio::sync::broadcast` channel. Clients do NOT each poll the DB | Rust tokio |
| L3 | `GET /founder/v1/live/stream` = SSE. On connect: snapshot frame, then for each broadcast: `founder_live_since(last_id)` delta frames. Every frame is a signed envelope; heartbeat comment every 15 s; slow client dropped (bounded channel) | Rust axum |
| L4 | SPA `useLive()`: opens the stream, sends each frame to the kernel worker, draws ONLY verified frames, falls back to polling `/live` every 15 s if the stream breaks, shows "Live" / "Reconnecting" chip honestly | React-TS + WASM |
| L5 | `pending_channels` (hard-coded ["glitch","support","company_mail"] in bridge.rs) replaced by rows from `founder_live_sources` (registry); empty registry says "no sources connected", never a made-up list | Rust + SQL |
Not in this step: WebTransport/QUIC (later, same frames), triggers on awam tables (never; Polar and awam tables stay NO-TOUCH, E109 uses fingerprints).

## Safety and honesty
- Auth and write-signature rules unchanged; stream needs the same token + device approval. 401 without it (CHECK in install script).
- No user content in frames: counts, states, ids, timestamps only (Rule 69).
- Tick failure never kills the process: logged, counted, "stale since HH:MM" shown on the Dashboard (never a frozen number pretending to be live).
- Load: one tick query per 5 s regardless of how many tabs (broadcast), so cost stays flat.

## Phases (one at a time, green before next)
| Phase | Done when |
|---|---|
| 4b-1 | `/live` snapshot signed, kernel-verified, Dashboard reads it (tests + Chrome: same numbers as before, fewer calls) |
| 4b-2 | tick task + `/live/stream` (cargo tests: broadcast, bounded client, since-delta; curl proof: heartbeat + a change frame) |
| 4b-3 | `useLive()` in the SPA; Chrome proof: change a real row (e.g. a lead), the Dashboard number changes within ~10 s without reload |
| 4b-4 | `pending_channels` from the registry; Chrome shows the registry's list |
Pull per phase: Rust + SPA = `founder-install.sh`; no new SQL (E109 is in).

## Open questions (founder, only these)
1. Tick every 5 s ok (cost vs freshness), or 10 s?
2. Dashboard first (4b-3 on Dashboard only); Bridge page afterwards. ok?
