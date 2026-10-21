# 04 — Technology (stack + B-series + R-items)

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

| Technology / batch | Status | Note |
|---|---|---|
| Tokio async 1.53.3 | 🟢 GREEN (live dekha/proof) | live |
| axum 0.8.9 | 🟢 GREEN (live dekha/proof) | live |
| QUIC wtransport 0.7.2 (quinn) | 🟢 GREEN (live dekha/proof) | live; ufw 3443/udp open item D11 |
| tRPC-style /rpc/* | 🟢 GREEN (live dekha/proof) | live |
| B1 Rust JWT local verify + refresh | 🟢 GREEN (live dekha/proof) | 21 Oct 04:55 |
| B2 passkey/recovery Rust (G42) | 🟢 GREEN (live dekha/proof) | 05:50 |
| B2b Bun hardening + passkey list/delete | 🟢 GREEN (live dekha/proof) | 05:50 |
| B3 mail.send/undo/queue worker/org.mailboxes (R1) | 🟢 GREEN (live dekha/proof) | 06:00 |
| B4 event-driven push (R5) | 🟢 GREEN (live dekha/proof) | 21 Oct 06:50 founder output: proof SAB PASS (UDP 3443, /internal/event, family 3/3) |
| B5 G40 19 Bun-only routes -> Rust | 🟢 GREEN (founder ka server output 21 Oct 08:27: public procs live, founder procs 401, daam 790/46 Rust+Brain) | repo + sandbox PASS (~80 checks, asli Bun vs Rust); server par rust-engine-install.sh baqi |
| B6 G16 self-serve billing Rust | 🔴 TODO (bana nahi) | Polar :3400 NO-TOUCH |
| B7 G26/G27 calendar iMIP/recurrence/link/CalDAV | 🟠 PARTIAL — live Chrome check 21 Oct 08:4x (Basic acct): maujood = week/month/day, time-grid, drag, new-meeting form (title/guests/datetime/duration/find-a-time/location/agenda-gate), .ics import/export, Avail. (copyable /api/calendar/availability link). NAHI = recurrence UI, booking page, iMIP reply, CalDAV, 2-way sync | shaam ko banega |
| B8 Brain 38 files/504 endpoints -> Rust, Bun 1.4.3, tokio 1.54 | 🔴 TODO (bana nahi) |  |
| R3 typed contract | 🔴 TODO (bana nahi) |  |
| R4 direct DB pool | 🔴 TODO (bana nahi) |  |

## Ops
| Item | Status | Note |
|---|---|---|
| ufw 3443/udp (QUIC) | 🟢 GREEN (live dekha/proof) | 21 Oct 07:09 founder output: ufw active, rule pehle se hai |
| Passkey test-account exempt (Brain live) | 🟢 GREEN (live dekha/proof) | 21 Oct 07:09 founder output: marker live auth-passkey.ts mein |
| Caddy cert renewal 12 Nov | 🔵 FOUNDER chahiye | D11 — 12 Nov se pehle dekhna |
| Bun /api/billing/subscription bug | 🔴 TODO (bana nahi) | D11 |
| E24 email_hash HMAC migrate run | 🔴 TODO (bana nahi) | D11 |
| E52 alias fair-use SQL (cap 25) server par | 🔴 TODO (bana nahi) | sql-run.sh E52_alias_fair_use CHECK_E52 |
| clamd tcp fix / EICAR | 🟢 GREEN (live dekha/proof) | PROMISES #12 GREEN |
| A5 FOUNDER_PASSWORD plain env compare (auth.ts:631) | 🔴 TODO (bana nahi) | G35 passkey/2FA ke baad hatana |
| repo main.rs live ke barabar mirror | 🔴 TODO (bana nahi) | installers live patch karte hain; A1 gap |
| Cron anexomail-sync-domains/maps duplicate (crontab + /etc/cron.d) + script repo mein nahi | 🔴 TODO (bana nahi) | A4 |
| Login-loop live verify (founder sign-out/login) | 🔴 TODO (bana nahi) | recorder |
| BUG mojibake '5:31â¯AM' preview/ingest charset | 🔴 TODO (bana nahi) | ledger |
| BUG thread card sender line clip | 🔴 TODO (bana nahi) | ledger |
| Plan docs ka 10 s undo-send -> 30 s | 🔴 TODO (bana nahi) | MASTER-BUILD-PLAN/package maps |
