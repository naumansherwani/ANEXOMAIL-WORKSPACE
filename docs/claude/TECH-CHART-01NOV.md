
---

## TECHNOLOGY CHART UPDATE — 1 Nov 2026 10:00 PKT (founder order 09:51, verified by fetch, nothing copied from unverified text)

| Technology | Verified fact (source seen 1 Nov 2026) | Awam side | Founder side | Phase |
|---|---|---|---|---|
| WebTransport (browser) | Baseline: Chrome, Edge, Firefox, Safari 26.4 (Mar 2026) | LIVE: Rust `wtrpc`, UDP 3443, `wtransport` 0.1.14 + quinn 0.10.2 (old) | PLANNED, step 7a, `wtransport` 0.7.1 (latest on docs.rs) | awam upgrade 0.1.14 -> 0.7.x only on founder order after cutover |
| Caddy and WebTransport | quic-go gives HTTP/3 (default since Caddy 2.6). Caddy does not proxy WebTransport itself; maintainer points to `caddy-l4` for HTTP/3 passthrough. Issue 5086 page did not mention WebTransport, so the status stays unconfirmed | UDP 3443 is bound directly by Rust, not through Caddy | same: Rust binds UDP itself; Caddy L4 only if needed, tested first | 7a |
| MoQ (Media over QUIC) | `draft-ietf-moq-transport-22` dated 1 Oct 2026, still a WG draft, NO RFC; IESG milestone Dec 2026. Wire format still changes between drafts. Cloudflare relay: tech preview since Aug 2025 (draft-07 subset); self-serve relay beta Jul 2026 (secondary source). Cloudflare and moq.dev relays were not interoperable as of Jun 2026 | PLANNED for ANEXOChat one-to-many (channels, live rooms, announcements) behind a flag, pinned to one draft | same module, shared | after ANEXOChat core; never before |
| MoQ claims NOT verified | "Meta relay", "production ready", "kills WebRTC" from the pasted text. Do not write these anywhere as fact | - | - | - |
| Two-way calls | MoQ is NOT the right fit for 2-way calling; WebRTC stays (TURN doc: anexovideochat-turn.md) | WebRTC | WebRTC | unchanged |
| DBSC | Chrome 146 on Windows since 9 Apr 2026, macOS later | PLANNED | step 7b | 7b |
| Hybrid post-quantum TLS (X25519MLKEM768) | Chrome default; needs Go 1.24+ in Caddy. NOT yet checked on our server, so NOT claimed | check pending | check pending | 7b |
| TLS symmetric cipher | Server negotiated TLSv1.3 + TLS_AES_128_GCM_SHA256 (founder's openssl output). So "256-bit TLS" on the splash is inaccurate; use "TLS 1.3" | fix splash wording on awam only with founder word | founder splash says TLS 1.3 | 7b |
| Merkle audit ledger (E107) | RFC 6962-style; kernel 0.6.0 `merkle@1` | n/a | GREEN | step 5 done |

Honest answer to "tumhay ati hai kya": yes, Rust + tokio + wtransport + quinn are written here already (awam `wtrpc`). The website's WebTransport was NOT rewritten; it is old (0.1.14) and works.

FOUNDER DECISION 1 Nov 10:04: MoQ is built by us (own Rust relay on wtransport), no Cloudflare relay/API. Service = systemd, never pm2/Bun. Not started; comes after ANEXOChat core.

---

## TECHNOLOGY MATCH — 2 Nov 2026 05:10 PKT (founder 04:57 order: "technology match ker ke dai"). Locked rule vs repo (tech-proof.py) vs server/Chrome proof. Nothing here is assumed.

| Locked technology (rule) | In the repo code (tech-proof.py) | Proven on the server / Chrome (founder paste or my Chrome look) | Status |
|---|---|---|---|
| Rust axum 0.8 + tokio (Rule 61) | PROVEN founder Cargo.toml | founder-install 134 tests, service zinda (2 Nov 04:27) | GREEN |
| Ed25519 server->browser, HMAC+HKDF browser->server (FC15/FC38) | PROVEN sign.rs | "Ed25519 signing ON kid s1 ... write-request signature ENFORCED" (install output) | GREEN |
| SHA-256 audit chain + Merkle RFC 6962 (E107) | PROVEN ledger.rs | Chrome: "Chain intact, entry 30", seal #1 | GREEN |
| ONE Rust WASM kernel (Rule 52), Worker, pinned | PROVEN web-wasm, kernel.worker.ts | Chrome: awam serves 0.7.0, SHA-256 == pin | GREEN |
| Kernel merkle@1 (inclusion proofs) | PROVEN | Chrome 1 Nov "5 of 5 proven in this browser" | GREEN |
| Kernel merkle@2 (RFC 9162 consistency) | PROVEN lib.rs | server: Rust+SQL green; Chrome: needs a 2nd seal + the SPA with the /audit/proof fix | PARTIAL (not live-proven) |
| React 19.2, Vite 8, TypeScript, TanStack Router, Tailwind 4.2, shadcn | PROVEN | T1 GREEN 425ec14; Chrome live | GREEN |
| PostgreSQL + RLS, passkey SQL (E117/E118) | PROVEN | CHECK_E117/E118 OK, E65 sweep OK | GREEN |
| TLS 1.3 AES-256-GCM terminator rustls (T256-1) | PROVEN tls256.rs | server 1 Nov 15:05 + E119 prober rows | GREEN (test port 8443; Chrome padlock K3 pending) |
| X25519MLKEM768 post-quantum key exchange | n/a (Caddy) | openssl on both hosts 1 Nov 14:55 | GREEN |
| Three.js (lazy) | PROVEN Scene3D.tsx | Chrome live | GREEN |
| WebTransport / QUIC `wtransport` on founder | **MISSING** | awam has it (0.7.2), founder none | NOT IN CODE (K6 / 7a) |
| Passkey `webauthn-rs` (Rust) | **MISSING** | SQL side only | NOT IN CODE (J3 / 7-2) |
| Three.js WebGPU renderer | **MISSING** | - | NOT IN CODE (L2) |
| Framer Motion, GSAP on founder | **MISSING** | awam has both | NOT IN CODE (L1) |
| DBSC | **MISSING** | - | NOT IN CODE (K7 / 7b) |
| MoQ | **MISSING** | footer claims it, nothing runs | NOT IN CODE (M) |
| PQ mail content OpenPGP RFC 9980 | **MISSING** (a false PROVEN from a comment in tls256.rs was FIXED today: regex now needs a real function) | - | NOT IN CODE (Q4) |
| Streaming attachment encryption, live-state encryption | **MISSING** | - | NOT IN CODE (Q5 / PQN) |
| G5b signed checkpoints, G5c time anchors (no accounts) | **MISSING** (tech-proof rows added; the stale "G5c witnesses" row replaced by the G5-D wording) | - | NOT IN CODE (G5b-d) |

MISSING somewhere: 13 (tech-proof.py). Mixed layers found: 0. Bun/Node on the founder server: 0. Second kernel: 0.
