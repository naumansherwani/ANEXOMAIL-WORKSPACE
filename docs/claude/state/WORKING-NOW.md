# WORKING NOW (manual checkpoint, 23 Nov 2026 08:53 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1m-5 B6 Deliverability WRITTEN: CP3 SQL, Control Plane deliverability route, AD15, deliverability.rs, pure TS + screen, card v wired, installers updated
NEXT STEP: his ad-auto (AD15) then desk-install (rebuilds Control Plane, CP3, PROOF deliverability CP3), my Chrome look, then GREEN
HIS LAST WORD: gate forces one commit
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
- 5003706f 23 Nov 08:41 ledger line fc677448
- fc677448 23 Nov 08:41 Desk B6 Deliverability: research, list, contract
- 3c8c3df3 23 Nov 08:40 ledger line 0c6a46ec
- 0c6a46ec 23 Nov 08:40 B9 Customers and Plans GREEN
- 595cff51 23 Nov 08:31 ledger line 0da64cac

## Uncommitted files (half-done work if any)
M  admin-desk/scripts/cp-install.sh
M  admin-desk/scripts/desk-install.sh
A  admin-desk/server/src/deliverability.rs
M  admin-desk/server/src/main.rs
A  admin-desk/sql/AD15.sql
A  admin-desk/sql/checks/AD15-check.sql
A  control-plane/sql/CP3.sql
A  control-plane/sql/checks/CP3-check.sql
M  control-plane/src/answer.rs
M  control-plane/src/census.rs
M  control-plane/src/core.rs
M  control-plane/src/db.rs
M  control-plane/src/h3srv.rs
M  docs/claude/admin-desk/scripts/cp-install.sh
M  docs/claude/admin-desk/scripts/desk-install.sh
A  docs/claude/admin-desk/server/src/deliverability.rs
M  docs/claude/admin-desk/server/src/main.rs
A  docs/claude/admin-desk/sql/AD15.sql
A  docs/claude/admin-desk/sql/checks/AD15-check.sql
M  docs/claude/admin-desk/state/WORKING-NOW.md
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
R  founder-web/dist-desk/assets/desk-zne_XITt.js -> founder-web/dist-desk/assets/desk-a6D6-xa8.js
M  founder-web/dist-desk/desk.html
M  founder-web/src/desk/DeskCards.tsx
A  founder-web/src/desk/DeskDeliverability.tsx
M  founder-web/src/desk/desk_cards.ts
A  founder-web/src/desk/desk_deliverability_pure.test.ts
A  founder-web/src/desk/desk_deliverability_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 .../assets/{desk-zne_XITt.js => desk-a6D6-xa8.js}  |  19 +-
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/DeskCards.tsx                 |   2 +
 founder-web/src/desk/DeskDeliverability.tsx        |  67 +++++++
 founder-web/src/desk/desk_cards.ts                 |   2 +-
 .../src/desk/desk_deliverability_pure.test.ts      |  26 +++
 founder-web/src/desk/desk_deliverability_pure.ts   |  50 ++++++
 29 files changed, 1082 insertions(+), 42 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (b44fd0941dfa22c09817879eb685c0be13e3edfc)
