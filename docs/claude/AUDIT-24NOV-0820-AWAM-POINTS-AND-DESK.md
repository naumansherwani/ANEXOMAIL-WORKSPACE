# AUDIT 24 Nov 2026 08:2x PKT (his 08:17 order: "ek ek word E201 mein hai ya nahi, agar nahi edit kero; baki Admin Desk ka audit; 0.1% shak = Chrome se live dekho, live fix, auto loop fix")
E201 was already run on his server (sha in his ledger), so an edit of E201 would never run again: every missing point is PART 2 of E201 (his 08:21 order: E201 part 2 merged into E201, E201 part 2 file deleted; the changed sha makes sql-run AUTO run E201 again).
## A. AWAM BLUEPRINT POINTS vs SQL (source: AWAM-PACKAGES-PROPOSAL-07NOV.md sections 1, 2, 6, G4, G5, his 22 Nov chart, 24 Nov 08:03)
| # | His point | In SQL? | Where |
|---|---|---|---|
| 1 | Premium 7,000 users FINAL | YES, live | E201 package_seat_cap + file_chart |
| 2 | Business 60, Pro 20, Basic 5, Business Pro 570 (never unlimited) | YES, live | E201 |
| 3 | Max card unlimited, STRICT 125,000 per company, he raises it himself | YES, live | E201 guard + package_seat_cap_raise (reason 20+ chars, append-only) |
| 4 | 90 percent yellow, 95 percent high, never blocked | YES, live | E201 package_seat_level + ledger + package_cap_alerts_open |
| 5 | Max price 125,000 FINAL | YES | E201 workspace_plans row; E201 part 2 package_fact |
| 6 | Premium and Max storable (subscription FK) | YES, live | E201 (workspace_plans had 4 plans) |
| 7 | Chart as data: price, storage, attachment, chat file, pool | WAS MISSING -> E201 part 2 | package_fact |
| 8 | Pool = seats x 50 GB (250 GB, 1 TB, 3 TB, 28.5 TB, 350 TB), Max 500 TB | WAS MISSING -> E201 part 2 | package_fact + check |
| 9 | * values (Premium storage/pool; Max storage, attachment, chat file, pool) are recommendations, no public TB numbers until Hetzner verified | WAS MISSING -> E201 part 2 | starred list + view package_card_public hides them |
| 10 | Pool alerts 70 / 85 percent, 100 percent slow (never delete, e-mail keeps working) | WAS MISSING -> E201 part 2 (levels + ledger + report door); the usage METER is Rust, OPEN | package_pool_level, package_pool_report |
| 11 | Yearly: Business, Business Pro, Premium 2 months free, Max 3, FIRST months, shown as free | WAS MISSING -> E201 part 2 (the facts); billing screen = AWL-2 Rust, OPEN | package_fact.yearly_free_months |
| 12 | Premium and Max: own domain mailboxes (no @anexomail.com restriction) | WAS MISSING -> E201 part 2 flag; the mailbox-creation enforcement is app code, OPEN | package_fact.own_domain_mailboxes |
| 13 | "Unlimited" = seats only, never storage or traffic | WAS MISSING -> E201 part 2 CHECK | seats_unlimited_card only for business_max |
| 14 | Locked values win over the pasted chart (Basic 15 GB, Business Pro attachment 60 MB) | E201 part 2, conflict written in the note | package_fact.note |
| 15 | No price change until he says go | His 08:28 word: the chart is FINAL, old prices go. E202 (price migration) written + scratch-tested, not on his server yet. WAS the finding (FACT row of CHECK_E201): workspace_plans still holds basic 23 / pro 46 / business 97 per user, his chart says 40 / 105 / 360 flat per company. NOT changed; waits for his go | CHECK_E201 row 13 |
| 16 | 10 GB Max chat-file tier in the Rust engine, founder dashboard alert card, billing screen free-months, mailbox creation by the company | NOT SQL: Rust / React, OPEN | AWL-3 code half, AWL-2 |
| 17 | 48-hour trial is the only free entry, trial -> paid changes only the package | existing E17; not touched | - |
## B. ADMIN DESK AUDIT (live, read-only look in his signed-in Chrome 08:19 PKT, nothing clicked, nothing changed)
| # | Finding | Verdict | Owner |
|---|---|---|---|
| D1 | Login page and /dashboard load, "Live . verified", no console errors, no sideways scroll at 1536 | OK | - |
| D2 | Chrome reports the page protocol as h2 (nextHopProtocol), HTTP/3 chip says QUIC | KNOWN OPEN (item A Browser HTTP/3: Alt-Svc / Namecheap HTTPS record, his hands), not new | phase 1a |
| D3 | Urgent alerts shows "0 is healthy" next to "0 high . 1 not acknowledged . oldest 29 h 7 min": one alert has waited 29 hours | REAL FINDING: the headline says healthy while an alert is unacknowledged for over a day; needs an age rule (an unacknowledged alert older than a set time turns the card yellow) | Dashboard final (1o) |
| D4 | "Plans and prices are not connected yet" (desk_bridge_pure.ts line 60) | prices are blocked by design (money stays on the founder side); the plan ROWS are now live (AD22/AD24) and his Max price word is FINAL, so the plan-rows phase (R3p) is unblocked | R3p |
| D5 | Systems says "Working, but some parts are not measured yet" | breaks the FUTURE-PROOF law wording ("never not measured yet"); the unmeasured signals must be built (ledger probe incremental verify first) | Systems / AD03 plan |
| D6 | Ledger card says "Not connected yet" although the audit export and the ledger exist (audit copies proven on his server) | the CARD is not wired (phase L), the log is; wording must say what exists | phase L |
| D7 | Managed Move-In "Not connected yet" | honest, phase P | phase P |
Auto-fix decision: D3 to D6 are phase work with their own gates (each needs a world-class SQL + Rust + screen row), not text edits; a quick string change would only hide the gap, which the AUTOFIX law forbids. They are written into the Desk NOW-LIST as the next audit items after the B13 binding table.
## C. WHAT THE PULL COMMANDS ARE
Awam SQL (E201 part 2): his fixed AUTO form only. Desk: nothing new to install (no Desk code or Desk SQL changed in this step).
