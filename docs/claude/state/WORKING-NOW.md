# WORKING NOW (manual checkpoint, 21 Nov 2026 00:25 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT step 8: his prep re-run 00:25 -> local cluster postgresql@18-main DOWN after restart with unix_socket_group=anexopg (live site unaffected, REST). FIX 2 pushed: postgres user also joins anexopg; script self-heals a down cluster and rolls the group line back on failure. Not yet re-run.
NEXT STEP: He re-runs qconnect-switch-prep.sh (same line) and pastes. If the restart fails again the script prints the log tail and restores the cluster. Then switch, then step 9.
HIS LAST WORD: ledger working now blueprint time date, compaction-proof, 2-min loop, rules read, advance technology
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
- da8ec74b 21 Nov 00:22 ledger line 7327db98
- 7327db98 21 Nov 00:22 QCONNECT: prep socket group fix
- 0e914f4a 21 Nov 00:19 ledger line f687effa
- f687effa 21 Nov 00:19 QCONNECT: step 8 switch scripts + contract
- a8e41c51 21 Nov 00:17 ledger line 821e8d69

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/server/qconnect-switch-prep.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md                | 23 ++++++-----------------
 docs/claude/tech-contracts/CURRENT.md           |  2 ++
 docs/cursor-work/server/qconnect-switch-prep.sh | 11 +++++++----
 3 files changed, 15 insertions(+), 21 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (78c3a35875da6a27f7c166c814221baa785090ce)
