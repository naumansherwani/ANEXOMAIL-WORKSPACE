# BRIDGE vs DASHBOARD — a CEO's split (founder 28 Oct 2026, 13:01: "tum CEO ho, kya karoge?")
Rule: **Bridge = verbs and "now" (what needs ME).** **Dashboard = nouns and "trend" (how is the COMPANY).** A tile lives in exactly one of them; the other links to it. Technology and gates as in FOUNDER-KILLER-FEATURES-28OCT.md (Rust + Postgres + WASM verify + React 19.2). Nothing mocked: a tile with no source says "Not connected / Not measured".

## What I check as CEO, in this order every morning
1. Is anything on fire? 2. Is money coming in? 3. Who is waiting for my decision? 4. Did anyone touch something they shouldn't? 5. Are customers OK? 6. What is live / risky?

## BRIDGE (founder only, across all tenants, every row has an action)
| # | Block | Source / step | Action (gate) |
|---|---|---|---|
| B1 | **Needs you** — one queue: approvals, appeals, comp/extend requests, sealed agreements waiting for my countersign, insider holds to review, release waiting | Decide (N) step 8; K1 11a; K4 10b; F3/F4 | Approve / reject (G2, G3 for money) |
| B2 | **Money now** — MRR, failed payments, who is about to churn | Polar (F3-a done, F3-b step 9) | Send reminder / extend grace (G2) |
| B3 | **Fire alarm** — anything failing right now + the kill switches | Systems probes (12), Control (13) | Open incident / kill switch (G3) |
| B4 | **Release** — what is live, one-click deploy + rollback | Release deck (9), executor (13) | Deploy / rollback (G3) |
| B5 | **Customers waiting** — new leads, SLA breaches, abuse review queue | Mail Desk (11), People (10) | Reply / assign (G2) |
| B6 | **Live Pulse** — real vs test accounts, signups today | step 8 | none (read) |
| B7 | **Poison Pill** — devices I can shred | K3 (13a) | Shred (G3 + passkey) |
| B8 | **Mesh fleet** — office LAN nodes online (only when K2 exists) | K2 (12a) | none |
| B9 | **My desk** — founder mail summary, my tasks/calendar | Founder desk (15) | open |
Bridge stays short: max ~6 blocks visible, each with its count; everything else one click away in the decks (Rule 65: clean screen, nothing lost).

## DASHBOARD (company health, read-only G1; first for ANEXOMAIL itself, later the same component per business account — FC22)
| # | Block | Source / step |
|---|---|---|
| D1 | **Ledger Integrity Gauge** (founder's #1) | F2c Merkle — 5a |
| D2 | **Active Work Chain Dependencies** (founder's #2) | Promise engine + `depends_on` — 10a |
| D3 | **Device Trust Map** (founder's #3) | founder_devices + device vault — 8a |
| D4 | **Uptime and speed** — probes history, p95, error rate | Systems — 12 |
| D5 | **Growth** — MRR trend, signups, activation, churn curve | F3 — 9 |
| D6 | **Mail health** — deliverability, bounces, queue age | Mail Desk — 11 |
| D7 | **Capacity** — disk, mailboxes, storage per plan | Systems — 12 |
| D8 | **Support clock** — SLA, response time trend | Mail Desk — 11 |
| D9 | **Audit activity** — writes per day, time machine / drift | F2c, S2 — 5, 6 |
Navigation order (founder 13:06): **Dashboard, then Bridge**, then the decks. "Dashboard" appears above Bridge when D1 ships (5a); no empty page before that. The sidebar group label "Command center" is no longer printed above Bridge; it is the first part of the breadcrumb (Command center / Bridge).

## What I (CEO) would build first
1. Make money real (Polar token, F3-b) — a company that cannot see its money is flying blind.
2. Needs-you queue (Decide) — it turns the Bridge from a report into a tool.
3. Ledger Integrity Gauge — the one number that proves everything else can be trusted.
Then People/Mail Desk, then the killer features in FOUNDER-KILLER-FEATURES order.

## TECHNOLOGY AND CODE PER TILE (Rule 62: technology first; read from server/founder/Cargo.toml and founder-web/package.json on 30 Oct 2026)
**In use today (verified in the repo):** Rust edition 2024, `axum 0.8` + `tokio 1` (full), `tower-http 0.6`, `reqwest 0.12` (rustls, GET-only Polar reader), `ring 0.17` (Ed25519 signing), `hmac 0.12` + `sha2 0.10` + `hex` (request MAC, hash chain), `serde`/`serde_json`. SPA: `react 19.2`, `vite 8.2`, `three 0.185` (lazy). Data: Supabase Postgres through service role RPCs (RLS on). Endpoints today: `/founder/v1/{exchange,keys,me,bridge,settings,finance/polar,actions,audit,action}`.
**Target stack not yet in the code (Rule 61, honest; corrected 30 Oct 19:35):** WebTransport/QUIC (`wtransport`), `webauthn-rs` passkey, `ed25519-dalek`/WASM kernel (F2b), Merkle (E107). TypeScript, TanStack Router, Tailwind 4.2 and shadcn ARE in the code since T1 (commit 425ec14, live in Chrome 30 Oct 19:20). Every tile below says which of these it needs.
| Tile | Technology it runs on | Code (exists -> new) | Data source / SQL | Pull command type |
|---|---|---|---|---|
| B2 Money now / D5 Growth | Rust `reqwest` GET poller (60 s, last-good + stale flag) -> signed envelope -> React | `polar.rs`, `bridge::money` exist; churn/failed-payment views new (F3) | Polar Metrics API (read-only token) + `E105` pulse tables | SQL (new view) then founder-install |
| B3 Fire alarm / D4 Uptime | Rust probes (`reqwest`, `tokio::time`) + `systemd` reader | `bridge::trouble` exists (mail outbox, expiry watch); probe history new | probes table (new E-file), `E102` audit | SQL then founder-install |
| B1 Needs you | Rust action queue `founder_actions` + G2 two-tap / G3 passkey (`webauthn-rs`, new) | `actions.rs`, `gate.rs` exist; queue UI new (step 8) | `E102`/`E103` | SQL then founder-install |
| B5 Customers waiting / D6 / D8 | Rust mail-desk reader + SLA clock (`tokio`) | `bridge::voice` exists (leads count); rest new (F5) | leads/mail tables read-only | founder-install |
| B6 Live Pulse | Rust `tokio::sync::watch` change feed -> WebTransport push (`wtransport`, new) | new `pulse.rs` | real vs test accounts registry (`test_accounts`, Rule 49) | founder-install |
| B4 Release / B3 kill switches | Rust executor (allow-listed commands, step-up G3) | `actions.rs` base; executor new (F8) | `founder_actions` | SQL + founder-install |
| B7 Poison Pill / B8 Mesh | Crypto-shred (key destroy), LAN node (research spike) | new | new E-file | later |
| D1 Ledger Integrity Gauge | `sha2` chain + Merkle (E107) verified in the browser by the WASM kernel (F2b) | `audit.rs` (v1 chain) exists; Merkle + kernel new | `E102` chain, `E107` checkpoints | SQL then founder-install |
| D2 Work Chain Dependencies | Postgres `depends_on` constraint + promise engine | new | `E1xx` (step 10a) | SQL then founder-install |
| D3 Device Trust Map | Postgres `founder_devices` + device-reported city (never IP) | `ftoken.rs`/`login.rs` exist; map UI + three.js (lazy) new | `E104` | founder-install |
| D7 Capacity | Rust `tokio::process`/`sysinfo`-style reader (read only) | new | server metrics | founder-install |
| D9 Audit activity | SQL view over `founder_audit` | `audit.rs` reads exist; chart new | `E102` | SQL then founder-install |
Rule that follows from this table: a tile is built only when its row's technology exists (e.g. B6 needs WebTransport first); until then the Bridge/Dashboard shows "Not connected / Not measured" with the reason (Rule 69).

## PULL-COMMAND FORM FOR THIS WORK (Rule 41 / 46 / 48 / 66)
Only commands that already exist in the repo are given to the founder, one technology at a time, always `git -C /opt/anexomail-web fetch -q origin main && bash <(... show origin/main:<script>)`, never `git pull`/`merge` in /opt/anexomail-web. A command that was invented or untested is a Rule 48 breach (30 Oct 2026: `founder-polar.sh status` did not exist; it now does and is tested).

## STATUS IN CODE TODAY (30 Oct 2026 19:35, checked against Bridge.tsx and the live Chrome tab)
**What the founder sees on Bridge now (all real data, none mocked):** Billing · Polar, Finance (manual revenue), Customer voice (leads), Needs attention (Mail Outbox, Expiry Watch), Polar webhook events and signature-reject row.
| Tile | Status | Note |
|---|---|---|
| B1 Needs you | NOT BUILT | queue UI = step 8 (Decide); `actions.rs` exists |
| B2 Money now | PARTIAL, LIVE | Billing · Polar + Finance cells; churn/failed payments = F3-b |
| B3 Fire alarm | PARTIAL, LIVE | Mail Outbox + Expiry Watch checks; 12 probes + kill switches later |
| B4 Release | NOT BUILT | Release deck lists registry actions only; executor = F8 |
| B5 Customers waiting | PARTIAL, LIVE | Customer voice (leads count); SLA/abuse queue = F5 |
| B6 Live Pulse | NOT BUILT | needs WebTransport first |
| B7 Poison Pill, B8 Mesh | NOT BUILT | K3 / K2 |
| B9 My desk | NOT BUILT | step 15 |
| D1 Ledger Integrity Gauge | NOT BUILT | needs F2b then F2c Merkle (E107) |
| D2 Work Chain Dependencies | NOT BUILT | step 10a |
| D3 Device Trust Map | NOT BUILT | step 8a |
| D4-D9 | NOT BUILT | each waits on its step above |
**There is no founder "Dashboard" view yet.** The sidebar group "Workspace (user app)" has an item called Dashboard: that is the awam product dashboard (`/app`), NOT the founder Dashboard D1-D9. To avoid the clash, the founder Dashboard will appear above Bridge only when D1 ships, and will be labelled "Company health".
**Rule kept:** a tile is added only when its source and technology exist; until then it is not drawn (Rule 69).
