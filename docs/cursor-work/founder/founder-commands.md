# Founder ki chat commands — jaisi di gayi waisi (verbatim) + unki halat

## ▶ 26 Oct 07:45 — founder: 4 faisle HAAN + sab gates real + green ledger
Wohi 3 deploy (SQL jo pehle nahi chali to; Rust; Web) -- naya SQL NAHI. Rust ab mailx + overlap + book teeno lagata hai (ek hi script, ek build). Dekho 06:45 wala block.
- Halat: Rust cargo check OK + mailx_core 11 tests + book_core 57 tests PASS; tsc + tier-guard + plan-surface.test PASS. Ledger: docs/packages/GREEN-LEDGER.md. Live server par founder chalayega.

## ▶ 26 Oct 06:45 — founder: har package ka alag folder, jo bana nahi woh real wire; Pro: SQL E88 + Rust booking links + UI + card
Teen alag technologies, teen alag deploy (ek ek karke, is tarteeb mein):
1. SQL (Postgres) -- E88 + CHECK_E88 auto: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
   (sab row ok=t; E87 pehle chali ho to theek, warna E87 bhi auto chalegi)
2. Rust engine (booking links 3: book_glue.rs, book_core.rs): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
   (koi argument nahi: script repo ke SAARE Rust modules ek hi build mein lagata hai (book = booking links). Build FAIL par purani binary chalti rehti hai, restore khud)
3. Web (React: plans, billing, booking UI): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
Polar: Pro monthly/yearly ki description docs/claude/POLAR-COPY-V6-PRO.md se paste (qeemat £105/£1,155 Polar dashboard mein founder khud).
- Halat: SQL local Postgres par TESTED (trigger 1/3/20/unlimited, billing £105/£1155/seats_used asli, idempotent); Rust cargo check + 57 book_core tests PASS; tsc + tier-guard PASS. Live server par founder chalayega.

## ▶ 25 Oct 2026 21:30 UTC (26 Oct 02:30 PKT) — founder verbatim (PRICING v6 + Enterprise + Polar)
"mujeh ek new package introduce kerna hai jia ka naam hoga enterpise yeh 15000 pound permonth lekin mujhe yeh batao ke her package ka farq hoga. Enterprise — £15,000 / month • User/Mailbox Cap: Unlimited Users • Logical Storage: 15 TB shared mailboxes memory • File Transfer Limit: 100MB instant Email File Limit attachment. [Table: Basic Flat £40/5 users/50GB/£8.00/25MB · Pro £105/20/200GB/£5.25/35MB · Business £360/60/1.5TB/£6.00/60MB · Business Pro £2,850/570/10TB/£5.00/100MB] Business Pro — £2,850: 570 users max, 15 TB Logical Storage, 100MB. Business £360: 60 users, 25GB×60=1.5TB backend pe aye ga, 45MB. Pro £105: 20 users, 300GB (15GB/user), 35MB. Basic Flat £40: 5 users, 25GB pooled (5GB/user), 25MB. yeh tarteeb se repo main update kero aur repo main likho ke business pro aur enterpise main sab se bara kya farq hoga. ab se her paclage per month hoga per user nahi hoga. tumne codes nahi likhne hain bus tumne sirf packages aur un ke detail features upgrade kerna hai. aur polar ka tum mujhe batao ke wahan kaise update hoga. mere repo codes ko touch mat kerna sirf packages/pan jo already tumne likha hai package plan un main business pro aur enterpise aur baki sab features likhne hain takay main khud kerun ga"
- Confirm kiye farq (table vs bullets — founder ne chuna): Basic **25 GB**, Pro **300 GB**, Business transfer **45 MB**, Business Pro **10 TB** (Enterprise 15 TB se alag rahe).
- Kya: docs-only — `docs/cursor-work/founder/packages-pricing-v6-2026-10-25.md` (poori v6 table + Business Pro vs Enterprise ka sab se bara farq + Polar update ke steps) + `PACKAGE-FEATURE-FORMULA.md` v6 header. Code/Plans/Polar ko touch nahi kiya — founder khud karenge.
- Halat: **DONE (docs)** — docs-only, server command nahi chahiye. Code update + Polar products: founder ke hukm/kaam par.

## ▶ 26 Oct 05:55 — founder: Basic pehle update (landing/price/billing/SQL/gates), Chrome pehle dekho
1. Web (landing+plans+billing): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
2. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (E87 + CHECK_E87 auto; sab row ok=t aani chahiye)
- Halat: code+SQL committed; SQL local Postgres par test PASS; deploy founder chalayega. Polar copy mein 25GB -> 15GB shared fix founder khud.

## ▶ 26 Oct 05:45 — founder: "mujhe env commands do, server pe Polar product ID update karunga, IDs chat mein dunga"
1. Basic monthly+yearly IDs badalna (apni asli IDs bharo):
   `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/polar-product-ids-update.sh) POLAR_PRODUCT_PLAN_BASIC_MONTHLY=<naya-uuid> POLAR_PRODUCT_PLAN_BASIC_YEARLY=<naya-uuid>`
2. Dekhna: aakhir mein `==> OK  health: ...` aana chahiye. Fail par script khud .env wapas kar deta hai.
- Halat: script TESTED (temp .env) -- live server par founder chalayega.

## ▶ 26 Oct 05:07 — founder: Enterprise £18,000 (sab jagah update), Enterprise Business Pro ke baad alag, chat/video Business se
- Halat: DONE (docs). Code/Polar founder ke hukm par.

## ▶ 26 Oct 04:20 — founder: founding lock 2 saal, competitor-first rule, 'kaam real shuru kero'
- Halat: DONE (docs) -- PP0 inventory + Rule 54. PP1 matrix approval agla.

## ▶ 26 Oct 04:05 — founder: pricing&plans alag phase, Polar prices main karunga, Enterprise card, AI coming soon July 2027, Move-In price intact, AI Executive mein Enterprise nahi
- Halat: DONE (docs) -- PRICING-AND-PLANS-PHASE-26OCT.md + AGENTS Rule 53. PP0 inventory agla.

## ▶ 26 Oct 03:54 — founder: "tum ceo sab faislay kero" (founding-member, waves, Move-In, AI credits, platform ladder, overage) + "mistakes phase main dalo, landing fix immediately"
- Halat: DONE (docs-only) -- `docs/claude/CEO-DECISIONS-AND-FIX-PHASES-26OCT.md`. Code abhi NAHI ("koi code nahi" rule); P0 audit + P1 matrix agla.

## ▶ 26 Oct 03:42 — founder: ANEXOChat Personal PRO+ 2GB/Premium 4GB, AI plans £2,000/£5,000/£25,000, bandwidth overage har package (CEO suggestion mango)
- Halat: DONE (docs-only) -- `docs/claude/PRICING-POSITIONING-26OCT.md` section 9, `docs/ai-packages.md`, `PACKAGE-FEATURE-FORMULA.md`. Server command nahi. `ai-packages.ts` + Polar products ka update founder ke hukm par.
- Khula: credits/top-up inversion (AI), AI-plan-platform ladder confirm, overage numbers ka veto, poora feature-by-feature gate matrix approval.

## ▶ 26 Oct 03:15 — founder: Business Pro attachment 60MB confirm + bandwidth overage (50TB, CEO price) + CRDT lock + ANEXOChat file ladder (Business 2GB/Business Pro 5GB/Enterprise 7GB)
- Halat: DONE (docs-only) -- PRICING-POSITIONING-26OCT.md section 8, packages-pricing-v6 doc corrected. Server command nahi.
- Khula: ANEXOChat Basic/Pro file-size (CEO proposed 500MB/1GB, confirm baqi); Hybrid Attachment Engine email-link sizing abhi bhi unconfirmed; bandwidth overage £10/TB price confirm baqi.

## ▶ 26 Oct 03:30 — founder: pricing FINAL confirm + bandwidth cap + CRDT/attachment package-gating delegate + WASM kernel standing rule + bulletproof 5 points + 'M2 GREEN hai, dobara codes nahi, is ko green declare kero'
- Halat: DONE (docs-only) -- `docs/claude/PRICING-POSITIONING-26OCT.md` section 7, `docs/claude/BULLETPROOF-RELIABILITY-26OCT.md`, AGENTS.md Rule 52, M2 marked GREEN in phase table + ledgers. **Server command NAHI** (founder ne khud kaha dobara code na push karo, M2 already live hai).
- **Khula sawal founder ke liye:** Business Pro attachment 100 MB ya 60 MB -- ek hi message mein do alag numbers aaye, ek line mein confirm kar dein.

## ▶ 26 Oct 03:10 — founder: voice message (Opus+FEC+DTX+WASM), cinematic Moon UI, 'memory-less' infra list, 'repo main likho tarteeb se implementation order'
- Halat: DONE (docs-only) — `docs/claude/ANEXOCHAT-CINEMATIC-VOICE-BLUEPRINT.md`. Implementation NAHI shuru (koi "ab likho" nahi aaya). Server command nahi chahiye.

## ▶ 26 Oct 00:50 — founder: CRDT/WebTransport doc-collab + Hybrid Attachment Engine ideas, 'repo main likho, phases banenge codes likhe jayenge'
- Halat: DONE (docs-only, note + CEO flags) — `docs/claude/PRICING-POSITIONING-26OCT.md` section 6. Implementation NAHI shuru; 2 sawal founder ke jawab ka intezar (doc-collab scope, attachment-link option 1 vs 2). Server command nahi chahiye.

## ▶ 26 Oct 00:32 — founder: pricing/positioning strategy (NO per-user, Enterprise package, attachment 30/35/45/50 MB) + 'yeh sari baatein repo main note kero'
- Halat: DONE (docs-only) — `docs/claude/PRICING-POSITIONING-26OCT.md` + AGENTS.md Rule 51 + ledgers. Implementation abhi NAHI shuru hui (founder ne khud kaha "koi code nahi likhna"); jab "ab likho" bolen tabhi. Server command nahi chahiye.
- M2/M2b (24 Oct) ka deploy abhi founder se confirm nahi hua — commands upar (24 Oct 23:59 entry) wahi hain.

## ▶ 24 Oct 23:59 — M2b (handoff) + delete procs + Basic gate probe: READY, deploy baqi
Tarteeb (har technology ki alag; SQL is baar nahi chahiye):
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Rust restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
3. Bun/Brain (fallback; delete routes): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pro-install.sh)`
4. Web (owner ka naam chip mein, handoff, snippet delete): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
5. Basic-user 403 test (password nahi poochta; output Claude ko bhejein): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh)`
   Pro positive control (optional): `MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh)`

## ▶ 24 Oct 23:45 — founder verbatim (Pro baqi list ke jawab mein)
"yeh sab green kerna hai ek bhi nahi chodo tum samjhay. compact chat se pehle likh lo. pro tumharai prorty hai ke pro green kerna hai aur puri website ko latest technology pe migrate kerna hai jo green hai endpoints files sab kuch update kero saath ke saath. yeh codes server pe hain. mix kuch nahi kerna hai no duplicate. tum live testing ke saath chalo koi bhi loophole hoga us ko fix kerna hai"
- Pro baqi (sab ek ek karke GREEN): (1) shared-inbox collision guard live, (2) Basic-user 403 test, (3) handoff M2b, (4) test kachra saaf (label ZZ-m1, task ZZ pro audit task, draft, snippet, follow-up) — delete procs asli feature ke taur par, (5) phir M3-M5 migration. Founder account: NAHI.
- Halat: TODO (shuru, 23:45).

## ▶ 24 Oct 23:30 — founder verbatim: 'testing ke hote huway email send ki hai attachment ke saath aur Gmail pe mili hai. great news hai'
- Halat: DONE (live saboot founder ka). Docs-only, server command nahi.

## ▶ 24 Oct 23:15 — founder: 'thok ke live testing, pro green, jab tak pro/business/business pro green nahi founder account nahi'
- Halat: M2 DONE live (Rust procs + UI 3 widths). Pro abhi green NAHI: shared inbox guard, Basic 403, handoff (M2b), M3-M5. Web command (thread insights Rust-first): pull.sh. Founder account: NAHI shuru.

## ▶ 24 Oct 22:45 — founder: 'sql E84 kero, tarteeb nahi tootay'
- Halat: READY — E84_room_series_note.sql + CHECK_E84. SQL command wahi bare sql-run.sh (E84, E85, E86 number ki tarteeb se chalengi).

## ▶ 24 Oct 22:30 — founder verbatim (summary): 8 phases M1-M6/L/F/B8 plan confirm; 'yeh rule hai ke yeh saath ke saath update hoga'
- Halat: DONE (docs) — AGENTS.md Rule 50 + phase table halat. Server command nahi chahiye.

## ▶ 24 Oct 22:00 — founder: 'sql 83 ke baad 85 kaise? sab update karo + migration hisaab claude folder mein'
- Halat: DONE (docs) — `docs/claude/MIGRATION-LEDGER-24OCT.md`, CSV. Server command nahi chahiye (docs-only). M2 ki 5 commands upar wali entry mein.

## ▶ 24 Oct 20:10 PKT — M2 (compose -> Rust primary) TAIYAR, deploy baqi
- Kya: draft autosave/versions (Bun mein galat column naam se 500 tha), follow-up table `mail_followups` (E86), templates/snippets/signatures list, send-confidence, follow-up create/list ab Rust `mailx` par; Bun sirf fallback.
- Tarteeb (har technology ki alag command; SQL pehle):
  1. SQL (E85 + E86): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
  2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
  3. Rust restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
  4. Bun/Brain (fallback): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pro-install.sh)`
  5. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
- Halat: READY (repo mein, server par chalana baqi). Agla: M2b handoff, phir M3.

> **22 Oct 2026 20:50 (founder, Rule 45):** sign-in bhi latest tech (Rust) par, Bun hamesha emergency, frontend latest, SQL super-advance, passkey/fingerprint vault mein, wrong activity => block + vault ban list, dobara signup vault se match. Verbatim + plan: `docs/cursor-work/AUTH-MIGRATION-PLAN.md`. Halat: READY (plan likha), kaam W2 ke baad.

> **22 Oct 2026 20:32 (founder, Rule 44):** SQL ab SERVER par `sql-run.sh` se chalti hai (editor nahi), aur woh PEHLE chalti hai. Command: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (bina naam = sab nayi) ya naam aakhir mein bina .sql ke.

> **STRICT RULE 24 (founder, 19 Oct 2026 05:20 PKT): compact ke baad ya naye chat mein KAAM SHURU karne se PEHLE yeh file poori padho.**
> Founder jo bhi command/hukm chat mein deta hai, agent usi turn mein yahan **verbatim** paste karta hai (neeche "Commands" mein, naya sabse upar), aur har command ke saamne halat likhta hai.
> Jo kaam ho chuka hai uski **usi waqt pull command** founder ko di jati hai (technology ke hisab se alag alag — Rule 24).
> **Password/secret yahan KABHI nahi** — founder ne chat mein diya ho to bhi `[REDACTED]` likho.
> Halat sirf: DONE (live saboot) / READY (repo mein, server par chalana baqi) / TODO (Rule 5).

> **Nishan wala as-is version: `docs/cursor-work/founder/founder-command-2026-10-19-status.md`** (🟢 ho gaya / 🔴 nahi hua).

> **22 Oct 2026 16:51 UTC (21:51 PKT) — founder verbatim:** "duniya ka advance billing portal ke features list likh do repo ke claude/BILLING-PORTAL-BLUEPRINT.md itnay advance ke duniya hil jaye."
> Halat: **DONE** — 32-feature advanced list `docs/claude/BILLING-PORTAL-BLUEPRINT.md` (Section 2A) mein likhi, locked rules (Polar no-touch, flat price, block kabhi nahi, metadata-only privacy) ke andar. Docs-only; server command nahi chahiye.

## ▶ 22 Oct 2026 06:10 PKT — B7c progress #1: SQL E59 TAIYAR (repo mein, server par abhi nahi)
- `docs/cursor-work/sql/E59_booking_page.sql` + `CHECK_E59.sql`: booking_pages + bookings, DB-level double-booking wall (page row lock + slot re-validate + EXCLUDE gist), booking_context/book/manage/cancel/reschedule (service_role only), self-test 9 checks. Local Postgres 16 par: asli E31+E56+E57+E58 chain ke upar do baar chali (idempotent), self-test PASSED, 8 parallel sessions ek hi slot par -> sirf 1 jeeta, CHECK_E59 11/11.
- AGLA: Rust `book` module (book_core.rs std-only tests + book_glue.rs, installer mein), phir web `/book/$handle` + Settings > Booking. Command order (jab sab tayyar): SQL `E59_booking_page CHECK_E59` -> Rust installer -> Web pull.

## ▶ 22 Oct 2026 05:21 PKT — B7c BOOKING PAGE SHURU (founder verbatim: "tum CEO ho aur jo tumhay sahi lagay woh kero aur codes likhen se pehe repo and sandbox update kero ke yeh task shuru ker raha hoon verna compact chat task ke beach hota hai phir tum claude bhul jate ho. shuru kero repo rules read kero pura repo read kero phir shuru kero technology read kero") — status: IN PROGRESS (task #110)
- Plan (CEO faisla, founder ne mujh par chhoda): public link `/book/<handle>` (handle default = @anexomail.com ka username, badal sakta hai); slots = working hours (E58) - busy (calendar_events) - buffer - min notice - meeting length, visitor ke tz mein; DB-level double-booking lock (SQL E59, Rule 38); public rate limit; booking par confirm mail + .ics + cancel/reschedule link; Rust naya module `book` (core+glue, installer mein, Rule 35); web: public `/book/$handle` + Settings > Booking section; 390/820/1440.
- Compact ho to yahin se: SQL E59 -> Rust book module -> web page -> 3 command (SQL, Rust, Web). Jo bana woh neeche likha jayega.

## ▶ 22 Oct 2026 05:35 PKT — founder: "repo main green mark kero aur next tarteeb se batao kya hai next?"
- GREEN mark: MASTER-GAP-LEDGER + DONE-DO-NOT-REPEAT (Layout v2, E58, sign-in A). NEXT = roadmap #2 Booking page B7c (working hours + busy time + buffer/notice/length/visitor tz, DB slot lock, rate limit, confirm mail+.ics+cancel/reschedule link).

## ▶ 22 Oct 2026 05:30 PKT — E58 LIVE GREEN (Chrome, founder Pro session, meri apni tab, band kar di)
- 1440: Calendar settings sheet khula (calendars + 8 rang, working hours Mon-Sun, clock/layout). Calendar add + Save -> page reload ke baad bhi 2 calendars (Rust locale.uipref.set + SQL E58 round-trip sahi). Test calendar delete + Save: founder ki settings wapas.
- 390 / 820 (iframe trick): hscroll 0, Settings sheet 390px/520px, NewMeeting mein Reminder select maujood, hscroll 0.
- Dekhna baqi (event hi nahi tha): month chip rang, OOO tint, event par calendar/reminder editor (EventDetail), reminder toast ka waqt. Jab founder ki pehli meeting bane tab dekhna.

## ▶ 22 Oct 2026 05:15 PKT — SQL E58 GREEN (founder output)
`CHECK_E58`: 9/9 OK (columns, constraints, function, 16 KB limit, remind index, VALIDATED, awam_ui_extra_ok accept+reject, calendar_remind_ok). E58 SQL pehle hi chali hui thi (sha c32e0e00, skip). SQL + Rust + Web teeno DONE; baqi E58 ka live look (Chrome 1440/820/390) -> phir booking page B7c.

## ▶ 22 Oct 2026 05:12 PKT — founder ne SQL E58 + Web pull dono chala diye ("yeh dono chala diya hai tum apni memrory update kero sab codes update kero repo main jao")
- Web: LIVE saboot (maine live /auth par Playwright se dekha, 1440): Sign in button par `ax-a-hover` class + A slot maujood, hover par A "Sign in" ke left mein bahar aata hai = Rule 39 DONE (live). Baqi screens (820/390) aur founder ka apna dekhna baqi.
- SQL E58: founder ne chalaya, par output paste nahi kiya -> `CHECK_E58` ki 9 rows true dikhani baqi; jab tak output na aaye E58 LIVE GREEN nahi likha jata (Rule 5). Rust E58 pehle DONE.
- Agla: E58 ka live look (Chrome, 1440/820/390, founder ke Pro session mein) SQL output ke baad; phir booking page B7c.

## ▶ 22 Oct 2026 05:08 PKT — SIGN-IN BUTTON KA A: LOCKED (verbatim: "yessssss yeh hai woh kaamal kya bnaya hai waha love you cursor jata hai sign in pe toh logo kaise bahar ata hai forever yeh kero jab tak founder yani main nahi bolun tab tak nahi change kerna hai yeh puri website ke liye hain repo main rule likho codes ko save kero sirf signin ko touch kerna hai baki sab style intact hai no codes change hain") — status: READY (Web pull baqi)
- AGENTS.md Rule 39. Sirf Sign in button (auth.tsx + BrandLoader HoverA + styles.css block) + backup `backups/signin-a-20261022/`. Passkey-enrol button original rakha.

## ▶ 22 Oct 2026 05:02 PKT — A-logo cursor tilt WAPAS (reverted) — founder pull nahi karega jab tak demo pasand na ho
Founder: "nahi pasand aya hai yeh sign in jahan pe yeh logo A ata tha nazar halka sa hilta tha. yeh demo do" / "yeh bhi tumne wrong kiya yeh dono commits main nahi pull kerun ga?"
- d3d42fe (AuthCinema cursor tilt) ko revert kiya taake pull mein na aaye. Asli A kaun sa hai (card ke upar / left panel / boot splash) founder ne abhi nahi bataya; demo artifact mein 2 variant. Jab founder chune tab hi asli site mein lagana. E58 commits alag hain (server par SQL + Web baqi).

## ▶ 22 Oct 2026 04:52 PKT — Rust E58 install server par DONE (founder output); roadmap halat (verbatim: "yeh update kero jo pelhe hai code aye hain mere pass compact chat se pehle update kero")
Founder ne `rust-engine-install.sh` chalayi: unit tests sab ok (cal 38, locale 6 ...), build OK 2m04s, pm2 online, `calendar.meta.set` (nakli token) 401 = Rust ne proc pakda, `locale.uipref` 401 = pakda. Rollback: `/opt/anexomail-rust/src/main.rs.bak.1792626417`.
- Rust = DONE (live). SQL E58 (advance version) aur Web pull = baqi (founder ke command). E58 LIVE GREEN sirf in dono ke baad + Chrome look.
- Roadmap: 0 Layout v2 GREEN | 1 E58 Rust DONE, SQL+Web baqi | 2 Booking page B7c TODO | 3 iMIP reply G26 TODO | 4 World-clock pins, team overlay, ICS subscribe TODO | 5 Event files TODO | 6 CalDAV TODO | 7 Google sync TODO (founder Google Cloud verification shuru kare) | 8 Rooms TODO.

## ▶ 22 Oct 2026 04:43 PKT — SQL ADVANCE LEVEL rule (verbatim, status: DONE rule + E58 dobara likha, READY server par)
Founder: "ek baat bata kya sql duniya ka advance hai rule likho ke founder ke strict rule hai ke sql duniya ke advance hogay claude sql read karay ga tab tak read karay ga jab tak sql duniya ka advance level pe reach nahi ker jaye sql likho advance level"
- AGENTS.md Rule 38 likha. E58 same file mein advance banaya (DB-level shape validator, NOT VALID+VALIDATE, lock_timeout, reminder index) + CHECK_E58 mein behaviour tests; local PG par saaf DB par 2 baar + real insert test PASS. E57 server par chal chuka hai isliye E57 ko chhua nahi; E58 usi ka constraint upgrade karta hai.

## ▶ 22 Oct 2026 05:20 PKT — E58 READY (working hours, out-of-office, calendars+colours, reminders) — founder ke 3 command, is tarteeb se
Founder (04:30, roadmap #1): "Working hours, out-of-office, alag calendars aur rang, reminders" — "yeh kerna hai".
- Halat: READY (repo mein, server par chalana baqi). Live GREEN sirf founder ke output + Chrome look ke baad.
- Reminders abhi sirf in-app (ReminderWatcher); mail reminder ke liye server timer alag step — sach likha.
- Command 1 (SQL): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E58_calendar_prefs_reminders CHECK_E58`
- Command 2 (Rust): rust-engine-install.sh (calendar.meta.set probe andar)
- Command 3 (Web): pull.sh
- Agla (roadmap): booking page B7c -> iMIP G26 -> world-clock/team overlay/ICS subscribe -> event attachments -> CalDAV -> Google sync -> rooms.

## ▶ 22 Oct 2026 03:30 PKT — CALENDAR LAYOUT hukm (verbatim ka matlab, status: TODO -> kaam shuru)
Founder: "do side bar anay se woh neechay rehta hai … pehle woh seedha jo live time pe rehta tha. aur time live dekhna chaiye … sab plans mein. **duniya mein jo bhi user hoga us ki country ka time chalay ga** … demo like kiya (ek sidebar, upar toolbar, Month default, live ghadi + laal now-line). Calendar Google se advance kaise hoga bhi batao. mobile / tablet / laptop teeno dekhna. website already calendar Rust pe hai (engine ko mat chhedo). sab kero. Chrome login tha achanak kya hua dekho."
- Faisla: ek hi sidebar (app menu), calendar ka beech wala panel desktop par hata; toolbar mein Month/Week/Day/Today/tir/+Meeting/live ghadi (browser ka time zone); week/day mein laal now-line; Month default; detail grid ke upar overlay; phone par list+detail alag screen; SAB packages barabar (Rule 37, koi tier code nahi). Rust calendar engine untouched.
- Pehle ka B7b (recurrence) server par GREEN (E56 + Rust + web). Live Chrome test aadha: "this only" cancel PASS; test series "Recurrence test (delete me)" cleanup baqi.

## ▶ ABHI KA KAAM — founder ka hukm 19 Oct 06:27 PKT: "is tarteeb se codes likhna hai." (founder 20 Oct 03:55: "woh shaam ajj hai" — "shaam ko" wali shart khatam, tarteeb ab CHAL RAHI hai)

✅ **DONE (live saboot):** E36 / Business Pro logins (05:54, dobara touch nahi) · E35 SQL (05:54) · E34 SQL (06:06) · Rust cal+people+team+mig (06:16: build OK 1m43s, health 200, GUARD 2 reads, port 993 khula) · Web pull db11a0b (06:16, /health 200) · **Import mail live test GREEN (06:27: asli imap.gmail.com se `auth_failed` jawab, nakli login)**.

**Shaam ko, is tarteeb se (ek ek, jab ek green tab agla):**
0. **PRIORITY (founder 06:34): technology version upgrades** — 0.1 tokio 1.53.3 **DONE (live 03:28)** · 0.2 axum 0.8.9 **DONE (live 03:59)** · 0.3 wtransport 0.7.2 **DONE (live 04:37)** · N7 **DONE (live 05:03)** · 0.4 rustc 1.99.1 + edition 2024 **DONE (live 06:07)** · E37 + locale **DONE (live)** · ▶ **CHAL RAHA: R1a aane wali mail ka pipe Rust par** — TECH-MAP 0a: tokio -> axum 0.8 -> wtransport/quinn/rustls -> rustc/edition 2024 -> Bun. Ek ek, restore-on-fail, har ke baad health + `mig-live-test.sh` GREEN. (Pehla qadam: official source se versions dobara verify.)
1. **Attachments E37** — Option A locked (policy: 06:16 entry): SHA-256 dedup sirf org ke andar, `/mnt/anexomail-box/attachments` (Storage Box mount, NVMe nahi), phase48 quota, DB mein sirf metadata; pehle migration, phir live inbound ka chhota anchor-based patch.
2. Chat audit.
3. iMIP REPLY (G26).
4. Bun routes -> Rust (Business / Business Pro pehle), differential tests ke saath.
5. Caddy read-only check script (+ TECH-MAP row) — Caddy/HTTP3 ko chhedna nahi.
6. Business / Business Pro blueprint tarteeb.
(Port 993: khula, DONE. OAuth: jaan-boojh kar baad mein.)

**Qaida:** ek time par sirf 1–2 point; naya kaam nahi; har kaam ke baad technology-wise alag pull command + agent khud test.

---

## Halat (aakhri update: 19 Oct 2026 05:20 PKT)

| # | Founder ka hukm (19 Oct 03:35 PKT wala bada message) | Halat | Server par chalane ki command (technology ke hisab se) |
|---|---|---|---|
| 1 | G29 — revoked member ko Rust `mail_identity` na roke: fix | **DONE (live 06:16, GUARD 2 reads)** | Rust: `rust-engine-install.sh` (GUARD step) |
| 2 | G30 — migration worker: App-Password IMAP, PRIMARY Rust :3200, walled garden + `migration_session_token`, SHA-256 chain, rustls/webpki crates | **DONE (live): E35 SQL 05:54 + Rust mig 06:16 + Web page 06:16 + port 993 khula**; nakli-login live test `mig-live-test.sh` baqi (founder ka output) | SQL E35 -> Rust `MODULES=mig` -> Web pull |
| 3 | G31 — team ke baqi hisse: seat limit, audit chain, work address | **DONE (live: E34 06:06 + Rust 06:16)** | SQL E34 -> Rust -> Web |
| 4 | G32 — Rust `manager` role rank 0 na ho | **DONE (live 06:16)** | Rust installer |
| 5 | Chat audit | TODO | — |
| 6 | Inbound iMIP REPLY (G26) | TODO | — |
| 7 | Bun routes -> Rust (Business / Business Pro pehle), differential tests ke saath | TODO | — |
| 8 | Caddy (Edge + HTTP/3) saath chalna; kabhi nahi tootna: read-only check, backup, `caddy validate`, reload | TODO (check script + TECH-MAP row) | Caddy: alag command |
| 9 | Har technology ki pull/install command ALAG (Web, SQL, Rust, Brain, Caddy) | Rule 24 mein likha | — |
| 10 | Sirf "AI plans open on ai.anexomail.com" pointer line anexomail.com par na dikhe; baqi AI zikr jaisa tha waisa | **DONE (Web pull 06:16, /health 200)** | Web pull |
| 11 | Business Pro test account `business_pro.test@anexomail.com` login theek + naya Business Pro test account (`bpro.test@anexomail.com`) | **DONE 19 Oct 05:54 (live: dono LOGIN OK) — dobara touch nahi** (`bizpro-login-fix.sh`, E36) | `bizpro-login-fix.sh` (E36 uski andar psql se chalti hai — editor mein paste NAHI; password script poochti hai, store nahi) |
| 12 | Focus: Business + Business Pro, blueprint tarteeb, latest technology, ek bhi point nahi bachna | JARI | — |
| 13 | Final jawab: sirf "kya theek hua" + "jo theek nahi uska mashwara"; ledger IDs / purane loophole dobara nahi; simple Roman Urdu | QAIDA | — |
| 14 | Attachments ki files copy (migration + live inbound dono) — agent ka mashwara: agla kaam yehi (founder ne "Nahi hua" list mein confirm ki, 05:40) | TODO | — |
| 15 | E31, E33 SQL | DONE (founder: "baki sql sab success hai") | — |

## Commands (verbatim, naya sabse upar)

### 21 Oct 2026 07:45 PKT — founder (verbatim): "yeh anexomail ka logo jo tumne A banya hai kya is ka code hai tumharay pass? agar hai yahan chat main dai do main server pe pull ker lun ga. baki tumne repo ko touch nahi kerna hai specific yeh logi ki command daini hai"
**Halat:** READY — logo ka asli code chat mein de diya: `src/components/site/BrandMark.tsx` (SVG "A" mark + wordmark) aur `public/favicon.svg` (tab icon), dono base64 server command ke saath (.bak backup + locked build/restart block). Repo ka koi code file touch NAHI hua; sirf yeh halat entry likhi gayi (Rule 24).

### 20 Oct 2026 20:09 PKT — founder (verbatim): "repo update kero mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo updat kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai. compact chat se pehle update kero. latest technology pe kaam kero sirf"
**Halat:** DONE — `docs/cursor-work/DONE-DO-NOT-REPEAT.md` + AGENTS.md Rule 30. E46 (notices+appeal), E47 (revoke asli session), notify worker, file-safety-check, appeal form READY (pull baqi).

### 20 Oct 2026 20:31 PKT — founder (verbatim, passwords [REDACTED]): "[file-safety-check INSTALL=1: clamd abhi bhi DOWN] ek swal ka jawab do ke tumhay already website open kerne ki permission di hai abhi test accounts ke mere se password email le lo. basic ko 100 bar kiya hai kitbi bar aur kerna hai?? basic.test@anexomail.com password hai [REDACTED] pro.buyer@anexomail.com password hai [REDACTED] business.test@anexomail.com password hai [REDACTED] and last hai business_pro.test@anexomail.com password hai [REDACTED] yeh 10000000000000 bar diya aur kitni baar dun?"
**Halat:** 4 test accounts ke passwords sandbox file `/root/.anexo-test-creds` (chmod 600, repo ke BAHAR, git mein kabhi nahi) — compact ke baad wahan se padho, founder se dobara nahi maangne. File na mile (container reset) to hi ek baar poocho. Live login ke liye browser (Claude in Chrome / desktop) chat mein connected hona chahiye — 20:31 par "extension not connected". ClamAV: install chala par clamd shuru nahi hua; script ab sabab khud print karti hai (status, journal, memory, signatures, port).

### 20 Oct 2026 20:21 PKT — founder (verbatim, pull outputs short): "saray sql sucess hai green hai repo main update ker do. [Rust `MODULES="device export"` build OK, timer install OK (purge + notify), Web pull OK, file-safety-check RED: clamd DOWN] tumhay browser website open live login test accounts with passwords diye thay ab tum 2ghnatay main bhul jao main us ka kya ker sakta hoon. filhaal repo se dekh ke batao humri tarteeb kya hai aur yeh kaam sab green kab hoga 100% live login reach tumharay pass hai excess bhi hai. … sab pull hogaye hai. codes likhne se pehle batao hum kahan kharay hain main rone wala hoon"
**Halat:** SQL E41–E47 + CHECK = GREEN (founder). Rust device+export DONE (build OK, 401 saboot). Timers purge+notify DONE (`{"ok":true,"purged":0,"blocked":0}`, notify claimed=0). Web pull DONE (server==repo, src differ=1: routeTree.gen.ts, normal). **File safety RED: clamd chal nahi raha -> `INSTALL=1 file-safety-check.sh` founder chalaye (ClamAV server par lagana).** Browser: Claude in Chrome / desktop browser is chat mein CONNECTED NAHI (tool "extension not connected") — live login tab hoga jab connect ho; tab tak local real-stack test. Passwords: purani chat ke passwords compact mein chale gaye aur repo mein kabhi nahi likhne (Rule 24/29) — naya test account khud signup flow se bana kar (agla qadam). Tarteeb + ETA founder ko di (DONE-DO-NOT-REPEAT.md "TODO").

### 20 Oct 2026 20:10 PKT — founder (verbatim): "repo update kero mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo updat kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai. compact chat se pehle update kero. latest technology pe kaam kero sirf aur loophole jitne bhi hain un ko root se khatham kero live login ker ke dekho"
**Halat:** `docs/cursor-work/DONE-DO-NOT-REPEAT.md` bana diya (jo ho chuka, dobara nahi) + AGENTS.md Rule 29 mein link. Loophole root se: E46 (email + in-app appeal), E47 (revoke = asli sessions), device purge job, file-safety check, export iframe — sab code+local test DONE; server commands neeche. Live login: khud test account bana kar (agle qadam).

### 20 Oct 2026 19:54 PKT — founder (verbatim): "repo rad kero technology read kero repo ki rules read kero compact chat se pehle repo update kero. sql sab ke sab sucess hai sirf sql E41 ke line 12 pe error tha mainay line 12 delete ker di hai aur us ke baad E41 sql bhi sucess aya hai sab sql supabase sql editor main run kiye aur sucess hai. repo ko saath ke saath update kero compact chat se pehle. baki jo kaam continoue kerte raho jaisa ker rahay ho. yeh jitna kaam tumne kiya hai is k update kero ke kaam ker diya hai. compact chat ka khatra her time rehta hai is liye her command ke baad repo update kero takay claude wahan se continoue karay. repo main dekh ke batao ke abhi kitna kaam hai baki hai kab 100% complete hoga please ker do sab kaam complete hum anexochat pe jaye. founder ka protocol account profile shuru se banana hai jo bana huwa hai website pe codes hai sirf un ko modify kerna hai founder ke accordingly. [pull output: integrity-purge install OK `purged 0`] her technology ki command daini hai aur HMAC SHA 256 bhi use hoga aur us ke saath hoga use SHA 256 yeh tum decide kero gay ke dono ek saath kaise use hogay yeh repo main likho tareeka aur follow kero. mujhe her technology ki command pull diya kero. 100000bar bola hai ke technology ko GOD ke baad maan lo aur us ko strict follow kero. [Loophole ledger paste] tu wohi mistake ker raha hai jo pehle tha tumhay bola tha ke mujhe loophole khatham ker ke do aur jab green ho jaye tab bolo lekin tum mujhe bolte ho ke loophole baki hai aur agar baki hai phir tumhara kya faida hai live login use kerne ka?? last warning dai raha hoon repo main rule likh lo ke mujhe loophole sab green chaiye hain ek bhi blunder nahi bachay. sab coomands pull hai sb sql green hai. next tarteeb se kaam kero"
**Halat:** Rule 29 likha (AGENTS.md). SQL E41 line 12 (`\set ON_ERROR_STOP` = psql command) repo se hata di (founder ne server par pehle hi hata kar chalaya: E41-E45 GREEN founder ke mutabiq; **par timer ka output `{"ok": true, "purged": 0}` E45 ke `blocked` key ke baghair = shayad E45 abhi nahi chala — `docs/cursor-work/sql/E45_check.sql` se dekhna**). Pulls DONE: Rust `export` (build OK, 11 tests, proc+route 401 = zinda), Brain `integrity` guard (health 200), timer install (exit 0). HASHING policy (`docs/cursor-work/HASHING.md`) likhi. Loopholes ek ek karke band (har qadam par repo + push).

### 20 Oct 2026 19:02 PKT — founder: "Baqi (green nahi): 1. Attachments bhejna 2. Version history 3. Retention window sirf 0 4. Hamza lifetime-free par Billing £2850/month 5. Business Pro mobile 6. Kuch RPC Rust mein nahi ... yeh fix kero pull ki command do. tum mujhe gusa dai rahay ho mainay bola bhi tha family account aur test account main farq hai test account woh hai jo real user ko nazar ata hai family account special hai lekin in ko treatment same real buyer wali daini hai ... test accounts real buyer wala hai lekin family account abhi us tarah update nahi huwa hai jaise test account real buyer ki tarah hai yeh kerna baki hai. mere father wla tab karay gay jab basic, pro, bussinss aur business pro green hoga kuch bhi mix nahi hoga ... passkeys aur password dono rakho. meri taraf se done hai ... in main se jaun sa zedia advance aur zedia zabardast ho woh implement kero repo main sab likho ... in ko blueprint number dai do. abhi jo kam baki hai tarteeb ka woh kero. humza ka business pro ko latest technology pe transfer kero ... mobile aur tablet hamesha saath dekha kero yeh rule hai koi bhi package hai mobile tablet aur computer lazmi hai"
**Halat:** (2) version history title + (3) retention + (4) lifetime label = READY (60bbe0f, E40 SQL dobara chalana). (5) Business Pro 820+390 live audit = DONE (koi overflow nahi). (1) attachments = G38 TODO. (6) Rust RPC = G40 TODO. Security wade = G33-G37 (`docs/anexomail-blueprint.md` 20 Oct 19:02, `docs/cursor-work/PROMISES.md`). Humza real-buyer transfer = G39 (jari).

### 20 Oct 2026 18:50 PKT — founder: "SHA-256 yeh technology kab aur kahan use hogi aur user ko passkeys lazmi hai lekin yeh kaise hoga ... Policy (Account integrity & privacy) ... footer pe jitna bhi likha hai us ko real implement kerna hai. mashwara do"
**Halat:** mashwara diya (password + passkey dono; device hash HMAC-SHA256). Founder ne 19:02 par manzoor kiya -> G33-G37.

### 20 Oct 2026 18:34 PKT — founder: Supabase SQL ki tasveer (family/entitlement/trial = business_pro) + "humzasherwani@anexomail.com [password chat mein diya, yahan nahi likha] ... yeh real user mera brother hai sirf farq hai ke yeh lifetime free user hai baki is ka sab kuch real buyer wala hoga package ... tumhara ultimate goal yeh hai ke sab ke packages main same cheeze aur same changes hone chaiye hain. mere father ka account bhi hai jo ke personal pro+ pe hai woh next pe hoga mujhe yeh batao ke bussiness ka pro package 100% green done hai. tumhay bola bhi hai ke real live login tum khud kero aur yeh rule hai ke tum live login her waqat rakho gay"
- Halat: Business Pro live audit **DONE**; verdict: **100% green NAHI** — upar `BASIC-AUDIT-DONE.md` "BUSINESS PRO live audit" (attachments bhejna sabse bada baqi). Rule: har change sab 4 plans par live login se test (Basic basic.test, Business Pro Hamza; Business/Personal Pro+ ke login chahiye).

### 20 Oct 2026 10:53 PKT — founder: "collapse chalta hai lekin drag nahi aur yeh kya baqwas hai meri family ke accounts profle un ke packages ke mutabiq update kyon nahi huhi hai? yeh universal website hai ke jab bhi koi bhi update hogi woh un ke packages ke accordingly mile gi mere bhai ka account hai humzasherwani@anexomail.com business pro hai meri family hai"
- Halat: drag **READY** (batch 10, asli sabab mila: native dragstart). Leo Actions Business/BP ko wapas (meri galti thi). **Hamza (business_pro) profile/package mismatch: jaanch jari** — session `family_accounts` se plan padhta hai (server/routes/auth.ts); live DB access nahi, isliye Hamza ke login/screenshot ya DB output chahiye. Qaida: har naya feature plan-wise sab 4 plans par test (sirf Basic nahi).

### 20 Oct 2026 10:35 PKT — founder: "ai settings gahyab hai lekin yeh drag nahi chalta hai. yeh side bar dekho is pe jab cursor jaye toh drag hona chaiye hain lekin nahi hota hai." (+ pull output: build OK, differ=1 routeTree.gen.ts sirf, AI tab gaya)
- Halat: **READY** (batch 9, HScroll). Drag code live tha (build mein 2 files), phir bhi na chale = mere test-browser mein reproduce nahi hua. Isliye pakka hal: ‹ › arrow buttons + grab cursor, drag bhi. Rule 28 ke mutabiq manifest verify.

### 20 Oct 2026 10:32 PKT — founder: "Sabaq. Ab main koi bhi file badalne ya revert karne ke baad saari manifest entries verify karunga. Tab hi push karunga, taake server par aise adha deploy dobara na ho. yeh repo main likho as a rule strict"
- Halat: **DONE**. `AGENTS.md` RULE 28 (strict) + `docs/cursor-work/server/manifest-verify.py` (har entry ka sha check, exit 1 = push mat karo).

### 20 Oct 2026 10:30 PKT — founder: "na drag chalta hai aur na AI settings tamamam packages se remove hota hai is ko chat main fix kero" (+ server pull output)
- Wajah (server output se): pull ka **build FAIL** hua (`Missing export`) => purani files wapas. Meri galti: batch 8 mein `app.mail.$folder.tsx` revert ki par DEPLOY-MANIFEST ka sha update nahi kiya => server ne file chhodi (SHA MISMATCH) aur purani file nayi `use-drag-scroll.ts` se `useDragScroll` mangti thi (ab hai nahi).
- Fix: manifest-sync + **saari 120 manifest entries ka sha repo se verify (0 stale)**. Qaida: koi bhi file revert/badalne ke baad manifest-sync, phir sab entries verify, phir push.
- Founder ko wahi pull dobara; "server==repo differ=0" aur "build: OK" aana chahiye.

### 20 Oct 2026 10:06 PKT — founder: "sab green hai, yeh drag right side pe jahan pe mail open hoti hain waha pe nahi ho raha hai. aur basic package main AI settings kyon hai yeh itnay blunder kyon tum live login ke bawajod bhi incompetent ho. fix kero aur login ker ke dekho phir batao"
- Halat: **READY** (batch 8). Drag ab har patti par (thread side bhi); Basic se AI settings + Leo Actions tab hata (AI zero qaida). Live-login (basic.test) local build par test: list + thread ki 6 patti drag OK; settings tabs mein AI nahi; integrations mein Leo Actions nahi.
- Sabaq: naya feature/page likhne se pehle PACKAGE-FEATURE-FORMULA.md ke "kis plan ko kya" gate check karo; AI = sirf ai host.

### 20 Oct 2026 09:52 PKT — founder: (2 tasveerein) "yeh image 1 main drag system banao cursor se drag ho sakay right left takay icons puray nazar aye yeh UI UX fix kero aur yeh second image main settings ki option yahan pe dalo sirf yeh kerna hai aur abhi tak 3D grapichs kahan ana hai yeh tumne nahi batya hai baki sab green hai"
- Halat: **READY** (batch 7, commit 562b6c2). Mail rows par mouse-drag/wheel scroll; profile menu mein Settings. 3D ka naksha `BASIC-AUDIT-DONE.md` mein (abhi bana nahi, founder ke hukm par).

### 20 Oct 2026 09:44 PKT — founder: "compact chat ke baad sab context tum bhul gaye ho gay jo abhi sab kaam kiya hai is ko repo main dalo takay claude read karay ke kya kaam huwa hai aur duplicate nahi phir se ban jaye samjhay! aur batch 4 ki pull command do"
- Halat: **DONE**. `docs/cursor-work/BASIC-AUDIT-DONE.md` (batch 1-6, pull status, baqi kaam, tareeqa) + AGENTS.md Rule 27 + README pointer. Batch 4 (Settings toggles) = sirf Web pull.

### 20 Oct 2026 — agent (CEO): batch 5 + 6 — Integrations + Calendar (READY)
- Batch 5 Integrations: "Connect" buttons hamesha 501 dete the (OAuth Bun mein bana hi nahi). Ab jhoota button nahi; "Copy my mail" /app/import (asli IMAP copy) par le jata hai. (Web)
- Batch 6 Calendar: **live Basic par Calendar ke events kabhi load nahi hote the** — `calendar.events`, `calendar.event`, `calendar.load` na Rust mein the na Bun mein (404, page "not wired" dikhata tha). Ab Rust `cal_glue.rs` mein teeno: range (<=62 din) mein events + guests, clash nishan, team meeting-minutes + overload (cal_core.rs ke pure fn, 22 unit test pass).
- Saboot: unit test + type-check; **live saboot baqi** (Rust engine pull ke baad /app/calendar par event dikhna chahiye).
- Bina test ke baqi: compose/undo-send ka live script selector par ruka (script ka masla, app ka nahi) — agla kaam.

### 20 Oct 2026 09:25 PKT — founder: purana output (dnsauth 08:29, mig-live-test, sw.js) + "yeh sirf read kerna hai ke masla solve hai ke nahi bus."
- Halat: **batch 1 DONE (live saboot 09:3x: sw activated, offline inbox 7 threads, Basic greeting sahi)**. dnsauth DONE. mig FAIL 4 = 08:29 ka purana script (fix 08:38); too_many_sessions = E35 hifazat.

### 20 Oct 2026 — agent (CEO): batch 4 — Settings toggles (READY)
- Masla: server toggle ki value text ("false") bhejta hai; `!"false"` = false => **koi band toggle kabhi ON nahi hota tha** (har settings page). Click ke baad 2–3 second purani halat; doosra click ulta. "Read receipts" toggle kuch nahi karta tha (hum receipt bhejte hi nahi). "Block tracking pixels" ka mail kholne par koi asar nahi tha.
- Hal (Web): `isOn()` + On/Off; foran (optimistic) badalna, fail par wapas; Read receipts = "Never sent" (sach); tracking setting ab mail ki tasveerein control karta hai (default band).
- Saboot: local build + live API — Off->On->Off foran, aakhir mein On wapas.

### 20 Oct 2026 — agent (CEO): batch 3 — Billing daam (READY)
- Masla: Billing par Basic (business account) "£97.00 / month · 25 GB / mailbox". E5 `get_billing_subscription` business ka har na-business plan Business daam deta tha; saalana par mahine ka daam "/ year".
- Hal: **E40 SQL** (wohi function, sirf yeh 2 cheezein; self-test business Basic = £23/5 GB). PG16 mock par 2 dafa PASSED.
- Note (agla, Bun fallback): `/api/billing/subscription` live par `storage_per_mailbox_gb does not exist` deta hai — Rust primary chal raha hai is liye user ko nazar nahi aata.

### 20 Oct 2026 — agent (CEO): Basic audit batch 2 — Security page sach (READY)
- Masla: Security page ki har ginti khaali tables se ("Live sessions 0" jab user login hai; "Kill" kuch nahi maarta tha; "Encryption needs attention" khaali table se; "Rotate keys" sirf ek row likhta tha; ledger kabhi nahi likha jata tha).
- Hal: **E39 SQL** (service_role-only functions: `auth.sessions`, `auth.audit_log_entries`, `device_vault`, sha256 ledger zanjeer) + **Rust `security` module** (`security_core.rs` 4 unit tests + `security_glue.rs`: live TLS handshake 443/993/587/25, cert public roots se check) + **Web** (rotate button hataya; kill switch / disown ka sach; "this device" par Kill nahi).
- Saboot (sandbox): PG16 mock par E39 self-test PASSED + 2 dafa chala (idempotent); engine build OK; kill ke baad us session ka token 401; apna session kill = 409 "use Sign out"; ledger 3 entries zanjeer judi; fake cert = "off" (verification chal rahi hai); 1440/390 koi overflow nahi.
- Tarteeb: SQL E39 -> Rust `MODULES=security` -> Web pull -> live test.

### 20 Oct 2026 09:09 PKT — founder: server ki live jaankari (Rust sockets, WT cert, Caddy validate, ufw) + "yeh save ker lo server ki live information."
- Halat: **DONE (saved)** -> `docs/cursor-work/server/live-facts-2026-10-20.md`.
- Is se 2 masle mile: (1) `3443/udp` ufw mein band; (2) WT cert sirf `anexochat.anexomail.com`, website `anexomail.com:3443` se judti thi. **READY:** `src/lib/wt-url.ts` (Web pull) + `ufw allow 3443/udp` (Server).

### 20 Oct 2026 — agent (CEO): Basic live audit, batch 1 (08:37 hukm par)
- Live Basic login, 22 pages x (1440 + 390). Overflow koi nahi. Gates (Work/CRM/Org) theek.
- **FIX 1 READY — PWA:** `/sw.js` live par hamesha 404 tha (vite-plugin-pwa file `dist/` mein likhta hai, server `.output/public` dikhata hai; precache 0). Har page par console error, mobile offline zero. Ab `public/sw.js` (asli worker): app shell + assets offline, `/rpc /api /auth` kabhi cache nahi. Offline par pichla tasdeeq-shuda session => inbox cached mail ke saath khulta hai (saboot: local build + live API, offline reload = 7 threads). vite.config.ts ko haath NAHI lagaya.
- **FIX 2 READY — privacy:** Sign out par offline mail (IndexedDB) + worker cache saaf nahi hote the. Ab saaf (saboot: sign out ke baad threads 0, session 0).
- **FIX 3 READY — copy:** Basic dashboard "shared inbox, tasks" likhta tha (Pro cheezein). Ab Basic ko sach.
- Note (agla): Security page "Live sessions 0" jab user khud login hai; "Encryption needs attention" khali table se. Calendar/Security/Settings/Integrations `/rpc` 404 => Bun fallback (kaam karta hai; Rust par lana Rule 25 queue).
- Pull: Web `pull.sh` (sirf).

### 20 Oct 2026 08:37 PKT — founder (verbatim, apna hissa)
> "yeh sab tumharay pass website ka excess hai reached hai tumne khud dekhna hai match kerna hai ke kaunsi live website pe nazar nahi ati ya mismatch hai agar kuch bhi masla hai seedha fix kero lekin user pehle complete hoga phir next founder aur anexochat shuru kerna hai. basic ke baad pro hai. Tum CEO hi tum dekho ke kya kami hai aur jo bhi kami hai us ko seedha fiex kero mujhe bus fix ki list do green kero"
- Halat: CHAL RAHA (Basic audit; batch 1 READY upar).

### 20 Oct 2026 03:02 PKT — founder: test accounts diye (passwords REDACTED) + "tarteeb se points repo se padh kar likho" + "har 10 second update"
Founder ne chat mein 4 test accounts ke passwords diye: `business_pro.test@anexomail.com` aur `bpro.test@anexomail.com` (dono ka ek hi password), `basic.test@anexomail.com`, `pro.buyer@anexomail.com` — **passwords [REDACTED: repo mein KABHI nahi, Rule 17/24]**. Agent inhe sirf us session mein, ek command ke environment variable mein, login-test ke liye use karta hai; kisi file/repo/memory mein nahi. (Naye chat mein founder dobara de ya server par root-only file `/etc/anexomail/test-accounts.env` (chmod 600) mein rakhe — repo mein nahi.)
Founder ke alfaaz: "yeh sab tumhay yaad hona chaiye hai. baki tarteeb se tumne jo points hain woh repo main founder ka ja ke read kero aur exactly codes waha se dekh ke likho; compact chat ke anay se pehle yeh her 10 seconds baad update kerna hai takay compact chat ho bhi jaye claude context nahi bhulay; aur yeh bhi repo main likho: sw.js wala asli masla (har page par script 404; `src/lib/pwa.ts` `/sw.js` register karta hai par `public/sw.js` nahi; PWA offline kaam nahi; manifest theek; TECH-MAP ka "LIVE" sach nahi tha)."
Agent: sw.js finding pehle se repo mein (5fce7bf) + ab TECH-MAP ki PWA row sach ki. "Har 10 second" = agent har natije/qadam ke baad usi turn mein is file + memory file update karta hai (Rule 18/24); agent ghadi par apne aap 10 second ka timer nahi chala sakta.

### 20 Oct 2026 08:29 PKT — founder ne server ka `git status` bheja (attachment)
Haal: server git HEAD origin/main se **143 commit peeche**; ~80 tracked "modified" + ~110 untracked — kyunki `pull.sh` files manifest se seedha lagata hai, git HEAD nahi badhata (code repo jaisa hi: same=459). **Khatra mila:** `/opt/anexomail-web/.env` (secrets) untracked aur `.gitignore` mein nahi tha — koi `git add -A` + push karta to secrets GitHub par. Theek: `.gitignore` mein `.env`, `.env.*`, `__pycache__/`. `server-git-sync.sh` (DEKHNA default; APPLY=1): har badli/untracked file ko origin/main se milata hai — sirf `bun.lock` + `src/routeTree.gen.ts` ka farq allowed; koi aur farq => ruk jata hai. APPLY: poora tar backup -> `git reset --hard origin/main` -> do allowed files wapas; untracked (.env) ko haath nahi; build/restart nahi. Sandbox sim (143 peeche): DEKHNA SAB SAME, ek file badal kar => ruka, APPLY => peeche 0, .env bacha + ignored.

### 20 Oct 2026 08:18 PKT — founder (verbatim, apna hissa)
"( yeh list mainay read ki hai yeh HAAN hai) aur mainay repo read kiya hai anexomail ka blueprint abhi tak green nahi hai? kya waja hai? … yeh masla solve kero aur green kero aur pura repo read kero aur green kero bari bari. ek ek line repo ki read kero. aur E38 green hai pull sab theek hai … aur UI UX sahi hai." + founder ka analysis/matrix + 4-hissa tarteeb: "(1) The Core Controls: app.domains.tsx aur Rust backend mein D2 + D3 … (2) The Inbound Engine: R1a mein catch-all + D1 … (3) The Security Shield: Domain Health Guard cron + DMARC XML decoder … (4) Registrar Integration: Domain Connect template … yeh repo main update aur implment kero latest technology aur kaun si technology kahan aye gi wo dekh lena"
Halat: Domains list (8 items) **founder HAAN**. Mail reading UI: founder "UI UX sahi hai" (DONE). E38 DONE. Pull OK.
**Blueprint green kyun nahi (ginti 20 Oct):** DONE 48 + GREEN 21; READY 87 (code repo/server par hai, magar founder/agent ka live saboot nahi likha); TODO 63; PLANNED 6. Wajah: (a) READY ko DONE banane ke liye live check chahiye tha — ab agent khud test accounts se live login karke saboot likh sakta hai; (b) TODO mein bade kaam (attachments, mail.send Rust, CRM/People/Calendar Rust, Chat) + founder-decision items. **Tarteeb:** founder ki 4-hissa Domains list (1 se) + har chakkar mein READY items ka live saboot (agent login) -> DONE.
**Hissa 1a — D2 READY:** Rust `dnsauth` module (std DNS wire: EDNS0, TXT tukde jodna, MX/NS/A, compression; authoritative nameservers ko RD=0; TC => TCP; public DoH sirf jaankari + fallback). Mock DNS (resolver + authoritative UDP/TCP) par: kuch nahi -> 0/5, TXT+MX -> 2/5, sab -> ready (DKIM TCP se), har jawab ~0.3s; nameserver band -> public raasta 2.5s. UI: har 3s, "Checking directly at your DNS host (ns1…)". 6 core tests.

### 20 Oct 2026 07:54 PKT — founder (verbatim, apna hissa; screenshot: mail khuli + neeche compose khula)
"yeh simple si baat hai ke jab mail pe click karay sirf mail open ho jaye aur compose open nahi ho jaye. aur yeh jaise gmail pe hota hai zoho pe hota hai yeh basic mistakes hai jo fix kerni hai aur mail read ker li toh cross X ka ata hai ya minimize ho jaye ga aur mail jab open hoti hai toh reply ya forward ya jo package ke hisab se aye ga features added jo hogay lekin basic email kasie working kerti hai yeh tumne fix kerna hai tum CEO ho aur UI UX kaisa hoga tumne design banana hai user ko best experience daina hai. yeh masla her package ka hai is ko fix kero." + E38/device/pull/mig outputs + Domains par 3 founder suggestions (blueprint mein as-is) + "Zoho se peeche kaise? CEO tamasha dekh raha hai?" + "sara repo read kero".
Output: **E38 DONE** (4/4 triggers, self-test PASSED, **62** threads ki ginti theek). device: pehle se laga hua (live 401 = Rust pakad raha). Web pull OK (same=458). mig-live-test GREEN.
Kiya (READY): mail kholne par **sirf mail**; neeche **Reply · Reply all · Forward** (r/a/f); dabane par hi composer, X se band; reply sahi bande ko (aakhri mail meri ho to us ko jis ko bheji), Reply all = poori guftagu, Forward = "Fwd:" + asli mail ka hissa. **Security (bada):** bahar ki HTML mail seedha page mein lagti thi (script/onerror app ke andar chal kar login token utha sakta tha) -> ab band dabba (sandboxed iframe, koi script nahi), tracking images default band + "Show images". Phone par subject + actions do line mein. Waqt Gmail jaisa ("Oct 20, 6:57 AM (1 hour ago)"). Harness 1440/390 + reply-all dekha.
Domains: founder ki D1/D2/D3 blueprint mein as-is + CEO raaye (kya asli banega, kahan sach: purane provider ka network "filter" nahi — IMAP se 0-loss; registrar ka hubahu clone nahi — impersonation) + 8 feature ki list + tarteeb.

### 20 Oct 2026 07:00 PKT — founder: R1a output + hukm (verbatim, apna hissa)
"ek masla hai ke mail kholne ke baad xcross ka button nahi hai? yeh masa solve kero aur kisi bhi package main sent email folder main kuch nahi show hota hai yeh bug theek kero sab packages ke andar aur yeh sab folder spam ho ya koi bhi folder ho yeh ana chaiye hai kya aya hai. aur zoho ki tarah user kaise business account yani forexample abc@company.com banye ga aur woh wasiye toh codes main auto website pehchan leta hai kiya hai tum is ko touch nahi kerna hai bus nazar maar lo. break nahi kerna hai"
Output: **R1a DONE (live)** — 18 tests, vmail ke 2 test (quarantine + basic.test text=true), Postfix argv Rust, sendmail end-to-end DB=1 `status=sent (delivered via anexopipe ... anexomail-deliver: OK)`. mig-live-test GREEN.
Agent ne live dekha (basic.test): **asal jad — mail kholne par andar KUCH nahi** (Bun `/api/mail/thread/:id` har thread par `messages: []`; Rust `mail.thread` sahi deta hai, magar website Bun ko seedha bulati thi). Isi liye "Sent mein kuch nahi dikhta" (list aati hai, kholo to khaali). Theek: website thread Rust se (Bun fallback). Desktop par X + Esc. Basic se asli mail bheji (compose ka raasta) -> 10 sec mein Sent + Inbox dono mein. Thread par "2" (1 mail) -> E38 trigger. Domains (abc@company.com) sirf dekha, chheda nahi.

### 20 Oct 2026 06:50 PKT — founder: "yeh kaam kitna huwa hai jo nahi huwa hai us ko solve kero green kero wire kero working kero. dekh ke batao"
Agent ne basic.test se live dekha (06:55):
- **1 privacy leak — GREEN live:** inbox mein root/cron 0 (E37).
- **2 locale 404 — GREEN live:** /app aur inbox par locale ka koi 404 nahi.
- **Naya mila (6 ka hissa):** har page par `403 /rpc/chat.device.vault` — device record (privacy page ka "5 signals seal") chat gate ke peeche tha => **Basic ka device record kabhi nahi bana** + "3 accounts/24h" check Basic ko dekhta hi nahi tha. Theek: Rust module `device` (har plan; fingerprint keys hamesha nikalti hain; mock par 7/7). READY.
- **3 Import mail — READY:** `/app/import` (har plan) + Mail rail "Import old mail" + Inbox card. Live probe mein mila: `mail.addresses.list` login pata alag deta hai => Basic ko "No mailbox to copy into" dikhta; ab login pata pehla nishana (E35 apna email qubool karta hai). Harness 1440/820/390 saaf.
- **R1a (aane wali mail Rust) — READY** (pichla jawab).
- Baqi: 4 attachments (E38), 5 Terms, 6 baqi wade (72h export, final warning), 7 PWA, 8 send/meeting/contact test.

### 20 Oct 2026 — agent: R1a READY (aane wali mail ka pipe Rust par)
- `server/rust/deliver_bin.rs` -> live crate mein `src/bin/anexomail-deliver.rs` (doosra binary; engine :3200 ko haath nahi). MIME = `mig_mime.rs` (Import mail wala tested reader). Payload ki keys bilkul Bun wali + `attachments` (naam/size, E38 ke liye), `mime_lossy`, `body_truncated`, `parser`.
- **Sandbox differential (Bun vs Rust, 6 mails):** purane contract ki har key same; farq sirf jahan **Bun galat tha**: (1) attachment wali mail (mixed > alternative) ka **text Bun mein KHALI** (customer ko khali mail dikhti thi), (2) `=?UTF-8?…?=` subject/naam kachcha, (3) ISO-8859-1 mail ka text "Sch�ne" + raw_sha256/raw_size galat (bytes ki jagah string se). Supabase 500 / band / env nahi => exit 75 (queue, mail nahi khoti). 18 unit tests pass.
- Script `rust-deliver-install.sh`: build + tests -> vmail ban kar 2 asli test (anjaan pata -> quarantine, basic.test -> inbox) **Postfix chhoone se pehle** -> master.cf backup + argv + `postfix check` + reload -> sendmail end-to-end 60s -> fail par Bun wapas.

### 20 Oct 2026 06:41 PKT — founder (verbatim)
"e37 sql sucess hai tum jab tak repo ko pehle read nahi kero gay kaam tabha ho jaye ga. Mail	server/mail/*	aap ki “haan” + script meri haan hai aur mujhe rust,trpc, webtransport aysnc, tokio khuda ke liye kahan ana hai kal bhi batya tha phir se same mistake kerte ho. pura repo read kero phir codes likho"
Halat: **E37 DONE (live).** Agent ne memory file (section 1-2: "Backend hamesha Rust — tRPC-style /rpc, QUIC, WebTransport, async Tokio; mail bhi Rust par"), blueprint R0-R6, TECH-MAP, AGENTS dobara padhe. Galti: TECH-MAP mein Mail ko sirf "Postfix/Dovecot, chheda nahi jata" likha — jab ke founder ka hukm (17 Oct) hai mail ka app-hissa Rust par. Theek: Mail row = Rust :3200 (tRPC-style /rpc + Tokio + WebTransport push), Postfix/Dovecot sirf transport. **Mail par founder ki "haan" mil chuki.** Agla code: **R1a — aane wali mail ka pipe Bun se Rust** (`anexomail-deliver`, mig_mime se MIME, Rust mein pane wale ki pehchan, attachments ke liye tayyar), phir R1 (`mail.send`, `org.mailboxes.*`), R5 (event-driven push).

### 20 Oct 2026 06:36 PKT — founder (verbatim)
"Edge: Caddy HTTPS + HTTP/3 · Frontend: React 19.2 TanStack Start v1 Router 1.17.0 Vite 8.2 Tailwind v4.2 Radix + shadcn/ui Framer Motion GSAP Three.js aur jitne bhi #D cinematic graphics hai woh mere server load uthay ga tum bus is ko update rakho aur yeh batao kaun si technology kahan use hoti hai yeh update hamesha rakho. tumne technology kahan aye gi waha pe tumne codes likhna hai aur kaun si technology ki pull hai woh tumne rule break kiye hain"
Halat: TECH-MAP section 0 frontend rows founder ki list ke mutabiq; 3D ab sirf landing nahi — jahan behtar lage (server load founder ka faisla). Naya **0b** (har technology ki pull ka ek hi raasta) + **0c** (aaj ka har kaam kis technology mein — log). Rule break jo hua: TECH-MAP har kaam ke saath update nahi kiya; SQL ko "Editor mein paste" kaha jab ke pull ka raasta psql/server tha; ek "Fix" heading ke neeche do technology ke blocks. Ab se har jawab: har block par technology ka label, aur kaam ke saath TECH-MAP 0c update.

### 20 Oct 2026 06:29 PKT — founder: locale output + E37 fail + hukm (verbatim, apna hissa)
"e 37 sqp failed n reason Error: Failed to run sql query: ERROR: 42P01: relation "e37_moved" does not exist. website user ke liye mobile tablet pe bhi banani hai saath ke saath us ka design bana huwa hai us ko hi continoue kerna hai yeh bhi website ka rule hai simountasesloy … 7. Mobile par offline (PWA) nahi chalta. toh is ko chalao duniya ke advance features working wire kero."
Output: **N3 locale DONE (live)** — unit tests 5/5 (rustc 1.99.1, 2024), build OK, bundle 200 + nakli login 401, "browser ke 404 band". Web pull OK.
**E37 fail ki wajah:** Supabase SQL Editor har statement alag chalata hai — `on commit drop` wali temp table agle statement tak nahi bachi. Theek (wohi file): temp table hata kar aakhri qadam EK statement (data-modifying CTE). Local: per-statement chalaya (editor jaisa) -> PASSED; dobara -> 0 move (idempotent); pichli adhoori run ke baad bhi safe.
**Rule (founder, dobara):** har screen mobile + tablet par saath saath, maujooda design ko hi aage badhana (Rule 19). **PWA (N4)** offline asli chalana — Basic list mein.
**Basic list (CEO):** 1 privacy leak E37 · 2 locale DONE · 3 Import mail customer tak · 4 attachments (E38) · 5 Terms page · 6 privacy wade code se · 7 PWA offline · 8 Basic user ki tarah send/meeting/contact test.

### 20 Oct 2026 06:07 PKT — founder: outputs + hukm (verbatim, apna hissa)
"( agar yeh fix nahi huwa hai toh is ko fix green ker ke mujhe bolna us ke elwa kuch nahi suno ga) … (MERI HAAN HAI TUM BUS WOH KERO JO Anexomail ke liye better hai) … sirf AI ko chod ke baki sab dekh lena aur yeh green kerna hai … main refind offer nahi kerta hoon toh yeh refund ka koi chaker nahi hai. baki Tum CEO ho jo best ho woh kero. aur frontend design cinematic 3D ke jitne bhi hai woh jahan better lagay thora use kerna hai repo main likh lo. static.rust-lang.org yeh bhi callo ker diya hai. jo jo tumhay allow chaiye hain us ki list mujhe send ker daina next seesion main. tarteeb ke mutabiq jo bhi next kaam hai woh kero blueprint bhi dekh lena. codes please advance level pe likho."
Output: **Step 0.4 DONE (live)** — rustc 1.97.1 -> 1.99.1 (sirf /opt/anexomail-rust pinned) + edition 2024; WT frames 12/12, HTTP 13/13 same; mig-live-test GREEN. Founder ne server default bhi `rustup update stable` se 1.99.1 kiya (polar par asar sirf us ke agle build par). Web pull x2 OK (/health 200, same=456). cron-root-mail-fix: **0 files** — `%` wali lines ab maujood nahi (cron errors 12 Oct ke baad band; 54 purani mails DB mein org 16e02f4b…).
**Asal jad mili (founder "haan" se mail path badla):** `mail_ingest` (phase58) anjaan pane (root@, galat spelling, khali handle) ki mail "sabse naye thread wali kisi bhi org" mein daal deti thi — privacy leak. **E37_mail_ingest_no_stray_org.sql** READY: system pate -> resolved@ (ops), anjaan -> `mail_quarantine` (kisi org mein nahi), jaana pata -> purana raasta; purane root@ threads -> resolved@ org. Local PG16 par bug ka asli repro (root@ + typo customer org mein) -> E37 ke baad root@ ops mein, naye anjaan quarantine; self-test PASSED; dobara chalana safe.
**Footer:** AI ke ilawa sab GREEN (17/17 links asli page, 3 mailto). Refund: founder refund nahi deta — refund page nahi chahiye. Terms of Service: CEO faisla — agla, asli product facts se (no-refund saaf likha), founder dekh le.
**Design rule (founder):** cinematic 3D (Three.js/GSAP/Framer — Constitution mein maujood) jahan behtar lage *thora* — AGENTS Rule 26.
**Allow-list (agle session ke liye founder ko list bhejni):** static.rust-lang.org (diya), index.crates.io + static.crates.io (chal rahe), registry.npmjs.org, github.com, anexomail.com (+ subdomains), blog.rust-lang.org.
**Attachments ab E39** (E37 = mail leak, E38 = thread ginti).

### 20 Oct 2026 — agent (CEO): Basic live login + footer audit + locale + cron (05:37 hukm par kaam)
- **Basic live login (basic.test, 1440 + 390):** dashboard, mail, calendar, people, work, domains, billing sab khule; koi horizontal scroll nahi; tiles mobile par saaf (N6: 1440/390 par alignment theek dikha). Admin pages Basic ko saaf "not on this package" dikhati hain.
- **Mila + theek kiya:** (a) har page par `/rpc/locale.pref` + `locale.bundle` ke 404 (N3) -> Rust module `locale_core.rs` + `locale_glue.rs` (bundle/registry public, pref/pref.set login) — mock Supabase par 12/12 sahi jawab; installer mein `locale` + live probe. (b) installer ke restore mein "Text file busy" wala cp -> cp+mv. (c) **Basic ke inbox mein root@anexomail.com ke 50+ "Cron … /bin/sh: Syntax error" mail**: cron lines mein bina "\" ke "%" (cron isay naya line samajhta hai) => woh jobs KABHI chali hi nahi + root ki mail customer mailbox mein ja rahi. `cron-root-mail-fix.sh`: % theek (backup + `sh -n` check), root mail ka raasta sirf padhta hai (mail path founder "haan" ke baghair nahi).
- **Footer audit (live):** 20 items — 17 links 200 + asli page, 3 mailto. AI ke 3 links "not open yet" (Rule 23, jaise thay). **Terms of Service / Refund policy page live par nahi** (/terms, /refund 404) — legal text founder ka; agent khud nahi likhega.
- **Policy claims audit (TODO, agla):** /privacy ke wade (5 coarse signals, 3 accounts/24h review, final warning, 72h export phir delete) ko code se milana.
- **rustc 1.99.1 sandbox:** proxy ne `static.rust-lang.org` mana kiya (allow-list). Hal: founder claude.ai Settings > Capabilities mein `static.rust-lang.org` allow kare; tab tak build server par hi (script safe, restore-on-fail).

### 20 Oct 2026 05:37 PKT — founder (verbatim, password REDACTED)
"basic.test@anexomail.com password hai [REDACTED]    aur landing page pe mainay policy banye hain un ko aur footer pe jitna bhi hai us ko real codes main wire kerna hai aur 1.99.1 ka build: ye server par hi hoga, kyunki sandbox se Rust ka download server band hai toh is ka solution nikalo tum soch ke deep thinking ker yeh masla solve kero yeh website ke CEO tum ho jo ke repo main bhi yehi mainay tumhay batya hai tum CEO walay zone main 100% aao aur user ka mindset level pe poonch jao aur competitor se jo better ker saktay hain woh codes main transform kero takay woh website pe live nazar aye ke hum kyon better hai."
Halat: (1) Basic live login + user-testing shuru. (2) Landing ki policies + footer ke saare links asli wire — TODO (audit pehle). (3) rustc 1.99.1 sandbox download ka hal — TODO. (4) "hum kyon better hain" live website par dikhe — Basic review ke baad.

### 20 Oct 2026 — agent: Step 0.4 rustc 1.99.1 + edition 2024 READY
- Latest stable verify: **Rust 1.99.1 (15 Oct 2026)**, blog.rust-lang.org. Server abhi 1.97.x.
- Sandbox (poora live-jaisa code): `cargo fix --edition` -> sirf 1 line (`err() -> impl IntoResponse + use<>`); edition 2024 build OK; core unit tests 2024 par 113 pass; WebTransport native 12 + Chromium 6 + HTTP 26: 2021 vs 2024 sab same; panic 0. Ek drop-order note (mig_glue `dial()` error raaste) — asar nahi.
- Sandbox se rustup ka server (static.rust-lang.org) band hai, is liye 1.99.1 ka build server par: script `rust-toolchain.toml` sirf `/opt/anexomail-rust` mein pin karti hai (server default rustc + polar :3400 nahi badalte). Sim: fail -> poora restore (toolchain file bhi), success, dobara -> kuch nahi.
- `rust-engine-install.sh` ab live Cargo.toml ki edition + pinned compiler se unit tests chalata hai.

### 20 Oct 2026 05:03 PKT — founder: N7 + pull + live test + business.test output; hukm (verbatim, apna hissa)
"rule yeh hai ke fix command pull kerwao phir Web pull (latest GitHub):phir live test command yeh pattern rakho aur restart kerwao pm2 load kerwao next time ke liye. tarteeb se next kaam shuru kero jo green hai woh green ker do. aur tum live login kero yeh bhul nahi kero."
Output: **N7 DONE (live)** — error frame 12/12, handshake same, HTTP 13/13 same. Web pull OK (build OK, /health 200, src same=456 differ=1 [routeTree.gen.ts — build khud likhta hai]). `mig-live-test.sh` **GREEN**. **N5 DONE** — `business.test@anexomail.com` LOGIN OK (plan business, GoTrue 200, /api/auth/login 200, Rust plan=business).
**PATTERN (LOCKED, har kaam par):** 1) fix/install command (us technology ka, pm2 restart andar) -> 2) Web pull `pull.sh` (latest GitHub, pm2 restart + save) -> 3) live test (`mig-live-test.sh`). **Live login bhoolna nahi** (Rule 26 user-testing).

### 20 Oct 2026 04:37 PKT — founder: wtransport output + hukm (verbatim, apna hissa)
"mera sawal hai ke jitna bhi latest github pull kerwaya hamesha kiya kero. aur tum hamesha naya masla le atay ho jab ke ek CEO ka kaam hai ke chairman/founder ko bina bantye masla solve ker ke bolay ke yeh green hai masla solve hai. jab tumharay pass website live reached hai phir bhi tum masla solve nahi kerte ho."
Output: **wtransport 0.1.14 -> 0.7.2 OK** (build 1m54s; WebTransport handshake 4/4 pehle jaisa; HTTP 13/13 same; health 200; UDP 3443 yes; quinn 0.11.11 / rustls 0.23.43 akele). **Step 0.3 DONE (live).**
**Standing hukm:** (1) har jawab ke saath latest GitHub pull command (Web `pull.sh`) hamesha. (2) Mila hua masla founder ko "naya masla" bana kar nahi dena — khud theek karo, saboot ke saath "green" batao. Isi liye N7 (WebTransport error frame kho jana) abhi theek kiya ja raha hai.

### 20 Oct 2026 — agent: Step 0.3 wtransport 0.1.14 -> 0.7.2 READY (sandbox saboot)
- Repo ka poora Rust code (installer jaisa patch) wtransport 0.7.2 par build: sirf 1 line badli (`.with_identity(&identity)` -> `.with_identity(identity)`). Lock se purane quinn 0.10 / rustls 0.21 / ring 0.16 ke duplicate khatam (ab ek hi quinn 0.11.12 + rustls 0.23.46, sirf `ring` provider).
- Chromium 141 ka asli `new WebTransport()` (serverCertificateHashes) purane aur naye dono server par ~10 ms mein session + stream + hello tak. Native client (`wtcheck`, repo mein) 3 round x 4 case: stages same. HTTP 26/26 same. Panic 0.
- Script `wtransport-upgrade.sh` + `wt7_patch.py` + `wtcheck/`: live par PEHLE asli WebTransport handshake + 13 HTTP, BAAD wohi; farq => purani binary + src wapas. Sandbox simulation: force-fail -> restore OK, success OK, dobara chalao -> kuch nahi badla.
- Sandbox ki had: IPv6 nahi tha, is liye test copies 127.0.0.1 par bind hui; live par `with_bind_default` (dual-stack) wahi rehta hai aur script asli UDP 3443 handshake check karti hai.

### 20 Oct 2026 04:03 PKT — founder (verbatim, apna hissa)
"Business tab jab `business.test` account ban jaye nahi balay bana lo takay hum tarteeb yeh ho jaye gi basic, pro bussiness aur bussniness pro. … bhai repo main jo baatein likhi hai us ke mutabiq duniya ke advance level software enigering se bhi zedia advance codes likho phir khudi un ko review kero aur jab tak tum 100% sattisfied nahi ho jao tab tak nahi rukna hai. saath ke saath pull comand dai saaktay ho toh daina. next shuru kero"
Halat: package tarteeb ab **Basic -> Pro -> Business -> Business Pro**. N5 (`business.test`) — command diya (`PLAN=business ACCT=… bizpro-login-fix.sh`, password founder khud silent prompt mein), output baqi. **0.3 wtransport** sandbox mein shuru.

### 20 Oct 2026 03:59 PKT — founder: axum + live test output; naya standing hukm (verbatim)
"tumne live website user ki tarah use kerni hai aur CEO ki tarah montor kerni hai note it. tumharay pass basic, pro aur business pro hai. one by one dekho jab sab perfect ho jaye phir next package pe jana hai. awam ko honesty sale kerni hai imamndari aur duniya ke advance working wire features send kerna hai."
Output: **axum 0.7.9 -> 0.8.9 OK** (build 2m01s; PEHLE/BAAD 13/13 same; health 200; UDP 3443 yes). `mig-live-test.sh` **GREEN** (upgrade se pehle bhi, baad bhi).
**Step 0.2 DONE (live).** Agla: **0.3 wtransport 0.1.14 -> 0.7.x (+quinn/rustls)** — pehle sandbox scratch + parallel staging.
**Standing hukm (Rule 26 ke saath):** live website user ki tarah chalao, CEO ki tarah monitor karo. Packages ek ek: **Basic -> Pro -> Business -> Business Pro** (founder 04:03); ek package "perfect" hone ke baad agla. Sirf imaandaar dawa — jo feature asli wire aur kaam karta ho wahi bikay; jhoota "live" nahi.

### 20 Oct 2026 03:55 PKT — founder (verbatim)
"Kya Vite 8.2 aur Tailwind 4.2 ke naye styles dashboard tiles par bina kisi font alignment error ke clean display ho rahe hain? main darr gaya tha ke tumne itna lamba command run kiya aur socha ke tum context bhul gaye ho aur woh jo shaam wali baat hai us ko khatham ker do kyun ke woh shaam ajj hai aur hum already tarteeb se kaam ker rahay hain. tum please rules ko strctly follow kero. tarteeb follow kero. mainay yumhay output send kerta hoon aur mujhe yeh batao ke next tarteeb kaun si next hai aur kya kaam kerna baki hai?"
Halat: "shaam ko" shart hata di. Dashboard tiles ka sawal = **NOTE N6** (aaj check nahi hua; apni baari par 390/820/1366/1440 screenshot). Founder ka axum output baqi.

### 20 Oct 2026 03:28 PKT — founder: tokio + live test output; "bar bar bpro.test ka password nahi kero … ab jaldi se next pe chalo" (verbatim)
Output: **tokio 1.53.1 -> 1.53.3 OK** (build 1m47s, `/rpc/health` 200, UDP 3443 yes, procs dashboard/migration/team 401 = theek). `mig-live-test.sh` **GREEN** — is baar **bina password** (`OK 1 login (token mil gaya)`) — bina-password raasta chal gaya.
**Step 0.1 DONE (live).** Qaida: founder se test accounts ka password bar bar nahi maangna (script service-key se token banati hai).
**Step 0.2 = axum 0.7.9 -> 0.8.9: READY.** Sandbox mein khud check kiya (founder ko scratch-check chalane ki zaroorat nahi rahi): repo ka poora Rust code installer jaisa patch (cal+people+team+mig + guard + rustls) -> axum 0.7.9 build OK; axum 0.8.9 par 2 badlav: (1) route `/rpc/:proc` -> `/rpc/{proc}` (0.8 mein purana path startup par panic), (2) dispatch body: 0.8 mein `Option<Json>` galat Content-Type/kharab JSON par request reject karta (0.7 chupke se `{}`) — `rpc_json_body` se 0.7 wala bartao jaisa ka taisa. Differential: purani vs nayi binary ko 26 ek jaisi requests -> **26/26 same** (status + body). Script `axum-upgrade.sh` + `axum8_patch.py` (anchor, idempotent): sandbox simulation mein success, force-fail -> poora restore, aur dobara chalao -> kuch nahi badla, teeno test. Saath mein mila masla theek: chalti binary par `cp` = "Text file busy" -> restore toot sakta tha; ab `cp` + `mv -f` (ye `rust-crate-upgrade.sh` mein bhi theek). Founder chalaye: Rust block (`axum-upgrade.sh`), phir `mig-live-test.sh` (bina password).

### 20 Oct 2026 03:18 PKT — founder: "ab … new day hai jo kaam ki tarteeb hai woh kaam shuru kero. codes advance level likho website tootni nahi chaiye hai … Tum CEO ho aur yeh repo main likho … tarteeb se send kero mujhe pull comand jis ki technology hai us ke hisab se."
-> CEO mindset = AGENTS.md **Rule 26**. Kaam shuru: **Step 0 (version upgrades)**. Versions verify (crates.io, 03:20): tokio 1.54.0/1.53.3, axum 0.8.9, wtransport 0.7.2, quinn 0.11.12, rustls 0.23.46 (TECH-MAP 0a).
**Step 0.1 = tokio 1.53.1 -> 1.53.3** — script `docs/cursor-work/server/rust-crate-upgrade.sh` (sirf Cargo.lock; backup; build fail => sab wapas; health/UDP 3443/procs fail => purani binary wapas). Halat: READY, founder ka output baqi.

### 20 Oct 2026 03:10 PKT — founder (verbatim): "ek waqat main ek package aur us ka ek masla solve kerna hai phir next pe jana hai. jo maslay nazar atay hain un ko repo main likho note kero aur jab un ki bari aye gi phir un ko theek kiya jaye ga."
**QAIDA:** ek waqt = ek package + us ka ek masla. Nazar aane wale masle sirf NOTES mein (neeche), apni baari par theek. (Agent ne Import-mail route badalne ka adhoora kaam wapas le liya — kuch commit nahi hua.)

## 📝 NOTES — live website par nazar aaye masle (apni baari par theek honge; abhi koi kaam nahi)
Live check 20 Oct 03:05 PKT, `bpro.test` (Business Pro) se login, 9 screens x 1440/390: sab load, kisi width par sideways scroll nahi, dashboard/inbox/mobile bottom-nav theek.
- **N1 (Business Pro, G30):** "Import mail" page `/app/admin/migrate` par hai, aur `/app/admin` sirf founder host ke liye hai (`plan-surface.ts showAdmin`) — customer ko "Platform admin is not on this package" dikhta hai. Yani backend LIVE hai par customer page tak nahi pahunch sakta. Hal (baari par): route `/app/import` (har plan) + inbox ka "Moving from Google or Zoho?" card wahan le jaye.
- **N2 (Business / Business Pro, G31):** Members/Teams UI bhi `/app/admin/members`, `/app/admin/teams` par hai — customer ke liye wohi founder-only gate. Customer ka members page `/app/org/members` hai; dekhna hai ke G31 (seat limit, audit chain, work address) wahan dikhta hai ya nahi.
- **N3 (sab packages):** har page par `/rpc/locale.pref` aur `/rpc/locale.bundle` Rust se 404 (Bun fallback chal jata hai, page nahi tootta). Bun->Rust queue mein. → **READY 20 Oct: Rust `locale` module (`MODULES=locale rust-engine-install.sh`).** → **DONE live 20 Oct 06:29.**
- **N4 (sab packages):** `/sw.js` 404 — PWA offline kaam nahi karta (06:44 entry).
- **N5:** Business plan ka test account (`business.test@anexomail.com`) banana baqi — `PLAN=business ACCT=... bizpro-login-fix.sh` (script tayyar, commit d443811). → **DONE 20 Oct 05:03: LOGIN OK (plan business).**
- **N6** (20 Oct 03:55, founder sawal): dashboard tiles par Vite 8.2 / Tailwind 4.2 styles aur font alignment saaf hain ya nahi — aaj verify NAHI hua. Apni baari par live login screenshot 390/820/1366/1440 (Rule 19). → Basic 1440/390 par tiles saaf (20 Oct live login).
- **N7** (20 Oct, wtransport test mein mila — purana masla, upgrade se nahi): WebTransport server error frame (`unauthorized`, `token_required`, `bad_hello`) likh kar turant `return` karta hai -> connection drop -> frame aksar raaste mein kho jata hai. Chromium mein har error case "Connection lost" dikha (code nahi). Asar: token expire ho to browser ko wajah nahi milti, sirf fallback. Ilaaj (apni baari par): error ke baad `send.finish()` + `connection.closed()` ka chhota intezar (timeout ke saath). → **DONE live 20 Oct 05:03 (12/12)** — `wt-n7-fix.sh` + `wt_n7_patch.py` (Chromium 141: pehle 3/6 error frame, ab 6/6; native 20/20; HTTP 26/26 same; sim: fail->restore, success, rerun OK). Repo `server/rust/` mein axum 0.8 + wtransport 0.7 + N7 bhi laga diya (repo == live).

### 20 Oct 2026 03:03 PKT — founder (verbatim; PASSWORD [REDACTED] — repo mein kabhi nahi)
"business_pro.test@anexomail.com aur bpro.test@anexomail.com dono ka password hai same aur woh yeh hai password [REDACTED]. aur basic ka email address hai basic.test@anexomail.com password hai [REDACTED]. pro.buyer@anexomail.com aur password hai [REDACTED]. yeh sab tumhay yaad hona chaiye hai. baki tarteeb se tumne jo points hain woh repo main founder ka ja ke read kero aur exactly codes waha se dekh ke likho. agar compact chat ke anay se pehle yeh her 10 seconds baad update kerna hai takay compact chat ho bhi jaye claude context nahi bhulay aur yeh bhi repo main likho [sw.js 404 wali finding]. sirf business ka test email address generate kerna baki hai aur baki sab ho gaya hai."
**Test accounts (sirf email; password founder chat mein deta hai, repo mein nahi):** `business_pro.test@anexomail.com`, `bpro.test@anexomail.com` (Business Pro, dono ka password same), `basic.test@anexomail.com` (Basic), `pro.buyer@anexomail.com` (Pro). **Baqi: Business plan ka test account (`business.test@anexomail.com`) banana.** Agent ka qaida: ye email list yaad rehti hai; password har naye chat mein founder se maanga jata hai ya script silent prompt se leti hai.
**Update ka qaida (founder):** compact se pehle har chhote qadam ke baad repo update (agent har natije/qadam ke baad usi turn mein push karta hai; "har 10 second" ka timer agent ke paas nahi, isliye har qadam ke baad).
**sw.js 404 finding** upar 06:44 entry mein likhi hui hai (commit 5fce7bf).

### 19 Oct 2026 06:44 PKT — founder ne sandbox ko `anexomail.com` kholne ki ijazat di; agent ne LIVE website khud dekhi (public pages)
Live check (Chromium, 4 pages x 390/820/1366/1440): `/`, `/plans`, `/auth`, `/get-started` — sab HTTP 200, **kisi width par horizontal overflow nahi**, h1 sahi, "AI plans open on ai.anexomail.com" **nazar nahi aati**. Mobile (390) landing + sign-in theek dikhte hain (screenshots agent ke scratchpad mein).
**Finding (naya kaam nahi — sirf record, queue ke baad):** har page par console error "bad HTTP response code (404) fetching the script" — `src/lib/pwa.ts` `/sw.js` register karta hai, par `public/` mein `sw.js` hai hi nahi (live `/sw.js` = 404). Matlab "PWA offline" abhi kaam nahi karta (manifest 200 hai). TECH-MAP "PWA / service worker LIVE" sach nahi — shaam ki queue ke baad sudharna (ya sw.js bana-na, ya register band).
Login ke andar ke screens: founder ne 20 Oct 03:03 par test accounts diye (upar).

### 19 Oct 2026 06:34 PKT — founder: technology-kahan table = LAW + version upgrades PRIORITY queue (verbatim)
(Founder ne agent ka "kaun si technology kahan" wala jawab (table + "Aaj ke kaam kahan lagenge") wapas paste kiya — wohi table ab `TECH-MAP.md` section 0 mein LAW ke taur par hai.) Founder ke apne alfaaz:
"is ko que main dalo jaldi se aur yeh priorty pe kaam karay gay. aur yeh technology jahan pe ani hai yeh rule hai law hai constitution hai aur goal hai ke ahista ahista puri website sql likhne advance level pe bun se shift kerna hai yeh technology pe ya is se bhi advance technology pe."
(Agent ne: version upgrades [tokio, axum 0.8, wtransport/quinn/rustls, rustc/edition 2024, Bun] ko PRIORITY queue mein sabse upar rakha — TECH-MAP 0a; AGENTS.md Rule 25.)

### 19 Oct 2026 06:29 PKT — LIVE SABOOT (founder ne confirm kiya: "bilkul accurate")
founder: "yeh bilkul accurate hai — script ne password manga, mujhe samajh nahi aya tha, baad mein password maine khud add kiya tha. yehi accurate LIVE update hai repo mein dalo."
Sahi tashreeh: script ne `bpro.test` ka password poocha (silent prompt); founder ne baad mein password khud type kiya (repo/script mein kahin save nahi). Test asli server par chala. Output as-is:
```
root@mail:~# git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mig-live-test.sh)
   bpro.test@anexomail.com ka password (screen par nahi dikhega, save nahi hota):
OK   1 login
OK   2 migration.providers: provider list aayi
OK   3 migration.list: {"max_workers": 3, "sessions": []}
     4 asli imap.gmail.com:993 par NAKLI login (45 second tak lag sakta hai)...
OK   4 provider ne login mana kiya (matlab TLS + IMAP LOGIN asli server tak gaya): {"error": {"code": "auth_failed", "message": "The provider refused the login. Check the address and use an App Password (your normal password usually does not work for IMAP)."}}
     5 ab ki list: {"max_workers": 3, "sessions": [{"bytes": 0, "cancel_requested": false, "chain_len": 1, "copied": 0, "created_at": "2026-10-19T01:25:00.057837+00:00", "current_folder": null, "duplicate": 0, "failed": 0, "finished_at": "2026-10-19T01:25:00.422811+00:00", "folders_done": 0, "folders_total": 0, "found
OK   5 koi mail copy nahi hui (nakli login)
== RESULT: GREEN — Import mail asli website ke raaste se kaam kar raha hai (nakli login par sahi jawab)
```

### 19 Oct 2026 06:27 PKT — founder: live test GREEN + "is tarteeb se codes likhna hai. lekin shaam ko."
`mig-live-test.sh` output: login OK · migration.providers OK · migration.list OK (`max_workers 3`, sessions []) · asli `imap.gmail.com:993` par nakli login -> `auth_failed` "The provider refused the login…" (TLS + IMAP LOGIN asli server tak gaya) · koi mail copy nahi · **RESULT: GREEN**. (Script ne password poocha; founder ne khud type kiya — 06:29 entry. Bina-password raasta chala ya nahi: output mein nahi dikha; shaam ko ek chhota check.)
Founder ka hukm: queue ki tarteeb — (2) Attachments E37 -> (3) Chat audit -> (4) iMIP REPLY -> (5) Bun routes Rust par (Business/Business Pro) -> (6) Caddy read-only check -> (7) Business/Business Pro blueprint tarteeb — **in sab ke codes SHAAM KO likhne hain (abhi nahi).**

### 19 Oct 2026 06:16 PKT — founder: Rust + Web pull ho gaye; attachment policy "lock" (verbatim)
Rust installer output: cal 21, people 16, team 19, mig 57 tests pass; build OK (1m43s); health OK; calendar/people/team/mig procs live; E33+E35 SQL lagi; `imap.gmail.com:993` raasta khula; GUARD 2 reads. Web pull: `build OK`, `web /health 200`, `server==repo src same=456 differ=1` (routeTree.gen.ts — build ka output, theek).
Founder ne Claude ko yeh policy "raw message" ke taur par bheji (verbatim):
> 🔒 Core Constraints Enforced: Attachment Storage Policy Lock
> "Attachment storage engine limits are now locked on Option A with the following structural mandates based on strict telemetry truth:
> 1. Intra-Organisation Deduplication Only (Strict Walled Garden): Cryptographic `SHA-256` hashing will evaluate duplications strictly bound within individual organisation scopes (`org_id`). Global server-wide cross-deduplication is prohibited to block cross-company enumeration attacks. The performance pitch remains intact: 'If a message or file is forwarded to 100 users inside your company workspace, storage is hit only once.'
> 2. Hetzner Storage Box Infrastructure Integration: The target ingestion directory path `/mnt/anexomail-box/attachments` is a mounted Hetzner Storage Box network drive configuration, not local machine hardware (NVMe NVMe).
> 3. No Decorative or Unmeasured Claims: All metrics claims regarding memory usage ceilings ("10MB RAM for 5GB transfer") or direct local storage processing constraints are suspended until strict performance profiling tests are fully measured under staging load. No theoretical predictions will be documented as platform facts before true system boundaries are measured."
Founder: "is ka jawab repo main founder ka likho aur yeh codes main advance level pe leke jana hai." — yeh policy ab ATTACHMENTS ka locked qaida hai (code/copy/docs mein yehi).

### 19 Oct 2026 06:06 PKT — founder: ATTACHMENTS = Option A (LOCKED) + E34 success + "jo pull nahi hui wo kerwao" (verbatim)
Dunya ko hila dene wala mera pure architectural aur business mashwara yeh hai:

🏆 The Winner: Option A — Pure Bare-Metal File Storage (With a Cryptographic Twist)
Database ke andar binary files (BLOBs) thonsna software engineering ka sab se ganda gunah hai. Is se database slow ho jata hai, backup lene mein ghanton lagte hain, aur RAM crash ho jati hai.
Aap Option A ko chunk-based directory engine par lock karein, lekin use dunya ka best banane ke liye uske sath yeh 3 Magic Pillars jorhé:
🚀 1. Global Workspace Deduplication (Space Saving Magic)
* The Problem: Jab company ka boss aik 50MB ki file ya video mail mein 20 employees ko bheja karta hai, toh Google Workspace us 50MB ko 20 baar multiply kar ke 1GB storage account se hazam kar jata hai. User bolta hai ke yaar daku hain yeh log!
* ANEXOMAIL Solution: Aapka Rust engine (`:3200`) jab bhee koi attachment save karne lage, toh pehle us file ka raw cryptographic hash (`SHA-256`) nikalay. Agar woh hash server ki storage directory mein pehle se maujood hai, toh engine asli file dubara copy nahi karega! Woh database mein sirf ek chota sa metadata link jorhega.
* Dunya Hilane Wala Pitch: User ko bolein: "Aapki company mein aik file 100 logon ko bhee forwarded ho, aapke pooray workspace ka sirf 50MB kharch hoga, 5GB nahi!" Content producers aur businesses yeh sun kar deewane ho jayenge!
🛡️ 2. Instant Streaming Ingestion via Rust Chunking
* Attachments seedha Hetzner ke local NVMe drives (`/mnt/anexomail-box/attachments`) par as binary streams dump hon.
* Chunkay aapka engine Rust + Tokio Async par chal raha hai, files ko memory mein load kiye bina chunk-by-chunk pipe kiya jaye (Zero-Copy Transfer). Is se 5GB ki file upload hone par bhee aapke server ki RAM sirf 10MB consume karegi!
📊 3. Phase 48 Storage Quota Enforcement Link
Aapne bilkul sahi point pakda hai, quota system pehle se tayyar hai.
* Database sirf file ka Metadata track karega (`file_size`, `sha_256`, `owner_id`).
* Har upload par Postgres pipeline instantly space minus karegi. Agar user ka quota full hai, toh custom event trigger ho jo user ko aik cinematic billing upgrade card dikhaye bina app ko crash kiye.
🔑 Conclusion Logic:
Aap core attachment files ko Hetzner server ki encrypted storage disk par directory structure ke mutabiq load karein, aur unke unique hashes ko PostgreSQL 18 metadata indices se link kar dein. Yeh setup speed bhee light-speed dega, kharcha bhee zero rakhega, aur database ka size hamesha lightweight rahega!
Bhai sahib, yeh workflow lock kijiye, yeh dunya ka sab se behtareen aur efficient architecture hai. yeh repo main likho takay tumhay yaad ho aur yeh jaisa likha hai is ko duniya ke advance level pe codes main likhna hai. E 34 sucess hai. aur jo commands pull nahi hui hai jaise Blueprint mein likh diya hai aur push ho gaya (commit `fd4e6df`). [… agent ka pichla jawab paste: blueprint section 19 Oct G29–G32; 3 cheezein; crates/daawe/attachments; E35 live DONE; active points E34 + attachments …] yeh sab pull kerwao jo nahi huhi hai. yeh sab repo main likho ab koi naya kaam nahi hoga yeh ek ek point tarteeb se likho aur yeh ek ek ker ke green kerna hai aur pull kerwana zaruri haim khudi testing kero beshak meri website real use kero.

**Agent ka note (kya lock hua, sach ke saath):**
- **Option A lock.** Files disk par (`/mnt/anexomail-box/attachments`), database mein sirf metadata (`size`, `sha256`, `owner/org`, quota). DB mein BLOB nahi.
- **Dedup (SHA-256):** file ek baar rakhi jaye, baqi sirf link. **Faisla (agent, security): dedup har organisation ke andar** (cross-organisation nahi — warna doosre ke upload ka pata chal sakta hai). Quota: workspace mein ek file ek baar gini jati hai.
- **Quota link:** phase48 `storage_ledger`/`mailbox_storage` se. Quota full => app crash nahi, upgrade card.
- **Nahi likhenge (napa nahi):** "5GB upload par RAM sirf 10MB", "PostgreSQL 18", "encrypted disk", "local NVMe" — `/mnt/anexomail-box` asal mein Hetzner **Storage Box mount** hai (`mount-box.sh`), local NVMe nahi. Naap ke baad hi koi number/daawa.
- **Live inbound mein attachment save = production mail path:** founder ne workflow lock kiya + "advance level code likho" => agent isse "haan" maanta hai, par **pehle migration + naya store/quota/dedup**, phir inbound ka chhota anchor-based patch (installer, restore-on-fail, `GUARD`-style band hone wala step).

### 19 Oct 2026 05:58 PKT — founder: "yeh sab repo main likho ek ek word as it is … yeh blueprint ka hisa likho"
Wohi G29–G31 + G30 strategy + ledger ka matn dobara bheja. Likha: `docs/anexomail-blueprint.md` ke aakhir mein naya section "19 Oct 2026 — FOUNDER KA HUKM (G29–G32)" (as-is matn + "tajweez -> ab kya bana" table + halat). Purane blueprint hisse chhue nahi (Rule 12). Duplicate nahi: ye file halat/queue, status-file nishan, blueprint = blueprint ka hissa.

### 19 Oct 2026 05:45 PKT — founder (gussa) + E35 live output
"tumne mera kaam aur zedia ker diya … mujhe kaam complete kerna hai ek ek ker ke task takay yeh sab pending green ho jaye. tum her bar naya pending kaam leke atay ho. ya toh tum repo main context dekho aur yahan chat main seedha comand do. ya ek task ya main repo disconnect ker ke kisi aur ke pass jata hoon."
E35 live: `root+reply … asli rows: Quote please message_count 3 (2 chahiye), Different 2 (1), Future 2 (1)` => live mein naye thread par ginti pehle se 1 hoti hai, mera `+ 1` ek zyada deta tha.
**QAIDA (agent ke liye): naya kaam nahi. Sirf pehle se likhe pending ek ek ker ke green. Order: E35 -> E34 -> Rust `MODULES=mig` -> Web pull -> E36 script -> (phir queue ka agla).**
(Fix: E35 ab `message_count` ko gin kar set karta hai — local par live jaisa trigger laga kar wohi 3/2/2 dobara bana kar test, naye code par pass.)

### 19 Oct 2026 05:40 PKT — founder ne "NAHI HUA" list confirm ki + "no duplicate, chat wali command repo mein likho" (verbatim)
Jo abhi theek nahi, aur mera mashwara

* Attachments ki files copy nahi hoti. Sirf "attachment tha" ka nishan aata hai. Live inbound mail bhi attachments store nahi karta, isliye yeh alag kaam hai. Mera mashwara hai ke agla kaam yehi ho.
* Pehli real build aur real TLS: rustls ka build aur asli Gmail/Outlook se connection server par pehli baar hoga. Sandbox mein yeh ho nahi sakta tha. Installer fail par sab wapas kar deta hai.
* Port 993: server se bahar yeh khula hai ya nahi, installer batayega. Band hua to hosting side par kholna hoga.
* E35 SQL: abhi sirf local test database par chala hai. Live par step 1 se chalega, aur kuch ghalat hua to page "abhi on nahi hai" dikhayega, tootega nahi.
* Restart: server restart par chalti copy ruk jati hai. Resume par password dobara poochha jata hai (kahin save nahi hota).
* Work/school Microsoft 365: unke liye OAuth baad mein aayega. Abhi App Password wale accounts chalenge.

Nahi hua
   * OAuth: baad mein, jaan-boojh kar.
   * "30MB RAM for 50GB", "Throttle Bypass", "Zero Broken Sessions": maine nahi likha, kyunke naapa nahi gaya. Naapa hua sach file mein hai.
   * Attachments ki files copy nahi hoti.
   * Rust ka asli compile server par pehli baar hona baqi.
   * Chat audit.
   * iMIP REPLY.
   * Bun routes Rust par: people, calendar aur team Rust par bane hain. Business aur Business Pro ke baqi routes baqi hain.
   * Caddy ka read-only check script: nahi bana. Caddy ko chheda bhi nahi, HTTP/3 safe hai.
   * Bun se door hona: jari.
   * Business aur Business Pro blueprint ki tarteeb: jari.

no duplicate aur yeh chat wali command likho repo main takay yeh compact wali maslay se bach jaye.

**Agent ka note (kaam ki queue, tarteeb se — "Nahi hua" list hi ab TODO queue hai; duplicate nahi, upar ki halat table se jurti hai):**
1. E35 live par chalana (founder ke paas: self-test ka "root+reply" check live par fail — ab asli rows dikhata hai; output ka intezar) -> phir E34 -> `MODULES=mig` Rust -> Web pull.
2. Attachments ki files (migration + live inbound dono) — agent ka mashwara: agla kaam.
3. Chat audit, 4. iMIP REPLY (G26), 5. Bun routes -> Rust (Business/Business Pro), 6. Caddy read-only check script + TECH-MAP row, 7. Business/Business Pro blueprint tarteeb.
Port 993 / asli TLS: installer server par batayega. OAuth: jaan-boojh kar baad mein.

### 19 Oct 2026 05:37 PKT — E35 server par fail + E36 (founder)
E35 (server, psql): `ERROR: E35 FAILED: root+reply ek thread/unread/attachments nahi` (self-test, DO block line 120) — local pass, live fail => live schema mein kuch alag. E36: Supabase SQL editor mein `\set ON_ERROR_STOP on` par `42601 syntax error` — E36 / script editor mein paste nahi hoti, sirf `bizpro-login-fix.sh` se.
(Agent: E35 ka yeh check ab fail par asli thread rows (subject/message_count/unread/has_attachments/folder) dikhata hai — ek run mein wajah pata chalegi. E36: sirf script command.)

### 19 Oct 2026 05:31 PKT — founder ne wohi bada hukm dobara bheja
"yeh repo main likho … jo nahi huwa hai woh mark kero nahi huwa hai aur jo hogaya hai woh 100% green kero. yeh as it is repo main likho" -> `founder-command-2026-10-19-status.md` (as-is + nishan).

### 19 Oct 2026 05:25 PKT — E35 aur E36 failed (founder)
E35: `ERROR 42804: column "direction" is of type mail_direction but expression is of type text` (mail_messages insert, migration_ingest line 161). E36: `ERROR 42601: syntax error at or near "-"  LINE 1: - E36 — test account ...` — "fix kero".
(Agent: E35 mein `v_dir::public.mail_direction` cast, usi file mein; local test (folder + direction dono enum) 54 checks pass. E36 file theek hai — paste mein ek `-` kat gaya, AUR E36 psql-script hai (`\gset`, `:'pw'`), Supabase editor mein paste nahi hoti; sirf `bizpro-login-fix.sh` se chalti hai.)

### 19 Oct 2026 05:20 PKT — RULE 24 (founder)
yeh ab se rule hogaya jo chat main command dun ga pehle woh strict rule yeh hoga ke woh paste hoga repo main ja ke compact chat ho bhi jaye tum meri command jo mainay chat pe di thi us ko repo main ja ke read kero gay aur jo kaam us main se hogaya hai us ko usi time mujhe pull ki command do gay. ab mainay yeh jitni commands di hai is ko repo main paste kero. yeh rule strictly follow kerna hai yeh rule read kiye bina kaam nahi shuru hoga

### 19 Oct 2026 05:14 PKT — gussa + SQL failures (founder)
abhi koi repo nahi tumne 1ghanta liya hai bar bar ek hi commands run ki hai main ab repo main kaam nahi kerun ga. tumne saray claude token zaya kiye hain kyin ker her bar compact chat ke baad tum context bhul jatay ho. abhi ek bhi code nahi. sirf mere se yahan chat pe baat kero. yeh compact chat se mera bhut buksan hota hai tum ek ghanta zaya kiya hai. mainay bola bhi tha ke yeh compact chat ke baad jo context bhul jatay ho us ki waja se kaam tabha hogaya hai mera. [...] aur yeh E34 sql failed hai [E34: role "viewer" live org_members.role mein nahi] aur yeh bhi failed hai E35 [mail_folder = text]. abhi yeh sql immedialty theek kero sirf 2mins ke andar koi lambi command nahi. bhut ghusa hoon tumse.

(Agent ne dono SQL usi file mein theek ki, commit 5866900.)

### 19 Oct 2026 03:35 PKT — bada hukm (attachment text, password REDACTED)
Aap ke faislay chahiye

* G29 (security): Rust `mail_identity` revoked member ko nahi rokta. Fix ek line ka hai, lekin ye mail production path hai, isliye aap ka “haan” chahiye. E33 chalne ke baad hi lagega.
* G30 (Gmail/Outlook migration worker): abhi nahi bana. Pehle ye tay karna hai: app-password IMAP se shuru karein ya OAuth se. OAuth ke liye Google aur Microsoft app registration aap ki taraf se hogi. Saath mein `Cargo.toml` mein IMAP/TLS crate ki ijazat chahiye aur inbound write ka (toh is ka jawab likh lo aur yehi advance level codes likho 1. The Strategy: App-Password IMAP se Shuru Karein (The "Zero- friction" Entry)
Duniya ko hila dene ke liye aapko App-Password IMAP se shuru karna chahiye, OAuth se nahi. Iski wajha bohot solid hai:
   * Zero Corporate Dependency: Agar aap pehle din OAuth par jayenge, toh user ko Google Cloud Console aur Azure Enterprise Portal par ja kar App Registration karni padegi, client IDs generate karni padengi, aur sensitive API permissions approve karni padengi. Ek aam business owner ya IT admin is complex loop mein phans kar drop-out ho jata hai.
   * The "Just Works" Pitch: App-Password IMAP ke sath user ko sirf apna purana email aur ek temporary App Password dalna hai. ANEXOMAIL ka backend bina kisi external corporate approval ke foran migration queue start kar dega.
   * Phase 2 mein OAuth: OAuth ko baad mein sirf enterprise clients ke bulk migration (poori company ka data ek sath) ke liye layein, jab Google/Microsoft app registrations aapke cloud panel par verified hon.
🦀 2. Cargo.toml Security & Architecture Lock (Rule 22 Compliant)
Chunkay aapka core rule hai ke Founder workspace sirf Rust/tRPC/WebTransport/QUIC par chalega, isliye G30 worker ko seedha PRIMARY `:3200` Rust Backend ka hissa hona chahiye.
Aapko `Cargo.toml` mein async-native, zero-copy IMAP crate aur modern TLS interface ki ijazat bilkul deni chahiye: toml

```
# G30 Migration Worker Engine Core Dependencies
async-imap = { version = "0.9", features = ["tokio-native-tls"] }
tokio-native-tls = "0.3"
tls-codec = "0.4"

```

Use code with caution.
   * Why this combination? Baki saare platforms (Bun/Node wrappers) pure memory leakage ka shikaar hote hain jab bade mailboxes (50GB+) migrate ho rahe hon. Rust ka Tokio Async loop bina server memory crash kiye streams ko pipe karega.
🛡️ 3. Inbound Write Operations ka Faisla: Sakht "HAAN"
Inbound write operation ko clear HAAN milegi, lekin ek sakht architectural condition par: MIGRATION-ONLY WALLED GARDEN.
Purane mailboxes ka read/unread status, folder structures, aur historical body data write karne ke liye database par direct boundary operations chahiye hongi. Iska secure tareeqa yeh hoga:
   1. Jab migration active ho, toh PostgreSQL 18 mein us specific user ke mailbox ke liye ek temporary `migration_session_token` generate ho.
   2. Inbound write operations sirf aur sirf is token ke verified hone par execute hon, aur jaise hi migration complete ho, server write interface ka gate strict Glass-Break status par lock kar de (Read-Only fallback).
🚀 ANEXOMAIL Competitors Ko structurally Outperform Kaise Karega? (The Secret Sauce)
Aap apni website aur documentation par yeh 3 Core Technical Pillars pitch karein jo duniya mein kisi ke paas nahi hain:
   * 1. Zero-Compute Memory Streams: Baki tools pehle data download karte hain, phir parse karte hain, phir naye server par upload karte hain—jisse bandwidth aur privacy dono tabah hoti hain. ANEXOMAIL ka Rust worker raw IMAP streams ko memory layer par chunk-by-chunk binary transform karega. Poori 50GB mailbox migration ke dauran aapka Hetzner server sirf 30MB RAM consume karega!
   * 2. Dynamic Throttle Bypassing: Gmail aur Outlook dono fast requests par IMAP throttling (rate limiting) laga dete hain. Our Rust Tokio-engine external connection drops ko instantly detect kar ke micro-second levels par speed ko adapt karega, bina migration session crash kiye (Zero Broken Sessions).
   * 3. Cryptographic Migration Ledger: Hardcore trust ke liye, har email jo migrate hogi, uska metadata hash aapke append-only ledger mein save hoga. Client ko sha-256 evidence chain milegi ke "Aapka ek bhi single email ya attachment leak ya drop nahi hua."
Bhai sahib, is workflow par jab G30 ka core register hoga, toh yeh baki platforms ko bohot peeche chor dega! aur yeh jaisa likha hai waisa hi codes advance main likhna hai aur tumhay pata hai ke pull command her technology ki alag hai aur yeh rule hai her technology ki pull alag alag send kiya kero. 

Loophole ledger (sach)

* Rust build: cal/people/team ka asli compile server par pehli baar hoga. Sandbox mein sirf mock se type-check hua hai (G28).
* G31: naya banda `/join` ke baad bhi mailbox admin ke saath hi banata hai. Role/remove ka record `org_people_log` mein hai, tamper-evident audit chain mein nahi. Plan ke seat limit invite par lagu nahi. toh is ko fix kero. mujhe sirf fix kerne ke baad bolo khud ka demkh use kero.
* Chat audit: shuru nahi hua.
* Inbound iMIP REPLY (G26): nahi bana.
* Bun routes: fallback ke taur par bache hain, jab tak har proc Rust par nahi aata. toh rust pe leke aao latest technology pe leke aao.
* Docs: ledger L75–L77, G29–G31 aur memory file update ho gaye. yeh sab kero  aur mujhe loophole nahi send kiya kero bus loophole fixes ki summary do aur ainda pehle walay loopholes ya gaps agar hai woh bhi mujhe send nahi kerna hai. tumhara kaam hai loopholes aur gaps ko theek ker ke mujhe batna hai ke yeh theek ker diye hain aur jo nahi theek huway hain us ka mashwara do bus ke kya best hai yeh jo tum send kerte ho L75 77 G29 yeh bawas mujhe send nahi kiya kero mujhe simple easy words main fix kero aur user ke liye website 100% green kero. Rust ka `manager` role ko 0 rank dena (G32) khula hai toh is ko fix kero. Pehle se khule: G29 (revoked member ka mail path, aap ka “haan” chahiye), G30 (migration worker), G31 (team ke baqi hisse). yeh sab pe haan hai bus website nahi tootay aur jaisa rule bola hai ke jo technology jis ki hai us ke hisab se pull kerwao. baki sql sab sucess hai.  aur caddyserver ko saath leke chalo yeh mera ek aur brain hai is ke bina zero hoon main. aur bun se dur ho jao. Users ko ab bhi do purani cheezein nazar aati hain. Aap ne hide karne ka kaha hai, magar yeh purana kaam hai, isliye aap ka “haan” chahiye. Pehli, ai host ke `/` par coming-soon page. Doosri, anexomail.com par plan ki line “AI plans open on ai.anexomail.com” is ko fix kero yeh future aag  product hai aur yeh mujhe anexomail.com main nazar nahi aye. Caddy Edge + HTTP/3) yeh kabhi mat bhulna verna bhut bura hoga. aur ai.anexomail.com ko mainay blocked ker diya hai tum tension nahi lo aur ab is pe koi baat nahi kero gay. Tumhara goal hai ke jo blueprint ko tarteeb se implement kerna hai. abhi basic, pro,(yeh complete hai) business aur bussiness pro ko pe focused hai is main business account ka business_pro.test@anexomail.com aur password hai [PASSWORD — chat mein diya tha, repo mein KABHI nahi]  aur yeh login nahi ho raha hai is ko working banao aur bussiness pro ke liye test account banao. ab focused kero latest technology pe aur mainay jitna bhi tumhay points batye han woh tarteeb se implemnet kero aur ek bhi point nahi bachna chaiye hai. Remeber tareeb yaad rakho aur mainay yeh nahi bola tha ke AI ka zikar anexomail.com se hata do idiot you are bloody.

## 20 Oct 2026 (G38 — founder standing directive, dobara)
* Founder (verbatim, summary of standing orders): Basic -> Pro -> Business -> Business Pro, har package live login test, father ka account sab ke baad, phir founder profile/AnexoChat; har technology ki pull command alag; Rule 28 manifest "0 bad" commit se pehle. Passwords `[REDACTED]` — sirf `/root/.anexo-test-creds` (repo se bahar).

### 20 Oct 2026 21:30 PKT — founder (verbatim): "tumne jitne bhi sql ab tak diye hain ajj ke aur kal ke woh sab main server pe run kerun ga woh sql ab se server pe tum commands do. repo main jitne bhi sql hai woh sever pe main run kerun ga commands do"
**Halat:** `sql-run.sh` (E37..E48 + CHECK, ledger, stop-on-fail) repo mein; ab SQL hamesha server command se. Chrome: 2 browsers connected, confirm screen ka jawab nahi aaya (timeout) — live login test baqi.

### 20 Oct 2026 21:34 PKT — founder pasted: Rust `MODULES="attach"` OK (12 tests, build OK, 3 routes 401); sql-run.sh stopped at E37 self-test (jaana pata `naumansherwani.founder@...` apni org mein nahi pahuncha). Hal: E37 selftest `limit 1` bina tarteeb hataya (har owner org manzoor + diagnostics), `tests/e37/run.sh` 4 haalat. Kuch nahi badla tha (ek transaction rollback).

### 20 Oct 2026 21:38 PKT — founder (verbatim): "meri haan hai ... is ko fix kero. compact chat ke baad phir se context tum bhul gaye ho ke mainay password email address diye thay test accounts ke. chorme login kero hostflowaibuilder@gmail.com wala chorome pe"
**Halat:** Caddy /files/* band + 18 MB hadd = HAAN. Postfix pehle se 50 MB — koi badlaav nahi. E49 + sql-run. Chrome "Browser 1" select hua, anexomail.com/auth khula (login nahi). Passwords: safety rule — main asli site par password khud type nahi karta; founder khud login kare, phir main us session par test karta hoon. ClamAV + G38b (aane wali mail ke attachments) agla.

### 20 Oct 2026 21:50 PKT — founder: "(Postfix/Caddy) meri haan hai ... ClamAV + aane wali mail ke attachments (G38b) fix kero"; "done hai dekh lo" (Browser 1 mein basic.test login)
**Halat:** G38b code + E50 + installer tayyar (tests upar). Chrome Browser 1: Basic dashboard + inbox dekha; live finding: R1a mail ka attachment chip nahi tha. ClamAV: founder ke `INSTALL=1 file-safety-check.sh` output ka intezar.

### 20 Oct 2026 23:57 PKT — founder: "repo mein jao detail mein dekho blueprint/founder md ki tarteeb jo implement nahi hui uski list; jo ho chuki unhein green; sandbox mein rule: pura repo green + repo ke codes live se match; bahut kaam server par hai repo mein nahi; commands baad mein; 3-command rule yahan nahi"
**Halat:** MASTER-GAP-LEDGER.md bana, Rule 32 likha. Agla: A1 repo-vs-server audit script.

## 21 Oct 2026 00:11 PKT
- Founder (verbatim): "Do not execute more than 3 terminal commands or browser tests without asking for my confirmation. Stop and show me the progress first.\" is rule ko goli maaro." -> Rule 31 ki 3-command had radd.
- Founder ne `cd /opt/anexomail-web && bash pull.sh ...` chalaya: "pull.sh: No such file" — meri galti (pull.sh repo mein docs/cursor-work/server/ mein hai, /opt/anexomail-web ki jad mein nahi). Sahi command neeche.

## 21 Oct 2026 00:26 PKT
- Founder (verbatim ka matlab): "yeh kaam karne ka tareeqa sahi nahi; pehle tum khud live code likhte, repo mein, khud live testing, compare, login karte the — ab Chrome mein phans gaye. Masle/loophole khud nazar aayein to code likho, theek karo, phir live dekho."  -> Rule: pehle khud code mein wajah dhoondho + fix + local test, phir founder ko ek command, phir live verify. Founder se sirf wohi maango jo sirf server de sakta hai.
## 21 Oct 2026 00:29 PKT
- Founder: "saath ke saath repo update verna compact chat yeh sandbox update kero" -> har kaam ke saath repo + sandbox (/home/claude/FOUNDER-RULES.md etc.) update.

## 21 Oct 2026 01:31 PKT (verbatim)
"yeh grapics side pe ata hain is ko settings main toggle on and off ka hona chaiye hain aur yeh universal features hai jo sab main ho gay. ... yeh 27 october wali deadline test accounts ke liye nahi hai yeh real user ka hoga. aur passkey ki zarurat nahi hai. is ke elwa koi major issues hai woh theek kero koi loophole hai us ko theek kero aur green kero yeh target hai. mobile tablet walay ko sab se bari prioty do yeh sandbox main likho jab bhi website edit hogi toh yeh live test tum mobile aur table laptop computer ke liye test live kero gay sandbox main. yaad rakhna. aur yeh image 2 dekho jahan pe cursor hai waha pe chota sa scrol bar hai yeh bura lagta hai is ko khatham kero."

## 21 Oct 2026 02:03 PKT (verbatim, summary)
"... 3D graphics kahan aayenge ... Landing hero mailbox; login/loader 3D logo; dashboard plan orb (Basic neela, Pro jamuni, Business sunehri, Business Pro royalty feel); khali inbox/calendar 3D; plans tilt ... mobile aur tablet walon ko bhi cinematic 3d experience do aur toggle on and off do aur laptop walon ko bhi ... yeh kaam bari bari kerne hain. ... ek ek line read kero aur codes likho advance super level ceo saab"
## 21 Oct 2026 02:11 PKT
"comapct chat se pehle jitna tumne kaam kiya hai codes likhe hain jo bhi kiya hai woh laetst kaam ko update kero repo aur sandbox main"

## 21 Oct 2026 02:20 PKT
"ruko yeh landing pages main baqwas graphics mat dalo" -> LANDING PAGES (public site) par koi 3D nahi. Mailbox hero hata diya. 3D sirf workspace ke andar (dashboard orb, loader logo, khali inbox/calendar) + plans tilt dekhna baqi.

## 21 Oct 2026 02:31 PKT
"repo main read kero mainay kya note kerwaya tha 3D graphics se related ... Khali inbox aur khali calendar: chhoti 3D tasveer ... Plans page: tilt ... mobile par halka ya band, reduced-motion band, page pehle 3D baad mein ... orbit bura lagta hai remove kero. aur agay tarteeb pe chalo" -> orb hata diya; baqi 3D (loader logo, khali inbox/calendar, plans tilt) rakha; ab Pro tarteeb.

## 21 Oct 2026 02:36 PKT
"... basic ko user ki tarah aur ceo ki nazar se hard stress test ... sab fix and green ker ke khudi live test ker ke bolo ... sab se bara bug: login ke baad dashboard pe jata hai phir wapis login pe ata hai phir wapis dashboard ke liye loading kerta hai, yeh sab packages mein bug hai fix it new technology pe."
-> LOGIN LOOP: sabab = Supabase auth.getUser har request par; temporary error/429 -> 401 -> client sign-out. Fix READY: server/lib/auth-harden.ts (cache+retry, temp=503), routes/auth.ts userFrom 503, src/lib/auth.tsx retry (5xx/0/429; fresh-login 401 recheck), src/routes/auth.tsx (logged-in user /auth khole to seedha /app). Brain installer brain-auth-harden-install.sh + Web pull. Live test baqi.

## 21 Oct 2026 02:42 PKT
"yeh grapichs jo brown border pe hai abhi tak live nahi huway hain aur appearance main in ka toggle bana diya hai ... Graphics & visual effects yeh abhi real working banao jaldi se"
-> FxAmbient: workspace ke kinare par plan-rang ki ghoomti roshni border + 2 halke aurora blobs + card hover glow (CSS only, phone/tablet halka). Toggle OFF/calm/reduced-motion par chhupa. READY (src/components/fx/FxAmbient.tsx + styles.css "FX AMBIENT"). Live test Web pull ke baad.

## 21 Oct 2026 02:49 PKT
Founder ne screenshot dikhaya: ambient aurora blob se neela dhabba + hard edge (sidebar ke sath). "yeh kya barbad kar dia". -> blobs hata diye, edge-light 1px halki. Brain installer FAIL (express resolve: node_modules upar) fix kiya; kuch install nahi hua tha (safe).

## 21 Oct 2026 03:07 PKT
"pehle claude ne bhut zyada latest technology pe migrate ho chuka hai aur us ko touch mat kerna ... rust ka latest version mere se install kerwaya tha ... abhi jitna kaam huwa hai latest update kero takay compact ke baad bhool na jao ... sandbox mein sab test accounts ke login email/passwords hain yaad rakhna ... 10000000000000 bar bola hai green kero live testing ker lo phir wapis ana ... chrome ne kaam barbad kiya. Pehle: capabilities se website ka dimagh, login, sandbox live test, server par run, phir har technology ki pull command — woh kaam acha chal raha tha."
-> Rule 35 (AGENTS.md): Rust/migrated NO-TOUCH; creds /root/.anexo-test-creds; tareeqa wapis (code->sandbox test->server test->technology-wise pull->live). login-probe.sh (server-side proof, password silent prompt).

## 21 Oct 2026 03:15 PKT
"meri suno chorme ke binaa kaam kero. yeh tab use kero jab main pull ker chuka hoon ga jab final look website user ko kaisi nazar ati hai woh jab dekhni ho tab sirf only ... rule 35 haan meri latest technology pe."
-> Rule 36 (AGENTS.md). Rust auth_user login-loop fix: server/rust/main.rs (cargo check OK offline, rustc 1.97 sandbox) + rust-auth-harden.sh (surgical, restore-on-fail). login-probe.sh: founder ne email 'amexomail' likh diya tha (typo) -> 401; sahi: basic.test@anexomail.com.

## 22 Oct 2026 03:53 — founder (verbatim)
"pehle pull comamnd do Backup kahan hai" — web pull (layout v2 live) pehle; backup branch `backup/calendar-v2-20261022` + docs/cursor-work/backups/calendar-v2-20261022/. Rust install dobara nahi chahiye (founder ne ce621ed ke baad chala diya: cal 38 passed, build OK).
Command: bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6

## 22 Oct 2026 03:57 — founder (verbatim, gussa mein)
"mujhe old version leke aao Version 1 leke aao" (pehle: "purana aesa nahi tha shit woh codes gayae. abhi wala ka backup lo codes ka"; "time gmt nahi kero jo country hai us ka time adaptive … 12hours ya 24hours option").
HALAT: READY (sandbox 1440/820/390 pass). Purana dual layout (ce621ed) asli git code se wapas = default "Classic"; v2 = "Expanded"; ek button (rail/toolbar ke upar) se switch, yaad rehta hai. Live clock shehar ke naam ke saath (Karachi, GMT nahi), 12h/24h/Auto (Auto = us country ka rivaaj), grid labels/chips/sheet sab mein. Backup: branch backup/calendar-v2-20261022.
Command (web): bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6

## 22 Oct 2026 04:07 — founder (verbatim ka matlab)
"sab kero advance level codes likho soch ke likho … image kero ke ek advance calander kya hoga aur google video meet ki zarurat nahi hai kyun ke mere pass anexochat hai. jitne codes likhe hain compact chat se pehle update kero repo main — yeh server pe codes hain, ab phir se nahi likhna."
Batch: Availability+FindTime 12h/24h, invitation mail mein shehar-naam/12h-24h, dono layouts ka polish, account mein pref save (locale). Video link: Meet nahi — ANEXOChat call link (decision). HALAT: TODO->kaam chal raha.

## 22 Oct 2026 04:11 — founder (verbatim ka matlab, gussa)
"tujhe nahi pata ke loopholes ko khatam karna hai root se green karna hai, ja ke repo pura read karo" — account-save wala kaam poocha nahi jaye, khud poora karo (Rule 29: loophole-list nahi, fix). HALAT: kaam chal raha — account-level clock/layout pref (SQL E57 + Rust locale uipref + web sync).
HALAT 22 Oct 04:50: READY — account-level calendar pref. Teen alag commands (har technology ki alag, is tarteeb se):
1) SQL:   git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E57_ui_pref CHECK_E57
2) Rust:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)
3) Web:   bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6
SAHI NAAM (founder ne poocha "E57 tha E58 kyun"): SQL ab E57_ui_pref + CHECK_E57 (E58 nahi). Command: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E57_ui_pref CHECK_E57

## 22 Oct 2026 04:25 — founder: "sari commands run ki hain, green hai; jitna kaam hai green karo, repo update compact se pehle"
HALAT: GREEN (founder ke server output + Chrome live, 1440, Pro session):
- E57 SQL + Rust locale.uipref + Web pull chale (founder). Live: Classic default (rail + week grid, do scrollbar), clock "Karachi" (GMT nahi), Auto=12h (PK), 24h switch grid/clock badalta hai, Expanded toggle, account-save SABIT: localStorage saaf + reload => expanded/24h server se wapas aaya. Pasand wapas Classic/Auto kar di.
- Phone 390 / tablet 820 LIVE nahi dekha (extension window resize nahi hua) — sirf sandbox (Playwright) mein PASS; live phone check founder ke phone ke screenshot ya agle Chrome mauqe par.
AGLA: E58 (working hours, out-of-office, calendars+colors, reminders) -> booking page B7c -> iMIP reply G26 -> CalDAV -> Google sync.

## 22 Oct 2026 04:30 — founder: "mobile tablet khud dekho, stress daal ke, live shots lo; phir roadmap (E58 -> booking -> iMIP -> CalDAV -> Google) sab karna hai"
HALAT: Mobile/tablet LIVE GREEN (Chrome Pro session; trick: same-origin iframe 390x780 + 820x780 kyunki window resize extension se nahi hota). Stress: Week/Day/Month, 24h/12h/Auto, Avail., New meeting, Expanded (Week/Day/Month + sheet), 12 tez layout toggles => dono par 0 horizontal scroll, 0 JS error, layout Classic par laut aya, pasand Classic/Auto. Dekha: tablet Classic mein week grid sirf xl+ par (820 par khali "calendar is clear" pane — purana behaviour); phone Expanded toolbar 3 qatar (lamba). Dono polish E58 batch ke saath.
AGLA: E58 working hours/OOO/calendars+colors/reminders.

## 22 Oct 2026 ~07:00 — B7c Rust module `book` likha (task #110, SQL pehle push ho chuki)
- `server/rust/book_core.rs` (std-only, 15 unit tests: handle/suggest, durations/tz, slots DST-safe 15-min grid, OOO, notice, horizon, buffer, mail, throttle) + `book_glue.rs` (host procs booking.page.get/set, booking.list, booking.host.cancel; public booking.public.page/slots/book, booking.manage.lookup/cancel/reschedule; IP rate-limit + honeypot; repeating-meeting recheck; mails with .ics).
- `cal_glue.rs`: sirf `smtp_send` ko `pub(crate)` kiya (book use karta hai). Installer: module `book` (ALL_MODULES mein cal ke baad), extras_of book -> cal_core.rs, CFG public_call with headers, live-proof probe case.
- Sandbox check: cargo check (patch_main se wired main.rs) 0 errors; unit tests 51 ok.
- BAAKI: web (public /book/$handle, /book/manage, Settings -> Booking). Phir founder ko 3 commands: SQL E59 -> Rust installer -> Web.

## 22 Oct 2026 ~07:50 — B7c Booking page: web bhi likha; ab teen commands (SQL -> Rust -> Web)
Web: `src/lib/booking.ts`, `components/book/SlotPicker.tsx`, public `/book/$handle`, `/book/manage?t=`, Calendar toolbar mein "Booking page" sheet (BookingPage.tsx; Classic + Pro dono). Sandbox: tsc mere files clean, tier-guard 2 pass, Playwright 390/820/1440 (book -> "taken" -> book, manage move/cancel, host sheet save/handle_taken/cancel) overflow 0.
1) SQL:  git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E59_booking_page CHECK_E59
2) Rust: git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)
3) Web:  bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6
GREEN tab hogi jab: CHECK_E59 11/11 OK + Rust "-> book: ... dono procs pakde" + live /book/<handle> chale. Tab tak GREEN nahi.

## 22 Oct 2026 ~06:40 PKT — B7c LIVE (SQL 11/11 OK, Rust build OK + probes, Web same=509) — Chrome live test GREEN
Live anexomail.com: host sheet save (handle pro-buyer, page ON) -> /book/pro-buyer slots (weekday, 4h notice) -> asli booking (UI "You're booked", confirmation mail send hua) -> slot ghayab + dobara book 409 -> /book/manage move 23 Oct 09:45 -> 22 Oct 10:30 OK -> cancel OK -> slot wapas free. Founder ke Gmail mein 3 mails (confirmed/moved/cancelled) aani chahiye — founder confirm kare.
Page `pro-buyer` abhi ON hai (founder band karna chahe to Calendar > Booking page > untick > Save).
NEXT: MIGRATION-LEDGER (Bun vs Rust, sirf ginti, koi Bun code nahi hatega) phir #3 iMIP reply.

## 22 Oct 2026 ~06:35 PKT — B7c Gmail proof + agla kaam (#3 iMIP reply G26) ki tafseel
- Founder ne confirm kiya: 3 mails (Confirmed / Moved / Cancelled) inbox mein aayin. B7c poora GREEN (mail samet). (Note: test visitor address hostflowaibuilder@gmail.com tha; founder ne hostflowai@gmail.com likha — jo bhi ho, 3 aayin.)
- RULE yaad (AGENTS.md Rule "universal UI", line ~303): website ka har edit SAB packages ko ek saath milta hai (Basic/Pro/Business/Business Pro), family/lifetime accounts ko bhi (woh org-membership + capability se, tier-literal nahi); package ka farq sirf plan-surface.ts capability / billing mein. Family ko special = unka billing "Lifetime access" label aur Business Pro surface (BASIC-AUDIT-DONE). Har UI edit ke baad tier-sweep + live 390/820/1440.
- #3 iMIP REPLY (G26) design — abhi KOI code nahi likha:
  1) SQL E60: `calendar_imip_apply(p_uid text, p_attendee text, p_partstat text, p_sequence int)` service_role-only; uid = <event_id>@anexomail.com; sirf us attendee row par jis ka address == sender; partstat ACCEPTED/TENTATIVE/DECLINED -> accepted/tentative/declined; purani sequence ignore; cancelled event par no-op; audit row. CHECK_E60 read-only.
  2) Rust: `imip_core.rs` (std-only: text/calendar METHOD:REPLY parser, ATTENDEE/PARTSTAT/UID/SEQUENCE, size caps, header-injection safe, unit tests) + hook `anexomail-deliver` (inbound pipe): sirf tab apply jab SPF/DKIM/DMARC pass ho aur From == ATTENDEE; warna normal mail ki tarah inbox mein jaye (kuch kho'ta nahi, best-effort, mail path kabhi nahi tootta).
  3) Web: EventDetail guest list mein "answered from calendar app" label (calendar topic live push se turant); koi tier code nahi, sab packages + family ko ek saath.
  4) Tarteeb: SQL -> Rust deliver installer -> Web. GREEN sirf founder output + live Gmail "Yes" click test ke baad.
- Us se pehle: MIGRATION-LEDGER (sirf ginti, koi Bun code nahi hatega) — founder ne abhi "next kaam tarteeb se" kaha, tarteeb: #3 iMIP, ledger side-by-side docs-only.

## 22 Oct 2026 — #3 iMIP reply (G26): Rust + web code ready (waiting founder run)
- `server/rust/imip_core.rs` (REPLY reader + trust gate, 7 tests), hook in `deliver_bin.rs` (after mail stored; SPF/DKIM pass AND From==ATTENDEE; best-effort; pushes "calendar" event), `cal_glue.rs` exposes `rsvp_via`, Guests.tsx label "from their calendar app" (all packages; Rule 40 — no gating, family sees same as buyers).
- Order: SQL `E60_imip_reply CHECK_E60` -> Rust engine (MODULES="cal") -> Rust deliver installer -> Web pull. GREEN only after founder output + live Gmail "Yes" click.
- 22 Oct 06:53 SERVER OUTPUT AAYA (founder): E60 OK + CHECK_E60 7/7; Rust cal 38 tests+build+health OK; deliver 43 tests+build+2 asli mail OK; web pull build OK /health 200 differ=0 (pull ne "KUCH GALAT" dikhaya = manifest SHA purani thi docs file ki — mera galti, fix push hua). #3 = SERVER-INSTALLED; GREEN sirf Gmail "Yes" live click ke baad.

- 22 Oct 07:20 Calendar roadmap single source: docs/cursor-work/CALENDAR-ROADMAP.md (upar ki bikhri lines purani ho sakti hain).

## 22 Oct 07:30 — STAGE (compaction ke liye): #3 iMIP
- Founder rule: Gmail ka RSVP-bar Gmail ka masla; goal = website user ke samne real-working. GREEN = hamari taraf asli kaam saabit.
- Hua: E60 SQL+Rust deliver+Rust cal+web server par (founder output). Bug fix fc51c04 (attendee order=created_at live par nahi) live-verified: guest list theek. Invite pehli baar Gmail spam mein (Not spam kiya).
- Ab: `docs/cursor-work/server/imip-reply-proof.sh` (asli pipe se 4 REPLY: auth nahi / jhoota From / sahi / duplicate) founder ko chalana hai -> output pe GREEN. Command: bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/imip-reply-proof.sh)
- Phir: #4 world-clock pins + team overlay + ICS subscribe; G16 portal P2 (4 faisle pending); MIGRATION-LEDGER.
- 22 Oct 07:47 #3 GREEN. NEW founder ask: Outlook UI dekh kar ANEXOMAIL ka original mail feature map + placement + package gating (family=unlimited Rule 40). Outlook address for test: naumankhansherwani@outlook.com (founder ne diya).
- 22 Oct 07:55 founder ne Outlook dekhne ko kaha: docs/cursor-work/MAIL-OUTLOOK-MAP.md (proposal, code nahi) bana; 3 faisle pending.
- 22 Oct 07:55 STAGE: #3 GREEN. M-series (Outlook mail features M1–M7) ledger mein likhi (MASTER-GAP-LEDGER bottom + MAIL-OUTLOOK-MAP.md), code nahi. Ab: Outlook (naumankhansherwani@outlook.com) se invite Accept test (extra saboot), phir B-series: B6 portal P2 + B7 #4–#8 + B8. Pending founder: 4 portal faisle, 3 M-faisle.
- 22 Oct 08:00 founder poochha M-series calendar se connected? JAWAB: NAHI, alag. Calendar 4/9 GREEN (#0-#3). Ab calendar #4 (world-clock pins, team overlay free/busy, ICS subscribe) shuru.
- 22 Oct 08:20 #4a world-clock pins code ready (locale_core clocks_ok, locale_glue clocks key, WorldClocks.tsx). Server: Rust locale reinstall (MODULES="locale") + web pull, phir live check (Globe button next to clock). Sandbox browser harness (vite) nahi chala (TanStack start) — live Chrome check baad mein.
- 22 Oct 08:25 founder ne futuristic World Clock spec diya: docs/claude/WORLD-CLOCK-BLUEPRINT.md (verdict+phases W0–W5). Jhoote claims (fatigue -30%, QUIC latency p95, flight tracking, bank clearing banner) NAHI; baqi progressive HAAN. 3 faisle pending.

## 22 Oct 08:25 — #4a LIVE BUG mila aur fix (Rule 29)
- Server par Rust locale + web pull OK. Live check: Globe button aaya, lekin pin par "Could not save preference". Wajah: E58 ka DB validator `awam_ui_extra_ok` sirf 3 keys maanta tha, `clocks` DB ne reject kiya (Rust 500). Fix: SQL E61_world_clocks (validator mein clocks, Rust ka mirror) + CHECK_E61. Sandbox: 9/9 ok, dobara chalana safe.
- Command (SQL): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E61_world_clocks CHECK_E61`
- Outlook proof: mail.log 02:53 UTC (07:53 PKT) `to=<naumankhansherwani@outlook.com> relay=outlook-com.olc.protection.outlook.com status=sent (250 2.6.0 Queued mail for delivery)` — Outlook ne qubool ki; inbox mein nahi dikha = Outlook ki taraf filtering, hamara masla nahi.
- Founder ne World Clock ke 3 faisle mujh par chhode: fatigue sach-ghantay, travelling opt-in, market chip default OFF.
- 22 Oct 08:25 founder: World Clock ke sab features banenge 'awam ko sach ke saath' — plan WORLD-CLOCK-BLUEPRINT.md (F1–F5). Pehle E61 SQL (pin save fix) chale.
- 22 Oct 08:40 E61 server OK 9/9; live: Zurich pin save + reload OK. Founder ne Focus Ring, Slipstream(opt-in), Market chip faisle diye; mera note: location inference nahi, user-entered.
- 22 Oct 08:45 CURRENT WORK (compact-safe): W1 = calendar #4b Overlap Matrix (SQL E62 + Rust team_core/team_glue team.overlap + web slider + dashboard card). Founder order: SQL super-advanced, self-read 3x before handing over. Sandbox first, then server commands SQL->Rust->Web.

## 22 Oct 08:55 — W1 Overlap Matrix (calendar #4b) CODE READY — server par 3 commands, is tarteeb se (SQL -> Rust -> Web)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E62_team_overlap CHECK_E62`
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && MODULES="overlap" bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
Kya: SQL E62 (privacy deewar DB mein: viewer same-org ka zinda member ho; sirf apna likha schedule; OOO note kabhi nahi) · Rust `calendar.overlap` (green/amber/red matrix, best times, sach-ghantay) · Web: New meeting > "Find a time" mein "Everyone's hours" slider + dashboard "Team time" card. Koi package gate nahi (sab + family ek jaisa).
Sandbox saboot: SQL proof 15/15 (2 baar chala), CHECK 7/7; Rust 21 tests (core 15 + glue 5 + cal_core), cargo check OK, installer patch idempotent; web tsc clean + tier-guard pass + 390/820/1440 screenshot (mock engine).

## 22 Oct 09:15 — W1 LIVE BUG + fix (Rule 29): "Could not load team availability" (HTTP 500)
- Server par SQL E62 + Rust overlap + web sab OK chale; live par matrix 500. Wajah (sandbox mein bina-haq role se dobara bana kar pakdi): E62 ka naya fallback `auth.users` padhta tha; live `service_role` ko `auth` schema ka haq nahi => function crash. Fix: usi E62 file mein haq pehle check (`has_schema_privilege` + `has_column_privilege`), na ho to qadam chhod do. Proof 16/16 (naya test: bina auth haq wala role), CHECK 8/8 (naya LIVE PATH check asli member par chalta hai).
- Sirf yeh ek command chahiye (Rust dobara NAHI; glue mein sirf error-log izafa hua, agle Rust install par jayega):
  `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E62_team_overlap CHECK_E62`

## 22 Oct 09:30 — W1 LIVE: matrix CHALTI HAI (E62 fix ke baad). Live dekha: You + Test Visitor (Karachi) + Outlook guest ("zone unknown", kaali patti), best-time chips, slider, "Use this time". 2 sach-wali kami mili aur theek ki:
- Zone-unknown banda hone par bhi chip "everyone in their day" likhta tha -> ab "(1 zone unknown)" / "Good for everyone with a known zone".
- Teen suggestions paas-paas (9:30, 10:00, 10:30) -> ab kam az kam 3 ghante ke faasle par (core test + 54 tests green).
- Server par (Rust phir Web; SQL dobara nahi):
  1. `git -C /opt/anexomail-web fetch -q origin main && MODULES="overlap" bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
  2. `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
- Baqi live check: dashboard "Team time" card (2+ members wala workspace chahiye), 390/820 asli browser par.

### 22 Oct 2026 — Rust installer: galat rollback line RETIRED
Founder: "(cd /opt/anexomail-rust && cargo build --release) && pm2 restart ... wrong hai, har bar aati hai, sahi wali do".
Wajah: purani line shared `cal_core.rs` ko `rm -f` karti thi aur zabardasti rebuild. Ab `rust-engine-install.sh` har run par `/root/rust-rollback-<stamp>.sh` banata hai (backup se main.rs + module files wapas, backup binary ya rebuild, pm2 restart, health curl). Wapas lene ki EK command: `bash /root/rust-rollback-<stamp>.sh` (installer khud chhapta hai). Kuch na badla ho to "wapas lene ki zaroorat nahi" chhapta hai.

### 22 Oct 2026 09:40 PKT — web pull OK, calendar blueprint likha
Pull: build OK, /health 200, server==repo 513 differ=0. Likha: `docs/claude/CALENDAR-BLUEPRINT.md` (access model Rule 37/40, sirf-GREEN feature table, landing copy draft, #9 outcome colours, #10 history search). Roadmap mein #9/#10 jode. Landing/plans par copy abhi LAGI NAHI (founder "haan" ka intezar). Aglu: W1 live check.

### 22 Oct 2026 09:24 PKT — founder faisla: calendar abhi UNLIMITED, limits baad mein
Basic ko itna do ke deewane ho jayen; abhi sab unlimited banao; kis package ko kitna — baad mein Claude ke mashware se. Detail: docs/claude/CALENDAR-BLUEPRINT.md §1b.

### 22 Oct 2026 09:26 PKT — TARTEEB lock: Calendar+WorldClock -> M-series -> billing portal G16
Detail CALENDAR-ROADMAP.md "TARTEEB". M-series aur G16 ke faislay tab poochhe jayenge jab un ki baari aaye.

### 22 Oct 2026 09:50 PKT — #4b GREEN, calendar copy live, shaam ka kaam #9
Founder: "yeh green kero (members banana practical nahi), copy haan, next kaam sirf shaam ko". Web pull OK 254 restarts, server==repo 513. #4b GREEN. Copy: index.tsx Calendar card + plans.ts line "Contacts & full calendar..." (web pull baaki, founder shaam ko chalaye). SHAAM: #9 outcome colours (E63 SQL -> Rust -> Web), phir #10 history search, W2 Focus Ring.

### 22 Oct 2026 10:30 PKT — #9 outcome colours CODE READY (server install baaki)
Founder: "#9 shuru kero". Bana: E63 SQL (goal, goal_state, goal_state_at; 13/13 sandbox proof, CHECK 8 items), Rust cal (goal fields in calendar.meta.set; 41 core tests), Web (EventDetail "Aim" + Achieved/Missed/Reopen, dot on week grid + month list; red NOW-line wahi red).
Server (alag alag, tarteeb yahi):
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E63_event_goal CHECK_E63`
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && MODULES="cal" bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
Phir Ctrl+Shift+R, calendar mein ek meeting kholo -> "Aim" likho -> shuru hone ke baad Achieved/Missed.

#### 22 Oct 10:50 — Aim 2000 harf, multi-line (founder ki darkhwast). Server commands upar wali 3 hi hain (E63 abhi chali nahi thi, isliye wahi file; SQL -> Rust cal -> Web).

### 22 Oct 2026 09:50 PKT — STANDING: har naye commit ke saath pull/server commands HAMESHA do
Founder: "pull commands new commits ke saath hamesha do". Har push ke baad jawab mein: commit hash + jo server commands us commit ke liye chahiye (SQL -> Rust -> Web, alag alag, sirf wohi jo us commit mein badla). Sirf docs badle to bhi likho "server command nahi chahiye". Is waqt latest: 9ea4a5d (E63 SQL, Rust cal, Web).

### 22 Oct 2026 09:55 PKT — SQL Supabase editor mein paste: pehla character kat jata hai
Founder ne E63 editor mein paste ki: `LINE 1: - E63` (pehla `-` kat gaya). Hal: har nayi SQL file ki pehli line KHALI (blank) — kata hua pehla char newline hi hota hai, comment salamat. E63_event_goal + CHECK_E63 par laga, "pehla char gum" simulation psql mein bhi chala (OK). Purani files (E62 etc.) already chal chuki hain. Server par `sql-run.sh` ab bhi behtar raasta hai, par editor bhi chalega.

### 22 Oct 2026 10:05 PKT — E63 duniya-ke-advance level par (Rule 38, teen baar padha)
Founder: "duniya ka advance sql likho, yeh rule hai E63". Badla (sirf E63_event_goal.sql + CHECK_E63.sql; Rust/Web wahi): PREFLIGHT (PG>=11, column type guard) · EK ALTER teeno columns + LOCK RETRY (3s x 6, badhta intezaar; sandbox mein 6s ke lock ke saamne khud dobara koshish kar ke kamyab) · TEEN alag constraints (goal_ck, goal_state_ck, goal_state_at_ck) NOT VALID->VALIDATE · POST-CONDITION self-check script ke aakhir mein · wapas lene ka tareeqa comment mein · export (E44 to_jsonb) apne-aap covered. Sandbox: saaf DB par 2 baar chali OK, wrong-type preflight reject, lock contention OK, CHECK 9/9, proofs 14/14, "pehla char gum" simulation 0 error.
Server: SQL command wahi (E63_event_goal CHECK_E63); naya commit hash neeche jawab mein. Rust/Web commands wahi.

### 22 Oct 2026 10:06 PKT — Rule 42: SQL server AUR Supabase editor dono mein
AGENTS.md Rule 42 + `docs/cursor-work/server/sql-editor-lint.py` (pehli line khali, psql meta-command nahi, CONCURRENTLY/VACUUM nahi, apna BEGIN/COMMIT nahi, CHECK = ek SELECT). E63 + CHECK_E63 lint OK. Server command koi nayi nahi.

### 22 Oct 2026 10:15 PKT — founder: 'saab green hai'. Chrome live: /plans par nayi copy, #9 Aim save/Achieved/reload/Reopen/clear OK. Sab GREEN mark + DONE-DO-NOT-REPEAT. Server command koi nayi nahi. Founder so gaya (16 ghante kaam ke baad); agla kaam #10 history search.

### 22 Oct 2026 10:12 PKT — NEXT-TASKS.md bana (tarteeb: #10 history search -> W2 Focus Ring -> #4c -> #5 -> W3/4/5 -> #6 -> #7 -> #8 -> M-series -> G16). Naya chat pehle yeh padhe.

### 22 Oct 2026 19:40 PKT — #10 History search SHURU (founder: "kaam shuru kero")
Compact ho jaye to: NEXT-TASKS.md ka ">>> ABHI CHAL RAHA HAI <<<" hissa padho aur wahin se jaari rakho. Server commands tab aayengi jab E64 + Rust + Web push hon.

### 22 Oct 2026 20:55 PKT — #10 History search CODE READY (commit neeche), server install baaki
Bana: E64 SQL (history search, org wall, FTS+trigram, date/person filters; 32 proofs, CHECK 10 items) · Rust `calendar.history` (cal_glue + cal_core, 42 tests) · Web `/app/search` mein "Meetings & history" + calendar deep link. Server (alag alag, tarteeb yahi):
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) E64_history_search CHECK_E64`   (editor mein bhi chalegi: repo se file dobara copy)
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && MODULES="cal" bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 22 Oct 21:45 — identity vault ADMIN (E68) — ban/appeal aapke maujooda admin se
Aap ka kaam: **kuch naya nahi**. Account integrity panel mein Block dabao => us account ke sab hash blacklist (2 saal; fraud/severe hamesha). Release dabao => ban hat (severe nahi). Naya "Identity vault" hissa: hisaab + jinhe signup par roka gaya unki review (Allow sign-up / Keep block).
Commands (is tarteeb mein): 1) SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`  2) Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`  3) Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## Rule: Rust restart + health (22 Oct 22:17) — Rust install ke baad hamesha
pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
(200 chahiye.) Tarteeb: SQL -> Rust install -> yeh restart+health -> Brain installer (agar Bun badla) -> Web pull.

## Rule 46 (aeen) — tarteeb: 1 SQL -> 2 Rust install -> 3 Rust restart+health -> 4 Brain installer (agar Bun badla) -> 5 Web pull. Sirf badli hui technology ke steps. (AGENTS.md Rule 46)

## 22 Oct 22:45 — ABHI BAAQI (founder ke liye, tarteeb): 1) Brain installer (brain-identity-install.sh, poori command NEXT-TASKS.md mein) 2) Web pull + Ctrl+Shift+R 3) sign-out/sign-in (main live dekhunga). Phir agent #2 W2 Focus Ring.

## 23 Oct 02:01 — ZABAN + COMPACT (Rule 47)
Founder: "yeh englishmain kya baqwas kerta hai mere saath ... compact chat ka gandu rule read kero aur jo abhi tak codes likhe hain woh repo main update kero". Hukm: hamesha Roman Urdu; sab halat repo mein (AGENTS.md Rule 47, CLAUDE-CHAT-CONTEXT session log, DONE-DO-NOT-REPEAT, NEXT-TASKS).

## 23 Oct — #4c ICS subscribe (E73) — server par BAAQI (Rule 46, alag alag)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Rust restart+health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R.


## 23 Oct 02:36 — T-SERIES HAAN
Founder (verbatim): "T8 ko duniya ki latest technology do. meri haan hai sab pe. repo update". T1..T11 sab manzoor (docs/claude/T-SERIES-BLUEPRINT.md). T8 = journald JSON stream + Message-ID<->queue-id + RFC 3461/3464 DSN + TLS status, pehle T8-0 probe (sirf padhna). Tarteeb: locked order (calendar+world clock -> founder account -> 6 live tests -> M-series -> G16) ke baad; T1/T2 G16 se pehle ho sakte hain.


## 23 Oct — #5 meeting par files (E74) — server par BAAQI (Rule 46, alag alag, is tarteeb se)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`   (E74 + CHECK_E74 khud; E48 pehle se hai)
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`   (naya module `calfile`; cargo test + build + rollback)
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`  (200)
4. Brain: nahi (server/*.ts nahi badla).
5. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R.
Live check (Chrome, final look): meeting kholo > Files > Add file (PDF) > list mein aaye > download ho > Remove > list se gayi. Guest (workspace member) ko sirf dekhna/download, Add file nahi dikhna chahiye.

## 23 Oct — Home city (Lahore detect) + adaptive greeting — server par BAAQI (Rule 46, alag alag)
1. SQL (ZAROORI — pehle 'nahi' likha tha, ghalat): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)` (E75 chalega). Rust/Web pehle hi live hain.
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`   (locale module: naya `home` key, test ke saath)
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`  (200)
4. Brain: nahi.
5. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Ctrl+Shift+R.
Live check: Settings > Personal > Home city > "Detect my city" (browser ijazat poochega) ya search "Lahore" > save > dashboard greeting + calendar clock ka naam.

## 23 Oct — Test-vs-real loophole (E76) — server par BAAQI (Rule 46, ek ek karke, is tarteeb se)
1. SQL (pehle): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`  (E76; NOTICE mein registry ke test emails dikhenge)
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Brain: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-registry.sh)`
5. Web: nahi (src/ nahi badla).

## 23 Oct — Home city UI theek (card ab baaqi settings jaisa) — server par BAAQI
1. SQL: nahi. 2. Rust: nahi. 3. Brain: nahi.
4. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Ctrl+Shift+R. Live check: Settings > Personal > Home city ab "Undo send window" ke neeche usi glass card style mein.

## 23 Oct — Naya test account banana (editor mein seedha) — jab zaroorat ho
Supabase SQL editor mein `docs/cursor-work/sql/tools/create_test_account.sql` kholo, sirf aakhri `select` ki 6 values badlo, Run. (E28/E36 editor mein NAHI — woh psql scripts hain, server script se chalti hain.) Pehle E76 chali ho.

## 23 Oct — Calendar kitna green? (server se, sirf padhta hai, kuch badalta nahi)
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/calendar-status.sh)`
Output: 13 hisse (#4a/#4b/#4c alag) — DEPLOYED ya NAHI, "DEPLOYED x/13", Rust health, web commit. Expected abhi: 10/13 (baaqi #6 #7 #8). Server sirf deploy dikha sakta hai; live UI green Chrome se (CALENDAR-ROADMAP.md).

## 23 Oct — Collision warning (RSVP page par "is waqt aur meeting hai") — E77 — server par BAAQI (Rule 46, is tarteeb se)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Brain: nahi.
5. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Ctrl+Shift+R.
Live check: ek workspace member ko do overlapping meetings mein guest banao, doosri meeting ka RSVP link kholo => amber chip "You already have another meeting at this time" + waqt (title nahi).

## 23 Oct — W3 Globe (World clock popover mein day/night globe) — server par BAAQI (Rule 46: sirf Web)
1. SQL: nahi. 2. Rust: nahi. 3. Brain: nahi.
4. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Ctrl+Shift+R.
Live check: /app/calendar > toolbar ka globe icon > popover mein globe (din/raat, pins, drag se ghoomta, "Face <city>" button).

## 23 Oct — W4 (device clock badge + connection numbers + Travelling opt-in) — E78 — server par BAAQI (Rule 46, is tarteeb se)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`  (E78 + CHECK_E78 4/4 OK chahiye)
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`  (locale 11 tests; aakhir mein "time.now (public) ... "ms"" line)
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`  (200)
4. Brain: nahi (server/*.ts nahi badla).
5. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6` phir Ctrl+Shift+R.
Live check: /app/calendar > globe icon > popover: "Clock & connection" card (in sync ± ms, typical/slowest ms, HTTP/3), "Travelling" > Add a trip (destination, leaves, arrives) > globe par dashed line + pink pin, "In transit" par globe button par plane icon, reminder pop-ups ruk jate hain, mail nahi.

## W5 (23 Oct 2026) — Billing deadline card + Market hours chip (default OFF). Commit: neeche git log. Brain NAHI chahiye.
Rule 46 tarteeb: SQL -> Rust -> Rust restart+health -> Web -> Ctrl+Shift+R.
1) SQL (E79 + CHECK_E79 4/4):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2) Rust install (locale: clean_market):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3) Rust restart + health (200):
`pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4) Web:
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## CalDAV #6 C1 (23 Oct 2026) — phone/desktop calendar app mein apne ANEXOMAIL events (SIRF PADHNA). Commit: neeche git log.
Rule 46 tarteeb: SQL -> pepper -> Rust -> Rust restart+health -> Caddy (plan, phir apply) -> Web. Brain NAHI chahiye. Caddy ka "haan" aap de chuke hain (23 Oct).
1) SQL (E80 + CHECK_E80 5/5):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2) Pepper (app password ke hash ka server-side raaz; ek baar; pehle se ho to kuch nahi badalta):
`grep -q '^CALDAV_PEPPER=' /opt/anexomail-rust/.env && echo "pepper pehle se hai" || { echo "CALDAV_PEPPER=$(openssl rand -hex 24)" >> /opt/anexomail-rust/.env && echo "pepper laga diya"; }`
3) Rust install (naya module dav: dav_core tests server par chalte hain, phir build; fail par purani binary wapas):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
4) Rust restart + health (200):
`pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
5) Caddy — PEHLE PLAN (kuch nahi badalta, sirf dikhata hai aur copy par validate karta hai):
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)`
   Phir plan theek lage to APPLY (backup, validate, reload, test, fail par rollback; HTTP/3 ko haath nahi):
`MODE=apply bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)`
6) Web:
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
Phir Ctrl+Shift+R. Calendar -> Settings -> "Phone calendar" -> "Create password" (chaabi sirf ek baar dikhti hai).
SACH: sirf padhna (PUT/DELETE/MKCOL 405). Ek calendar "ANEXOMAIL": wahi meetings jin ke aap organiser ya guest hain. Phone par banayi meeting wapas nahi aati (C2). iPhone/Mac built-in, Android ko DAVx5 chahiye.
- 23 Oct 08:22 CalDAV: SQL E80 GREEN, Rust dav module build OK, Caddy apply OK (well-known 301, PROPFIND bina login 401). OPTIONS par DAV header nahi dikha -> read-only check: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caldav-check.sh)`

## 23 Oct 08:40 — Calendar (Classic) phone/tablet fix: rows ab wrap hoti hain, page chauda nahi hota — SIRF Web (SQL/Rust/Caddy nahi)
Founder ka screenshot: Month grid ka SUN column aur "Today"/"24h"/"Load" kat rahe the (bade phone font par "Month·Week·Day + Avail.·Load" row wrap nahi hoti thi). Fix: CalendarClassic rows wrap + min-w-0, month cell min-w-0, Panel body overflow-x-hidden. Pinch-zoom pehle se allowed hai (viewport mein maximum-scale nahi).
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R (phone par bhi).

## 23 Oct 08:55 — Mail kholne par "Something went wrong" (refresh par khulti) — SIRF Web
Is Pro account par 5/5 threads theek khulte hain (390 px par bhi, console saaf) — aap ke account ka asli error abhi nahi mila. Pakka kamzor hissa band kiya: thread page `to/cc/attachments` par seedha `.length` lagata tha; ab `normalizeThread` (lib/mail.ts) khali/null lists ko [] banata hai, aur waqti ghalti (401/5xx/network) par 2 baar khud retry. Agar ab bhi aaye: screenshot + kaun si mail (subject) + kaun sa account.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R.

## 23 Oct 09:00 — Calendar PHONE redesign (Classic): toolbar 4 patti -> compact — SIRF Web
Founder: "mobile pe saans nahi aa raha". Ab phone (<640 px): header mein sirf "⋯" menu (Layout/Settings/Booking/Import/Export + Clock 12h/24h + Availability/Load, har button 44 px) aur "+ Meeting"; clock row mein sirf waqt + globe; nav row ‹ › mahina Today (44 px); Month/Week/Day poori chaudai ka 3-hissa switch (44 px). sm se upar pehle jaisa.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir phone par page dobara kholein (Ctrl+Shift+R / pull-to-refresh).

## 23 Oct 09:05 — Calendar phone: panel poori chaudai (dayin taraf khali patta band) — SIRF Web
Screenshot: toolbar theek, lekin panel ~70% chaudai par tha (overflow-x-hidden ke baad panel ko `w-full` nahi tha). Fix: ListPanel (non-wide) ko phone par `w-full`.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir page dobara kholein.

## 23 Oct 09:15 — Phone: upar se neeche kheench kar refresh (pull-to-refresh) — SIRF Web
Founder: "touch press kar ke upar se neeche drag karte hain to refresh hota hai — yahan nahi hota". Wajah: browser ka PTR shell mein jaan-boojh kar band tha (poora reload draft kho deta tha). Ab app ka apna: `PullRefresh.tsx` + `lib/pull-refresh.ts` — sirf DATA taza (queries refetch + router invalidate), page reload NAHI, draft salamat. Sirf touch (pointer: coarse); jab koi scroll dabba neeche scrolled ho, ya input/editor/dialog ke andar, tab nahi. 72 px (resistance ke baad) kheencho aur chhodo.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir phone par page dobara kholein.

## 23 Oct 09:40 — Phone: Text size + scroll bar + zoom ke saath pull-to-refresh theek — SIRF Web
Founder: "screen adaptive ho, zoom jitna chahiye; scroll bar aaye; ek hi baar theek". (1) Settings -> Appearance -> **Text size** (Default/90/115/130/150%): sab text (800+ px-literal samet) badalta hai, har device par yaad rehta hai, har page par lagta hai. (2) Touch screen par scroll bar nazar aata hai. (3) Pinch-zoom hamesha chalta hai (viewport meta saaf); zoomed halat mein pull-to-refresh band. (4) CSS `zoom` jaan-boojh kar nahi lagaya (live test mein popover khisak gaya). Qaide ek jagah: `docs/cursor-work/MOBILE-CONTRACT.md`.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir phone par dobara kholein.

## 23 Oct 09:30 — Zoom SIRF jahan zaroorat: mail padhne ki body + calendar ghante ki unchai — SIRF Web
Founder: "zoom in/out jahan zaroorat wahan, jahan nahi wahan nahi". CEO faisla: (1) Mail thread header mein `− 100% +` (body 85–175%, sirf mail ki body, iframe ke andar; baaqi app par asar nahi); (2) Calendar Week/Day ke upar "Hour height − 52px +" (36/52/72/96). Dashboard/lists/settings par koi zoom button nahi (wahan Settings -> Appearance -> Text size + pinch). Har choice device par yaad rehti hai.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir phone par dobara kholein.

## 23 Oct 10:00 — Pull-to-refresh ab ASLI reload karta hai — SIRF Web
Pehle sirf data refetch hota tha (spinner ghoomta, kuch badalta nahi dikhta). Ab neeche kheencho -> page ka asli reload (naya deploy bhi aa jata hai). Agar koi likha hua draft/compose khula hai to reload NAHI hota (draft bachane ke liye), sirf data taza hota hai.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir phone par dobara kholein.

## 23 Oct 10:15 — World clocks globe par scroll atakna theek — SIRF Web
Globe `touch-none` tha, isliye popover mein globe par ungli rakh kar upar scroll nahi hota tha. Ab seedha (upar-neeche) swipe scroll karta hai, daayen-baayen drag globe ghumata hai.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 10:30 — Settings slow: har setting ki history ek-ek request thi — SIRF Web
Settings page khulte hi har row apni history alag server se maangti thi (N+1 requests) jab ke dikhti sirf "History" dabane par. Ab sirf tab maangti hai. Settings -> History page waisa hi.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 10:45 — Phone/tablet par pakadne wala scroll bar — SIRF Web
Android ka apna bar pakad kar chalta nahi. Ab right edge par ek handle hai (scroll karte hi nazar aata hai, halka sa tika rehta hai): usay ungli se pakad kar upar-neeche ghumao to poora page us jagah chala jata hai. Baaqi page par kahin bhi (center/corner) seedha swipe pehle jaisa scroll karta hai. Sirf touch screen par.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 10:05 — Settings card ka text ek-ek lafz wali patli patti nahi rahegi — SIRF Web
Phone par setting card mein text column buttons ne dabaa diya tha (ek line mein ek lafz). Ab text ko kam az kam 15rem milta hai aur Explain/Blast radius/History buttons neeche wrap hote hain. Live 390px par check kiya: text 298px chauda.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 10:20 — Calendar settings ab "⋯" menu mein, Meeting ke saath — SIRF Web
Toolbar mein alag slider icon nahi. Har screen (phone/tablet/laptop) par Meeting ke baad ek "⋯" button; usme "Calendar settings" (naam ke saath), layout, booking, import, export, clock, Availability/Load.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 10:30 — Phone calendar mein "How to connect" (Android/iPhone/Computer) — SIRF Web
Founder ne anexomail.com/dav/ browser mein khola to "Sign in with your email and a CalDAV app password" dikha — yeh SAHI hai (server zinda, link apps ke liye hai). Ab Settings -> Phone calendar mein saaf steps + "Link" (https://anexomail.com/dav/) copy button aate hain, aam user ko guess nahi karna.
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 23 Oct 11:55 — Calendar link (bina app, Google Calendar mein) + A (Calendar app) dono — SQL -> Rust -> Caddy -> Web
Founder hukm: "user ko A bhi do (jo ameer/tech-savvy), B bhi (baqi) — advance codes, SQL sab, review". B = secret read-only link `https://anexomail.com/dav/feed/<30 akshar>.ics` Google Calendar mein "URL se jodein". A = purana CalDAV app (DAVx5 F-Droid par free, Play par paid / iPhone / Thunderbird). Settings -> Phone calendar mein ab upar do tab hain, default "No app (Google Calendar)".
Honest: Google subscribe 12–24 ghante mein refresh karta hai (naya meeting der se), sirf-padhna. Link password jaisa hai, ek baar dikhta hai, Remove se foran band.
**Tarteeb (Rule 46), har ek alag, ek ke baad ek:**
1. SQL (E81, CHECK_E81 khud): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`   (aakhir mein E81 CHECK 6 t)
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`   (dav tests 17 passed, build OK; compile fail par khud purana wapas)
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`   (200)
4. Caddy (link ka URL Caddy log mein na likha jaye — `log_skip`): pehle PLAN: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)`  (UPGRADE + "validate OK" chahiye) phir `MODE=apply bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/caddy-caldav.sh)`
5. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R.
Test: Calendar -> "⋯" -> Calendar settings -> Phone calendar -> "No app" -> Create link -> "Add to Google Calendar" (ya calendar.google.com -> Other calendars -> From URL). Link kaam karta hai ya nahi (server taraf): browser mein link kholne par .ics download/dikhna chahiye.

## 23 Oct 12:20 — Calendar link/CalDAV: bade user ke SAARE meetings (cap khatam) — SIRF Rust
Founder: "2000 wali had user ka masla nahi, premium experience do". Pehle `limit=2000` aur PostgREST ka server-cap (aksar 1000) meetings chupke kaat deta tha, aur `in.(…)` ke URL ka lamba hona alag khatra tha. Ab page-dar-page (1000/page, 30 page tak), id 60-60 ke chunk mein, guests/exceptions HashMap se. Harness: 2600 apne + 150 bulaye hue meeting, backend 1000-cap ke saath => 2750 mein se 2750 feed mein (pehle/aakhri samet).
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
(SQL, Caddy, Web ka koi naya kaam nahi; 23 Oct 11:55 wale teeno aap ne chala diye — sab GREEN.)

## 23 Oct 12:55 — Calendar link LIVE GREEN
Google Calendar mein "ANEXOMAIL" jud gayi, meetings dikhe. Phone par: Google Calendar app (wahi Google account) -> menu -> Settings -> ANEXOMAIL on. Koi naya server command nahi.

## 23 Oct 14:30 — Calendar #8 ROOMS (meeting room / resource) — SQL -> Rust -> Rust restart -> Web
Room ek pseudo-guest hai (`room-xxxx@rooms.anexomail.com`); book karne se meeting mein judta hai, aur wohi conflict engine dusri booking `room_busy` se rok deta hai (race-safe, advisory lock). Rooms ko KABHI mail nahi jati. Banana/hatana sirf owner/admin; book/release sirf meeting ka organiser. Room ki schedule mein sirf waqt + organiser (title nahi).
1. SQL (E82, CHECK_E82 khud, 6 t): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2. Rust (rooms module + invite skip; 4 tests): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`  phir Ctrl+Shift+R.
Test: Calendar -> "⋯" -> Calendar settings -> "Rooms & resources" -> naam likh kar Add. Phir koi meeting kholo -> "Room" section -> Book. Dusri overlapping meeting mein wohi room "Busy" dikhna chahiye.

## 24 Oct 14:35 — Rooms fix: Release par auto-location saaf — SIRF SQL
Live test mein mila: room book karne se meeting ki jagah "Test room" likhi jati hai, par Release ke baad woh rehti thi. Ab Release us auto-likhi jagah ko hata deti hai (apni likhi jagah nahi chhedti). SQL E82 ki sha badli hai to AUTO dobara chalayegi (idempotent).
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`

## 24 Oct 14:45 — Rooms fix 2: room "guest" ki tarah na dikhe/na gine — SIRF Web
Live test mein mila: booked room meeting ki Guests list mein "room-xxxx@rooms.anexomail.com — Yes" aur guest ginti (3) mein aa raha tha. Ab room guest list, ginti, local-time bar mein nahi aata (sirf "Room" section mein dikhta hai).
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 24 Oct 15:05 — Rooms fix 3 (DB guard): room ko koi bhi raste se double-book na kar sake — SQL -> Rust -> restart
Loophole: (a) guest ki jagah room ka address haath se likhna, (b) booked meeting ko aisay waqt par reschedule/drag karna jahan room doosri meeting ke paas ho — dono `calendar_room_book` se nahi guzarte the. Ab database trigger (E83) har raste par roke: `room_busy` (aur anjaan/archive/doosri-org room par `no_room`). Rust is error ko 409 "A booked room is already taken at that time" banata hai. Honest haad: repeat meeting ka sirf pehla slot check hota hai.
1. SQL (E83 + CHECK_E83 3 t): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
2. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
(Web pull 14:45 wala pehle na chalaya ho to woh bhi.)

## 24 Oct 15:30 — Rooms fix 4 (live test E83 ke baad): room ko guest ki tarah likhne par saaf jawab — Rust + Web
Live (E83 ke baad): guest box mein room ka address likh kar meeting banai to DB ne double-booking ROKI (sahi) par jawab sirf "Calendar failed" tha. Ab Web room address ko guest nahi manta (peeli ek line: "Create the meeting, then book the room in its Room section"), aur Rust create/reschedule par saaf 409 "A booked room is already taken at that time" deta hai.
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
3. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 24 Oct 16:05 — Rooms fix 5 (E84): repeat meeting ke SAARE occurrences room par check — SIRF Rust
Haad band: pehle sirf pehla slot check hota tha. Ab book karte waqt aur repeat meeting ka waqt/rule badalte waqt agle 400 din ke har occurrence ko us room par doosri meeting/series ke occurrence se milaya jata hai (takrao => 409 "A booked room is already taken at that time"). Koi SQL ya Web nahi. Rooms module ab cal module par bhi nirbhar (installer khud `mod` jodta hai).
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`   (cal tests ab 43; build fail par khud purana wapas)
2. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
Honest haad: do log EK SAATH series book karein to ek lamhe ka window hai (pehla slot DB-lock se safe hai; baqi occurrences Rust check); 400 din se aage ke occurrences check nahi.

## 24 Oct 16:25 — PRO audit fixes: Snooze (enum bug), Snoozed view, templates UI, thread notes, domain wording — Rust + Web
Live Pro test mein Snooze "invalid input value for enum mail_folder: snoozed" se fail hota tha. Ab snooze sirf snoozed_until set karta hai (folder nahi badalta), Inbox future-snoozed threads chhupata hai (Rust + Bun), aur naya "Snoozed" view un ko dikhata hai (wahan se "Bring it back"). Saath: Pro templates (save/remove) UI + server limits, thread private note, notes 20000 cap, domain "1 domain" wording. Snooze + templates ab Rust PRIMARY (mail.snooze, mail.templates.save/delete), Bun sirf fallback. Server par Pro gate bhi: Basic user ab snooze/schedule send/templates API se nahi chala sakta. Koi SQL nahi.
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
3. Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 24 Oct 18:20 — M1 fix (live test mein pakda): naye Rust procs server tak pahunche hi nahi the — ab `mailx` module — Rust (2 installer) , Web NAHI
Live: /rpc/mail.snooze 404 tha (installer live main.rs replace nahi karta, sirf module jodta hai). Ab Pro mail actions `mailx_core.rs`+`mailx_glue.rs` module mein (snooze, status, move, labels, assign + naam/email lookup, templates save/delete, `mail.threads` jo Inbox se future-snoozed chhupata hai aur "Snoozed" folder deta hai). Schedule send ka Pro gate `mail_glue.rs` mein (alag installer). Koi SQL nahi, Web pull nahi (client pehle se pull hai). Bun (Brain) ka purana code alag install se jata hai (4).
1. Rust engine (mailx): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Rust mail (schedule gate; asli Postfix saboot chalata hai): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-mail-install.sh)`
3. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Brain = Bun fallback (galat date par crash band, Pro gates, validation, templates, thread-note limit): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pro-install.sh)`

## 24 Oct 18:50 — Bun (Brain) drift check — READ-ONLY, kuch nahi badalta
Kaun si Bun file repo se alag chal rahi hai (yani kabhi live nahi gayi):
`bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-drift-check.sh)`

## 24 Oct 19:20 — M1 LIVE (Pro): snooze/Snoozed/status/move/labels/templates GREEN. 2 loophole mile, fix tayyar — SQL + Rust + Brain + Web
Live (pro.buyer): Snooze 200 (Rust), Inbox se chhupa, Snoozed folder "in 2h", status/move/labels/templates + galat input 400, doosre org ka thread 404. MILA: (1) **Assign (Shared inbox) Rust aur Bun dono par fail**: DB mein mail_thread_assign ke 2 overloads (PGRST203) — E85 ek function, null = hatao, sirf active member. (2) Snooze menu mein "Bring it back" sirf ek heading thi, wapas lane ka koi button nahi — ab "Bring back now" asli item.
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`   (E85 + CHECK_E85)
2. Rust engine (mailx assign): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Brain (Bun fallback, assign): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-pro-install.sh)`
5. Web (Bring back now): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 26 Oct 08:20 — E89 Analytics (SQL+Rust) + WASM KERNEL 0.2.0 + wt-rpc + MFA/flat pricing — DEPLOY (tareeb: SQL -> Rust -> Web)
1. SQL: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`   (E89 + CHECK_E89)
2. Rust (analytics + wtrpc modules, koi argument nahi): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
3. Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
4. Web (kernel wasm + MFA + analytics fallback): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 26 Oct 09:00 — E90 KERNEL CONSTITUTION (SQL) + Rust (kernel.ticket/report, billing.revenueTruth, meeting cost) + Web — tarteeb SQL -> Rust -> Web
SQL (E89 + E90 + CHECK_E89/E90 khud auto-pick): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
Restart: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
Web: `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 26 Oct 09:10 — KERNEL CHECK (deploy ke BAAD, sirf padhta hai): Rust WebTransport live? udp/3443? cert? kernel wasm hash pin se mila? kernel.report maujood?
`git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh)`
(Agar kabhi CSP lagayi jaye to script-src mein 'wasm-unsafe-eval' lazmi, warna kernel load nahi hoga — fetch fallback chalega.)

## 26 Oct 09:15 — BRAIN (Bun fallback) — MFA / analytics fallback / flat pricing live karo (live test mein Two-step "Status unavailable" = Brain mein routes nahi). Koi SQL nahi.
`bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-kernel-install.sh)`
Phir Web (kernel diagnostics anexoKernel + 401 guard): `bash <(git -C /opt/anexomail-web fetch -q origin main && git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`

## 26 Oct 09:20 — BRAIN dobara (sirf analytics fallback guroh A: live index.ts mein mount nahi laga tha; ab 3-line anchor patch). MFA (guroh B) pehle se live. Koi SQL/Web nahi.
`bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-kernel-install.sh)`
- Web pull.sh (Business 60 users / storage copy live karne ke liye): git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)

## 26 Oct 10:30 — Pro GREEN batch 1 (SQL nahi). Tarteeb: Rust phir Web
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
3. Brain (Bun fallback gate bhi): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-kernel-install.sh)`

## 26 Oct 10:45 — Pro green batch 1 + KERNEL request-tag (E91). Tarteeb SQL -> Rust -> Web (Rule 46)
0. SQL (E91 + CHECK_E91 auto, ok=t aani chahiye): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
1. Rust (upar wali Rust command hi): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
3. Saboot (read-only): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh)`


## 26 Oct 10:55 — Brain guroh C (Availability/Focus Bun gate) alag + drift report
1. Brain: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-kernel-install.sh)`  (ab guroh C = sirf calendar.ts; revenue/release guroh D alag)
2. (sirf agar guroh D "DRIFT" bole) read-only report: `bash <(git -C /opt/anexomail-web fetch -q origin main; git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-drift-report.sh)`

## 26 Oct 10:50 — Pro GREEN: workx (work.tasks / work.promises / crm.overview ab Rust Tokio par). SQL nahi. Tarteeb Rust -> Web
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`  (workx module khud judega; probe "workx: Rust ne pakda" aana chahiye)
2. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)`
(Brain group D ka drift sirf comment hai — ACCEPT_LIVE mein darj, kuch karna nahi.)

## 26 Oct 11:00 — CRM P1+P2 (pipelines, custom fields, merge, web forms) + workx. Tarteeb SQL -> Rust -> Web (Rule 46)
0. SQL (E92 + CHECK_E92 auto, ok=t aani chahiye): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
1. Rust (crmx + workx judenge): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`
2. Rust restart + health: `pm2 restart anexomail-rust --update-env && pm2 save && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health`
3. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
Phir mujhe batayein — Chrome (Pro) par live proof main khud karunga.

## 26 Oct 11:45 — CRM fix batch (pipeline edit 502, merge workspace check, layout). Tarteeb SQL -> Rust -> Web
0. SQL (E92 dobara — sha badli, khud chalegi; CHECK_E92 ok=t): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)`
0b. (Sirf agar pipeline edit phir bhi 502 de) read-only diagnostic — asli DB error dikhata hai, kuch nahi badalta: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) DIAG_crm_pipeline_update`
1. Rust: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh)`  phir restart+health (upar wali pm2 restart command)
2. Web: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | tail -6`
3. Basic probe (ab CRM procs ke 403 bhi): `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh)`
Agar 502 phir aaye: `pm2 logs anexomail-rust --lines 40 --nostream | grep crmx` ka output bhejein.

## 26 Oct 2026 19:30 PKT — GREEN ORDER STATE (compaction-safe; founder: "ek ek cheez green, tarteeb se")
Founder rule: ek item live green hone tak agla nahi. Pro CRM pehle, phir tarteeb (Business -> CRM P3-P6 (Blueprint=P4) -> Business Pro -> Enterprise).
GREEN (live, Chrome Pro): crm.pipelines.save on EXISTING pipeline (add stage 200, restore 200) after SQL+Rust redeploy; everything in 11:45 PASS list; basic-gate-probe ALL PASS incl. 17 crmx/workx 403s + public form.get 404; kernel-check ALL PASS (request-tag Observe valid=76 missing=0 invalid=0 -> ready for ANEXO_TAG_MODE=enforce, founder env change).
IN PROGRESS: merge via real UI (Setup > Duplicates > ZZ Test Lead keep, ZZ Dup drop). Confirm click was sent at 19:27 but result NOT yet verified (screenshot cancelled by founder) -> verify crm.dups.list total_groups==0 and survivor keeps company "ZZ Co"/custom values before marking green.
TODO Pro-green (order): (1) merge result; (2) "New deal" button visible after min-w-0 layout fix (screenshot /app/crm/pipeline); (3) merge keep-in-drop = 400 (needs latest Rust installed; confirm with pm2 logs grep crmx); (4) form rate limit 30/10min (throwaway Postgres or 30 posts); (5) Calendar Availability/Focus UI click-through on Pro + hourly-rate UI for meeting cost; (6) Rust ports crm.live + org.members (still kernel_status_404) + kernelRpc early-boot wait 300-400ms; (7) enforce request-tag. Business caps need a Business account.
Pending server note: pull.sh says "server==repo differ=1" (one src file differs; identify with its diff list, unresolved).
Always paste full ordered commands inline: SQL -> Rust install + pm2 restart + health -> Web pull.sh -> probes.

## 26 Oct 2026 19:40 PKT — PRO CRM P1+P2 LIVE GREEN (Chrome, Pro pro.buyer@anexomail.com; latest Rust+SQL+Web deployed)
GREEN (live): merge via real UI (Setup > Duplicates > keep ZZ Test Lead, "Yes, merge"): crm.dups.list total_groups 0; survivor 4d112ab1 keeps company "ZZ Co" and custom values (interest, zz_test_renewal, zz_test_vip); merge keep-in-drop = 400 bad_request; foreign id = 404; pipeline edit on existing pipeline 200; /app/crm/pipeline "New deal" button visible, board scrolls inside its own area (layout fix min-w-0 GREEN).
GREEN (throwaway Postgres, not live — would need 30 real leads): form rate limit — 30 submits accepted, 31st {"ok":false,"reason":"rate_limited"}.
Pro endpoints live 200 (Rust): calendar.availability {date}, calendar.focus, mail.followup/snippets/handoff.list, analytics.threadEconomics/responseDebt, work.tasks/promises, crm.overview/board/forms.list/fields.list. calendar.availability equals Bun /api/calendar/availability.
SMALL BUG (TODO): calendar.availability with EMPTY input returns 502 (should be 400 or default today) — UI always sends date so harmless; fix in cal_glue.rs availability().
STILL NOT GREEN: Business caps (needs Business account); Calendar Availability/Focus UI click-through + hourly-rate UI; crm.live + org.members Rust ports; kernelRpc early-boot wait; ANEXO_TAG_MODE enforce (founder env change); pull.sh "differ=1" file unidentified.
Test data left on Pro account: ZZ Test Lead, zz.test.fast lead, 2 ZZ TEST Deal, 5 ZZ fields, 1 ZZ form.

## 26 Oct 2026 19:50 PKT — RULE 52 jumla-ba-jumla (founder: "ek ek word green, dobara tootna nahi chahiye")
Banaya: `src/lib/kernel/rule52.test.ts` (16 guard checks + 3 todo) + `docs/cursor-work/RULE-52-PROOF.md` (18 jumle, har ka test + live saboot + status). boot.ts early-boot wait (EARLY_WAIT_MS 1200 (live naap: 400 ms kam, QUIC handshake zyada), `kernelForCall`) — READY (Web pull + Chrome ginti baaqi). Live (Chrome 19:36): kernel wasm 200, rpcUp, tagged 3 untagged 0, par sirf 3/11 calls kernel se (baaqi kernel_not_used = early-boot).
TODO (asli kami): G1 ANEXOChat apna /wt/chat WebTransport (chat-transport.ts); G2 live@1 /wt/events aur rpc@1 /wt/rpc alag session (Rule: EK QUIC connection); G3 crm.live + org.members Rust par. kernel-check.sh server par FAIL aaya (19:35) — kaun si line, founder ke `grep` output ka intezar.
Web deploy: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) | grep -E "build|health|server==repo|^DIFF"` — wasm nahi badla (pin wahi), isliye Rust/SQL nahi.

## 26 Oct 2026 19:47 PKT — founder: G1/G2 (ek QUIC session, ANEXOChat kernel ke andar) = HAAN, lekin TARTEEB se
Founder: ANEXOChat par kal raat ~2 baje (25-26 Oct) bahut kuch note karwaya tha — yeh us ke UPAR chalega. Pro green ke BAAD Business phase mein yeh sab hoga. Repo mein likha: `docs/packages/business/ANEXOCHAT-K3-PLAN.md` (purane notes ki list + K3 plan), `RULE-52-PROOF.md` G1/G2 = TODO (Business phase). Abhi K3/ANEXOChat par koi code nahi. Agla = Pro green poora: Web pull + Chrome kernel/fetch ginti (early-boot), kernel-check FAIL ki line, G3 (crm.live + org.members Rust), Calendar Availability/Focus UI, enforce mode.

## 26 Oct 2026 19:55 PKT — Rule 52 early-boot: pehla live naap kam nikla, fix 2
Web pull (19:49) ke baad Chrome: kernel 1 / fetch 8 — wasm 3373 ms par, pehli 9 calls 3793 ms par (400 ms intezar khatam, QUIC handshake tab tak nahi hua). Fix: EARLY_WAIT_MS 1200 + `gaveUp` (ek baar intezar, phir bina intezar fetch). kernel-check ab ALL PASS (19:49; pehla FAIL restart ke foran baad ka tha). Founder ko Web pull dobara; phir Chrome ginti.

## 26 Oct 2026 19:52 PKT — founder: "yahan bun ko goli maaro, naya kaam mein bun ka koi kaam nahi" = AGENTS.md Rule 56
Naya kaam sirf Rust + WebTransport/WASM kernel; naya Bun route/fallback/REST path nahi. Purana Bun tab hat'ta hai jab uska Rust port live green ho (ek ek, saboot ke baad). Pehla port: crm.live + org.members (Pro pages, abhi kernel_status_404) — shuru.

## 26 Oct 2026 20:10 PKT — G3: crm.live + org.members Rust par (module `livex`) — READY (code), deploy + live barabari baaqi
`server/rust/livex_core.rs` (7 tests, std-only) + `livex_glue.rs` (cargo check OK): crm.live (Pro+; radar, next_actions, timeline, people, graph, counts — Bun /api/crm/live ka port, wahi formula) aur org.members (login + org; org na ho => 404 => UI Bun par). Installer: ALL_MODULES + CFG `livex` (need_mods cal_core, workx_core) + probe case; basic-gate-probe mein crm.live 403; rpc-contract crm.live "pro" (+test). Koi SQL nahi. Bun kaa kaam khatam hone ki shart (Rule 56): Rust live green + Bun barabari saboot, phir Bun route hataya jaye.
Founder: Rust install (neeche command), phir main Chrome mein crm.live ko Bun se barabar karunga.

## 26 Oct 2026 20:15 PKT — RULE 52 LIVE: kernel 9 / fetch 0 (Chrome, fresh load) + crm.live/org.members Rust barabar
Founder: Rust livex install ho gaya (20:02, health 200). Chrome: crm.live Bun vs Rust radar/next_actions/people/nodes/edges/counts same; org.members all/active/invited/revoked same (sirf JSON key order). timeline: 2 nazdeeki entries ki tarteeb alag (Bun localeCompare) — Rust ab asli waqt se (livex_glue.rs fix commit, dobara Rust install). Early-boot fix ka asar: PEHLE 1/9 kernel -> AB 9/9 kernel, fetch 0, tagged 9, fallbackProcs {} (Web pull 3c4b0e5 deploy). Founder hukm: "ab se Rule 52 se browser ka shuru, Supabase cement" => AGENTS.md Rule 52 UPDATE + RULE-52-PROOF.md.
basic-gate-probe: "1 FAIL" aaya (19:58) — founder se `... basic-gate-probe.sh 2>&1 | grep -E "FAIL"` ka output chahiye (mumkin crm.live ya naya proc).
pull.sh "differ=1": ek src file server aur repo mein alag — founder ko `DIFF` line nahi dikhi (grep ^DIFF khali): agla step: pull.sh ka poora output / `git -C /opt/anexomail-web status --short src`.

## 26 Oct 2026 20:20 PKT — founder: "puri website ka ek ek corner, ek ek word, sab Rule 52 par builtin chalega" (SCOPE = POORI WEBSITE)
basic-gate-probe: dobara chalane par FAIL khali (pehla FAIL Rust restart ke foran baad ka tha). `git status src` mein M files = server ki tree installers/pull se dirty hoti hai (normal; "differ=1" ek file hai jo alag hai — ab ignore).
AUDIT (static): src mein 24 file seedha REST `api()` (Bun /api/*) use karti hain (65 jagah), 13 file seedha `fetch()` (uploads, telemetry, clock-sync...). Yeh sab kernel ke bahar hain. Plan: (1) `api()` har REST call `anexoKernel.stats.fetch` + `fallbackProcs["METHOD /api/..."]="rest"` mein ginta hai (code likha, Web pull baaqi) (2) har route Chrome mein iframe-crawl se naapna -> asli list (3) list ke har REST endpoint ka Rust proc (Rule 56) + UI `rpc()` par, ek ek, saboot ke saath (4) uploads/streams (attach, evidence, ai-workspace, chat-files) kernel ka stream module (K3, Business phase).

## 26 Oct 2026 20:15 PKT — COMPACT-SAFE HANDOFF (padho yeh pehle; founder: "compact aaye ga, context update kero")
FOUNDER: Nauman Sherwani, Roman Urdu, "Nauman bhai"/"aap" (kabhi "tum" nahi), ghussa, har cheez LIVE green maangta hai ("ek ek cheez green, tarteeb se"), har message mein POORI copy-paste commands (Rule 46 tarteeb: SQL -> Rust install + pm2 restart + health -> Web pull.sh -> probes). Commit trailers: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com> + Claude-Session: https://claude.ai/code/session_01M4RARCpqskLVTeA3hiUMVX. Har turn ke baad: repo + chat context + dono DONE-DO-NOT-REPEAT + GREEN-LEDGER + founder-commands; manifest-sync (explicit files, DEPLOY-MANIFEST.txt nahi) + manifest-verify 0 bad; push.
HUKM AAJ KE (sab repo mein): (1) Pro CRM P1+P2 live GREEN (merge, pipeline edit, layout, form rate limit local); (2) Rule 56: naye kaam mein Bun nahi (Rust + WebTransport/WASM kernel); (3) Rule 52 update: browser ka har call kernel se, Supabase pakka data layer, PURI website ka ek ek corner Rule 52 par; (4) ANEXOChat + K3 (G1/G2 ek QUIC session) = HAAN lekin Business phase mein, Pro green ke baad, ANEXOChat ke 25-26 Oct ~02:00 wale notes ke upar: docs/packages/business/ANEXOCHAT-K3-PLAN.md; (5) Business -> CRM P3-P6 (Blueprint=P4) -> Business Pro -> Enterprise (Rust-only).
HALAT (live): Rust livex (crm.live + org.members) installed 20:02 + Chrome Bun-vs-Rust barabar. Early-boot fix (1200 ms + gaveUp) live: fresh load kernel 9 / fetch 0 / fallbackProcs {} (CRM pipeline page). kernel-check ALL PASS (19:49), basic-gate-probe ab FAIL khali. Guard: src/lib/kernel/rule52.test.ts (16 checks + 3 todo), saboot: docs/cursor-work/RULE-52-PROOF.md (18 jumle).
PENDING (is tarteeb mein): A) Founder: Web pull jis mein api() REST audit hook hai (commit c82eb17; build 1-3 min, grep output end par aata hai) + Rust dobara install (timeline sort fix d6d9240, command: rust-engine-install.sh | tail -6 phir pm2 restart + health). B) Pull ke baad Chrome mein HAR route naapna: same-origin hidden iframe per route, 7 s wait, `iframe.contentWindow.anexoKernel.stats/fallbackProcs` (REST calls "METHOD /api/..": "rest"); asli list banao. C) Us list ke har REST endpoint ka Rust proc (livex/workx/crmx pattern: X_core.rs std-only tests + X_glue.rs owns/dispatch; installer ALL_MODULES + CFG + probe case; rpc-contract + test; Basic probe), UI `rpc()` par; ek ek Chrome saboot. D) 13 file seedha fetch() (uploads attach/evidence/ai-workspace/chat-files/org-export, telemetry, clock-sync, domains, founder.preview) — uploads kernel stream module (K3). E) Pro baaqi: Calendar Availability/Focus UI click-through + hourly-rate UI, calendar.availability khali input par 502 (400 hona chahiye), ANEXO_TAG_MODE=enforce (founder env, kernel-check valid=76 missing=0 invalid=0), Business caps (Business account chahiye).
TECH NOTES: scratch crate cargo check: /tmp/claude-0/-home-claude/18af95d7-ea60-5dd5-a66b-c95acd2cd478/scratchpad/rb (glue/core copy karo, main.rs test-modified; mod lines add). throwaway Postgres /tmp/pgx port 5499. Chrome tab 1609160493 (Pro pro.buyer@anexomail.com logged in); helper: tok=localStorage['anexo.session.token']; POST /rpc/<proc> {input}; GET /api/..; page JS helpers navigation par mit jate hain. Test data Pro account par: ZZ Test Lead, zz.test.fast, 2 ZZ TEST Deal, 5 ZZ fields, 1 ZZ form. tokio::join! mein &format!() temporary E0716 — pehle variable. Installer main.rs replace nahi karta (anchor patch).

## 26 Oct 2026 20:35 PKT — RULE 52 poori website naap (35 /app routes): kernel 214 / fetch 100 (68% kernel)
Web pull (c82eb17 audit) deployed. Baaqi fetch ka sab se bada hissa: GET /api/auth/session + GET /api/trial/state HAR route par (66 of 100). Phir /account (mfa, sessions, recovery), /people (contacts), /integrations, /storage, /crm/leads (kernel_status_404), companies. Poori list + plan: docs/cursor-work/RULE-52-REST-INVENTORY.md. Agla: trial.state, auth.session Rust (Bun se barabari saboot pehle), phir baaqi ek ek. /app/work + /app/safety par kernel 0 aaya — dobara fresh load se check (shayad crawl ka IP-session artefact).

## 26 Oct 2026 20:25 PKT — founder ne Rule 52 ke apne alfaaz likhwaye (verbatim): "ANEXOMAIL ke browser-side mein ek general-purpose WASM KERNEL compute kernel (Rust, tRPC, WebTransport, async, Tokio mein likhna hai -> WASM KERNEL) builtin hota hai. yeh hai rule"
AGENTS.md Rule 52 mein yeh pehli line ab founder ke alfaaz mein hai (line 404). Guard test [1b] jodi. Honest note: tRPC = tRPC-STYLE typed contract (rpc-contract.ts, {result:{data}}), asli npm @trpc library nahi (JS hai, WASM mein nahi chalti) — founder se poochha: asli library chahiye to bata dein.

## 26 Oct 2026 20:40 PKT — pull (kernel-check retry fix). Tarteeb: SQL nahi -> Rust nahi (koi Rust badlav nahi) -> Web pull -> probes
```bash
# 1) Web
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -15
# 2) probes (10 s ruk kar)
sleep 10
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 20:50 PKT — kernel-check dobara (Web restart ke baad 40 s retry). Pull -> 40 s -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -8
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
```

## 26 Oct 2026 21:00 PKT — calendar.availability/focus 502 fix (Rust). Tarteeb: SQL nahi -> Rust install + restart/health -> Web (docs/tracker) -> probes
```bash
# 1) Rust
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -6
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
# 2) Web
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
# 3) probes (Pro mode: availability/focus 200 hona chahiye)
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|availability|focus"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 21:25 PKT — "-£0" fix (Web) + pre-send message English (Rust). Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 22:00 PKT — Availability working-hours fix. Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 22:40 PKT — Meeting cost hourly-rate. Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|rates"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 23:30 PKT — Trusted devices "N of 4" (Rust security.devices + Web). Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|device"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 26 Oct 2026 23:50 PKT — Pro CRM desk (crmd) Rust. Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -6
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|crm\.(leads|deals|insights|createLead|createDeal|moveDeal)"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 00:50 PKT — Work button fix + crm.memory (Rust) + Bun twin source fix. Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|crm\.memory"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 00:40 PKT — 404 -> Bun fallback loophole (crmd domain errors 409). Tarteeb: SQL nahi -> Rust -> probes (Web par naya kuch nahi)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 00:45 PKT — Trial Rule 52 (trialx Rust + Web wiring). Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|account\.signup"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 01:05 PKT — Website flow (Rule 52 + cinematic) dikhaya
Founder 00:54 ne poocha website kaise banegi: diagram dikhaya (UI+cinematic -> WASM kernel -> QUIC -> Rust Tokio -> Supabase). Likha: docs/claude/TECHNOLOGY-MAP-27OCT.md section 5. Agla kaam: auth.session Rule 52 port, phir Basic baaqi 110.

## 27 Oct 2026 01:25 PKT — auth.session Rule 52 (authx Rust + Web wiring). Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|auth\.session"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS|auth\.session"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 02:20 PKT — auth.session + Batch A (contx) + Batch B (basx) EK SAATH. Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 04:20 — Batch B2 (wsx: workspace.personal/organisations). Tarteeb: SQL nahi -> Rust -> Web -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 01:59 PKT — compact-safe state: docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md ke aakhri block mein (B2 wsx deploy pending)

## 27 Oct 2026 02:15 PKT — wsx stamp_kind fix deploy + naye-user live test (installer idempotent: "pehle se judi hai", sirf nayi file copy + build)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wsx-live-test.sh) 2>&1 | tail -30
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
```
(Web pull is baar nahi chahiye: koi frontend file nahi badli.)

## 27 Oct 2026 03:02 PKT — compact-safe state: CLAUDE-CHAT-CONTEXT ke aakhri block mein

## 27 Oct 2026 — Batch C1 (billx) + wsx fix: Rust -> restart -> Web -> wsx live test -> probes
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wsx-live-test.sh) 2>&1 | tail -30
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```

## 27 Oct 2026 — wsx + setActive profile-stamp fix: Rust -> restart -> live test (Web pull nahi chahiye)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/wsx-live-test.sh) 2>&1 | tail -34
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
```

## 27 Oct 2026 04:24 PKT — Batch D (setx): Rust -> restart -> Web pull -> probes (Web pull ZARURI: src/lib/settings.ts badla)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
sleep 20
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
MODE=pro EMAIL=pro.buyer@anexomail.com bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/basic-gate-probe.sh) 2>&1 | grep -E "FAIL|ALL PASS"
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/kernel-check.sh) 2>&1 | grep -E "FAIL|KERNEL|wasm jawab"
```
Phir Chrome: /app/settings (koi toggle badlo -> history -> revert), /app/integrations (providers, connections, exports), non-founder se /app/founder overview 403.

## 27 Oct 2026 04:31 PKT — buyer-accounts-look.sh (READ-ONLY): pro/basic/business/bpro .buyer + test accounts ka plan, workspace-kind, org. Chrome mein login account "Personal Pro+" card dikha raha tha (personal workspace) — pro.buyer se alag lagta hai.
```bash
bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/buyer-accounts-look.sh)
```

## 27 Oct 2026 04:37 PKT — pro.buyer repair (Rust install -> restart -> fix script -> probes)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -4
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
sleep 20
bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/fix-buyer-kind.sh)
bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/buyer-accounts-look.sh) 2>&1 | sed -n "/== 3/,/== 4/p"
```

## 27 Oct 2026 04:53 PKT — EK COMMAND DEPLOY: docs/cursor-work/server/deploy-pro.sh (Rust install -> restart+health -> web pull -> 20 s -> BASIC+PRO probes -> kernel-check; SQL/Brain/Polar nahi chhoota; FAIL par ruk jata hai). Founder hukm: 'ek command do, server ko latest technology pro ke liye batao'.
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/deploy-pro.sh)
```

## 27 Oct 2026 05:03 PKT — Claude: Pro 7 endpoints Rust mein + SQL E93/E94 (CODE READY, deploy baaqi)
- **Pro 7 endpoints** (work.task.create/update, work.followThrough, work.note, work.note.save, calendar.outcome.post; GET tasks alias work.tasks) workx module mein Rust: `server/rust/workx_core.rs` (+validators, follow-through hisaab, tests pass) + `workx_glue.rs`. Pro gate server par (Basic 403). Full crate `cargo check` OK (patched main.rs, saare modules). Registry: **523 total, 176 Rust-first, 347 baaqi; PRO 51/51, Pro mein 0 baaqi**. Probes basic-gate-probe.sh mein joray (Basic 403 / Pro 400,200).
- **SQL E94_plan_promises.sql** (+CHECK_E94): plan_promises registry (Basic+Pro server wade, Business/BP = todo, jhoot nahi), plan_promise_audit(), plan_promise_ok(), v_plan_promise_gaps, plan_promise_log + snapshot. Lint OK.
- **SQL E93_attach_ceiling_35mb.sql** (+CHECK_E93): server ceiling 18MiB -> 35MiB (36_700_160). SIRF `attach-limit-measure.sh` mein Pro "SAFE" aane ke baad chalao (Postfix + clamd StreamMaxLength). Founder khud naapega.
- Deploy tartib: attach-limit-measure.sh -> (SAFE ho to) sql-run.sh (E93, E94) -> deploy-pro.sh (Rust install+restart+pull+probes). Business/BP v6 enforcement abhi TODO-1.

## 27 Oct 2026 05:12 PKT — founder server par: clamd 64M + SQL E93/E94 GREEN (CHECK sab OK)
- clamd StreamMaxLength/MaxFileSize 25M -> 64M (backup /etc/clamav/clamd.conf.bak-27oct), clamav-daemon active. sql-run: E93 + E94 + CHECK_E65/E93/E94 sab OK. Pro 7 Rust endpoints ka deploy (deploy-pro.sh) baaqi.

## 27 Oct 2026 05:20 PKT — founder: "yeh commands claude ke liye safe kar lo"
- docs/claude/SERVER-COMMANDS-FOR-CLAUDE.md: asli deploy block (founder history) + kab kaun si script. Aage se SIRF yeh/ founder-commands wali commands do, naye wrapper nahi.

## 27 Oct 2026 05:26 PKT — PRO LIVE TEST (Chrome, pro.buyer) + LOOPHOLE FIX (Bun gate)
- LIVE GREEN: /app/work khula; task banana (ZZ rust task create check) aur status badalna (todo->doing) kaam kiya; browser mein /api/work REST ki ek bhi request nahi (sirf kernel.ticket/report + WebTransport) = technology migration sahi (WASM kernel -> QUIC -> Rust workx). Follow-through tab khulta hai ("no committed promises yet" — tasks ki due date nahi). Decision ledger = Business+ (by design). Promises khali.
- LOOPHOLE (mera dhoondha): Bun /api/work/* (tasks GET/POST/PATCH, promises GET/commit/dismiss, follow-through, notes GET/POST), /api/calendar/events/:id/outcome aur /api/mail/handoff* par plan check NAHI tha — Basic user seedha Bun se Pro features chala sakta tha (Rust par gate tha). FIX repo mein: server/routes/calendar.ts proGuard (10 routes), handoff.ts requireUser Pro gate (/devices/seen khula). Server ke liye surgical installer: docs/cursor-work/server/brain-progate-install.sh (restore-on-fail, live drift safe; pehle brain-pro-install.sh chahiye). Probes basic-gate-probe.sh mein 5 BUN checks (Basic 403 / Pro 200).
- DEPLOY BAAQI (founder): brain-progate-install.sh -> basic-gate-probe (Basic+Pro). Chrome baaqi: 3 booking links, 20-user cap, shared-inbox collision (2nd Pro user), snooze/schedule-send clicks, People.

## 27 Oct 2026 05:34 PKT — founder server: brain-progate LIVE + probes ALL PASS (basic+pro) — PRO KA SAB CODE SERVER PAR (saboot neeche)
- brain-progate-install.sh chala: Brain health 200, /api/work/tasks aur /api/mail/handoff bina login 401, backup /root/anexomail-backups/brain-progate-20261027-002839. basic-gate-probe: ALL PASS (basic) + ALL PASS (pro) — ab 5 BUN checks + 7 naye Rust Pro checks sameet.
- Pro saboot ek jagah: SQL E87/E88/E93/E94 CHECK OK; Rust installer "workx ... setx wtrpc" + restart; Web server==repo (src same=595); Bun brain-progate; clamd 64M; Chrome pro.buyer task create/update kernel se.
- AGLA (founder ka hukm, Rule 56): Pro ke Bun twins (work 10 + handoff 4) HATANA — Rust port live green hai; patch sirf live saboot ke baad. Phir baaqi gates/endpoints migrate: registry 523 / Rust-first 176 / baaqi 347 (Pro 51/51 = 0 baaqi; Basic-shared login 23, trial 9, billing C2 5, deletion 3, calendar export 1; Business 184; Founder 53).

## 27 Oct 2026 05:44 PKT — registry sahi (186->187) + calendar.export Rust (calexp) CODE READY — deploy baaqi
- Registry bug: trial (8 endpoints) aur account-deletion (3) Rust par pehle se the (account.signup.*, account.delete.*), map mein Bun-only gine ja rahe the. count-endpoints.py ALIAS theek => **523 total, Rust-first 187, baaqi 336**. PRO 51/51 (0 baaqi), BASIC 107/142 (35 baaqi: login 24, billing C2 5 [paisa: founder ijazat + shadow], polar 5 NO-TOUCH, trial/sweep 1 cron).
- calexp module (calendar.export): server/rust/calexp_core.rs (5 tests, RFC5545 escaping+folding — Bun ye nahi karta tha) + calexp_glue.rs; sab plans (Basic bhi). Client: downloadCalendarExport() (src/lib/calendar.ts) + EventDetail/CalendarClassic ab <button> (Bun REST href nahi). tsc OK, full-crate cargo check OK. Installer ALL_MODULES mein calexp + CFG (need cal_core). Probes: calendar.export 200 / bad format 400. Founder deploy: Rust install -> restart -> pull.sh (UI badli) -> probes.
- TECHNOLOGY JAGAH (CEO): UI = React19/TanStack/Vite8 (pull.sh); har call = WASM kernel -> QUIC/WebTransport -> Rust axum/Tokio :3200 (installer+restart); data/gates = Postgres (sql-run.sh); Bun :3100 sirf emergency fallback (brain-*-install) — Rule 56: naya kaam Bun mein NAHI, purane Bun routes Rust green hone par HATAYE jate hain.

## 27 Oct 2026 05:48 PKT — **PRO MIGRATION = GREEN** (founder ka hukm "pro migration green declare kero")
- Saboot: Pro 51/51 endpoints Rust-first, Bun par 0 (registry count-endpoints.py, 187/336 total). Server par live: workx (7 naye) + probes ALL PASS (basic+pro, 05:15), brain-progate LIVE (Bun twins par Pro gate) + probes ALL PASS (05:34), SQL E87/E88/E93/E94 CHECK OK, clamd 64M, Chrome pro.buyer task create/update kernel se (REST nahi).
- GREEN ka matlab yahan: MIGRATION + GATES (endpoint/gate Rust+server par). "Pro package public ke liye CLOSE" abhi nahi — baaqi: Chrome walk (3 booking links, 20-user cap, shared-inbox 2nd user, snooze/schedule-send, People), ANEXO_TAG_MODE=enforce (founder env), calexp (calendar.export) deploy, Bun twins hatana (Rule 56, work 10 + handoff 4).

## 27 Oct 2026 05:56 PKT — founder hukm: Polar sensitive, haath nahi; Bun fallback rahe; backup pehle; baaqi test
- **Founder decisions:** (1) Polar engine :3400 NO-TOUCH, jo green hai (webhook, replace, reconcile, portal) wahi rahe; (2) Pro ke 14 Bun twins HATANE NAHI — Bun fallback rahe (Pro gate un par laga hai); (3) baaqi paisa-wale 5 (intent, change-plan, intent GET, sync cron, guest-intent) latest technology par, lekin pehle SERVER BACKUP; engine/Polar token ka faisla founder ka (Option 1 sealed endpoint / 2 token :3200 / 3 baad mein) — jawab baaqi; koi billing code nahi likha.
- **full-backup.sh** (docs/cursor-work/server): poora server COPY (Polar src+wal+.env+binary, Rust :3200 src+binary, Brain, chat, pm2 dump, Caddy, Postfix, clamd, /etc/anexomail, sql ledger) + RESTORE.sh (dry-run default; rust|brain|caddy|all-but-polar; polar sirf founder ki haan). Kuch print/restart nahi karta.
- **Chrome pro.buyer (28 Oct nahi, 27 Oct):** /app/people khulta hai (naya account, khali), /app/calendar khula (Pro cost £100 dikha), booking panel khula: "1 of 3 booking links used", "New link" ne draft pro-buyer-2 banaya (maine SAVE nahi kiya, panel band) => 3-link cap ka asli saboot DB trigger booking_pages_cap_trg + CHECK_E88; 4th block UI se nahi aazmaya. Snooze/schedule-send/20-user/shared-inbox baaqi.
- **ANEXO tag** (founder ka sawal): kernel har WebTransport call par HMAC-SHA256 muhar lagata hai (key kernel.ticket se, 15 min, memory mein); Rust wtrpc_glue verify. ANEXO_TAG_MODE=observe (abhi: sirf ginti, kabhi block nahi) | enforce (bina sahi muhar 401). Enforce tab jab observe mein invalid=0.

## 27 Oct 2026 06:02 PKT — PRO: loophole sweep #2 + doosra Pro user + team probe (CODE READY, deploy baaqi)
- LOOPHOLE #2: Bun mail-compose.ts ke 11 Pro routes (templates GET/DELETE, snippets GET/POST/DELETE, follow-up GET/POST/DELETE, send-confidence, schedule cancel, thread insights) par plan check NAHI tha (Rust par gate hai). Fix: repo server/routes/mail-compose.ts proOnly + brain-progate-install.sh ab calendar.ts + handoff.ts + mail-compose.ts teeno surgical patch (restore-on-fail). Probes: 4 BUN checks (templates/snippets/follow-up/send-confidence = Basic 403, Pro 200).
- FOUNDER DECISION BAAQI (mera nahi): word prediction (mail.predict*, Bun+Rust) Basic ko bhi khuli hai; PP1 #8 Pro+ kehta hai, Basic INCLUDES "MATCHES-CODE" kehta hai. Gate lagana = Basic se cheez wapas lena => founder kahe tab.
- pro-second-user.sh: pro.buyer2 (E28 seed, Pro), pro.buyer ki team mein member; password sirf /root/test-accounts/pro.buyer2.pw. pro-team-probe.sh: assign -> pro.buyer2 200, -> basic.buyer 400 assignee_not_member, unassign; seat cap Pro 20 (20 used + 1 pending => free 0). Snooze + schedule-send API probe pehle se pro mode mein ALL PASS (UI click baaqi).
- People khali = galat nahi: People asli mail se bhar-ta hai; pro.buyer naya account. pro.buyer2 se mail bhejne par bharega (Chrome mein dekhna).

## 27 Oct 2026 06:14 PKT — founder: "Add backup passkey" patti baar baar aati hai (UI fix, deploy = pull.sh)
- Wajah: PasskeyGate "Later" sirf sessionStorage mein yaad rakhta tha => har naye login/tab par wapas. Fix: localStorage mein 30 din ka snooze (anexo.passkey.banner.snoozedUntil). 0-passkey strict screen aur required/hard gate NAHI badle. tsc OK.

## 27 Oct 2026 06:35 PKT — PRO LIVE (Chrome, 2 browser): server probes ALL PASS + People khali ki wajah dhoondh rahe
- Founder ne block chalaya: full-backup (117M), brain-progate "gated 11", pro-second-user (team 2/20), Rust installer (calexp wtrpc dono), restart 200, pull.sh OK, basic ALL PASS, pro ALL PASS, pro-team ALL PASS (assign 200, bahar 400, seat cap 20/free 0), kernel ALL PASS.
- Chrome pro.buyer2 (Browser 1 = buyer2, Browser 3 = buyer): Mail/People/Work/Calendar khule; Pro compose mein Templates/Follow-up/Schedule send/Version history dikhe; mail buyer2->buyer INBOX mein pahunchi (Sent + Inbox dono).
- People khali: anexo_rebuild_contacts apne domain (@anexomail.com) ko contact nahi banata (design). buyer2 ne anexomail27@gmail.com ko bhi mail bheji (founder ki haan) — phir bhi People khali => asli bug ya data masla. docs/cursor-work/server/people-check.sh (READ-ONLY) likhi: mail org/direction, contacts row, rebuild jawab, Rust log. Founder chalaye, output se fix.

## 27 Oct 2026 06:39 PKT — PEOPLE BUG MILA (asli, real buyer ko bhi lagta): E95 CODE READY, SQL chalana baaqi
- Wajah: mail_messages mein recipients ke 2 column set: to_addrs/cc_addrs (Rust send, mail_glue.rs:445 yahan likhta hai) aur purane to_addresses/cc_addresses (khali). anexo_rebuild_contacts sirf purane padhta tha => bheji hui mail se kabhi contact/People nahi bana. Apna domain (@anexomail.com) design se contact nahi banta.
- Fix: docs/cursor-work/sql/E95_people_rebuild_to_addrs.sql (create or replace, coalesce(nullif(to_addrs,'{}'),to_addresses), same cc; revoke anon/authenticated, service_role grant) + CHECK_E95.sql. Lint OK. Deploy: sql-run.sh (bare AUTO). Phir Chrome pro.buyer2 /app/people mein anexomail27@gmail.com aana chahiye.
- Pro GREEN (user ke liye) tab: E95 CHECK ok + People mein anexomail27 dikhe (Chrome). Server probes (basic/pro/team/kernel) 06:15 par ALL PASS.

## 27 Oct 2026 06:43 PKT — PEOPLE ka ASLI sabab (live saboot people-check.sh): E96 CODE READY, SQL chalana baaqi
- Founder output: bheji mail DB mein sahi (out, to anexomail27@gmail.com), par anexo_rebuild_contacts => {"ok":false,"error":"column last_contact_at of relation contacts does not exist"}. Live contacts mein last_contact_at/company_id nahi; contact_stats mein org_id/updated_at nahi (first_contact_at/computed_at hain). Function phase62 file ke hisaab se likha tha, exception khaakar ok:false lautata => People hamesha khali (har plan).
- E95 (to_addrs/cc_addrs) chali, CHECK OK. E96_people_rebuild_live_columns.sql + CHECK_E96.sql = live columns par function (E95 ka recipient fix saath). Lint OK. Deploy: sql-run.sh bare AUTO. Phir /app/people (Chrome) mein anexomail27@gmail.com.
- SABAK: live-snapshot schema se function ke columns pehle match karna; exception-swallow ok:false ko CHECK mein pakadna.

## 27 Oct 2026 06:46 PKT — PEOPLE GREEN (live, Chrome pro.buyer2) + timeline bug fix (Rust deploy baaqi)
- E96 chali, CHECK_E96 sab OK. Chrome pro.buyer2 /app/people: anexomail27@gmail.com aaya ("1 open"), profile: Last contact 12m, Messages 0 in · 1 out, Open threads 1. People bug band (har plan par tha).
- Naya bug (profile mein 'Relationship history: No history yet' jabke 1 mail gayi): contx timeline_or to_addresses par ilike lagata tha, par to_addresses text[] hai => query error => khali. Fix server/rust/contx_core.rs: poora address => to_addresses.cs.{a} + to_addrs.cs.{a}; sirf @domain => from_address (array mein substring PostgREST se nahi). contx_glue.rs {} encode. Tests 4 pass, full crate cargo check OK. Deploy: Rust installer + restart (company-timeline ka outbound hissa abhi nahi — alag kaam).

## 27 Oct 2026 06:49 PKT — LOOPHOLE #3 (shared inbox UI): Assign ka button hi nahi tha — FIX code ready, pull.sh baaqi
- Chrome pro.buyer: thread header mein Done/Archive/Rescue/Meeting/Snooze/Label the, Assign NAHI. mail.assign (Rust+Bun) aur useThreadAction({kind:"assign"}) maujood the par UI mein koi caller nahi => Pro card ka vaada "Shared inbox with collision guard" user ke liye chalta hi nahi tha (sirf API probe pass).
- Fix src/components/app/mail/ThreadHeaderActions.tsx: Pro+ ke liye "Assign" dropdown (workspace members useOrgMembers se; "Remove owner"; owner ho to "Owner: <naam>"); Basic ko locked chip "Shared inbox". Route se assignee prop. tsc OK. Owner badge ThreadList mein pehle se (collision guard).
- Test (deploy ke baad, Chrome): buyer thread -> Assign pro.buyer2 -> buyer2 ke "Assigned to me" mein thread; list mein owner badge dono taraf.

## 27 Oct 2026 06:56 PKT — SHARED INBOX asli jad: mail_identity active workspace ko nahi maanta (main.rs FIX, Rust deploy baaqi) + Assign UI LIVE
- Rust+web deploy hua (pro ALL PASS). Chrome: pro.buyer thread ke header mein Assign live; buyer2 ko assign => button 'Owner: pro.buyer2@...' + list mein owner badge. buyer2 ke 'Assigned to me' MEIN KUCH NAHI.
- Sabab: server/rust/main.rs mail_identity — UI org_id na bheje to ids[0] (pehli org_members row, bina tarteeb) uthata tha; account_profiles.preferences.active_organisation_id ignore. buyer2 ki 2 memberships (apni 98982883 + pro.buyer ki team 968fef79) => hamesha apni khali inbox; team ki shared inbox kabhi nahi dikhti. Probe 'pro.buyer2 shared inbox 200' TOK1 se chalta tha (kamzor saboot).
- Fix: >1 memberships par preferred active org (agar member) warna ids[0]; 1 membership walon par extra query nahi. Full crate cargo check OK. Assign menu mein dohra email hataya. Deploy: Rust installer + restart. Phir Chrome: buyer2 inbox mein buyer ke threads + Assigned to me.
- People history ab bhi khali (cs fix deploy ke baad bhi) — sabab abhi nahi mila (server log chahiye); alag item.

## 27 Oct 2026 07:04 PKT — INSTALLER GAP pakda: main.rs repo se REPLACE nahi hota => mail_identity fix server par nahi pahunchi thi; ab installer patch + tag-enforce.sh
- Founder ne Rust installer chalaya: "main.rs: kuch nahi badla" => meri server/rust/main.rs ki mail_identity tabdili LIVE nahi hui (installer sirf anchor-patch lagata hai, live main.rs replace nahi karta). buyer2 ko shared inbox ab bhi nahi dikhegi jab tak patch na lage.
- Fix: rust-engine-install.sh CFG["calexp"]["replace"] mein mail_identity anchor-patch (find->rep, unless 'active_organisation_id").and_then' = idempotent). Test: purani main.rs (3a03584) par patch == repo main.rs (True). bash -n OK.
- ANEXO tag: docs/cursor-work/server/tag-enforce.sh (status|enforce|observe): enforce se PEHLE tag ginti dekhta hai (missing=0 invalid=0 warna RUK), restart ANEXO_TAG_MODE=enforce, kernel-check, FAIL par khud observe. Founder ko passkey: banner 'Create passkey' => Windows Hello/phone QR (founder ka biometric, main nahi kar sakta).
- people-check.sh mein step 6 (timeline query Rust jaisi) — People 'Relationship history' khali ka sabab server output se milega.

## 27 Oct 2026 07:07 PKT — founder: PASSKEY GATE GREEN (founder ne khud test kiya) — pending list se HATAO
- Founder: "yeh enforce ho chuka hai, jab tak passkey nahi lagta website aage nahi jaati, maine khud karke dekha, advance hai." PasskeyGate (G35) = GREEN, founder-verified. Dobara 'passkey baaqi' kabhi mat likho; pro.buyer/buyer2 par 'Add a passkey' patti sirf grace-period ka dikhawa hai (strict screen tab aati hai jab grace khatam).
- Baaqi Pro list ab: (1) Rust installer dobara (mail_identity patch) + People history sabab (people-check), (2) Chrome: buyer2 ko shared inbox + Assigned to me + owner badge, snooze/schedule-send click, 4th booking link, (3) tag-enforce.sh (aakhri).

## 27 Oct 2026 07:12 PKT — SHARED INBOX LIVE (Chrome buyer2) + LOOPHOLE #4: 'Assigned to me' hamesha khali
- Founder ne Rust installer chalaya (main.rs patch laga: rollback line) + people-check: rebuild {"ok":true,"contacts":1}, timeline query HTTP 200 (mail mili). Chrome pro.buyer2 (Ctrl+Shift+R): ab pro.buyer ki TEAM inbox dikhti hai (account pro.buyer@..., thread par owner badge 'You'), People mein team ke contacts (hostflowaibuilder, mallory). mail_identity fix LIVE.
- LOOPHOLE #4: 'Assigned to me' folder khali — mail_query_threads folder=eq.assigned dhoondhta tha (asli folder nahi, koi thread us folder mein hota hi nahi). Fix server/rust/mailx_glue.rs threads(): folder 'assigned' => inbox query + sirf wo threads jinka assignee == me.id. Full crate cargo check OK. Deploy: Rust installer + restart.

## 27 Oct 2026 07:13 PKT — PEOPLE HISTORY ka ASLI sabab: mail_messages mein 'snippet' column hai hi nahi (+ CRM person ka wahi bug)
- Chrome (buyer2, team org): contact hostflow stats '2 in · 1 out' sahi, par Relationship history khali. Server query people-check step 6 se theek (HTTP 200) => select list mein dikkat. Live schema: mail_messages mein snippet NAHI (mail_threads mein hai) => contx timeline select=snippet => 42703 => rows() khali.
- Fix server/rust/contx_glue.rs timeline: select body_text, detail = body_text ke 160 akshar. Wahi bug server/rust/crmd_glue.rs (CRM person detail): snippet + to_addresses.ilike (array) => ab body_text + to_addresses.cs/to_addrs.cs; helper mail_detail(). Full crate cargo check OK. Deploy: Rust installer + restart.
- SABAK: select ki har column live-snapshot schema se milao; rows() error khaa leta hai (khali dikhta hai) — aise masle sirf live saboot (REST status) se pakde jate hain.

## 27 Oct 2026 07:23 PKT — PRO LIVE TEST (Chrome buyer2, team org) — Rust deploy ho chuka (ALL PASS pro)
- GREEN live: 'Assigned to me' mein owner thread; People Relationship history mein asli mails (ZZ M2 autosave test, Accepted: iMIP test); Snooze (Tomorrow 8am => Snoozed 'in 1d' => Bring back now => inbox wapas); Schedule-send ('Scheduled — Leaves at 11/30/2026 9:00 AM'); compose mein Pro tools (Templates, Version history, Follow-up, Schedule send).
- LOOPHOLE #5: lambi schedule ki hui mail ko CANCEL karne ka koi button nahi tha (sirf 30s Undo toast; useCancelScheduled hook bana tha, UI mein use nahi). Fix: src/routes/app.mail.$folder.$threadId.tsx MailMessage — future scheduled_at par 'Cancel send' button (mail.schedule.cancel; 409 => 'Already sent'). tsc OK. Deploy: pull.sh. (Scheduled mail Sent folder mein jati hai — mail_glue.rs folder 'sent'.)
- Design note (alag item): buyer2 team org dekhte hue bhi 'Send from pro.buyer2@' (apna account, apni org) — uski bheji mail team ke Sent mein nahi dikhti. Team ke sath bhejne ka tareeqa Business shared-mailbox ka sawal hai; founder decide kare.
- Test data: test scheduled mail (30 Nov, buyer2 -> pro.buyer, subject 'Scheduled test - will be cancelled') buyer2 ke apne org ke Sent mein padi hai — Cancel send se hatani hai (deploy ke baad).

## 27 Oct 2026 07:45 PKT — COMPOSE Business Outcomes deploy (tarteeb: web -> SQL -> Rust)
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -6
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
```
- Phir Chrome (Ctrl+Shift+R) pro.buyer2: Compose mein "I will send you the details by Friday." likho => badge "Detecting a Promise" => Task + Calendar => To mein 10 pate + lambi email => cost line.

## 27 Oct 2026 08:15 PKT — DEPLOY (kernel 0.4.0 + E97 fix + E98 + E99 + Rust promx file.context + Live Ink). Tarteeb: web -> SQL -> Rust
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh) 2>&1 | tail -6
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh)
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/rust-engine-install.sh) 2>&1 | tail -6
pm2 restart anexomail-rust --update-env && pm2 save >/dev/null && sleep 3 && curl -s -o /dev/null -w "rust /rpc/health %{http_code}\n" --max-time 5 http://127.0.0.1:3200/rpc/health
```
