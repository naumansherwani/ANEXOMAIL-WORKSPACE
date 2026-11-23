# ADMIN DESK WORKING NOW (auto snapshot before a compaction, 23 Nov 2026 08:07 PKT) - read this FIRST for the Desk after a compaction
DOING: awam pull failed: new files not in deploy manifest, fixed + gate
NEXT STEP: his awam pull re-run, then three Chrome looks, B9
HIS LAST WORD: his 08:06 paste (pull.sh build FAIL)
LAWS: Desk isolation (never mix with founder/awam) / HTTP/1 + HTTP/2 BANNED, HTTP/3 only / Rule 52 kernel-verified calls / founder technology or MORE advanced / every phase row = feature + code + technology + HAAN / address him only as Aap, Roman Urdu short, end with Rule-70 table + 'Abhi code mein NAHI'.
REMINDER (his 22 Nov 06:41): BEFORE EVERY DESK PHASE run rules-read.py + desk-phase-start.py <phase>, read this file and docs/claude/admin-desk/DESK-PHASES-22NOV.md (strict rules + technology + features per phase). Technology listed = CODE. HTTP/1 + HTTP/2 never named.
RULE BOOK: docs/claude/admin-desk/RULE-BOOK.md (strict rules 1..N, rebuilt from DESK-PHASES-22NOV.md each checkpoint); blueprint: BLUEPRINT-ADMIN-DESK.md + DESK-PHASES-22NOV.md.
FOLDER: canonical docs/claude/admin-desk/ (edit here) + identical root copy admin-desk/ (python3 docs/cursor-work/server/desk-copy-sync.py sync).

## RULE BOOK (strict rules, read before every phase)
1. BEFORE EVERY PHASE: run `python3 docs/cursor-work/server/rules-read.py` then `python3 docs/cursor-work/server/desk-phase-start.py <phase>` and READ both outputs, plus docs/claude/admin-desk/state/WORKING-NOW
2. ADVANCE TECHNOLOGY ONLY, AND IT MUST BECOME CODE: the technology written next to a phase is his word, not a wish. A listed technology missing from code = OPEN GAP, the phase is never GREEN. Contract first (d
3. HTTP/1 AND HTTP/2 ARE BANNED FOR THE DESK, everywhere (code, tests, comments, strings). HTTP/3 + WebTransport (QUIC) only. HTTP fallback is banned until HE approves it.
4. RULE 52: every Desk call and every stream frame is Desk-signed (Ed25519) and verified by the Desk's own Rust WASM kernel; requests carry the HKDF/HMAC MAC + replay nonce.
5. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" AND my live Chrome look (live bundle = repo, 390 / 820 / 1200+). Installed or written is not green.
6. ISOLATION: the Desk is its OWN security domain (own binary, keys, tables, cookie, role). Never mix with founder or awam code. Vendor ban stays (Caddy, Namecheap by his hands, Hetzner, his own Rust only).
7. Never remove or restyle a feature he did not name. Login look and Bridge look are his approved ones.
8. After EVERY message: repo + ledger + blueprint + COMPACT-SAVE updated with real date and time (rec.sh, desk-copy-sync, lane-sync, manifest-sync, rules-gate 0 fail). EVERY phase is named by ALPHABET in build 
9. Address him only as Aap, Roman Urdu, short; end every reply with the Rule-70 table and "Abhi code mein NAHI"; server commands = ONE line.
10. WEB RESEARCH GOES INTO THE REPO IN ORDER (his 22 Nov 2026 07:15 PKT): every web search's points and features are written, in order, into the blueprint (section 'WEB RESEARCH LOG' in DASHBOARD-CARDS-CLICK-PL
11. FOLDER-WISE GREEN, DASHBOARD FIRST (his 22 Nov 2026 07:26 PKT, REPEATED 20:15 PKT in anger; step order = DASHBOARD-FOLDER-ORDER-22NOV.md): the Desk is made green folder by folder in rail order and the DASHB
12. FOUR-DAY TARGET (his 22 Nov 2026 07:26 PKT): the WHOLE Admin Desk is complete, wired and green in 4 days: by 26 Nov 2026 07:26 PKT. Day plan: docs/claude/admin-desk/FOUR-DAY-PLAN-22NOV.md. Every message re-
13. NO READ, NO COMMIT (his 22 Nov 2026 07:26 PKT): the commit gate 'DESK PHASE START' fails a Desk code commit unless the receipt shows the strict rules, this blueprint, the rule book and both WORKING-NOW file
14. NO PHASE NAME, NO "P1" ANYWHERE AN EMPLOYEE CAN SEE ON THE ADMIN DESK (his 22 Nov 2026 09:03 PKT, CHAIRMAN, said three times, "baaned hai"): not in cards, pages, tooltips, alert text, notes, test rows or da

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

> [21 Nov 2026 23:10 PKT] LIVE: R3a0, s1, s2 (UDP 4400), R3a1 pages, AD1+AD1b, owner, login door + desk_app DB login (his install 23:08 'database login live'). NEXT: his sign-in -> Rule 52 kernel RPC -> DBSC -> orb -> passkey -> R4-1..10 -> R3p -> R3b-g. Gap: public path still TCP/HTTP2 via Caddy until his AAAA+HTTPS record.

> [22 Nov 2026 01:08 PKT] NEW PHASE R3-SCALE (SCALE-50K-DESIGN-22NOV.md, S1..S11): 50,000-staff design, Zanzibar-style relation auth + SCIM + passkeys + routing/SLA + partitions + audit. Order: R3d > dashboard+bridge > inboxes > S1.. . Advance tech per row in the doc.

> [22 Nov 2026 01:13 PKT] PHASE R3-SCALE + WORLD-ADVANCE (W1..W10) written, awaiting his 4 haans; R3d code next.


## Desk ports on his server: TCP 127.0.0.1:4400 (loopback) + UDP 4400 (own HTTP/3, ufw open); public TCP 443 via founder SNI front -> awam-edge -> Caddy -> Desk; Desk cert copy /etc/anexomail/tls/desk (root only, systemd LoadCredential)

## Last 8 Desk commits
- 322539f3 23 Nov 08:07 Awam pull fix: manifest has the new key files, new gate
- 18088658 23 Nov 08:05 ledger line 3c71506f
- 3c71506f 23 Nov 08:05 Status 23 Nov 08:05 in all blueprints
- f004d2c7 23 Nov 08:01 ledger line 9a5a58bc
- 9a5a58bc 23 Nov 08:01 Awam keys: Ctrl+D, Ctrl+/, Alt+Shift pages, walk, rail follows
- f39acb99 23 Nov 07:56 ledger line 00974202
- 00974202 23 Nov 07:56 Desk: remove Opens when it is connected, tooltip is the short key only
- 4a22e32a 23 Nov 07:52 ledger line 60aaff50

## Uncommitted Desk files
 M docs/claude/admin-desk/state/WORKING-NOW.md

## Gate rows (admin-desk/gates/DESK-FEATURES.json)
warn R3a2-dbsc now holds in code: change its status to code in admin-desk/gates/DESK-FEATURES.json
warn ADMIN DESK OPEN until 24 Nov: R3p1-plans [R3p1] Plans as data (Premium, Max first) -> needs PostgreSQL RLS, hash-chained ledger in admin-desk/sql/AD02.sql
warn ADMIN DESK OPEN until 24 Nov: R3p2-webhook [R3p2] Polar signed webhook door -> needs Rust Tokio axum, HMAC-SHA256 constant-time in admin-desk/server/src/polar.rs
warn ADMIN DESK OPEN until 24 Nov: R3p4-sla [R3p4] SLA clock per plan -> needs Rust Tokio timers in admin-desk/server/src/sla.rs
warn ADMIN DESK OPEN until 2026-12-05: QUIC-datagram [R3a0-s2+] QUIC DATAGRAM (RFC 9221) + WebTransport for live Desk events (Rule 52 kernel RPC over QUIC) -> needs QUIC 
warn ADMIN DESK OPEN until 2026-12-20: QUIC-moq [R3a0-s2+] Media over QUIC (MoQ) for Desk voice notes / live updates, later phase -> needs Media over QUIC (MoQ) for Desk 
warn ADMIN DESK OPEN until 2027-01-10: QUIC-v2 [R3a0-s2+] QUIC version 2 (RFC 9369) when quinn ships it -> needs QUIC version 2 (RFC 9369) when quinn ships it in admin-de
warn ADMIN DESK OPEN until 2027-01-10: QUIC-ech [R3a0-s2+] Encrypted Client Hello (ECH) on the Desk host with the DNS HTTPS record, when rustls server ECH is stable -> ne
