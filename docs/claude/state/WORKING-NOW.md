# WORKING NOW (manual checkpoint, 24 Nov 2026 06:07 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: B13 Z4 plan written
NEXT STEP: Z4a SQL cp.consent_inbox, Z4b Control Plane door
HIS LAST WORD: his 06:06 order
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
- 5e2f36bd 24 Nov 06:00 ledger line a0654476
- a0654476 24 Nov 06:00 title wrap green
- 21a4f6f2 24 Nov 05:54 ledger line 438b135a
- 438b135a 24 Nov 05:54 dashboard remaining
- ec731295 24 Nov 05:53 ledger line dfb8e075

## Uncommitted files (half-done work if any)
A  admin-desk/D6-B13-Z4-CUSTOMER-APPROVAL-PLAN-24NOV.md
M  admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  admin-desk/NOW-LIST-23NOV.md
A  docs/claude/admin-desk/D6-B13-Z4-CUSTOMER-APPROVAL-PLAN-24NOV.md
M  docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  docs/claude/admin-desk/NOW-LIST-23NOV.md
M  docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 admin-desk/NOW-LIST-23NOV.md                       |  1 +
 .../D6-B13-Z4-CUSTOMER-APPROVAL-PLAN-24NOV.md      |  7 +++++
 .../admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md    |  3 +++
 docs/claude/admin-desk/NOW-LIST-23NOV.md           |  1 +
 docs/claude/admin-desk/state/WORKING-NOW.md        |  1 +
 docs/claude/state/WORKING-NOW.md                   | 31 +++++++++-------------
 docs/cursor-work/server/DEPLOY-MANIFEST.txt        |  8 +++---
 9 files changed, 40 insertions(+), 22 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (29d947d685366ed78f5430572b22e5716364787f)
