# WORKING NOW (manual checkpoint, 24 Nov 2026 07:41 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: E201 awam package caps SQL written and scratch-tested
NEXT STEP: his Desk T1 command FIRST, then awam E201 line, then T2
HIS LAST WORD: his 07:33 order: fix awam loopholes today; his 07:40 order: Desk CP6 first, order never breaks
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
- 6c78729c 24 Nov 07:30 ledger line 77e022b6
- 77e022b6 24 Nov 07:30 b13 t1 cp6
- 6d78da02 24 Nov 07:26 ledger line 9e36ebce
- 9e36ebce 24 Nov 07:26 t1 checklist
- 93ffdbf6 24 Nov 07:25 ledger line 5a236721

## Uncommitted files (half-done work if any)
M  admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  admin-desk/NOW-LIST-23NOV.md
M  docs/claude/AWAM-BLUEPRINT-ALPHABETIC-20NOV.md
A  docs/claude/AWAM-E201-GATE-CHECKLIST-24NOV.md
M  docs/claude/AWAM-LOOPHOLE-PHASES-24NOV.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  docs/claude/admin-desk/NOW-LIST-23NOV.md
M  docs/claude/admin-desk/state/WORKING-NOW.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
A  docs/cursor-work/sql/CHECK_E201.sql
A  docs/cursor-work/sql/E201_awam_package_caps_final.sql
M  docs/cursor-work/sql/index.md
R  founder-web/dist/assets/index-CsDyrRci.js -> founder-web/dist/assets/index-C-V5xrHJ.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/awam.txt
M  lanes/docs.txt
M  lanes/founder.txt
M  lovable-gold/README.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/dist/index.html                        |   2 +-
 founder-web/src/system_brain.json                  |   6 +-
 lanes/ALL-FILES.csv                                |   5 +-
 lanes/awam.txt                                     |   2 +
 lanes/docs.txt                                     |   1 +
 lanes/founder.txt                                  |   2 +-
 lovable-gold/README.md                             |   2 +-
 30 files changed, 488 insertions(+), 57 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (bb95efd3d7899e9f2fb91599009ea56e2deab640)
