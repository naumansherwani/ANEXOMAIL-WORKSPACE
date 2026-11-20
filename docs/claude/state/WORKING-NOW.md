# WORKING NOW (manual checkpoint, 21 Nov 2026 00:13 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 
NEXT STEP: 
HIS LAST WORD: ledger working now blueprint time date, compaction-proof, 2-min loop, rules read, advance technology
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
- 075ab205 21 Nov 00:04 ledger line 814aa2f4
- 814aa2f4 21 Nov 00:04 QCONNECT: bootstrap guard against managed Supabase
- 88886515 20 Nov 23:56 ledger line a3842b0e
- a3842b0e 20 Nov 23:56 QCONNECT step 7: Rust identity engine localid.rs + LOCAL_E198 doors
- f6844be0 20 Nov 23:46 ledger line 4cca17f3

## Uncommitted files (half-done work if any)
M  CLAUDE.md
MM docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/QCONNECT-PLAN-20NOV.md
MM docs/claude/RESUME-POINT.md
MM docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
MM docs/claude/tech-contracts/CURRENT.md
MM docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
MM docs/cursor-work/DONE-DO-NOT-REPEAT.md
MM docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
MM docs/cursor-work/server/PULL-COMMANDS.md
R  founder-web/dist/assets/index-O4qxGF_C.js -> founder-web/dist/assets/index-BhYDc03m.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/founder.txt

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/cursor-work/server/DEPLOY-MANIFEST.txt        | 30 ++++++++--------
 docs/cursor-work/server/PULL-COMMANDS.md           |  2 ++
 .../{index-O4qxGF_C.js => index-BhYDc03m.js}       |  2 +-
 founder-web/dist/index.html                        |  2 +-
 founder-web/src/system_brain.json                  |  6 ++--
 lanes/ALL-FILES.csv                                |  2 +-
 lanes/founder.txt                                  |  2 +-
 18 files changed, 71 insertions(+), 45 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (2ea8f80c715d87fb17b4b542fac52fe2c2d4e8bd)
