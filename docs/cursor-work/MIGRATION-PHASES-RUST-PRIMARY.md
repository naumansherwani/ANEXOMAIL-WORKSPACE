# Website migration to latest technology — phases (Rust PRIMARY, Bun emergency fallback FOREVER)

Rules (founder, 24 Oct 2026):
- Every account kind is covered by the SAME code path: Basic, Pro, Business, Business Pro, Personal, Basic Personal, family accounts. They differ only through `resolve_plan` (SQL RPC, reads family_accounts/trial_accounts) -> gate in the proc. NO per-kind copies of code.
- Founder-only routes (founder.ts, admin, release, perf, revenue, move-in) are a SEPARATE batch (F). Never mixed into buyer batches.
- Bun is never deleted: it is the emergency fallback (`rpcOrRest`: Rust 404/501/502/503 -> Bun). Site must not break at any step.
- No duplicate code: shared helpers live ONCE in `server/rust/main.rs` (`pro_plan_ok`, `mail_is_uuid`, `mail_pct`, `mail_thread_owned`, `sb_*`) or in a `*_core.rs` / `*_glue.rs` module; client calls go through `rpcOrRest` only.
- Every batch: Rust proc + same plan gate + Basic-user test + Bun validation parity + live Chrome test (1440 / 820 / 390) before GREEN.

- Family accounts: they got LIFETIME plans (see family_accounts), but in the product they are REAL BUYERS: same features, same gates, same limits as the plan they hold. Never special-case them in code; `resolve_plan` already maps them. Tests must include a family account of each plan.
- ORDER (locked 24 Oct 16:12): FIRST all ~510 Bun endpoints migrate to the latest technology (phases below, each in the technology that fits: axum/rpc, tokio, WebTransport). THEN the packages are made GREEN one by one: Pro -> Business -> Business Pro (live test 1440/820/390). Pro stays "not green" until its Bun-only endpoints are on Rust.
- No mixed code: one technology per job, no second copy of logic in Bun and Rust beyond the thin fallback validation parity.
- Pull commands are given PER TECHNOLOGY with each batch (SQL / Rust+restart / Web), only the ones that batch needs.

- HOW Rust code ships (learned live 24 Oct 16:30): `rust-engine-install.sh` does NOT replace the live `main.rs`; it only adds modules (`mod X_core; mod X_glue;` + one `owns()/dispatch()` hook). Procs written into `server/rust/main.rs` NEVER reach the server (live test: /rpc/mail.snooze stayed 404). So every new Rust proc lives in a `*_core.rs` (std-only, unit-tested on the server) + `*_glue.rs` module, registered in the installer's CFG/ALL_MODULES. `main.rs` in the repo is not edited for new procs. `mail_glue.rs` (send/schedule) ships via `rust-mail-install.sh`. Before pushing: compile the glue in a stub harness and call every proc.

- HOW Bun (Brain) fallback code ships: `pull.sh` only updates the Web app (`anexomail-web`). Bun `/api/*` routes run in Brain (`/opt/anexomail/src`, pm2 `anexomail-leo`, :3100) and change ONLY through a `brain-*-install.sh` (anchor hunks, bun build pre-flight, restore-on-fail). Editing `server/routes/*.ts` in the repo does NOT change live Bun. Proof (24 Oct 16:24): live Bun still had the old snooze code; `until:"garbage"` crashed it (502 until pm2 restart). For Bun fixes: regenerate `brain_pro_hunks.json` (base->current hunks, round-trip verified) and give `brain-pro-install.sh`.
- Pull command types: SQL = `sql-run.sh`; Web = `pull.sh`; Rust engine = `rust-engine-install.sh` (modules); Rust mail = `rust-mail-install.sh`; Brain (Bun fallback) = `brain-*-install.sh`; then pm2 restarts.

## LIVE STATUS RULE (founder 24 Oct 17:18 PKT): yeh table SAATH KE SAATH update hota hai
Har kaam ke saath isi turn mein is table ki halat (TODO / READY / deploy pending / LIVE GREEN) + `MIGRATION-LEDGER-24OCT.md` ki ginti (script se dobara) badli jati hai. Phase GREEN sirf jab Basic-user test + live Chrome 1440/820/390 ho chuke.

## Phases (8)
| Phase | What | Tech used |
|---|---|---|
| M1 LIVE GREEN (24 Oct 19:20; E85 assign fix deploy pending) | thread labels/status/move/assign/snooze, templates save/delete, schedule gate | axum+/rpc, tokio |
| M2 READY (24 Oct 20:10, commit 1520a18; deploy + live test pending; handoff = M2b) | templates LIST, snippets, signatures, drafts+versions, follow-up, handoff, send-confidence, thread note | axum+/rpc |
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
