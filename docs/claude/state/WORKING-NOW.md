# WORKING NOW (auto snapshot before a compaction, 20 Nov 2026 07:40 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3-3 Rust door done (cargo 558/0); QC3-4 presend_pure.ts + 50 tests done; starting QC3-5 UI (MailPresendBar, presets, timeline) via kernel RPC
NEXT STEP: QC3-5: api in mail_api.ts, MailPresendBar, schedule presets, MailTimeline in Sent detail, CSS, harness 390/820/1280 under real CSP
HIS LAST WORD: 5-min check + his 07:33 no filtered tests
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
- bc481060 20 Nov 07:40 QC3 status: install run, QC3-5 technology written
- ced1f86d 20 Nov 07:37 ledger line c5ce0679
- c5ce0679 20 Nov 07:37 QC3-4: presend_pure.ts + 50 tests (bun 454/0)
- 86b37e9d 20 Nov 07:35 ledger line 5863e28c
- 5863e28c 20 Nov 07:35 QC3-3: Rust + Tokio + axum delivery timeline doors (cargo 558/0)

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 19 +++----------------
 1 file changed, 3 insertions(+), 16 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# >>> QC3 20 Nov 2026 07:42 PKT: QC3-3 (Rust + Tokio + axum timeline doors, commit 86b37e9d, cargo 558/0) = HIS founder-install RUN at 07:40 (his word); his output paste NOT seen yet, so no saboot line (healthz, SPA, Ed25519) is recorded and QC3 is NOT green. QC3-4 (presend_pure.ts, 50 bun tests, bu
# >>> QC3 20 Nov 2026 07:30 PKT: E195 is on his server (70/0). QC3 TECHNOLOGY PER STEP (my explanation to him 20 Nov 07:23, his order 07:26 to write it word for word everywhere): PostgreSQL (SQL): DONE. E195 written, sandbox 70/0, and RUN ON HIS SERVER 20 Nov 07:26 PKT: his sql-run paste shows e195_
# >>> NOW: QC3 (20 Nov 2026 07:15 PKT): plan docs/claude/QC3-PLAN-20NOV.md, contract top of tech-contracts/CURRENT.md. Order: QC3-1 contract (done) -> QC3-2 SQL E195 -> QC3-3 Rust door -> QC3-4 pure + tests -> QC3-5 UI -> QC3-6 tests -> QC3-7 his sql-run + install + live look. <<<
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SO
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
WIP snapshot: refs/wip/last (50a4a7e5cc27bb5231de0116688097d5c8412a0b)
