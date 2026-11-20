# WORKING NOW (manual checkpoint, 20 Nov 2026 23:42 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT step 7 survey + design done (localid.rs Rust identity engine, design in the plan); SQL schema-first: pg-local-authschema.sh (read only) written, WAITS his paste of it before any code; score 6 of 10 proven
NEXT STEP: 1) his paste of pg-local-authschema.sh; 2) code localid.rs + bcrypt + key file in the installer + sandbox tests against a real PostgreSQL; 3) his founder-install; 4) step 8 switch; 5) step 9 re-measure; 6) step 10 dump on server only
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
- f4a003c8 20 Nov 23:38 ledger line c3563819
- c3563819 20 Nov 23:38 QCONNECT: step 6 installed (off), score 6 of 10
- 2d8fd6ea 20 Nov 23:26 ledger line 0f24446d
- 0f24446d 20 Nov 23:26 QCONNECT step 6: Rust local PostgreSQL engine inside Sb (pg.rs), FOUNDER_DB=local
- 0ad082f3 20 Nov 22:22 ledger line 5f355fee

## Uncommitted files (half-done work if any)
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/QCONNECT-PLAN-20NOV.md
 M docs/claude/state/WORKING-NOW.md
?? docs/cursor-work/server/pg-local-authschema.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/BLUEPRINT-ABC-01NOV.md |  1 +
 docs/claude/QCONNECT-PLAN-20NOV.md |  6 ++++++
 docs/claude/state/WORKING-NOW.md   | 24 +++++++-----------------
 3 files changed, 14 insertions(+), 17 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (95b9e15a0552e66d93e0da119a7f1f2accf75f0d)
