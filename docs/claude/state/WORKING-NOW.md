# WORKING NOW (manual checkpoint, 21 Nov 2026 10:44 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: auth.rs + owner/real-account scripts pushed
NEXT STEP: his desk-install + desk-owner run, then login door + AD1b
HIS LAST WORD: real account method, gold codes
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
- 7a53170d 21 Nov 10:36 ledger line 70629973
- 70629973 21 Nov 10:36 checkpoint
- 0f2f08d9 21 Nov 10:36 ledger line d4bca7c6
- d4bca7c6 21 Nov 10:36 checkpoint
- d41e24a8 21 Nov 10:36 ledger line 79a3aef8

## Uncommitted files (half-done work if any)
 M admin-desk/scripts/desk-install.sh
 M admin-desk/server/Cargo.lock
 M admin-desk/server/Cargo.toml
 M admin-desk/server/src/main.rs
M  admin-desk/state/WORKING-NOW.md
 M docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md
 M docs/claude/admin-desk/scripts/desk-install.sh
 M docs/claude/admin-desk/server/Cargo.lock
 M docs/claude/admin-desk/server/Cargo.toml
 M docs/claude/admin-desk/server/src/main.rs
 M docs/claude/admin-desk/state/COMPACT-SAVE.md
 M docs/claude/admin-desk/state/PHASES.md
M  docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/founder/founder-commands.md
?? admin-desk/server/src/auth.rs
?? docs/claude/admin-desk/codes/
?? docs/claude/admin-desk/scripts/desk-business-account.sh
?? docs/claude/admin-desk/scripts/desk-owner.sh
?? docs/claude/admin-desk/server/src/auth.rs

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/admin-desk/server/src/main.rs      |   7 ++
 docs/claude/admin-desk/state/COMPACT-SAVE.md   |   2 +-
 docs/claude/admin-desk/state/PHASES.md         |   4 +-
 docs/claude/admin-desk/state/WORKING-NOW.md    |   2 +-
 docs/claude/state/WORKING-NOW.md               |  43 ++++----
 docs/claude/tech-contracts/CURRENT.md          |   3 +
 docs/cursor-work/founder/founder-commands.md   |   2 +
 16 files changed, 313 insertions(+), 34 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (9549f0d5f9a4105868df5e32e3fbf1f180767439)
