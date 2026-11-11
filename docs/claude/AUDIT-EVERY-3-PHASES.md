<!--TECHLAW-->
# RULE: AUTO AUDIT + AUTO LOOPHOLE FIX AFTER EVERY 3 PHASES (founder 11 Nov 2026 17:27, capitals)
After every THREE phases turn green: STOP new-phase work, run the audit, fix every loophole found WITHOUT ASKING, then give him the pull command(s). Counter = docs/claude/AUDIT-COUNTER.json (`phases_since_audit`); rules-gate FAILS when it is above 3, so a 4th phase cannot be committed before the audit.
## THE AUDIT (what Claude runs, in this order)
1. Technology: every phase green since the last audit vs its TECH LAW cell and CLAUDE.md line 18 (grep the code, not memory): listed technology present? else OPEN GAP in TECH-LAW-GATE.json.
2. Transport: TECH-RATCHET count (raw fetch/XHR/WebSocket) only down; Path card shows HTTP/3.
3. Security loopholes: authz on every new door (SQL service_role only, definer + pinned search_path, RLS), replay/nonce, rate limits, secrets never in the repo (public repo), error messages leak nothing, constant-time compares.
4. Ledgers: SQL hash chains verify (founder_*_verify), CHECK files all OK, posture functions true.
5. Mobile/tablet/laptop: 390 / 820 / 1200+ measured (UI phases), live bundle hash = repo build.
6. Tests: cargo test --release, bun test, tsc (only the known tracked errors), rules-gate 0 fail.
7. Records: chat context RESUME HERE, RESUME-POINT.md, CLOSE-THE-GAPS, DONE ledger, PULL-COMMANDS, tech-contracts/CURRENT.md.
Every loophole found is FIXED in the same pass (autofix), recorded as a line `AUDIT n: found X, fixed Y, TECH-LAW CHECKED`, then `phases_since_audit` is set to 0 and `last_audit` stamped.
## THEN THE PULL COMMAND: one numbered step at a time, one line, no quotes (sql-run.sh first, founder-install.sh second; awam pull only when shared code changed).
