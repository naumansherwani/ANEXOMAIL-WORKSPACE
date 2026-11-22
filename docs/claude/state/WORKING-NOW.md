# WORKING NOW (manual checkpoint, 22 Nov 2026 23:39 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: D5a-3b contract v2 written from his real database facts; folder phases written (Dashboard separate, rail order)
NEXT STEP: build control-plane crate: sign + answer core with tests, then HTTP/3 server, CP1.sql, installer
HIS LAST WORD: his 23:3x word: dashboard phases separate, rail order phases
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
- e12110bb 22 Nov 23:34 ledger line 0c4cbfb4
- 0c4cbfb4 22 Nov 23:34 D5a-3b schema paste and look 2
- 610119ff 22 Nov 22:42 ledger line ed337fb9
- ed337fb9 22 Nov 22:42 D5a-2 GREEN and phase R plan
- 2f2c8c6f 22 Nov 22:27 ledger line 61797108

## Uncommitted files (half-done work if any)
 M admin-desk/D5A-3B-SCHEMA-READ-22NOV.md
 M admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/admin-desk/D5A-3B-SCHEMA-READ-22NOV.md
 M docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
?? admin-desk/FOLDER-PHASES-22NOV.md
?? docs/claude/admin-desk/FOLDER-PHASES-22NOV.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 admin-desk/D5A-3B-SCHEMA-READ-22NOV.md             |  3 ++
 admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md        | 37 +++++++++++++++++++++-
 docs/claude/admin-desk/D5A-3B-SCHEMA-READ-22NOV.md |  3 ++
 .../admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md    | 37 +++++++++++++++++++++-
 docs/claude/state/WORKING-NOW.md                   | 30 +++++++-----------
 docs/claude/tech-contracts/CURRENT.md              | 11 +++++++
 6 files changed, 101 insertions(+), 20 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (30bbf7a78aedd6dd6bf7c4e8c1ab7d051f52f93f)
