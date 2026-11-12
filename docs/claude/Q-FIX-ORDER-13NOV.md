# Q-series FIX ORDER (founder 13 Nov 2026 04:02 PKT): ONE phase at a time, in this order. Each step closes only with his output + my live Chrome look.

Never start a step while the one before it is open. Technology per step = the blueprint row + tech-contracts/CURRENT.md.

1. Q1b-3 intake ON (NOW). Tech: Rust Tokio LMTP RFC 2033 on loopback, ClamAV INSTREAM fail-closed, AES-256-GCM seal on arrival, ML-KEM-768 + X25519 for recipient_pq, passkey-touch reads. Code exists (fmail_in.rs, fmail_ep.rs). Written 13 Nov 04:15: docs/cursor-work/server/fmail-intake-check.sh (read-only preflight: free loopback port from his live ss + red-line file, ClamAV, Postfix per-address lookup, env). Next after his output: fmail-intake-on.sh (env + restart + rollback, Postfix untouched), then ONE per-address Postfix transport entry only with his haan (awam shares anexomail.com). Missing = server side: free loopback port (PORT RED LINE: fresh read-only `ss` list first), FMAIL_LMTP_BIND, clamd reachable, Postfix hook for noreply@/founder mailbox (needs his haan). Proof = a real mail from his other address appears in the Inbox, sealed, ledger row grows.
2. Q1d send REAL. DKIM key (Compose, passkey touch), DNS TXT, FMAIL_SEND=on, real test mail out.
3. Q1b-4 SPF/DKIM/DMARC verdicts (Rust mail-auth) + trust ring per thread.
4. Q3 attachments + mail live over WebTransport (closes Q-live-wt, Q-att-wt, Hetzner Storage Box, ClamAV on files).
5. Q-smtp-mtasts: MTA-STS, DANE, TLS-RPT.
6. Q4 kernel pqmail (OpenPGP RFC 9980).
7. Q1e calendar (E172-E173).
8. Pill gap: add PQC segment so the pill matches the Q1c row.

## UI gaps (his 13 Nov 04:08: 'yeh bhi UI fix karna hai, phase ki tarteeb mein add kero'). Each rides with the phase that feeds it; none is a UI redesign, all ADDITIVE (UI LAW), original LogoMark stays.
- U1 with step 1/2 (real mail exists): per-message Ledger Proof pill + Touch-to-Unseal gate LIVE-proven on a real message (code exists: proofChip, touch gates). Tech: Rust ledger + kernel SHA-256/Merkle verify, passkey touch.
- U2 pill: third segment "PQC sealed" when the mailbox key is ML-KEM-768+X25519 (E168 key registry, pq mailboxes), else "AES-256 sealed". Tech: React 19 TS, data from the mail doors.
- U3 with Q1b-4: trust ring per thread (SPF, DKIM, DMARC, virus scan), warm colour + empty chip on failure. Tech: Rust mail-auth verdicts, SVG ring, Framer Motion.
- U4 with Q3: live heartbeat over the kernel WebTransport session (no spinner, Framer Motion glides numbers) + 8-segment attachment ring (one Tokio stream per segment: speed + AES-256-GCM status). Tech: Rust WASM kernel, wtransport, Tokio.
- U5 (HIS HAAN 13 Nov 04:11, approved, additive): "Who can read this?" sheet (Radix Dialog; reads key registry + ledger), Ctrl K command palette (the founder shell search already exists: wire mail actions into it), light theme for the Mail page only if the founder shell has one.

## Step 1 facts read from his server (13 Nov 04:11 PKT): Postfix virtual_transport = anexopipe, transport_maps EMPTY, founder address = vmailbox entry; 127.0.0.1:18025 free; clamd on 127.0.0.1:3310 (+ socket clamav:clamav, unusable by the founder user -> TCP loopback); rspamd, postgrey, opendkim 127.0.0.1:8891 in the path.
Step 1b written: docs/cursor-work/server/fmail-intake-on.sh (service only; port re-check, clamd PONG, env backup, restart, listener proof, LMTP self-test, auto rollback). Step 1c (his haan needed): ONE per-address transport_maps entry -> lmtp:inet:127.0.0.1:18025, then a real mail from his other address.

## STEP 1 CHECKLIST (his 13 Nov 04:15 word: every point written in the phase so context loss cannot drop it)
- [x] 1a preflight read-only (fmail-intake-check.sh) - his output 04:11
- [x] 1b intake service ON - his output 04:15: LMTP ON 127.0.0.1:18025 loopback, ClamAV 127.0.0.1:3310, listener = anexomail-founder, healthz 200, self-test: founder RCPT 250, unknown 550. Postfix untouched. (Service proof only: NOT REAL until a real mail is stored.)
- [ ] 1c Postfix per-address entry (fmail-intake-postfix.sh, WRITTEN 04:20, needs his HAAN; main.cf backup, postfix check, auto rollback)
- [ ] 1d real mail from his other address appears in the Inbox sealed, ledger row grows, ClamAV verdict stored (not 'skipped')
- [ ] 1e live Chrome look 390/820/1200 with a real message: U1 (ledger proof pill, Touch-to-Unseal) proven on it
- Rollbacks: service = cp /etc/anexomail/founder.env.pre-intake /etc/anexomail/founder.env && systemctl restart anexomail-founder ; Postfix = cp /etc/postfix/main.cf.pre-founder-intake /etc/postfix/main.cf && systemctl reload postfix
