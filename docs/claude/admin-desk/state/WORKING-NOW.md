# ADMIN DESK WORKING NOW (auto snapshot before a compaction, 21 Nov 2026 10:08 PKT) - read this FIRST for the Desk after a compaction
DOING: Desk WORKING-NOW + PHASES inside the Desk folder; runner creates own DB anexo_desk, tested end to end
NEXT STEP: his ONE line ad-sql-run.sh (no argument) -> AD1 on server; then auth.rs ARGON2ID -> DBSC -> orb -> passkey -> R3p
HIS LAST WORD: 10:04 desk working now
LAWS: Desk isolation (never mix with founder/awam) / HTTP/1 + HTTP/2 BANNED, HTTP/3 only / Rule 52 kernel-verified calls / founder technology or MORE advanced / every phase row = feature + code + technology + HAAN / address him only as Aap, Roman Urdu short, end with Rule-70 table + 'Abhi code mein NAHI'.
FOLDER: canonical docs/claude/admin-desk/ (edit here) + identical root copy admin-desk/ (python3 docs/cursor-work/server/desk-copy-sync.py sync).

## Phase table (docs/claude/admin-desk/state/PHASES.md)
| Phase | Feature | Code | Technology | HAAN | State |
|---|---|---|---|---|---|
| R3a0 | Own process, host gate, headers, own bundle | server/src/main.rs, founder-web/vite.desk.config.ts | Rust, Tokio, axum 0.8, CSP + Trusted Types, Vite 8 | his 21 Nov 07:50 | LIVE on his server |
| R3a0-s1 | TLS 1.3 AES-256-GCM public path | server/awam-edge (existing) | Rust rustls, AES-256-GCM only | his 08:07 | PROVEN (his openssl 08:53) |
| R3a0-s2 | Own HTTP/3 (QUIC) listener, X25519MLKEM768, BBR | server/src/h3.rs | quinn, h3, rustls PQ, ring | his 09:08 / 09:18 | PROVEN on his server 09:55 (H3CHECK OK); DNS AAAA + HTTPS record = his hands, OPEN |
| R3a1 | Cinematic login + landing, telemetry pill | founder-web/src/desk/* | React 19, Three.js, Tailwind 4, kernel (Rule 52) | his 08:31 | LIVE (pill HTTP/3 line after his next desk-install.sh) |
| R3a2-1 | AD1 SQL: schema desk, desk_app, RLS, SHA-256 ledger | sql/AD1.sql, sql/checks/AD1-check.sql, scripts/ad-sql-run.sh | PostgreSQL ROW LEVEL SECURITY, hash chain | his 08:19 | WRITTEN + TESTED on PG16 AND the runner tested end to end (own database anexo_desk created, AD1 applied, 8/8 checks, 2nd run skipped, quoted PGHOST reproduced); NOT yet run on his server |
| R3a2-2 | auth.rs: ARGON2ID, constant-time, token audience desk | server/src/auth.rs | Rust argon2 | his 08:07 | NEXT |
| R3a2-3 | DBSC device-bound session | server/src/auth.rs | DBSC | his 08:07 | after auth.rs |
| R3a1-b | Orb pulse / shockwave / zoom into the 3-pane workspace | founder-web/src/desk | Three.js, GSAP | his 08:28 | after R3a2 |
| R3a2-4 | Passkey ceremony (optional) | server/src/passkey.rs + UI | WebAuthn, rp_id admindesk.anexomail.com | his 08:07 | after DBSC |
| R3p | Plans (Business Premium, Max first; Business tiers advanced only; Basic stays Bun) | AD2 SQL, polar.rs, sla.rs, lanes UI | Rust, HMAC-SHA256 webhook, RLS | his 09:08 | after the Desk; needs his support terms (R3p0) |
| R3b-g | Inboxes, auto mail, dashboard, reply, SLA engine, final | later | Rust, kernel RPC | his 3-day plan | Sun 22 - Mon 23 Nov |

## Desk ports on his server: TCP 127.0.0.1:4400 (loopback) + UDP 4400 (own HTTP/3, ufw open); public TCP 443 via founder SNI front -> awam-edge -> Caddy -> Desk; Desk cert copy /etc/anexomail/tls/desk (root only, systemd LoadCredential)

## Last 8 Desk commits
- b5f6863a 21 Nov 10:08 desk: working-now + phases inside desk folder, own database anexo_desk
- 7942ff0f 21 Nov 10:08 desk: working-now + phases inside desk folder, own database anexo_desk
- a766b69f 21 Nov 10:01 desk: ad-sql-run psql socket fix
- 81b51095 21 Nov 10:00 desk: folder in docs/claude/admin-desk + root copy, DESK COPY gate
- 7f3f62dd 21 Nov 09:58 desk: AD1.sql + runner, tested on PG16
- cb0d3c35 21 Nov 09:56 desk: HTTP/3 proven, gate row code, pill, back to phase order
- 86a82d75 21 Nov 09:53 desk: quic udp tech list, gate rows, bbr
- c3e5e361 21 Nov 09:52 desk: h3-check diagnosis section

## Uncommitted Desk files
 M admin-desk/state/WORKING-NOW.md
 M docs/claude/admin-desk/state/WORKING-NOW.md

## Gate rows (admin-desk/gates/DESK-FEATURES.json)
warn ADMIN DESK OPEN until 22 Nov: R3a2-argon2 [R3a2] Password door with ARGON2ID, constant-time -> needs ARGON2ID, constant-time compare, token audience desk in admin-de
warn ADMIN DESK OPEN until 23 Nov: R3a2-dbsc [R3a2] Device-bound session (DBSC) -> needs DBSC in admin-desk/server/src/auth.rs
warn ADMIN DESK OPEN until 24 Nov: R3p1-plans [R3p1] Plans as data (Premium, Max first) -> needs PostgreSQL RLS, hash-chained ledger in admin-desk/sql/AD2.sql
warn ADMIN DESK OPEN until 24 Nov: R3p2-webhook [R3p2] Polar signed webhook door -> needs Rust Tokio axum, HMAC-SHA256 constant-time in admin-desk/server/src/polar.rs
warn ADMIN DESK OPEN until 24 Nov: R3p4-sla [R3p4] SLA clock per plan -> needs Rust Tokio timers in admin-desk/server/src/sla.rs
warn ADMIN DESK OPEN until 2026-12-05: QUIC-datagram [R3a0-s2+] QUIC DATAGRAM (RFC 9221) + WebTransport for live Desk events (Rule 52 kernel RPC over QUIC) -> needs QUIC 
warn ADMIN DESK OPEN until 2026-12-20: QUIC-moq [R3a0-s2+] Media over QUIC (MoQ) for Desk voice notes / live updates, later phase -> needs Media over QUIC (MoQ) for Desk 
warn ADMIN DESK OPEN until 2027-01-10: QUIC-v2 [R3a0-s2+] QUIC version 2 (RFC 9369) when quinn ships it -> needs QUIC version 2 (RFC 9369) when quinn ships it in admin-de
warn ADMIN DESK OPEN until 2027-01-10: QUIC-ech [R3a0-s2+] Encrypted Client Hello (ECH) on the Desk host with the DNS HTTPS record, when rustls server ECH is stable -> ne
