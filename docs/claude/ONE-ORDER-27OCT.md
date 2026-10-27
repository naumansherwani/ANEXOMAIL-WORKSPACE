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
