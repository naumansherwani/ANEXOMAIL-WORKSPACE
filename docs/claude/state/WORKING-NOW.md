# WORKING NOW (manual checkpoint, 25 Nov 2026 03:58 PKT) - read this FIRST after a compaction; it is where the work stopped
LAW: GATE IS THE FINAL AUTHORITY (his 24 Nov 2026 09:29 PKT): a commit happens ONLY when rules-gate.py approves; never cheat or loosen a gate; docs/claude/GATE-FINAL-AUTHORITY-LAW-24NOV.md
LAW: RULE 52 COMBO (his 24 Nov 2026 11:11 PKT): RFC 9421 + IETF WIMSE HTTP-signature (S signed calls), RFC 7489 (M mail identity), OWASP Logging (L) in EVERY phase of founder, awam and Desk; contract line RULE 52 COMBO: S= M= L=; docs/claude/RULE-52-COMBO-LAW-24NOV.md
DOING: T4e GREEN; web install has NO SQL (awam-sql.sh in SQL command); thin LTO build
NEXT STEP: his SQL line then WEB line; my live Chrome look; T4f, T4h
HIS LAST WORD: his 03:50/03:54 orders: founder-install model, no SQL in web
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
- a1a128df 25 Nov 03:39 ledger line 3ed095ff
- 3ed095ff 25 Nov 03:39 T4e fix tenant path in Control Plane
- 7fd24a11 25 Nov 03:22 ledger line d378ca2a
- d378ca2a 25 Nov 03:22 install rule final separate
- 7bff1f5b 25 Nov 03:20 ledger line 81106a36

## Uncommitted files (half-done work if any)
M  CLAUDE.md
M  admin-desk/INSTALL-SPLIT-RULE-25NOV.md
A  admin-desk/scripts/awam-sql.sh
M  admin-desk/scripts/cp-install.sh
M  admin-desk/scripts/desk-install.sh
M  admin-desk/scripts/desk-sql-install.sh
M  admin-desk/server/Cargo.toml
M  control-plane/Cargo.toml
M  docs/claude/TECH-LAW-GATE.json
M  docs/claude/admin-desk/INSTALL-SPLIT-RULE-25NOV.md
A  docs/claude/admin-desk/scripts/awam-sql.sh
M  docs/claude/admin-desk/scripts/cp-install.sh
M  docs/claude/admin-desk/scripts/desk-install.sh
M  docs/claude/admin-desk/scripts/desk-sql-install.sh
M  docs/claude/admin-desk/server/Cargo.toml
M  docs/claude/admin-desk/state/WORKING-NOW.md
 M docs/claude/state/WORKING-NOW.md
M  docs/cursor-work/server/DEPLOY-MANIFEST.txt

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/admin-desk/scripts/cp-install.sh       | 40 +------------
 docs/claude/admin-desk/scripts/desk-install.sh     | 14 -----
 docs/claude/admin-desk/scripts/desk-sql-install.sh |  5 +-
 docs/claude/admin-desk/server/Cargo.toml           |  5 +-
 docs/claude/admin-desk/state/WORKING-NOW.md        |  2 +
 docs/claude/state/WORKING-NOW.md                   | 40 +++++++------
 docs/cursor-work/server/DEPLOY-MANIFEST.txt        | 12 ++--
 18 files changed, 219 insertions(+), 137 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
> ## >>> 20 Nov 2026 09:58 PKT QC4 plan vs code matched (table in docs/claude/QC4-PLAN-20NOV.md): feature 7 DONE end to end (not installed), feature 3 data DONE, pure logic for 3-6 DONE+tested, screens for 1,2,3,4,5,6 = QC4b NOT in code. <<<
> ## >>> 20 Nov 2026 09:12 PKT HIS QC4 FEATURE LIST (7 features, his paste 09:09) is now verbatim in docs/claude/QC4-PLAN-20NOV.md and founder-commands.md; QC4a done (not installed), QC4b screen next <<<
> ## >>> 20 Nov 2026 09:55 PKT QC4a = DONE, WRITTEN AND TESTED, NOT INSTALLED (20 Nov 2026 09:55 PKT): cargo whole suite 559 passed 0 failed 0 filtered out (was 558, +1 test for References + Reply-To), pure-TS tests 474 pass 0 fail (sandbox runner, not a runtime), tsc clean, vite build OK (index-BcA
> ## >>> 20 Nov 2026 09:34 PKT QC4 SPLIT: QC4a server+data (Rust References + Reply-To in the open summary, mail_api, pure TS done) then QC4b screen (inline panel, Reply/Reply all/Forward buttons+keys, fold chip, selection reply, forward); ONE install. Rust edit waits on
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
WIP snapshot: refs/wip/last (681810f8f50398b6eb55d9b4ad26a16e7f97f3e2)
