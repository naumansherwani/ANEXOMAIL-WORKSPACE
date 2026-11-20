# WORKING NOW (manual checkpoint, 20 Nov 2026 22:22 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT score 5 of 10 DONE; step 6 SURVEY DONE (212 rpc names, 17 rows reads over 10 tables, 2 counts, 4 files with direct http); design written in the plan: second engine inside Sb, env FOUNDER_DB=local, templates from pg_proc, deadpool-postgres on the socket; code not started
NEXT STEP: 1) step 6 code: pg.rs + Sb engine switch + tests against the scratch Postgres in the sandbox (rpc template from pg_proc, rows translator); 2) step 7 signin; 3) step 8 switch + delta copy + rollback; 4) step 9 re-measure; 5) step 10 nightly dump on server only
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
- 6247ded3 20 Nov 22:21 ledger line 91003589
- 91003589 20 Nov 22:21 QCONNECT: step 5 compare done, score 5 of 10
- 2cbd984f 20 Nov 22:16 ledger line 3313ce56
- 3313ce56 20 Nov 22:16 QCONNECT: compare script empty-table fix, score 4 of 10
- 0014035f 20 Nov 22:07 ledger line e7abd9dc

## Uncommitted files (half-done work if any)
 M docs/claude/QCONNECT-PLAN-20NOV.md
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/QCONNECT-PLAN-20NOV.md |  3 +++
 docs/claude/state/WORKING-NOW.md   | 22 +++++-----------------
 2 files changed, 8 insertions(+), 17 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (38cc47504368e6f496f832d7634fa1b5b750aaad)
