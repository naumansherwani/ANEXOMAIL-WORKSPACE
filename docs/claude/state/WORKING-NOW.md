# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 21:44 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT step 3 WRITTEN (not run): pg-local-install.sh (PostgreSQL from Ubuntu packages, PG18, cluster on a UNIX SOCKET ONLY, no TCP port, database anexo_founder, root peer role, compat layer QCONNECT_bootstrap.sql idempotent on scratch PG16) + ports paste 21:06 recorded in PORTS-LIVE.md (no new listener). His ONE line to run is in chat. After his paste: sql-run on the new database with ENV_FILE=/etc/anexomail/local-pg.env LEDGER=/var/lib/anexomail/sql-applied-local.tsv, then CHECKs. AUTH FACT: password login + session mint still use the managed auth service; Rust signin must own passwords and sessions before the switch (passkey login needs no password check).
NEXT STEP: 1) his paste of pg-local-install; 2) sql-run E-line on the local DB (ENV_FILE + LEDGER overrides), fix any E-file that needs a managed-project-only object; 3) E197 login door; 4) data copy; 5) Rust Postgres backend
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
- 3235e43e 20 Nov 21:44 QCONNECT: pg-local-copy.sh (dump + restore + row-count proof); install proven
- 2e706d12 20 Nov 21:39 ledger line 8489873a
- 8489873a 20 Nov 21:39 QCONNECT: pg-local-install unset PGHOST, explicit socket host
- acaa3bd4 20 Nov 21:16 ledger line 881a9d63
- 881a9d63 20 Nov 21:16 QCONNECT: pg-local-install socket-only fix (ALTER SYSTEM + restart + diagnosis)

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 19 +++----------------
 1 file changed, 3 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (8b9df9b513b7f2975221c71628e2f2d0ec52b04f)
