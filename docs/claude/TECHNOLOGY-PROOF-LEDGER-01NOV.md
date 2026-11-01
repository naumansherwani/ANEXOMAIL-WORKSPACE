# TECHNOLOGY PROOF LEDGER — founder + awam (1 Nov 2026 14:15 PKT)
Founder order 14:04: "jo bhi latest technology hai woh founder aur awam ko mile gi ... yeh prove kerna hai ke yeh jitni bhi latest technology note kerwaye hain woh founder ko do".
Proof = a script that reads the repo and shows file:line for every technology, or says MISSING. Run it any time: `python3 docs/cursor-work/server/tech-proof.py` (`--md` for this table). It claims nothing it cannot find in a file (Rule 69). Technologies are the ones noted in AGENTS.md top block, TECH-MAP 0d, FOUNDER-TECHNOLOGY-ADOPTION-30OCT.md.

| Technology | Founder lane | Awam lane | Built by |
|---|---|---|---|
| Rust + axum 0.8 | PROVEN server/founder/Cargo.toml:9 | PROVEN server/rust/Cargo.toml:21 | - |
| Tokio async runtime | PROVEN server/founder/Cargo.toml:10 | PROVEN server/rust/Cargo.toml:22 | - |
| WebTransport / QUIC (wtransport) | MISSING | PROVEN server/rust/Cargo.toml:30 | founder 7a |
| HTTP/3 edge (Caddy) | n/a here | n/a here | server check (not repo code) |
| Ed25519 server->browser | PROVEN server/founder/src/sign.rs:5 | n/a here | - |
| HMAC + HKDF browser->server | PROVEN server/founder/src/sign.rs:5 | n/a here | - |
| SHA-256 audit chain + Merkle | PROVEN server/founder/src/ledger.rs:1 | n/a here | - |
| Rust WASM kernel (Rule 52) | PROVEN web-wasm/src/lib.rs:1 | PROVEN src/lib/rpc-contract.ts:109 | - |
| Kernel runs in a Web Worker | PROVEN founder-web/src/kernel.worker.ts:18 | n/a here | - |
| Kernel module merkle@1 | PROVEN web-wasm/src/lib.rs:32 | n/a here | - |
| React 19.2 | PROVEN founder-web/package.json:20 | PROVEN package.json:68 | - |
| Vite 8 | PROVEN founder-web/package.json:29 | PROVEN package.json:102 | - |
| TypeScript | PROVEN founder-web/package.json:25 | PROVEN package.json:100 | - |
| TanStack Router | PROVEN founder-web/package.json:15 | PROVEN package.json:52 | - |
| TanStack Start (SSR) | n/a here | PROVEN package.json:53 | founder is a static SPA by design |
| Tailwind CSS 4.2 | PROVEN founder-web/package.json:23 | PROVEN package.json:77 | - |
| shadcn / Radix + cva | PROVEN founder-web/package.json:18 | PROVEN package.json:19 | - |
| Three.js (lazy) | PROVEN founder-web/src/Scene3D.tsx:22 | PROVEN package.json:78 | - |
| Three.js WebGPU renderer | MISSING | MISSING | founder UI phase 'WebGPU' (after 7-4) |
| Framer Motion | MISSING | PROVEN package.json:60 | founder UI phase 'Motion + GSAP' (after 7-4) |
| GSAP | MISSING | PROVEN package.json:61 | founder UI phase 'Motion + GSAP' (after 7-4) |
| PostgreSQL + RLS | PROVEN docs/cursor-work/sql/E117_founder_passkey_stepup_recovery.sql:117 | PROVEN docs/cursor-work/sql/E24_account_deletion.sql:61 | - |
| Passkey / WebAuthn in SQL | PROVEN docs/cursor-work/sql/E118_founder_chairman_protocol.sql:183 | n/a here | - |
| webauthn-rs (Rust passkey) | MISSING | n/a here | founder 7-2 |
| DBSC (device-bound sessions) | MISSING | n/a here | founder 7b |
| Post-quantum hybrid TLS check | n/a here | n/a here | founder 7b (server check first) |
| TLS 1.3 AES-256-GCM-only terminator (rustls) | PROVEN server/founder/src/tls256.rs:15 | MISSING | founder T256-1 written; awam T256-2 (after founder proof + his written haan) |
| TLS posture ledger (SQL, real handshakes) | PROVEN docs/cursor-work/sql/E119_founder_tls_posture.sql:44 | n/a here | - |
| MoQ (Media over QUIC) | MISSING | MISSING | founder MoQ-F (after 7a); awam MQ0-MQ4 |

## What is MISSING, and the phase that builds it (founder lane unless written otherwise)
| Technology | Why missing | Phase | Rule |
|---|---|---|---|
| webauthn-rs | passkey ceremonies are SQL-only so far (E117/E118) | **7-2 (NEXT)** | founder, same canonical action hash |
| WebTransport (`wtransport`) | founder live channel still SSE/polling | **7a** (after 7) | own UDP port + cert, founder picks port |
| DBSC | not built; the login page must NOT claim it | **7b** | Chrome 146 Windows, founder's setup |
| Post-quantum hybrid TLS | server check not yet run, so NOT claimed | **7b** (read-only openssl check first) | |
| Framer Motion + GSAP | locked in TECH-MAP 0d for the founder UI, not in `founder-web/package.json` (awam has both) | **NEW row 7c: "Motion + GSAP"** after 7-4; must keep the CINEMATIC look pixel-equal (FC43) | founder UI |
| Three.js WebGPU renderer | founder Scene3D is WebGL2 first by design ("WebGPU swaps in later") | **NEW row 7d: "WebGPU renderer"** after 7c, WebGL2 fallback kept | founder UI |
| MoQ | not in either lane; IETF draft, no RFC | **NEW row 7e "MoQ-F"** (founder first, after 7a, Live Pulse behind a flag), then awam MQ0-MQ4 (ONE-ORDER-27OCT.md) | honest wording: "adopting MoQ (IETF draft)" until it is green |
Awam lane gaps: MoQ (MQ0-MQ4), WebGPU renderer (not asked; Three.js is there). Awam code is not touched by this ledger.

## Fact verified on the server (founder paste, 1 Nov 14:19) — closes the open question
Awam live `/opt/anexomail-rust/Cargo.lock`: **wtransport 0.7.2, quinn 0.11.11** (matches the repo `Cargo.toml`). The earlier chart value "0.1.14 / quinn 0.10.2" was stale and is corrected. Founder host TLS: TLSv1.3, `TLS_AES_128_GCM_SHA256`, certificate verification OK. The check printed no key-exchange group, so post-quantum hybrid TLS is still UNKNOWN and is NOT claimed anywhere (7b will check with a command that shows the negotiated group).

## Order the missing ones will be built (one phase at a time, Rule 66)
7-2 webauthn-rs -> 7-3 Privacy UI -> 7-4 enforce -> 7-5 flare -> 7a wtransport -> 7b DBSC + PQ TLS -> 7c Motion + GSAP -> 7d WebGPU -> 7e MoQ-F. Each is green on the server + his Chrome before the next starts; this script is re-run after each and the MISSING count must drop by exactly the one that was built.

## Server-green (founder pastes) so far on this ledger
E117 (13:00), E118 (13:19), E119 + Rust tls256 + prober route + install (14:45). Counted `MISSING` after the run is in the printed footer of `tech-proof.py`.
