# WORKING NOW (manual checkpoint, 20 Nov 2026 04:34 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC1e D4A: manifest fix for org emoji route
NEXT STEP: AWAM TECH LAW: footer tech only; D4A pull again, then live look
HIS LAST WORD: his 14:46/14:47/14:53: WhatsApp look, 32 recents, founder and awam ledgers separate with time and date, keep everything in repo and context
RULE: finish THIS step first (uncommitted files below are the half-done code), then commit with rec.sh. ONE phase, ONE command at a time.

## LIVE PORTS OF HIS SERVER (docs/claude/state/PORTS-LIVE.md, his fresh ss paste; update it whenever he pastes a new one)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 03:30 PKT** (real clock). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## FOUNDER + other processes in the same list (never touch)
| Proto | Port | Process |
|---|---|---|

## Last 5 commits
- adf0e99d 20 Nov 04:32 ledger line 70d954d8
- 70d954d8 20 Nov 04:32 CLAUDE.md top line: awam tech law file path
- 61b9fa1d 20 Nov 04:32 ledger line 0c445068
- 0c445068 20 Nov 04:32 AWAM tech law: landing footer list is final; D4A gaps recorded
- 11a9c138 20 Nov 04:20 ledger line c0b8787e

## Uncommitted files (half-done work if any)
 M docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md
 M docs/claude/AWAM-TECH-LAW-FOOTER-20NOV.md
 M docs/claude/QC1E-LEDGER-AWAM-19NOV.md
 M docs/claude/state/WORKING-NOW.md
 M docs/cursor-work/server/DEPLOY-MANIFEST.txt
 M docs/cursor-work/server/manifest-sync.py

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/AWAM-BLUEPRINT-CLEAN-17NOV.md   |  1 +
 docs/claude/AWAM-TECH-LAW-FOOTER-20NOV.md   | 14 ++++++++++++++
 docs/claude/QC1E-LEDGER-AWAM-19NOV.md       |  1 +
 docs/claude/state/WORKING-NOW.md            | 26 +++++++++-----------------
 docs/cursor-work/server/DEPLOY-MANIFEST.txt |  1 +
 docs/cursor-work/server/manifest-sync.py    |  2 +-
 6 files changed, 27 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
<!--FEATURES-->
## FEATURES (auto, from docs/claude/features/*.json, full list docs/claude/FEATURES-LIVE.md; a missing feature is fixed BEFORE a commit, his 18 Nov 08:07 order)
QC1c: 44/44 written. NOT WRITTEN: 
<!--/FEATURES-->
## >>> 18 NOV 2026 07:2x PKT NOW (his order 07:16, update for Claude after any compaction): PHASES IN HAND = (1) QLIVE-c (package stream limits stream_tier.rs, live drafts SQL E188 [his sql-run OK], simulation test founder-web/sim, 2 real browser bugs fixed) and (2) Q-contacts-kernel (contacts@1 in 
## >>> 15 NOV 19:25 HIS ORDER: L closed. NEXT = Q SERIES until complete, THEN S5 (not before). Lovable codes migration phase written in docs/claude/FOUNDER-LOVABLE-MIGRATION-15NOV.md and docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md (preserve as written, advance technology, fix loopholes, polish). Q s
## >>> HANDOFF 14 NOV 07:10 (he is sleeping; read this first tomorrow): DONE and proven: KP3 step 5 GREEN, pre-connect GREEN by his order, clean blueprint (docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md), audit steps A+B GREEN, audit step C INSTALLED on his server (receipt 35, tests 394, listening aft
WIP snapshot: refs/wip/last (a82d9400a1e7cb3188283b15bb7bdbcb2207fdcb)
