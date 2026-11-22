# WORKING NOW (manual checkpoint, 23 Nov 2026 02:14 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1i D5a-5 code + tests + audit DONE, committed; waits his desk-install then my Chrome look (F11)
NEXT STEP: his desk-install, then my live Chrome look, then 1i GREEN, then 1j
HIS LAST WORD: his 02:07 order
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
- 0bc1bfc8 23 Nov 02:08 ledger line 327ceebf
- 327ceebf 23 Nov 02:08 1i plan and list
- fbea1b8d 23 Nov 02:03 ledger line aff35c7c
- aff35c7c 23 Nov 02:03 Order lock
- 1fd877b7 23 Nov 01:54 ledger line 8df10397

## Uncommitted files (half-done work if any)
 M admin-desk/D5A5-FAIL-CLOSED-LIST-23NOV.md
 M admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M admin-desk/FOLDER-PHASES-22NOV.md
 M admin-desk/kernel/src/lib.rs
 M admin-desk/kernel/src/wire.rs
 M admin-desk/server/src/lookup.rs
 M docs/claude/admin-desk/D5A5-FAIL-CLOSED-LIST-23NOV.md
 M docs/claude/admin-desk/DESK-D-SERIES-BLUEPRINT-22NOV.md
 M docs/claude/admin-desk/FOLDER-PHASES-22NOV.md
 M docs/claude/admin-desk/kernel/src/lib.rs
 M docs/claude/admin-desk/kernel/src/wire.rs
 M docs/claude/admin-desk/server/src/lookup.rs
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 D founder-web/dist-desk/assets/anexomail_desk_kernel_bg-Lgal3fHB.wasm
 D founder-web/dist-desk/assets/desk-CaheKM8J.js
 M founder-web/dist-desk/desk.html
 M founder-web/src/desk/desk_kernel.ts
 M founder-web/src/desk/kernel/anexomail_desk_kernel.d.ts
 M founder-web/src/desk/kernel/anexomail_desk_kernel.js
 M founder-web/src/desk/kernel/anexomail_desk_kernel_bg.wasm
 M founder-web/src/desk/kernel/anexomail_desk_kernel_bg.wasm.d.ts
?? founder-web/dist-desk/assets/anexomail_desk_kernel_bg-pHx6Jilq.wasm
?? founder-web/dist-desk/assets/desk-C-GRp42D.js
?? founder-web/src/desk/desk_lookup_pure.test.ts
?? founder-web/src/desk/desk_lookup_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/dist-desk/assets/desk-CaheKM8J.js      | 105 -------------
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/desk_kernel.ts                |  23 ++-
 .../src/desk/kernel/anexomail_desk_kernel.d.ts     |   7 +
 .../src/desk/kernel/anexomail_desk_kernel.js       |  51 +++++++
 .../src/desk/kernel/anexomail_desk_kernel_bg.wasm  | Bin 117016 -> 120010 bytes
 .../desk/kernel/anexomail_desk_kernel_bg.wasm.d.ts |   1 +
 22 files changed, 598 insertions(+), 177 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (41eb500d6aa8ae115da1fcfc76beb9a4ba99803c)
