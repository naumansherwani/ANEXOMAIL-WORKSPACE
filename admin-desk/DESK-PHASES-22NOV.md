# ADMIN DESK: ORIGINAL BLUEPRINT BY PHASE (technology + features next to every phase). Written 22 Nov 2026 06:42 PKT, his 06:41 order.
## STRICT RULES (top of the Desk, read before EVERY phase; the commit gate "DESK PHASE START" fails a Desk code commit without a fresh read)
1. BEFORE EVERY PHASE: run `python3 docs/cursor-work/server/rules-read.py` then `python3 docs/cursor-work/server/desk-phase-start.py <phase>` and READ both outputs, plus docs/claude/admin-desk/state/WORKING-NOW.md and docs/claude/state/WORKING-NOW.md. The scripts print this page, the phase row and the ledger tail; receipts last 2 hours.
2. ADVANCE TECHNOLOGY ONLY, AND IT MUST BECOME CODE: the technology written next to a phase is his word, not a wish. A listed technology missing from code = OPEN GAP, the phase is never GREEN. Contract first (docs/claude/tech-contracts/CURRENT.md), code second.
3. HTTP/1 AND HTTP/2 ARE BANNED FOR THE DESK, everywhere (code, tests, comments, strings). HTTP/3 + WebTransport (QUIC) only. HTTP fallback is banned until HE approves it.
4. RULE 52: every Desk call and every stream frame is Desk-signed (Ed25519) and verified by the Desk's own Rust WASM kernel; requests carry the HKDF/HMAC MAC + replay nonce.
5. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" AND my live Chrome look (live bundle = repo, 390 / 820 / 1200+). Installed or written is not green.
6. ISOLATION: the Desk is its OWN security domain (own binary, keys, tables, cookie, role). Never mix with founder or awam code. Vendor ban stays (Caddy, Namecheap by his hands, Hetzner, his own Rust only).
7. Never remove or restyle a feature he did not name. Login look and Bridge look are his approved ones.
8. After EVERY message: repo + ledger + blueprint + COMPACT-SAVE updated with real date and time (rec.sh, desk-copy-sync, lane-sync, manifest-sync, rules-gate 0 fail). Phases of the Bridge are named by ALPHABET (A, B, C ...).
9. Address him only as Aap, Roman Urdu, short; end every reply with the Rule-70 table and "Abhi code mein NAHI"; server commands = ONE line.
## PHASES (technology | features | state at 22 Nov 2026 06:42 PKT)
| Phase | Advance technology | Features | State |
|---|---|---|---|
| R3a0 Host | Rust + Tokio + Axum 0.8, systemd hardening, TLS 1.3 AES-256-GCM, X25519MLKEM768, HTTP/3 (quinn + h3) on UDP 4400, Caddy edge | own process 127.0.0.1:4400, host gate, CSP + Trusted Types, HSTS, own installer | LIVE; browser page load still shows h2 (phase A below) |
| R3a1 Login look | React 19, TypeScript, Three.js (lazy), CSS backdrop-filter, WebAuthn detection | night-office scene, glass card, ONE light under the card, no scrollbar, eye icon, Save password, principle line | LIVE, his word "perfect" 22 Nov 06:02 |
| R3a2 Login door | Argon2id, constant-time, PostgreSQL RLS (AD1), audience "desk" | /desk/v1/auth/login, sessions, append-only ledger, desk_app role | LIVE |
| R3d Rule 52 | Rust Ed25519 signer, HKDF/HMAC, Desk-own Rust WASM kernel, deskCall | signed answers, kernel-verified, replay nonce | LIVE |
| R4-1 Shell + dashboard | React 19, TS, Tailwind 4, kernel | rail + bottom tabs, greeting, clock, account menu with Sign out, menu closes outside | LIVE (06:11 install) |
| R4-1b A | HTTP/3 page load, Alt-Svc, DNS HTTPS record (his Namecheap) | browser shows h3 for the Desk page | OPEN: Chrome shows h2; WebTransport reaches UDP 4400 (pcap) |
| R4-1b B Bridge doors | Rust Axum, Rule 52, PostgreSQL RLS (fadm_need) | summary, services, alerts, alert act | INSTALLED, no live look yet (not green) |
| R4-1b C WebTransport | Rust h3-webtransport (QUIC), Rule 52 per frame, Rust WASM kernel verify_frame (seq, STALE 12 s), Tokio | /wt/bridge stream, hello MAC, signed frames, real stream state on the chip, no fallback | C1 server INSTALLED; C2 kernel + client WRITTEN (sandbox Chromium proof ok); his install + my live look pending |
| R4-1b D Command Bar | React 19, Framer Motion, kernel stream data | Live SLA clock, Active P1 alerts with package prices, Mail and QUIC heartbeat, red pulse at P1 >= 1 | NOT written |
| R4-1b E Team fan-out | Tokio broadcast, WebTransport streams | one DB read per tick shared by all staff sessions | NOT written |
| R4-1b F MoQ | Media over QUIC tracks (IETF), WebTransport | named tracks summary/services/alerts as MoQ objects | NOT written (tracks already named in the frame) |
| AD2 / S1+S2 org + policy | PostgreSQL tuples (Zanzibar-style), RLS, Rust evaluator, deny-by-default | staff, relations, forbid-wins policy | NOT written |
| ON1..ON12 staff accounts | webauthn-rs, Argon2id, DBSC, device-bound passkeys | enrollment code, devices, leaver, recovery, zero-trust locks (AAGUID, IP + shift, circuit breaker) | NOT written |
| R3b / R4-2 inboxes | PostgreSQL RLS (fadm_mailbox), Rust, virtual list | hello, moveyourbusiness, resolved, billing (restricted), leo, noreply | NOT written |
| R3c auto mail | Rust, RFC 3834 Auto-Submitted | 7-day per-sender gate, Polar signed webhook | NOT written |
| R3e / R3f SLA | Rust, SQL SLA engine (AD4), SKIP LOCKED routing | assign, reply, clock stops only on human reply or resolve, root-cause note | NOT written (needs his support terms) |
| W1 transparency log | Merkle tiles, signed tree head | audit log browsers remember | NOT written |
| W3 hybrid PQ | ML-DSA + Ed25519, ML-KEM | post-quantum signatures and mail | NOT written |
| R4-3..R4-10 mail | React, Tiptap 3, Rust, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | compose, rich text, undo/schedule, attachments, outbound TLS policy | NOT written |
| R-CRM | React 19, Rust, RLS | accounts, leads, pipeline, tasks, reports in company style | NOT written |
| R4 Managed Move-In | Rust async IMAP migrator | company mailbox migration | NOT written |
| R3g Final | Rust, React | dashboard + final audit + load proof (S10) | NOT written |
Sources: BLUEPRINT-ADMIN-DESK.md (R3a detail tables), MASTER-PLAN-22NOV.md, REMAINING-LIST-22NOV.md, BRIDGE-PLAN-22NOV.md, EMPLOYEE-ACCOUNTS-PLAN-22NOV.md, SCALE-50K-DESIGN-22NOV.md, WORLD-ADVANCE-DESK-22NOV.md. This page is the one-page summary; when a phase starts its own feature table (feature | code | technology | HAAN) is written in BLUEPRINT-ADMIN-DESK.md.
