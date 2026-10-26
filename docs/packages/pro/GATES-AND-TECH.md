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
