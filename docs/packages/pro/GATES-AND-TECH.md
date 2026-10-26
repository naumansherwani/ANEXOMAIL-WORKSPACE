# PRO — gates aur technology (26 Oct 2026, repo code se verify; pehli audit ki 2 ghaltiyan theek ki gayin)
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
