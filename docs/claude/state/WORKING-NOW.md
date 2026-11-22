# WORKING NOW (manual checkpoint, 23 Nov 2026 04:25 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1k GREEN with all closed items: 9 runbooks Approved by the Chairman (my Chrome, his account), checklist tick live + persisted. NOW = 1l D5c Escalate (research first)
NEXT STEP: 1l research + LIST + ADVANCE-RESEARCH [1l] + contract, then code; after 1o: 1a (Caddy to own HTTP/3 code) then phone 390 / tablet 820 test
HIS LAST WORD: his 04:23
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
- 2f1bf66f 23 Nov 04:18 ledger line cba544eb
- cba544eb 23 Nov 04:18 1k GREEN, NOW 1l
- 611b16af 23 Nov 04:10 ledger line c923b616
- c923b616 23 Nov 04:10 1k: install did not take, need head of output
- f4451da4 23 Nov 04:04 ledger line 889c9577

## Uncommitted files (half-done work if any)
 M admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M admin-desk/NOW-LIST-23NOV.md
 M docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/admin-desk/NOW-LIST-23NOV.md
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md        |  5 ++++
 admin-desk/NOW-LIST-23NOV.md                       |  3 +++
 .../admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md    |  5 ++++
 docs/claude/admin-desk/NOW-LIST-23NOV.md           |  3 +++
 docs/claude/state/WORKING-NOW.md                   | 27 ++++++++--------------
 5 files changed, 25 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (705c74a2023fe3c275c6352515f696365ae69e5c)
