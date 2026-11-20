# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 09:04 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 GREEN by his word 08:52; QC4 inline reply+forward is NOW (QC2 already green); Outbox badge fix waits his install
NEXT STEP: write QC4 tech contract in CURRENT.md first (mail-parser + mail-builder Rust, kernel RPC, React 19 TS), check existing reply/forward code in MailBox.tsx/MailCompose.tsx, then plan+code
HIS LAST WORD: 5-min check 08:48
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
- 55886126 20 Nov 09:04 QC4 split in blueprint and PHASE-NOW
- f4ef5fe4 20 Nov 09:04 ledger line 0585ad19
- 0585ad19 20 Nov 09:04 QC4 split plan
- 318cce26 20 Nov 09:00 ledger line b3255c53
- b3255c53 20 Nov 09:00 QC4-2: reply_pure.ts (reply all, forward, fold, selection, References) + golden tests

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 17 ++---------------
 1 file changed, 2 insertions(+), 15 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on branch wip-qc4a until the wh
> ## >>> 20 Nov 2026 09:10 PKT QC4-2 DONE (20 Nov 2026 09:10 PKT): founder-web/src/reply_pure.ts + 13 golden tests (pure TypeScript, sandbox runner only): replyTargets (reply, reply all, me removed, dedupe, Reply-To), subjects (Re once, Fwd once), replyBody (selection replaces whole mail), forwardBo
> ## >>> 20 Nov 2026 09:03 PKT QC3 = GREEN FINAL BY THE CHAIRMAN'S WORD (20 Nov 2026 09:03 PKT, his 08:55: 'main chairman hoon, tu green likho bus final hai'). WIRED: YES / REAL: YES / TECH-LAW CHECKED. Whole phase QC3-1..QC3-7. Proof: his founder-install x3 (4/4 saboot: SPA 200, exchange without to
> ## >>> 20 Nov 2026 08:58 PKT QC4 (inline reply and forward) STARTED: plan docs/claude/QC4-PLAN-20NOV.md, contract top of tech-contracts/CURRENT.md. Next: QC4-2 pure TS reply_pure.ts, QC4-3 Rust References from the store
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (d5ca7f4b211560519431727c5594e8eeaf0e21b0)
