# WORKING NOW (manual checkpoint, 23 Nov 2026 05:16 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1m-1 code done (B1 queue pressure + B2 SLA at risk), waits his ad-auto + desk-install + my Chrome look
NEXT STEP: his 2 server lines, Chrome look, then 1m-1 GREEN, next B3
HIS LAST WORD: his 05:13: start 1m
LATER (his 23 Nov 05:10, OVERVIEW-S4-LATER): Overview screen (his 22.jpg look) comes at the END, after 1o, 1a, phone/tablet test, Founder Escalation Inbox: docs/claude/admin-desk/OVERVIEW-S4-PLAN-23NOV.md. Also FOUNDER-ESCALATION-INBOX after 1o.
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
## AWAM Rust engine = process `anexomail-rust` (pid 3145875 at 20 Nov 03:30)
| Proto | Address:Port | Meaning |
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## RESERVED BY HIS WORD 21 Nov 2026 07:5x PKT: TCP 127.0.0.1:4400 = ADMIN DESK (own Rust process `anexomail-desk`, loopback only; Caddy has the admindesk block since 21 Nov 07:51 PKT: reverse_proxy 127.0.0.1:4400, validated + reloaded; noth

## Last 5 commits
- 7c5e7107 23 Nov 05:10 ledger line bc169da6
- bc169da6 23 Nov 05:10 Overview S4 reminder gate
- fe54e05f 23 Nov 05:06 ledger line bc150900
- bc150900 23 Nov 05:06 Overview S4 later
- db3b2083 23 Nov 05:04 ledger line 74022546

## Uncommitted files (half-done work if any)
 M admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M admin-desk/NOW-LIST-23NOV.md
 M admin-desk/server/src/main.rs
 M docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/admin-desk/NOW-LIST-23NOV.md
 M docs/claude/admin-desk/server/src/main.rs
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 D founder-web/dist-desk/assets/desk-BmAwjGyi.js
 M founder-web/dist-desk/desk.html
 M founder-web/src/desk/DeskCards.tsx
 M founder-web/src/desk/desk_cards.ts
?? admin-desk/D6-CARDS-LIST-23NOV.md
?? admin-desk/server/src/pressure.rs
?? admin-desk/sql/AD11.sql
?? admin-desk/sql/checks/AD11-check.sql
?? docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md
?? docs/claude/admin-desk/server/src/pressure.rs
?? docs/claude/admin-desk/sql/AD11.sql
?? docs/claude/admin-desk/sql/checks/AD11-check.sql
?? founder-web/dist-desk/assets/desk-B_b4HGWG.js
?? founder-web/src/desk/DeskPressure.tsx
?? founder-web/src/desk/desk_pressure_pure.test.ts
?? founder-web/src/desk/desk_pressure_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/admin-desk/server/src/main.rs          |   3 +
 docs/claude/state/WORKING-NOW.md                   |  46 ++++---
 docs/claude/tech-contracts/CURRENT.md              |   9 ++
 founder-web/dist-desk/assets/desk-BmAwjGyi.js      | 135 ---------------------
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/DeskCards.tsx                 |   3 +
 founder-web/src/desk/desk_cards.ts                 |   4 +-
 12 files changed, 63 insertions(+), 158 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (9090aa399f9e970045b00b03c00b409e22d04779)
