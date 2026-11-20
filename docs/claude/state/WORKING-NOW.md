# WORKING NOW (manual checkpoint, 20 Nov 2026 22:06 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT: copy table-complete (677/677, pgvector 0.8.1); his word: NO dump on the Storage Box; pg-local-compare.sh (hash compare + verify functions) written, waits his run; nothing wired into the running service yet
NEXT STEP: 1) his paste of pg-local-compare; 2) Rust data.rs pg backend (flag, REST rollback); 3) Rust signin owns passwords; 4) switch with rollback + re-measure (login 50 ms); 5) nightly dump ON SERVER only, 7 kept; meanwhile QSPEED E197
HIS LAST WORD: SQL advance 400+ likho QC7
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
- 24029b99 20 Nov 22:01 ledger line 7a55b36b
- 7a55b36b 20 Nov 22:01 QCONNECT: WORKING-NOW checkpoint corrected
- 1dc89ec9 20 Nov 22:00 ledger line 167b966e
- 167b966e 20 Nov 22:00 QCONNECT: copy proof 675/677, pg-local-vector.sh, status block
- 2ad9d26d 20 Nov 21:44 ledger line 3235e43e

## Uncommitted files (half-done work if any)
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/QCONNECT-PLAN-20NOV.md
 M docs/claude/state/WORKING-NOW.md
?? docs/cursor-work/server/pg-local-compare.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/BLUEPRINT-ABC-01NOV.md |  1 +
 docs/claude/QCONNECT-PLAN-20NOV.md |  4 ++++
 docs/claude/state/WORKING-NOW.md   | 24 +++++++-----------------
 3 files changed, 12 insertions(+), 17 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (7e75f7a8aa773b466040eaaffda6379a531174ee)
