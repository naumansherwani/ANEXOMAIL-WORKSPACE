# Website migration to latest technology — phases (Rust PRIMARY, Bun emergency fallback FOREVER)

Rules (founder, 24 Oct 2026):
- Every account kind is covered by the SAME code path: Basic, Pro, Business, Business Pro, Personal, Basic Personal, family accounts. They differ only through `resolve_plan` (SQL RPC, reads family_accounts/trial_accounts) -> gate in the proc. NO per-kind copies of code.
- Founder-only routes (founder.ts, admin, release, perf, revenue, move-in) are a SEPARATE batch (F). Never mixed into buyer batches.
- Bun is never deleted: it is the emergency fallback (`rpcOrRest`: Rust 404/501/502/503 -> Bun). Site must not break at any step.
- No duplicate code: shared helpers live ONCE in `server/rust/main.rs` (`pro_plan_ok`, `mail_is_uuid`, `mail_pct`, `mail_thread_owned`, `sb_*`) or in a `*_core.rs` / `*_glue.rs` module; client calls go through `rpcOrRest` only.
- Every batch: Rust proc + same plan gate + Basic-user test + Bun validation parity + live Chrome test (1440 / 820 / 390) before GREEN.

## Phases (8)
| Phase | What | Tech used |
|---|---|---|
| M1 DONE (deploy pending) | thread labels/status/move/assign/snooze, templates save/delete, schedule gate | axum+/rpc, tokio |
| M2 | templates LIST, snippets, signatures, drafts+versions, follow-up, handoff, send-confidence, thread note | axum+/rpc |
| M3 | contacts, companies, workspace/organisations, storage (preflight/commit/state), billing state | axum+/rpc, tokio (storage), Postgres |
| M4 | auth (18) + trial (7) + passkey leftovers | axum+/rpc, JWT local verify, SQL if needed |
| M5 | org (27), crm (24), calendar (17), settings, security, integrations | axum+/rpc, tokio (fan-out) |
| L | polling -> live: 23 `refetchInterval` replaced by WebTransport events (snooze wake-up, scheduled-send status, calendar, crm, work, chat) | wtransport 0.7.2 / QUIC, tokio hub |
| M6 | chat (141) + ai (21+14+9) + files | axum+/rpc, tokio, WebTransport (chat/calls) |
| F | FOUNDER batch (separate): founder, admin, release, perf, revenue, move-in, billing-support | axum+/rpc (founder gate) |
| B8 | tokio 1.54, Bun 1.4.3, Brain -> Rust | toolchain |

## Deploy commands per technology (founder runs; order matters)
- SQL (only when a batch says so): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
- Rust (axum, tokio, wtransport): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)` then `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
- Web client + Bun fallback: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
- Rust mail delivery (only when deliver_bin.rs changes): `rust-deliver-install.sh` (same pattern).
Each batch's `founder-commands.md` entry says which of these apply.
