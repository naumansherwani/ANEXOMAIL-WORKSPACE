# Technology audit — 24 Oct 2026 (Rust PRIMARY, Bun FALLBACK)

Measured from the repo (not from memory):
- Repo: 2,155 files total (60 `.rs`, ~38,035 lines of Rust). NOT 35,000 files.
- Bun/Express endpoints in `server/routes/*.ts`: **511** (chat 141, org 27, crm 24, ai 21, auth 19, calendar 17, movein 16, mail 14, mail-compose 14, ai-automation 14, settings 13, security 13, release 13, integrations 13, billing-sync 12, ...).
- Rust procs (`/rpc/*`): ~328.
- Client call sites: 142 go Rust-first (`rpcOrRest`, Bun only as fallback); **76 call sites (61 unique paths) still go straight to Bun**: auth 18, mail 11 (drafts, follow-up, handoff, send-confidence ...), trial 7, contacts 5, companies 3, storage 3, billing 3, workspace 3, leo 2, search 1, public 1.
- Client polling: 23 `refetchInterval` still exist (should be driven by the live WebTransport push).

## Plans do NOT move to Rust automatically
A plan/package is enforced per endpoint. Rust has gates only where someone wrote them (CRM, work notes/tasks, thread insights). Found live-audit loophole: Snooze, Schedule send, Email templates (Pro card) were hidden only in the UI; the server let a Basic user call them. Fixed 24 Oct: Rust `pro_plan_ok` (resolve_plan) + Bun `resolvePlan` on mail.snooze, mail.templates.save, mail.schedule (send time > 130 s ahead; the 10 s undo-send hold stays Basic).
RULE for every migrated proc: copy the plan gate with it, and write a Basic-user test.

## Which technology goes where
- **axum 0.8.9 + tRPC-style /rpc/**: every request/response endpoint (the 511 Bun routes). Bun = fallback only.
- **Tokio 1.53.3 (async)**: all server concurrency: mail queue worker, reconcile tasks, SMTP/IMAP migration, fan-out (room-series check, universal search, dashboard), timers (snooze wake-up, scheduled send, trial expiry). Anything that waits on I/O.
- **WebTransport / QUIC (wtransport 0.7.2, quinn)**: everything the user should see without refresh: new mail, thread moved/snoozed-back, scheduled mail sent, calendar/rooms changes, CRM/work updates, chat messages/typing/presence, call signalling, upload/import progress. Replaces the 23 client polls.
- **PostgreSQL**: data store; accessed from Rust (PostgREST/sb_*), Bun only as fallback. RLS/triggers stay in SQL (E-series).
- **Bun 1.4.x**: fallback only; B8 = Brain -> Rust, tokio 1.54, Bun 1.4.3.

## Order to move Bun-primary -> Rust-primary (Pro first, then the rest)
1. Pro mail actions: thread labels/status/assign/move, templates LIST, snippets, drafts, follow-up, handoff, send-confidence, thread note (check).
2. Snooze wake-up + scheduled-send status as live events (no polling).
3. contacts/companies, workspace, storage, billing state.
4. auth (18) + trial (7), then org(27)/crm(24)/calendar(17).
5. chat (141) and ai (21+14+9), last.
