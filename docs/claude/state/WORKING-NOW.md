# WORKING NOW (manual checkpoint, 23 Nov 2026 05:01 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: SQL files zero-padded; 1l installed on his server (AD10 CHECK OK, 3 PROOF SAME), my Chrome look next
NEXT STEP: Chrome look: create TEST escalation, then 1l GREEN
HIS LAST WORD: his order: AD10 sorted after AD9, save context
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
- 446f959a 23 Nov 04:48 ledger line 3c87ed51
- 3c87ed51 23 Nov 04:48 1l D5c Escalate code
- 988153f9 23 Nov 04:36 ledger line 8f1f5669
- 8f1f5669 23 Nov 04:36 1l research + contract before code
- d23a5a2e 23 Nov 04:30 ledger line f4afe900

## Uncommitted files (half-done work if any)
 M admin-desk/gates/DESK-FEATURES.json
 M admin-desk/scripts/gen-pkg-seed.py
 D admin-desk/sql/AD1.sql
 D admin-desk/sql/AD1/00-FOUNDER-TECH-RULE.md
 D admin-desk/sql/AD1/README.md
 D admin-desk/sql/AD1b.sql
 D admin-desk/sql/AD1c.sql
 D admin-desk/sql/AD2.sql
 D admin-desk/sql/AD3.sql
 D admin-desk/sql/AD4.sql
 D admin-desk/sql/AD4b.sql
 D admin-desk/sql/AD5.sql
 D admin-desk/sql/AD6.sql
 D admin-desk/sql/AD6b.sql
 D admin-desk/sql/AD6c.sql
 D admin-desk/sql/AD6d.sql
 D admin-desk/sql/AD7.sql
 D admin-desk/sql/AD8.sql
 D admin-desk/sql/AD9.sql
 D admin-desk/sql/AD9b.sql
 M admin-desk/sql/README.md
 D admin-desk/sql/checks/AD1-check.sql
 D admin-desk/sql/checks/AD1b-check.sql
 D admin-desk/sql/checks/AD1c-check.sql
 D admin-desk/sql/checks/AD2-check.sql
 D admin-desk/sql/checks/AD3-check.sql
 D admin-desk/sql/checks/AD4-check.sql
 D admin-desk/sql/checks/AD4b-check.sql
 D admin-desk/sql/checks/AD5-check.sql
 D admin-desk/sql/checks/AD6-check.sql
 D admin-desk/sql/checks/AD6b-check.sql
 D admin-desk/sql/checks/AD6c-check.sql
 D admin-desk/sql/checks/AD6d-check.sql
 D admin-desk/sql/checks/AD7-check.sql
 D admin-desk/sql/checks/AD8-check.sql
 D admin-desk/sql/checks/AD9-check.sql
 D admin-desk/sql/checks/AD9b-check.sql
 M admin-desk/sql/checks/README.md
 M admin-desk/tools/gen-ad9.py
 M docs/claude/admin-desk/gates/DESK-FEATURES.json

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/admin-desk/sql/checks/AD7-check.sql    |  15 -
 docs/claude/admin-desk/sql/checks/AD8-check.sql    |  14 -
 docs/claude/admin-desk/sql/checks/AD9-check.sql    |  12 -
 docs/claude/admin-desk/sql/checks/AD9b-check.sql   |   8 -
 docs/claude/admin-desk/sql/checks/README.md        |   2 +-
 docs/claude/admin-desk/tools/gen-ad9.py            |   6 +-
 docs/claude/state/WORKING-NOW.md                   |  64 +-
 79 files changed, 65 insertions(+), 7293 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (2d20441cae3efcd933e9513f00cfda7825f6c89e)
