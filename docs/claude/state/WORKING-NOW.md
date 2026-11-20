# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 08:41 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 GREEN by his word 08:52 (b77e8f47). Outbox badges + tile fix pushed, NOT installed
NEXT STEP: his next founder-install, then my live look at Outbox badge; then QC4 inline reply+forward (check QC2 status in FOUNDER-MAILBOX-PHASES-18NOV.md first; write QC4 tech contract in CURRENT.md first)
HIS LAST WORD: 5-min check 08:42
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
- 1557e182 20 Nov 08:41 QC3 checkpoint
- b77e8f47 20 Nov 08:39 ledger line fb812c58
- fb812c58 20 Nov 08:39 QC3 green by his word; Outbox badges; delivery tile layout fix from live look
- 5398cb0e 20 Nov 08:35 ledger line 6da637d5
- 6da637d5 20 Nov 08:35 QC3 checkpoint

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 17 ++---------------
 1 file changed, 2 insertions(+), 15 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 08:52 PKT QC3 = GREEN BY HIS WORD (20 Nov 2026 08:52 PKT: his 'green kero' + his founder-install paste x2 + his phone screenshot 08:29). WIRED: YES / REAL: YES / TECH-LAW CHECKED for: (a) Sent timeline on real mail, (b) compose schedule presets Karachi time, (c) Systems > Mail h
> ## >>> 20 Nov 2026 08:45 PKT QC3 LOOPHOLE FIX (20 Nov 2026 08:45 PKT): #5 service worker stale bundle = CLOSED WITH PROOF (live headers: index /_cc/ no-store, early.js no-store, flare-sw.js no-store, hashed bundle immutable; flare-sw.js only handles push + 'anexo-flare' cache, never caches the bun
> ## >>> 20 Nov 2026 08:27 PKT QC3 AUDIT: docs/claude/QC3-AUDIT-20NOV.md. Live bundle = QC3-5 (badges 7a3f1fa0 not installed yet). Doors 401 without token, healthz 200. 390/820 live = after the Q series (his 08:20). Open: badges live, delivery-board mount, bar live, SW stale. <<<
> ## >>> 20 Nov 2026 08:40 PKT QC3 GAP CLOSE (20 Nov 2026 08:40 PKT): Sent-li
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (09ccc11c357d0f9d95642943c2416d6ebd3a6412)
