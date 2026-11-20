# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 07:26 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3-2 E195 pushed, blueprint updated (9fa59f5d); starting QC3-3 Rust timeline door (Tokio/axum)
NEXT STEP: QC3-3 Rust door + cargo tests; then QC3-4 pure TS, QC3-5 UI via kernel RPC
HIS LAST WORD: his 07:23: tell which tech is in QC3 (answered)
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
- 0b2a26c0 20 Nov 07:26 QC3: E195 live on his server; tech per step written everywhere
- 423d480c 20 Nov 07:25 ledger line 85e7a7c2
- 85e7a7c2 20 Nov 07:25 QC3 checkpoint (WORKING-NOW)
- 9fa59f5d 20 Nov 07:21 ledger line 171c9315
- 171c9315 20 Nov 07:21 blueprint: QC3 in progress

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 19 +++----------------
 1 file changed, 3 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# >>> QC3 20 Nov 2026 07:30 PKT: E195 is on his server (70/0). QC3 TECHNOLOGY PER STEP (my explanation to him 20 Nov 07:23, his order 07:26 to write it word for word everywhere): PostgreSQL (SQL): DONE. E195 written, sandbox 70/0, and RUN ON HIS SERVER 20 Nov 07:26 PKT: his sql-run paste shows e195_
# >>> NOW: QC3 (20 Nov 2026 07:15 PKT): plan docs/claude/QC3-PLAN-20NOV.md, contract top of tech-contracts/CURRENT.md. Order: QC3-1 contract (done) -> QC3-2 SQL E195 -> QC3-3 Rust door -> QC3-4 pure + tests -> QC3-5 UI -> QC3-6 tests -> QC3-7 his sql-run + install + live look. <<<
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
WIP snapshot: refs/wip/last (8761ee49cc646cbc031d964398da630ea1bdbab2)
