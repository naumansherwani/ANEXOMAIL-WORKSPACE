# WORKING NOW (manual checkpoint, 21 Nov 2026 03:08 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 21 Nov 03:55 PKT: HIS ORDER (03:07): delete 'by his word' everywhere, write only GREEN. DONE in docs: 196 replacements in 20 files (GREEN BY HIS WORD -> GREEN). From now on I write only GREEN (with WIRED/REAL/TECH-LAW CHECKED). Statements 'waived / closed by his word' (what was skipped) are kept. Still: NO CODE until his haan.
NEXT STEP: Wait for his haan or his choice a/b/c for QC8.
HIS LAST WORD: his 21 Nov 03:07: by his words delete, sirf green likho
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
- 19f81c27 21 Nov 03:07 ledger line e982cd7a
- e982cd7a 21 Nov 03:07 Standing order: no code until his haan (03:06)
- bd9100c1 21 Nov 03:07 ledger line b90b0802
- b90b0802 21 Nov 03:07 QC8: plain-words answer and options recorded
- e86dbf92 21 Nov 03:00 ledger line a2f53bba

## Uncommitted files (half-done work if any)
 M CLAUDE.md
 M docs/claude/AWAM-BLUEPRINT-ALPHABETIC-20NOV.md
 M docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/CLOSE-THE-GAPS-07NOV.md
 M docs/claude/DONE-DO-NOT-REPEAT.md
 M docs/claude/FOUNDER-MAILBOX-PHASES-18NOV.md
 M docs/claude/PHASE-NOW.md
 M docs/claude/QC1E-LEDGER-AWAM-19NOV.md
 M docs/claude/QC1E-LEDGER-FOUNDER-19NOV.md
 M docs/claude/QC3-AUDIT-20NOV.md
 M docs/claude/QC3-PLAN-20NOV.md
 M docs/claude/QCONNECT-PLAN-20NOV.md
 M docs/claude/RESUME-POINT.md
 M docs/claude/founder/PULL-COMMANDS.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
 M docs/cursor-work/DONE-DO-NOT-REPEAT.md
 M docs/cursor-work/founder/founder-commands.md
 M docs/cursor-work/server/PULL-COMMANDS.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/founder/PULL-COMMANDS.md               | 34 ++++++++---------
 docs/claude/state/WORKING-NOW.md                   | 43 +++++++++++++---------
 docs/claude/tech-contracts/CURRENT.md              | 34 ++++++++---------
 ...DE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md | 34 ++++++++---------
 docs/cursor-work/DONE-DO-NOT-REPEAT.md             | 34 ++++++++---------
 docs/cursor-work/founder/founder-commands.md       | 34 ++++++++---------
 docs/cursor-work/server/PULL-COMMANDS.md           | 34 ++++++++---------
 21 files changed, 210 insertions(+), 203 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (fcf0a61d3d24722d13d75f24d239fb57af18aecc)
