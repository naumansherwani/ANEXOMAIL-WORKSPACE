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

- 27 Oct 01:00 FOUNDER 00:51: poori cinematic list ab se implement hogi + WebXR VR/AR 'must aye ga' => Rule 60 (AGENTS.md) + CINEMATIC-FRONTEND-STACK section E (route-wise 'kahan hoga': landing/about/plans, auth/claim/checkout, loaders, dashboard, CRM stage, calendar globe, anexochat Moon, anexovideocall WebXR, kaam wale screens cinematic NAHI, founder_ lab) + item 12 WebXR Business+ K3 ke baad. Rule 52: data kernel se, 3D sirf UI.

## 27 Oct 2026 01:05 PKT — Website flow (Rule 52 + cinematic) dikhaya
Founder 00:54 ne poocha website kaise banegi: diagram dikhaya (UI+cinematic -> WASM kernel -> QUIC -> Rust Tokio -> Supabase). Likha: docs/claude/TECHNOLOGY-MAP-27OCT.md section 5. Agla kaam: auth.session Rule 52 port, phir Basic baaqi 110.

## 27 Oct 2026 01:25 PKT — auth.session CODE LIKHA (authx) — deploy pending
authx_core.rs (6 tests pass) + authx_glue.rs: Rust 'auth.session' (profile, workspace_plan, account_kind, orgs merge, active org, onboarded, display name) Bun sessionResult ka hu-ba-hu. Full crate cargo check (rustls+ring+webpki) PASS. auth.tsx ab rpcOrRest('auth.session') (Bun GET /api/auth/session fallback). Installer authx + probe + basic-gate-probe shape check. tsc OK, bun test 212 pass. Login/refresh/logout Bun par (alag). Agla: founder deploy output -> Chrome proof, phir Basic 110.

## 27 Oct 2026 01:55 PKT — BATCH PLAN + Batch A (contx) CODE
docs/claude/BATCH-PLAN-27OCT.md: batches A-F (gate/UI/halat). Batch A contx: contacts.list/tags/get/update/tag/timeline, companies.list/get/timeline, search.universal — sab plans, koi gate nahi; contx_core (4 tests) + contx_glue, full crate cargo check PASS; lib/contacts.ts -> rpcOrRest; installer+probes; bun test 213. Deploy pending (authx+contx ek saath). Agla: Batch B (storage/workspace/support/dashboard.ai-usage).

## 27 Oct 2026 02:20 PKT — Batch B (basx) CODE: storage x5, support.sla(public)/drafts/draftDiscard, dashboard.ai-usage, workspace.setActive
basx_core (2 tests)+basx_glue, full crate cargo check PASS (authx+contx+basx). LOOPHOLE band: Bun support/drafts + discard BINA login chalte the -> Rust mein login+org zaroori. Storage preflight/reserve allowed:false par 200+body (Rule 59). Clients: storage-client, SlaProof, AppShell, join -> rpcOrRest. Installer basx (public) + probes. bun test 213, tsc OK. Deploy pending: authx+contx+basx EK deploy (founder-commands 02:20). Agla: Batch B2 workspace.personal/organisations/invitations, phir C billing-sync, D settings/integrations/security, E account-deletion/mail/calendar/locale, F auth.

## 27 Oct 2026 02:40 PKT — auth.session LIVE GREEN (authx)
Founder deploy 01:19: Rust restart 184, Web pull OK, basic/pro ALL PASS (auth.session 200 + shape), KERNEL ALL PASS. Chrome proof: /app/people fresh load par /api/auth/session REST NAHI (sirf kernel). Top REST ab sirf contacts/companies/tags (contx deploy pending) — unka /rpc 404 -> Bun fallback sahi chal raha (fallback saboot). NOTE: founder ne 01:19 par PURANA (authx-only) command chalaya; Rust list mein contx+basx abhi NAHI. Dobara wahi 6 commands chalane hain (founder-commands 02:20) — installer ab contx+basx lagayega.

## 27 Oct 2026 02:55 PKT — INSTALLER FAIL fix (basx)
Founder deploy 01:24: installer ruk gaya ('dashboard.ai-usage' live main.rs mein pehle se Rust par) — kuch install NAHI hua, server wahi purana, KERNEL ALL PASS, kuch toota nahi (safe-stop). Galti: mera clash-scan dhila tha. Fix: dashboard.ai-usage basx se hata diya (basx ab 9 procs). Naya docs/cursor-work/server/installer-dryrun.sh: deploy se PEHLE installer ka patch-step repo main.rs par chalta hai + proc clash scan; authx contx basx dry-run PASS, full crate cargo check PASS. LESSON: har naye module par dryrun pehle, phir founder ko command.

## 27 Oct 2026 03:05 — PRO GREEN ginti (founder sawal 01:27)
Pro green close = ~8 deploys: Pro-only 4 endpoints (1), Basic-shared ~81 (6: B2 workspace, C billing-sync, D settings/integrations/security, E account/mail/cal/locale/trial, F auth login), + tag enforce (founder env) + shared-inbox collision test (2nd Pro user) + calendar UI click-through. Detail: docs/packages/pro/PRO-GREEN-TRACKER.md (03:05). Abhi deploy pending: contx+basx (installer fix 452dd4e, dry-run PASS).

## 27 Oct 2026 03:30 — contx+basx DEPLOYED; Basic storage 500 fix
Founder deploy 01:37: Rust par ab authx contx basx; Pro ALL PASS; KERNEL ALL PASS; Basic par storage.state/preflight 500. Wajah: DB chat_ensure_workspace Basic (chat nahi) ko 'chat_not_entitled' raise karta hai — purana Bun bhi Basic ko 500 deta tha (purani bug), mera Rust copy kar gaya. Fix basx: chat workspace na ho to chat_members, warna plan-based jawab (resolve_plan + storage_plans) — state/preflight/reserve/commit/release; input jaanch pehle. basx_core 3 tests, crate check PASS, dry-run PASS. Deploy: sirf Rust install+restart+probes (web unchanged).

## 27 Oct 2026 03:50 — LIVE GREEN (Chrome, Pro): contx + basx
Chrome (pro account): /app/people khula, data kernel se (REST /api/contacts|companies|tags GAYAB; sirf kernel.ticket). /app/storage khula: 'Plan pro, Model Pooled workspace' kernel se, REST nahi. Website TOOTI NAHI: har page render, Pro probes ALL PASS, KERNEL ALL PASS. Basic storage.state/preflight 500 ka fix 4065cd0 deploy pending (purani Bun bug thi). GREEN ab: authx, contx(10), basx storage Pro + support/setActive probe PASS. Baaqi fail sirf Basic storage (fix pushed).

## 27 Oct 2026 03:55 — authx + contx + basx LIVE GREEN (founder deploy 01:49)
Founder output: Rust par ab '... trialx authx contx basx wtrpc'; Rust restart 190; Web pull OK; ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. 15 purane FAIL ka sabab: us waqt installer ruk gaya tha (ai-usage clash) — fix 452dd4e; Basic storage 500 fix 4065cd0 — dono deployed, ab 0 FAIL. GREEN (code dobara NAHI likhna): auth.session; contacts.list/tags/get/update/tag/timeline; companies.list/get/timeline; search.universal; storage.state/preflight/reserve/commit/release; support.sla(public)/drafts/draftDiscard; workspace.setActive. Chrome proof Pro: people+storage kernel se, REST gayab. Endpoint ginti: Rust-first 161, baaqi 362. AGLA: Batch B2 workspace.personal/organisations/invitations, phir C billing-sync 12.

## 27 Oct 2026 04:20 — Batch B2 (wsx) CODE: workspace.personal + workspace.organisations
wsx_core (3 tests: slugify, personal_slug, normalize_org_domain jaisa Bun regex, name>=2) + wsx_glue (organisations[owner_id retry] -> org_members[status retry, fail=rollback] -> account_organisations+account_org_members -> orgs -> mail_accounts attach -> account_profiles.workspace_kind+onboarded). Clients: auth.tsx, onboarding.tsx, claim.tsx, ConvertToBusiness.tsx -> rpcOrRest (Bun fallback). invitations = team.invites.create (Rust pehle se). Full crate check PASS, dry-run PASS (authx contx basx wsx), tsc OK, bun 213. Probes: bad name/domain 400, personal existing:true. Deploy pending.

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

## 27 Oct 2026 02:15 PKT — wsx creation-path assurance: stamp_kind fix + live test script
- LOOPHOLE mila (static schema check): account_profiles mein email/legal_name/display_name NOT NULL; profile-row-less naye user ka workspace_kind stamp chup-chaap fail hota (Bun mein bhi yehi bug). FIX server/rust/wsx_glue.rs `stamp_kind(uid,email,kind)`: row na ho to email/legal_name/display_name (email ka local part) ke saath insert. cargo check clean (scratch /tmp/axchk). Rust re-install zaroori (wsx dobara).
- NAYA docs/cursor-work/server/wsx-live-test.sh: 2 throwaway zz.wsx.<ts>.* users (GoTrue admin, password screen par nahi), workspace.personal (created, phir existing:true, wahi org), workspace.organisations (business); organisations/org_members/account_organisations/account_org_members/orgs/mail_accounts/account_profiles rows check; phir sirf apne zz rows saaf. Pass = "ALL PASS (wsx live)". Abhi founder ne CHALAYA NAHI — result pending.
- Ginti (count-endpoints.py): 523 total, Rust-first 163, remaining 360. Basic-shared baqi ~83: auth login 24, billing-sync 12, integrations 10, trial 9(3 baqi after trialx6?—recount), polar 7 (NO-TOUCH), security 7, settings 7, account-deletion 3, mail 2, calendar 1, locale 1. Pro-only baqi 4 (mail/handoff DELETE, mail/devices/seen, mail/follow-up DELETE, analytics/:report). NOTE: ENDPOINT-PACKAGE-MAP.csv ka status column purana hai (contacts/storage ab done) — ginti ke liye count-endpoints.py maano.
- Category jawab: endpoint->package = docs/claude/ENDPOINT-PACKAGE-MAP-26OCT.md/.csv (starts_at: basic/pro/business/business_pro/founder/internal/ai_soon), gate-table docs/claude/PP1-FULL-GATE-TABLE-26OCT.md, features docs/packages/features.tsv, Rule 57 (server gate resolve_plan, UI sirf mirror).
- AGLA: founder wsx re-install + wsx-live-test.sh ALL PASS -> tab Batch C billing-sync (pehle billing-sync.ts poora padhna, Polar NO-TOUCH).

## 27 Oct 2026 02:30 PKT — Personal HOLD; PEHLA kaam Business Polar payment
Founder: Personal package alag se (Gmail/Outlook jaise private users, alag UI/gates) — HOLD. Pehle Business ki Polar payment (Basic/Pro jaisa edit). Kiya: docs/claude/POLAR-COPY-V6-BUSINESS.md (honest copy, £360/£3,960, IDs unchanged), server/config/billing-products.ts v6 flat amounts (perSeat false) + test. Baqi: founder Polar edit + live checkout test, landing Business card overclaim, pull.sh.

## 27 Oct 2026 02:40 PKT — Business Pro Polar copy: docs/claude/POLAR-COPY-V6-BUSINESS-PRO.md (2850/28500, IDs unchanged, honest). Baqi: founder Polar edit + checkout test; phir Pro green par wapas.

## 27 Oct 2026 02:42 PKT — Business FINAL copy (founder verbatim): docs/claude/POLAR-COPY-V6-BUSINESS.md + src/lib/plans.ts Business card isi ke mutabiq (13 lines, overclaims hata di; tsc/bun test 213 pass). Founder ka hukm: "saray packages in ke hisab se" => Business Pro, phir Pro/Basic card+Polar isi andaaz mein match hon (Business Pro card abhi overclaim wali, baqi). DNS-proven-green line: I3-17 live proof baqi.

## 27 Oct 2026 02:45 PKT — Business Pro FINAL copy + plans.ts card match (overclaims hata di). Founder: 8K/40-person/AV1 ladder bane nahi, ANEXOChat blueprint mein banenge — tab tak Polar/landing mein nahi (DEFERRED list docs/claude/POLAR-COPY-V6-BUSINESS-PRO.md). Baqi: founder Polar edit (Business + Business Pro), checkout test; phir Pro green par wapas.
## 27 Oct 2026 02:50 PKT — Business Pro copy founder ke purane text ke andaaz mein final (570 users/10TB/60MB/12h priority support; Decision ledger + Email-chat bridge hata ke, bante hi jodna). plans.ts card match.
## 27 Oct 2026 02:55 PKT — Business Pro REALITY copy (founder: sach offer karo, codes se). Code audit table docs/claude/POLAR-COPY-V6-BUSINESS-PRO.md; unverified lines hata di (5GB, latest technology, real delete, search chat/files). TODO-1: Business/BP v6 enforcement SQL (60/570 users, 1.5/10TB, 45/60MB). plans.ts match. Business (360) copy ki bhi isi tarah audit baqi (DNS-green line, 15GB transfer/2GB send enforcement verify).
## 27 Oct 2026 02:52 PKT — Founder: sab plans par unit "/ month" (Business Pro ka "/ company / month" hata); "for the whole company, up to N users" wazahat tagline/userCap mein.

## 27 Oct 2026 02:58 PKT — Landing lists wapas (founder ki lambi Business 59 + Business Pro 53 lines: git 1181acb se restore). Jo bana nahi (calls/codec/QUIC/ring/8K/group calls/Decision ledger/Email-Chat bridge/Safety review/Sealed evidence/Ban list/Suspicious-device/Final-warning) unke aage " — coming with ANEXOChat" (Business 16, BP 21+). Polar checkout copy REALITY (chhoti list) alag rehti hai. Baqi audit: baaki lines (200/5,000 work objects, 5GB, etc.) ki enforcement verify.

## 27 Oct 2026 03:02 PKT — COMPACT-SAFE STATE (agla session yahin se shuru)
1. PRIORITY BADLI: Personal package HOLD (alag UI/gates, Gmail/Outlook jaise private users, baad mein). Business Polar payment = pehle kaam (ho chuka repo side).
2. REPO DONE (push): Polar copy Business (docs/claude/POLAR-COPY-V6-BUSINESS.md, 360/3960) + Business Pro (POLAR-COPY-V6-BUSINESS-PRO.md, 2850/28500, REALITY audit table) ; billing-products.ts flat v6 (40/105/360, perSeat false); plans.ts: sab plans unit "/ month"; Business 59 + BP 53 lines landing par, unbuilt par " — coming with ANEXOChat". Polar par sirf chhoti sach wali list.
3. FOUNDER BAQI: (a) Polar edit 4 products (Business M/Y, Business Pro M/Y) + checkout test £360.00/£2,850.00; (b) web pull.sh; (c) wsx: rust-engine-install + restart + docs/cursor-work/server/wsx-live-test.sh => "ALL PASS (wsx live)" (stamp_kind fix deploy) — commands founder-commands.md 02:15 block; output Claude ko; (d) Business copy mein DNS-green line (I3-17 proof) faisla; yearly Business 1 vs 2 month free faisla.
4. TODO sach banane ke: Business/BP v6 enforcement SQL (users 60/570, pool 1.5/10TB, attach 45/60MB) ; search mein chat/files ; Decision ledger, Email-chat bridge, calls (ANEXOChat blueprint); 200/5,000 work objects, 5GB verify.
5. PRO GREEN AGLA (tarteeb): wsx proof -> Batch C billing-sync 12 (billing-sync.ts poora padho, money, Polar :3400 NO-TOUCH, Bun fallback) -> D settings7+integrations10+security7 -> E deletion3+mail2+calendar1+locale1+trial -> Pro-only 4 (mail/handoff DELETE, mail/devices/seen, mail/follow-up DELETE, analytics/:report) -> login24 last -> Calendar Chrome click-through, ANEXO_TAG_MODE=enforce, shared-inbox 2nd-user test, passkey mandatory.
6. Ginti 523 total / 163 Rust-first / 360 baqi (count-endpoints.py); Basic-shared baqi ~83.
7. RULES: har turn repo+ledgers update (sahi waqt: system date PKT), manifest-sync (DEPLOY-MANIFEST.txt khud nahi) + verify "0 bad", full deploy commands, koi code dobara nahi, Roman Urdu "aap".

## 27 Oct 2026 03:06 PKT — CEO FAISLE: (1) Business yearly = 2 months free = £3,600 (360x10); Business Pro £28,500 (2 months). plans.ts + billing-products.ts 3960->3600, annual two-months-free. Founder ko Polar Business YEARLY price £3,960 -> £3,600 dobara edit karna hai (description: "£3,600 per year ... (two months free)"). (2) DNS-green line Polar copy se HATI (ownership proof I3-17 bana nahi, checkout par overclaim = refund/trust risk); landing par "coming with domain ownership proof"; jab dnsauth proof live ho tab wapas. Polar 4 products founder ne green kar liye (Business yearly ab 3600 par dobara).

## 27 Oct 2026 03:08 PKT — Batch C1 (billx): billing.state, billing.stateHealth, billing.claimGuest — Rust code + installer + probes (DEPLOY PENDING)
billing-sync.ts poora padha: subscription/invoices/portal/settle pehle se Rust-first. C1 = padhne wale 3 (Polar call nahi). LOOPHOLE band: Bun/Rust state-health ab FOUNDER-only (pehle har login wala company ke gaps/alerts dekhta tha). Files: server/rust/billx_core.rs (3 tests) + billx_glue.rs, installer ALL_MODULES+CFG+probe, basic-gate-probe +4 checks (state 200, stateHealth non-founder 403, claimGuest 400 x2), billing-sync.ts founder check, app.billing.state.tsx -> rpcOrRest. cargo check clean, tsc clean, bun test 371 pass. C2 (intent, change-plan, guest-intent, cron sync, pull-truth = asli paisa) FOUNDER KI IJAZAT + shadow-mode ke baad (repo POLAR-CONTROL-PLANE-PLAN: live checkout reedh). claimGuest ka src mein koi client caller nahi (grep).

## 27 Oct 2026 $T PKT — TRIAL 48h design (founder): docs/packages/TRIAL-48H-DESIGN.md. Alag gate/data (no mixing), 48h server countdown, expire par login = seedha /plans, Pro jaisi cheezein trial limits ke saath, latest tech must. Banega: Pro green -> Founder account -> Trial. trial.ts ke baaqi 6 endpoints migrate NAHI (Batch E se nikale). C2 rok diya; agla Batch D (settings+integrations+security 24).
## 27 Oct 2026 03:25 PKT — TRIAL folder docs/packages/trial/ (README, FEATURES-AND-GATES, DATA-ISOLATION, NO-MOCK-AND-ONBOARDING, BUILD-PLAN). Founder approve; NO mock data; trial = individual account_kind trial; CEO: basic ANEXOChat (text/photo/doc, 1:1 + group max 5, 2 guests invite) BINA calls/voice; send 25/din, attach 10MB, storage 1GB, CRM 25 records; banega Pro green -> Founder account -> Trial.

## 27 Oct 2026 03:33 PKT — LIVE PROOF (founder output): billx + wsx-fix + Business/Pro changes DEPLOYED. ALL PASS (basic) + ALL PASS (pro) + KERNEL CHECK ALL PASS. Rust list: ... authx contx basx wsx billx wtrpc. server-git-sync: SAB SAME (allowed farq sirf bun.lock + routeTree.gen.ts) => differ=1 bekhatar. billing.state/stateHealth/claimGuest probes PASS (non-founder 403 = loophole band).
wsx-live-test.sh pehli baar chala: BUG MERA ("line 23: kind: unbound variable") — FIX kiya (EM alag line). Dobara chalana baaqi => tab hi 'naye user ka workspace' GREEN. Script pehle hi gir gayi: kuch banaya/badla nahi.
TRIAL update (founder 03:30): convert mein sirf 'Start fresh' (Keep-data hata), trial ka chuna email/address naye real package ke saath alot; trial calendar ke SAB features. Docs: docs/packages/trial/*.
## 27 Oct 2026 03:34 PKT — CHROME LIVE CHECK /plans: Basic £40, Pro £105, Business £360, Business Pro £2,850 sab '/ month' (dohra nahi), 'Get 2 months free' Business/BP, 59 features Business par; landing mein 'coming with ANEXOChat' dikh rahe. Do call-lines (Answered/declined ring result, Every connection step timed) par label chhoot gaya tha — fix pushed. Baqi: wsx-live-test dobara chalana (bug fix ke baad).

## 27 Oct 2026 03:43 PKT — wsx LIVE TEST (founder run): 8/10 workspace-table checks PASS (organisations, org_members, account_organisations, account_org_members, orgs, mail_accounts, existing:true shape, same-org, cleanup) — workspace BANTA hai. 2 REAL BUG MILE: (1) profile stamp (workspace_kind/onboarded) fail: upsert mojooda row par bhi INSERT-tuple banata hai, NOT NULL email/legal_name/display_name khali => chup-chaap fail. FIX wsx_glue.rs stamp_kind: row hai => PATCH, nahi => poori INSERT. (2) test script 'true' vs 'True' (mera typo) — theek. Rust re-install + wsx-live-test dobara => tab hi GREEN. server-git-sync dobara: SAB SAME.
