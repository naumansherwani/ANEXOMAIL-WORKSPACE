# MASTER GREEN PLAN — puri website, har gate, har endpoint, har package (founder hukm 26 Oct 2026 21:53 PKT) — PEHLE YEH PADHO
Founder (verbatim ma'na): "puri website ka ek bhi corner nahi chodna; sab gates green; sab end points latest technology (Rust + WebTransport/WASM kernel) par migrate aur green; basic, pro, aur in ke ilawa SAB packages green; repo mein tarteeb dekho aur tarteeb se chalo."
Qaida: GREEN = LIVE saboot (founder server output + Chrome). Naya kaam sirf Rust + WASM kernel (Rule 52/56). Bun sirf emergency fallback; route tab hatao jab Rust==Bun saabit ho.

## A. DEPLOYED / GREEN — DOBARA CODE NAHI LIKHNA (server par pull ho chuka, founder output saboot)
| Cheez | Commit | Saboot |
|---|---|---|
| Pro CRM P1+P2, crm.live, org.members Rust (livex) | d6d9240 etc. | Chrome Bun==Rust |
| Rule 52 early-boot, REST audit hook, guard tests | 288346f..cb20531 | kernel 9/fetch 0 |
| kernel-check retry 8x5s | 91d55ef | KERNEL CHECK ALL PASS |
| calendar.availability/focus 502 fix (focus_windows org_id only) | 4bd9dbc | ALL PASS (pro) 20:56 |
| "-£0" money() fix, pre-send scan English | d59d059 | deployed 21:36, ALL PASS |
| Availability working hours + local tz (tz_offset, work_hours) | 6a1d91e | deployed 21:48: ALL PASS basic+pro+KERNEL; Chrome Avail. = 16 slots, 9:00 AM se (09-17) |
Server abhi 55eafce par hai (docs-only baad ka commit). `src differ=1` = routeTree.gen.ts (benign).

## B. TARTEEB (isi order se, ek ek green)
1. PRO baaqi: live walk mein na dikhe — public booking links(3), Overlap Matrix, shared inbox collision guard, snooze UI, Focus/hourly-rate UI, 4 trusted devices UI; ANEXO_TAG_MODE=enforce (founder env).
2. RULE 52 poori website (REST -> kernel): trial.state, auth.session, /account (mfa/sessions/recovery), companies, contacts+tags, storage/state, integrations, crm.leads; phir unmeasured routes (mail, settings, org, security, admin, perf, founder, public) naapna; Bun-only endpoints (511 Bun vs ~328 Rust procs, TECH-AUDIT-24OCT) Rust par: pehle Pro mail actions, snooze/schedule live events, contacts/companies/workspace/storage/billing state, auth(18)+trial(7), org/crm/calendar, chat(141) + ai last.
3. BASIC package: har gate + endpoint Rust par green (docs/packages/basic/*).
4. BUSINESS: ANEXOChat + K3 (G1/G2 ONE QUIC, kernel 0.3.0) -> docs/packages/business/ANEXOCHAT-K3-PLAN.md; N-DOC-01 collaborative docs; Business caps live (Business account chahiye).
5. CRM P3-P6 (Blueprint P4) -> docs/packages/crm.
6. BUSINESS PRO -> docs/packages/business_pro.
7. ENTERPRISE (Rust-only) -> docs/packages/enterprise.
8. Har package ke liye: har gate probe (basic-gate-probe MODE=...), har RPC contract (rpc-contract.ts), Chrome live walk table, GREEN-LEDGER line.
Har port ka tareeqa: X_core (std-only tests) + X_glue + installer CFG/probe + rpc-contract + probe + Chrome Bun-vs-Rust proof; phir Bun route hatana.
Master Pro list: docs/packages/pro/PRO-GREEN-TRACKER.md.
