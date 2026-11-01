# FOUNDER WORKSPACE — founder ki apni list, apni tarteeb (founder 1 Nov 07:52 PKT)
Order verbatim: founder-commands.md 07:52. Sidebar: Dashboard, Bridge, phir group **Founder Workspace** (Bridge ke neechay). Har item founder ke apne endpoint (`/founder/v1/*`), apne gates (G1/G2/G3), apni tables, latest technology (Rust axum+tokio -> signed envelope -> WASM kernel verify -> React-TS). User ke pages/data/token KABHI nahi (FC18/FC22). Item sidebar mein tab aata hai jab wire hoke live ho ("jab bari aye gi"); slow technology banned.

| # | Founder ki list (user app naam) | Founder Workspace item | Live source (asli) | Gates | Step (blueprint) | Halat |
|---|---|---|---|---|---|---|
| 1 | Dashboard | **Dashboard** (company health) | live feed + Polar + audit + inbox | G1 | 4a/4b/4d | LIVE |
| 2 | Mail | **Mail Desk** | company mailboxes (Postfix/Dovecot) + outbox | G1/G2 | 11 | deck sidebar mein; asli mail 11 mein |
| 3 | People | **People** | accounts, devices, orgs (metadata only) | G1/G2 | 10 | deck; asli 10 mein |
| 4 | Calendar | Mail Desk > Calendar | calendar tables | G1 | 11 | 11 mein |
| 5 | Work | People > Work chain | work + depends_on (10a) | G1 | 10 | 10 mein |
| 6 | CRM | People > CRM | revenue_leads, accounts | G1/G2 | 10 | 10 mein |
| 7 | Org | People > Org | orgs, members, policies | G1 | 10 | 10 mein |
| 8 | Analytics | Systems > Analytics | probes + Polar metrics | G1 | 12 | 12 mein |
| 9 | Safety | Systems > Safety | abuse + host proof + insider guard | G1/G2 | 12 (K4 10b) | 12 mein |
| 10 | ANEXOChat | Systems > ANEXOChat (+ Mail<->Chat Bridge 12b) | chat metadata | G1 | 12 / 12b | 12 mein |
| 11 | AI | **AI** (10 founder-only pages) | AI spend/receipts | G1 | 12 | deck; asli 12 mein |
| 12 | Speed | Systems > Speed | p95 probes | G1 | 12 | 12 mein |
| 13 | Founder | Control + Settings (purane Lovable founder pages replace, F9) | founder_actions | G2/G3 | 13/14 | cutover par |
| 14 | Admin | Control (kill switch, flags, executor) | founder_actions | G2/G3 | 13 | 13 mein |
Founder-only extra (user ke paas nahi): Finance (Polar), Release, Move-In, Audit ledger, **Inbox** (4d P2).
**Naam 'Admin/Founder/Speed...' ke sidebar items ek ek karke tab dikhenge jab unka page asli data se live ho** — abhi group mein wo decks hain jo sidebar mein pehle se the (Mail Desk, People, AI, Systems, Control, Finance, Release, Move-In, Audit ledger), isi tarteeb mein (founder ki list ki tarteeb pehle, phir founder-only).

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
| L10 | Decks (Finance/People/Mail Desk/AI/Release/Move-In/Systems/Control) catalog pages hain, "Nothing here is live data" | har deck ko ek ek wire karna = steps 9-13; tab tak deck page par asli registry actions (live) hi dikhte hain, koi nakli number nahi |
| L11 | Sidebar mein pehle user-app group (user pages) | HATA (07:45) |
| L12 | Repo mein bun.lock (founder-web) | HATA (07:55) |
| L13 | Tests bun-par | Kernel SSE port (step 4e) |
| L14 | Awam root bun/node | awam migration lane (founder deck ke baad) |
