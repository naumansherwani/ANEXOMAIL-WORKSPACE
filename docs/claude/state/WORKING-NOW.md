# WORKING NOW (auto snapshot before a compaction, 22 Nov 2026 01:25 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: Employee plan final ON1..ON12 (his answers); R3d stage B coding
NEXT STEP: R3d stage B: wasm build, deskCall, ping route, live proof
HIS LAST WORD: his 01:24 answers + 4 zero-trust locks
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
- cad6b1db 22 Nov 01:22 ledger line 9e3cf7b7
- 9e3cf7b7 22 Nov 01:22 Desk R3d stage A: signing + own kernel crate
- f9ac1bbb 22 Nov 01:14 ledger line be1cefbb
- be1cefbb 22 Nov 01:14 Desk: employee accounts plan
- 1feda4c5 22 Nov 01:13 ledger line b3d0dcfc

## Uncommitted files (half-done work if any)
 M admin-desk/BLUEPRINT-ADMIN-DESK.md
 M admin-desk/EMPLOYEE-ACCOUNTS-PLAN-22NOV.md
 M admin-desk/state/COMPACT-SAVE.md
 M admin-desk/state/PHASES.md
 M admin-desk/state/REMINDERS.md
 M docs/claude/BLUEPRINT-ABC-01NOV.md
 M docs/claude/admin-desk/BLUEPRINT-ADMIN-DESK.md
 M docs/claude/admin-desk/EMPLOYEE-ACCOUNTS-PLAN-22NOV.md
 M docs/claude/admin-desk/state/COMPACT-SAVE.md
 M docs/claude/admin-desk/state/PHASES.md
 M docs/claude/admin-desk/state/REMINDERS.md
 M docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
 M docs/cursor-work/founder/founder-commands.md
 D lovable-gold/MANIFEST.sha256
 D lovable-gold/README.md
 D lovable-gold/awam/ENDPOINTS-awam.csv
 D lovable-gold/awam/src/lib/network.ts
 D lovable-gold/awam/src/lib/notify.ts
 D lovable-gold/awam/src/lib/offline.ts
 D lovable-gold/awam/src/lib/org-export.ts
 D lovable-gold/awam/src/lib/org.ts
 D lovable-gold/awam/src/lib/outcomes.test.ts
 D lovable-gold/awam/src/lib/outcomes.ts
 D lovable-gold/awam/src/lib/overlap-focus.test.ts
 D lovable-gold/awam/src/lib/overlap.ts
 D lovable-gold/awam/src/lib/passkey-login.test.ts
 D lovable-gold/awam/src/lib/passkey.ts
 D lovable-gold/awam/src/lib/perf.ts
 D lovable-gold/awam/src/lib/places.test.ts
 D lovable-gold/awam/src/lib/places.ts
 D lovable-gold/awam/src/lib/plan-surface.test.ts
 D lovable-gold/awam/src/lib/plan-surface.ts
 D lovable-gold/awam/src/lib/plans.ts
 D lovable-gold/awam/src/lib/promise-engine.ts
 D lovable-gold/awam/src/lib/public-locale.ts
 D lovable-gold/awam/src/lib/pull-refresh.test.ts
 D lovable-gold/awam/src/lib/pull-refresh.ts
 D lovable-gold/awam/src/lib/pwa.ts
 D lovable-gold/awam/src/lib/recurrence.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 .../founder/src/routes/app.founder_.safety.tsx     |   40 -
 .../founder/src/routes/app.founder_.security.tsx   |   75 -
 .../founder/src/routes/app.founder_.settings.tsx   |   95 -
 .../founder/src/routes/founder.preview.tsx         |  303 --
 lovable-gold/founder/src/routes/founder.tsx        |   11 -
 lovable-gold/founder/src/routes/founder_.$.tsx     |   12 -
 lovable-gold/founder/src/routes/founderlogin.tsx   |   16 -
 208 files changed, 110 insertions(+), 42650 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (d7d521ac058ec034469a69e4ec64556f5df23a56)
