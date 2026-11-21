# WORKING NOW (manual checkpoint, 21 Nov 2026 07:35 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: Desk tech-law gate checks (3 ok + 11 open) written; attachments after R4; phase detail R3a0-R3a2 written for discussion; desk-host-check.sh read-only written
NEXT STEP: his haan for the read-only host check + paste, then Namecheap steps one at a time; R3a2 owner SQL E201
HIS LAST WORD: his 21 Nov 07:34: gate ruk le, attachments after move-in, phase details
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by
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
- 5328bd8f 21 Nov 07:31 ledger line dd66f70f
- dd66f70f 21 Nov 07:31 Desk isolation gate (founder and Desk never mixed)
- 38dcddba 21 Nov 07:31 ledger line 3ca0635a
- 3ca0635a 21 Nov 07:31 Desk isolation gate (founder and Desk never mixed)
- d056b1a7 21 Nov 07:29 ledger line dde2559c

## Uncommitted files (half-done work if any)
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/TECH-LAW-GATE.json
 M docs/claude/state/WORKING-NOW.md
 M docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
 M docs/cursor-work/founder/founder-commands.md
?? docs/claude/ADMIN-DESK-R3A0-R3A2-PHASE-DETAIL-21NOV.md
?? docs/cursor-work/server/desk-host-check.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/BLUEPRINT-ABC-01NOV.md                 |   1 +
 docs/claude/TECH-LAW-GATE.json                     | 125 ++++++++++++++++++++-
 docs/claude/state/WORKING-NOW.md                   |  29 ++---
 ...DE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md |   1 +
 docs/cursor-work/founder/founder-commands.md       |   2 +
 5 files changed, 139 insertions(+), 19 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (a8f43387a86b3b16ce33d3c4523e694fa8513e5c)
