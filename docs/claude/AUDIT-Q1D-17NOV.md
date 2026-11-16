# AUDIT-Q1d (17 Nov 2026 01:30 PKT, his order: is every LISTED advance technology really in the code of Q1d; auto fix what is missing)
Method: each listed technology compared with the repo (grep + read), no guessing. Result per technology:
| Listed technology | In code? | Evidence |
|---|---|---|
| Rust + Tokio + axum | YES | server/founder/src (fmail_out.rs sender, tokio::select exact-time wake) |
| WASM kernel (browser) | YES for the mail ledger + every signed answer; PARTLY for the DKIM evidence | web-wasm mailledger.rs / envelope; NO dkim module in the kernel (gap G2) |
| WebTransport / HTTP/3 doors | YES | every Q1d door goes through api.ts -> kernel RPC (wtrpc.rs, h3.rs) |
| X25519MLKEM768 | YES (outgoing SMTP + all listeners) | fmail_smtp.rs rustls_post_quantum::X25519MLKEM768 first; his probe 16 Nov 05:37 |
| AES-256-GCM | YES | TLS suites (fmail_smtp.rs, tls256.rs), DKIM keys sealed AES-256-GCM (fmail_dkim.rs), mail seal (fmail_seal.rs) |
| PostgreSQL RLS + hash chains | YES | E175: 3 chains (dns_obs, sign_log, proof), forced RLS, append-only; selftest 28 |
| DKIM dual (Ed25519 RFC 8463 + RSA-2048) + oversign | YES + OUTSIDE PROOF | Gmail dkim=pass (RSA), Ed25519 neutral (Gmail does not verify it), saved in the proof ledger |
| DKIM2 / ML-DSA-44 | NO, tracked only by design | no receiver verifies draft-09 |
## Gaps found
- G1 FOUND + FIXED (repo): the three DKIM evidence chains were re-checked only inside the SQL selftest; no door, no screen. Fix: GET /founder/v1/mail/dkim/chain (Rust, signed) + button "Check evidence chains" in Systems > Mail signing. cargo build ok, tsc clean. Live proof pending his founder-install + my Chrome look.
- G2 OPEN (own step): the kernel does not re-hash the DKIM sign-log / proof chains (the mail ledger it does, QUI-H3). Home = U1U2 (kernel proof pills), SQL door + kernel module `dkimchain@1`.
- G3 OPEN: outgoing mail shows receive-side badges (Not anchored, SPF/DKIM/DMARC not checked, Scan pending) and the compose time as Sent time. Home = Q1b4.
- G4 OPEN: Q1b4 lists Rust mail-auth for SPF/DKIM/DMARC verdicts; the crate is not used yet (our DKIM signer is hand-written on ring/rsa). Home = Q1b4.
- G5 OPEN: MTA-STS / DANE / TLS-RPT for outgoing mail. Home = Qtls (gate Q-smtp-mtasts).
- G6 OPEN: Delete (E180 door) live test needs his word; Stale badge forced test; 390/820 looks.
