# WORKING NOW (manual checkpoint, 23 Nov 2026 03:27 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1k code done and tested; commit then give his 2 commands (ad-auto then desk-install)
NEXT STEP: his ad-auto + desk-install paste then Chrome look then GREEN
HIS LAST WORD: his order
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
- 06f6c2ac 23 Nov 03:17 ledger line e75d586b
- e75d586b 23 Nov 03:17 1k: research list + contract
- 269b755b 23 Nov 03:16 ledger line 1a766922
- 1a766922 23 Nov 03:16 after-compaction points
- 1cc9c4fe 23 Nov 03:13 ledger line cd06a6a5

## Uncommitted files (half-done work if any)
 M admin-desk/D5B-RUNBOOKS-LIST-23NOV.md
 M admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M admin-desk/NOW-LIST-23NOV.md
 M admin-desk/server/src/main.rs
 M docs/claude/admin-desk/D5B-RUNBOOKS-LIST-23NOV.md
 M docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/admin-desk/NOW-LIST-23NOV.md
 M docs/claude/admin-desk/server/src/main.rs
 M docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/server/rules-gate.py
 D founder-web/dist-desk/assets/desk-DGfUACHd.js
 M founder-web/dist-desk/desk.html
 M founder-web/src/desk/DeskCards.tsx
 M founder-web/src/desk/desk_cards.ts
 M founder-web/src/desk/desk_plan_pure.test.ts
 M founder-web/src/desk/desk_plan_pure.ts
?? admin-desk/runbooks.seed.json
?? admin-desk/server/src/runbooks.rs
?? admin-desk/sql/AD9.sql
?? admin-desk/sql/AD9b.sql
?? admin-desk/sql/checks/AD9-check.sql
?? admin-desk/sql/checks/AD9b-check.sql
?? admin-desk/tools/
?? docs/claude/admin-desk/runbooks.seed.json
?? docs/claude/admin-desk/server/src/runbooks.rs
?? docs/claude/admin-desk/sql/AD9.sql
?? docs/claude/admin-desk/sql/AD9b.sql
?? docs/claude/admin-desk/sql/checks/AD9-check.sql
?? docs/claude/admin-desk/sql/checks/AD9b-check.sql
?? docs/claude/admin-desk/tools/
?? founder-web/dist-desk/assets/desk-C-59IlnA.js
?? founder-web/src/desk/DeskRunbooks.tsx
?? founder-web/src/desk/desk_runbook_pure.test.ts
?? founder-web/src/desk/desk_runbook_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/cursor-work/server/rules-gate.py              |  18 ++++
 founder-web/dist-desk/assets/desk-DGfUACHd.js      | 115 ---------------------
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/DeskCards.tsx                 |   2 +
 founder-web/src/desk/desk_cards.ts                 |   1 +
 founder-web/src/desk/desk_plan_pure.test.ts        |   2 +-
 founder-web/src/desk/desk_plan_pure.ts             |   2 +-
 18 files changed, 117 insertions(+), 153 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (d9f71858771c9d66c15aa5429bd6bbfa91b2b473)
