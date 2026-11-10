> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# PRO — gates aur technology (26 Oct 2026 07:40, repo code se verify; sab GREEN neeche)
GREEN = server-side gate asli + test. In par DOBARA code NAHI likhna.
REAL = server-side gate maujood. SCREEN = sirf UI. NAHI = bana nahi.
| Feature | Haalat | Gate / file | Technology |
|---|---|---|---|
| 20 users cap | REAL (E88) | SQL `team_seat_calc` pro=20 | Postgres |
| 3 company domains | REAL | `org_domain_cap` (E15) | Postgres, server rokta hai |
| 10 mailboxes | REAL (E88 se 5->10) | `storage_plans.mailbox_limit`; Rust `mail_glue.rs`, Bun `org.ts` | Postgres + Rust |
| 300GB shared | REAL (E88) | `storage_plans.pooled_bytes` | Postgres pooled path |
| 35MB attachment | REAL (E88; pehle 25MB) | `storage_plans.max_send_bytes`; Rust `attach_core.rs` | Rust + Postgres |
| Shared inbox / collision guard (assign) | REAL (pehle se) | Rust `mailx_glue.rs` `pro_gate` (Basic ko 403) | Rust :3200 + Postgres `mail_thread_assign` |
| Snooze, templates | REAL (pehle se) | Rust `pro_gate` | Rust |
| Schedule send | REAL (pehle se; undo-send 30s Basic, baad ka waqt Pro+) | `server/routes/mail-compose.ts` `proOnly` + UI gate | Bun fallback + Rust mail engine |
| Boards / notes / tasks | REAL route + UI gate | `showWork` | TS + WebTransport live |
| Thread analytics (per-thread) | REAL (pehle se) | Rust `main.rs` "Thread analytics are a Pro+ feature" | Rust |
| 3 booking links | REAL (E88 + Rust + UI) | trigger `booking_pages_cap` + `chat_phase_entitlements` + Rust `book_glue.rs` | Postgres + Rust + React |
| 4 trusted devices | REAL (pehle se) | `device_vault_register` + `chat_feature_allowed('device_vault')` = 4 | Postgres |
| 48h support | PROCESS (insani) | -- | -- |
| Billing card (£105, 20 users, 300GB, seats_used) | REAL (E88) | `get_billing_subscription` | Postgres |
| CRM base (accounts/leads/pipeline) | GREEN (pehle se) | `showCrm` Pro+ + `surfaceDenial /app/crm` | TS + Bun crm.ts |
| Pre-send scan (`mail.confidence`) | GREEN (E88 wala commit, 26 Oct 07:40) | Rust `pro_only_proc` + `pro_gate` (Basic ko 403) | Rust :3200, unit test |
| Follow-up reminders (`mail.followup.*`) | GREEN (26 Oct 07:40) | Rust `pro_only_proc` | Rust |
| Snippets (`mail.snippets.*`) | GREEN (26 Oct 07:40) | Rust `pro_only_proc` | Rust |
| Draft handoff (`mail.handoff.*`) | GREEN (26 Oct 07:40) | Rust `pro_only_proc` | Rust + WebTransport |
| Overlap Matrix (`calendar.overlap`) + Focus Ring | GREEN (26 Oct 07:40) | Rust `overlap_glue.rs` 403 + UI `useProCalendar` (NewMeeting). Find-a-time (`calendar.findtime`) har package par | Rust |
| Meeting cost meter | UI GREEN (CostMeter `useProCalendar`); server field Bun `calendar.ts` ungated (Rust cal_glue cost = null) | UI | Bun/Rust |
| Analytics routes (threads, deep-work = Pro+; leaks/promises/forecast/team = Business+) | ROUTE GATE GREEN (`surfaceDenial` + test). BACKEND (data) BANA NAHI -> NOT-BUILT #1 | `plan-surface.ts` | TS |
