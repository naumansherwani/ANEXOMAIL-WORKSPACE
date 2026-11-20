# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 09:08 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 GREEN FINAL; QC4 split QC4a/QC4b written (1adfade8); QC4-2 pure TS done; Rust References on branch wip-qc4a, cargo NOT run yet (he interrupted a run; I asked him whether to run it)
NEXT STEP: his answer on cargo run; then QC4a: Reply-To in Summary + cargo whole suite + merge to main + mail_api references; then QC4b screen; one install
HIS LAST WORD: 5-min check 09:35
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
- a8a4c09c 20 Nov 09:08 QC4a done
- 96a94a79 20 Nov 09:04 ledger line 5c5cb77d
- 5c5cb77d 20 Nov 09:04 QC4 checkpoint
- 1adfade8 20 Nov 09:04 ledger line 55886126
- 55886126 20 Nov 09:04 QC4 split in blueprint and PHASE-NOW

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 19 +++----------------
 1 file changed, 3 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on branch wip-qc4a until the wh
> ## >>> 20 Nov 2026 09:10 PKT QC4-2 DONE (20 Nov 2026 09:10 PKT): founder-web/src/reply_pure.ts + 13 golden tests (pure TypeScript, sandbox runner only): replyTargets (reply, reply all, me removed, dedupe, Reply-To), subjects (Re once, Fwd once), replyBody (selection replaces whole mail), forwardBo
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
NOW: QC1c - COMPOSE C1c: TLS lock on every chip from our own STARTTLS probe (SQL E187; discuss after QC1b)  [Rust Tokio SMTP STARTTLS rustls X25519MLKEM768 probe, PostgreSQL domain TLS facts]
WIP snapshot: refs/wip/last (170261165c5fc3e58fac39d65ecab37152a07231)
