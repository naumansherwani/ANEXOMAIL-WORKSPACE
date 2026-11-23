# WORKING NOW (manual checkpoint, 23 Nov 2026 12:01 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: Title + B9c installed, 390/820 and Y4/Y5/Y6 open; blueprint updated
NEXT STEP: title 390/820 look, B9c Y4/Y5/Y6 after his Y6 answer, then BL-29 CC1
HIS LAST WORD: his 11:58 order (sone gaya)
LATER (his 23 Nov 05:10, OVERVIEW-S4-LATER): Overview screen (his 22.jpg look) comes at the END, after 1o, 1a, phone/tablet test, Founder Escalation Inbox: docs/claude/admin-desk/OVERVIEW-S4-PLAN-23NOV.md. Also FOUNDER-ESCALATION-INBOX after 1o.
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
## AWAM Rust engine = process `anexomail-rust` (pid 3145875 at 20 Nov 03:30)
| Proto | Address:Port | Meaning |
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## RESERVED BY HIS WORD 21 Nov 2026 07:5x PKT: TCP 127.0.0.1:4400 = ADMIN DESK (own Rust process `anexomail-desk`, loopback only; Caddy has the admindesk block since 21 Nov 07:51 PKT: reverse_proxy 127.0.0.1:4400, validated + reloaded; noth

## Last 5 commits
- db7190ba 23 Nov 11:50 ledger line 5a47b976
- 5a47b976 23 Nov 11:50 Command Center title in the real Desk
- 2b0fed22 23 Nov 11:47 ledger line 6847778f
- 6847778f 23 Nov 11:47 Command Center title V24 soft light centre
- a15f318c 23 Nov 11:44 ledger line c024beeb

## Uncommitted files (half-done work if any)
M  admin-desk/D6-CARDS-LIST-23NOV.md
M  admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  admin-desk/NOW-LIST-23NOV.md
A  backups/desk/20261123-1205-command-center-title-approved/00-FOUNDER-TECH-RULE.md
A  backups/desk/20261123-1205-command-center-title-approved/APPROVED-DEMO-V24.html
A  backups/desk/20261123-1205-command-center-title-approved/DeskTitle.tsx
A  backups/desk/20261123-1205-command-center-title-approved/README.md
A  backups/desk/20261123-1205-command-center-title-approved/desk_title.test.ts
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/admin-desk/D6-CARDS-LIST-23NOV.md
M  docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  docs/claude/admin-desk/NOW-LIST-23NOV.md
M  docs/claude/admin-desk/state/WORKING-NOW.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
R  founder-web/dist/assets/index-DGS4aJoa.js -> founder-web/dist/assets/index-DUci0g_o.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/founder.txt
M  lanes/shared.txt
M  lovable-gold/README.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 .../{index-DGS4aJoa.js => index-DUci0g_o.js}       |   2 +-
 founder-web/dist/index.html                        |   2 +-
 founder-web/src/system_brain.json                  |   6 +-
 lanes/ALL-FILES.csv                                |   7 +-
 lanes/founder.txt                                  |   2 +-
 lanes/shared.txt                                   |   5 +
 lovable-gold/README.md                             |   2 +-
 30 files changed, 325 insertions(+), 56 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (28d0d604d3d242b98222553351816004e9fb29a4)
