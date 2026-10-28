> **SUPERSEDED (27 Oct 2026): tarteeb ke liye sirf docs/claude/ONE-ORDER-27OCT.md.** Yeh file reference/history hai; isse naya kaam shuru na karein.

# MIGRATION STATUS — 26 Oct 2026 22:30 PKT (founder: "repo ki ek ek line padh kar batao implementation-green ka goal kahan tak baaqi hai")
Padha: MIGRATION-PHASES-RUST-PRIMARY.md, MIGRATION-PHASES-24OCT.md, MIGRATION-LEDGER-24OCT.md + CSV (script `count-endpoints.py` se DOBARA nikali), TECH-MAP/TECH-AUDIT/TECH-STACK-BEAST, AUTH-MIGRATION-PLAN, RULE-52-*, PRO-GREEN-TRACKER, GREEN-LEDGER.
Qaida (24 Oct, locked): PEHLE ~510 Bun endpoints latest technology par; PHIR packages ek ek green (Pro -> Business -> Business Pro). Aaj founder ne is mein jora: Rule 52 (browser har call kernel se) + Rule 56 (naya kaam Rust only) + "sab packages green".

## 1. Ginti (script, 26 Oct)
| Cheez | Ginti |
|---|---|
| Bun REST endpoints (server/routes) | 523 |
| Client Rust-first (rpcOrRest, Bun sirf fallback) | 125 (~24%) |
| Baaqi | 398 (~76%) |
| Rust procs repo mein | 335 (28 glue + 31 core modules, server/rust ~42,500 lines) |
Caveat: yeh ginti "client wiring pattern" naapti hai. Aaj ka CRM (crm.pipelines/fields/forms/merge/board/live, work.*, org.members) Rust par hai aur Chrome mein kernel se chalta hai, lekin crm.ts "0 Rust-first" dikhata hai kyunke naya kaam `kernelRpc` se jata hai, `rpcOrRest` se nahi. Asli browser naap (Rule 52, 35 routes): kernel 214 / fetch 100 (68% kernel).

## 2. Phase-wise halat (M = Mail/Lane A phases, tarteeb 24 Oct se)
| Phase | Kya | Halat | Baaqi endpoints |
|---|---|---|---|
| P0 | tokio/axum/tRPC-style /rpc, WT events, mail.send/schedule, passkey (9), calendar+rooms | DONE | 0 |
| M1 | thread actions (labels/status/move/assign/snooze), templates save/delete | LIVE GREEN | 0 |
| M2 | drafts+versions, templates list, snippets, signatures, follow-up, handoff, confidence, thread note | LIVE GREEN (24 Oct Chrome; 26 Oct founder "M2 GREEN") | mail 3, mail-compose 1, handoff 2, billing-support 1, locale 1 = ~8 chhote leftovers |
| **M3** | contacts 10, companies, workspace 4, storage 10, dashboard 5, support 3, billing-sync 12, polar 7 (polar :3400 NO-TOUCH, sirf state) | **NAHI SHURU** (Rust procs: contacts/companies/storage/workspace = 0) | **51** |
| M4 | auth 24 (+9 passkey DONE), trial 9 | NAHI SHURU (Phase A plan: AUTH-MIGRATION-PLAN) | **33** |
| M5 | org 27, crm 24 (aaj P1+P2+live Rust), calendar 3, settings 13, security 8, integrations 13, analytics 3 | PARTIAL (crm/org.members/calendar Rust; baaqi nahi) | **91** |
| L | 23 `refetchInterval` polls -> WebTransport events | NAHI SHURU | 23 polls |
| M6 | chat 141 (Rust mein 102 chat.* procs, cutover saabit nahi), ai 12, ai-credits 11, files 11, ai-automation 5 | PARTIAL procs; cutover baaqi (Business phase: ANEXOChat K3) | **180** |
| F | founder/admin 8/perf 8/movein 11/glitch 4/release 1 (Lane C alag batch) | PARTIAL (founder 6, release 12, revenue 2 done) | **32** |
| P5 | lane B: personal/family, account-deletion 3 | NAHI SHURU | 3 |
| B8/P10 | toolchain, sqlx direct pool, mimalloc, moka, tracing | NAHI SHURU | -- |
Jod: 8+51+33+91+180+32+3 = 398 baaqi.

## 3. M3 ke baad kab? (jawab)
Koi calendar tareekh repo mein nahi; sirf TARTEEB locked hai: M2b leftovers -> **M3** -> **M4** -> M5 -> L -> M6 -> F -> B8/P10. Aaj founder ke hukm se Rule 52 ke measured top REST (auth.session + trial.state = 66 of 100 fetches) ko M4 ke andar se AAGE kheench kar pehle karna hai (sirf do read-only procs: `trial.state`, `auth.session`; baaqi M4 (login/logout/MFA) baad mein).

## 4. Package-green ka goal (implementation green)
Pro: gates + features server-side green (probes ALL PASS basic/pro); live walk mein booking links/Overlap/shared inbox/snooze/hourly-rate/devices dikhna baaqi + 398 endpoints mein Pro-relevant jo Bun par hain (contacts/companies/storage/billing state/settings/security/integrations). Qaida 24 Oct: "Pro not green jab tak uske Bun-only endpoints Rust par nahi". => Pro green = M3 + M4 (auth/trial) + M5 ka Pro hissa + Chrome walk.
Business/Business Pro/Business Premium: M5/M6 + K3 (ANEXOChat, ONE QUIC) + N-DOC-01 + CRM P3-P6.
## 5. Agla qadam
M2b leftovers (chhote) -> M3 batch 1: `trial.state` + `auth.session` (Rule 52 top REST), phir contacts+companies, storage state, workspace, dashboard, billing-sync; har ek X_core+X_glue+installer+probe+Chrome Bun==Rust.
