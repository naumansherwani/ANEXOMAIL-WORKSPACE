# WORKING NOW (manual checkpoint, 20 Nov 2026 07:12 PKT) - read this FIRST after a compaction; it is where the work stopped
DOING: QC3 plan+contract pushed (a0df148e); writing QC3-2 SQL E195 timeline door
NEXT STEP: QC3-2 E195 + CHECK, then QC3-3 Rust door, QC3-4 pure, QC3-5 UI
HIS LAST WORD: his 07:09 order: best answers, plan, start
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
- 66ddfea0 20 Nov 07:12 ledger line a0df148e
- a0df148e 20 Nov 07:12 QC3 plan + contract (docs only)
- 01380ff5 20 Nov 07:05 ledger line b31237c4
- b31237c4 20 Nov 07:05 5-min checkpoint: QC3 waits his word
- 6b752a86 20 Nov 07:05 ledger line 6df808ef

## Uncommitted files (half-done work if any)
 M docs/claude/state/WORKING-NOW.md

## EDIT IN PROGRESS (docs/claude/state/EDIT-INTENT.md; empty = no edit was cut)

## Uncommitted size
 docs/claude/state/WORKING-NOW.md | 23 +++++------------------
 1 file changed, 5 insertions(+), 18 deletions(-)

## Q state
=== PHASE NOW (docs/claude/PHASE-NOW.md, open it first) ===
# >>> NOW: QC3 (20 Nov 2026 07:15 PKT): plan docs/claude/QC3-PLAN-20NOV.md, contract top of tech-contracts/CURRENT.md. Order: QC3-1 contract (done) -> QC3-2 SQL E195 -> QC3-3 Rust door -> QC3-4 pure + tests -> QC3-5 UI -> QC3-6 tests -> QC3-7 his sql-run + install + live look. <<<
# QC2 (FOUNDER) PHASE POINTS (FOUNDER; awam D4A used P1-P6, different thing), FROM WEB RESEARCH 20 Nov 2026 05:3x PKT (his order 05:30). ONE phase, no sub-phases; GREEN only when ALL points are WIRED: YES / REAL: YES / TECH-LAW CHECKED.
RESEARCH SOURCES (opened and read): Exclaimer embedded vs hosted signature images (https://exclaimer.com/email-signature-handbook/embedded-vs-hosted-images-in-email-signatures/); Superhuman Snippets help (https://help.superhuman.com/article/466-snippets); Cornell IT Gmail plain vs formatted (https:/
HIS 4 QUESTIONS, ANSWERS FROM RESEARCH (his word still needed, defaults below):
1. Only what he writes is rich: YES. Reply/forward of received HTML = QC4. Pasted HTML is untrusted (the ProseMirror XSS above): pin prosemirror-view >= 1.42.3, schema + paste rules in the browser, Rust ammonia as the second wall on the server.
2. Signature = text + links only in QC2. Reason: embedded (CID/base64) logo adds ~33 % size and shows as an attachment in Microsoft 365 / OWA, iOS Mail has stripped it; a hosted logo is blocked by default in many clients and needs the host online; guidance keeps a logo under 50 KB. Logo comes after 
3. Snippets: trigger `/name` (Superhuman uses `;`, we keep `/` and Ctrl+K), built-in variables {first_name} {my_name} {date}, plus any {custom_placeholder}; sending with an unfilled {placeholder} WARNS first (Superhuman does the same). Private snippets only (single founder; team sharing not needed).
WIP snapshot: refs/wip/last (22760f5fdc40c5dc0ae0606461c348d1b3114eaf)
