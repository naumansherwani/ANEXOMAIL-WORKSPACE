# WORKING NOW (manual checkpoint, 20 Nov 2026 19:20 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: DK-a INSTALLED (his paste 19:20, healthz 200); doing my live Chrome kernel 0.19.0 look
NEXT STEP: Chrome look -> QC5 Delete forever -> QC7 -> QC8 -> Q3 -> DK-b (his hardware keys)
HIS LAST WORD: 5-min check 10:11
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 03:30 PKT** (real clock). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## FOUNDER + other processes in the same list (never touch)
| Proto | Port | Process |
|---|---|---|

## Last 5 commits
- dbd27325 20 Nov 19:09 ledger line 073635e8
- 073635e8 20 Nov 19:09 WORKING-NOW checkpoint refresh
- 2dc9af34 20 Nov 19:08 ledger line 3e7393b5
- 3e7393b5 20 Nov 19:08 DK context saved
- fe26ff73 20 Nov 19:04 ledger line 73975c25

## Uncommitted files (half-done work if any)
M  CLAUDE.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
M  docs/claude/state/SERVER-FIRST.jsonl
 M docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
R  founder-web/dist/assets/index-BhYPHuch.js -> founder-web/dist/assets/index-DyOmStTK.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/founder.txt

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/cursor-work/server/DEPLOY-MANIFEST.txt        | 30 ++++++++---------
 docs/cursor-work/server/PULL-COMMANDS.md           |  2 ++
 .../{index-BhYPHuch.js => index-DyOmStTK.js}       |  2 +-
 founder-web/dist/index.html                        |  2 +-
 founder-web/src/system_brain.json                  |  6 ++--
 lanes/ALL-FILES.csv                                |  2 +-
 lanes/founder.txt                                  |  2 +-
 18 files changed, 63 insertions(+), 43 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (6b1db0ead75134135798f2b0b8117233ef7f5175)
