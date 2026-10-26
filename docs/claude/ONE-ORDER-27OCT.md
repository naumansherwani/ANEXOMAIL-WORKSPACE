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
| 2 | **Pro-only baaqi 4** | mail/handoff DELETE, mail/devices/seen, mail/follow-up DELETE, analytics/:report | baaqi |
| 3 | **Batch D** (M5) | settings 7 + integrations 10 + security 7 (paisa nahi) | baaqi, AGLA |
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

## Ginti (count-endpoints.py): 523 total | Rust-first 163+3 (billx) | baaqi ~357. Basic-shared baaqi ~80 (Polar 7 NO-TOUCH, login 24 aakhir).

## M-series ka nakshe se milan
M1/M2 = DONE. M3 = contacts/storage/support/workspace DONE, billing-sync = C1 DONE, C2 qadam 6. M4 = auth.session DONE, login qadam 6, trial qadam 10. M5 = settings/integrations/security qadam 3, org/crm/calendar baaqi qadam 4+11. M6 = qadam 11-12. F = qadam 9. L = qadam 8. Purani locked order ("Founder account -> identity tests -> M-series -> G16 -> T") BADAL gayi: ab Pro green + migration PEHLE; G16 DONE.
