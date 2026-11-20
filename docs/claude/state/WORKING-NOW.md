# WORKING NOW (auto snapshot before a compaction, 21 Nov 2026 01:41 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: REAL CLOCK 21 Nov 01:40 PKT (my earlier stamps 01:42 onward up to 02:10 ran AHEAD of the real clock; order by commit time is true, use date). HIS 01:40 WORD: before QCONNECT the founder system was fine for speed, he asked ONLY for the LOGIN to be fast. The switch moved the whole founder database local. He must run the rollback line (OFF=1) or decide. Login-only needs an identity+session plane split (new code, contract, audit), not tonight.
NEXT STEP: 1) his OFF=1 paste (or his decision to keep local) 2) if rollback: record it, then plan 'login plane local, data plane managed' with contract first (QSPEED E197 + local identity/session tables), 3) off-server backup question only if he keeps local 4) QC8. ALWAYS stamp ledger lines with the real clock from date.
HIS LAST WORD: qconnect se pehle jo system tha founder side ka wo batao, sirf login bola tha fast ho jaye baqi sab speed theek thi
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
- 95ee13ef 21 Nov 01:41 QCONNECT: real clock correction, login-only wish recorded
- 33b02cda 21 Nov 01:38 ledger line ff2c6a88
- ff2c6a88 21 Nov 01:38 QCONNECT: scope dispute recorded, rollback line given
- 1ed379a4 21 Nov 01:34 ledger line 6db7e2a1
- 6db7e2a1 21 Nov 01:34 backup risk recorded as top gap

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 17 ++---------------
 1 file changed, 2 insertions(+), 15 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (01650e898244a1ef973b4aaa827db830b884ba97)
