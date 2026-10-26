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

## B. CEO FAISLA (26 Oct 22:05 PKT, founder: "yeh faisla tumne kerna hai, tum CEO ho; pehle ke sab kaam isi mein dalo") — FINAL TARTEEB, isi se chalna
Har qadam: ek ek GREEN (founder output + Chrome saboot), phir agla. Naya kaam sirf Rust + kernel; Bun sirf fallback.
| # | Qadam | Kya | Kyun yeh jagah |
|---|---|---|---|
| 1 | PRO WALK poora | public booking links(3), Overlap Matrix, shared inbox collision guard, snooze UI, hourly-rate/Focus UI, 4 trusted devices — Chrome mein dikhana; jo na dikhe woh theek karna | Pro package aaj customer ko bik raha hai; jo card par likha woh account mein nazar aana chahiye |
| 2 | RULE 52 top REST: `trial.state`, `auth.session` (read-only) | har page par 66 REST calls kam | sab se bada fetch; kam risk (sirf padhna) |
| 3 | M3: contacts+companies, storage state, workspace, dashboard, billing-sync, support (polar NO-TOUCH) | 51 endpoints | Pro ke daily features (People, Storage, Billing card) |
| 4 | M4: auth (login/logout/MFA/recovery/sessions) + trial baaqi | 33 | login-critical => differential test, ek ek |
| 5 | M5: org, settings, security, integrations, analytics, calendar leftovers, crm leftovers | 91 | Business ke liye zaroori + Pro settings |
| 6 | PRO GREEN CLOSE: ANEXO_TAG_MODE=enforce (founder env), saari Pro-relevant routes kernel 100%, PRO-GREEN-TRACKER sab GREEN | | Pro = "green" tab |
| 7 | BASIC package poora (har gate/endpoint probe + Chrome walk) | | Basic sab se zyada users |
| 8 | L: 23 polls -> WebTransport live events | | live feel, kam load |
| 9 | BUSINESS: M6 chat/ai/files + ANEXOChat + K3 (ONE QUIC, kernel 0.3.0) + N-DOC-01 + Business caps | 180 | Business phase |
| 10 | CRM P3-P6 (Blueprint P4) | | Business ke baad |
| 11 | BUSINESS PRO | | |
| 12 | F: founder/admin/perf/movein/glitch (alag batch) | 32 | internal |
| 13 | ENTERPRISE (Rust-only, Bun-free) + toolchain (sqlx pool, mimalloc, moka, tracing) | | akhir |
Pehle ke sab kaam (Pro tracker items, ANEXOChat K3 plan, CRM P3-P6, tag enforce, passkey Oct 27, Rule 52 G1/G2) ISI table ke qadam mein hain — alag list nahi.
Har port ka tareeqa: X_core (std-only tests) + X_glue + installer CFG/probe + rpc-contract + probe + Chrome Bun-vs-Rust proof; phir Bun route hatana.
Master Pro list: docs/packages/pro/PRO-GREEN-TRACKER.md. Halat/ginti: docs/cursor-work/MIGRATION-STATUS-26OCT.md.
