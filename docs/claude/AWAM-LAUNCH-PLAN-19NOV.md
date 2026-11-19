# AWAM LAUNCH PLAN: 30 NOV - 30 DEC 2026, SEMINAR 17 JAN 2027, LONDON (written 19 Nov 2026 11:4x PKT, his order 11:23). AWAM ONLY, never mixed with the founder file.
His ask: how many days do the awam Basic package gates, the migration (advance technology), Business and Business Pro with AnexoChat need so the website can launch; Business Premium and Business MAX have no code yet and run entirely on the founder's technology. Window: 30 Nov to 30 Dec. London on 17 Jan, so 16 Jan is travel and is NOT a work day.

## 1. What the repo says (facts, not guesses)
- 822 frozen Lovable files, 475 Bun endpoints; Rust twin existed for 169, so 306 are Bun-only (3 Nov map, re-checked per file when its phase starts).
- Of the 306: AnexoChat chat.ts = 141 (0 twins); AI files = 54 (ai 21, ai-automation 14, ai-credits 10, ai-studio 9), AI is a separate product from July 2027 and is NOT migrated now; so the real migration without chat and AI is about 111 endpoints (files 11, admin 10, perf 8, auth 23, org 20, settings 6, billing-sync 5, polar 5 and so on).
- Already done on the awam side: calendar 17/17, mail-compose 17/17, contacts 10/10, auth-passkey 9/9, crm 13/22, mail 13/14. PRO is GREEN. Premium and Max numbers exist as written, preserved, built = false code (AWAM-QLIVE-TIERS-18NOV.md: 25 / 100 live streams, 30 days log, 125,000 users per company cap with 90 % / 95 % alerts).
- The founder lane (Q series + R3) finishes 25 Nov, spill-over buffer 26-29 Nov. The awam turn starts 30 Nov.

## 2. Days needed (my estimate from the endpoint counts and my pace on the founder lane: about 10 endpoints per day with parity test + loophole pass + looks; it is an estimate, not a promise)
| Block | Work | Working days |
|---|---|---|
| AW0 gates | Basic, Business, Business Pro: server-side plan limits, per-company RLS, billing ledger, Polar link, upgrade paths | 4 |
| AW2 transport | K5b Rust rustls terminator, TLS 1.3 + AES-256-GCM, X25519MLKEM768, HTTP/3, closes WEBSITE-PROMISES P2 (needs his openssl proof) | 3 |
| AW3 sign-in | passkey only, no 2FA, DBSC device-bound sessions, kernel verify (twins mostly exist) | 3 |
| AW4 mailbox | the founder mailbox moulded for the awam: trust ring, compose, sealed mail, attachments | 5 |
| AW1 migration | about 111 non-chat, non-AI endpoints to Rust twins, parity tests, loophole pass | 11 |
| AnexoChat core | channels, messages, presence, live (WebTransport + SSE fallback): about 50 of the 141 endpoints | 5 |
| Premium + MAX | 25 / 100 streams, 30-day log, company-own-domain mailbox, 125,000 cap alerts, all on the founder's modules | 4 |
| AnexoChat rest | the other about 91 endpoints | 7 |
| Tests, looks, polish | parity suite, 390 / 820 / 1200+ looks of every package screen, landing AI link -> "Coming soon", rehearsal | 4 |
| TOTAL | | 46 working days |
31 days sit between 30 Nov and 30 Dec, 46 days sit between 30 Nov and 15 Jan (the 16th is travel). 46 does not fit 31, so the order below decides what is LIVE on 30 Dec and what finishes by 15 Jan. If the pace is faster than my estimate, dates move earlier; if slower, the last blocks slip first.

## 3. The dated plan v2 (HIS ORDER 19 Nov 11:28: migration goes package by package, FIRST Basic, THEN Business, THEN Business Pro; the gates (plan limits, RLS, billing) are written INSIDE each package's migration, together with its endpoints). Package contents follow the feature ladder in AWAM-PACKAGES-PROPOSAL-07NOV.md: Basic = email + calendar + contacts; Business = Basic + team chat / file sharing + org admin; Business Pro = Business + multiple teams, advanced admin / audit, big files.
| Dates | Package block | Inside it | Ready |
|---|---|---|---|
| Mon 30 Nov - Wed 16 Dec (17 days) | **1. BASIC** | its gates (5 users, 15 GB, 3 mailboxes, 25 MB attachment, billing ledger, Polar link) 2 d; the shared base every package needs: K5b transport 3 d (his openssl proof), passkey sign-in + DBSC 3 d, awam mailbox 5 d; its endpoints (mail, auth, settings, billing, trial, storage, security, integrations, about 45) 4 d | Basic is complete and can be sold |
| Thu 17 - Sat 26 Dec (10 days) | **2. BUSINESS** | its gates (60 users, 1.5 TB pool, 45 MB attachment, 500 MB chat file, pooled transfer) 1 d; org admin + files + admin endpoints (about 41) 4 d; AnexoChat core (channels, messages, presence, live: about 50 endpoints) 5 d | Business is complete |
| Sun 27 Dec - Mon 5 Jan (10 days) | **3. BUSINESS PRO** | its gates (570 users, 10 TB, 100 MB attachment, 1.5 GB chat file, 28.5 TB pool) 1 d; advanced admin / audit, perf, remaining CRM about 17 endpoints 2 d; AnexoChat rest (about 91 endpoints: calls, big files, multi-team) 7 d | Business Pro is complete |
| Tue 6 - Fri 9 Jan (4 days) | Business Premium + Business MAX | no code today; they run on the founder's technology: 25 / 100 streams, 30-day log, company-own-domain mailbox, 125,000-user cap with 90 % / 95 % alerts | the two top packages |
| Sat 10 - Thu 15 Jan (6 days) | tests, 390 / 820 / 1200+ looks of every package, landing "Coming soon", seminar rehearsal | | seminar-ready |
| Fri 16 Jan | travel | | |
| Sat 17 Jan | SEMINAR, London | | |
**What is live on 30 Dec because of this order: Basic complete, Business about 60 % (gates + org admin + files done by 22 Dec, AnexoChat core finishes 26 Dec).** I say it plainly: his order puts Business Pro on 5 Jan, not 30 Dec; the 46-day estimate does not fit 31 days, whatever the order. If my pace is faster than my estimate every date moves earlier; if slower, the LAST blocks slip first (Premium / MAX, then Business Pro's AnexoChat rest). (Seminar date: he said 17 Jan; older files say 16 Jan; I use 17 Jan.)

## 4. What I need from him (his hands, one step at a time when each block comes)
openssl proof for AW2; payment link choice stays Polar (his word); Hetzner written confirmation for company-own-domain mailboxes (Premium / Max); phone 390 and tablet 820 screenshots at each block's end; his go for the Syria wall.

## 5. Honest risks
1. The 46 days are an estimate; the biggest single block is migration (11) and AnexoChat (12). 2. Premium and Max are scheduled AFTER the 30 Dec launch set because they reuse the mailbox and the stream limits; if he wants them first, Business Pro features move after them. 3. No AI in the awam; AI files stay preserved. 4. Nothing here starts before the founder lane is proven (25 Nov).
