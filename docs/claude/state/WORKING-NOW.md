# WORKING NOW (manual checkpoint, 20 Nov 2026 07:05 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC2 live look done on his server (rich editor, paste clean, panel OK); alignment CSS fix pushed; QC3 discussion with him NOW (no code)
NEXT STEP: discuss QC3 details with him; his haan, then contract in CURRENT.md first; open: phone/tablet look by his phone, SPA update-after-install gap
HIS LAST WORD: his 07:03: next phase details + ledger
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
- 62af6f5b 20 Nov 06:58 ledger line 77c32271
- 77c32271 20 Nov 06:58 5-min checkpoint: QC2 waits founder-install
- 844dc2d3 20 Nov 06:51 ledger line cd37ee98
- cd37ee98 20 Nov 06:51 5-min checkpoint: QC2 waits founder-install
- 03e5f8df 20 Nov 06:50 ledger line 60962ec1

## Uncommitted files (half-done work if any)
 M docs/claude/CLOSE-THE-GAPS-07NOV.md
 M docs/claude/state/WORKING-NOW.md
 M founder-web/src/richeditor.css

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/CLOSE-THE-GAPS-07NOV.md |  1 +
 docs/claude/state/WORKING-NOW.md    | 25 +++++++------------------
 founder-web/src/richeditor.css      |  3 +++
 3 files changed, 11 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
WIP snapshot: refs/wip/last (e6d33dcb38ebbfd9d6ee05a310f5833a80ab13b4)
