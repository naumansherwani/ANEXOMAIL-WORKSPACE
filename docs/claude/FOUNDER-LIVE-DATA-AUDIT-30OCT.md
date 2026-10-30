# FOUNDER LIVE-DATA AUDIT + E109 (30 Oct 2026, 22:30 PKT)
Founder order 22:17 (verbatim in founder-commands.md): every number real, nothing mock, page updates itself live, advanced SQL.

## 1. Honest audit: is anything on the founder pages invented?
| Item | Source today | Verdict |
|---|---|---|
| Money (MRR, accounts), target | `revenue_accounts`, `revenue_targets` (target 500 is a real row in that table) | REAL |
| Leads, mail queue | `revenue_leads`, `mail_outbox` | REAL |
| Polar webhook, subscriptions, rejects | E105/E106 RPC over Polar tables | REAL |
| Audit chain, gates, devices, settings | founder tables E102/E104/E108 | REAL |
| Endpoint latency, Verified/Trusted | measured in the browser, kernel verdict | REAL |
| Clock, greeting | device time, home city setting | REAL |
| "Not connected yet: Glitch, Support, Company Mail" | HARD-CODED list in `bridge.rs` (`pending_channels`) | NOT data, a static claim. Must come from a registry (E109 sources) in the Rust wiring step |
| Live update | 15 s polling of `/bridge` | NOT live enough. E109 + Rust SSE fixes it |
| Decks (Finance/People/Mail Desk/Systems...) | shells; real data lands per phase | show "Not connected", no numbers invented |
No hard-coded business number was found in `founder-web/src` (grep of £/numbers in Finance/Live/Decks).

## 2. E109 (SQL, 600 lines, tested on a real Postgres 16 with stub tables: selftest OK, CHECK 9/9)
- `founder_live_sources` registry (12 sources) + `founder_live_state` fingerprints (count + newest timestamp).
- `founder_live_events` append-only change feed (id = version, no PII, 30-day prune only through `founder_live_prune`).
- `founder_live_tick()` change detection + stale/recover (SLO), records `founder_metric_points` (1-min buckets, compressed).
- `founder_live_snapshot()` ONE round trip instead of 5 REST calls (fixes the 1.8 s refresh); `founder_live_since()` Last-Event-ID catch-up; `founder_live_anomalies()` deterministic z-score (N2); `founder_live_series()` sparkline data.
- No trigger on user-side tables (Rule B6a / FC18). Honest trade-off written in the file header.
## 3. Order (one phase at a time, Rule 66)
1. SQL E109 on the server (`sql-run.sh` + `CHECK_E109`) — NOW.
2. RUST: `/founder/v1/live` snapshot + SSE `/founder/v1/live/stream` (tick every 2 s, push event ids), signed frames, kernel verifies each frame. Replaces `pending_channels` with registry data.
3. UI: Dashboard subscribes (EventSource-style with Last-Event-ID), numbers animate on change, "updated Ns ago" from real timestamps, sparkline from `founder_live_series`.
4. WebTransport later (F-live) replaces SSE.
