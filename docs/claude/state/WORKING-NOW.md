# WORKING NOW (manual checkpoint, 22 Nov 2026 08:25 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: D3 GREEN, D3b written
NEXT STEP: his install + look D3b, ping paste, D4 gate
HIS LAST WORD: his 08:23 word
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
- 39bd96d8 22 Nov 08:19 ledger line df98fe49
- df98fe49 22 Nov 08:19 Desk D3 live look, D3b proposal, D7 D9 D10 rows GREEN
- fb577c7d 22 Nov 08:19 ledger line 0f955b32
- 0f955b32 22 Nov 08:19 D3 live
- 330b6010 22 Nov 08:16 ledger line e9ca5b76

## Uncommitted files (half-done work if any)
 M CLAUDE.md
 M docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md
 M docs/claude/admin-desk/DESK-PHASES-22NOV.md
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 D founder-web/dist-desk/assets/desk-BvvohRXS.js
 M founder-web/dist-desk/desk.html
 M founder-web/src/desk/DeskCards.tsx
 M founder-web/src/desk/DeskPages.tsx
?? founder-web/dist-desk/assets/desk-CuFsRFmO.js
?? founder-web/src/desk/desk_trend_pure.test.ts
?? founder-web/src/desk/desk_trend_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/admin-desk/DESK-PHASES-22NOV.md    |   3 +-
 docs/claude/state/WORKING-NOW.md               |  34 ++++----
 docs/claude/tech-contracts/CURRENT.md          |   2 +
 founder-web/dist-desk/assets/desk-BvvohRXS.js  | 104 -------------------------
 founder-web/dist-desk/desk.html                |   2 +-
 founder-web/src/desk/DeskCards.tsx             |   5 +-
 founder-web/src/desk/DeskPages.tsx             |   4 +
 9 files changed, 31 insertions(+), 126 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (7152e51463a370d638d40fd991af34231c09a7bf)
