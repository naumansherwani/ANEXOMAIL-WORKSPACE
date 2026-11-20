# WORKING NOW (manual checkpoint, 21 Nov 2026 01:12 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 21 Nov 01:35 PKT: MAIL CHAIN CORRECTED: only QC8 is open; QC2 QC3 QC4 QC5 QC7 are done (ledger dates in blueprint top). QCONNECT reopened by his 01:05 (30 min), then QC8. My earlier 'remaining QC2..QC8' and 'back to QC2' lines were wrong.
NEXT STEP: 1) his qconnect-switch.sh paste + sign in once 2) qconnect-measure.sh 3) pg-local-dump-install.sh 4) my Chrome look 5) THEN QC8 (shortcuts + accessibility final pass): contract in CURRENT.md first. Source of truth: FOUNDER-MAILBOX-PHASES-18NOV.md + DONE-DO-NOT-REPEAT.md.
HIS LAST WORD: yeh kaise mix hua, QC8 ne ana tha, blueprint update kero, repo se ledger do
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
- 4521e501 21 Nov 01:08 ledger line bcb5e7c2
- bcb5e7c2 21 Nov 01:08 correction: QC3a already done, QCONNECT reopened state
- b2df55a5 21 Nov 01:05 ledger line e1aba74a
- e1aba74a 21 Nov 01:05 QCONNECT reopened: step 9 measure + step 10 dump scripts
- 4e5fec6c 21 Nov 00:59 ledger line 89ada5c6

## Uncommitted files (half-done work if any)
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/DONE-DO-NOT-REPEAT.md
 M docs/claude/FOUNDER-MAILBOX-PHASES-18NOV.md
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
 docs/claude/founder/PULL-COMMANDS.md               |  2 +-
 docs/claude/state/WORKING-NOW.md                   | 33 ++++++++++------------
 docs/claude/tech-contracts/CURRENT.md              |  2 +-
 ...DE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md |  2 +-
 docs/cursor-work/DONE-DO-NOT-REPEAT.md             |  2 +-
 docs/cursor-work/founder/founder-commands.md       |  2 +-
 docs/cursor-work/server/PULL-COMMANDS.md           |  2 +-
 11 files changed, 25 insertions(+), 27 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (7e867d551cca1233687cacbd2fca6e3f7a08cd1d)
