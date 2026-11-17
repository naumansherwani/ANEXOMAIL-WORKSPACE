# REPO MESS REPORT: Lovable vs Cursor vs Claude vs founder vs awam (17 Nov 2026 05:2x PKT)
Numbers from docs/awam/INVENTORY.csv (3414 files).

## What is what
| Era / owner | Where | Files | Status |
|---|---|---:|---|
| Lovable gold, awam | lovable-gold/awam | 823 | FROZEN copy, SHA-256 manifest, gate-protected. Keep |
| Lovable gold, founder | lovable-gold/founder | 48 | FROZEN copy of the old founder pages. Keep |
| Lovable live (awam site, Bun) | src, server/routes, server/lib, server/gates, server/mail, sql, anexochat | about 1,000 | still the LIVE awam site; replaced file by file in AW1 |
| Awam Rust | server/rust, server/awam-edge | 105 + 6 | the future awam backend; K5a edge live |
| Cursor era | .cursor/rules (14 IDE rules), docs/cursor-work (821: scripts, SQL E-files, harness, snapshots) | 835 | deploy scripts still USED; the rules are tooling |
| Claude era | docs/claude (224), CLAUDE.md, state files | 225 | current plans and laws |
| Founder | founder-web, server/founder, docs/claude/founder | about 500 | separate, never mixed |
| Shared | web-wasm (kernel), public, scripts | about 55 | one kernel for both |
| AI product | ai-product/ (new copy of 41 files) | 41 | separate home, live originals stay until the split |

## The mess, itemised
1. 41 old founder pages live INSIDE the awam src (app.founder*, founder.tsx, founderlogin.tsx, FounderBar, founder*.ts, 10 of them AI). They are Lovable leftovers; the real founder UI is founder-web. They stay (frozen copy exists in lovable-gold/founder) until the cutover removes them with his word.
2. 198 copies of 00-FOUNDER-TECH-RULE.md and 52 of READ-FIRST-FOUNDER-LAW.md sit in nearly every folder (his law: a copy in every folder). Intentional, not clutter; do not delete. Hide them from reading by using this index.
3. Four overlapping "master plan" generations: ONE-ORDER-27OCT, MASTER-BUILD-PLAN, BLUEPRINT-ABC-01NOV, MIGRATION-PHASES-24OCT/RUST-PRIMARY, GREEN-BOARD (21 Oct). Current truth = AWAM-BLUEPRINT-CLEAN-17NOV (awam) and the founder blueprint. Older ones are history; do not build from them.
4. docs/cursor-work/server holds 289 scripts: 262 awam (brain-*, caddy-*, attach-*), 20 founder. The awam ones deploy the CURRENT Bun site; keep until AW1.
5. Polar payment docs/rules: his word, Polar STAYS, no conflict.
6. AI files were mixed into awam src/server/sql and the founder pages: now collected in ai-product/ (copy). Live originals untouched so the site still builds.
7. .lovable (6 files) and .cursor/rules (14) are tooling, not code.
8. Corrected by him: awam is HTTP/3 with h2/1.1 fallback on his server; my earlier "HTTP/2 only" and "K5a only" wording were both wrong. K5b = the h3 side under our own Rust.

## Rules I followed (so nothing breaks)
No file was moved or deleted: gates, lanes, AWAM-INHERIT-MANIFEST.json and the hash chain read these paths. New tidiness = this index, ai-product/ copy, lanes updated.

## Safe next cleanups (each needs his word)
a) At cutover T: delete the live Bun awam files (copy stays in lovable-gold). b) Move the AI live files into ai-product/ when the AI product starts. c) Mark the old plan generations SUPERSEDED at their top. d) (Polar decided: stays.) AI files are NEVER deleted: used by the AI product from July 2027.
