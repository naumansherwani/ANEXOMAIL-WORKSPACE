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
