# HANDOFF LIVE (printed by rules-read.py, the first command after every compaction / new chat). Written 13 Nov 2026 19:05 PKT. Update it with every step (rec.sh does the one-line parts; the STEP block below is edited by hand).

## STEP NOW = see the generated Q-SERIES STATE block at the bottom of this file (single source of truth: docs/claude/state/Q-STATE.jsonl, hash-chained; update it ONLY with `python3 docs/cursor-work/server/qstate.py start|done|defer <id> "<proof>"`).
- His rule for green (13 Nov 19:06): the advance technology CODE installed and proven on HIS SERVER is what counts. CORRECTION 19:11: I wrongly DEFERRED T3 (first real mail); he never said that. T3 stays a required step: fmail-intake-selftest.sh sends 3 real mails through Postfix itself (plain, EICAR, encrypted-zip stub), no outside sender needed.
- Phase order = the PLAN list in docs/cursor-work/server/qstate.py (Q1b-3 T4, Q1d, Q1b-4, Q3, MTA-STS/DANE, U1/U2, Q4, U5, Q1e).

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
- docs/cursor-work/server/qstate.py = the automatic state machine (hash-chained ledger, generates the block below, gate-verified, printed by the SessionStart hook in .claude/settings.json after every start/resume/compaction).
- docs/cursor-work/server/rec.sh "<ledger line>" "<CLAUDE.md line-1 text>" "<commit subject>" = updates founder-commands, both DONE ledgers, chat context, both PULL-COMMANDS, CURRENT.md, RESUME-POINT, CLAUDE.md line 1, runs lane/manifest syncs + rules-read + rules-gate, commits (Phase/Tech lines only) and pushes. Do NOT put the word GREEN in a ledger line unless it also says 'WIRED: YES / REAL: YES / TECH-LAW CHECKED' (gate fails). Do not add lines to the top of CLAUDE.md (the ONE BUILD gate reads its head).
- Server scripts written for Q1b-3 (all under docs/cursor-work/server/): fmail-intake-check.sh (read-only), fmail-intake-on.sh, fmail-intake-postfix.sh, fmail-intake-audit.sh (read-only), fmail-postfix-pq.sh, fmail-clamd-alerts.sh, fmail-intake-watch.sh (read-only). Rust+SPA install = founder-install.sh; SQL = sql-run.sh.
- Sandbox (recreate if /tmp is gone): cargo tests in a copy of server/founder (cp src/*.rs then cargo test --release, ~3 min full build), PG16 sandbox for SQL selftests (port 55432, db t167), Playwright harness for 390/820/1280 screenshots (NODE_PATH=/opt/npm-tools/node_modules, vite dev server restarted with --force after CSS edits).
- Live Chrome look: Claude in Chrome tab on https://founderworkspace.anexomail.com/#/mail ; compare live bundle (script src under /_cc/assets) with founder-web/dist before any green.

## FACTS OF HIS SERVER (13 Nov)
- Postfix 3.10.6 + OpenSSL 3.5.5, virtual_transport anexopipe (awam), transport_maps = hash:/etc/postfix/founder-transport with ONE line: the founder address -> lmtp:inet:127.0.0.1:18025. clamd on 127.0.0.1:3310 (+ socket clamav:clamav). Founder LMTP intake ON 127.0.0.1:18025 (env FMAIL_LMTP_BIND, FMAIL_CLAMD in /etc/anexomail/founder.env; backups *.pre-intake). Mail sender OFF (no FMAIL_SEND=on). opendkim 127.0.0.1:8891 (awam). Backups: /etc/postfix/main.cf.pre-pq, /etc/postfix/main.cf.pre-founder-intake, /etc/clamav/clamd.conf.pre-alerts.
- Founder bundle live = founder-web/dist (index-BKdnTGPQ.js at 13 Nov 04:00). Mail page tech: kernel WebTransport RPC (no fetch except /auth/refresh); live channel is SSE (open gap Q-live-wt, Q3).

<!--QSTATE-->
## Q-SERIES STATE (generated from docs/claude/state/Q-STATE.jsonl by docs/cursor-work/server/qstate.py: do not edit by hand)
NOW: Q1b3-T4 - SQL E171: scan state 'opaque'  [PostgreSQL RLS, append-only ledger, selftest + CHECK]
- [x] Q1b3-T1: Postfix inbound TLS X25519MLKEM768 first  (Postfix 3.10 + OpenSSL 3.5, ML-KEM-768 hybrid, TLS 1.3 AES-256-GCM)  PROOF: his output 13 Nov 18:5x: PQ client Negotiated TLS1.3 group X25519MLKEM768, classic X25519, default X25519MLKEM768; setting kept (c2b284fc..1b843b15)
- [x] Q1b3-T2: clamd AlertEncrypted + AlertExceedsMax  (ClamAV INSTREAM, fail-closed quarantine)  PROOF: his output 13 Nov 18:5x: clamd PONG ~10 s, EICAR FOUND, clean OK, Heuristics.Encrypted.Zip FOUND
- [x] Q1b3-T3: first real mail through the intake  (Postfix per-address LMTP RFC 2033, ClamAV, seal on arrival, ledger; end-to-end self-test mails sent by Postfix itself (NOT deferred, his order 19:11))  PROOF: all 3 selftest mails status=sent (250 2.0.0 stored) via Postfix; live Chrome: Inbox 1 (ledger anchor verified SHA-256, virus scan clean), Quarantine 2; found lane bug -> E171
- [>] Q1b3-T4: SQL E171: scan state 'opaque'  (PostgreSQL RLS, append-only ledger, selftest + CHECK)  PROOF: E171 + Rust opaque guard + UI verdict written; sandbox CHECK 5/5, selftest 9/0, cargo fmail_in 11 pass, bun 26 pass; waits his sql-run + founder-install
- [ ] Q1d-1: DKIM key from Compose + DNS TXT  (Ed25519 + RSA DKIM, passkey touch (mail.key))
- [ ] Q1d-2: FMAIL_SEND=on + real outgoing mail  (Rust Tokio SMTP, STARTTLS TLS 1.3 X25519MLKEM768, undo window, outgoing PQ TLS proof)
- [ ] Q1b4: SPF / DKIM / DMARC verdicts + trust ring (U3)  (Rust mail-auth, Framer Motion ring)
- [ ] Q3: attachments + live over WebTransport + 8-segment ring (U4)  (Rust Tokio WebTransport, Hetzner Storage Box, ClamAV, WASM kernel)
- [ ] Qtls: MTA-STS / DANE / TLS-RPT  (RFC 8461 / 7672 / 8460)
- [ ] U1U2: ledger proof pill + Touch-to-Unseal live proof (U1), PQC pill segment (U2)  (kernel SHA-256/Merkle verify, passkey touch, React 19 TS)
- [ ] Q4: kernel pqmail OpenPGP RFC 9980  (Rust WASM kernel ML-KEM-768 + X25519, ML-DSA-65 + Ed25519)
- [ ] U5: Who-can-read-this sheet, Ctrl K mail actions, light theme (approved)  (Radix Dialog, command palette, React 19 TS)
- [ ] Q1e: calendar E172-E173  (Rust + SQL RLS + React TS, same sealing)
chain head: 1cf0f09f08b96e74 (6 events)
<!--/QSTATE-->
