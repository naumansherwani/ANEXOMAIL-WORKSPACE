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
