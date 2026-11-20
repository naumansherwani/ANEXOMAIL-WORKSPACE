# WORKING NOW (manual checkpoint, 20 Nov 2026 20:13 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC7a: E196 SQL (473 lines) + Rust doors + clock written and tested on scratch pg; writing React Remind me chip; then his sql-run E196 + install; then QC7b sealed draft
NEXT STEP: React: mail_followup api + pure helpers + chip in read pane (additive); then push and give him sql-run E196 then founder-install
HIS LAST WORD: SQL advance 400+ likho QC7
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
- a33a93c4 20 Nov 20:02 ledger line 4479d0b1
- 4479d0b1 20 Nov 20:02 QC5 recorded as my own live proof
- b2f171e0 20 Nov 20:02 ledger line 25d79458
- 25d79458 20 Nov 20:02 QC5 is my proof
- 724ce010 20 Nov 20:01 ledger line a66b87ea

## Uncommitted files (half-done work if any)
M  CLAUDE.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
 M docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
A  docs/cursor-work/sql/CHECK_E196.sql
A  docs/cursor-work/sql/E196_founder_mail_followups.sql
R  founder-web/dist/assets/index-ocDOkx6x.js -> founder-web/dist/assets/index-CNFwkYU-.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/awam.txt
M  lanes/founder.txt
M  lovable-gold/README.md
M  server/founder/src/fmail_ep.rs
A  server/founder/src/fmail_followup.rs
M  server/founder/src/main.rs

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 lanes/ALL-FILES.csv                                |   5 +-
 lanes/awam.txt                                     |   1 +
 lanes/founder.txt                                  |   4 +-
 lovable-gold/README.md                             |   2 +-
 server/founder/src/fmail_ep.rs                     |   2 +-
 server/founder/src/fmail_followup.rs               | 135 ++++++
 server/founder/src/main.rs                         |   7 +-
 24 files changed, 706 insertions(+), 50 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (bb999a8dc327fb648f01a9a50f885b203dfc2afd)
