<!--TECHLAW-->
# TECH CONTRACT FOR PHASE: K8d (kernel WebTransport RPC) + K7 GAP 2 (post-quantum device proof)
STATE: IN PROGRESS
Opened: 11 Nov 2026 04:40 PKT, updated 20:25 PKT (DBSC fresh challenge on every 200) (network = provider area for sessions) (E161 live) (permanent DBSC heal: 403 fresh challenge, dead chip re-offer, E161) (E160 key rotation not theft) (refresh challenge 15 min; ring still Alert after sign-in) (ring-alert fix: chip-bound device never re-offered a key) (K8d REOPENED: ring Alert after K8d, cause being checked, not green). Rule: rewritten at the START of every phase and BEFORE any code; a code commit without this file is refused; STATE may be GREEN only when no row says NO. Every commit carries `Phase:` and `Tech:` lines.
Source of the list: CLAUDE.md line 18 (FOUNDER TECHNOLOGY LAW) + the TECH LAW cell of this phase in docs/claude/BLUEPRINT-ABC-01NOV.md.

| Listed technology | Where it must live in code | IN CODE | Proof command / live proof |
|---|---|---|---|
| HTTP/3 (QUIC) PRIMARY, h2/h1.1 fallback | server/founder/src/h3.rs | YES | Path card "HTTP/3 QUIC", journal HTTP/3 ON |
| X25519MLKEM768 + AES-256-GCM | tls256.rs, h3.rs, wt.rs | YES | external client probe (11 Nov) |
| Rust WASM kernel rpc@1 carries every API call | founder-web/src/kernel.worker.ts, kernel.ts, web-wasm | DONE, LIVE 11 Nov 18:10 | network panel: no fetch for /founder/v1 |
| WebTransport RPC endpoint | server/founder/src/wt.rs (/wt/rpc through the same router gates) | DONE, LIVE 11 Nov 18:10 | Rust test + live |
| api.ts get/getOnce/post/put + devicekey.ts register on the kernel (fetch = fallback only) | founder-web/src/api.ts, devicekey.ts, Surface.tsx | CODE DONE 17:55 (10 raw calls left: exchange, refresh, SSE, login, passkey, logout, kernel load), LIVE 11 Nov 18:10 | TECH-RATCHET.json count falls |
| Post-quantum HYBRID device proof (ML-DSA + ECDSA P-256; DBSC cookie path stays ES256 = browser standard) | founder-web/src/devicekey_pure.ts + server/founder/src/dbsc.rs + SQL | NO | Rust test + live; gate K7-devicekey-pq |


## K8d EXCHANGE DECISION (19:45 PKT, needs his word, not decided by Claude)
Fact (Chrome resource timing 19:36): /founder/v1/exchange is already HTTP/3 (nextHopProtocol h3). Question: also through the kernel/WebTransport? NO, and why: the DBSC chip cookie and the Secure-Session-Registration / Secure-Session-Challenge headers exist ONLY in the browser HTTP stack (spec); a WebTransport stream carries neither, so moving the exchange there would remove the hardware-chip proof. Option A (recommended): exchange stays ONE h3 fetch, documented exception; every other call is on the kernel. Option B: exchange on the kernel with only the software WebCrypto key (weaker, no chip). Gate stays: raw fetch count may only fall; exchange is the allowed one.
