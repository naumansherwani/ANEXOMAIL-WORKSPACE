# WORKING NOW (manual checkpoint, 25 Nov 2026 05:54 PKT) - read this FIRST after a compaction; it is where the work stopped
LAW: GATE IS THE FINAL AUTHORITY (his 24 Nov 2026 09:29 PKT): a commit happens ONLY when rules-gate.py approves; never cheat or loosen a gate; docs/claude/GATE-FINAL-AUTHORITY-LAW-24NOV.md
LAW: RULE 52 COMBO (his 24 Nov 2026 11:11 PKT): RFC 9421 + IETF WIMSE HTTP-signature (S signed calls), RFC 7489 (M mail identity), OWASP Logging (L) in EVERY phase of founder, awam and Desk; contract line RULE 52 COMBO: S= M= L=; docs/claude/RULE-52-COMBO-LAW-24NOV.md
DOING: his 05:53: I broke the fadm_ table pattern, fixed, legacy-rename with selftest and CHECK
NEXT STEP: his SQL line (install-line.sh sql)
HIS LAST WORD: his 05:46 order
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
- d994831e 25 Nov 05:49 ledger line 8128a123
- 8128a123 25 Nov 05:49 AD35 alone note
- 59762854 25 Nov 05:47 ledger line bcc6676e
- bcc6676e 25 Nov 05:47 editor error note
- 8a865ae1 25 Nov 05:35 ledger line aa922bb1

## Uncommitted files (half-done work if any)
M  CLAUDE.md
A  admin-desk/scripts/ad-legacy-rename.sh
M  admin-desk/scripts/desk-sql-install.sh
A  admin-desk/sql/checks/legacy-rename-check.sql
A  admin-desk/sql/editor/00-FOUNDER-TECH-RULE.md
A  admin-desk/sql/editor/AD34-editor.sql
A  admin-desk/sql/editor/AD35-editor.sql
A  admin-desk/sql/legacy-rename.sql
A  admin-desk/tests/make-editor-sql.sh
M  docs/claude/DONE-DO-NOT-REPEAT.md
M  docs/claude/RESUME-POINT.md
M  docs/claude/TECH-LAW-GATE.json
A  docs/claude/admin-desk/scripts/ad-legacy-rename.sh
M  docs/claude/admin-desk/scripts/desk-sql-install.sh
A  docs/claude/admin-desk/sql/checks/legacy-rename-check.sql
A  docs/claude/admin-desk/sql/editor/00-FOUNDER-TECH-RULE.md
A  docs/claude/admin-desk/sql/editor/AD34-editor.sql
A  docs/claude/admin-desk/sql/editor/AD35-editor.sql
A  docs/claude/admin-desk/sql/legacy-rename.sql
M  docs/claude/admin-desk/state/WORKING-NOW.md
A  docs/claude/admin-desk/tests/make-editor-sql.sh
M  docs/claude/founder/PULL-COMMANDS.md
M  docs/claude/state/HEARTBEAT.json
MM docs/claude/state/WORKING-NOW.md
M  docs/claude/tech-contracts/CURRENT.md
M  docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md
M  docs/cursor-work/DONE-DO-NOT-REPEAT.md
M  docs/cursor-work/founder/founder-commands.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt
M  docs/cursor-work/server/PULL-COMMANDS.md
R  founder-web/dist/assets/index-BySpq46c.js -> founder-web/dist/assets/index-CyjvvtcP.js
M  founder-web/dist/index.html
M  founder-web/src/system_brain.json
M  lanes/ALL-FILES.csv
M  lanes/docs.txt
M  lanes/founder.txt
M  lanes/shared.txt
M  lovable-gold/README.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/dist/index.html                        |    2 +-
 founder-web/src/system_brain.json                  |    8 +-
 lanes/ALL-FILES.csv                                |   16 +-
 lanes/docs.txt                                     |    7 +
 lanes/founder.txt                                  |    2 +-
 lanes/shared.txt                                   |    7 +
 lovable-gold/README.md                             |    2 +-
 38 files changed, 5403 insertions(+), 54 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (bd07ba675568a3fa27a9d9828098073d2fad471d)
