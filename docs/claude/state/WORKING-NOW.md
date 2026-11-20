# WORKING NOW (manual checkpoint, 20 Nov 2026 23:38 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT score 6 of 10 proven on his server; step 6 Rust pg engine INSTALLED switched OFF (his founder-install paste OK, journal still REST 324-508 ms as designed); NOW step 7 Rust signin owns passwords + sessions (survey the 4 direct-http places in auth.rs/passkey.rs/signin.rs, read E153/E167 first)
NEXT STEP: 1) step 7 survey + code (SQL schema-first: read E153/E167/passkey schema); 2) his founder-install; 3) step 8 delta copy + freeze + FOUNDER_DB=local + rollback; 4) step 9 re-measure; 5) step 10 nightly dump on server only
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
- 2d8fd6ea 20 Nov 23:26 ledger line 0f24446d
- 0f24446d 20 Nov 23:26 QCONNECT step 6: Rust local PostgreSQL engine inside Sb (pg.rs), FOUNDER_DB=local
- 0ad082f3 20 Nov 22:22 ledger line 5f355fee
- 5f355fee 20 Nov 22:22 QCONNECT: step 6 survey and design
- 6247ded3 20 Nov 22:21 ledger line 91003589

## Uncommitted files (half-done work if any)
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/QCONNECT-PLAN-20NOV.md
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/BLUEPRINT-ABC-01NOV.md |  1 +
 docs/claude/QCONNECT-PLAN-20NOV.md |  3 +++
 docs/claude/state/WORKING-NOW.md   | 23 ++++++-----------------
 3 files changed, 10 insertions(+), 17 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (97c76c33a83ad38c04824b368b23e10d6de00140)
