# PRO GREEN TRACKER — tarteeb se (founder hukm 26 Oct 2026 20:46: "ek ek cheez tarteeb se green mark kero"; compact-safe, PEHLE YEH PADHO)
Qaida: GREEN tab likha jata hai jab LIVE saboot (founder server output ya Chrome) ho. Naya kaam sirf Rust + WebTransport/WASM kernel (Rule 56). Har naye deploy ke saath Rule 46 tarteeb: SQL -> Rust install + pm2 restart + health -> Web pull -> (sleep 20) probes.

| # | Kaam | Status | Saboot / agla qadam |
|---|---|---|---|
| 1 | Pro CRM P1+P2 (pipelines, fields, forms, merge, board) | GREEN | live 26 Oct (merge UI, pipeline edit 200, keep∈drop 400, form rate limit 30/31) |
| 2 | crm.live + org.members Rust | GREEN | Rust livex installed 20:02/20:3x, Chrome Bun-vs-Rust barabar |
| 3 | Rule 52 guard + early-boot (kernel 9 / fetch 0 CRM page) | GREEN | rule52.test.ts 16 checks, kernel-check ALL PASS (20:46) |
| 4 | basic-gate-probe | GREEN | ALL PASS (basic) 20:46 |
| 5 | kernel-check wasm hash | GREEN | ALL PASS 20:46 (retry 8x5s) |
| 6 | calendar.availability/focus khali input 502 -> 200 | GREEN (founder Pro probe 20:56: availability 200, focus 200, ALL PASS pro; Chrome Avail. FREE slots dikhte hain) |  <!-- --> wajah: calendar_focus_windows mein created_by column nahi; ab org_id-only, org na ho to khali list. Founder: Rust install; probe pro mode mein 200 check karta hai. Phir GREEN |
| 7 | Calendar Availability/Focus UI click-through + hourly-rate UI | PENDING | Chrome (Pro account) mein dekhna |
| 8 | ANEXO_TAG_MODE=enforce | PENDING (founder env) | observe valid=76 missing=0 invalid=0 => taiyar |
| 9 | Rule 52 poori website: trial.state | NEXT | Rust port (trial_core/glue), Chrome Bun-vs-Rust |
| 10 | auth.session (Phase A, GoTrue HTTP se) | QUEUED | login-critical; pehle Rust==Bun saboot |
| 11 | /account (mfa, sessions, recovery), companies, contacts+tags, storage/state, integrations, crm.leads | QUEUED | REST list RULE-52-REST-INVENTORY.md |
| 12 | Unmeasured routes (mail, settings, org, security, admin, perf, founder, public) + /app/work, /app/safety re-check | QUEUED | kernel/fetch ginti |
| 13 | Direct fetch() uploads (13 file) | BUSINESS PHASE (K3 stream) | docs/packages/business/ANEXOCHAT-K3-PLAN.md |
| 14 | Business caps live test | BUSINESS ACCOUNT chahiye | Business phase |
| HOLD | Personal Pro £46, partner meeting | founder ki alag meeting | -- |
NOT Pro: Writer/Sheet/Show (N-DOC-01 collaborative docs) = Business (PROPOSED, bana nahi).

## LIVE FEATURE WALK — Pro account pro.buyer (Chrome, 26 Oct 20:57-21:20) — "jo user ko offer kiya woh account mein nazar aana chahiye"
| Card feature | Live nazar aaya? | Note |
|---|---|---|
| Domains (3) / mailboxes (10) | HAAN — /app/domains "1 of 3 domains · Pro", "0 of 10 mailboxes" | |
| 300GB shared storage, 35MB transfer | HAAN — /app/storage "Mailboxes 1 of 10, Max single transfer 35 MB, pool 300 GB" | "File engine" Business ka (by design) |
| Calendar + Availability + Calendar settings (working hours, rooms, out of office) | HAAN | GREEN 21:50 (Chrome Avail. 16 slots 09:00-17:00) |
| Compose: templates, snippets (zzm2), follow-up, schedule send, undo-send 30 s | HAAN (undo "Not sent" saabit) | |
| Pre-send scan | HAAN — Rust mail.confidence 200 (attachment_promised, risky_tone, external_domain, score 73) | BUG FIXED: message Roman Urdu tha -> English (Rust+Bun) |
| Work: tasks, promises, Work chain Pro | HAAN | Decision ledger = Business (by design) |
| Analytics Center (7 tabs: Response debt, Thread economics, Deep work...) | HAAN pages render | data tabs ka asli data dekhna baaqi (naya account, khali) |
| CRM: Overview, Leads, Pipeline, Relationships, Accounts, Tasks, Reports, Setup | HAAN | BUG FIXED: "-£0" (negative zero) -> "£0" in crm.ts money() |
| Devices | HAAN — /app/devices | "4 trusted devices" ka limit UI mein dekhna baaqi |
| Public booking links (3), Overlap Matrix, Snooze UI | HAAN GREEN (22:10, PRO-LIVE-GREEN-26OCT.md) | agla Chrome pass: calendar toolbar booking button, World clocks, Mail > Assigned to me, thread snooze menu, meeting form hourly rate |
| Passkey banner "required from Oct 27" | dikha — kal se lazmi | founder ko yaad dilana |

## 22:10 UPDATE: booking links (1 of 3), Overlap Matrix, snooze menu, Thread insight LIVE GREEN — docs/claude/PRO-LIVE-GREEN-26OCT.md. Baaqi sirf: hourly-rate UI (GREEN 22:30), shared-inbox live collision (2nd user), trusted devices 4 UI, tag enforce.

## 27 Oct 2026 03:05 — PRO GREEN KITNA BAAQI (ginti repo map se)
| Hissa | Baaqi | Deploy |
|---|---|---|
| Pro-only Bun endpoints (map: 7; asal 4: mail/handoff delete, mail/devices/seen, mail/follow-up delete, analytics/:report; promise commit/dismiss + crm.insights Rust crmd par pehle se, map lag) | 4 | 1 |
| Basic-shared (Pro bhi use karta hai): authx LIVE GREEN; contx+basx deploy pending; B2 workspace 3; C billing-sync 12; D settings 7+integrations 10+security 7; E account-deletion 3+mail 2+calendar 1+locale 1+trial 9; F auth login 24 (risky, aakhir); polar 7 NO-TOUCH | ~81 | ~6 |
| Tracker #7 Calendar UI click-through (Chrome) | 1 | 0 (sirf dekhna) |
| Tracker #8 ANEXO_TAG_MODE=enforce (founder env) | 1 | 1 command |
| Shared-inbox live collision (doosra Pro user chahiye) | 1 | founder |
Kul ~8 deploys + 2 founder kaam. Ek deploy = 6 commands, ek batch ek package.

## 27 Oct 2026 03:50 — LIVE GREEN (Chrome, Pro): contx + basx
Chrome (pro account): /app/people khula, data kernel se (REST /api/contacts|companies|tags GAYAB; sirf kernel.ticket). /app/storage khula: 'Plan pro, Model Pooled workspace' kernel se, REST nahi. Website TOOTI NAHI: har page render, Pro probes ALL PASS, KERNEL ALL PASS. Basic storage.state/preflight 500 ka fix 4065cd0 deploy pending (purani Bun bug thi). GREEN ab: authx, contx(10), basx storage Pro + support/setActive probe PASS. Baaqi fail sirf Basic storage (fix pushed).

## 27 Oct 2026 03:55 — authx + contx + basx LIVE GREEN (founder deploy 01:49)
Founder output: Rust par ab '... trialx authx contx basx wtrpc'; Rust restart 190; Web pull OK; ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. 15 purane FAIL ka sabab: us waqt installer ruk gaya tha (ai-usage clash) — fix 452dd4e; Basic storage 500 fix 4065cd0 — dono deployed, ab 0 FAIL. GREEN (code dobara NAHI likhna): auth.session; contacts.list/tags/get/update/tag/timeline; companies.list/get/timeline; search.universal; storage.state/preflight/reserve/commit/release; support.sla(public)/drafts/draftDiscard; workspace.setActive. Chrome proof Pro: people+storage kernel se, REST gayab. Endpoint ginti: Rust-first 161, baaqi 362. AGLA: Batch B2 workspace.personal/organisations/invitations, phir C billing-sync 12.

## 27 Oct 2026 01:59 PKT — COMPACT-SAFE STATE (sab se latest; PEHLE YEH PADHO)
TIME NOTE: aaj ki entries mein 02:20/02:40/02:55/03:05/03:30/03:50/03:55/04:20 wale stamps meri galti hain (session clock); asli waqt abhi 01:59 PKT. Entries ki TARTEEB hi sahi tarteeb hai.
LIVE GREEN (founder output + Chrome): authx (auth.session), contx (contacts x6, companies x3, search.universal), basx (storage x5, support.sla/drafts/draftDiscard, workspace.setActive), pehle ke: crmd (12 CRM), trialx (6), security.devices limit. Basic+Pro ALL PASS, KERNEL ALL PASS (01:49).
CODE LIKHA, DEPLOY PENDING: Batch B2 wsx (workspace.personal + workspace.organisations) commit 13df117/1513354 — founder ko 6 commands diye (founder-commands.md). Installer ab: authx contx basx wsx.
AGLA (tarteeb): C billing-sync 12 (Polar :3400 NO-TOUCH) -> D settings7+integrations10+security7 -> E account-deletion3+mail2+calendar1+locale1+trial9 -> Pro-only 4 (handoff delete, devices/seen, follow-up delete, analytics/:report) -> F auth login 24 (aakhir, fallback) -> tag enforce (founder env) + shared-inbox test (2nd Pro user).
RULES: har naye module pe PEHLE docs/cursor-work/server/installer-dryrun.sh + full crate cargo check (rustls+ring+webpki scratch /tmp/axchk), phir founder ko 6 commands; clash scan; Basic account se bhi probe (Basic ke paas chat workspace nahi — chat_ensure_workspace error deta hai). Founder ghussa: tabahi nahi, safe-stop tha; credit zaya na ho — code dobara mat likhna, batch-wise.
GINTI: 523 endpoints, Rust-first 163 (after wsx 2 = ~163), baaqi ~360. Gate/UI plan: docs/claude/BATCH-PLAN-27OCT.md. Pro baaqi ~8 deploy: docs/packages/pro/PRO-GREEN-TRACKER.md.
TECH: browser React19/TanStack/Vite8/Tailwind4 -> WASM kernel 0.2.0 -> QUIC/WebTransport (/wt/rpc) ya /rpc -> Rust axum/Tokio -> Supabase PostgREST; Bun sirf fallback; cinematic (three/R3F/GSAP/WebGPU/Theatre/Rapier/WebXR) sirf Rule 60 jagah, kaam wale screens nahi.

## 27 Oct 2026 02:08 PKT — wsx (workspace.personal/organisations) LIVE: probes ALL PASS
Founder deploy 02:08: Rust par ab '... trialx authx contx basx wsx wtrpc', Rust restart 193, Web pull OK, ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. Probe saboot: bad name/anexomail domain/bad domain => 400; existing workspace => existing:true (koi naya workspace nahi bana). KHULA ITEM (loophole): NAYA-USER creation path (organisations->org_members->account_*->mail_accounts->profile stamp) LIVE nahi aazmaya — asli workspace banta, isliye probe mein nahi; sirf unit tests (slug/domain) + Bun fallback. Isay saaf test account (naya signup, zz.*) se Chrome mein aazmana hai PEHLE pro ko awam ke liye green kehne se. PRO GREEN STATUS: koi bhi item chhoot'na nahi — baaqi list GREEN-LEDGER/PRO-GREEN-TRACKER mein.

## 27 Oct 2026 04:03 PKT — QADAM 2 (Pro-only 4) = KHATAM, asli sach: registry blind-spot tha (template paths + const PROCS + alias). count-endpoints.py theek kiya: ALIAS table (18 verified Rust twins) + PROCS arrays + match-arm scan. ASLI: 523 total, Rust-first 187, baaqi 336. Basic+Pro 195: 123 Rust (63.1%), baaqi 72 (login 23, integrations 10, trial 9 deferred, polar 7 NO-TOUCH, security 7, settings 7, billing C2 5, deletion 3, calendar export 1). Pro-only 0. Pehle ka '57%' / '68 kaam' andaaza galat tha (founder ne mana kiya) — ab registry se. Probe +3 (followup.delete, handoff.delete, device.seen). AGLA: qadam 3 Batch D (settings 7 + integrations 10 + security 7).
## 27 Oct 2026 04:24 PKT — Pro asli baaqi 7 (work tasks GET/POST, tasks PATCH, follow-through, notes GET/POST, meeting outcome): client naam Rust mein nahi, Bun par chalte hain. Pehla 'Pro-only 0' ghalat tha. Batch D (settings/integrations) code ready, deploy baaqi.

## 27 Oct 2026 04:37 PKT — BUG (mera): workspace.personal mojooda company workspace par bhi workspace_kind='personal' stamp karta tha; basic-gate-probe (MODE=pro) har run mein ye call karta hai => pro.buyer business->personal ho gaya, UI ne auth.session account_kind=personal se 'Personal Pro+' surface dikhayi (Pro gates band dikhe). Fix: wsx_glue existing branch ab mojooda kind ko NAHI chhoota (sirf kind na ho to personal likhta hai, aur asli kind lautata hai). Repair: docs/cursor-work/server/fix-buyer-kind.sh (sirf 4 *.buyer, personal->business, pehle/baad). Order: Rust install + restart PEHLE, phir fix script, phir probes. cargo check poori crate OK. Server DB: buyer-accounts-look.sh se saboot (pro.buyer kind=personal, baaqi buyers business).

## 27 Oct 2026 04:49 PKT — PRO CHROME WALK (pro.buyer, live): GREEN = sidebar Pro card (repair ke baad), dashboard (300GB), domains '1 of 3 domains · Pro' + '0 of 10 mailboxes', mail inbox, compose (templates, snippets, version history, follow-up reminders, 30s hold), calendar (month/week/day, Avail., Load, meeting cost), work (tasks board, promises, work chain Pro, Decision ledger 'Business and above'), CRM overview/pipeline, analytics 7 tabs, security devices 'Trusted devices 0 of 4 on your plan', settings save + history. RED: (1) compose Attach button 'up to 19 MB per message' — Pro vaada 35 MB: mail_attach_limits.server_ceiling_bytes = 18_874_368 (E49) har plan ko 18 MiB par rokta hai; Basic 25 MB ka vaada bhi isi se toota. Safe nayi hadd 36_700_160 (Pro): base64 se 49.1 MB < Postfix 52.4 MB; PEHLE naapna: clamd StreamMaxLength + Postfix message_size_limit (attach-check.sh), phir E89. Business 45 MB / BP 60 MB ke liye Postfix limit badhani paregi. (2) settings revert: pehli tabdili ka from_value NULL => revert '' likhta tha (toggle off reh gaya) — Rust mein theek (default_value wapas), deploy baaqi; Bun fallback mein wohi bug (Rule 56: Bun ko haath nahi). NOT CHECKED: 3 booking links, 20 users cap, shared-inbox collision (2nd Pro user), snooze/schedule-send click, People. Pro GREEN CLOSE abhi nahi.

## 27 Oct 2026 05:03 PKT — Claude: Pro 7 endpoints Rust mein + SQL E93/E94 (CODE READY, deploy baaqi)
- **Pro 7 endpoints** (work.task.create/update, work.followThrough, work.note, work.note.save, calendar.outcome.post; GET tasks alias work.tasks) workx module mein Rust: `server/rust/workx_core.rs` (+validators, follow-through hisaab, tests pass) + `workx_glue.rs`. Pro gate server par (Basic 403). Full crate `cargo check` OK (patched main.rs, saare modules). Registry: **523 total, 176 Rust-first, 347 baaqi; PRO 51/51, Pro mein 0 baaqi**. Probes basic-gate-probe.sh mein joray (Basic 403 / Pro 400,200).
- **SQL E94_plan_promises.sql** (+CHECK_E94): plan_promises registry (Basic+Pro server wade, Business/BP = todo, jhoot nahi), plan_promise_audit(), plan_promise_ok(), v_plan_promise_gaps, plan_promise_log + snapshot. Lint OK.
- **SQL E93_attach_ceiling_35mb.sql** (+CHECK_E93): server ceiling 18MiB -> 35MiB (36_700_160). SIRF `attach-limit-measure.sh` mein Pro "SAFE" aane ke baad chalao (Postfix + clamd StreamMaxLength). Founder khud naapega.
- Deploy tartib: attach-limit-measure.sh -> (SAFE ho to) sql-run.sh (E93, E94) -> deploy-pro.sh (Rust install+restart+pull+probes). Business/BP v6 enforcement abhi TODO-1.

## 27 Oct 2026 05:12 PKT — founder server par: clamd 64M + SQL E93/E94 GREEN (CHECK sab OK)
- clamd StreamMaxLength/MaxFileSize 25M -> 64M (backup /etc/clamav/clamd.conf.bak-27oct), clamav-daemon active. sql-run: E93 + E94 + CHECK_E65/E93/E94 sab OK. Pro 7 Rust endpoints ka deploy (deploy-pro.sh) baaqi.

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
