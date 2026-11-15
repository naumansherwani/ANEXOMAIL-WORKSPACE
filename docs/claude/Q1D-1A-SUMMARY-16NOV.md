# Q1d-1a SUMMARY (16 Nov 2026 02:35) - what the phase is, features, advance technology
Phase: Q1d-1a = the founder mail DKIM lifecycle (key, DNS TXT, signing, proof). Sub-phase 1 of Q1d (1a, 1b, 2a, 2b). Plan: Q1D-PLAN-16NOV.md. Contract + EXECUTION RECORD: tech-contracts/CURRENT.md.
## Status (a1..a4)
- a1 DONE (repo): oversigning in server/founder/src/fmail_dkim.rs (From/To/Subject/Date/Message-ID listed once extra in h=, twice if absent; header added after signing breaks Ed25519 AND RSA; cargo 10/10).
- a2 DONE and ON HIS SERVER (his paste 16 Nov 02:3x: E175 selftest 28 ok, 0 failed; CHECK_E175 7/7 OK, E65 sweep OK; sha 3dd4fbff6069e7a9). Written in sandbox PG16 first: docs/cursor-work/sql/E175_founder_mail_dkim_lifecycle.sql (513 lines, needs E167/E169/E170) + CHECK_E175.sql (7 checks). selftest 28 ok. Chain tables hold 0 rows until a3 wires Rust (0 rows checked, 0 broken).
- a3 DONE in repo 16 Nov 02:5x (cargo 408/408 incl. 5 new tests; NOT on his server until founder-install): Rust wiring in fmail_out.rs: call fmail_dkim_send_gate175 before claiming; fmail_dkim_sign_record175 after each signature; read-only DNS probe -> fmail_dkim_dns_record175; proof door -> fmail_dkim_proof175; policy/health door. Contract note in CURRENT.md FIRST.
- a4 AFTER (needs his haan, additive only): new React file + one-line mount: key, TXT, DNS state, rotation, proof paste.
- Then: founder-install (oversign Rust live), his Compose key touch (hands), his Namecheap TXT (hands), Q1d-1b Gmail Show original paste, Q1d-2a, Q1d-2b (FMAIL_SEND=on only with his haan).
## Features
1 Dual signature Ed25519-SHA256 (RFC 8463) + RSA-2048 (RFC 6376 relaxed/relaxed), x= expiry 7 days, private key AES-256-GCM wrapped under vault master, creation needs passkey touch (action mail.key).
2 Oversigning (RFC 6376 8.15).
3 Policy ratchets: switches go on once, never off (trigger-enforced); rotate_days; passkey touch to change (ledger dkim_policy).
4 Dated selectors (e.g. e2611a) + rotation report: when the old key's DNS record may be removed.
5 DNS observation: hash-chained fmail_dkim_dns_obs; SQL decides match.
6 Signature log: hash-chained fmail_dkim_sign_log; over-sign is re-computed in SQL from h=, the signer is not trusted.
7 Proof: pasted receiver header (Gmail Show original) parsed in SQL, hash-chained fmail_dkim_proof (for Q1d-1b).
8 Health + send gate: no send if DKIM would fail. 9 chain_verify + selftest. All tables append-only, forced RLS, service_role only.
## Advance technology by layer
Rust = signer (ring/mail-auth). Tokio = sender worker, blocking RSA keygen thread, SQL doors. WASM kernel = signs/verifies browser requests and answers, later re-hashes the sign-log chain; NEVER holds a DKIM private key. WebTransport = browser<->server doors only (Compose, key touch, health); mail itself leaves by SMTP STARTTLS TLS 1.3 (Q1d-2a proves X25519MLKEM768). PostgreSQL 16 RLS, SHA-256 hash chains, triggers.
## DKIM2 / ML-DSA-44 sirf tracked | IETF draft, FIPS 204 | Q1d (OPEN)
draft-ietf-dkim-dkim2-spec-09 (WG draft, expires 5 May 2027): per-hop chain, mf=/rt= binding, RSA-SHA256, Ed25519-SHA256, ML-DSA-44. No receiver verifies it: NOT built. Build later in Rust + kernel verify when a receiver does. qstate step Q1d-DKIM2 (deferred).
## His command: DONE (sql-run AUTO). NO founder-install asked yet: Rust oversign + wiring go live with the founder-install AFTER a3. Next command to him = founder-install, only then.
## (old) His ONE command was
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/sql-run.sh) 2>&1 | tail -25
Expect: E175 selftest 28 ok + CHECK_E175 7 OK. No awam pull (kernel unchanged).

## a3 as built: fmail_out.rs process() = send gate (fmail_dkim_send_gate175) -> sign_all_rec -> fmail_dkim_sign_record175 per signature BEFORE SMTP (refusal = Retry). Doors: GET mail/dkim/health, POST mail/dkim/check (DNS TXT probe), POST mail/dkim/proof, POST mail/dkim/policy (touch). fmail_dkim::parse_sig. Contract = CURRENT.md Q1d-1a a3 CONTRACT. NEXT: his founder-install (sender is still OFF, FMAIL_SEND not on), then a4 UI (additive, needs his haan: mail_api.ts door calls + DkimSetup panel), then his Compose key touch, Namecheap TXT, Q1d-1b.

## PENDING (gate SERVER FIRST): the 4 route lines in main.rs are saved as docs/claude/state/PENDING-main-rs-dkim-routes.patch (git apply it). main.rs is a server-surface file: needs a fresh read-only paste from him (ss -tulpn | grep -E ':443|:25|:8443' style), then `python3 docs/cursor-work/server/serverfirst.py record "<cmd>" <paste file>`, then git apply the patch, cargo test, rec.sh, THEN give him founder-install. Without these routes the doors are dead code; send gate + sign log in fmail_out.rs already work.
