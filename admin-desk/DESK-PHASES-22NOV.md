# ADMIN DESK: ORIGINAL BLUEPRINT BY PHASE (technology + features next to every phase). Written 22 Nov 2026 06:42 PKT, his 06:41 order; ALPHABETIC ORDER (his 06:43 word) laid out 22 Nov 2026 06:50 PKT: A to Q in build order, old ids in brackets.
## STRICT RULES (top of the Desk, read before EVERY phase; the commit gate "DESK PHASE START" fails a Desk code commit without a fresh read)
1. BEFORE EVERY PHASE: run `python3 docs/cursor-work/server/rules-read.py` then `python3 docs/cursor-work/server/desk-phase-start.py <phase>` and READ both outputs, plus docs/claude/admin-desk/state/WORKING-NOW.md and docs/claude/state/WORKING-NOW.md. The scripts print this page, the phase row and the ledger tail; receipts last 2 hours.
2. ADVANCE TECHNOLOGY ONLY, AND IT MUST BECOME CODE: the technology written next to a phase is his word, not a wish. A listed technology missing from code = OPEN GAP, the phase is never GREEN. Contract first (docs/claude/tech-contracts/CURRENT.md), code second.
3. HTTP/1 AND HTTP/2 ARE BANNED FOR THE DESK, everywhere (code, tests, comments, strings). HTTP/3 + WebTransport (QUIC) only. HTTP fallback is banned until HE approves it.
4. RULE 52: every Desk call and every stream frame is Desk-signed (Ed25519) and verified by the Desk's own Rust WASM kernel; requests carry the HKDF/HMAC MAC + replay nonce.
5. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" AND my live Chrome look (live bundle = repo, 390 / 820 / 1200+). Installed or written is not green.
6. ISOLATION: the Desk is its OWN security domain (own binary, keys, tables, cookie, role). Never mix with founder or awam code. Vendor ban stays (Caddy, Namecheap by his hands, Hetzner, his own Rust only).
7. Never remove or restyle a feature he did not name. Login look and Bridge look are his approved ones.
8. After EVERY message: repo + ledger + blueprint + COMPACT-SAVE updated with real date and time (rec.sh, desk-copy-sync, lane-sync, manifest-sync, rules-gate 0 fail). EVERY phase is named by ALPHABET in build order (A, B, C ... Q), never S-numbers; the old ids stay in brackets.
9. Address him only as Aap, Roman Urdu, short; end every reply with the Rule-70 table and "Abhi code mein NAHI"; server commands = ONE line.
## PHASES (technology | features | state at 22 Nov 2026 06:50 PKT). Foundation rows first (done), then A to Q in order. One phase at a time, each GREEN only after my live Chrome look.
| Phase | Advance technology | Features | State |
|---|---|---|---|
| R3a0 Host | Rust + Tokio + Axum 0.8, systemd hardening, TLS 1.3 AES-256-GCM, X25519MLKEM768, HTTP/3 (quinn + h3) on UDP 4400, Caddy edge | own process 127.0.0.1:4400, host gate, CSP + Trusted Types, HSTS, own installer | LIVE; browser page load still shows h2 (phase A below) |
| R3a1 Login look | React 19, TypeScript, Three.js (lazy), CSS backdrop-filter, WebAuthn detection | night-office scene, glass card, ONE light under the card, no scrollbar, eye icon, Save password, principle line | LIVE, his word "perfect" 22 Nov 06:02 |
| R3a2 Login door | Argon2id, constant-time, PostgreSQL RLS (AD1), audience "desk" | /desk/v1/auth/login, sessions, append-only ledger, desk_app role | LIVE |
| R3d Rule 52 | Rust Ed25519 signer, HKDF/HMAC, Desk-own Rust WASM kernel, deskCall | signed answers, kernel-verified, replay nonce | LIVE |
| R4-1 Shell + dashboard | React 19, TS, Tailwind 4, kernel | rail + bottom tabs, greeting, clock, account menu with Sign out, menu closes outside | LIVE; boot screen (Anexomail mark + ADMIN DESK) live-confirmed 22 Nov 2026 06:59 PKT (bundle = repo, raw HTML has boot, no big heading) |
| A Browser HTTP/3 | HTTP/3 page load, Alt-Svc, DNS HTTPS record (his Namecheap) | browser shows h3 for the Desk page | OPEN: Chrome shows h2; WebTransport reaches UDP 4400 (pcap) |
| B Bridge doors | Rust Axum, Rule 52, PostgreSQL RLS (fadm_need) | summary, services, alerts, alert act | GREEN for the read path 22 Nov 2026 06:49 PKT: the three Bridge queries (summary, services, alerts) run live through the C stream and every frame was kernel-verified; alert-act door tested in sandbox only (no live alert yet) |
| C WebTransport | Rust h3-webtransport (QUIC), Rule 52 per frame, Rust WASM kernel verify_frame (seq, STALE 12 s), Tokio | /wt/bridge stream, hello MAC, signed frames, real stream state on the chip, no fallback | GREEN 22 Nov 2026 06:49 PKT: WIRED: YES / REAL: YES / TECH-LAW CHECKED. His install 06:42 PKT, my live Chrome on admindesk.anexomail.com: live bundle desk-BdocEYqO.js = repo build, chip data-live=live 'Live · verified', stayed live past the 12 s stale limit (heartbeat works), no console errors. OPEN LOOK: 390 / 820 live (my Chrome window would not resize; layout unchanged except chip text) |
| D Command Bar | React 19, Framer Motion, kernel stream data | Live SLA clock, Active P1 alerts with package prices, Mail and QUIC heartbeat, red pulse at P1 >= 1 | WRITTEN 22 Nov 2026 06:59 PKT (not green): desk_bridge_pure.ts + 5 bun tests, DeskCommandBar.tsx (motion, red pulse + icon + words, reduced motion), wired into DeskShell from the kernel-verified stream; SLA clock says 'No cases yet' and prices say 'not connected yet' (no data exists, nothing invented); needs his install + my Chrome look |
| D1 Cards + router | React 19, TS, Desk router, Framer Motion | account cards removed, clickable cards, /dashboard/* | PLANNED 22 Nov 2026 07:15 PKT (DASHBOARD-CARDS-CLICK-PLAN-22NOV.md) |
| D2 Alerts page | React, Rust alert act door, Rule 52 | P1 / unacked list, ack, filters in URL | PLANNED 07:15 PKT |
| D3 Service health page | React, stream services track | per-service detail | PLANNED 07:15 PKT |
| D4 Wiring registry | desk_cards.ts + test + gate | card -> route -> track -> phase, "Waits for" pages | PLANNED 07:15 PKT |
| D5 Plans + SLA doors | Rust, Postgres, Polar HMAC | doors ready, fill when J / K land | PLANNED 07:15 PKT |
| D6 Rest of dashboard list | per DASHBOARD-LIVE-COMMAND-22NOV.md B1..B13 | lands in phases H, K, N, P, Q | PLANNED 07:15 PKT |
| E Team fan-out | Tokio broadcast, WebTransport streams | one DB read per tick shared by all staff sessions | NOT written |
| F MoQ | Media over QUIC tracks (IETF), WebTransport | named tracks summary/services/alerts as MoQ objects | NOT written (tracks already named in the frame) |
| G Org + policy (AD2, S1+S2) | PostgreSQL tuples (Zanzibar-style), RLS, Rust evaluator, deny-by-default | staff, relations, forbid-wins policy | NOT written |
| H Staff accounts (ON1..ON12) | webauthn-rs, Argon2id, DBSC, device-bound passkeys | enrollment code, devices, leaver, recovery, zero-trust locks (AAGUID, IP + shift, circuit breaker) | NOT written |
| I Inboxes (R3b, R4-2) | PostgreSQL RLS (fadm_mailbox), Rust, virtual list | hello, moveyourbusiness, resolved, billing (restricted), leo, noreply | NOT written |
| J Auto mail (R3c) | Rust, RFC 3834 Auto-Submitted | 7-day per-sender gate, Polar signed webhook | NOT written |
| K Cases + SLA (R3e, R3f) | Rust, SQL SLA engine (AD4), SKIP LOCKED routing | assign, reply, clock stops only on human reply or resolve, root-cause note | NOT written (needs his support terms) |
| L Transparency log (W1) | Merkle tiles, signed tree head | audit log browsers remember | NOT written |
| M Hybrid post-quantum (W3) | ML-DSA + Ed25519, ML-KEM | post-quantum signatures and mail | NOT written |
| N Mail craft + attachments (R4-3..R4-10) | React, Tiptap 3, Rust, ML-KEM, WebTransport, Hetzner Storage Box, ClamAV, OpenPGP PQC (RFC 9980) | compose, rich text, undo/schedule, attachments, outbound TLS policy | NOT written |
| O CRM (R-CRM) | React 19, Rust, RLS | accounts, leads, pipeline, tasks, reports in company style | NOT written |
| P Managed Move-In (R4-11) | Rust async IMAP migrator | company mailbox migration | NOT written |
| Q Final audit + load proof (R3g, S10) | Rust, React | dashboard + final audit + load proof (S10) | NOT written |
Sources: BLUEPRINT-ADMIN-DESK.md (R3a detail tables), MASTER-PLAN-22NOV.md, REMAINING-LIST-22NOV.md, BRIDGE-PLAN-22NOV.md, EMPLOYEE-ACCOUNTS-PLAN-22NOV.md, SCALE-50K-DESIGN-22NOV.md, WORLD-ADVANCE-DESK-22NOV.md. This page is the one-page summary; when a phase starts its own feature table (feature | code | technology | HAAN) is written in BLUEPRINT-ADMIN-DESK.md.
