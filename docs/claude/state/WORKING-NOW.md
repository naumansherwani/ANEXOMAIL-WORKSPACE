# WORKING NOW (manual checkpoint, 21 Nov 2026 01:34 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QCONNECT green+closed, but HIS 01:33 CONCERN is the top open item: founder data now single-copy on his one server (dump on the same server). Awam NOT moved. Waiting his answer: what is 'server 2' / how is the server hosted, and which off-server copy he accepts (not Storage Box, no vendor).
NEXT STEP: Do NOT write backup scripts until he answers (law 3: read-only question first). Then write the off-server copy line. Then QC8.
HIS LAST WORD: yeh umar bhar ka masla, awam bhi risk founder bhi risk, storage pe weight na aye
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
- 15a66e88 21 Nov 01:30 ledger line ff446368
- ff446368 21 Nov 01:30 QCONNECT: green and closed by founder word
- e5bc0eae 21 Nov 01:28 ledger line e046ad80
- e046ad80 21 Nov 01:28 QCONNECT: declared done with proof, gaps recorded, next QC8
- eab16a49 21 Nov 01:26 ledger line e9575f5c

## Uncommitted files (half-done work if any)
 M docs/claude/CLOSE-THE-GAPS-07NOV.md
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/CLOSE-THE-GAPS-07NOV.md |  1 +
 docs/claude/state/WORKING-NOW.md    | 24 ++++++------------------
 2 files changed, 7 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (828f8fa035f9c621889951baab95a30e85d0fffb)
