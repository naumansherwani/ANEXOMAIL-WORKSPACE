# FOUNDER PORT ORDER — every workspace feature: order, technology, phase, what works today (30 Oct 2026, 21:20 PKT)
Founder order (21:14, verbatim in docs/cursor-work/founder/founder-commands.md): "yeh sab cheezein mujhe tarteeb se chaiye hain aur yeh mujhe working chaiye hain technology ke hisab se chaiye hain aur in ki tarteeb phases main kab aye gi yeh bhi batna hai."
Source of truth for the order is FOUNDER-MASTER-ORDER-28OCT.md (locked). This file adds the per-feature view. No dates are written: a date would be a guess. One phase at a time (Rule 66): green on the server, CHECK, and live in Chrome before the next phase starts.

## Technology layers (never mixed, Rule 70)
| Tag | Layer | Lives in | Pull command (per technology) |
|---|---|---|---|
| SQL | Supabase Postgres, RLS on, append-only audit | `docs/cursor-work/sql/E1xx_*.sql` + `CHECK_E1xx.sql` | `sql-run.sh` |
| RUST | `anexomail-founder` (axum 0.8 + tokio), signed endpoints | `server/founder/src/` | `founder-install.sh` |
| KERNEL | the one Rule-52 WASM kernel (verify, Merkle, intent) | `web-wasm/` | `founder-install.sh` (founder) + awam `pull.sh` + E90 publish (user site) |
| UI | React 19 + TypeScript + TanStack Router + Tailwind + shadcn | `founder-web/src/` | `founder-install.sh` |
| CINEMA | aurora, glass, flip clock, Three.js (lazy) | CSS in `founder-web/` | `founder-install.sh` |
| WEB | awam Bun app (only the host guard touches it) | `server/routes/auth.ts` | awam `pull.sh` |

## Order (top = first). "Today" = what you can use right now.
| Step | Founder version (user-app feature it replaces) | Technology | Needs first | Today |
|---|---|---|---|---|
| done | **Dashboard**: greeting + clock, company watch, tiles, revenue target, working features, gates G1/G2/G3, Founder API probes | UI + CINEMA over RUST signed endpoints, KERNEL verifies | — | LIVE, Chrome-proven (21:06) |
| done | **Bridge**: needs-attention checks, money exceptions, Polar webhook | UI + RUST | — | LIVE |
| done | **Settings** Personal + Appearance (user's tabs 1-2), profile, home city, sidebar | UI + RUST + SQL E108 | — | LIVE, persists |
| done | **Audit ledger** (hash-chain check) | UI + RUST + SQL E102 | — | LIVE, chain intact (#14) |
| done | **Trust**: every answer verified in the browser | KERNEL + UI | — | LIVE (F2b) |
| 3 | Host guard: founder cannot sign in on awam hosts | WEB + Bash | founder login once, `status` shows `founder_host=true` | probe log live after awam pull; enforce next |
| 5 | **F2c Audit v1 + Merkle**, Ledger Integrity Gauge on Dashboard | SQL E107 + RUST + KERNEL (`merkle`) + UI | design note first (Rule 63) | NEXT |
| 6 | **S2** Settings: Time machine, Drift and schedule | SQL + RUST + UI | F2c | planned |
| 7 | **F2d** passkey for G3, FOUNDER_PASSWORD removed; **S3** Privacy | RUST (webauthn-rs) + SQL + UI | S2 | planned |
| 8 | **Decide** (one button, B1 "Needs you" queue), **Live Pulse**, **S4** Notifications | RUST + UI; Live Pulse = WebTransport (`wtransport`, UDP port + cert from you at that time) | F2d | planned |
| 9 | **Finance** (Polar failed payments, churn, reconcile, Revenue, Billing), **Release** (7 launch pages), **Move-In** | RUST + SQL + UI | Decide | planned. The deck pages exist as shells; real data lands with this step |
| 10 | **People** = People, Org, CRM, Work, Account 360, abuse and appeals | RUST + SQL + UI | Finance | planned; sidebar link opens the user-app page meanwhile |
| 11 | **Mail Desk** = Mail, Calendar, notifications email, undo-send | RUST + SQL + UI | People | planned; link opens the user-app page meanwhile |
| 12 | **Systems** = Analytics, Speed, Safety, ANEXOChat, Admin, **AI** (10 pages, founder-only) | RUST + SQL + UI (3D globe lazy, CINEMA) | Mail Desk | planned; link opens the user-app page meanwhile |
| 13 | **Control**: kill switch, flags, one-click executor (every action G2/G3, audit + rollback) | RUST + SQL + UI | Systems | planned. Executor is OFF today: every attempt is only recorded in the audit |
| 14 | **F9 cutover**: 36 old Lovable founder routes + 53 Bun-only endpoints removed after Rust == Bun proof | RUST + WEB | all above | last cleanup |
| 15 | **Founder desk**: Docs, Sheets, Tasks (WOPI engine chosen after a licence read) | UI + RUST | cutover | last |
The N1-N12 extras (decision journal, anomaly watch, runway simulator, signed exports, time travel, board brief, command palette actions, offline PWA, SLO burn alerts, Live Pulse, bridge map) slot in after their prerequisite phase: see FOUNDER-ADVANCED-FEATURES-30OCT.md.

## What "working" means here
A step is called working only when: the server runs it, the CHECK passes, Chrome shows real data, and a failed source says "Not answering" or "Not connected" instead of a guess (Rule 69). Until a founder version exists, the sidebar group "Workspace (user app)" opens the real user-app page, so nothing is missing in daily use. Those links are the user app, not founder pages: they carry the user's own login and never founder data.
