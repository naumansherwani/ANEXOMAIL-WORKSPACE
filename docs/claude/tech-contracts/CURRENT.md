<!--TECHLAW-->
# TECH CONTRACT FOR PHASE: K8d (kernel WebTransport RPC) + K7 GAP 2 (post-quantum device proof)
STATE: IN PROGRESS
Opened: 11 Nov 2026 04:40 PKT. Rule: this file is rewritten at the START of every phase and BEFORE any code; a code commit without this file in it is refused by rules-gate; STATE may be GREEN only when no row says NO.
Source of the list: CLAUDE.md line 18 (FOUNDER TECHNOLOGY LAW) + the TECH LAW cell of this phase in docs/claude/BLUEPRINT-ABC-01NOV.md.

| Listed technology | Where it must live in code | IN CODE | Proof command / live proof |
|---|---|---|---|
| HTTP/3 (QUIC) PRIMARY, h2/h1.1 fallback | server/founder/src/h3.rs | YES | Path card "HTTP/3 QUIC", journal HTTP/3 ON |
| X25519MLKEM768 + AES-256-GCM | tls256.rs, h3.rs, wt.rs | YES | external client probe (11 Nov) |
| Rust WASM kernel rpc@1 carries every API call | founder-web/src/kernel.worker.ts, kernel.ts, web-wasm | NO | network panel: no fetch for /founder/v1 |
| WebTransport RPC endpoint | server/founder/src/wt.rs (/wt/rpc through the same router gates) | NO | Rust test + live |
| api.ts get/getOnce/post/put + devicekey.ts register on the kernel (fetch = fallback only) | founder-web/src/api.ts, devicekey.ts, Surface.tsx | NO | TECH-RATCHET.json count falls |
| Post-quantum HYBRID device proof (ML-DSA + ECDSA P-256; DBSC cookie path stays ES256 = browser standard) | founder-web/src/devicekey_pure.ts + server/founder/src/dbsc.rs + SQL (his 11 Nov 04:43: tomorrow's GAP 2) | NO | Rust test + live; gate K7-devicekey-pq |
