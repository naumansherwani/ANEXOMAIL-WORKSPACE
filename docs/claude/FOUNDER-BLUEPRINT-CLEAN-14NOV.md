# FOUNDER BLUEPRINT, CLEAN ORDER (14 Nov 2026 06:35 PKT)

Written on the founder's order 14 Nov 06:24: phases in order, numbered, the advance technology next to each phase, whether it is IN CODE, and a GREEN mark only where the repo has proof. The long history stays in `BLUEPRINT-ABC-01NOV.md`; this file is the readable one. Founder lane only (awam is in its own blueprint).

**How to read it.** GREEN = WIRED: YES / REAL: YES / TECH-LAW CHECKED, proven on his server and in my live Chrome. PARTLY = built and installed but one part is not proven. NOT GREEN = not built or not proven. "In code" says YES only if the technology is really in the repo code and running.

Stack that every phase inherits (founder technology law, 11 Nov 03:21 and 13 Nov 20:30): Rust WebAssembly kernel (one kernel), Rust + Tokio + Axum backend, HTTP/3 only (quinn + h3), WebTransport over UDP 443, AES-256-GCM only, X25519MLKEM768, React 19 + TypeScript + TanStack + Vite + Tailwind 4 + Radix/shadcn, PostgreSQL with RLS. No WebSocket, no SSE, no H2/H1, no Bun/Node on the server, no third-party vendor.

| # | Phase | What it is | Advance technology | In code | Status |
|---|---|---|---|---|---|
| 1 | A | Device approval + request signatures | Rust Ed25519/ES256, WebAuthn L3, kernel `envelope@1` | YES | GREEN |
| 2 | B | Settings S1 (photo, name, city, graphics, sidebar) | React 19 + TS strict + Tailwind 4 + shadcn; data over the kernel | YES | GREEN |
| 3 | C | Server leftovers (Polar token DROPPED by him; data via webhook ledger in O) | Rust + SQL | YES (C1 dropped, C2 parked) | GREEN (as scoped) |
| 4 | D | UI stack | React 19, Vite 8, TanStack Router, Tailwind 4, shadcn, TS strict | YES | GREEN |
| 5 | E | Loophole fixes L1-L12 | CSP, Trusted Types, hash-pinned WASM | YES | GREEN except L5 (parked) and lockfile (open) |
| 6 | F | WASM kernel verifies in the browser | Rust WASM kernel, Worker, pinned SHA-256 | YES | GREEN |
| 7 | G | Audit ledger, Merkle, seals, anchors (G1-G5d) | SQL hash chain, RFC 9162 consistency proofs, C2SP signed checkpoints, kernel `merkle@2`, OpenTimestamps + RFC 3161 | YES | GREEN |
| 8 | H | Settings S2: time machine + drift | SQL + Rust + kernel verify | YES | GREEN |
| 9 | I | Appearance, Ambient Studio, key registry | Rust + SQL + React CSS layers | YES | GREEN |
| 10 | J1-J5 | Passkey + Privacy (one factor, no 2FA) | WebAuthn L3, Rust `passkey.rs`, kernel `action@1` | YES | GREEN (T3 two-hardware-key flow never run for real) |
| 11 | J6 | Phone alerts | Web Push (VAPID) from Rust | YES | GREEN on desktop Chrome (real phone optional) |
| 12 | J8 | Vault lease + panic lock | SQL E143-E145 + Rust + kernel | YES | GREEN (panic lock not run for real; vault key encrypts nothing yet) |
| 13 | K1-K4 | Post-quantum key exchange, AES-256 on :443 | Rust `tls256.rs` (rustls, TLS 1.3, AES-256-GCM only), X25519MLKEM768, SQL E119 | YES | GREEN |
| 14 | K5-K6 | AES-256 for awam (separate lane); QUIC | Rust quinn / wtransport | YES | GREEN |
| 15 | K7, K7c | Device-bound sessions (DBSC), enforce mode | hybrid ML-DSA-65 + ECDSA P-256 device proof, kernel `mldsa@1` | YES | GREEN (Safari/Firefox ML-DSA proof closed by his word, not live-proven) |
| 16 | K8a-K8d | HTTP/3 primary, ML-KEM proof, kernel RPC | Rust quinn + h3, kernel `rpc@1` over WebTransport | YES | GREEN |
| 17 | K8e | ALPN h3 only; TCP 443 of the founder host speaks no HTTP | own Rust authoritative DNS with HTTPS record alpn=h3, Rust SNI front | YES | GREEN by his order 14 Nov (820 tablet waived by him) |
| 18 | KP3 step 1 | WebTransport on UDP 443 | Rust quinn + h3 + h3-webtransport on the one endpoint | YES | GREEN |
| 19 | KP3 step 2 | Browser + kernel same origin | Rust WASM kernel dials the page origin; CSP `connect-src 'self'` | YES | GREEN |
| 20 | KP3 latency | Adaptive QUIC Retry | Rust quinn | YES | GREEN |
| 21 | KP3 pre-connect | Worker dials /wt/rpc while the kernel loads | React-TS Worker + Rust WASM kernel | YES | INSTALLED, NOT GREEN (its own effect cannot be measured from outside) |
| 22 | KP3 step 3 | QUIC path row (honest chip, measured RTT) | React-TS + Worker + kernel session | YES | GREEN by his order |
| 23 | KP3 step 4 | Dashboard live feed over WebTransport only | kernel `flive@1` over QUIC | YES | GREEN |
| 24 | KP3 step 4b | No SSE anywhere for the founder | Rust axum (SSE routes deleted), kernel WebTransport | YES | GREEN |
| 25 | KP3 step 5 | UDP 4443 removed (CSP, env, ufw, listener) | Rust quinn + h3-webtransport on the one UDP 443 endpoint; shell installer with rollback | YES | GREEN 14 Nov 06:01 (receipts 25, 26, my live Chrome) |
| 26 | KP3 audit A | API latency audit: slow-call log | Rust axum, `wtrpc.rs` | YES in repo | NOT GREEN: install failed once and rolled back (receipt 27), retry pending |
| 27 | L | Look: Framer Motion + GSAP + Three.js WebGPU; LA-1..LA-7 orb and Bridge map features | WebGPU + TSL (orb pixel-equal), GSAP, Radix Popover, SQL E166, Rust `bridge.rs` | YES | PARTLY: L2 WebGPU, LA-1/2/3/5/6 GREEN; LA-4 looked live; LA-7b map particles written, not proven |
| 28 | S5 | TanStack Start in SPA mode (decided 13 Nov) | TanStack Start, static shell, Rust serves it, no Node/Bun | NO | NOT GREEN (decided, not built) |
| 29 | Q | Mail + Calendar (Q0 research done, Q1 mailbox, Q2 attachments, Q3 parallel chunks over WebTransport, Q4 OpenPGP PQC RFC 9980, Q5 PQ network, Q6 sealed agreements) | Rust + SQL + kernel, ML-KEM / ML-DSA, resumable chunks over WebTransport, ClamAV, Hetzner Storage Box | PARTLY (plan written, mail intake and Mail page exist, Q3 pushed stream not built) | NOT GREEN |
| 30 | M | MoQ (Media over QUIC) relay | Rust relay on QUIC + kernel | NO | NOT GREEN |
| 31 | N | Decide + Live Pulse + push, Device Trust Map | Rust push + kernel WebTransport, SQL | NO | NOT GREEN |
| 32 | O | Finance deck (Polar webhook ledger, revenue, billing, release) | Rust webhook verify + SQL ledger + React | NO | NOT GREEN |
| 33 | P | People: Org, CRM, Team, Account 360, Work, Insider Guard | SQL RLS + ledgers, Rust, React | NO | NOT GREEN |
| 34 | R | Systems: health, analytics, speed, admin, safety, chat, Mail Desk (R3) | Rust probes, mesh sync over QUIC | NO | NOT GREEN |
| 35 | S | Control: kill switch, flags, executor, poison pill | Rust + SQL + passkey two-key gates | NO | NOT GREEN |
| 36 | T | Cutover: remove old Lovable/Bun founder routes | Rust only, after Rust == Bun proof | NO | NOT GREEN |
| 37 | U | Docs + Sheets | WOPI host in Rust | NO | NOT GREEN |
| 38 | V | Founder AI (founder only) | Rust + React, kernel | NO | NOT GREEN |
| 39 | X | Extra advanced: proof of restore, continuity, served-code seal, supply-chain board | Rust + SQL + kernel, PQ signatures | NO | NOT GREEN |
| 40 | D-series | D3 UI and D2b Rust (policy change needs a fresh passkey touch) | Rust + SQL E155-E157 + React | PARTLY (D1, D2b installed; D2b-5 written) | PAUSED by him, resumes after Q |

Order of work from here, only on his word, one step at a time: finish the audit install (26), KP2 laptop SSH test, Q3 pushed mail stream, then back to D3, then M, N, O, P and the rest in letter order.

Open technology gaps (honest list): kernel Merkle `merkle@2` pin on the awam side, 0-RTT (only if measured), `/wt/core`, ssh key-only hardening (needs his haan), live Safari/Firefox ML-DSA proof (closed by his word).
