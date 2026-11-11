<!--TECHLAW-->
# FOUNDER PHASES: ORDER + TECHNOLOGY STATUS (11 Nov 2026 17:30 PKT, his order 17:12). Honest, from docs/claude/FOUNDER-TECH-AUDIT-11NOV.md + live proofs.
Reading key: TECH-GREEN = behaviour green AND the listed technology proven in code/live. BEHAVIOUR-GREEN = works and proven, but the API still travels by `fetch` (on the wire it is HTTP/3 since K8b; Rule 52 wants kernel -> WebTransport) = ONE gap, K8d, which closes for every row marked K8d at once.

| Order | Phase | What | Listed technology | Status |
|---|---|---|---|---|
| 1 | A | Device approval + Ed25519 signatures | Rust Ed25519, WebAuthn L3, kernel envelope | BEHAVIOUR-GREEN (K8d) |
| 2 | B | Settings S1 | React 19/TS UI, Rust | BEHAVIOUR-GREEN (K8d) |
| 3 | C | Server leftovers | - | C1 dropped by him, C2 parked |
| 4 | D | UI stack | React 19.2, Vite 8.2, TanStack Router, Tailwind 4.2, shadcn, TS | TECH-GREEN (TanStack START not used on purpose: needs a JS server, his Bun/Node ban) |
| 5 | E | Loophole fixes L1-L12 | Rust + SQL | GREEN (L5 parked, lockfile open) |
| 6 | F | WASM kernel verify | Rust WebAssembly kernel | TECH-GREEN |
| 7 | G | Audit + Merkle | SHA-256 chain, Merkle (kernel merkle@1), PostgreSQL RLS | TECH-GREEN for hash chain; API = K8d |
| 8 | H | Settings S2 time machine + drift | Rust + SQL + kernel | BEHAVIOUR-GREEN (K8d) |
| 9 | I | Key registry, Appearance, Ambient | Rust + React | BEHAVIOUR-GREEN (K8d) |
| 10 | J | Passkey + Privacy | WebAuthn L3, kernel re-derives action hash | BEHAVIOUR-GREEN (K8d); post-quantum signature = Q |
| 11 | K1 | X25519MLKEM768 | ML-KEM hybrid | TECH-GREEN again (K8c, regression after K4 fixed 11 Nov) |
| 12 | K2/K3/K4 | AES-256-GCM TLS 1.3 terminator | rustls AES-256 | TECH-GREEN + h2 fallback (K8a) |
| 13 | K5a | awam AES-256 | | GREEN |
| 14 | K6 | WebTransport live feed | wtransport QUIC | TECH-GREEN for the live feed; API not on it = K8d |
| 15 | K7 | DBSC device key | TPM key + WebCrypto key | BEHAVIOUR-GREEN (live: Device key GOOD); observe mode; gaps K7-devicekey-fetch (K8d) + K7-devicekey-pq (ML-DSA hybrid) |
| 16 | K8a/b/c | h2 fallback, HTTP/3 PRIMARY on UDP 443, ML-KEM | | TECH-GREEN (all live-proven 11 Nov) |
| 17 | D3 Devices UI | aurora seal | React + Framer-ready CSS | GREEN (390/820 screenshots from him still wanted) |
| 18 | K8d | kernel WebTransport RPC for every API call | Rust WASM kernel + WebTransport | OPEN, tomorrow gap 1 |
| 19 | K7c | enforce | | OPEN, after K8d, his haan given |
| 20 | L | Framer Motion + GSAP + Three.js WebGPU | | pending (GSAP missing, no WebGPU scene, Scene3D three types) |
| 21 | M | MoQ | IETF MoQ relay | pending |
| 22 | N..V, X | Decide, Finance, People, Mail, Systems, Control, Cutover, Docs, AI, Extras | per blueprint TECH LAW cell | pending |
| 23 | Q-pq | ML-DSA hybrid + OpenPGP PQC | | pending |
| - | D-series | Devices & sessions D2b-D3 | | PAUSED by him |
| - | AX / W1-W6 | awam lane | | after the founder letter it needs |
