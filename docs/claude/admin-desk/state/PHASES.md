# ADMIN DESK PHASES (status table, kept by Claude; the live pointer is WORKING-NOW.md in this folder). Each row: feature | code | technology | HAAN (his word) | state
Updated 21 Nov 2026 10:20 PKT. Rule 52: signed kernel-verified calls, no raw fetch. Founder technology or MORE advanced. HTTP/1 and HTTP/2 are BANNED for the Desk.
> [22 Nov 2026 00:50 PKT] CURRENT ORDER: see REMAINING-LIST-22NOV.md (12 rows). Flash cancelled. Premium/Max after Desk complete.

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

> [22 Nov 2026 01:14 PKT] R3-ONBOARD (ON1..ON8) written (EMPLOYEE-ACCOUNTS-PLAN-22NOV.md), awaits his 4 answers.

> [22 Nov 2026 01:15 PKT] MASTER PLAN (P1..P12, 10 steps) written; now coding R3d.

> [22 Nov 2026 01:25 PKT] ON1..ON12 FINAL (his answers: all haan; teams support / migration / frontend_demo; +4 zero-trust locks AAGUID, IP+shift, circuit breaker, no_access default). EMPLOYEE-ACCOUNTS-PLAN-22NOV.md. ORDER: R3d > dashboard+bridge > S1+S2 > ON1. Not in code.

> [22 Nov 2026 01:36 PKT] R3d stage B written + tested; waits his desk-install, then my live Chrome proof. NEXT: R4-1 shell/bridge on deskCall.

> [22 Nov 2026 01:47 PKT] STATUS-REAL-22NOV.md: LIVE vs CODE-ONLY vs PLAN-ONLY. Desk complete about 12 percent (1.5/12), whole plan about 3 percent live. R3d code pushed 01:38, his 01:39 paste shows the OLD script ran: rerun the pull command. TIME-STAMP FIX: ledger lines stamped 02:05-02:55 were wrong, real 01:3x-01:4x.

> [22 Nov 2026 01:55 PKT] R-CRM added to the Desk plan (his 01:54): CRM as much as the awam user gets, company style, built NEW. MASTER-PLAN-22NOV.md. Not in code.

- [22 Nov 2026 01:59 PKT] SANDBOX LIVE TEST done (real binary + real Postgres AD1/AD1b + real Chrome 390/820/1280): all pass after 2 UI fixes. SANDBOX-LIVE-TEST-22NOV.md. His rerun of desk-install is next, then my Chrome look on his real URL.

- [22 Nov 2026 03:02 PKT] R4-1c (PLAN, after his haan): rail renamed to 4 groups per SIDEBAR-SECTIONS-AND-LOOPHOLES-22NOV.md; new items Live Pulse & SLA, Domains & DNS Health, Customers & Plans, Security & Policies, Chairman Escalations. Technology: React 19 + module registry, kernel RPC; each item stays "not connected" until its phase is WIRED + REAL.

- [22 Nov 2026 03:08 PKT] 4-DAY PLAN written (FOUR-DAY-PLAN-22NOV.md). Day1 R4-1b Bridge, AD3 SQL, AD2 Rust door. Day2 R4-2 inboxes, cases, routing. Day3 R3c auto mail, R3f SLA, R4-11 Managed Move-In. Day4 People, deliverability, security screens, CRM base, final proof. Advance tech per phase inside the file.

- [22 Nov 2026 03:19 PKT] DASHBOARD PHASES (DASHBOARD-LIVE-COMMAND-22NOV.md): R4-1b Bridge = A3 pipeline heartbeat + B4 alert center + B5 service health (Rust probes, SSE); R3b/R3f = A1 Live SLA Clock + B1 queues + B2 SLA at risk (Rust scheduler, Postgres); R3p = A2 Active P1 + packages with prices + B9 (HMAC webhook, plan rows); R4-1c = B3 security health score (SQL views); R4-10 = B6 deliverability; R4-11 = B7 Move-In board; R4-2 = B11 spoof/link guard (Rust MIME). Tech per row in the file.

- [22 Nov 2026 03:43 PKT] R4-1b BRIDGE (BRIDGE-PLAN-22NOV.md): step 1 AD3 SQL + AD3-check written and sandbox-tested; steps 2 Rust probes, 3 signed doors, 4 React command bar NOT written. Cases/queues/SLA SQL renumbered AD4.

- [22 Nov 2026 03:53 PKT] BRIDGE FEATURES (BRIDGE-FEATURES-22NOV.md): R4-10 deliverability; R4-1b step 5 SLO burn (Rust HdrHistogram); step 6 cipher meter (rustls); step 7 Merkle anchor (external Storage Box); R4-1c insider radar + Chairman inbox + Desk Freeze; step 4 honest telemetry UI. AD3 LIVE.

- [22 Nov 2026 03:58 PKT] BRIDGE: step 7 Merkle anchor REMOVED, inbox placement REMOVED (his 03:57).

- [22 Nov 2026 03:59 PKT] R4-1b step 2 probes.rs written + tested (24 tests); AD3 patched for 4 s probes; needs desk-install + ad-auto on his server.
