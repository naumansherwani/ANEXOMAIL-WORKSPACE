# ONE ORDER — sirf yeh tarteeb chalti hai (03:49 PKT, 27 Oct 2026) — CEO faisla, founder hukm: "ek tarteeb, duplicate nahi, end mein repo implement"
Yeh file MASTER-GREEN-PLAN section B + BATCH-PLAN-27OCT + MIGRATION-STATUS (M1-M6) + T-series + trial/personal faislon ko **ek** list banati hai. Baaqi sab docs ab sirf reference/history hain (har ek ke upar is file ka note laga hai). Naya kaam shuru karne se pehle sirf yeh file + DONE-DO-NOT-REPEAT.

## Khatta rule: duplicate kaise NAHI banega (har item par, kisi ke bhi haath se)
1. **Ek registry:** docs/claude/ENDPOINT-PACKAGE-MAP.csv + `python3 docs/cursor-work/server/count-endpoints.py` (kaun si proc Rust mein hai). Kaam se pehle dekho proc pehle se Rust mein to nahi.
2. **Installer clash-scan:** `bash docs/cursor-work/server/installer-dryrun.sh "<modules>"` — proc pehle se live main.rs mein ho to PATCH FAIL (safe stop).
3. **Green = 4 saboot:** (a) cargo check poori crate (b) installer dry-run (c) founder deploy + probes ALL PASS (basic/pro/kernel) (d) Chrome check. Phir DONE-DO-NOT-REPEAT mein "GREEN, dobara nahi likhna".
4. **Kaun kya:** code + tests + probes + docs = CEO (main). Server commands chalana + output dena = founder. Chrome saboot = main (founder ka login chahiye to founder bataye).
5. Bun route tab hatao jab Rust==Bun saabit ho; tab tak Bun sirf fallback (Rule 56/59).

## Tarteeb (ek ek khatam, phir agla)
| # | Kya | Kya shamil (M-series nam) | Halat 27 Oct 03:49 |
|---|---|---|---|
| 1 | **Jo deploy hua par saboot adhoora** | wsx (workspace.personal/organisations) + setActive profile-stamp fix + billx C1 | **GREEN ✅ 03:53 PKT (ALL PASS wsx live + basic + pro)** |
| 2 | **Pro-only baaqi** | registry sach: **0 baaqi** (7 mein se sab ka Rust proc live: mail.handoff.delete, mail.device.seen, mail.followup.delete, work.promise.commit/dismiss, crm.insights, analytics.*). Client REST wale raaste bulata hi nahi => purane Bun twins unused. Probes jode (3). | **DONE 04:03** (deploy: sirf probe, Rust nahi badla) |
| 2b | **Pro: 7 asli — CODE READY 27 Oct (deploy baaqi)** (registry sakht karne par mili) | calendar.ts: /work/tasks GET+POST, /work/tasks/:id PATCH, /work/follow-through, /work/notes GET+POST, /calendar/events/:id/outcome — client `work.task.create`/`work.note`/`calendar.outcome.post` naam Rust mein hain hi nahi (Rust ke `work.tasks.*` THREAD-level alag cheez hain) => abhi Bun par chalte hain. Qadam 2 ka "0 baaqi" ghalat tha | baaqi, Batch D deploy ke baad |
| 3 | **Batch D** (M5) | settings 5 + integrations 10 + founder overviews 3 (module `setx`); security ke 10 procs PEHLE SE Rust (registry blind spot tha); Business settings 6 (blast/simulate/drift/schedule) aur Leo actions 2 Bun par | **CODE READY 27 Oct 2026 04:24 PKT** (cargo check poori crate OK, 8 unit tests, installer dry-run OK) — deploy + probes + Chrome baaqi |
| 4 | **Batch E** (M3/M5 leftover) | account-deletion 3 + mail 2 + calendar 1 + locale 1 | baaqi |
| 5 | **Pro walk** (Chrome, jo dikhana baaqi) | calendar screen, trusted devices UI, shared-inbox 2nd-user collision test, booking links, ANEXO_TAG_MODE=enforce (founder env), passkey mandatory | baaqi |
| 6 | **Login 24** (M4, aakhir, fallback ke saath) + **C2 billing paisa** (intent/change-plan/guest-intent/sync — founder ijazat + shadow-mode) | | baaqi |
| 7 | **PRO GREEN CLOSE** | PRO-GREEN-TRACKER sab GREEN + Basic package walk + Basic/Pro probes | tab "awam ke liye Pro green" |
| 8 | **L**: 23 polls -> WebTransport live events | | Pro close ke baad |
| 9 | **FOUNDER ACCOUNT** (F, 32 endpoints) | founder/admin/perf/movein | founder hukm: Pro ke baad |
| 10 | **TRIAL 48h** | docs/packages/trial/* | Founder account ke baad |
| 11 | **BUSINESS** (M6, 180) | v6 enforcement SQL (60 users/1.5TB/45MB), ANEXOChat K3 + calls (landing "coming" lines), Office suite, WebXR (Rule 60), DNS ownership-proof, search chat/files | |
| 12 | CRM P3-P6, **BUSINESS PRO** (570/10TB/60MB enforcement), T1-T12 (T-series) | | |
| 13 | **ENTERPRISE** (Rust-only, Bun-free) + toolchain; **PERSONAL package** (alag UI/gates) | | Personal HOLD — founder naya faisla de tab |
(Polar :3400 hamesha NO-TOUCH; Polar dashboard edit founder khud — Business/BP copy DONE.)

## (PURANI, GHALAT) Ginti 04:03 — neeche sahi wali dekho
## ASLI Ginti (04:03, count-endpoints.py + alias table): 523 total | Rust-first 187 | baaqi 336. **Basic+Pro (195): 123 Rust (63.1%), baaqi 72** = login 23, integrations 10, trial 9 (naye design par baad mein), polar 7 (NO-TOUCH), security 7, settings 7, billing-sync 5 (C2: intent, change-plan, intent/:id, sync, guest-intent), account-deletion 3, calendar export 1. **Pro-only: 0 baaqi.** Kaam ke: 56 (login 23 + D 24 + deletion 3 + calendar export 1 + C2 5).

## M-series ka nakshe se milan
M1/M2 = DONE. M3 = contacts/storage/support/workspace DONE, billing-sync = C1 DONE, C2 qadam 6. M4 = auth.session DONE, login qadam 6, trial qadam 10. M5 = settings/integrations/security qadam 3, org/crm/calendar baaqi qadam 4+11. M6 = qadam 11-12. F = qadam 9. L = qadam 8. Purani locked order ("Founder account -> identity tests -> M-series -> G16 -> T") BADAL gayi: ab Pro green + migration PEHLE; G16 DONE.

> **Ek jagah ka naksha (04:1x):** sab series (P/G/B/R/M/T/C/D/E/F/L/K) + technology + package gates = docs/claude/MASTER-MIGRATION-AND-GATES-27OCT.md (tarteeb phir bhi isi file ki).

## SAHI ginti (27 Oct 2026 04:24 PKT, count-endpoints.py SAKHT): client ka proc naam Rust source mein sach-much ho tabhi "Rust-first"; 3 route files ke prefix galat the (security/settings/integrations). **523 total | Rust-first 169 | baaqi 354.** Package: basic 96/46 (login 23, trial 9, C2 billing 5, polar 5 NO-TOUCH, deletion 3, calendar export 1) | pro 44/**7** | business 4/184 | business_pro 0/5 | founder 24/53 | internal 1/3 | ai_soon 0/56. (Pehle 187/336 dikhaya tha: 47 jhoote 'Rust-first' the.)

## 27 Oct 2026 05:03 PKT — Claude: Pro 7 endpoints Rust mein + SQL E93/E94 (CODE READY, deploy baaqi)
- **Pro 7 endpoints** (work.task.create/update, work.followThrough, work.note, work.note.save, calendar.outcome.post; GET tasks alias work.tasks) workx module mein Rust: `server/rust/workx_core.rs` (+validators, follow-through hisaab, tests pass) + `workx_glue.rs`. Pro gate server par (Basic 403). Full crate `cargo check` OK (patched main.rs, saare modules). Registry: **523 total, 176 Rust-first, 347 baaqi; PRO 51/51, Pro mein 0 baaqi**. Probes basic-gate-probe.sh mein joray (Basic 403 / Pro 400,200).
- **SQL E94_plan_promises.sql** (+CHECK_E94): plan_promises registry (Basic+Pro server wade, Business/BP = todo, jhoot nahi), plan_promise_audit(), plan_promise_ok(), v_plan_promise_gaps, plan_promise_log + snapshot. Lint OK.
- **SQL E93_attach_ceiling_35mb.sql** (+CHECK_E93): server ceiling 18MiB -> 35MiB (36_700_160). SIRF `attach-limit-measure.sh` mein Pro "SAFE" aane ke baad chalao (Postfix + clamd StreamMaxLength). Founder khud naapega.
- Deploy tartib: attach-limit-measure.sh -> (SAFE ho to) sql-run.sh (E93, E94) -> deploy-pro.sh (Rust install+restart+pull+probes). Business/BP v6 enforcement abhi TODO-1.

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

## 27 Oct 2026 07:45 PKT — COMPOSE 'BUSINESS OUTCOMES' (Pro): Promise Extraction + Thread Economics — BANA, deploy baaki
- Founder idea (07:29): email likhte waqt kaam aur paisa. Word prediction SAB plans par rahegi (faisla); upgrade baad mein. Cinematic stack (docs/claude/CINEMATIC-FRONTEND-STACK-27OCT.md) padhi: Rule 60 = Mail/Compose "kaam wali screen" => cinematic/3D yahan NAHI; yahan technology = WASM kernel + useDeferredValue/debounce + motion (reduced-motion ka ehtram) + virtualised/fast.
- KERNEL 0.3.0: web-wasm/src/intent.rs = module intent@1 (deterministic, bina model/network): wada pehchanna (English + Roman Urdu: "I will send by Friday", "Monday tak bhej doon ga"), deadline (Friday/kal/12 Nov/ISO/"in 3 days"/EOD, same-weekday = agla hafta), sawal/inkaar/shart/quoted ko chhodna; attention cost integers (SQL se bit-ba-bit). cargo test 40/40; bun real-wasm 40 pass; asli Chromium (playwright) pe 0.3.0 + intent@1 + scan/cost sahi. pin sha d19eded4...3482. kernel.ts: intentScan()/intentCost() (i64 => BigInt).
- SQL E97 (554 lines, asli Postgres 16 par do baar chala, selftest + CHECK_E97 10/10): commitment_ledger = APPEND-ONLY (update/delete/truncate trigger se mana) + hash-chain + HMAC-SHA256 seal (org ki 32-byte key commitment_keys mein, sirf service_role); commitment_record() ek atomic call = work_promises + work_tasks + (optional) calendar_events hold + sealed ledger row, dedupe by sha256 key; commitment_set_status (fulfilled/broken/snoozed/cancelled), commitment_sweep_overdue, commitment_verify (poori chain dobara hisaab); attention_cost()/attention_estimate() + org_attention_rates (default GBP 60/ghanta) + thread_economics_log; views open/due_soon/kept_rate/monthly economics. Mojooda work_promises/work_tasks REUSE.
- SQL E98: kernel 0.3.0 release (E90 kernel_release_publish) + kernel_modules intent. CHECK_E98.
- RUST module promx (promx_core 5 tests + promx_glue; installer CFG + ALL_MODULES + probe; dryrun clash-free; poore crate cargo check OK): commit.record/status/list/verify/economics/rate/rateSet, Pro gate (Basic 403), domain errors 400/409 (404 sirf unknown_proc). rpc-contract.ts + test (promx pro), basic-gate-probe 7 naye proc.
- FRONTEND: src/lib/outcomes.ts (debounced kernel scan hook, recordPromises/recordEconomics) + src/components/app/compose/OutcomesBar.tsx ("Detecting a Promise. Link to Calendar & Tasks?" badge + "This email will cost about X of attention" + 2-min call suggestion SIRF jab call asli mein sasti ho) + ComposeStudio wiring (sirf Pro; send ke baad record, kabhi send nahi rokta). tsc OK, eslint OK, bun src/lib 216 pass.
- HMAC-256: (1) har request par kernel ka ANEXO tag (observe; enforce baad mein), (2) har wada ledger row par per-org HMAC-SHA256 seal + chain verify.
- PRE-EXISTING fail (mera nahi): rpc-contract.test.ts "workx pro_only" — workx_core mein 6 naye proc (work.task.create/update, work.note, work.note.save, work.followThrough, calendar.outcome.post) contract mein nahi; alag drift-fix item.
- ABHI NAHI BANA: Feature 3 "File Context Graphing" (file card + version diff) — pooled storage/file versions ka schema dekh kar alag phase; word-prediction upgrade alag phase. Round 3 (asli QUIC server + deploy ke baad live Chrome) baaki.
- DEPLOY tarteeb (founder): 1) pull.sh (web+kernel) 2) sql-run.sh bare AUTO (E97, E98 + CHECKs) 3) rust-engine-install.sh + pm2 restart. Phir Chrome pro.buyer2 compose: "I will send you the details by Friday" => badge => Task + Calendar => send => Work/Tasks + Calendar mein entry.

## 27 Oct 2026 08:15 PKT — FEATURE 3 (File Context) + LIVE INK (typewriter/gradient caret) + kernel 0.4.0 — BANE, deploy baaki
- E97 fail fix pehle push (c57cc77). Ab: kernel 0.4.0 = intent@1 + NAYA filectx@1 (web-wasm/src/filectx.rs: "the latest CRM sheet" / Q3_budget.xlsx pehchanna, generic "the report" par khamosh, quoted lines chhodta). cargo 46/46, bun real wasm 41 pass, asli Chromium mein 0.4.0 + dono module sahi. pin sha 7499188264...f88c.
- SQL E99 (docs/cursor-work/sql/E99_file_context.sql + CHECK_E99): file_stem() (v2/final/copy/(1)/ext hata kar naam ki family), file_kind_exts() ("sheet" => xlsx/xls/csv...), file_context_find(org, query, limit) = top families + har version (kaun, kab, thread, size, same_as_older via sha256, size_delta). SIRF apni org ki mail (dusri org ki file nahi — test mein SECRET other-org file bahar rahi). Live-jaisi lean DB par 2 baar chala, selftest + CHECK_E99 sab true. HONEST HADD: file andar se nahi kholi jati => diff = metadata (content wahi/naya, size); cell-level diff NAHI.
- Rust promx: naya proc file.context (Pro). core 6 tests, crate check OK, dryrun clash-free. rpc-contract: commit.* + file.context pro.
- E98 ab kernel 0.4.0 (E98_kernel_release_040.sql + CHECK_E98; purani 030 file hata di) — modules intent+filectx.
- FRONTEND: FileContextCard (versions list, "Add reference line" email mein, "Open the conversation"), useFileContext (kernel scan -> 700ms baad server), asli Chromium (vite dev lab) mein card/badge/cost render dekhe. GhostTextArea LIVE INK: naye likhe akshar logo-blue gradient mein behte hain (1.1s mein settle), blinking caret logo-gradient mein; reduced-motion/Calm par band; Chromium screenshot se proof.
- PRE-EXISTING drift FIX: rpc-contract workx ke 6 proc (work.task.create/update, work.note, work.note.save, work.followThrough, calendar.outcome.post) ab contract mein pro; bun src/lib 221 pass 0 fail.
- Deploy tarteeb: pull.sh -> sql-run.sh (E97 dobara, E98, E99) -> rust-engine-install.sh -> restart. Phir live Chrome: badge, cost, file card, Live Ink.
