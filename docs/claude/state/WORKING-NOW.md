# WORKING NOW (manual checkpoint, 23 Nov 2026 10:19 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1m-8 B9b code done, committing
NEXT STEP: his desk-install, Chrome look at Customers
HIS LAST WORD: his 10:12 + 10:16 words
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
- 92f4d775 23 Nov 10:09 ledger line bd9a2eeb
- bd9a2eeb 23 Nov 10:09 B6b GREEN
- 49d66341 23 Nov 09:59 ledger line 7fd84e13
- 7fd84e13 23 Nov 09:59 Desk 1m-7 B6b own-domain mail posture + gate PHASE FILES
- 99d32b28 23 Nov 09:52 ledger line 5f7f1cf3

## Uncommitted files (half-done work if any)
M  admin-desk/BILLIONAIRE-SETUP-LIST-23NOV.md
M  admin-desk/D6-CARDS-LIST-23NOV.md
M  admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  admin-desk/NOW-LIST-23NOV.md
M  admin-desk/scripts/cp-install.sh
M  admin-desk/scripts/desk-install.sh
M  admin-desk/server/src/customers.rs
A  control-plane/sql/CP4.sql
A  control-plane/sql/checks/CP4-check.sql
M  control-plane/src/census.rs
M  docs/claude/admin-desk/BILLIONAIRE-SETUP-LIST-23NOV.md
M  docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md
M  docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  docs/claude/admin-desk/NOW-LIST-23NOV.md
M  docs/claude/admin-desk/scripts/cp-install.sh
M  docs/claude/admin-desk/scripts/desk-install.sh
M  docs/claude/admin-desk/server/src/customers.rs
M  docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/server/rules-gate.py
R  founder-web/dist-desk/assets/desk-DoEHb_-E.js -> founder-web/dist-desk/assets/desk-BoFzV3WI.js
M  founder-web/dist-desk/desk.html
M  founder-web/src/desk/DeskCustomers.tsx
M  founder-web/src/desk/desk_customers_pure.test.ts
M  founder-web/src/desk/desk_customers_pure.ts
A  founder-web/src/desk/desk_packages_pure.test.ts
A  founder-web/src/desk/desk_packages_pure.ts
M  lanes/ALL-FILES.csv
M  lanes/founder.txt
M  lanes/shared.txt
M  lovable-gold/README.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/src/desk/desk_customers_pure.ts        |  23 +++-
 founder-web/src/desk/desk_packages_pure.test.ts    |   9 ++
 founder-web/src/desk/desk_packages_pure.ts         |  24 ++++
 lanes/ALL-FILES.csv                                |   6 +-
 lanes/founder.txt                                  |   4 +-
 lanes/shared.txt                                   |   2 +
 lovable-gold/README.md                             |   2 +-
 32 files changed, 429 insertions(+), 60 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (a2d5f97a82e4ef51f1b0a0f7cdbb0c865c99fefa)
