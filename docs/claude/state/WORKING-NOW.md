# WORKING NOW (manual checkpoint, 21 Nov 2026 01:21 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT SWITCH IS LIVE on his server (21 Nov ~01:30 PKT, his paste): second switch run OK, journal 'database engine = LOCAL PostgreSQL', healthz 200, me 401, bridge 401, 36 tables copied, 0 founder-owned mismatches. Root cause of run 1 was the identity key format (fixed). He must SIGN IN ONCE (old gotrue tokens invalid). NOT declared done: needs his sign-in, measure, dump, my Chrome look.
NEXT STEP: 1) he signs in once (password or passkey) 2) qconnect-measure.sh paste 3) pg-local-dump-install.sh paste 4) my Chrome look at the signed-in dashboard (read-only) 5) declare only with WIRED+REAL+TECH-LAW proof 6) then QC8. Rollback OFF=1. No guesses.
HIS LAST WORD: yeh kya sara saal chalega, web research kero, compaction save
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
- 3440a709 21 Nov 01:16 ledger line 2506c1b6
- 2506c1b6 21 Nov 01:16 QCONNECT fix 4: identity key DER with public key
- 1a331403 21 Nov 01:12 ledger line 4eda0677
- 4eda0677 21 Nov 01:12 correction: only QC8 open in the mail chain
- 4521e501 21 Nov 01:08 ledger line bcb5e7c2

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
WIP snapshot: refs/wip/last (fdb4778fbf1e4efbce09cdac6f29224c11b097ba)
