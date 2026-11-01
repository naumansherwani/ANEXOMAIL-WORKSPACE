# FOUNDER MASTER AUDIT - everything founder-related in ONE place, in blueprint order (1 Nov 2026, 06:20 PKT)
Founder order 1 Nov 06:10 (verbatim in docs/cursor-work/founder/founder-commands.md): "founder se related jitne kaam hai us ka deep audit ker ke sab ko ek jaga pe le aao ... un ki tarteeb lagao blueprint main". Sources audited: FOUNDER-MASTER-ORDER-28OCT, PORT-ORDER-30OCT, ADVANCED-FEATURES-28OCT (items 1-33, sections A-I) + 30OCT (N1-N12), KILLER-FEATURES (K1-K4, I1-I3), PARITY-30OCT, LEGACY-REVIVAL-30OCT, NEEDS-ORDER-28OCT, MAIL-CHAT-BRIDGE-28OCT, LIVE-DATA-AUDIT, LOOPHOLE-LEDGER (L1-L22), SERVER-STATE, founder/FOUNDER-ONLY-STEPS, BUILD-PLAN. This file does NOT replace them (they hold the detail); it is the single ordered index. Order only changes with the founder's "haan" (Rule 66). Legend: GREEN = server + CHECK + seen in founder Chrome. REPO = in repo, not on server. PLAN = not started.
Layers (Rule 70, never mixed): SQL (Postgres, RLS, `sql-run.sh`) | RUST (`anexomail-founder`, axum 0.8 + tokio, `founder-install.sh`) | KERNEL (`web-wasm/`, the one Rule-52 kernel) | UI (React 19.2 + TS + TanStack Router + Tailwind 4.2 + shadcn, `founder-web/`) | CINEMA (aurora, glass, flip clock, Three.js lazy) | WEB (awam Bun Brain, only the host guard).

## 1. THE ORDER (top = first)
| # | Item | Technology | State | Gate to call it green |
|---|---|---|---|---|
| 1 | F1a-1 device approval, F2a Ed25519 + request signatures, E100-E106 | SQL RUST KERNEL | GREEN | - |
| 2 | S1 Settings Personal + Appearance (E108), profile, home city, sidebar | SQL RUST UI | GREEN | - |
| 3a | T1 UI stack: TypeScript, TanStack Router, Tailwind 4.2, shadcn | UI | GREEN | - |
| 3b | Loopholes L1-L4, L6-L22 (speed, logo, Founder blue, orb, bridge map, splash, refresh numbers) | UI RUST CINEMA | GREEN | - |
| 4 | F2b kernel verifies every answer in browser ("Trusted") | KERNEL UI | GREEN | - |
| 4a | Dashboard front page, Bridge page, Audit ledger view, Settings | UI RUST | GREEN | - |
| 4b | **Live data (founder 22:17)**: E109 SQL GREEN; 4b-1 Rust `/founder/v1/live` snapshot (GREEN 1 Nov 06:23: installed, 71 tests, Chrome shows "9 of 9 endpoints answering" and card "Live feed: Version 0, 12 sources, all fresh"); 4b-2 tick+SSE is next;  4b-2 SSE (INSTALLED 1 Nov 06:38); 4b-3 SPA live stream (CODE DONE 1 Nov 07:20: sse.ts, livefeed.ts, Dashboard Live feed chip + Recent changes; 7 bun tests; needs founder-install, green = Chrome); 4b-3 Dashboard auto-update; 4b-4 `pending_channels` from registry | RUST UI KERNEL | **IN PROGRESS: 4b-1 (design note FOUNDER-LIVE-RUST-SSE-DESIGN-01NOV.md)** | a real number changes in Chrome without reload |
| 4c | L5 host guard: founder not on awam hosts. Guard was never installed in the Brain (`anexomail-leo`); founder chose to **PARK** it: built natively in the Rust auth at awam migration | WEB | PARKED | - |
| 4d | **Founder Inbox P1** (founder 1 Nov 07:11/07:17: koi feature 'Not connected' nahi): user reports intake `user_reports` E112 (Glitch+Support: severity, SLA, dedup, hash-chain events), Rust read endpoints, Stream-health chip fix. Design: FOUNDER-CHANNELS-CEO-LIST-01NOV.md. P2 Inbox UI, P3 Reply+Mail Desk (step 11), P4 awam 'Report a problem' button (USER SIDE: founder ki ijazat / awam migration) | SQL RUST UI | IN PROGRESS | pehli asli report Inbox + Dashboard par aaye, channel `connected` apni state machine se |
| 5 | **F2c audit v1 + Merkle (E107)** + N5 signed exports (Merkle proof + Ed25519) | SQL RUST KERNEL(`merkle`) UI | PLAN (design note first) | Merkle root verifies in browser, tamper test fails closed |
| 5a | I1 Ledger Integrity Gauge on Dashboard | UI KERNEL | PLAN | gauge = real chain check |
| 6 | S2 Settings: Time machine + Drift and schedule; N6 time travel | SQL RUST UI | PLAN | - |
| 7 | F2d passkey for G3 (webauthn-rs), FOUNDER_PASSWORD removed; S3 Privacy; N4 two-person / break-glass; N9 offline PWA with signed cache (after F2d) | RUST SQL UI KERNEL | PLAN | - |
| 8 | Decide (N) one button; Live Pulse (real vs test accounts, E76); S4 Notifications (push); N1 decision journal; N2 anomaly watch (E109 z-score exists); N10 SLO burn alerts; N11 Live Pulse over WebTransport (`wtransport`, needs UDP port + cert from founder) | RUST SQL UI | PLAN | - |
| 8a | I3 Device Trust Map (device-reported city, never IP) | UI SQL | PLAN | - |
| 9 | F3 Finance deck: Polar failed payments, churn, reconcile, Revenue, Billing; Release (7 old launch pages); Move-In; N3 runway simulator (kernel maths); N7 weekly board brief (no LLM) | RUST SQL UI KERNEL | PLAN (Polar reader ON; shells exist) | numbers equal Polar |
| 10 | F4 People deck: People, Org, CRM, Work, Account 360, abuse + appeals (metadata only, never content) | RUST SQL UI | PLAN | - |
| 10a | I2 Active Work Chain Dependencies (needs `depends_on` SQL) | SQL RUST UI | PLAN | - |
| 10b | K4 Insider Guard (metadata-only deterministic auditor; hold = reversible) | RUST SQL | PLAN | - |
| 11 | F5 Mail Desk: Mail, Calendar, notifications email, undo-send; company address inbox | RUST SQL UI | PLAN | no customer content ever |
| 11a | K1 Sealed Agreements (cross-company escrow; needs F2c) | RUST KERNEL SQL | PLAN | - |
| 12 | F6 Systems: Analytics, Speed, Safety, ANEXOChat, Admin, **AI (10 pages, founder-only)**, calls telemetry, motion budgets; legacy checklists in `docs/claude/legacy/<page>.md` | RUST SQL UI CINEMA | PLAN | each old page checklist ticked in Chrome |
| 12a | K2 Mesh / air-gapped sync (research spike; needs a LAN node) | RUST | PLAN | - |
| 12b | **Mail<->Chat Bridge** 12b-1..6 (FOUNDER-MAIL-CHAT-BRIDGE-28OCT.md master + BRIDGE-EMAIL-CHAT-ENGINE-DESIGN-01NOV.md detail; user side phases 23-31 already exist) | SQL RUST KERNEL UI | PLAN | - |
| 13 | F8 Control: kill switch, flags, one-click executor (G2/G3, audit + rollback); N8 command palette that acts (kernel `intent`) | RUST SQL UI KERNEL | PLAN (executor OFF today) | - |
| 13a | K3 Poison Pill (crypto-shred of cached device data; G3) | UI KERNEL RUST | PLAN | - |
| 14 | F9 cutover: 33-36 old Lovable founder pages + 53 Bun-only founder endpoints removed ONLY after Rust == Bun proof each; `FounderBar`, `founder.preview`, 3 Lovable hosts | RUST WEB | PLAN | proof per endpoint |
| 15 | Founder desk: Docs + Sheets (Collabora/OnlyOffice via WOPI after licence read), calendar, tasks | UI RUST | PLAN | - |
| A | **Awam migration lane** (founder 1 Nov 06:07): the whole website moves to the latest technology AFTER the founder deck, as the business package (all endpoint gates on new tech). Awam ONE-ORDER is separate (FC21). L5 host separation lands here natively | RUST UI SQL | LATER | - |

## 2. Carried inside the steps (so nothing is lost)
- ADVANCED-FEATURES-28OCT items 1-33: A Command Bridge (-> 4b, 8), B Money (-> 9), C People (-> 10), D Mail Desk (-> 11), E Release (-> 9/13), F Systems (-> 12), G Control (-> 13), H extras "duniya hil jaye" (-> after 4 and F7 3D deepen), I health rules (every feature).
- F7 3D deepen (zones, drill-down, WebGPU, 60 fps / 2D fallback) -> after 12; Three.js WebGL already lazy for orb, bridge map.
- N12 bridge map: GREEN (done).
- Rule 70 report on every reply; Rule 6 mock never; user and founder never mix; FC18/FC22 parity rule (user feature changes compare with founder copy).

## 3. FOUNDER-ONLY actions (Claude never types passwords)
| When | Action |
|---|---|
| Per phase | one pull command (SQL `sql-run.sh`, Rust+SPA `founder-install.sh`), paste output back |
| Step 7 | passkey enrol on his device |
| Step 8 (N11) | UDP port + certificate for WebTransport |
| Step 15 | licence decision for the office engine |
| Parked | awam host-guard enforce (moves to awam migration) |

## 4. OPEN LEFTOVERS (honest, from ledgers)
1. Orb amber/red not yet seen live under a real warning (green proven). 2. F5 refresh 50-100 ms target not reached (floor ~1.85 s; Supabase round trip); 4b-1 single `/live` call is the lever. 3. `pending_channels` hard-coded -> 4b-4. 4. Awam kernel 0.5.0 pull + E90 `kernel_release_publish(...)` pending (user lane, not now). 5. Legacy checklists per old page not written yet (written when each phase starts). 6. Three awam files differ server vs repo (CommandPalette.tsx, dashboard.ts, app.admin.addresses.tsx): not founder work, noted. 7. Passkey and other awam login paths unguarded: parked with L5. 8. Mail<->Chat Bridge open questions (guests, delete window for other plans, DKIM-unverified domains) asked at 12b.

## 5. Pull command per technology (docs/claude/founder/PULL-COMMANDS.md has every one)
SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) <E-file> <CHECK-file> 2>&1 | tail -25`
RUST + SPA: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/founder-install.sh)`
Awam web (frontend only): `.../pull.sh`. Awam Brain (/api/auth): its own `brain-*-install.sh`, never pull.sh.
