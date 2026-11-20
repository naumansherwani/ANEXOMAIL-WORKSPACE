# WORKING NOW (manual checkpoint, 20 Nov 2026 08:15 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 badges written (not installed); QC3-7 partly live
NEXT STEP: his founder-install, then my live look at Sent badges + try 390/820 frame
HIS LAST WORD: his 08:14 order: start the rest
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
- 79f3707b 20 Nov 08:11 ledger line b987ba29
- b987ba29 20 Nov 08:11 QC3 live look
- b2298679 20 Nov 08:09 ledger line 57a6b8f3
- 57a6b8f3 20 Nov 08:09 QC3 saboot
- 107550d2 20 Nov 08:09 ledger line 23afc953

## Uncommitted files (half-done work if any)
M  CLAUDE.md
M  docs/claude/BLUEPRINT-ABC-01NOV.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/PHASE-NOW.md
M  docs/claude/QC3-PLAN-20NOV.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
 M docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
D  founder-web/dist/assets/index-BnCN-wK_.css
R  founder-web/dist/assets/index-BcI-69ZE.js -> founder-web/dist/assets/index-D-pOXvDk.js
A  founder-web/dist/assets/index-DJ-uNax-.css
M  founder-web/dist/index.html
M  founder-web/src/MailBox.tsx
A  founder-web/src/SentBadges.tsx
M  founder-web/src/presend.css
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/founder.txt
M  lovable-gold/README.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/src/MailBox.tsx                        |  4 +-
 founder-web/src/SentBadges.tsx                     | 34 +++++++++++++++
 founder-web/src/presend.css                        |  3 ++
 founder-web/src/system_brain.json                  |  6 +--
 lanes/ALL-FILES.csv                                |  5 ++-
 lanes/founder.txt                                  |  5 ++-
 lovable-gold/README.md                             |  2 +-
 26 files changed, 150 insertions(+), 77 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 08:40 PKT QC3 GAP CLOSE (20 Nov 2026 08:40 PKT): Sent-list badges MOUNTED in code (SentBadges.tsx: one batch call via kernel RPC mail_api.badges, max 100 ids, polls 30 s only while mail is moving, calm: only Sending/Delayed/Failed/Scheduled/Undo/Cancelled/Undone get a word; Mail
> ## >>> 20 Nov 2026 08:25 PKT QC3-7 LIVE LOOK (20 Nov 2026 08:25 PKT, my Chrome, his founderworkspace.anexomail.com, 1536 wide): live bundle index-DhaYIeTm.js contains the QC3 code (mail/timeline, presets). SENT timeline PROVEN LIVE on real mail 'QC3a send now proof': Queued 11:30:16, Send now pres
> ## >>> 20 Nov 2026 08:12 PKT QC3 SABOOT (his founder-install paste, 2 runs, 20 Nov 2026 08:12 PKT): SPA index=200, exchange bina token=401, Ed25519 signing ON kid s1 write-request signature ENFORCED, public key endpoint=200, healthz=200, me bina token=401, bridge bina token=401, OK founder service
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
NOW: QC1c - COMPOSE C1c: TLS lock on every chip from our own STARTTLS probe (SQL E187; discuss after QC1b)  [Rust Tokio SMTP STARTTLS rustls X25519MLKEM768 probe, PostgreSQL domain TLS facts]
WIP snapshot: refs/wip/last (b5677b7a4eca3b1ded3bde9d153c12fe8d52ecf3)
