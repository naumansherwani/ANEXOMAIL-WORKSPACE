# Devices & Sessions Command Center plan (10 Nov 2026 20:18 PKT, founder order 20:15)
His list of 8 features, each judged honestly (no claim the code cannot prove; a card shows only what the server really measured).
| # | His wish | Real, buildable version | Not possible as worded |
|---|---|---|---|
| 1 | Hardware identity signature, spoof alert | Device-bound key (DBSC / non-extractable WebCrypto key, K7 observe mode already collects) + UA vs client-hints vs feature mismatch = "Spoof alert" red row | A browser can never read true physical hardware IDs; we show the device KEY id, never "hardware serial" |
| 2 | Live protocol badge QUIC vs TCP | Rust knows per request: WebTransport/QUIC (K6) or HTTP/2 TCP fallback; stored per session | none |
| 3 | Constant-time integrity status | Rust HMAC-SHA256 verify is constant-time (subtle/ring); card shows "verified at HH:MM:SS" from the last real check | "every second" claim: shown only as last real verification time |
| 4 | One-click session nuke | SQL revoke door + identity logout + Rust drops the in-memory session; target < 1 s, proof = ledger row + next request 401 | "browser memory wiped": server cannot reach a browser; the next request is refused and the SPA clears itself |
| 5 | Tamper-evident session ledger | New SQL E154: append-only hash-chained table (session, time, network hash, kernel version), UPDATE/DELETE blocked by trigger, verify function, same pattern as E151 | none |
| 6 | P2P vs TURN badge | Our architecture has no P2P/TURN; honest replacement = "Direct QUIC" / "Via TCP proxy" (same as #2) | P2P/TURN dropped |
| 7 | Phishing/timing shield | Factual posture list: passkey origin-bound (phishing-proof), constant-time compare, rate limits, WASM verify | "mathematically impossible" wording not used |
| 8 | Location lock (geofence) | Per-account allowed-country list checked at sign-in and at release (GeoIP of the network); new device outside = refused + ledger | VPN inside the allowed country; stated on the card |
Order: after S7 (his phone passkey GREEN): D1 SQL E154 (session ledger + geofence table + checks) -> D2 Rust (device key, protocol, revoke, geofence) -> D3 UI card in Settings > Devices (cinematic look, one build 390/820/1200+) -> D4 live proof. Awam never touched. Technology: Rust axum+tokio, WASM kernel, SQL E-series, React 19.2.
