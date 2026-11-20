# WORKING NOW (manual checkpoint, 20 Nov 2026 06:02 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: HOLD by his 06:02 word: QC2-B browser work STOPPED, nothing deleted, nothing new built; RichEditor.tsx parked (not imported anywhere)
NEXT STEP: WAIT his word: delete QC2-B and rebuild from scratch, or edit it step by step; QC2-A pull is his to run
HIS LAST WORD: his 06:02: hold QC2-B, ledger it
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
- c1dd3c6f 20 Nov 06:01 ledger line e1da4508
- e1da4508 20 Nov 06:01 5-min checkpoint: WORKING-NOW QC2-B in progress
- e914cfef 20 Nov 06:00 ledger line 9c4d59c3
- 9c4d59c3 20 Nov 06:00 QC2-B step 1: rich_pure, html send-target twin, signature/snippet api, Tiptap 3 dependency
- 88480a81 20 Nov 05:58 ledger line beb4a62d

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md
M  founder-web/package-lock.json
M  founder-web/package.json
M  founder-web/src/mail_api.ts
M  founder-web/src/mail_pure.ts
 D founder-web/src/rich_pure.test.ts
 D founder-web/src/rich_pure.ts

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md  |  29 +-
 founder-web/package-lock.json     | 611 --------------------------------------
 founder-web/package.json          |   6 -
 founder-web/src/mail_api.ts       |   7 -
 founder-web/src/mail_pure.ts      |   4 +-
 founder-web/src/rich_pure.test.ts |  22 --
 founder-web/src/rich_pure.ts      |  41 ---
 7 files changed, 12 insertions(+), 708 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
WIP snapshot: refs/wip/last (2381fff526f64e67b7e4e6e6dfca8ea99f331234)
