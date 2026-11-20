# WORKING NOW (manual checkpoint, 21 Nov 2026 01:26 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT 10 of 10 steps RAN on his server (21 Nov 01:4x PKT): switch live (LOCAL PostgreSQL + LOCAL identity), measured (door ~3 ms vs REST 307-324 ms), nightly dump installed (13M, SHA-256 OK, timer 03:20 UTC, server only). He SIGNED IN via the local identity engine (my Chrome 01:25: dashboard 2/2, 11/11 endpoints, HTTP/3 QUIC, ML-DSA-65; Mail page shows his real mailbox: Inbox 1, Sent 10, Trash 4). NOT yet declared: need a fresh SLOW-lines count since the switch (his one line) to prove the 320 ms is gone end to end.
NEXT STEP: 1) his paste: journalctl -u anexomail-founder --since=-5min --no-pager | grep -c SLOW 2) if ~0: declare QCONNECT done with WIRED+REAL+TECH-LAW proof (backend only, no UI change so Rule 34 N/A), gaps to CLOSE-THE-GAPS: reverse copy, awam-written tables stale, E197 3) then QC8. Rollback OFF=1.
HIS LAST WORD: live chrome pe aao khudi dekho
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
- 5f42bf46 21 Nov 01:24 ledger line 21b19439
- 21b19439 21 Nov 01:24 QCONNECT: step 9 measured, Chrome look at login page
- f0e19f19 21 Nov 01:22 ledger line 070d084f
- 070d084f 21 Nov 01:22 QCONNECT: switch live on his server, state saved
- 3440a709 21 Nov 01:16 ledger line 2506c1b6

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 23 +++++------------------
 1 file changed, 5 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (dc275cd64b34fe9c9d486c8ab287295bd1a556d7)
