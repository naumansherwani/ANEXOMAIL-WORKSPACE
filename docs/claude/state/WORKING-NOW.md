# WORKING NOW (manual checkpoint, 23 Nov 2026 09:58 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: 1m-7 B6b code done, committing
NEXT STEP: his ad-auto (AD17) + desk-install, my Chrome look at Deliverability
HIS LAST WORD: his 09:55 order
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
- 99d32b28 23 Nov 09:52 ledger line 5f7f1cf3
- 5f7f1cf3 23 Nov 09:52 B6b docs first
- 5e086bac 23 Nov 09:37 ledger line b358e684
- b358e684 23 Nov 09:37 BL-04 advance tech line
- 91228d40 23 Nov 09:37 ledger line 28f6ddfa

## Uncommitted files (half-done work if any)
M  admin-desk/server/Cargo.lock
M  admin-desk/server/Cargo.toml
A  admin-desk/server/src/mailposture.rs
M  admin-desk/server/src/main.rs
A  admin-desk/sql/AD17.sql
A  admin-desk/sql/checks/AD17-check.sql
M  docs/claude/admin-desk/server/Cargo.lock
M  docs/claude/admin-desk/server/Cargo.toml
A  docs/claude/admin-desk/server/src/mailposture.rs
M  docs/claude/admin-desk/server/src/main.rs
A  docs/claude/admin-desk/sql/AD17.sql
A  docs/claude/admin-desk/sql/checks/AD17-check.sql
 M docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/server/rules-gate.py
R  founder-web/dist-desk/assets/desk-BCNJ4Ky0.js -> founder-web/dist-desk/assets/desk-DoEHb_-E.js
M  founder-web/dist-desk/desk.html
M  founder-web/src/desk/DeskCards.tsx
A  founder-web/src/desk/DeskMailPosture.tsx
A  founder-web/src/desk/desk_mailposture_pure.test.ts
A  founder-web/src/desk/desk_mailposture_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/cursor-work/server/rules-gate.py              |  18 ++
 .../assets/{desk-BCNJ4Ky0.js => desk-DoEHb_-E.js}  |  14 +-
 founder-web/dist-desk/desk.html                    |   2 +-
 founder-web/src/desk/DeskCards.tsx                 |   3 +-
 founder-web/src/desk/DeskMailPosture.tsx           |  45 ++++
 founder-web/src/desk/desk_mailposture_pure.test.ts |  13 +
 founder-web/src/desk/desk_mailposture_pure.ts      |  33 +++
 21 files changed, 1286 insertions(+), 37 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (cfb64128daa246f4465d8bba039396e1b8a6486d)
