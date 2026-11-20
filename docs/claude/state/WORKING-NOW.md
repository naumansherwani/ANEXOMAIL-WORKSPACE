# WORKING NOW (manual checkpoint, 20 Nov 2026 06:18 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC2-B built: RichEditor + MailRichPanel + MailCompose wiring + html frame (no dark); committing; then his ONE founder-install + my live Chrome
NEXT STEP: his founder-install paste, then live Chrome 390/820/1200 (Word paste, unfilled placeholder, plain switch)
HIS LAST WORD: his 06:15-06:17: advance HTML, existing cinematic UI untouched, no dark
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
- cbfd501c 20 Nov 06:09 ledger line 51c6ca9b
- 51c6ca9b 20 Nov 06:09 E194 OK on his server; blueprint status + compose chain updated
- e5ba3714 20 Nov 06:08 ledger line 08f701e9
- 08f701e9 20 Nov 06:08 5-min checkpoint: QC2-B on hold
- 99e47b1d 20 Nov 06:05 ledger line e8beab93

## Uncommitted files (half-done work if any)
 M docs/claude/AWAM-INHERIT-MANIFEST.json
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 D founder-web/dist/assets/index-Bmsm3onk.css
 D founder-web/dist/assets/index-cy5QuCZf.js
 M founder-web/dist/index.html
M  founder-web/package-lock.json
M  founder-web/package.json
 M founder-web/src/MailCompose.tsx
M  founder-web/src/mail_api.ts
M  founder-web/src/mail_pure.ts
A  founder-web/src/rich_pure.test.ts
AM founder-web/src/rich_pure.ts
 M server/founder/src/fmail_rich.rs
?? founder-web/dist/assets/index-CPxcjKLX.css
?? founder-web/dist/assets/index-DAbUcy3K.js
?? founder-web/src/MailRichPanel.tsx
?? founder-web/src/RichEditor.tsx
?? founder-web/src/richeditor.css

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 founder-web/package.json                   |   6 +
 founder-web/src/MailCompose.tsx            |  64 ++-
 founder-web/src/mail_api.ts                |   7 +
 founder-web/src/mail_pure.ts               |   4 +-
 founder-web/src/rich_pure.test.ts          |  22 ++
 founder-web/src/rich_pure.ts               |  41 ++
 server/founder/src/fmail_rich.rs           |  15 +-
 14 files changed, 790 insertions(+), 94 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
WIP snapshot: refs/wip/last (1be550a4e64bd839d4fa1220501adb01e041d8e8)
