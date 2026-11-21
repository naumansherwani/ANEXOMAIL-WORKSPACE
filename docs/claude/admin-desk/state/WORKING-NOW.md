# ADMIN DESK WORKING NOW (auto snapshot before a compaction, 21 Nov 2026 21:27 PKT) - read this FIRST for the Desk after a compaction
DOING: login demo published; installer fixed
NEXT STEP: his desk-install + desk-appdb, his demo pick
HIS LAST WORD: login simple passkey, no ball, philosophy
LAWS: Desk isolation (never mix with founder/awam) / HTTP/1 + HTTP/2 BANNED, HTTP/3 only / Rule 52 kernel-verified calls / founder technology or MORE advanced / every phase row = feature + code + technology + HAAN / address him only as Aap, Roman Urdu short, end with Rule-70 table + 'Abhi code mein NAHI'.
FOLDER: canonical docs/claude/admin-desk/ (edit here) + identical root copy admin-desk/ (python3 docs/cursor-work/server/desk-copy-sync.py sync).

## Phase table (docs/claude/admin-desk/state/PHASES.md)
| Phase | Feature | Code | Technology | HAAN | State |
|---|---|---|---|---|---|
| R3a0 | Own process, host gate, headers, own bundle | server/src/main.rs, founder-web/vite.desk.config.ts | Rust, Tokio, axum 0.8, CSP + Trusted Types, Vite 8 | his 21 Nov 07:50 | LIVE on his server |
| R3a0-s1 | TLS 1.3 AES-256-GCM public path | server/awam-edge (existing) | Rust rustls, AES-256-GCM only | his 08:07 | PROVEN (his openssl 08:53) |
| R3a0-s2 | Own HTTP/3 (QUIC) listener, X25519MLKEM768, BBR | server/src/h3.rs | quinn, h3, rustls PQ, ring | his 09:08 / 09:18 | PROVEN on his server 09:55 (H3CHECK OK); DNS AAAA + HTTPS record = his hands, OPEN |
| R3a1 | Cinematic login + landing, telemetry pill | founder-web/src/desk/* | React 19, Three.js, Tailwind 4, kernel (Rule 52) | his 08:31 | LIVE (pill HTTP/3 line after his next desk-install.sh) |
| R3a2-1 | AD1 SQL: schema desk, desk_app, RLS, SHA-256 ledger | sql/AD1.sql, sql/checks/AD1-check.sql, scripts/ad-sql-run.sh | PostgreSQL ROW LEVEL SECURITY, hash chain | his 08:19 | WRITTEN + TESTED on PG16 (as superuser AND as a NON-superuser hosted-editor role) AND the runner tested end to end (own database anexo_desk created, AD1 applied, 8/8 checks, 2nd run skipped, quoted PGHOST reproduced); NOT yet run on his server |
| R3a2-2 | auth.rs: ARGON2ID, constant-time, token audience desk | server/src/auth.rs, scripts/desk-owner.sh | Rust argon2 | his 08:07 / 10:38 | CODE + 10 tests pass; AD1 = already run on his server (10:38); owner not created yet (his desk-install then desk-owner.sh); login DOOR next |
| R3a2-3 | DBSC device-bound session | server/src/auth.rs | DBSC | his 08:07 | after auth.rs |
| R3a1-b | Orb pulse / shockwave / zoom into the 3-pane workspace | founder-web/src/desk | Three.js, GSAP | his 08:28 | after R3a2 |
| R3a2-4 | Passkey ceremony (optional) | server/src/passkey.rs + UI | WebAuthn, rp_id admindesk.anexomail.com | his 08:07 | after DBSC |
| R3p | Plans (Business Premium, Max first; Business tiers advanced only; Basic stays Bun) | AD2 SQL, polar.rs, sla.rs, lanes UI | Rust, HMAC-SHA256 webhook, RLS | his 09:08 | after the Desk; needs his support terms (R3p0) |
| R3b-g | Inboxes, auto mail, dashboard, reply, SLA engine, final | later | Rust, kernel RPC | his 3-day plan | Sun 22 - Mon 23 Nov |

> [21 Nov 2026 10:31 PKT] AD1 flow: editor = sql/AD1.sql, server = scripts/ad-check.sh (read-only) after ad-db-env.sh once. WAITS his editor run + check paste.

> [21 Nov 2026 10:33 PKT] ad-db-env DONE on his server (10:3x); next his editor AD1 run + ad-check paste.

> [21 Nov 2026 10:35 PKT] AD1 now AUTO: ad-auto.sh (runs if missing, says already run if done). WAITS his output.

> [21 Nov 2026 10:35 PKT] AD1: ad-db-env DONE on his server; ad-auto.sh written (auto run / already run). WAITS his run + paste.

> [21 Nov 2026 10:44 PKT] ORDER NOW: AD1 DONE -> auth.rs (written) -> desk-install -> desk-owner.sh (his password) -> login door + AD1b desk_app login -> DBSC -> orb pulse/zoom -> passkey (optional) -> R3p plans -> R3b-g (Sun 22 - Mon 23 Nov).

> [21 Nov 2026 10:56 PKT] R3a2-2: owner admindesk@ CREATED on his server, auth.rs installed. NEXT login door + AD1b. desk-business-account.sh removed (no Desk relation).

> [21 Nov 2026 11:01 PKT] PLAN after login: see PLAN-DESK-UI-COPY-21NOV.md (R4-1..R4-10 = founder phases copied in order; Desk gate + /desk/v1 endpoints only).

> [21 Nov 2026 20:44 PKT] R3a2-3 LOGIN DOOR written + tested locally (door.rs, AD1b). His 3 server steps: ad-auto (AD1b) > desk-appdb.sh > desk-install. Then login at /adminlogin: admindesk@anexomail.com + his password. NEXT R4-1 copy of founder shell (PLAN-DESK-UI-COPY-21NOV.md).

## Desk ports on his server: TCP 127.0.0.1:4400 (loopback) + UDP 4400 (own HTTP/3, ufw open); public TCP 443 via founder SNI front -> awam-edge -> Caddy -> Desk; Desk cert copy /etc/anexomail/tls/desk (root only, systemd LoadCredential)

## Last 8 Desk commits
- 3d4bc21d 21 Nov 21:27 Desk login: no-passkey line removed
- 9695c321 21 Nov 21:26 ledger line b69596cc
- b69596cc 21 Nov 21:26 Desk login final + DB CA support
- a11cf985 21 Nov 21:22 ledger line e41e4f6f
- e41e4f6f 21 Nov 21:22 Desk login: restored, only ball removed and passkey moved down
- 6f373d34 21 Nov 21:21 ledger line eb8dcef6
- eb8dcef6 21 Nov 21:21 CLEAN-PUSH LAW + records
- f411782e 21 Nov 21:16 ledger line 672ba916

## Uncommitted Desk files
 M docs/claude/admin-desk/state/WORKING-NOW.md

## Gate rows (admin-desk/gates/DESK-FEATURES.json)
warn ADMIN DESK OPEN until 23 Nov: R3a2-dbsc [R3a2] Device-bound session (DBSC) -> needs DBSC in admin-desk/server/src/auth.rs
warn ADMIN DESK OPEN until 24 Nov: R3p1-plans [R3p1] Plans as data (Premium, Max first) -> needs PostgreSQL RLS, hash-chained ledger in admin-desk/sql/AD2.sql
warn ADMIN DESK OPEN until 24 Nov: R3p2-webhook [R3p2] Polar signed webhook door -> needs Rust Tokio axum, HMAC-SHA256 constant-time in admin-desk/server/src/polar.rs
warn ADMIN DESK OPEN until 24 Nov: R3p4-sla [R3p4] SLA clock per plan -> needs Rust Tokio timers in admin-desk/server/src/sla.rs
warn ADMIN DESK OPEN until 2026-12-05: QUIC-datagram [R3a0-s2+] QUIC DATAGRAM (RFC 9221) + WebTransport for live Desk events (Rule 52 kernel RPC over QUIC) -> needs QUIC 
warn ADMIN DESK OPEN until 2026-12-20: QUIC-moq [R3a0-s2+] Media over QUIC (MoQ) for Desk voice notes / live updates, later phase -> needs Media over QUIC (MoQ) for Desk 
warn ADMIN DESK OPEN until 2027-01-10: QUIC-v2 [R3a0-s2+] QUIC version 2 (RFC 9369) when quinn ships it -> needs QUIC version 2 (RFC 9369) when quinn ships it in admin-de
warn ADMIN DESK OPEN until 2027-01-10: QUIC-ech [R3a0-s2+] Encrypted Client Hello (ECH) on the Desk host with the DNS HTTPS record, when rustls server ECH is stable -> ne
