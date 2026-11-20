# WORKING NOW (manual checkpoint, 20 Nov 2026 05:54 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC2-A (founder) IN PROGRESS: E194 SQL written + PG17 33/33 + CHECK_E194; fmail_rich.rs (16 tests ok), fmail_rich_ep.rs, fmail_mime html wiring, main.rs routes, Cargo ammonia; cargo test of founder crate running in background (disk was full, cleaned target/incremental)
NEXT STEP: when cargo test passes: commit via rec.sh, then QC2-B browser (Tiptap, mail_pure sendTarget html, signature+snippet UI), then his sql-run E194 + founder-install
HIS LAST WORD: his 05:45: start QC2, only 2 sub-phases (A server, B browser), advance code and SQL
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
- 4d2d8e71 20 Nov 05:41 ledger line 70961f6e
- 70961f6e 20 Nov 05:41 Checkpoint: WORKING-NOW refreshed
- ccc7f488 20 Nov 05:37 ledger line cdc6b389
- cdc6b389 20 Nov 05:37 Record: QC2 is not Q3, order unchanged
- d83974a3 20 Nov 05:35 ledger line 9facc3ad

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md
 M docs/claude/tech-contracts/CURRENT.md
 M docs/cursor-work/founder/founder-commands.md
 M server/founder/Cargo.lock
 M server/founder/Cargo.toml
 M server/founder/src/fmail_mime.rs
 M server/founder/src/main.rs
?? docs/cursor-work/sql/CHECK_E194.sql
?? docs/cursor-work/sql/E194_founder_mail_signatures_snippets.sql
?? server/founder/src/fmail_rich.rs
?? server/founder/src/fmail_rich_ep.rs

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md             |  33 +++---
 docs/claude/tech-contracts/CURRENT.md        |   8 ++
 docs/cursor-work/founder/founder-commands.md |   2 +
 server/founder/Cargo.lock                    | 169 +++++++++++++++++++++++++++
 server/founder/Cargo.toml                    |   2 +
 server/founder/src/fmail_mime.rs             |  18 ++-
 server/founder/src/main.rs                   |   6 +
 7 files changed, 219 insertions(+), 19 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
4. Plain-text mode = per mail, NOT remembered (Gmail: per message, default stays formatted). Switching to plain text drops formatting and cannot be brought back, so ask "formatting will be removed" before switching.
WIP snapshot: refs/wip/last (5167facb1dfeecd4788b35331e274a4aac484e3a)
