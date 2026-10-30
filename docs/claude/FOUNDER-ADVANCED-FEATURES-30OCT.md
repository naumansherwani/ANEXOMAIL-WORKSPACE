# FOUNDER SIDE — NEW WORLD-CLASS FEATURES + USER/FOUNDER SEPARATION (30 Oct 2026, 20:35 PKT)
Founder order (20:26, verbatim in docs/cursor-work/founder/founder-commands.md): "in main duniya ke advance features founder ko diya jaye jo founder se related hai aur technology kaun si aye gi woh likho ... user aur founder mix nahi ho".
Docs only (Rules 62/63/64): no feature code until the founder approves one phase at a time. This list ADDS to FOUNDER-ADVANCED-FEATURES-28OCT.md (items 1-33) and FOUNDER-KILLER-FEATURES-28OCT.md (K1-K4, I1-I3); nothing below repeats them.

## 1. Rule: user side and founder side NEVER mix
| Layer | User (awam) | Founder |
|---|---|---|
| Host | anexomail.com | founderworkspace.anexomail.com |
| Binary | Bun web + Rust cores | Rust `anexomail-founder` (axum 0.8 + tokio) only. No Bun, no Node on the founder server |
| Token | user session JWT | founder session; server->browser Ed25519 (kid s1), browser->server HMAC-SHA256 + HKDF; audience is separate, a user token is never accepted |
| Tables | user/org tables | founder-only tables (E10x/E107...), RLS on, append-only audit; user code never reads them |
| UI | user SPA (own look) | founder SPA `founder-web/` (cinematic: aurora, glass sidebar, flip clock) |
| Shared | ONE thing only: the Rule-52 WASM kernel `web-wasm/` (crypto/verify code, no data, no UI) | same bytes via `founder-web/kernel-sync.sh` |
| Guard | `FOUNDER_HOST_GUARD`: founder accounts cannot sign in on awam hosts (L5 proves it, enforce after `founder_host=true` is seen) | |
Checked 30 Oct: `founder-web/` imports nothing from `src/`; user SPA `src/` has no founder table or `/founder/v1` call. The only mention is the type field `is_founder` in `src/lib/auth.tsx` (a flag the server returns so a founder account is never sent into awam onboarding). Keep it that way.

## 2. New features (each = founder-only data source, never user content)
| # | Feature | Why it is world-class | Technology layer | Data source / gate | Phase |
|---|---|---|---|---|---|
| N1 | **Decision journal + pre-mortem** | every Decide click stores reason + "what would make this wrong"; 30 days later it asks "was it right?" — founder learns from own record | Rust (tokio job) + SQL append-only + React UI | founder tables; G2 | after Decide |
| N2 | **Anomaly watch** (signups, bounce, spend, latency) | EWMA + z-score, deterministic, explains itself ("3.1 sigma above 14-day mean"); no AI guess | Rust tokio background task, SQL series | metadata counters only | after F2c |
| N3 | **Runway and scenario simulator** | drag price/churn/hires sliders, answer in the same frame, no server round trip | WASM kernel module (pure maths, tested vectors) + React UI | Polar numbers (read-only) | after S2 |
| N4 | **Two-person / break-glass (G3)** | dangerous action needs a second founder-device passkey tap or a sealed break-glass code; every use is audited and alerts | Rust (webauthn-rs) + SQL + UI | F2d passkey | F2d |
| N5 | **Tamper-evident signed exports** | any export carries a Merkle proof + Ed25519 signature; anyone verifies offline with the kernel | Rust (Merkle) + WASM kernel `merkle` | audit chain (F2c) | F2c |
| N6 | **Time travel (point-in-time)** | "show the company as it was last Tuesday 14:00" from the append-only history | SQL temporal queries + Rust + UI scrubber | audit + snapshots | S2 |
| N7 | **Weekly board brief (no LLM)** | deterministic one-page summary, every number links to its source row; signed | Rust templating + WASM verify + Docs-style UI | existing metrics | after N2 |
| N8 | **Command palette that can act** | Ctrl K runs only actions from the server registry (typed, risk-labelled); parsing in the kernel `intent` module | WASM kernel `intent@1` + Rust registry + shadcn UI | action registry | with Decide |
| N9 | **Offline founder PWA, signed cache** | opens with no network; cached answers verified by the kernel before display; shows age | Service worker + WASM kernel + React | signed responses | after F2d |
| N10 | **SLO and error-budget burn alerts** | "budget gone in 6 h at this rate", not raw graphs | Rust tokio + SQL + push (S4) | systems metrics | with S4 |
| N11 | **Live Pulse over WebTransport** | server pushes health/money/review changes over QUIC streams; datagrams for heartbeat | Rust `wtransport` + kernel verify per frame + UI | needs UDP port + cert (ask founder then) | after F2d |
| N12 | **Bridge map "---> <---"** | one glance: what is arriving (signups, mail, money) vs what is leaving (sends, refunds, errors) | React-TS + Cinematic CSS (Three.js only lazy, optional) | bridge data already live | S3 |

## 3. Bridge icon (done, 30 Oct)
Old house glyph replaced by a suspension bridge (two towers, cables, deck, hangers) in `founder-web/src/Brand.tsx` (`P.bridge`). Technology: React-TS + inline SVG, no image file, uses `currentColor` so the cinematic theme still colours it.

## 4. Order (unchanged master order, one phase at a time)
F2c Merkle -> S2 -> F2d passkey -> S3 -> Decide + Live Pulse + S4 -> N-items in the order above. Each item first gets its own short design note, then SQL (if any), Rust, kernel, UI, then server + Chrome green before the next.
