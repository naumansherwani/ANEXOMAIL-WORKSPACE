# WORKING NOW (manual checkpoint, 22 Nov 2026 01:37 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: R3d stage B code done + tested; pull = desk-install
NEXT STEP: his desk-install paste, then my live Chrome Rule 52 proof; then R4-1 shell
HIS LAST WORD: his 01:31: real pull, phases tonight, desk rules on top
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
- d435d57e 22 Nov 01:25 ledger line e07c9674
- e07c9674 22 Nov 01:25 Desk: ON1-ON12 final plan
- cad6b1db 22 Nov 01:22 ledger line 9e3cf7b7
- 9e3cf7b7 22 Nov 01:22 Desk R3d stage A: signing + own kernel crate
- f9ac1bbb 22 Nov 01:14 ledger line be1cefbb

## Uncommitted files (half-done work if any)
 M CLAUDE.md
 M docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md
 M docs/claude/admin-desk/scripts/desk-install.sh
 M docs/claude/admin-desk/server/src/door.rs
 M docs/claude/admin-desk/server/src/main.rs
 M docs/claude/admin-desk/state/COMPACT-SAVE.md
 M docs/claude/admin-desk/state/PHASES.md
 M docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/founder/founder-commands.md
 D founder-web/dist-desk/00-FOUNDER-TECH-RULE.md
 D founder-web/dist-desk/assets/00-FOUNDER-TECH-RULE.md
 D founder-web/dist-desk/assets/desk-3KBasGG5.css
 D founder-web/dist-desk/assets/desk-BIgOCq0f.js
 M founder-web/dist-desk/desk.html
 D founder-web/dist-desk/kernel/00-FOUNDER-TECH-RULE.md
 M founder-web/src/desk/DeskPages.tsx
 M founder-web/src/desk/DeskSignIn.tsx
?? docs/claude/admin-desk/server/src/signed.rs
?? founder-web/dist-desk/assets/anexomail_desk_kernel_bg-DROILsBT.wasm
?? founder-web/dist-desk/assets/desk-CU2N64T3.css
?? founder-web/dist-desk/assets/desk-Dq2TTTlO.js
?? founder-web/src/desk/desk_kernel.ts
?? founder-web/src/desk/kernel/

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 .../dist-desk/assets/00-FOUNDER-TECH-RULE.md       |  5 ---
 founder-web/dist-desk/assets/desk-3KBasGG5.css     |  1 -
 founder-web/dist-desk/assets/desk-BIgOCq0f.js      |  9 -----
 founder-web/dist-desk/desk.html                    |  4 +-
 .../dist-desk/kernel/00-FOUNDER-TECH-RULE.md       |  5 ---
 founder-web/src/desk/DeskPages.tsx                 | 40 +++++++++++++++---
 founder-web/src/desk/DeskSignIn.tsx                |  8 ++--
 19 files changed, 109 insertions(+), 62 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (652a58e0fad2326b2a66ac37ad1e1b08ab579da3)
