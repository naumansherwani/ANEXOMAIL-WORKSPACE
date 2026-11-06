# START HERE after a compaction or a new chat (updated 6 Nov 2026 20:30 PKT, founder order 20:00 "rules her cheese top pe rakho")

## 0. Who and how
Nauman Sherwani = founder and chairman, Asia/Karachi. Talk Roman Urdu, "Aap" / "Nauman bhai", short. He gets angry at stale, repeated or missed things: fix directly, never hand him a list of problems. Never fake GREEN (GREEN = his pasted server output + my own Chrome look). Never skip a letter. ONE phase at a time. Founder code is SUPER ADVANCED, SQL above that. No mock data anywhere.

## 1. Read in this order (10 minutes)
1. `AGENTS.md` top blocks + Rules 70-74 (Rule 70 = every reply ends with the technology table + a line "Abhi code mein NAHI: ..."; Rule 73 lanes; Rule 74 pinpoint: open `lanes/FOUNDER-INDEX.md` first, never grep the repo).
2. `docs/claude/founder/CODES/00-README-RULES.md` (FC1-FC42).
3. `docs/claude/BLUEPRINT-ABC-01NOV.md`: the GREEN LEDGER table at the top + the letter order.
4. `docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` (line 13 = stamp, bottom = newest checkpoint) and the top of `docs/cursor-work/founder/founder-commands.md`.
5. `docs/claude/founder/PULL-COMMANDS.md` bottom block (what he must run next). Rule 24: at most 1-2 pull points per reply; Rule 46: all pull commands in order SQL, CHECK, Rust+SPA, Caddy, Web.

## 2. Process rules that bite
- Paste his order verbatim into `docs/cursor-work/founder/founder-commands.md` BEFORE working.
- Before a commit: `python3 lanes/lane-sync.py`; `git add -A`; `manifest-verify.py | grep PURANI | awk '{print $2}' | xargs python3 manifest-sync.py` (pass files explicitly), lane-sync again, twice; `manifest-verify.py` = 0 bad; `python3 docs/cursor-work/server/rules-gate.py --staged` (needs a DONE-DO-NOT-REPEAT.md line when code changes, and a PULL-COMMANDS note when the server changes).
- Commit trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01M4RARCpqskLVTeA3hiUMVX`. Push to origin main (the repo moved note in the output is harmless).
- Pull command form: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>) [args] 2>&1 | tail -N` (`sql-run.sh <name> [CHECK_name]`, `founder-install.sh`, `founder-device.sh approve <CODE>`, `pull.sh`).
- Sandbox: scratch Postgres on port 5546 (start: `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pg5546 -o '-p 5546 -k /tmp' -l /tmp/pg5546.log start"`); Rust offline test via scratchpad `fb/sync.sh` then `cargo test --offline` in `fb/founder` (about 1 minute); SPA `cd founder-web && bun test && npx tsc --noEmit && npx vite build && bash precompress.sh`.
- Founder-side code stays ON HOLD until he says "go" (CLAUDE.md top line) unless he orders the specific fix.

## 3. Decisions that are LOCKED (never re-offer)
- C1 Polar API token is DROPPED (three times). Polar goes through the two existing webhook endpoints + a hash-chained ledger, in letter O. Never offer `founder-polar.sh` or a token.
- ANEXOChat chart is reality: per file Business 500 MB / Business Pro 1.5 GB / Business Premium 4 GB; monthly per user 50 / 150 / 400 GB (100 sends); 80% warn, 100% throttle, NEVER block; users 20 / 570 / **21,000 cap for Premium (NOT unlimited; only the PRICE page says Unlimited)**. No AI for awam in ANEXOChat (founder only, on demand). SQL: `anexochat/sql/phase13_15_file_engine.sql` + `phase61_file_limits_quota.sql` + `CHECK_phase61.sql` (GREEN on his server 3 Nov 13:48).
- Business Pro is NEVER unlimited (570 users).
- Landing footer "Built with" is his wording: never touch it; MoQ stays "planned" until letter M is GREEN.
- Device trust: every browser/profile is its own device and is approved once (`founder-device.sh approve <CODE>`). Do not switch that off.
- `FOUNDER_PASSWORD` code delete only on his word. T3 two-key proof only when Control (S) arrives.

## 4. STATE (6 Nov 2026 20:30 PKT)
GREEN: A, B, D, E (L5 parked), F, G, H, I, J1-J5, J hardware E142, J6 on desktop, K1, K2, K3, ANEXOChat SQL 13-15 + 61.
Today: the founder phone (Android) was approved (19:45). Two bugs found from his screenshots and fixed in code: (1) exchange rate-limit was per ACCOUNT, now per account+device (`ftoken::exchange_key`); (2) the lock was checked BEFORE approval, so an approved phone still showed "Too many device attempts": now a lock never blocks an approved device (`ftoken::exchange_blocked`). Fix (1) is on his server (install 19:42); fix (2) + device-label names (`devicelabel.ts`) wait for his `founder-install.sh` (PULL-COMMANDS bottom block).
His honest "Not connected" tiles on Bridge/Finance are real (sources arrive in letters O, P, Q); they are not a bug.

## 5. ORDER (no letter skipped)
1. His `founder-install.sh` (the last block of PULL-COMMANDS) -> phone banner gone.
2. J6 real-phone proof (phone: Settings > Phone alerts > Add, allow notifications; I send the test; I read the receipt in the ledger) -> J6 fully GREEN.
3. J8 vault lease (no operator needed; only after his "go").
4. K4 AES-256 on :443 (also fixes the `/_cc` 404 on :8443), K5 awam T256-2, K6 WebTransport `wtransport` (UDP open), K7 DBSC.
5. L Look (Framer Motion + GSAP, Three.js WebGPU globe; CINEMATIC stays pixel-equal), M MoQ own Rust relay.
6. N Bun cutover begins, O Polar ledger (C1 emerges), P, Q (awam Mail/Calendar), R (+R3 Admin > Mail Desk), S, T (Bun off), U, V. J7/J9 only when he names an operator/aggregator.
Open words from him: Premium storage number (1 TB copied from Business Pro, needs his word), Premium plan card in `plans.ts`.
