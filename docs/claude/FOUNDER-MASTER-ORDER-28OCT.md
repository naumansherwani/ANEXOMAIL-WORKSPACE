# FOUNDER MASTER ORDER — numbered, one list (28 Oct 2026, 12:25 PKT)
Founder 12:12: "founder ke existing old codes latest technology par kab migrate honge, unki tarteeb kis number par hai? aur jo user ko offer hota hai woh mujhe kab milega?" This is the ONE numbered order. Detail lives in FOUNDER-BUILD-PLAN-28OCT.md §14z, FOUNDER-FEATURE-MAP-28OCT.md, FOUNDER-SETTINGS-CENTER-PORT-28OCT.md. A step is DONE only when it is green in the founder's Chrome (Rule 64). Nothing mocked (Rule 69).

UI system (tokens, shell, Trust, mobile/tablet): docs/claude/FOUNDER-UI-DESIGN-28OCT.md — applies to every step below.

## The order
| # | Step | State |
|---|---|---|
| 1 | F1a-1 device approval, F2a Ed25519 + request signatures | **LIVE (Chrome-proven)** |
| 2 | Settings S1 (E108): photo, name, **home city / adaptive city**, graphics, sidebar | built, tested, on server after: sql-run.sh -> CHECK_E108 -> founder-install.sh |
| 3 | Server leftovers: awam host guard (`pull.sh`, probe -> enforce), Polar Metrics token | founder commands pending |
| 4 | **F2b** WASM kernel verify in the browser (pins the public key, SRI, enforce) | next build |
| 5 | **F2c** audit v1 + Merkle (E107) | after 4 |
| 6 | **S2** Settings: Time machine + Drift & schedule | after 5 |
| 7 | **F2d** passkey proof for G3 (then FOUNDER_PASSWORD path removed) + **S3** Privacy | after 6 |
| 8 | **Decide (N)** one button + **Live Pulse** (real vs test accounts) + **S4** Notifications (push) | after 7 |
| 9 | **F3** Finance deck on latest tech: Polar failed payments / churn / reconcile, Revenue, Billing, **Release (7 old launch pages)**, **Move-In** | after 8 |
| 10 | **F4** People: Org, CRM, Team permissions, Account 360, abuse/appeals, Work | after 9 |
| 11 | **F5** Mail Desk (+ **Mail**, **Calendar** common features, email notifications, undo-send settings) | after 10 |
| 12 | **F6** Systems + **AI (10 pages, founder-only)**: health, **Analytics**, **Speed (perf)**, **Admin**, **Safety**, **ANEXOChat**, Workspace/AI settings | after 11 |
| 13 | **F8** Control: kill switch, flags, one-click executor (every action G2/G3, audit + rollback), Settings changes | after 12 |
| 14 | **F9 CUTOVER**: old 36 Lovable founder route files + 53 Bun-only founder endpoints removed ONLY after Rust == Bun proof for each | after 13 |
| 15 | **Founder desk**: Docs + Sheets (Collabora/OnlyOffice via WOPI; engine chosen after a licence read), calendar, tasks | last |
Awam ONE-ORDER resumes after step 3 is green (FC21); it is a separate lane and is not touched here.

## Old founder code -> which step migrates it (from FOUNDER-CODE-INVENTORY-28OCT.md: 36 route files, 6,541 lines; 77 endpoints = 53 Bun-only + 24 Rust-first)
| Old code (Lovable-era) | Today | Latest-tech home | Step |
|---|---|---|---|
| `app.founder` home + founder.ts (6 Bun endpoints) | replaced by the new Bridge | Bridge (done) | removed in 14 |
| Revenue / pipeline / billing (3 pages) | Rust pipeline proc + Bun | Finance deck | 9 |
| Launch / Release (7 pages, 13 Bun endpoints) | Rust `founder.release.*` + Bun | Release deck (read) + executor | 9 then 13 |
| Move-In (374 lines, 16 Bun endpoints) | Rust cockpit + Bun | Move-In deck | 9 |
| Org / People (4 Bun) + CRM | Bun | People deck | 10 |
| Admin (11 Bun) + Perf (9 Bun) + Analytics (Rust) | Bun / Rust | Systems deck | 12 |
| Security / Settings / Integrations / Safety (Rust setx) | Rust | Settings S1-S4, Systems, Control | 6, 7, 12, 13 |
| glitch (4 Bun), storage, org endpoints | Bun | Systems / People | 12, 10 |
| calls, motion pages | device samples | not planned — founder decides, else removed | 14 |
| AI (10 pages, ~2,814 lines) | Lovable pages; founder lifted Rule 23 for HIS workspace (28 Oct 12:17) | AI inside Systems deck (read-first, no free-text SQL, he presses send) | 12 |
| `founder.preview` (lorem/TODO), FounderBar, 3 Lovable hosts, FOUNDER_PASSWORD | dirt | deleted | 7 (password), 14 (rest) |
Rule for every row: before porting, write down where the old proc lives (ENDPOINT-PACKAGE-MAP.csv), port to Rust with the same behaviour, prove Rust == Bun in Chrome, only then retire the old route (F9).

## "What the user gets" -> founder (FC18/FC22: same features, latest tech, founder protocol, separate code)
| User feature | Founder version | Step |
|---|---|---|
| Greeting, clock, sidebar, Account menu, photo, Settings (Personal, Appearance), home city | **done** | 1-2 |
| Settings: Time machine, Drift & schedule | Settings S2 | 6 |
| Settings: Privacy | S3 | 7 |
| Settings: Notifications | S4 (push), email with Mail Desk | 8, 11 |
| People, Org, CRM, Work | People deck | 10 |
| Mail, Calendar | Mail Desk | 11 |
| Analytics, Speed, Safety, ANEXOChat, Admin | Systems deck | 12 |
| Docs, Sheets, Tasks | Founder desk | 15 |
Until a founder version exists, the sidebar's WORKSPACE links (Dashboard, Mail, People, Calendar, Work, CRM, Org, Analytics, Safety, ANEXOChat, AI, Speed) open the real user-app pages on the same host, so nothing is missing in daily use.
