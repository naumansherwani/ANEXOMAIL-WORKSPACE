# Q-series FIX ORDER (founder 13 Nov 2026 04:02 PKT): ONE phase at a time, in this order. Each step closes only with his output + my live Chrome look.

Never start a step while the one before it is open. Technology per step = the blueprint row + tech-contracts/CURRENT.md.

1. Q1b-3 intake ON (NOW). Tech: Rust Tokio LMTP RFC 2033 on loopback, ClamAV INSTREAM fail-closed, AES-256-GCM seal on arrival, ML-KEM-768 + X25519 for recipient_pq, passkey-touch reads. Code exists (fmail_in.rs, fmail_ep.rs). Missing = server side: free loopback port (PORT RED LINE: fresh read-only `ss` list first), FMAIL_LMTP_BIND, clamd reachable, Postfix hook for noreply@/founder mailbox (needs his haan). Proof = a real mail from his other address appears in the Inbox, sealed, ledger row grows.
2. Q1d send REAL. DKIM key (Compose, passkey touch), DNS TXT, FMAIL_SEND=on, real test mail out.
3. Q1b-4 SPF/DKIM/DMARC verdicts (Rust mail-auth) + trust ring per thread.
4. Q3 attachments + mail live over WebTransport (closes Q-live-wt, Q-att-wt, Hetzner Storage Box, ClamAV on files).
5. Q-smtp-mtasts: MTA-STS, DANE, TLS-RPT.
6. Q4 kernel pqmail (OpenPGP RFC 9980).
7. Q1e calendar (E172-E173).
8. Pill gap: add PQC segment so the pill matches the Q1c row.
