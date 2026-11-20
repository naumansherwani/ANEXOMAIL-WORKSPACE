# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 08:23 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 badges + delivery board written+pushed (60865477), NOT installed; SW loophole closed with proof
NEXT STEP: his founder-install, then my live look: Sent badges + Systems>Mail health board; bar live, 390/820 (after Q series), per-recipient rows, attachment-word check open
HIS LAST WORD: 5-min check 08:23
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
- 81d8870e 20 Nov 08:23 QC3 checkpoint
- 60865477 20 Nov 08:22 ledger line 1a93644c
- 1a93644c 20 Nov 08:22 QC3: delivery board + checkpoint
- 44763e6e 20 Nov 08:22 ledger line a7ba122a
- a7ba122a 20 Nov 08:22 QC3 delivery board

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 17 ++---------------
 1 file changed, 2 insertions(+), 15 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 08:45 PKT QC3 LOOPHOLE FIX (20 Nov 2026 08:45 PKT): #5 service worker stale bundle = CLOSED WITH PROOF (live headers: index /_cc/ no-store, early.js no-store, flare-sw.js no-store, hashed bundle immutable; flare-sw.js only handles push + 'anexo-flare' cache, never caches the bun
> ## >>> 20 Nov 2026 08:27 PKT QC3 AUDIT: docs/claude/QC3-AUDIT-20NOV.md. Live bundle = QC3-5 (badges 7a3f1fa0 not installed yet). Doors 401 without token, healthz 200. 390/820 live = after the Q series (his 08:20). Open: badges live, delivery-board mount, bar live, SW stale. <<<
> ## >>> 20 Nov 2026 08:40 PKT QC3 GAP CLOSE (20 Nov 2026 08:40 PKT): Sent-list badges MOUNTED in code (SentBadges.tsx: one batch call via kernel RPC mail_api.badges, max 100 ids, polls 30 s only while mail is moving, calm: only Sending/Delayed/Failed/Scheduled/Undo/Cancelled/Undone get a word; Mail
> ## >>> 20 Nov 2026 08:25 PKT QC3-7 LIVE LOOK (20 Nov 2026 08:25 PKT, my Chrome, his founderworkspace.anexomail.com, 1536 wide): live bundle index-DhaYIeTm.js contains the QC3 code (mail/timeline, presets). SENT timeline PROVEN LIVE on real mail 'QC3a send now proof': Queued 11:30:16, Send now pres
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (22704d55e2d5451fc460202b8bd564d826424da3)
