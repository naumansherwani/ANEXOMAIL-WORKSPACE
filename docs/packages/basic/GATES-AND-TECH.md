# BASIC — gates aur technology (26 Oct 2026)
| Feature | Haalat | Gate kahan | Technology |
|---|---|---|---|
| 5 users cap | REAL | SQL `team_seat_calc` (E87) | Postgres |
| 3 mailboxes | REAL | `storage_plans.mailbox_limit`, Rust `mail_glue.rs` | Postgres + Rust |
| 15GB shared | REAL | `storage_plans.pooled_bytes` (E87) | Postgres |
| 25MB attachment | REAL | `storage_plans.max_send_bytes` (E87) | Rust `attach_core.rs` |
| 1 company domain | REAL | `org_domain_cap` (E15) | Postgres |
| 1 booking link | REAL (accident: `unique(user_id)`); E88 isse EXPLICIT cap bana deta hai | E88 trigger | Postgres + Rust `book_glue.rs` |
| 2 trusted devices | E88 se REAL (pehle server par cap NAHI tha) | `device_trust_set` (E88) | Postgres + Rust `device_glue.rs` |
| Response debt only | E88 se REAL (analytics ka plan gate nahi tha) | `showAnalytics*` in plan-surface | TS + route guard |
| Billing card (price/users/storage) | REAL | `get_billing_subscription` (E87) | Postgres |
