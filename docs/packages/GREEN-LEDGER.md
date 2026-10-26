# GREEN LEDGER — in par DOBARA code NAHI likhna (founder: "yeh codes nahi likhna hai, yeh green hai") — 26 Oct 2026 07:45 PKT
Har line: cheez | kahan | test. Naya Claude: pehle yeh padho, phir docs/packages/<pkg>/NOT-BUILT.md.

## GREEN (server-side asli + test ya SQL self-test)
- Basic limits: 5 users / 3 mailboxes / 15GB pool / 25MB / 1 domain -> E87 (+CHECK_E87), local PG PASS
- Pro limits: 20 users / 10 mailboxes / 300GB pool / 35MB / 3 domains -> E88 (+CHECK_E88), local PG PASS
- Booking links 1/3/20/unlimited -> E88 trigger + Rust book_glue (page_id/new/delete) + UI BookingPage; Rust 57 tests PASS
- Device vault 2/4/10/50 -> chat_phase_entitlements `device_vault` (pehle se)
- Billing card: £40/£105, user cap, pooled storage, seats_used asli -> get_billing_subscription (E87/E88)
- Mail Pro+ (Rust `pro_gate`): snooze, assign (collision guard), templates; + `pro_only_proc`: pre-send scan, follow-ups, snippets, handoff (unit test) ; schedule send (Bun mail-compose `proOnly`); per-thread analytics (Rust main.rs)
- Calendar: Overlap Matrix Pro+ (Rust 403 + UI), meeting cost meter Pro+ (UI), Find-a-time + 1 booking link har package
- Analytics ROUTE gates (plan-surface + `plan-surface.test.ts`)
- CRM base Pro+ (`showCrm`)
- Domains cap 1/3 -> `org_domain_cap` (E15)
## READY (repo + local tests; "green" live test deploy ke baad — Rule 29) — 26 Oct 08:50
- Analytics backend (E89 + Rust + Bun fallback + package gate); meeting cost server gate (Rust cal_glue); flat partner/revenue model; MFA TOTP + magic-link verify; `billing.revenueTruth` (E90); Business price £360 flat (plans.ts, plans.tsx)
- WASM KERNEL 0.2.0 (Rust async Tokio WebTransport; sha256+hmac+sniff+rank+live+rpc) + `/wt/rpc` + kernel-first rpc.ts/live.ts + attachment sniff + chat sha256; KERNEL CONSTITUTION E90 (+CHECK_E90)
- `python3 scripts/wire-audit.py`: 0 REAL GAP (HELD = AI billing/knowledge, COMING SOON)
## NOT GREEN -> docs/packages/*/NOT-BUILT.md
- Personal (HOLD), Business/Business Pro/Enterprise features (agle phases), live tests (deploy ke baad), Caddy udp/3443 /wt/rpc check

## LIVE GREEN (Basic, 26 Oct 09:15, Rule 29: browser mein tested)
- Analytics gates server par (responseDebt 200; threadEconomics/deepWork/leaks/promise/forecast/team 403) — HTTP + WebTransport
- Kernel 0.2.0: wasm hash pin, QUIC /wt/rpc, kernel.ticket/report, constitution policy (ok/upgrade/block)
- Meeting cost Basic = null; founder-only procs 403
## LIVE NOT GREEN
- MFA UI (Brain mein routes nahi: brain-kernel-install.sh), Pro-side positive tests (Pro account chahiye), kernel in-app rpcUp (anexoKernel Web pull ke baad dekhunga)
- LIVE GREEN 09:20: anexoKernel.rpcUp=true (browser mein kernel QUIC par), Two-step sign-in UI (MFA status route live)
- LIVE NOT GREEN: Bun analytics fallback (/api/analytics/* 404 -> brain-kernel-install.sh dobara), MFA enroll/verify flow (account badalta hai — founder ki ijazat se), Pro-side tests

## FOUNDER SIGN-OFF 26 Oct 09:15 PKT
- BASIC = **DONE / GREEN** (founder: "basic done hai green"). Is par dobara code nahi (sirf bug aaye to).
- PRO package = founder ne Polar update kar liya ("new package bhi updated"). Agla: Pro live test (Pro account login chahiye), phir Business.
- Baqi chhota: Bun analytics fallback (brain-kernel-install.sh dobara) — Rust primary theek hai.

- **Basic = DONE (founder 26 Oct 09:15).** Agla: Pro live test.
## LIVE GREEN PRO (26 Oct 09:30, Chrome, Pro account)
- Analytics gates: Pro = responseDebt/threadEconomics/deepWork 200; leaks/promise/forecast/team 403 Business+ (HTTP + WebTransport dono)
- Pro procs (Rust): follow-ups, snippets, draft handoff, Overlap Matrix, CRM suggestions — 200; founder procs 403
- Billing card: Pro £105.00/month, 300 GB shared, 1/20 users; plan grid flat (£40/£105/£360/£2,850)
- Kernel: anexoKernel.rpcUp true
- Meeting cost: object bheja jata hai (Basic null); hourly_total null jab attendee hourly rates set nahi — jhoota number nahi. Asli £ ke liye rates set honi chahiye (open: rates UI/entry)
- Sidebar: Analytics Domains ke upar (founder hukm 09:19)

## PRO GREEN BATCH 1 — 26 Oct 10:30 PKT (READY, deploy + live test baqi)
Technology: Rust :3200 (Tokio async) primary; same dispatch HTTP + WebTransport /wt/rpc; Bun = fallback gate; core std-only tests (cal_core 48 pass).
- Availability + Focus windows: Bun-only thay -> ab Rust procs calendar.availability / calendar.focus (cal_core::availability_slots, Pro+ gate), Bun fallback bhi Pro+.
- Files on a meeting (calendar.files.*): Rust Pro+ gate (calfile_glue).
- Meeting goal/outcome (calendar.meta.set with goal): Pro+ (calendar_key/remind Basic).
- Thread rescue (chat.bridge.rescue): Pro+ server gate (main.rs) — pehle ungated tha.
- Reading-time/level meter: Pro+ (UI; word count Basic).
- Promise recovery: Business+ (code+INV; PP1 ka P+ CEO ne override), Goals+deadlines: tasks ke saath Pro+ (work.tasks server gate).
- Baqi Pro: CRM P1 (pipelines/custom fields/duplicate merge), P2 (web forms) — founder haan.
- Deploy: Rust (rust-engine-install.sh) phir Web (pull.sh). SQL nahi. Phir Chrome: Pro 200, Basic 403.

## KERNEL REAL WIRING — 26 Oct 10:45 PKT (READY, deploy + live test baqi)
- Request tag HMAC-SHA256 end-to-end: client (boot.ts ticket + hmac@1 tag) -> Rust wtrpc_glue (kernel_session_key E91, local verify, cache) -> mode observe/enforce. wtrpc_core 10 tests; E91 SQL local self-test + CHECK_E91 4/4 ok, lint OK.
- Stats: anexoKernel.stats {kernel, fetch, tagged, untagged, ticketOk, ticketFail, lastFallback}. Warm: AppShell mount.
- Typed contract rpc-contract.ts + 4 tests (Rust drift guard). bun 271 pass, tsc OK.
- Deploy tarteeb: SQL (E91) -> Rust -> Web. Phir kernel-check.sh + Chrome: anexoKernel.stats.tagged > 0, server log valid>0 invalid=0. Tab enforce.

## PRO GREEN BATCH 1 — LIVE PROOF (26 Oct 10:35 PKT, founder server output)
- basic-gate-probe BASIC: Rust 17/17 PASS (403 on every Pro proc, open procs 200/400). PRO (pro.buyer): ALL PASS 21/21 (Rust + Bun fallback availability/focus 200).
- Brain: guroh A B C lagey (Bun fallback Availability/Focus gate live). Guroh D (revenue/release) drift = sirf purane comments; ACCEPT_LIVE hash se ab lagega.
- Chrome Pro: anexoKernel rpcUp, tagged calls, Rust availability/focus 200.
- Baqi Pro: calendar UI click-through, fallbackProcs (Bun-only endpoints -> Rust), CRM P1/P2 (founder haan), meeting-cost hourly rates UI.

## 26 Oct 2026 10:50 PKT — Pro GREEN: workx module (Rust, Tokio async)
- DONE (code, compile-checked, 5 unit tests): `server/rust/workx_core.rs` + `workx_glue.rs` — `work.tasks`, `work.promises`, `crm.overview` Bun se Rust par. Gate Pro+ (resolve_plan; Basic 403 `feature_not_available`). Formula Bun jaisa (migration). Installer `rust-engine-install.sh` mein `workx` (ALL_MODULES + CFG + probe).
- Wajah: Chrome `anexoKernel.fallbackProcs` mein in teeno par `kernel_status_404` tha.
- TODO (agla): `crm.live`, `org.members` (Business) Rust par; `kernelRpc` early-boot intezar (300-400ms); `ANEXO_TAG_MODE` observe->enforce jab invalid=0; CRM P1/P2 founder ke "haan" par.
- Founder ko: Rust phir Web command (founder-commands.md 10:50). Live saboot (Rule 29) deploy ke baad: Chrome Pro par fallbackProcs dobara.

## 26 Oct 2026 11:00 PKT — CRM P1 + P2 (founder "haan"): pipelines, custom fields, duplicate merge, web forms
- READY (code, tested locally; NOT green until deploy + Chrome proof, Rule 29): SQL `E92_crm_p1_p2.sql` + `CHECK_E92.sql` (throwaway Postgres 16: apply x2 idempotent, first-char-lost simulation, self-test, CHECK t); Rust `crmx_core.rs` (10 tests) + `crmx_glue.rs` (cargo check ok) — 15 procs: crm.pipelines.*, crm.fields.*, crm.custom.set, crm.dups.list, crm.merge, crm.forms.*, crm.board, crm.deals.move, crm.deals.setPipeline (Pro+ gate) and PUBLIC crm.form.get / crm.form.submit.
- Caps (atomic, advisory lock inside SQL): Pro 1 pipeline / 5 fields / 1 form; Business 5/25/10; Business Pro+ unlimited. Submit: honeypot + speed check + 30 per 10 min per form + same-email 1 hour dedupe.
- UI: `/app/crm/setup` (Pipelines, Custom fields, Duplicates, Web forms), `/f/<slug>` public form, server-driven pipeline board (own stages, pipeline picker, custom fields on card) with the classic six-stage board as fallback if server lacks E92.
- Bun fallback: NONE for the new CRM setup procs (new, Rust-only by design; classic board keeps working on Bun).
- Contract: rpc-contract.ts + test cover crmx and workx. tsc clean, bun 273 pass.
- TODO: deploy SQL -> Rust -> Web; Chrome Pro live proof (create 2nd pipeline must hit cap 403 on Pro; form submit makes lead; merge); then P3-P6 (Business). Catalog: N-CRM-01/02/03 MATCHES-CODE; N-RET-01/02, N-OFC-01 PROPOSED. docs/packages/pro/PRO-VS-ZOHO.md.

- 26 Oct 11:20 LIVE PROOF (founder server output): basic-gate-probe ALL PASS (basic) 22/22 — Rust 403 on all Pro procs, Bun fallback /calendar/availability + /calendar/focus 403 (guroh C Brain fix GREEN). drafts/threads/responseDebt 200, findtime 400 as designed.

## 26 Oct 2026 11:45 PKT — CRM P1+P2 LIVE TEST (Chrome, Pro pro.buyer@anexomail.com) — SQL+Rust+Web deployed by founder
PASS (live): Setup page 4 tabs; limits from server Pro 1/5/1 (UI "1 of 1 · Upgrade", New pipeline/New form disabled at cap); 2nd pipeline 403 limit_reached; pipeline validation (won must be 100, <2 stages) 400; default pipeline cannot be deleted (409);
fields: 5 created, 6th 403, duplicate key 403(cap first), select without options 400, edit label/options keeps key; custom.set: number/date/checkbox/select/unknown/too-long/bad id all validated; lead+deal custom values saved and shown on card; card "Fields" editor saved via real click (Gold -> Silver);
forms: 1 created, 2nd 403, form without required email 400; public /f/<slug> page filled + submitted in real browser -> "ZZ thanks" and lead created (owner = form owner, source form:<slug>); same email again = no 2nd lead; bad email 400; honeypot = silently dropped; unknown/malformed slug 404; value >500 chars 400; pause form => public get/submit 404, resume => 200; rename updates public page;
board: deals on server board with own stages; Move to via real select (New -> Negotiation = 75%); bad stage 400; won => 100% + stale null; setPipeline unknown 404; merge validation (no drop 400, foreign id 404);
Rust vs Bun equality: crm.overview all 8 numbers + 6 stage counts identical; work.tasks same ids; work.promises same count. basic-gate-probe 22/22 (before CRM checks added).
BUGS FOUND (fixed in repo, need redeploy): (1) crm.pipelines.save on an EXISTING pipeline returned 502 db_unavailable (create/cap/validation fine) — local Postgres cannot reproduce; E92 made type-safe (::text casts) + Rust now logs real DB error (pm2 logs "crmx rpc crm_pipeline_save failed") + read-only DIAG_crm_pipeline_update.sql; NOT green until founder re-runs SQL + Rust and retest passes. (2) crm.merge said "not in the same workspace" for a form lead + a Bun-created lead (org_id differs/null) — SQL check now scope-based (row org = scope or null); self-test covers cross-workspace reject. (3) CRM layout: pipeline page grew wider than the screen so "New deal" button sat off-screen (x=2149) — min-w-0 on CrmStage root. (4) merge with keep inside drop returned 404 — now 400.
NOT live-tested yet: pipeline edit (blocked by bug 1), merge click (blocked by bug 2), 30/10min form rate limit, Business caps (needs Business account), Basic 403 on crmx (probe lines added).
Test data left (no delete route in Bun): 3 ZZ test leads (zz.test.lead x2 pending merge, zz.test.fast), 2 ZZ TEST Deal, 5 ZZ fields, 1 ZZ form — founder may keep/delete; merge cleans the duplicates.

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

| 26 Oct 20:40 | kernel-check wasm retry fix (transient FAIL, live sha == pin 7b1ddb7c7e31) | GREEN (live curl 3/3) |

| 26 Oct 20:50 | Rust livex reinstall + health 200; basic-gate ALL PASS; kernel-check wasm retry 8x5s (500 warm-up) | basic GREEN; kernel-check dobara run baaqi |

| 26 Oct 21:00 | kernel-check ALL PASS, basic-gate ALL PASS (founder 20:46); PRO-GREEN-TRACKER items 1-5 GREEN | GREEN; item 6 calendar 502 fix deploy baaqi |

| 26 Oct 21:25 | calendar.availability/focus Pro 200 live (probe ALL PASS pro) + Chrome Avail. FREE slots; Pro live walk 9 features seen | GREEN item 6; walk partial |

| 26 Oct 21:42 | d59d059 deployed: basic ALL PASS, KERNEL ALL PASS | GREEN deploy; Chrome verify -£0/English baaqi |

| 26 Oct 22:00 | availability working-hours (local tz) code + 49 cal tests | CODE READY; live baaqi |

| 26 Oct 22:15 | availability working hours+tz LIVE (Chrome 16 slots 09:00); ALL PASS basic+pro+kernel | GREEN |

| 26 Oct 22:15 | PRO live walk: booking links 1/3, Overlap Matrix, snooze, domains/mailboxes/storage, CRM, compose, availability | GREEN (hourly-rate UI gap) |

| 26 Oct 22:40 | meeting cost hourly-rate field (calendar.rates/.set, Rust+kernel, no SQL) | CODE DONE; deploy+Chrome baaqi |

| 26 Oct 23:00 | meeting cost hourly-rate (calendar.rates, Chrome cost £50, probes ALL PASS) | GREEN |

- 26 Oct 23:30 Trusted devices N of limit: Rust security.devices ab 'limit' bhi deta hai (resolve_plan + chat_phase_entitlements device_vault: basic 2 / pro 4), /app/security/devices par 'Trusted devices: N of 4 on your plan'. security_glue.rs + security-platform.ts + app.security.devices.tsx + basic-gate-probe pro (limit 4). cargo check OK, tsc clean. DEPLOY BAAQI (Rust install + Web pull). Baaqi Pro: shared-inbox live collision (2nd user), ANEXO_TAG_MODE=enforce (founder env).

- 26 Oct 23:45 Office suite (Writer/Sheet/Show) = BUSINESS package (Rule 58, docs/packages/business/OFFICE-SUITE.md, AGENTS.md). Founder hukm: Rust check mein koi crate chhodna nahi — rustls+webpki-roots ke saath POORA security_glue compile (cargo check offline, cache se) = OK, 0 error.

- 26 Oct 22:45 Trusted devices limit DEPLOYED (e710790/c364828): Rust restart 176, Web pull OK, basic ALL PASS, pro ALL PASS (security.devices 200 + device limit 4 PASS), KERNEL ALL PASS (founder output 22:44). Chrome UI dekhna baaqi.

- 26 Oct 23:50 Pro CRM desk Bun -> Rust (module crmd, code ready, deploy baaqi): 11 procs crm.leads, crm.deals, crm.createLead, crm.createDeal, crm.moveDeal, crm.convertLead, crm.dealWork, crm.dealThread, crm.insights, work.promise.commit, work.promise.dismiss. LIVE LOOPHOLE jo mila: Chrome mein 'Capture lead' = POST /api/crm/leads (Bun REST), kernel nahi. Technology: Rust axum+Tokio async, wahi dispatch HTTP /rpc aur WebTransport /wt/rpc (kernel), Supabase PostgREST, std-only core crmd_core.rs (7 tests), crmd_glue.rs, cargo check OK (rustls ke saath poora crate), bun test 211 pass, tsc clean. Gate Pro+ server par (Basic 403), rpc-contract + probe. Naya: negative deal value 0 ho jati hai. count-endpoints.py ab get()/useCrmMutation wiring bhi pehchanta hai (125 -> 144 Rust-first). Baaqi Pro: crm.memory (GET /api/crm/memory), analytics/:report catch-all twin, mail.devices.seen (client nahi), handoff/follow-up DELETE twins (Rust proc maujood).

- 27 Oct 00:12 crmd DEPLOYED (b39121a): Rust restart 178 (modules ... crmx livex crmd wtrpc), Web pull OK, basic ALL PASS, pro ALL PASS (crm.leads/deals/insights 200; createLead/createDeal/moveDeal bad input 400), KERNEL ALL PASS (founder output 00:10). Chrome saboot (leads page kernel vs REST) baaqi.

- 27 Oct 00:50 LIVE test (Chrome, Pro, crmd deployed): lead capture (kernel, koi /api/crm REST nahi), Convert (deal Qualified 30%), Advance (Proposal 55%) = GREEN. LOOPHOLE mila+fix: deal 'Work' button 'org_id null' error — asli sabab work_tasks.source CHECK (manual|promise|meeting_outcome) ne 'crm_deal' roka; ab source=manual + source_deal_id (Rust crmd + Bun twin dono). Naya: crm.memory Rust port (12vi proc, Bun GET /api/crm/memory jaisa shape; 8 core tests). DEPLOY BAAQI: Rust install + Web pull (commands founder-commands). Pro ko Basic ke features: gate rank se milte hain (basic probe pro account par ALL PASS); Basic ke 110 Bun endpoints abhi migration baaqi (auth 24, billing-sync 12, contacts 10, integrations 10, trial 9, polar 7, security 7, settings 7, dashboard 5, storage 5, workspace 4, account-deletion 3, support 3, mail 2, calendar 1, locale 1) — agla: trial.state + auth.session.

- 27 Oct 00:25 TECHNOLOGY MAP likha: docs/claude/TECHNOLOGY-MAP-27OCT.md (founder sawal 00:19: kaun si technology, async/tokio/webtransport/trpc/quinn/QUIC kab kahan). Jawab: async Tokio + tRPC-style /rpc + WebTransport/QUIC (wtransport=quinn) + WASM kernel LIVE hain; baaqi = poori website ko kernel par laana (fetch 100 -> 0), 23 polls -> events (step L), ONE QUIC session K3 (Business phase), Enterprise Bun-free. Bun mein naya code NAHI (Rule 56). Asli npm tRPC library nahi (default Rust-native contract).

- 27 Oct 00:30 Work-fix + crm.memory DEPLOYED (0bde5b0): Rust restart 180, Web pull OK, basic ALL PASS, pro ALL PASS (crm.memory 400/400/200), KERNEL ALL PASS (founder 00:27). FOUNDER RULE (27 Oct 00:27): Basic ke saare features/endpoints latest technology (Rust+kernel) par banenge aur Basic AUR Pro dono ko milenge (starts_at=basic => upar ke sab packages ko bhi; ek hi code dobara nahi likhna). Live test: Chrome Work button + memory, loophole mile to usi waqt fix.

- 27 Oct 00:40 LIVE GREEN (Chrome, Pro, 00:40): deal 'Work' button -> toast 'Work opened', task 'zz.kernel@example.com — opportunity' /app/work mein; crm.memory (Relationships panel) kernel se (koi /api/crm/memory nahi): Open deals 1, 'No decision-maker meeting in 12 days'. LOOPHOLE mila+fix: Rust domain errors 404 dene par client Bun par fallback karta tha (deals/thread 404 -> Bun). Ab crmd mein 404 SIRF unknown_proc; baaqi 409 (deal_not_found, lead_not_found, no_thread_for_address, promise not_found). Test: rpc-contract.test.ts 'crmd: domain errors never use 404'. RULE (naye Rust glue ke liye): domain 'nahi mila' = 409, 404 sirf 'proc nahi'. DEPLOY BAAQI (sirf Rust install).

- 27 Oct 00:45 FOUNDER (27 Oct 00:30-00:31): 'rule 52 pe kero' + 'sab endpoints baaki ke is Rule 52 par jayenge' => har baaqi endpoint: browser -> WASM kernel -> Rust (async Tokio, /rpc + /wt/rpc) -> Supabase; fetch/Bun sirf fallback. TRIAL (Basic+Pro, har plan) Rule 52 par: client src/lib/trial.ts ab rpcOrRest (kernel-first): account.signup.state/start/claim/address (Rust main.rs pehle se) + naye 3 procs module trialx (account.signup.security/events/holds; trialx_core 2 tests + trialx_glue; installer CFG+probe; probe lines events/holds/state 200, security {} 400). Claim: Rust ok:false => client ApiError 409 (Bun jaisa). bun test 212 pass, tsc clean, cargo check OK. DEPLOY BAAQI (Rust install + Web pull). AGLA: auth.session (Rule 52 top REST), phir Basic baaqi 110 ek ek karke (basic+pro dono ko milenge).

- 27 Oct 00:40 HANDOFF #3 (27 Oct 00:40): sab likhe codes ki poori list + halat -> docs/claude/CODES-WRITTEN-LEDGER-27OCT.md (compact ke baad PEHLE yeh + MASTER-GREEN-PLAN + TECHNOLOGY-MAP padho). HEAD 3b1047c. Server par: crmd+memory+Work fix deployed; fd9ee91 (409) + 3b1047c (trialx+trial client) CODE READY, founder deploy output baaqi.

- 27 Oct 00:45 DEPLOYED 00:43 (founder output): fd9ee91 (409) + 3b1047c (trialx + trial client): Rust restart 182 (modules ... crmx livex crmd trialx wtrpc), Web pull OK, basic ALL PASS, pro ALL PASS (account.signup.events/holds/state 200, security {} 400), KERNEL ALL PASS. Chrome: /api/trial/state REST band hui? dekhna baaqi.

- 27 Oct 00:50 Trial LIVE GREEN (Chrome 00:50): fresh /app/crm/leads load par SIRF /api/auth/session REST (trial/state + deals/thread REST nahi). FRONTEND TECHNOLOGY PLAN likha (founder sawal 00:43): docs/claude/FRONTEND-TECHNOLOGY-PLAN-27OCT.md — React 19/TanStack/Tailwind 4 rewrite NAHI; F1 kernel fetch->0, F2 events (L), F3 Rust-WASM compute, F4 React Compiler+virtual lists, F5 SSR host Bun se bahar (Enterprise; abhi 'bun .output/server/index.mjs'), F6 chat media WASM Opus (K3), F7 Office CRDT, F8 offline PWA, F9 passkeys, F10 view transitions.

- 27 Oct 00:55 CINEMATIC FRONTEND STACK likha (founder 00:48: three.js jaisi latest cinematic technologies ki list): docs/claude/CINEMATIC-FRONTEND-STACK-27OCT.md. Pehle se installed+live: three 0.185, R3F 9.7, drei, postprocessing, GSAP 3.15 (ScrollTrigger unused), motion/framer 13, lottie, tone (unused). ADD list: WebGPU+TSL, ScrollTrigger/Lenis, Theatre.js, Rapier WASM, GLSL Moon shaders, Web Audio/AudioWorklet, OffscreenCanvas, KTX2/Draco, Rive, View Transitions, Spline/glTF. Qaide: cinematic sirf landing/onboarding/chat/dashboard accent; kaam ke screens fast; lazy+fallback+measure.
