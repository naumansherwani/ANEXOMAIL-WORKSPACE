# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 19:27 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: DK-b: DK3 device key custody + DK4 screen (his order 19:26: finish ALL of DK first, no questions; QC5 paused after recon: SQL fmail_delete_hard exists, touch action mail.delete exists, Rust door + UI missing)
NEXT STEP: write DK3/DK4 contract in CURRENT.md, then code: kernel keygen+wrap, passkey PRF, IndexedDB, pubkey door, sealed_for_kernel read pane, Reply/Forward
HIS LAST WORD: phudi: finish all DK first, stop asking
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 03:30 PKT** (real clock). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
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
- 4fefe297 20 Nov 19:22 ledger line 3db4ad62
- 3db4ad62 20 Nov 19:22 DK-a live Chrome look recorded (19:35 PKT)
- 481ce7fd 20 Nov 19:22 ledger line ea896d7b
- ea896d7b 20 Nov 19:22 DK-a live look
- 5aaedbde 20 Nov 19:21 ledger line bcf1bc3c

## Uncommitted files (half-done work if any)
 M docs/claude/DONE-DO-NOT-REPEAT.md
 M docs/claude/RESUME-POINT.md
 M docs/claude/founder/PULL-COMMANDS.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
 M docs/cursor-work/DONE-DO-NOT-REPEAT.md
 M docs/cursor-work/founder/founder-commands.md
 M docs/cursor-work/server/PULL-COMMANDS.md
 M web-wasm/src/kemopen.rs
 M web-wasm/src/lib.rs
?? docs/cursor-work/server/ckpt-loop.sh

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/tech-contracts/CURRENT.md              |  2 +-
 ...DE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md |  2 +-
 docs/cursor-work/DONE-DO-NOT-REPEAT.md             |  2 +-
 docs/cursor-work/founder/founder-commands.md       |  2 +-
 docs/cursor-work/server/PULL-COMMANDS.md           |  2 +-
 web-wasm/src/kemopen.rs                            | 38 ++++++++++++++++++++++
 web-wasm/src/lib.rs                                |  8 +++++
 11 files changed, 70 insertions(+), 26 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (25a8af4e06b16911885d1024fd8638e4af4eb269)
