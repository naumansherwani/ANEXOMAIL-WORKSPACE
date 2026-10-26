- 22 Oct 2026: #3 iMIP code written (imip_core.rs, deliver hook, rsvp_via in cal_glue, Guests label). NOT green until server output + live Gmail test.
- 22 Oct 06:53: #3 iMIP E60 SQL + Rust cal + Rust deliver + web = server par INSTALLED (founder output). Dobara install mat karwana. Baaki: live Gmail Yes test. Rule: records likhne ke BAAD manifest-sync dobara (pull "KUCH GALAT" ki wajah).
- 22 Oct 06:56 founder correction: G16 billing portal (B6 Rust billing.portal) kal shaam bana hua hai, GREEN — ledger D6 theek kiya. Dobara 'baqi' mat likhna.
- 22 Oct 06:57 GALTI: maine G16 ko 'GREEN' likh diya tha — founder: portal bana nahi. Sach: sirf B6a (Manage billing -> Polar-hosted portal). In-app portal ka scope founder se pakka hone tak 'BANA NAHI'.
- 22 Oct 07:00 G16 = docs/claude/BILLING-PORTAL-BLUEPRINT.md (founder ne kal diya). Bana sirf P0+P1 (+B6a Polar-hosted button). P2–P8 BANA NAHI. 'Rust billing.portal GREEN' ko G16 ka poora kaam mat samajhna.
- 22 Oct 07:20 BUG (Rule 29): live calendar_attendees mein created_at column NAHI (CHECK_CAL_GUESTS ne saboot diya) — cal_glue attendee_rows/attendees_of_many 'order=created_at.asc' PostgREST error deta tha, .ok() ne chhupa diya => guest list khali. Fix: order=address.asc + error log. Rust cal reinstall baaki, phir iMIP test dobara.
- 22 Oct 07:30: #3 ka asli-pipe saboot script imip-reply-proof.sh push; founder ka output aane par GREEN. Gmail RSVP-bar sharT nahi.
- 22 Oct 07:47 #3 iMIP = GREEN (imip-reply-proof.sh founder output A/B/C/D sab theek). Dobara test mat mangna. Agla: founder ka naya hukm — Outlook-jaisa mail UI/feature map (kaun si feature kis package, kahan).
- 23 Oct 08:30 CalDAV #6 C1 BANA (server par BAAQI): dav_core.rs (14 tests pass sandbox), dav_glue.rs (compile server par hoga; installer build fail par rollback), installer module `dav`, caddy-caldav.sh (plan/apply/rollback; insert snapshot par dry-run OK), PhoneCalendar.tsx + lib/caldav.ts (2 bun tests; 367 total pass). E80 sandbox GREEN. Founder ne abhi KUCH NAHI chalaya. C2 (likhna, sync-collection) BANA NAHI. Live check baaki: curl PROPFIND + phone.
- 23 Oct 08:25 CalDAV C1 server par: E80 GREEN, Rust dav module build+health OK, Caddy apply OK (301/401). Dobara mat chalana. Baaki: Caddy re-apply (DAV header), Settings password, phone test.
- 23 Oct 08:30 CalDAV Caddy DAV header re-apply GREEN (OPTIONS dav: 1, calendar-access). Server taraf mukammal; baaki phone test.
- 23 Oct 08:40 Classic calendar phone overflow fix (rows wrap, Panel overflow-x-hidden). Live phone check baaki (founder).
- 23 Oct 08:55 Mail-open crash hardening: normalizeThread + retry (useThread). Asli error founder ke account se baaki.
- 23 Oct 09:00 Calendar phone toolbar redesign (⋯ menu, 44px targets, full-width view switch). Live phone check baaki (founder screenshot).
- 23 Oct 09:05 Phone calendar toolbar GREEN (founder screenshot); ListPanel w-full fix pushed, live check baaki.
- 23 Oct 09:15 App pull-to-refresh (PullRefresh.tsx, data-only, no reload). Live phone check baaki (founder).
- 23 Oct 09:40 MOBILE-CONTRACT.md + Text size (lib/text-size.ts, Appearance) + touch scrollbar + pull-refresh pinch guard. Phone live check baaki.
- 23 Oct 09:30 In-context zoom: mail body (READ_ZOOM) + calendar hour height (GRID_HOUR) via lib/zoom-prefs.ts. Phone live check baaki.

- 23 Oct: Pull-to-refresh asli `location.reload()` (draft ho to sirf refetch) — `lib/pull-refresh.ts hasDraft`, `PullRefresh.tsx`. Dobara data-only mat banao.

- 23 Oct: GlobeView touch-none -> touch-pan-y (popover scroll globe par atakta tha). Wapas touch-none mat karo.

- 23 Oct: useSettingHistory(key, enabled) — row history sirf open par fetch (N+1 hata). Wapas bina enabled mat lagao.

- 23 Oct: TouchScrollbar (draggable handle, coarse pointer) — lib/touch-scroll.ts + components/app/TouchScrollbar.tsx in AppShell. Dobara na banao.

- 23 Oct: SettingRow text column basis-[15rem] (buttons wrap) — wapas bina basis mat karo.

- 23 Oct: Calendar toolbar = Meeting + ek "⋯" menu (Calendar settings andar, label ke saath), sab screens par. Alag slider icon wapas mat lagao.

- 23 Oct: PhoneCalendar HowTo tabs (Android DAVx5 / iPhone / Computer) + DAV_URL. /dav/ ka browser mein "Sign in..." text normal hai — bug nahi.

- 23 Oct: DAVx5 Play Store par PAID (~1800), F-Droid par free. Founder paid app nahi lega. Guide text theek kiya. Agla option: no-install "Google Calendar subscribe" feed (secret ICS link, Rust route /dav/feed/<key>.ics; Google ka refresh 12-24h). Founder ka faisla baaki.

- 23 Oct: CalDAV B (Calendar link / feed): SQL E81 (kind dav|feed, CHECK_E81, proof) + Rust (dav_core Route::Feed/feed_ics/etag, dav_glue feed handler, procs caldav.feed.*) + Web PhoneFeed + Caddy log_skip. Local Postgres + asli handler harness (rust-harness/dav-feed-harness.sh) GREEN; server deploy baaki (founder). Dobara na banao.

- 23 Oct: DAV/feed load() paginated (sb_all, 1000/page) + chunked in.() + HashMap — 2000/1000 cap khatam. Dobara limit=2000 mat lagao. Deploy GREEN (SQL E81, Rust, Caddy log_skip, Web) founder ne 10:43 tak chalaya.

- 23 Oct: CalDAV B (Calendar link) LIVE GREEN: Google ne link kabool kiya, meetings dikhe. Dobara test/banana nahi.
- Calendar #8 Rooms: code complete 23 Oct 14:30 (deploy + live test baaki)
- Calendar GREEN 23 Oct 11:05: #8 Rooms green; #7 Google sync DROPPED/parked by founder
- Rooms deployed on server 24 Oct (SQL+Rust+Web all OK)
- CALENDAR GREEN HANDOVER 24 Oct 14:25 (12 green, #7 deferred)
- Rooms live test 24 Oct: create OK, book OK, release OK; bug: location rehti thi -> E82 release fix (14:35)
- Rule: har message ke baad context update (founder 24 Oct)
- 24 Oct 14:30 context checkpoint: rooms live-tested, release-location fix pending server SQL
- 24 Oct 14:45 rooms: Busy live OK; bug2 guest-list fix (Web)
- 24 Oct 15:05 E83 room DB guard written+proved (deploy baaki)
- 24 Oct 15:30 rooms fix4 (manual guest message) written; E83 live-verified (DB refused)
- 24 Oct 15:00 ROOMS LIVE-VERIFIED: hint, room_busy reschedule 409, release clears location
- 24 Oct 16:05 E84 series room check written (Rust, deploy baaki); web sweep: tsc/388 tests OK, lint 14 non-format items noted
- RULE: Nauman bhai ko hamesha 'aap' kehna, 'tum' nahi (24 Oct 15:17)
- 24 Oct 15:50 PRO audit start: templates UI, thread notes, domains plural (push baaki)
- 24 Oct 16:25 PRO fix: Snooze enum bug fixed (Rust+Bun), Snoozed view, templates UI, thread notes (push done, deploy baaki)
- 24 Oct 16:45 RULE: Rust PRIMARY, Bun fallback only; Pro snooze/templates ab Rust procs (mail.snooze, mail.templates.save/delete), deploy baaki
- 24 Oct 17:05 TECH AUDIT doc written; Pro server gates (snooze/schedule/templates) Rust+Bun; deploy baaki
- 24 Oct 17:30 M1: thread labels/status/move/assign/snooze Rust primary (client+Bun validation); deploy baaki
- 24 Oct 17:50 MIGRATION-PHASES-24OCT.md written (11 phases, lanes A/B/C); code deploy M1 baaki
- 24 Oct 18:00 M1 deployed by founder (Rust+restart+Web); live test pending
- 24 Oct 18:20 M1 fix: mailx module (Rust procs ab asli deploy path se), main.rs reverted; deploy pending
- 24 Oct 18:35 brain-pro-install.sh (Bun fallback Pro fixes) written; Bun live purana tha; deploy pending
- 24 Oct 18:50 brain-drift-check.sh (read-only) added; rule: har batch mein Bun command bhi
- 24 Oct 19:20 M1 live GREEN (snooze/folder/status/move/labels/templates); E85 assign fix + Bring back now written, deploy pending
- 24 Oct 20:10 M2 written (compose procs -> Rust mailx: drafts/versions/templates.list/snippets/signatures/confidence/followup; Bun draft columns fixed; E86 SQL; client rpcOrRest); deploy pending, M1 se baad
- 24 Oct 22:00 hisaab: docs/claude/MIGRATION-LEDGER-24OCT.md + ENDPOINT-MIGRATION-24OCT.csv (511 Bun endpoints, 132 Rust-first, 379 baqi; 320 Rust procs); E84 SQL nahi tha (Rust-only), isliye E83 -> E85
- 24 Oct 22:30 Rule 50: migration phase table + ledger saath ke saath update (founder rule)
- 24 Oct 22:45 E84 SQL banayi (tarteeb E83->E84->E85 poori; comment on guard + CHECK_E84, local 2x test OK)
- 24 Oct 23:15 M2 LIVE GREEN (Pro, Chrome 1440/820/390 + Rust procs): drafts save/versions v1-v2, snippets, followups (E86), confidence, templates.list, schedule (holding->cancel); thread insights now Rust-first; TaskBoard 4 columns OK; Pro NOT yet green (shared-inbox collision guard, Basic gate tests, M3-M5 migration first)
- 24 Oct 23:30 LIVE (founder): composer se attachment ke saath email bheji, Gmail par mili (send + attachment GREEN, Pro workspace)
- 24 Oct 23:59 M2b written (READY, deploy pending): handoff list/save/claim/delete + device.seen, drafts/snippets/followup delete procs (Rust mailx) + Bun delete routes (hunks4); composer autosave ab handoff save bhi karta hai; snippet delete (x) UI; basic-gate-probe.sh (Basic 403 test, server-side, no password); count-endpoints.py (ledger script)
- 25 Oct 00:20 Shared-inbox ownership LIVE GREEN (Rust assign: self 200, non-member 400, unassign 200, list shows owner). Loophole fixed (repo, Web deploy pending): owner chip showed raw user id -> now name ('You'/display name/email) via src/lib/assignee-name.ts
- 26 Oct 00:32 Pricing/positioning strategy locked (chat-only, no code yet): NO per-user pricing ever, naya Enterprise package, attachment 30/35/45/50 MB (seedha, no cloud-link), positioning strategy vs Zoho/Gmail -> docs/claude/PRICING-POSITIONING-26OCT.md + AGENTS.md Rule 51
- 26 Oct 00:50 Founder 2 naye ideas note kiye (chat-only, code nahi): (A) CRDT+WebTransport doc-collab sub-10ms -- CEO flag: abhi koi collab-doc feature hi nahi hai, scope founder se confirm chahiye; (B) Hybrid Attachment Engine (>25MB auto link) -- CEO flag: 25 Oct ki 'no cloud-link trick' positioning se takrata hai, 2 options likhe (per-recipient vs hamesha-link), founder faisla baqi -> docs/claude/PRICING-POSITIONING-26OCT.md section 6
- 26 Oct 02:50 Reconcile: PRICING-POSITIONING-26OCT.md ke attachment numbers (30/35/45/50, pehle ki guess) superseded by v6 locked numbers (packages-pricing-v6-2026-10-25.md: 25/35/45/100/100 MB) -- doosri parallel session ne founder se exact pricing table confirm karayi thi; merge conflict resolve kiya, dono docs ab align hain
- 26 Oct 03:10 ANEXOChat voice+cinematic Moon UI + 'memory-less' infra blueprint written (docs-only, no code): docs/claude/ANEXOCHAT-CINEMATIC-VOICE-BLUEPRINT.md -- Opus+FEC+DTX+WASM encoder pipeline, AnalyserNode replaced by AudioWorklet+Rust/WASM FFT (CEO suggestion), 3-layer Moon UI, io_uring/WAL/rkyv infra list with CEO overstatement flags, V1-V8 implementation order
- 26 Oct 03:30 M2 server-deploy CONFIRMED by founder ('M2 GREEN hai sab pull hogaya hai server pe codes hai') -- marked GREEN in phase table, no redundant code push. Pricing v6 FINAL confirmed by founder (contradiction flagged: table said Business Pro 100MB attachment, old-paragraph repaste said 60MB -- asked founder to confirm). New rules recorded: bandwidth cap on Enterprise 'unlimited users', CRDT->Business+/BusinessPro/Enterprise (CEO decision), Hybrid Attachment package-gated (CEO decision), WASM kernel standing rule (AGENTS Rule 52), 5 bulletproof-reliability items (8K adaptive -- already exists, verify; WASM chunk upload; QUIC keep-alive; dual-channel warning ladder; device vault cookie-clear verify -- architecture already hardware-hash based, handoff's localStorage id is separate weaker thing)
- 26 Oct 03:15 Attachment FINAL: Business Pro 60MB (not 100), Enterprise 100MB -- fixed in both PRICING-POSITIONING-26OCT.md and packages-pricing-v6-2026-10-25.md. CRDT gating LOCKED: Business/Business Pro/Enterprise. Bandwidth overage: 50TB/month threshold, CEO-suggested £10/TB (hidden, Polar+DB, not landing page). ANEXOChat big-file-send ladder recorded (Business 2GB, Business Pro 5GB, Enterprise 7GB new; Basic/Pro TODO CEO-proposed 500MB/1GB) -- distinct from email-attachment limits and from still-open Hybrid-Attachment-Engine email-link sizing
- 26 Oct 03:42 Founder gate decisions recorded (docs-only): ANEXOChat dono axes (Business 2GB/BizPro 5GB/Enterprise 7GB; Personal PRO+ 2GB/Premium 4GB; Basic/Pro NAHI), bandwidth overage har package (CEO: Business 10TB@£12, BizPro 30TB@£11, Ent 50TB@£10), AI repricing £2,000/£5,000/£25,000 (yearly 10x) -- PRICING-POSITIONING-26OCT.md s.9, ai-packages.md, PACKAGE-FEATURE-FORMULA.md. Code/Polar NAHI badla.
- 26 Oct 03:55 GTM + capacity-control strategy (docs-only): docs/claude/GO-TO-MARKET-AND-CAPACITY-26OCT.md -- wedge 15-570 user teams, SMTP reputation = asli khatra, controlled-flood waves + founding-member + capacity gates. Hetzner port-25/policy verify action item.

- 26 Oct 04:00 CEO decisions (founding 150/36mo, waves 25->50/wk, Move-In pilot, AI credits rule, AI platform ladder, overage approved) + mistake audit + phases P0-P8: docs/claude/CEO-DECISIONS-AND-FIX-PHASES-26OCT.md (docs-only)

- 26 Oct 04:05 Pricing&Plans phase (PP0-PP7) + AGENTS Rule 53 + corrections: Move-In prices intact, AI plans COMING SOON July 2027 (credits numbers void), AI Executive=Business Pro platform (Enterprise AI mein nahi): docs/claude/PRICING-AND-PLANS-PHASE-26OCT.md
- 26 Oct 04:30 PP0 feature inventory (real gates from plan-surface.ts + 175 routes, Enterprise missing from code, personal-vs-polar mapping, 6 gaps): docs/claude/PP0-FEATURE-INVENTORY-26OCT.md; AGENTS Rule 54 competitor-first; founding lock 36->24 mahine
- 26 Oct 04:40 PRICE AXES FINAL (Personal £17/£83/£1,850 alag; Business v6; £23/£46/£97 purani) + PP1 gate matrix in PACKAGE-FEATURE-FORMULA.md (proposal)
- 26 Oct 05:00 PP1 FULL gate table (39 groups, 213 features from INV-1/2/3): docs/claude/PP1-FULL-GATE-TABLE-26OCT.md -- founder approve baqi; inventories + 23 landing mistakes committed
- 26 Oct 04:40 PP1 founder jawab: calendar Basic generous/Pro zyada/Business sab; analytics tiered; CRDT Personal NAHI; Priority Support add-on vs Enterprise clarified (rename old page); 23 'ghaltiyan' = update-list
- 26 Oct 04:50 PP1: video tiers (Pro 720p, BP 2K, Ent full), booking links 1/3/20/unlimited/unlimited, tarteeb = ek ek package page (Business Basic pehle, phir Personal) -- PP1-FULL-GATE-TABLE-26OCT.md
- 26 Oct 05:00 Business Basic APPROVED (5 users/25GB/25MB/2 devices/1 booking link, domain+undo send in; GBP40/mo, yearly 440 pending). CORRECTION: Pro mein chat/video NAHI (Business+ se). Personal HOLD (alag meeting/UI/3-phase plan). Enterprise zero (baad mein advanced tech)
- 26 Oct 05:07 ENTERPRISE PRICE = £18,000/month (pehle 15,000) -- docs mein har jagah update (v6 file, PRICING-POSITIONING, FORMULA, PP1, INV-3, AGENTS). Enterprise Business Pro ke baad alag phase, abhi zero. Chat/video: Business se (Basic/Pro mein nahi)
- 26 Oct 05:20 AGENTS Rule 55: har package par PER MONTH + USER CAP (5/20/60/570/unlimited) zaroor likha ho, har page/card/Polar/SQL mein
- 26 Oct 05:30 Polar Basic checkout copy v6 (monthly £40 / yearly £440, up to 5 users, 25GB shared) landing se match: docs/claude/POLAR-COPY-V6-BASIC.md -- founder Polar mein paste karega; polar-products.md purani (never-touch) rahi
- 26 Oct 05:35 Polar Basic copy FINAL (domain-bring-your-own, up to 5 users cap, technology block 3 claims): docs/claude/POLAR-COPY-V6-BASIC.md
- 26 Oct 05:45 polar-product-ids-update.sh (docs/cursor-work/server/): founder ke diye KEY=UUID .env (/opt/polar-rust-payment) mein badalta hai, backup+health+rollback; local temp-env test PASS (update/add/bad-uuid/bad-key). Basic IDs founder chat mein dega, repo docs mein tab update
- 26 Oct 05:40 Basic Polar IDs: server .env mein Monthly 5e1c7b50-fee5-4214-873c-ad9f350476d9 / Yearly d3642ce7-a750-484c-940f-eb39039ed9c2 -- founder ne usi products ko Polar mein edit kiya (ID same), env change NAHI chahiye. Baqi: SQL phase43/E40 Basic 23/253 -> 40/440 update
- 26 Oct 05:55 BASIC CODE v6 (founder 'ab likho'): plans.ts card (£40/£440, '/ month', up to 5 users, 3 mailboxes, 15GB shared), plans.tsx (compare/FAQ/SEO/heads), index.tsx, billing-platform.ts+app.billing.tsx (user cap, shared storage), SQL E87_basic_v6.sql+CHECK_E87 (local Postgres test PASS: £40/£440, cap 5, 15GB pool). tsc 0 errors, tier-guard 2 pass. Founder correction: 15GB shared + 3 mailboxes (25GB/5 galat). Deploy baqi
- 26 Oct 06:05 Billing plan card: duplicate '/mo' + '/ month' hataya (priceFor: £40 / month, yearly £440 / year), Basic card par user cap line price ke neeche ('Up to 5 users · flat price for the whole company, no per-user fees'); plans.ts userCap field; tsc 0, tier-guard pass
- 26 Oct 06:10 Basic: 'koi app ke koi charges nahi, sab isi package mein' -- plans.ts feature line + POLAR-COPY-V6-BASIC.md bullet
- 26 Oct 06:45 Pro v6: docs/packages/{basic,pro}/ (har package ka alag folder: FEATURES/GATES-AND-TECH/NOT-BUILT), E88_pro_v6.sql+CHECK_E88 (Pro limits, seats_used asli, booking_links cap trigger; local PG PASS), Rust book_glue/book_core multi-link (cargo check + 57 tests PASS), booking UI (BookingPage.tsx/booking.ts), plans.ts/plans.tsx Pro card £105, billing label, server/lib/plan.ts Pro 10 mailboxes, POLAR-COPY-V6-PRO.md. AUDIT GHALTI THEEK: devices cap/collision guard/snooze/templates/schedule send/thread analytics PEHLE SE server-side REAL the.
