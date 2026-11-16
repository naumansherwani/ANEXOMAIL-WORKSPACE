# Q1b4 MASTER PLAN: SPF / DKIM / DMARC / ARC verdicts + TRUST RING (U3) - 17 Nov 2026 02:20 PKT

His order (17 Nov 02:10): "Q1b4 shuru karne se pehle repo mein master plan, advance technology plan, advance codes plan likho, phir shuru. SQL 800 lines super advance. Research karke duniya ka advance jo hai woh karo. Compaction ke liye aisa system ke Claude ko sab yaad rahay."
COMPACTION SAFETY: every sub-step below ends with `bash docs/cursor-work/server/rec.sh ...` (commits + WORKING-NOW + RESUME + CLAUDE.md top line). The step table in section 7 is the resume list: the first row not DONE is where to continue.

## 1. What is wrong today (read from the repo, not guessed)
- `server/founder/src/fmail_in.rs` line ~246 writes `p_spf:"none", p_dkim:"none", p_dmarc:"none", p_arc:"none", p_lookalike:false, p_tls:null` for EVERY inbound mail. Nothing is verified. The UI therefore shows "not checked" (honest, but useless).
- The crate `mail-auth` is NOT in `Cargo.toml` (a comment says it comes with fmail_in.rs, it never did). Cargo cache has mail-auth 0.9.2 (the last version that builds on the server's Rust; newer ones need Rust 1.98).
- The LMTP session throws the envelope sender (MAIL FROM) away, and nothing reads the client IP / HELO / TLS facts that Postfix already put in the top `Received:` header.
- Outgoing mail (direction out) shows the receive-side badges in the UI and its Sent time is the compose time, not the time the receiver said 250 (gap G3 of AUDIT-Q1d). Gap G4 = mail-auth unused.

## 2. Research (17 Nov 2026)
- SPF RFC 7208 (10 DNS-lookup limit, 2 void lookups), DKIM RFC 6376 + Ed25519 RFC 8463, DMARC, ARC RFC 8617, Authentication-Results RFC 8601, iprev (FCrDNS) RFC 8601 section 2.7.3.
- **DMARCbis = RFC 9989 (protocol, obsoletes RFC 7489), RFC 9990 (aggregate reports), RFC 9991 (failure reports), published May 2026.** Key change: the **DNS Tree Walk replaces the Public Suffix List** for finding the policy record and the Organizational Domain (at most 8 DNS queries per walk); new tags `psd`, `np` (policy for non-existent subdomains), `t` (testing mode); `pct`, `rf`, `ri` are historic. Our verifier therefore does the tree walk itself and hands the result to mail-auth (no PSL file that goes stale).
- Gmail and Yahoo require SPF + DKIM + DMARC and TLS for bulk senders; Gmail shows the verdict only on "Show original". Proton / Fastmail show a lock or badge. NOBODY shows a per-mail trust ring with the evidence behind it, and nobody ledger-chains the verdict. We do (below).
- Sources: suped.com RFC 9989/9990/9991 summary, dnsai.com DMARCbis tree walk, Stalwart mail-auth 0.9.2 source (SPF/DKIM/ARC/DMARC/iprev, test resolver), Postfix 3.10 `smtpd_tls_received_header`.

## 3. Technology (his law: only advance, latest)
| Layer | Technology |
|---|---|
| Verifier | Rust + Tokio, `mail-auth =0.9.2` (ring crypto, Ed25519 + RSA), hickory resolver, own RFC 9989 tree walk, own Postfix Received parser |
| Evidence | PostgreSQL 16, forced RLS, append-only hash-chained verdict ledger (SHA-256, per mailbox), per-signature rows, deterministic trust score in SQL (one source of truth) |
| Spoof defence | Lookalike = edit distance + confusable skeleton against domains this mailbox already trusts (SQL), display-name spoof (Rust), mixed-script IDN (Rust, idna) |
| Proof in the browser | WASM kernel already re-hashes the ledger chain (QUI-H3); the verdict chain gets the same door (U1U2 finishes it) |
| Screen | React 19 TS + Framer Motion: the TRUST RING (8 segments: SPF, DKIM, DMARC, ARC, TLS, scan, sender-history, lookalike), "Why this ring?" sheet with the raw evidence, 390 / 820 / 1200+ |
| Transport | signed GET doors over kernel WebTransport RPC (HTTP/3 only) |

## 4. The verdict model (decided here, written in SQL E183)
1. Postfix, the only thing facing the internet, writes the top `Received:` header (client IP, HELO, rDNS, TLS version, cipher, key exchange). Our LMTP also keeps the envelope MAIL FROM. Only that top header (written by our own Postfix) is trusted; any older one is ignored. If it cannot be read the verdict says "no client address" and SPF = `none` (never a guessed pass).
2. SPF on MAIL FROM (or HELO when the sender is `<>`), DKIM on every signature, DMARC by RFC 9989 tree walk, ARC chain, iprev.
3. SQL `fmail_auth_record183` stores one evidence row + one row per DKIM signature, appends the verdict to the hash chain, copies the five short verdicts into `fmail_messages` (spf, dkim, dmarc, arc, lookalike, tls_in) and returns the TRUST SCORE.
4. TRUST SCORE 0-100 and GRADE A+..F by ONE SQL function (`fmail_trust_score183`, IMMUTABLE, selftested): DMARC pass with an aligned DKIM = base 70; aligned SPF adds, TLS 1.3 post-quantum adds, a known sender with history adds; a dmarc `p=reject` domain that fails = hard F; lookalike or display-name spoof caps the grade at D; an infected or opaque attachment caps it at F. The reasons are returned as a list so the screen never says "trust me".
5. NEVER block or delete on a verdict in Q1b4 (observe mode, like K7): a failing mail goes to Inbox with a red ring, or Quarantine only when ClamAV says so (as today). Enforce (DMARC reject to Junk) = a later sub-phase with his haan.
6. OUTGOING mail: no receive badges. Instead: "Signed by anexomail.com (Ed25519 + RSA), delivered over TLS 1.3 post-quantum, accepted by the receiver at HH:MM:SS (250)". The Sent time = the time of the 250 (from the outbox ledger), fixing G3.

## 5. Codes plan (files; one sub-phase = one commit via rec.sh)
- **Q1b4-a** this plan + CURRENT.md contract (DONE when committed).
- **Q1b4-b SQL** `docs/cursor-work/sql/E183_founder_mail_auth_verdicts.sql` (target ~800 lines) + `CHECK_E183.sql`: tables `fmail_auth_evidence`, `fmail_auth_sig`, `fmail_auth_chain` (append-only, hash chain), trust score + grade + reasons, edit distance, confusable skeleton, lookalike check against mailbox history, sender history, `fmail_auth_record183`, `fmail_auth_get183`, `fmail_auth_summary183`, `fmail_auth_chain_verify183`, outgoing facts `fmail_out_facts183`, door audit rows, RLS forced, `fmail_selftest183` (rolled back). Proven in the sandbox PG16 (port 5441) before he runs it.
- **Q1b4-c Rust** `server/founder/src/fmail_auth.rs` (pure parts: Received parser, tree walk, display-name spoof, mixed-script check, verdict mapping; async part: mail-auth calls with a test resolver) + changes in `fmail_in.rs` (keep MAIL FROM, call verify, call `fmail_auth_record183`) + door `GET /founder/v1/mail/auth?box=&message=` and `GET /founder/v1/mail/auth/summary` + `Cargo.toml` (mail-auth =0.9.2, ring feature, idna). Target: cargo tests all green (413 now).
- **Q1b4-d UI** `founder-web/src/TrustRing.tsx` + `trust_pure.ts` (+ test) + `trust.css`, "Why this ring?" sheet, outgoing facts line, mounted with one line in MailView (MailBox.tsx and the orb stay untouched). tsc clean, bun tests green.
- **Q1b4-e his hands**: ONE sql-run (E183), then ONE founder-install, then my live Chrome: send him a mail from Gmail, see the ring + evidence, 390/820/1200; GREEN only with "WIRED: YES / REAL: YES / TECH-LAW CHECKED".
- Postfix is NOT changed (no server-surface edit). If `smtpd_tls_received_header` is off, a read-only command comes first (SERVER FIRST law) and he decides.

## 6. Not in Q1b4 (tracked)
BIMI (needs a VMC certificate, vendor), DMARC aggregate-report ingestion (RFC 9990; mail-auth has the parser; later phase), enforcement actions, ARC sealing (we are the final receiver), DKIM2 (no receiver verifies it).

## 7. STEP TABLE (the first row that is not DONE = where to continue after a compaction)
| Step | What | State |
|---|---|---|
| a | master plan + CURRENT.md contract | DONE (this commit) |
| b | SQL E183 (786 lines) + CHECK_E183 + sandbox proof (selftest 52 ok, door audit clean) | DONE 17 Nov 02:5x |
| c | Rust fmail_auth.rs + intake + doors + tests (cargo 429/429) | DONE 17 Nov 02:3x |
| d | UI TrustRing + outgoing facts + tests | todo |
| e | his sql-run E183, founder-install, Chrome look, GREEN | todo |
