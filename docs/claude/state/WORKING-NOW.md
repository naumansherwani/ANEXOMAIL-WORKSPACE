# WORKING NOW (manual checkpoint, 23 Nov 2026 00:29 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: R3a2-dbsc code done (AD8 + dbsc.rs), responder done; committing both
NEXT STEP: his ONE desk-install + ad-auto + sign-in
HIS LAST WORD: his 00:22/00:25 orders
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
- baeaccce 22 Nov 23:39 ledger line 32747762
- 32747762 22 Nov 23:39 D5a-3b contract v2 and folder phases
- e12110bb 22 Nov 23:34 ledger line 0c4cbfb4
- 0c4cbfb4 22 Nov 23:34 D5a-3b schema paste and look 2
- 610119ff 22 Nov 22:42 ledger line ed337fb9

## Uncommitted files (half-done work if any)
M  CLAUDE.md
A  admin-desk/scripts/cp-install.sh
MM admin-desk/scripts/desk-install.sh
 M admin-desk/server/Cargo.lock
 M admin-desk/server/Cargo.toml
 M admin-desk/server/src/auth.rs
 M admin-desk/server/src/bridge.rs
 M admin-desk/server/src/door.rs
M  admin-desk/server/src/lookup.rs
MM admin-desk/server/src/main.rs
 M admin-desk/state/HANDOFF-22NOV.md
A  control-plane/00-FOUNDER-TECH-RULE.md
A  control-plane/Cargo.lock
A  control-plane/Cargo.toml
A  control-plane/contract/00-FOUNDER-TECH-RULE.md
A  control-plane/contract/DESK-LOOKUP-CONTRACT.json
A  control-plane/sql/00-FOUNDER-TECH-RULE.md
A  control-plane/sql/CP1.sql
A  control-plane/sql/checks/00-FOUNDER-TECH-RULE.md
A  control-plane/sql/checks/CP1-check.sql
A  control-plane/src/00-FOUNDER-TECH-RULE.md
A  control-plane/src/answer.rs
A  control-plane/src/core.rs
A  control-plane/src/db.rs
A  control-plane/src/h3srv.rs
A  control-plane/src/main.rs
A  control-plane/src/verify.rs
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
A  docs/claude/admin-desk/scripts/cp-install.sh
MM docs/claude/admin-desk/scripts/desk-install.sh
 M docs/claude/admin-desk/server/Cargo.lock
 M docs/claude/admin-desk/server/Cargo.toml
 M docs/claude/admin-desk/server/src/auth.rs
 M docs/claude/admin-desk/server/src/bridge.rs
 M docs/claude/admin-desk/server/src/door.rs
M  docs/claude/admin-desk/server/src/lookup.rs
MM docs/claude/admin-desk/server/src/main.rs
 M docs/claude/admin-desk/state/HANDOFF-22NOV.md
MM docs/claude/admin-desk/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/dist/index.html                        |    2 +-
 founder-web/src/system_brain.json                  |    6 +-
 lanes/ALL-FILES.csv                                |   20 +-
 lanes/docs.txt                                     |    1 +
 lanes/founder.txt                                  |    2 +-
 lanes/shared.txt                                   |   17 +
 lovable-gold/README.md                             |    2 +-
 57 files changed, 2541 insertions(+), 69 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (7e2885865260bbb32a69543bdee59bfa49b30e13)
