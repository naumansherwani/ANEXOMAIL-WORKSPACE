# FOUNDER MASTER ORDER — numbered, one list (28 Oct 2026, 12:25 PKT)
Founder 12:12: "founder ke existing old codes latest technology par kab migrate honge, unki tarteeb kis number par hai? aur jo user ko offer hota hai woh mujhe kab milega?" This is the ONE numbered order. Detail lives in FOUNDER-BUILD-PLAN-28OCT.md §14z, FOUNDER-FEATURE-MAP-28OCT.md, FOUNDER-SETTINGS-CENTER-PORT-28OCT.md. A step is DONE only when it is green in the founder's Chrome (Rule 64). Nothing mocked (Rule 69).

UI system (tokens, shell, Trust, mobile/tablet): docs/claude/FOUNDER-UI-DESIGN-28OCT.md — applies to every step below.

## The order
| # | Step | State |
|---|---|---|
| 1 | F1a-1 device approval, F2a Ed25519 + request signatures | **LIVE (Chrome-proven)** |
| 2 | Settings S1 (E108): photo, name, **home city / adaptive city**, graphics, sidebar | built, tested, on server after: sql-run.sh -> CHECK_E108 -> founder-install.sh |
| 3 | Server leftovers: awam host guard (`pull.sh`, probe -> enforce), Polar Metrics token | Polar token **DONE 30 Oct** (reader ON); host guard still `probe` (needs one sign-in at /founderlogin, then enforce) |
| 3a | **T1 UI stack foundation** — TypeScript + TanStack Router + Tailwind 4.2 + shadcn (founder 30 Oct 18:54: locked technology is USED, not listed as a gap) — FOUNDER-TECHNOLOGY-ADOPTION-30OCT.md | in progress |
| 3b | **PRIORITY BEFORE F2b (founder 30 Oct 19:29):** fix the open loopholes in this order — L2 Bridge speed (Rust: auth DB checks + Polar pulse run together), L3 awam links never on the founder host (open on anexomail.com in a new tab), Bridge/Dashboard split ("Company health" view; Bridge keeps only action rows), L7 lockfile, L5 host guard enforce (founder: sign in once, then `founder-hostguard.sh status` -> `enforce`). L4 (Trust chip) is F2b itself. Green on server + Chrome first | in progress |
| 4 | **F2b** WASM kernel verify in the browser (pins the public key, SRI, enforce) | **LIVE** (Rust kernel `web-wasm/` in a Worker, SHA-256-pinned .wasm, Ed25519 enforce; Merkle `merkle@1` proofs shown as "proven" ticks in his Chrome 1 Nov) — row was stale |
| 5 | **F2c** audit v1 + Merkle (E107) | **SQL E107 GREEN on server (1 Nov 08:33)**; 5R Rust (`server/rust/merkle_core.rs`, `ledger.rs`, routes, auto-seal) + 5a UI card **GREEN on server + Chrome 1 Nov 09:00**; 5K kernel `merkle@1` (0.6.0) **GREEN on server + Chrome 1 Nov 09:35** (step 5 COMPLETE) |
| 5a | **I1 Ledger Integrity Gauge** (+ Dashboard item in Command center) — FOUNDER-KILLER-FEATURES | after 5 |
| 6 | **S2** Settings: Time machine + Drift & schedule | after 5 — SQL E113 **GREEN on the server 1 Nov 10:34** (CHECK 14/14 + E65); Rust `settings_s2.rs` (13 routes) + UI **installed on the server 1 Nov 10:53** (founder-install: 105 tests OK, build OK, saboot 4/4). **GREEN in founder Chrome 1 Nov 11:02** (Time machine 18 versions proven, Drift 92/100) |
| 6b | **S1b** Settings: key registry + all Appearance controls + **Ambient Studio** (founder 1 Nov 10:34) | SQL **E114 GREEN on the server 1 Nov 11:26** (CHECK_E114 14/14 + E65 6/6; 301,989,888,000 looks, computed from table sizes); Rust (`ambient.rs`, registry 14 keys, 5 ambient routes; 116 tests) + UI (Appearance 2 blocks + Ambient Studio) **written 1 Nov ~12:00, install + Chrome check pending** |
| 7 | **F2d** passkey proof for G3 (then FOUNDER_PASSWORD path removed) + **S3** Privacy | after 6 — design `FOUNDER-PASSKEY-F2D-DESIGN-01NOV.md`; **7-1 SQL E117 GREEN on the server 1 Nov 13:00** (CHECK_E117 7/7 + E65); founder 13:00: NO OTP/SMS in the founder protocol, mobile = backup flare only (section 7-0 of the design note: tiers T0-T3, action-hash binding, two keys); founder decisions 13:07 recorded (2 hardware keys, hybrid allow-list, T3 2 keys + 10 min, mobile = flare only); **7-1b E118 written + tested locally 1 Nov 13:25, server run pending**, then 7-2 Rust webauthn-rs, 7-3 UI, 7-4 enforce G3 + remove FOUNDER_PASSWORD, 7-5 mobile flare/cancel channel |
| 7a | **WebTransport / QUIC (`wtransport`)** founder live channel, replaces polling (own UDP listener + cert wiring, not awam's udp/3443); per `FOUNDER-TECHNOLOGY-ADOPTION-30OCT.md` | after 7 |
| 7b | (14:55: post-quantum hybrid X25519MLKEM768 is ALREADY negotiated on both hosts, Caddy go1.26.3; AES-256 plan = docs/claude/TLS-AES256-PLAN-01NOV.md T256-0..5) **Session & transport hardening (research 1 Nov, FOUNDER-TECHNOLOGY-ADOPTION-30OCT.md)**: DBSC (hardware-bound session, Chrome 146 Windows) + post-quantum hybrid TLS check on Caddy + founder splash lines (only true ones) | with 7 / 7a |
| 7b-T256 | **TLS AES-256 at every cost** (founder 14:24/14:33): Rust `tls256.rs` (rustls, AES-256-GCM only) on test port 8443 + SQL E119 proof ledger + `founder-tls256.sh`; then 443 per host; awam T256-2 only after his written haan. Plan `TLS-AES256-PLAN-01NOV.md` | **GREEN on the server 1 Nov 14:45**: E119 CHECK 4/4 + E65 6/6, founder-install 120 tests + build OK, founder-tls256.sh dry-run OK. **STILL OPEN:** `APPLY=1` (8443 test port), openssl proof, Chrome :8443 |
| 7c | **Motion + GSAP** in the founder UI (locked in TECH-MAP 0d, not yet in `founder-web/package.json`; founder 14:04 "latest technology founder ko do"); CINEMATIC look must stay pixel-equal (FC43) | after 7-4; proof: `tech-proof.py` MISSING count drops |
| 7d | **Three.js WebGPU renderer** (WebGL2 fallback kept) | after 7c |
| 7e | **MoQ-F** (Media over QUIC, founder first: own relay on staging, `moq@1` in the one kernel, Live Pulse behind a flag; one-way live only, WebRTC stays for calls); awam MQ0-MQ4 follow after it is proven (`ONE-ORDER-27OCT.md`) | after 7a; IETF draft: founder accepts the draft risk in writing first |
| 8 | **Decide (N)** one button + **Live Pulse** (real vs test accounts) + **S4** Notifications (push) | after 7 |
| 8a | **I3 Device Trust Map** (device-reported city, never IP) | after 8 |
| 9 | **F3** Finance deck on latest tech: Polar failed payments / churn / reconcile, Revenue, Billing, **Release (7 old launch pages)**, **Move-In** | after 8 |
| 10 | **F4** People: Org, CRM, Team permissions, Account 360, abuse/appeals, Work | after 9 |
| 10a | **I2 Active Work Chain Dependencies** (needs `depends_on` SQL) | with 10 |
| 10b | **K4 Insider Guard** (metadata-only deterministic auditor; hold = reversible) | after 10 |
| 11 | **F5 MAIL** = founder ka apna **Mail** (inbox, folders, compose, outbox, undo-send, email notifications) + **Calendar**; **Mail Desk** (company mailboxes, support replies, deliverability, SLA) is page ke ANDAR sab se END par (founder 1 Nov 07:57: "mail desk mera baap nahi hai, mail desk us mein aye ga end pe") | after 10 |
| 11d | **PQM** post-quantum MAIL CONTENT for the founder's own mail: OpenPGP RFC 9980 (ML-KEM-768+X25519, ML-DSA-65+Ed25519), SQL key registry -> Rust -> `pqmail@1` in the one WASM kernel -> compose UI; details PQM0-PQM5 in `ONE-ORDER-27OCT.md` (founder 14:48, after Proton shipped it 6 May 2026) | after 11 (his own mail first) |
| 11e | Awam technology catch-up A1-A7 (T256-2, Bun-free pages, webauthn-rs, DBSC, WebGPU, MoQ, PQM) follows each founder proof; table in `ONE-ORDER-27OCT.md` | after each founder phase is green |
| 11a | **K1 Sealed Agreements** (cross-company cryptographic escrow) | after 11 + F2c |
| 11b | **COMMON ATTACHMENTS (founder 1 Nov 09:05, plan `docs/cursor-work/ATTACH-LATEST-TECH-PLAN-27OCT.md`): A1 instant dedupe (kernel sha256 -> `attach.have`), A2 resumable chunks (per-chunk SHA-256), A4 signed share link.** ONE implementation in the shared Rust (`server/rust/attach_core.rs` / `attach_glue.rs`) + kernel `sha256@1`; founder Mail compose (step 11) and Mail<->Chat Bridge (12b) USE it, no second copy | with 11 (before 12b) |
| 11c | **A3 parallel chunks over WebTransport** (same shared attach code) | after the WebTransport phase (which comes after 7) |
| 12 | **F6** Systems: health, **Analytics**, **Speed (perf)**, **Admin**, **Safety**, **ANEXOChat**, Workspace settings. **AI is NOT here any more: it moved to the very end (step 16, founder 1 Nov 10:53)** | after 11 |
| 12a | **K2 Mesh / air-gapped sync** (research spike first; needs LAN node) | after 12 |
| 12b | **Mail<->Chat Bridge** (6 sub-steps 12b-1..6; most of it exists user-side, founder gets the latest-tech port + new deltas) — FOUNDER-MAIL-CHAT-BRIDGE | after 12 |
| 13 | **F8** Control: kill switch, flags, one-click executor (every action G2/G3, audit + rollback), Settings changes | after 12 |
| 13a | **K3 Poison Pill** (crypto-shred of cached data; G3) | after 13 |
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
| Mail (inbox, folders, compose, outbox), Calendar | **Mail** page; Mail Desk = uska aakhri hissa | 11 |
| Analytics, Speed, Safety, ANEXOChat, Admin | Systems deck | 12 |
| Docs, Sheets, Tasks | Founder desk | 15 |
(Founder 1 Nov 07:45: sidebar ka "Workspace (user app)" group HATA diya; ab group **Founder Workspace** mein sirf founder ke apne pages, har ek tab jab wire hoke live ho. Dekho FOUNDER-WORKSPACE-ORDER-01NOV.md.)

Bridge vs Dashboard (which tile lives where, CEO view): docs/claude/FOUNDER-BRIDGE-VS-DASHBOARD-28OCT.md

- Port order per feature (technology + phase): docs/claude/FOUNDER-PORT-ORDER-30OCT.md (21:20). Pointer only; master order above stays locked.

- Parity per user area (repo scan, 125 route files): docs/claude/FOUNDER-PARITY-30OCT.md (21:35).

- Legacy pages (30 Oct 22:10): none is dropped. Each old founder/admin page is ported with its own tick-list and retired only after Chrome proof: docs/claude/FOUNDER-LEGACY-REVIVAL-30OCT.md. F9 = "retire after proof", not "delete".

## ADMIN = awam ke maslon ka ghar (founder 1 Nov 09:36, locked)
"Jo awam se mera promise hai aur jin ki waja se founder account mein awam ke maslay solve hone hain, woh sab founder ke ADMIN mein hone hain. Founder ka apna sab kuch (Mail, Calendar, Settings, Profile ...) PERSONAL alag. Awam side ke saray maslay Admin ke andar solve honge aur wahan ADMIN ka apna UI/UX banega." (promises: `docs/cursor-work/PROMISES.md`.)
=> Systems > **Admin** (step 12) = awam ke maslay: support replies, glitch/inbox (E112), appeals/abuse, billing/Polar issues, move-in, org kill-switch/impersonate (G3), storage, health/incidents; apna alag Admin UI/UX (queues, SLA, per-issue actions). Founder personal pages Admin se alag rahenge. Step 12 ke design note mein yeh pehla sawal.


## MoQ = OUR OWN relay (founder 1 Nov 10:04: "i hate cloudflare, hum MoQ khud karay gay")
No Cloudflare relay or API anywhere in ANEXOChat. MoQ, when its turn comes (after ANEXOChat core, one pinned draft: `draft-ietf-moq-transport-22` as of 1 Oct 2026, no RFC yet), is a Rust relay we write and run ourselves on `wtransport`/QUIC, systemd service, no pm2, no Bun. Until then nothing is installed for MoQ and nothing is claimed. Interop with other relays is not a goal; if drafts change we change our one pin.


## Settings Center = awam ki tarteeb (founder 1 Nov 10:13) — locked
Tab order: Personal, Workspace, Appearance, Notifications, Privacy, Time machine, Drift & schedule (+AI in step 12). Full decision, keys and phases: `docs/claude/FOUNDER-SETTINGS-CENTER-DECISION-01NOV.md`. New: **S1b** (Appearance extension, E114) right after step 6 S2. No other step moves.

**S1b adds the Ambient Studio** (founder 1 Nov 10:40): car-style ambient looks, over one million generated recipes. See the addendum in FOUNDER-SETTINGS-CENTER-DECISION-01NOV.md.


## AI = FOUNDER ONLY, AT THE VERY END (founder 1 Nov 10:53 — locked, Rule 71)
Verbatim gist: "awam ko AI nahi milega; yeh AI anexomail.com ka hai, sirf us mein milega. Lovable ne jo data mix kiya hai us ki waja se aaj mera kaam tabah hua. AI ke jitne bhi advance features hain yeh founder ko milenge. AI wala kaam hum END pe karenge, founder side ka."
- **Step 16 (new, last, after Docs/Sheets step 15): FOUNDER AI** = all advanced AI features, founder workspace only (Rust + signed envelope + founder gates; read-first, no free-text SQL, he presses send). The old "AI (10 pages)" and the Settings "AI settings" tab are built here, not in step 12.
- **Awam gets no AI.** The awam code still has AI surfaces from Lovable (`src/components/app/ai/AiBits.tsx`, `src/lib/ai-studio.ts`, `ai-billing.ts`, `ai-automation.ts`, `settings/SettingsBits.tsx` Explain-with-Leo, compose/dashboard/calendar panels, `routes/app.settings.ai.tsx`). They are NOT touched now (Rule 35, awam is a separate lane). Removing them is a separate awam phase after the founder cutover, only on his written order, with an audit of what data those surfaces touch.
- Founder-side rule that follows: nothing from the awam AI code is copied into the founder side (no mixing again); the founder AI is written fresh on the founder stack.

## PHASE -> TECHNOLOGY (founder order 14:10, 1 Nov 2026) — which technology lands in which phase, in build order
One phase at a time (Rule 66); each is green on the server + his Chrome before the next. After each, `python3 docs/cursor-work/server/tech-proof.py` must show exactly one fewer MISSING. Never mix layers in one phase (Rule 70).
| Phase | Technology that lands | Layer | Proof it landed |
|---|---|---|---|
| 7-1 / 7-1b (DONE) | WebAuthn/FIDO2 registration schema, action hash, tiers, AAGUID allow-list, T3 two-key + delay, mobile flare (E117, E118) | SQL | CHECK_E117 7/7, CHECK_E118 7/7, E65 |
| **7-2 (NEXT)** | `webauthn-rs` (WebAuthn register + authenticate, FIDO2 keys, clone detection) + the SAME canonical action hash (parity vectors) + T3 ticker on Tokio | Rust | cargo tests + parity vectors == SQL; tech-proof: webauthn-rs PROVEN |
| 7-3 | Browser WebAuthn (`navigator.credentials`), Privacy tab: passkeys, hardware keys, allow-list, recovery codes, step-up prompt | React-TS UI | Chrome: add a key, see it listed |
| 7-4 | Enforcement of T2/T3 on real actions; founder sign-in passkey-only; `FOUNDER_PASSWORD` removed; no mailed sign-in link, no DBSC claim | Rust + SQL + UI | his Chrome passkey proof first |
| 7-5 | Out-of-band alert + STOP-cancel for the mobile flare (alert + cancel only, never a login) | Rust + SQL | provider + his number needed |
| 7a | WebTransport / QUIC via `wtransport` (own UDP port + cert), HTTP/3 live channel replaces polling | Rust + UI | tech-proof: wtransport PROVEN (founder); Chrome shows live transport |
| 7b | DBSC (device-bound sessions, Chrome 146 Windows). Post-quantum hybrid TLS: ALREADY negotiated on both hosts (X25519MLKEM768, seen 1 Nov 14:28) | Rust | DBSC header in code |
| 7b-T256 | AES-256-GCM-only TLS 1.3 terminator `tls256.rs` (Rust, GREEN on server) + SQL E119 posture ledger (GREEN) + `founder-tls256.sh` (dry-run GREEN; APPLY=1 next; test port 8443, then 443) | Rust + SQL + server ops | openssl: browser-style client lands on AES-256, AES-128-only refused; `/founder/v1/tls` verdict forced_256 |
| 7c | Motion (Framer) + GSAP in the founder UI, CINEMATIC look pixel-equal | React-TS UI | tech-proof: Framer Motion + GSAP PROVEN |
| 7d | Three.js WebGPU renderer (WebGL2 fallback kept) | React-TS UI | tech-proof: WebGPU PROVEN, FPS budget |
| 7e | MoQ-F: own MoQ relay (staging), `moq@1` in the one WASM kernel, Live Pulse behind a flag (one-way live; WebRTC stays for calls). Then awam MQ0-MQ4 | Rust + WASM kernel + UI | tech-proof: MoQ PROVEN; founder accepts the IETF-draft risk in writing first |
| 8 | Decide (one button), Live Pulse, S4 push notifications | Rust + SQL + UI | |
| 9-13 | Finance, People, Mail + Calendar (Mail Desk last), Systems, Control | Rust + SQL + UI | |
| 14 | Cutover: old Lovable founder routes + Bun-only endpoints removed after Rust == Bun | Rust | |
| 15 | Docs + Sheets (WOPI) | engine chosen after a licence read | |
| 16 | Founder AI (Rule 71: awam gets none) | founder only | |
