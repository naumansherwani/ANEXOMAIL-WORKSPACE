# WORKING NOW (auto snapshot before a compaction, 22 Nov 2026 20:41 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: No-incomplete-work law written everywhere + gate INCOMPLETE ADVANCE; desk-install build fix (contract inside crate)
NEXT STEP: his desk-install + desk-restart; his Control Plane address + key; D5a-5
HIS LAST WORD: Dashboard folder first
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## RESERVED BY HIS WORD 21 Nov 2026 07:5x PKT: TCP 127.0.0.1:4400 = ADMIN DESK (own Rust process `anexomail-desk`, loopback only; Caddy has the admindesk block since 21 Nov 07:51 PKT: reverse_proxy 127.0.0.1:4400, validated + reloaded; noth

## ADMIN DESK HTTP/3 (his fresh ss 21 Nov 2026 09:27 PKT, full `ss -ulnp` + ufw udp pasted): UDP 4400 was FREE (no listener, no ufw rule, outside the TURN 49152-65535 range) -> RESERVED for the Desk's own HTTP/3 (`anexomail-desk`, drop-in e

## Last 5 commits
- 6476741c 22 Nov 20:36 ledger line 79f0f952
- 79f0f952 22 Nov 20:36 Desk D5a-3 real HTTP/3 client + PostgreSQL integration test
- bebf54a1 22 Nov 20:30 ledger line c940ec13
- c940ec13 22 Nov 20:30 Working-now checkpoint 20:50
- a222d842 22 Nov 20:29 ledger line c21ae224

## Uncommitted files (half-done work if any)
MM CLAUDE.md
M  READ-FIRST-FOUNDER-LAW.md
M  admin-desk/BLUEPRINT-ADMIN-DESK.md
M  admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  admin-desk/scripts/desk-install.sh
A  admin-desk/server/contract/00-FOUNDER-TECH-RULE.md
A  admin-desk/server/contract/DESK-LOOKUP-CONTRACT.json
M  admin-desk/server/src/lookup.rs
M  anexochat/READ-FIRST-FOUNDER-LAW.md
M  anexochat/docs/READ-FIRST-FOUNDER-LAW.md
M  anexochat/packages/READ-FIRST-FOUNDER-LAW.md
M  anexochat/sql/READ-FIRST-FOUNDER-LAW.md
M  banned-countries/READ-FIRST-FOUNDER-LAW.md
M  docs/READ-FIRST-FOUNDER-LAW.md
M  docs/claude/AWAM-BLUEPRINT-ALPHABETIC-20NOV.md
M  docs/claude/BLUEPRINT-ABC-01NOV.md
M  docs/claude/DONE-DO-NOT-REPEAT.md
A  docs/claude/NO-INCOMPLETE-ADVANCE-LAW-22NOV.md
M  docs/claude/READ-FIRST-FOUNDER-LAW.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md
M  docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
M  docs/claude/admin-desk/scripts/desk-install.sh
A  docs/claude/admin-desk/server/contract/00-FOUNDER-TECH-RULE.md
A  docs/claude/admin-desk/server/contract/DESK-LOOKUP-CONTRACT.json
M  docs/claude/admin-desk/server/src/lookup.rs
M  docs/claude/admin-desk/state/WORKING-NOW.md
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/READ-FIRST-FOUNDER-LAW.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
M  docs/cursor-work/server/rules-gate.py
M  docs/packages/READ-FIRST-FOUNDER-LAW.md
M  docs/wire/READ-FIRST-FOUNDER-LAW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 server/routes/READ-FIRST-FOUNDER-LAW.md            |   1 +
 server/rust/READ-FIRST-FOUNDER-LAW.md              |   1 +
 server/storage/READ-FIRST-FOUNDER-LAW.md           |   1 +
 sql/READ-FIRST-FOUNDER-LAW.md                      |   1 +
 sql/editor/READ-FIRST-FOUNDER-LAW.md               |   1 +
 web-wasm/READ-FIRST-FOUNDER-LAW.md                 |   1 +
 web-wasm/src/READ-FIRST-FOUNDER-LAW.md             |   1 +
 90 files changed, 332 insertions(+), 76 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (a5cdafcac20c411e6c87add4b99d2f6a4554f9f4)
