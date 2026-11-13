# HANDOFF LIVE (printed by rules-read.py, the first command after every compaction / new chat). Written 13 Nov 2026 19:05 PKT. Update it with every step (rec.sh does the one-line parts; the STEP block below is edited by hand).

## STEP NOW (Q1b-3, his big haan 13 Nov 18:40 for T1-T4, one by one; full checklist = docs/claude/Q-FIX-ORDER-13NOV.md)
- T1 DONE (Postfix X25519MLKEM768 first, live). T2 DONE (clamd AlertEncrypted + AlertExceedsMax, EICAR/clean/encrypted-zip proven).
- T3 = HE sends ONE plain mail from his other address to naumansherwani.founder@anexomail.com; then he runs docs/cursor-work/server/fmail-intake-watch.sh (read-only); then my live Chrome look (390/820/1200, ledger proof pill U1, Touch-to-Unseal). His 18:59 output showed intake ON after the install but NO Postfix lines = no mail had arrived yet. Q1b-3 is NOT REAL until a real mail is stored sealed.
- T4 = SQL E171 ('opaque' scan state), sql-run.sh strictly by number, next free E171.
- THEN step 2: Q1d send REAL (DKIM key from Compose, DNS TXT fe/fr._domainkey, FMAIL_SEND=on, test mail out), then Q1b-4, Q3, MTA-STS/DANE, Q4, Q1e, UI U1-U5 (U5 approved).

## HIS STANDING RULES FOR THIS WORK (distilled; he is often angry, wants zero mistakes)
1. Roman Urdu, short, "Nauman bhai". ONE phase at a time, only that phase's technology; never list many phases. Commands to him: ONE line, pull command given the moment the commit is pushed.
2. Every reply ends with the Rule-70 table (Code | Technology | Phase) and a line "Abhi code mein NAHI: ...".
3. GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED" + proof from HIS server output AND my live Chrome look at 390/820/1200+. Never claim what was not seen live; say "code mein haan, live nahi dekha".
4. Advance technology law (CLAUDE.md line 18) = the listed technology per phase, never older. A listed item missing = open gap in TECH-LAW-GATE.json. Contract first (tech-contracts/CURRENT.md), then code.
5. Loopholes found by audit are fixed at once (his word 'auto fix'), researched on the web when needed, written in the repo.
6. NEVER rewrite git history or force-push without asking him first (I did once, he was angry). NO Co-Authored-By / noreply@... lines in commits (his 13 Nov 18:59 order); commit bodies keep only 'Phase:' and 'Tech:' lines.
7. Postfix / clamd / any shared server setting: only with his haan, backup + test + auto-rollback script, read-only preflight first. Port red line: fresh `ss` list before any listener.
8. UI LAW: never touch an existing screen without asking; Mail UI is new (ok); the ORIGINAL LogoMark stays on top of the Mail page; header = logo + ANEXOMAIL only.
9. No WebSocket, no Bun/Node in the server runtime. Sandbox tools are fine.

## TOOLS THAT LIVE IN THE REPO (so they survive)
- docs/cursor-work/server/rec.sh "<ledger line>" "<CLAUDE.md line-1 text>" "<commit subject>" = updates founder-commands, both DONE ledgers, chat context, both PULL-COMMANDS, CURRENT.md, RESUME-POINT, CLAUDE.md line 1, runs lane/manifest syncs + rules-read + rules-gate, commits (Phase/Tech lines only) and pushes. Do NOT put the word GREEN in a ledger line unless it also says 'WIRED: YES / REAL: YES / TECH-LAW CHECKED' (gate fails). Do not add lines to the top of CLAUDE.md (the ONE BUILD gate reads its head).
- Server scripts written for Q1b-3 (all under docs/cursor-work/server/): fmail-intake-check.sh (read-only), fmail-intake-on.sh, fmail-intake-postfix.sh, fmail-intake-audit.sh (read-only), fmail-postfix-pq.sh, fmail-clamd-alerts.sh, fmail-intake-watch.sh (read-only). Rust+SPA install = founder-install.sh; SQL = sql-run.sh.
- Sandbox (recreate if /tmp is gone): cargo tests in a copy of server/founder (cp src/*.rs then cargo test --release, ~3 min full build), PG16 sandbox for SQL selftests (port 55432, db t167), Playwright harness for 390/820/1280 screenshots (NODE_PATH=/opt/npm-tools/node_modules, vite dev server restarted with --force after CSS edits).
- Live Chrome look: Claude in Chrome tab on https://founderworkspace.anexomail.com/#/mail ; compare live bundle (script src under /_cc/assets) with founder-web/dist before any green.

## FACTS OF HIS SERVER (13 Nov)
- Postfix 3.10.6 + OpenSSL 3.5.5, virtual_transport anexopipe (awam), transport_maps = hash:/etc/postfix/founder-transport with ONE line: the founder address -> lmtp:inet:127.0.0.1:18025. clamd on 127.0.0.1:3310 (+ socket clamav:clamav). Founder LMTP intake ON 127.0.0.1:18025 (env FMAIL_LMTP_BIND, FMAIL_CLAMD in /etc/anexomail/founder.env; backups *.pre-intake). Mail sender OFF (no FMAIL_SEND=on). opendkim 127.0.0.1:8891 (awam). Backups: /etc/postfix/main.cf.pre-pq, /etc/postfix/main.cf.pre-founder-intake, /etc/clamav/clamd.conf.pre-alerts.
- Founder bundle live = founder-web/dist (index-BKdnTGPQ.js at 13 Nov 04:00). Mail page tech: kernel WebTransport RPC (no fetch except /auth/refresh); live channel is SSE (open gap Q-live-wt, Q3).
