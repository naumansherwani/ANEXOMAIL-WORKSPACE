# WORKING NOW (manual checkpoint, 21 Nov 2026 02:13 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 21 Nov 02:55 PKT: qconnect-login-only.sh WRITTEN + sandbox-tested (guards: empty list, refuse if Supabase has more rows, privilege test before stopping, append-only ledgers copied through replica role). Order for him: 1 founder-install (new binary, still local mode), 2 qconnect-login-only.sh. His open session stays valid.
NEXT STEP: He runs line 1 then line 2 and pastes; then my Chrome look (dashboard, HTTP/3, ML-DSA, Mail) and the proof that login is local and data is REST. Rollback OFF=1.
HIS LAST WORD: his 21 Nov 02:11: only login on server, rest as before, tech intact
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
- 3edfe459 21 Nov 02:03 ledger line 7a3ddbf1
- 7a3ddbf1 21 Nov 02:03 QCONNECT-LO: login-only mode code, contract, back-diff script
- f6c20944 21 Nov 01:56 ledger line da20e427
- da20e427 21 Nov 01:56 QCONNECT: option 2 chosen, mirror probe script, login-only parked
- ed804ee5 21 Nov 01:50 ledger line de43576b

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
?? docs/cursor-work/server/qconnect-login-only.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md      | 25 +++++++------------------
 docs/claude/tech-contracts/CURRENT.md |  2 +-
 2 files changed, 8 insertions(+), 19 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (25b966a375d7441c79895b0bb2e6a62f1e8a973c)
