# CODES KAUN SE LIKHE GAYE — LEDGER (27 Oct 2026 00:40 PKT) — compact ke baad PEHLE YEH PADHO
Halat: **LIVE GREEN** = server par deploy + probes ALL PASS + Chrome mein dekha. **DEPLOYED** = server par, probes pass, Chrome baaqi. **CODE READY** = repo mein push, server par pull NAHI hua. **In par dobara code NAHI likhna.**

## A. Rust modules / procs (async Tokio, /rpc + /wt/rpc, kernel)
| Kya | File(s) | Commit | Halat |
|---|---|---|---|
| Availability: working hours + local timezone (`tz_offset`) | cal_core.rs, cal_glue.rs, calendar.ts | 6a1d91e | LIVE GREEN |
| Meeting cost hourly rate `calendar.rates`/`.set` | cal_core/cal_glue, MeetingCostSettings.tsx, calendar.ts | bfcdd69 | LIVE GREEN |
| calendar.availability/focus 502 fix (org-only) | cal_glue.rs | 4bd9dbc | LIVE GREEN |
| Trusted devices "N of limit" (`security.devices` + `limit`) | security_glue.rs, security-platform.ts, app.security.devices.tsx | c364828 | LIVE GREEN (Chrome: "0 of 4") |
| **crmd** Pro CRM desk: `crm.leads/deals/createLead/createDeal/moveDeal/convertLead/dealWork/dealThread/insights`, `work.promise.commit/dismiss`, `crm.memory` (12 procs) | crmd_core.rs (8 tests), crmd_glue.rs | b39121a, 0bde5b0 | LIVE GREEN (lead/convert/advance/Work/memory Chrome mein) |
| deal->Work bug fix (work_tasks.source CHECK: source=manual + source_deal_id) | crmd_glue.rs, server/routes/crm.ts | 0bde5b0 | LIVE GREEN |
| Rule 59: domain error 409 | crmd_glue.rs + test | fd9ee91 | DEPLOYED (probes ALL PASS 00:43) |
| **trialx** trial `account.signup.security/events/holds` | trialx_core.rs (2 tests), trialx_glue.rs | 3b1047c | LIVE GREEN (Chrome 00:50: trial REST band) |
| Trial client Rule 52 (state/start/claim/address/events/holds/security via kernel) | src/lib/trial.ts | 3b1047c | LIVE GREEN (Chrome 00:50: trial REST band) |
| livex `crm.live` + `org.members` | livex_core/glue | ff882b4 | LIVE GREEN |
| crmx CRM P1+P2 (pipelines, fields, forms, merge) | crmx_core/glue | earlier | LIVE GREEN |
| Pre-send scan English; CRM `money()` "-£0" fix | mailx_core.rs, mail-compose.ts, crm.ts | d59d059 | LIVE GREEN |

## B. Tooling / rules / docs
- kernel-check.sh wasm retry 8x5s (91d55ef); basic-gate-probe.sh pro-mode checks (devices limit 4, crm.*, account.signup.*).
- count-endpoints.py ab `get()`/`useCrmMutation` wiring bhi gintaa hai (Rust-first 125 -> 145).
- Rules: **52** (kernel), **56** (no Bun in new work), **57** (endpoint->package map), **58** (Office suite = Business), **59** (404 sirf unknown_proc) — AGENTS.md.
- Docs: MASTER-GREEN-PLAN.md (13 steps), MIGRATION-STATUS-26OCT.md, ENDPOINT-PACKAGE-MAP(.csv/-26OCT.md), PRO-LIVE-GREEN-26OCT.md, PRO-GREEN-TRACKER.md, TECHNOLOGY-MAP-27OCT.md, packages/business/OFFICE-SUITE.md, docs/claude/README.md index.

## C. FOUNDER ke standing hukm (bhoolna mat)
Roman Urdu, "Nauman bhai"/"aap", sada zaba; har message mein POORI ordered commands (SQL -> Rust install+restart+health -> Web pull -> sleep 20 -> probes: basic-gate-probe basic + MODE=pro EMAIL=pro.buyer@anexomail.com + kernel-check); har turn repo context update + manifest 0 bad + push; naye code mein Bun nahi; **Basic ke endpoints Basic+Pro dono ko milte hain (ek hi code)**; **sab baaqi endpoints Rule 52 par (kernel)**; live test mein loophole mile to usi waqt fix; Business/Business Pro plans ke landing/profile/billing(Polar) baad mein (Polar NO-TOUCH).

## D. Agla (tarteeb)
1. Deploy output: fd9ee91 (409) + 3b1047c (trialx) -> Chrome: /api/trial/state ab nahi aani chahiye -> GREEN.
2. `auth.session` Rule 52 (login path: fallback pehle jaisa).
3. Basic baaqi 110 (auth 24, billing-sync 12, contacts 10, integrations 10, polar 7 NO-TOUCH, security 7, settings 7, dashboard 5, storage 5, workspace 4, account-deletion 3, support 3, mail 2, calendar 1, locale 1).
4. Pro baaqi: ANEXO_TAG_MODE=enforce (founder env), shared-inbox live collision (2nd Pro user), Bun twins hatana (proof ke baad).
5. Step L (23 polls -> events), Business/K3/Office suite, CRM P3-P6, Business Pro, Enterprise (Bun-free).
Test data Pro account: leads zz.kernel/zz.bunprobe/zz.test.*, deals "zz.kernel@... — opportunity", ZZ TEST Deal, rates 60/40 — founder chaahe to saaf.
