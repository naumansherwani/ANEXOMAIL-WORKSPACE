# FOUNDER WORKSPACE — founder ki apni list, apni tarteeb (founder 1 Nov 07:52 PKT)
Order verbatim: founder-commands.md 07:52. Sidebar: Dashboard, Bridge, phir group **Founder Workspace** (Bridge ke neechay). Har item founder ke apne endpoint (`/founder/v1/*`), apne gates (G1/G2/G3), apni tables, latest technology (Rust axum+tokio -> signed envelope -> WASM kernel verify -> React-TS). User ke pages/data/token KABHI nahi (FC18/FC22). Item sidebar mein tab aata hai jab wire hoke live ho ("jab bari aye gi"); slow technology banned.

**GALTI SUDHARI (founder 07:57): "Mail" ko "Mail Desk" likha tha — galat. Mail = inbox/folders/compose/outbox (founder ka apna Mail page). Mail Desk (company mailboxes, support replies, deliverability, SLA) us Mail ke ANDAR, sab se END par.**
Build tarteeb = FOUNDER-MASTER-ORDER-28OCT.md ka number (locked). Sidebar dikhane ki tarteeb = founder ki list. Har item ka kaam wahi jo master order ke step mein likha.
| # | Founder ki list | Founder Workspace page | Master step (build) | Live source (asli) | Gates | Halat |
|---|---|---|---|---|---|---|
| 1 | Dashboard | **Dashboard** | 1-4b, 4d | live feed, Polar, audit, inbox, host proof | G1 | **DONE, server par + Chrome GREEN** |
| 2 | Mail | **Mail** (inbox, folders, compose, outbox) | 11 | founder ke apne mailboxes (Postfix/Dovecot) | G1/G2 | NOT DONE (page catalog mein, asli mail 11 mein) |
| 3 | People | **People** | 10 | accounts, devices, orgs (metadata) | G1/G2 | NOT DONE |
| 4 | Calendar | **Calendar** (Mail ke saath) | 11 | calendar tables | G1 | NOT DONE |
| 5 | Work | People > **Work** | 10 + 10a | work + depends_on | G1 | NOT DONE |
| 6 | CRM | People > **CRM** | 10 | revenue_leads, accounts | G1/G2 | NOT DONE (leads ginti Dashboard par LIVE) |
| 7 | Org | People > **Org** | 10 | orgs, members, policies | G1 | NOT DONE |
| 8 | Analytics | Systems > **Analytics** | 12 | probes + Polar metrics | G1 | NOT DONE |
| 9 | Safety | Systems > **Safety** (+ K4 Insider Guard 10b) | 12 | abuse, host proof | G1/G2 | host proof LIVE (4c); baqi NOT DONE |
| 10 | ANEXOChat | Systems > **ANEXOChat** (+ 12b Mail<->Chat Bridge) | 12 / 12b | chat metadata | G1 | NOT DONE |
| 11 | AI | **AI** (10 founder-only pages) | 12 | AI spend/receipts | G1 | NOT DONE |
| 12 | Speed | Systems > **Speed** | 12 | p95 probes | G1 | endpoint ms Dashboard par LIVE; page NOT DONE |
| 13 | Founder | = **Bridge** (purane Lovable founder home replace) | 4a (done) / 14 cutover | bridge endpoint | G1 | **DONE (Bridge)**, purane pages 14 mein hatenge |
| 14 | Admin | Systems > **Admin** + **Control** (kill switch, flags, executor) | 12 + 13 | founder_actions | G2/G3 | registry LIVE (12 actions); executor NOT DONE |
Mail Desk (inside Mail, aakhri): Company mailboxes, Support replies (Inbox 4d P3 yahin jurti hai), AI email addresses, Deliverability, SLA clock.
Founder-only (user ke paas nahi): Finance (step 9, Polar LIVE), Release, Move-In (9), Audit ledger (DONE), **Inbox** (4d P1 DONE, P2 next), Settings (S1 DONE, S2-S4 baaki).

## Master order mein ab tak kya HO CHUKA (server par + Chrome)
1 device approval + Ed25519 (DONE) · 2 Settings S1 + profile + home city (DONE) · 3 Polar token (DONE; host guard L5 PARKED) · 3a TS + TanStack Router + Tailwind 4.2 + shadcn (DONE) · 3b loopholes L1-L22 (DONE) · 4 F2b WASM kernel verify (DONE) · 4a Dashboard + Bridge + Audit + Settings (DONE) · 4b live data E109 + stream + UI (DONE) · 4d Founder Inbox P1 E112 (DONE).
**Agla (master order):** 4d P2-P4 (Inbox page, jawab Mail ke saath, awam button) · 4e Kernel SSE port · 5 F2c Merkle · 5a gauge · 6 S2 · 7 F2d passkey + S3 · 8 Decide + Live Pulse + S4 · 8a Device Trust Map · 9 Finance/Release/Move-In · 10 People(+Org/CRM/Work) · 11 **Mail (+Calendar), Mail Desk end par** · 12 Systems (Analytics/Speed/Safety/ANEXOChat/Admin) + AI · 12b Mail<->Chat · 13 Control · 14 cutover · 15 Docs/Sheets.
**Naam 'Admin/Founder/Speed...' ke sidebar items ek ek karke tab dikhenge jab unka page asli data se live ho** — abhi group mein wo decks hain jo sidebar mein pehle se the (Mail, People, AI, Systems, Control, Finance, Release, Move-In, Audit ledger), isi tarteeb mein (founder ki list ki tarteeb pehle, phir founder-only).

## Technology rules (founder: bun, node, slow tech BANNED)
- Server: sirf Rust binary + static files. Bun/Node server par kabhi nahi (aaj bhi nahi: founder-install "server par npm/Node NAHI").
- Repo: `founder-web/bun.lock` HATA diya. Baqi: `package.json` + `vite.config.ts` build-tool ki list hain (React 19.2 + Vite 8.2 locked), tayyar `dist/` commit hota hai; build sirf mere sandbox mein.
- Tests: SSE parser/merge/backoff ke 7 tests abhi `bun:test` mein hain (sandbox-only). PLAN K-port: yeh logic Rust kernel (`web-wasm/`, Rule 52) mein jaye + `cargo test`; phir bun test hat jaye. Step "Kernel SSE port" 4e (Merkle se pehle, kyunke Merkle bhi isi kernel mein aata hai).
- Awam website (root `package.json`, `bun.lock`, Bun SSR) = founder ka hukam: poori website nayi technology par jaye gi founder deck ke BAAD (lane A). Abhi chheda nahi.
- Slow technology banned: har endpoint ka jawab-waqt Dashboard par dikhta hai (ms); naya endpoint 400 ms se upar ho to fix (loophole L10 niche).

## Loophole / glitch sweep (1 Nov 07:55, jo mila, status)
| ID | Mila | Fix / status |
|---|---|---|
| L8 | Stream health refresh par laal | CARD HATA DI (07:45), telemetry default off |
| L9 | "khali/empty/Ready" lafz | Inbox card + Recent changes asli numbers (07:50); Bridge "Nothing needs attention" + Channels "Waiting for first data" abhi baqi: founder ki haan (copy -> "2 of 2 checks passing" / "wiring: P4 button") |
| L10 | Decks (Finance/People/Mail/AI/Release/Move-In/Systems/Control) catalog pages hain, "Nothing here is live data" | har deck ko ek ek wire karna = steps 9-13; tab tak deck page par asli registry actions (live) hi dikhte hain, koi nakli number nahi |
| L11 | Sidebar mein pehle user-app group (user pages) | HATA (07:45) |
| L12 | Repo mein bun.lock (founder-web) | HATA (07:55) |
| L13 | Tests bun-par | Kernel SSE port (step 4e) |
| L14 | Awam root bun/node | awam migration lane (founder deck ke baad) |
