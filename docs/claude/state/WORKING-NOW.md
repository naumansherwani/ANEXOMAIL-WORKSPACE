# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 09:00 PKT) - read this FIRST after a compaction; it is where the work stopped
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
- 970390e7 20 Nov 09:00 QC4-2 reply_pure
- f66b50ea 20 Nov 08:56 ledger line 76a91751
- 76a91751 20 Nov 08:56 QC3 green final by the chairman's word
- dbdb9081 20 Nov 08:56 ledger line 3e9fdb80
- 3e9fdb80 20 Nov 08:56 QC3 green final

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 19 +++----------------
 1 file changed, 3 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:10 PKT QC4-2 DONE (20 Nov 2026 09:10 PKT): founder-web/src/reply_pure.ts + 13 golden tests (pure TypeScript, sandbox runner only): replyTargets (reply, reply all, me removed, dedupe, Reply-To), subjects (Re once, Fwd once), replyBody (selection replaces whole mail), forwardBo
> ## >>> 20 Nov 2026 09:03 PKT QC3 = GREEN FINAL BY THE CHAIRMAN'S WORD (20 Nov 2026 09:03 PKT, his 08:55: 'main chairman hoon, tu green likho bus final hai'). WIRED: YES / REAL: YES / TECH-LAW CHECKED. Whole phase QC3-1..QC3-7. Proof: his founder-install x3 (4/4 saboot: SPA 200, exchange without to
> ## >>> 20 Nov 2026 08:58 PKT QC4 (inline reply and forward) STARTED: plan docs/claude/QC4-PLAN-20NOV.md, contract top of tech-contracts/CURRENT.md. Next: QC4-2 pure TS reply_pure.ts, QC4-3 Rust References from the stored parent, QC4-4 UI. Forward as .eml = Q3. <<<
> ## >>> 20 Nov 2026 08:52 PKT QC3 = GREEN BY HIS WORD (20 Nov 2026 08:52 PKT: his 'green kero' + his founder-install paste x2 + his phone screenshot 08:29). WIRED: YES / REAL: YES / TECH-LAW CHECKED for: (a) Sent timeline on real mail, (b) compose schedule presets Karachi time, (c) Systems > Mail h
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (df7d25b347e42128f793298abf5bfed96c0e7216)
