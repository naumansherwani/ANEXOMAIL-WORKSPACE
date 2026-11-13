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
- [x] 1c Postfix per-address entry APPLIED by his run 04:20: transport_maps = hash:/etc/postfix/founder-transport, lookup = lmtp:inet:127.0.0.1:18025, other address empty (still anexopipe), postfix check passed (only the old warning: not owned by root /var/spool/postfix/etc/resolv.conf, not ours).
- [ ] 1d real mail from his other address appears in the Inbox sealed, ledger row grows, ClamAV verdict stored (not 'skipped')
- [ ] 1e live Chrome look 390/820/1200 with a real message: U1 (ledger proof pill, Touch-to-Unseal) proven on it
- Rollbacks: service = cp /etc/anexomail/founder.env.pre-intake /etc/anexomail/founder.env && systemctl restart anexomail-founder ; Postfix = cp /etc/postfix/main.cf.pre-founder-intake /etc/postfix/main.cf && systemctl reload postfix

## STEP 1 AUDIT 13 Nov 04:30 (his word: 'itna bara loophole', fix automatically). Researched: clamd.conf man page (AlertEncrypted default no, AlertExceedsMax default no, StreamMaxLength default 100M, MaxScanSize 400M), Postfix 3.10 notes (OpenSSL 3.5 forward compatibility; groups come from tls_eecdh_auto_curves, empty = OpenSSL decides).
LOOPHOLES FOUND IN OUR OWN CODE + FIXED (Rust, fmail_in.rs, tests 11 pass):
- L1 "skipped" (no scanner configured) went to the INBOX = fail OPEN. Now only "clean" reaches the inbox; skipped, error, infected = quarantine.
- L2 ClamAV trusts password-protected ZIP / PDF / Office as clean (AlertEncrypted default NO). New opaque_attachment(): encrypted ZIP (flag bit 0 in any local header), PDF /Encrypt, OLE EncryptedPackage/EncryptionInfo -> a clean verdict is not trusted, mail is quarantined (state error).
RESIDUAL (open, not green): encrypted 7z / RAR undetectable in Rust without unpacking -> clamd AlertEncrypted yes + AlertExceedsMax yes (clamd is shared with awam: needs his haan); scan state has no 'opaque' value (E171 could add it); a poisoned mail that crashes clamd lands in quarantine (safe); inbound Postfix TLS post-quantum depends on Postfix >= 3.10 + OpenSSL >= 3.5: measured by docs/cursor-work/server/fmail-intake-audit.sh (read-only, section C).
Not on his server until founder-install runs. After that: fmail-intake-audit.sh output, then his real test mail (1d).

## STEP 1 AUDIT RESULT from his server (13 Nov 04:35 PKT) - loopholes L1+L2 INSTALLED, rest OPEN for tomorrow evening
- founder-install 04:3x: 391 tests passed, build ok, healthz 200 => L1 (only clean reaches the inbox) + L2 (opaque_attachment) are LIVE.
- clamd read: StreamMaxLength 64M, MaxScanSize 100M, MaxFileSize 64M, MaxRecursion 16, ScanMail/ScanArchive true, AlertEncrypted + AlertExceedsMax NOT set (default no). EICAR straight to clamd = "Eicar-Test-Signature FOUND" (scanner works).
- Postfix 3.10.6 + OpenSSL 3.5.5 = capable of X25519MLKEM768, BUT tls_eecdh_auto_curves is pinned to "X25519 X448 prime256v1 secp384r1 secp521r1" (no ML-KEM), so the local PQ-only handshake FAILED (alert 40, group NULL). Inbound mail TLS is NOT post-quantum yet = OPEN GAP (TECH-LAW-GATE Q-smtp-mtasts line widened).
TOMORROW EVENING, in this order, each needs his haan because awam shares the Postfix + clamd:
 T1 Postfix: tls_eecdh_auto_curves = X25519MLKEM768 X25519 X448 prime256v1 secp384r1 secp521r1 (hybrid first, classic stays for old senders), backup + postfix check + reload + the same handshake test must show "Negotiated TLS1.3 group: X25519MLKEM768".
 T2 clamd: AlertEncrypted yes + AlertExceedsMax yes (closes encrypted 7z/RAR + zip-bombs), backup + restart + EICAR re-test; effect on awam: encrypted or over-limit attachments are flagged.
 T3 his real test mail from his other address (1d), then 1e live look 390/820/1200 + U1.
 T4 SQL E171: scan state 'opaque'.
Q1b-3 is NOT REAL until T3 is proven. Q1d (DKIM key + FMAIL_SEND) comes after, step 2.

## HIS BIG HAAN 13 Nov 18:40 PKT for T1, T2, T3, T4 (one by one, in order, each with advance technology + time). T1 started 18:40 (fmail-postfix-pq.sh written, waits his run). INBOUND-TLS-PQ-DONE is written here only after his output shows 'Negotiated TLS1.3 group: X25519MLKEM768'.

## T1 FIRST RUN 13 Nov 18:47 (his output): Postfix ACCEPTED the ML-KEM name: PQ-only client = "Negotiated TLS1.3 group: X25519MLKEM768", TLS_AES_256_GCM_SHA384. The classic-only handshake ALSO completed (TLSv1.3, AES-256-GCM) but my script asserted a group line that OpenSSL 3.5 s_client does not print for classic groups => the script rolled back a WORKING config (script bug, not a Postfix problem; main.cf is back to the old curves, backup main.cf.pre-pq kept). Fixed: test B now requires a completed TLS 1.3 handshake with AES-256-GCM, no alert, no ML-KEM given to a classic client. Re-run needed.

## T1 DONE 13 Nov 18:5x (his output, second run): INBOUND-TLS-PQ-DONE. Postfix 3.10.6 + OpenSSL 3.5.5, tls_eecdh_auto_curves = X25519MLKEM768 X25519 X448 prime256v1 secp384r1 secp521r1 KEPT on his server. A: PQ client = Negotiated TLS1.3 group X25519MLKEM768; B: classic client = Peer Temp Key X25519, TLS 1.3 AES-256-GCM; C: default client = X25519MLKEM768; 8: Postfix's own posttls-finger connected (its TLS line was cut by the script's head -4, so the OUTGOING-side TLS group is not shown: checked later with the real outgoing mail in Q1d). Watch real senders: journalctl -u postfix for TLS handshake failures. Q-in-tls-pq = ok in TECH-LAW-GATE.json.
## T2 STARTED 13 Nov 18:5x: docs/cursor-work/server/fmail-clamd-alerts.sh (clamd AlertEncrypted yes + AlertExceedsMax yes, backup, restart, PING wait, EICAR FOUND, clean OK, encrypted-ZIP stub, rollback). Waits his run.

## T2 DONE 13 Nov 18:5x (his output): clamd restart PONG after ~10 s; AlertEncrypted yes + AlertExceedsMax yes kept; EICAR = Eicar-Test-Signature FOUND; clean text = OK; encrypted ZIP stub = "Heuristics.Encrypted.Zip FOUND" (PROVEN). Backup /etc/clamav/clamd.conf.pre-alerts. Founder intake quarantines any ...FOUND. Encrypted 7z/RAR now flagged by clamd (not separately tested with a real 7z/RAR; the ZIP stub proves the alert path). Limit-exceeded alert is configured, not separately triggered.
## T3 STARTED 13 Nov 18:5x: fmail-intake-watch.sh (read-only: listener, Postfix delivery lines, sender TLS, founder log). He sends ONE plain mail from his other address to naumansherwani.founder@anexomail.com (mail 1 = expect Inbox, sealed, clean). Optional mail 2 = a password-protected zip attached (expect Quarantine). Then my live Chrome look 390/820/1200 + U1 (ledger proof pill, Touch-to-Unseal).
