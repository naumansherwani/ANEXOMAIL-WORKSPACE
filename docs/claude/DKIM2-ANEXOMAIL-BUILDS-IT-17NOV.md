# DKIM2 / ML-DSA-44: ANEXOMAIL BUILDS IT ITSELF (his word 17 Nov 2026 06:41 PKT)
> **PARKED 17 Nov 06:46 (his word): "dkim2 tracked complete kero filhal, baki chodo". Status = TRACKED, build later. The plan below stays for the day he says go.**

His word: "DKIM2 koi signature verify nahi karti toh na karay, meri company anexomail karay gi."
Decision: Q1d-DKIM2 is no longer "tracked only". Anexomail writes BOTH sides itself: the signer and the verifier, in Rust, inside our own mail path. We do not wait for Gmail or Outlook.

## Honest facts (so nothing is promised that is not true)
- DKIM2 is still an IETF working-group draft (draft-ietf-dkim-dkim2-spec, repo last read: -09, expires 5 May 2027). It can still change. Step D2a re-reads the NEWEST version before any code (a web search on 17 Nov showed several versions, the newest was not confirmed).
- Today no big receiver verifies it. So until others adopt it, a DKIM2 signature is verified only by Anexomail servers (our own domains, awam later). That is the point of building it first. It never replaces Ed25519 + RSA-2048 DKIM, which stay live and keep carrying DMARC.
- Receivers that do not know DKIM2 ignore the new header, so signing is harmless to delivery. Still: signing stays OFF until his haan.

## Sub-phases (one at a time, each closes with proof)
- D2a RESEARCH (written with date and time in this file): newest draft version, exact header and tag names, ML-DSA-44 (FIPS 204) key and signature sizes, how a ~1.3 KB public key fits a DNS TXT (multi-string), which Rust crate (RustCrypto ml-dsa or aws-lc-rs) passes the FIPS 204 known-answer tests.
- D2b RUST CRATE (research crate, signing OFF): sign + verify, FIPS 204 KAT vectors, tests including tamper cases. Rust + Tokio, no network.
- D2c VERIFIER ON INTAKE (read-only): fmail_auth.rs verifies a DKIM2 header when present and records it in the E183 evidence chain; the trust ring shows a DKIM2 mark only when a signature exists. Self-test mail between two Anexomail addresses.
- D2d SIGNER ON OUTGOING: needs his haan + his Namecheap TXT (his hands) + one SQL number for the key registry (next free E-number at that time). Rollback = switch OFF.
- D2e PROOF: his install paste + my live Chrome look; GREEN only with WIRED: YES / REAL: YES / TECH-LAW CHECKED.

Order: QC0 compose polish first (his order, one phase at a time); DKIM2 starts at the evening slot already in CLAUDE.md ("DKIM2 research crate, signing OFF").
