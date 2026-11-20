# WORKING NOW (manual checkpoint, 20 Nov 2026 05:31 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC2 points written, waits his word on 4 answers
NEXT STEP: his word, then P1 contract in CURRENT.md
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
- badb0547 20 Nov 05:28 ledger line 2e18baf1
- 2e18baf1 20 Nov 05:28 QC2 plan written for discussion, WORKING-NOW and ledgers updated
- 885a6399 20 Nov 05:21 ledger line a14e8248
- a14e8248 20 Nov 05:21 Package plan, R3 Mail Desk reminder, founder QC status by his word
- d64ec75b 20 Nov 05:13 ledger line 44fffdec

## Uncommitted files (half-done work if any)
 M docs/claude/PHASE-NOW.md
 M docs/claude/QC1E-LEDGER-FOUNDER-19NOV.md
 M docs/claude/QC2-PLAN-20NOV.md
 M docs/claude/state/WORKING-NOW.md
 M docs/cursor-work/server/DEPLOY-MANIFEST.txt

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/PHASE-NOW.md                    | 10 ++++++++++
 docs/claude/QC1E-LEDGER-FOUNDER-19NOV.md    |  1 +
 docs/claude/QC2-PLAN-20NOV.md               | 10 ++++++++++
 docs/claude/state/WORKING-NOW.md            | 25 ++++++++-----------------
 docs/cursor-work/server/DEPLOY-MANIFEST.txt |  5 +++--
 5 files changed, 32 insertions(+), 19 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# QC2 (FOUNDER) PHASE POINTS, FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
WIP snapshot: refs/wip/last (3c614595f16894b41ef540ca93d609dc4d7a3457)
