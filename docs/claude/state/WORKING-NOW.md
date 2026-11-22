# WORKING NOW (manual checkpoint, 23 Nov 2026 03:02 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1j audit+autofix L1-L6 done, install next
NEXT STEP: his install paste then Chrome signed-in look then GREEN
HIS LAST WORD: his 03:01 order: audit, add all research, autofix, WORKING-NOW
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
- 6b73183f 23 Nov 02:57 ledger line 53aed7fd
- 53aed7fd 23 Nov 02:57 1j: Plan context screen code
- 4b4b376e 23 Nov 02:56 ledger line ad2138b5
- ad2138b5 23 Nov 02:56 1j: plan, list, ML-DSA gap plan
- 308f6827 23 Nov 02:46 ledger line 711d040d

## Uncommitted files (half-done work if any)
 M admin-desk/D5-PLAN-CONTEXT-SCREEN-LIST-23NOV.md
 M docs/claude/admin-desk/D5-PLAN-CONTEXT-SCREEN-LIST-23NOV.md
 M docs/claude/state/WORKING-NOW.md
 D founder-web/dist-desk/assets/desk-CrifIdYe.js
 M founder-web/dist-desk/desk.html
 M founder-web/src/desk/DeskPlan.tsx
 M founder-web/src/desk/desk_plan_pure.test.ts
?? founder-web/dist-desk/assets/desk-DGfUACHd.js

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 admin-desk/D5-PLAN-CONTEXT-SCREEN-LIST-23NOV.md    |   5 +
 .../D5-PLAN-CONTEXT-SCREEN-LIST-23NOV.md           |   5 +
 docs/claude/state/WORKING-NOW.md                   |  30 +++---
 founder-web/dist-desk/assets/desk-CrifIdYe.js      | 115 ---------------------
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/DeskPlan.tsx                  |  24 +++--
 founder-web/src/desk/desk_plan_pure.test.ts        |   5 +
 7 files changed, 41 insertions(+), 145 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (6eb107566d50ac4eb77f0edccb372e095e1a3840)
