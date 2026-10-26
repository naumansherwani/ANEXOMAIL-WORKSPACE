# PRO — LIVE GREEN (Chrome, pro.buyer, 26 Oct 2026 20:57-22:10 PKT) — IN PAR DOBARA CODE NAHI LIKHNA (founder hukm 22:03)
Founder: "yeh jo live nazar aaye green kar do, phir se code nahi likhna; yeh sab repo mein claude folder mein dalo."
Saboot = Chrome mein khud dekha + founder server output (basic/pro/kernel ALL PASS). Server commit 6a1d91e+.

| Card par likha feature | Live saboot | Halat |
|---|---|---|
| 3 company domains | /app/domains "1 of 3 domains · Pro" | GREEN |
| 10 mailboxes | /app/domains "0 of 10 mailboxes"; /app/storage "Mailboxes 1 of 10" | GREEN |
| 300GB shared storage, 35MB attachment | /app/storage pool 300 GB, "Max single transfer 35 MB" | GREEN |
| Boards & notes, Tasks | /app/work Tasks (ZZ pro audit task), Promises, Work chain Pro | GREEN |
| Tasks & thread analytics | /app/analytics 7 tabs render; mail.threadEconomics probe 200 | GREEN (naya account: data khali) |
| CRM: accounts, leads, pipeline | /app/crm 8 pages (Overview, Leads, Pipeline, Relationships, Accounts, Tasks, Reports, Setup); pipeline/merge/forms live proof | GREEN |
| Snooze & schedule send | thread header Snooze menu: Later today / Tomorrow 8am / Next week; compose "Schedule send" button | GREEN |
| Email templates, snippets, follow-up | compose: Insert template, Templates…, snippet chip, "No follow-up" dropdown | GREEN |
| Undo send (30 s hold) | "Sending… Held for 30s" -> Undo -> "Not sent" | GREEN |
| Pre-send scan | Rust mail.confidence 200 (attachment_promised, risky_tone, external_domain, score 73); messages English | GREEN |
| Overlap Matrix for team time zones | Calendar > Meeting > Find a time > guest added: "EVERYONE'S HOURS" matrix, "everyone in their day", Good for everyone | GREEN |
| 3 public booking links | Calendar > Booking: "1 of 3 booking links used", New link, /book/pro-buyer, lengths, notice, time zone | GREEN |
| Availability + Focus (server) | Rust availability/focus 200; Avail. = 16 slots 09:00-17:00 Karachi (working hours + local tz) | GREEN |
| Calendar settings (working hours, rooms, out of office, outside calendars) | settings panel | GREEN |
| Thread insight ("Best time to send") + Rescue thread | thread header | GREEN |
| Domain connect + addresses | /app/domains Needs DNS 0/5, Continue setup | GREEN (DNS verify founder side) |
| Devices page | /app/devices | page GREEN; "4 trusted devices" UI limit nazar nahi aaya -> NOT CHECKED |
| Everything in Basic | Basic probe ALL PASS | GREEN |

## Jo is pass mein CONFIRM NAHI hua (green mark NAHI) — agla chhota kaam
1. Meeting cost / hourly rate: `CostMeter` UI (Bits.tsx) maujood, server cost Rust par, LEKIN koi UI field NAHI jahan attendee ka hourly rate set ho (src mein "hourly" 0 jagah) => meter kabhi dikhne wala nahi. REAL GAP: rate set karne ka UI banana (calendar attendee / People contact "hourly rate") — Rust: calendar_attendees.hourly_rate pehle se.
2. Shared inbox collision guard: server probe (assign Basic 403) GREEN; live collision (do users ek thread par) ke liye doosra Pro user chahiye -> test account.
3. Trusted devices "4" limit UI: /app/devices par device vault limit dikhana/test baaqi.
4. ANEXO_TAG_MODE=enforce: founder env.

## 22:40 — Hourly rate / Meeting cost (gap #1) — KIS TECHNOLOGY MEIN (Rule 52 + 56)
| Hissa | Technology | File |
|---|---|---|
| Server logic (rates ka hisaab, rakam saaf karna, gate) | Rust (std-only core, 50 tests) | server/rust/cal_core.rs (`clean_rate`, `effective_rates`) |
| Server I/O (2 naye procs `calendar.rates`, `calendar.rates.set`; cost har event par) | Rust axum+tokio `/rpc`, tokio task-local (rates ek baar per request) | server/rust/cal_glue.rs |
| Data | Postgres (analytics_rates, scope self/team) — NAYA SQL NAHI | phase24 table |
| Plan gate | Server par Pro+ (Basic 403), contract + probe | rpc-contract.ts, basic-gate-probe.sh |
| Browser | WASM kernel (rpc() -> kernelRpc), REST/Bun twin NAHI (Rule 56) | src/lib/calendar.ts, MeetingCostSettings.tsx (Calendar settings > Meeting cost) |
Status: LIVE GREEN 22:30 (Chrome + founder probes).

## 22:30 — MEETING COST / HOURLY RATE: LIVE GREEN (bfcdd69 deployed 22:19)
Founder output: Rust restart 173, Web pull OK, basic ALL PASS, pro ALL PASS (calendar.rates 200, rates.set bad value 400), KERNEL ALL PASS. Chrome: Calendar settings > Meeting cost fields maujood; save 60/40 -> "Meeting cost rates saved"; server `calendar.rates` = {self 60, guest 40}; `calendar.events` cost = {hourly_total 100, minutes 30, total £50} (organiser 60 + guest 40). DOBARA CODE NAHI.
Test data Pro account: rates self 60 / guest 40 (founder chaahe to 0 kar do).
Baaqi Pro: shared-inbox live collision (2nd user), trusted devices 4 UI, ANEXO_TAG_MODE=enforce (founder env).
