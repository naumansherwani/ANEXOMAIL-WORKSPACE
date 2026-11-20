# WORKING NOW (manual checkpoint, 20 Nov 2026 07:56 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3-1..6 done/written; his installs running (no paste); QC3-7 live look open
NEXT STEP: on his paste: my live Chrome look; clear anexo-assets-v1; no mail sent
HIS LAST WORD: 5-min check 08:56
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
- 03fce32d 20 Nov 07:49 ledger line de5d8f70
- de5d8f70 20 Nov 07:49 Fix test-runner wording (sandbox tool, not a runtime) + checkpoint
- af5b89cd 20 Nov 07:47 ledger line 23680f1d
- 23680f1d 20 Nov 07:47 QC3 checkpoint (WORKING-NOW)
- c95c2069 20 Nov 07:47 ledger line bf27f077

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 21 ++++-----------------
 1 file changed, 4 insertions(+), 17 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# >>> QC3 20 Nov 2026 07:48 PKT: QC3 PROGRESS TABLE (his order 07:46, write it everywhere): QC3-1 contract = DONE. QC3-2 SQL E195 = DONE and RUN ON HIS SERVER (70/0, CHECK 7/7). QC3-3 Rust + Tokio + axum doors (fmail_timeline.rs) = WRITTEN, cargo 558/0, commit 86b37e9d, his install RUNNING now, past
# >>> QC3 20 Nov 2026 07:42 PKT: QC3-3 (Rust + Tokio + axum timeline doors, commit 86b37e9d, cargo 558/0) = HIS founder-install RUN at 07:40 (his word); his output paste NOT seen yet, so no saboot line (healthz, SPA, Ed25519) is recorded and QC3 is NOT green. QC3-4 (presend_pure.ts, 50 bun tests, bu
# >>> QC3 20 Nov 2026 07:30 PKT: E195 is on his server (70/0). QC3 TECHNOLOGY PER STEP (my explanation to him 20 Nov 07:23, his order 07:26 to write it word for word everywhere): PostgreSQL (SQL): DONE. E195 written, sandbox 70/0, and RUN ON HIS SERVER 20 Nov 07:26 PKT: his sql-run paste shows e195_
=== Q-SERIES HANDOFF (automatic, SessionStart hook). READ THIS FIRST, then work. ===
<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
NOW: QC1c - COMPOSE C1c: TLS lock on every chip from our own STARTTLS probe (SQL E187; discuss after QC1b)  [Rust Tokio SMTP STARTTLS rustls X25519MLKEM768 probe, PostgreSQL domain TLS facts]
WIP snapshot: refs/wip/last (f38d0d69883e243806d5c710311faee7cf8804a2)
