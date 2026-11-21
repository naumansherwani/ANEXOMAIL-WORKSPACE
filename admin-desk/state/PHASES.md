# ADMIN DESK PHASES (status table, kept by Claude; the live pointer is WORKING-NOW.md in this folder). Each row: feature | code | technology | HAAN (his word) | state
Updated 21 Nov 2026 10:20 PKT. Rule 52: signed kernel-verified calls, no raw fetch. Founder technology or MORE advanced. HTTP/1 and HTTP/2 are BANNED for the Desk.

| Phase | Feature | Code | Technology | HAAN | State |
|---|---|---|---|---|---|
| R3a0 | Own process, host gate, headers, own bundle | server/src/main.rs, founder-web/vite.desk.config.ts | Rust, Tokio, axum 0.8, CSP + Trusted Types, Vite 8 | his 21 Nov 07:50 | LIVE on his server |
| R3a0-s1 | TLS 1.3 AES-256-GCM public path | server/awam-edge (existing) | Rust rustls, AES-256-GCM only | his 08:07 | PROVEN (his openssl 08:53) |
| R3a0-s2 | Own HTTP/3 (QUIC) listener, X25519MLKEM768, BBR | server/src/h3.rs | quinn, h3, rustls PQ, ring | his 09:08 / 09:18 | PROVEN on his server 09:55 (H3CHECK OK); DNS AAAA + HTTPS record = his hands, OPEN |
| R3a1 | Cinematic login + landing, telemetry pill | founder-web/src/desk/* | React 19, Three.js, Tailwind 4, kernel (Rule 52) | his 08:31 | LIVE (pill HTTP/3 line after his next desk-install.sh) |
| R3a2-1 | AD1 SQL: schema desk, desk_app, RLS, SHA-256 ledger | sql/AD1.sql, sql/checks/AD1-check.sql, scripts/ad-sql-run.sh | PostgreSQL ROW LEVEL SECURITY, hash chain | his 08:19 | WRITTEN + TESTED on PG16 (as superuser AND as a NON-superuser hosted-editor role) AND the runner tested end to end (own database anexo_desk created, AD1 applied, 8/8 checks, 2nd run skipped, quoted PGHOST reproduced); NOT yet run on his server |
| R3a2-2 | auth.rs: ARGON2ID, constant-time, token audience desk | server/src/auth.rs | Rust argon2 | his 08:07 | NEXT |
| R3a2-3 | DBSC device-bound session | server/src/auth.rs | DBSC | his 08:07 | after auth.rs |
| R3a1-b | Orb pulse / shockwave / zoom into the 3-pane workspace | founder-web/src/desk | Three.js, GSAP | his 08:28 | after R3a2 |
| R3a2-4 | Passkey ceremony (optional) | server/src/passkey.rs + UI | WebAuthn, rp_id admindesk.anexomail.com | his 08:07 | after DBSC |
| R3p | Plans (Business Premium, Max first; Business tiers advanced only; Basic stays Bun) | AD2 SQL, polar.rs, sla.rs, lanes UI | Rust, HMAC-SHA256 webhook, RLS | his 09:08 | after the Desk; needs his support terms (R3p0) |
| R3b-g | Inboxes, auto mail, dashboard, reply, SLA engine, final | later | Rust, kernel RPC | his 3-day plan | Sun 22 - Mon 23 Nov |

> [21 Nov 2026 10:31 PKT] AD1 flow: editor = sql/AD1.sql, server = scripts/ad-check.sh (read-only) after ad-db-env.sh once. WAITS his editor run + check paste.

> [21 Nov 2026 10:33 PKT] ad-db-env DONE on his server (10:3x); next his editor AD1 run + ad-check paste.

> [21 Nov 2026 10:35 PKT] AD1 now AUTO: ad-auto.sh (runs if missing, says already run if done). WAITS his output.

> [21 Nov 2026 10:35 PKT] AD1: ad-db-env DONE on his server; ad-auto.sh written (auto run / already run). WAITS his run + paste.
