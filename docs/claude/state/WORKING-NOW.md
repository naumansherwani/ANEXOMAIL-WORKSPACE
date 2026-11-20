# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 05:28 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC2 PLAN written (docs/claude/QC2-PLAN-20NOV.md), discussing with him; no code yet
NEXT STEP: his answers to the 4 questions in QC2-PLAN-20NOV.md, then contract in CURRENT.md, then SQL, Rust, browser
HIS LAST WORD: his 05:27: QC2 is ONE phase, no sub-phases, all of QC2 to QC8 must be GREEN
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
- 2e18baf1 20 Nov 05:28 QC2 plan written for discussion, WORKING-NOW and ledgers updated
- 885a6399 20 Nov 05:21 ledger line a14e8248
- a14e8248 20 Nov 05:21 Package plan, R3 Mail Desk reminder, founder QC status by his word
- d64ec75b 20 Nov 05:13 ledger line 44fffdec
- 44fffdec 20 Nov 05:13 Record PRO done and only Basic, Business, Business Pro remain (his words)

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 18 ++----------------
 1 file changed, 2 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
<!--FEATURES-->
## FEATURES (auto, from docs/claude/features/*.json, full list docs/claude/FEATURES-LIVE.md; a missing feature is fixed BEFORE a commit, his 18 Nov 08:07 order)
QC1c: 44/44 written. NOT WRITTEN: 
<!--/FEATURES-->
## >>> 18 NOV 2026 07:2x PKT NOW (his order 07:16, update for Claude after any compaction): PHASES IN HAND = (1) QLIVE-c (package stream limits stream_tier.rs, live drafts SQL E188 [his sql-run OK], simulation test founder-web/sim, 2 real browser bugs fixed) and (2) Q-contacts-kernel (contacts@1 in 
## >>> 15 NOV 19:25 HIS ORDER: L closed. NEXT = Q SERIES until complete, THEN S5 (not before). Lovable codes migration phase written in docs/claude/FOUNDER-LOVABLE-MIGRATION-15NOV.md and docs/claude/AWAM-LOVABLE-MIGRATION-15NOV.md (preserve as written, advance technology, fix loopholes, polish). Q s
## >>> HANDOFF 14 NOV 07:10 (he is sleeping; read this first tomorrow): DONE and proven: KP3 step 5 GREEN, pre-connect GREEN by his order, clean blueprint (docs/claude/FOUNDER-BLUEPRINT-CLEAN-14NOV.md), audit steps A+B GREEN, audit step C INSTALLED on his server (receipt 35, tests 394, listening aft
WIP snapshot: refs/wip/last (b2cad07f1545f8976f0e61b460df329fe06fa1b2)
