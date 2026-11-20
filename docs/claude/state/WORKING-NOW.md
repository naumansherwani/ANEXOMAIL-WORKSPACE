# WORKING NOW (manual checkpoint, 21 Nov 2026 03:24 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 21 Nov 03:25 PKT QC8a started (his haan): his 5 answers written, a1 audit done; a2 new pure key-map module + golden tests, NEW files only
NEXT STEP: a2 mail_keymap.ts + test, then show him the mount line and the ? sheet mock
HIS LAST WORD: his 21 Nov 03:22: 5 answers, shuru kero QC8a
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
- 22dc79a2 21 Nov 03:12 ledger line 6de007e8
- 6de007e8 21 Nov 03:12 QC8a and QC8b plan with research (no code)
- 57c035db 21 Nov 03:09 ledger line f05b5efe
- f05b5efe 21 Nov 03:09 Docs: only GREEN, no 'by his word' after GREEN (his 03:07 order)
- 19f81c27 21 Nov 03:07 ledger line e982cd7a

## Uncommitted files (half-done work if any)
 M docs/claude/QC8A-QC8B-PLAN-21NOV.md
 M docs/claude/state/WORKING-NOW.md
 M docs/cursor-work/founder/founder-commands.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/QC8A-QC8B-PLAN-21NOV.md          | 18 ++++++++++++++++++
 docs/claude/state/WORKING-NOW.md             | 25 +++++++------------------
 docs/cursor-work/founder/founder-commands.md |  2 ++
 3 files changed, 27 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (9f534b57d8d8b275cc8b8a1efc06986acfc43f0b)
