# Q-SERIES: ORDER, ADVANCE TECHNOLOGY PER PHASE, AND WHAT QUI-H (P1+P2 HYBRID) REALLY IS (13 Nov 2026 20:10 PKT, his request 20:05)
Rule (his): ONE phase at a time; the technology is written in front of every phase; a phase closes only with his output + my live Chrome look. Source of truth for state = docs/claude/state/Q-STATE.jsonl via docs/cursor-work/server/qstate.py (hash-chained).

## The order (technology in front of each phase)
| # | Phase | Advance technology | State |
|---|---|---|---|
| 1 | Q1b3-T1 Postfix PQ TLS inbound | Postfix 3.10.6 + OpenSSL 3.5.5, X25519MLKEM768 first, TLS 1.3 AES-256-GCM | DONE (his output) |
| 2 | Q1b3-T2 clamd alerts | ClamAV INSTREAM, AlertEncrypted + AlertExceedsMax, fail-closed | DONE (his output) |
| 3 | Q1b3-T3 first real mail | Postfix per-address LMTP RFC 2033 on loopback, ClamAV, AES-256-GCM seal on arrival, RLS + hash-chain ledger | DONE (3 mails stored; Chrome Inbox 1 / Quarantine 2) |
| 4 | Q1b3-T4 SQL E171 | PostgreSQL RLS, append-only ledger, scan state opaque, selftest + CHECK, Rust opaque guard | DONE (his sql-run + install; Chrome lane Quarantined = 2) |
| 5 | **QUI-H ledger-box hybrid P1+P2 (NOW)** | React 19 TS, kernel-verified signed founder responses, Bridge card as NEW file | BUILT in sandbox (commit 281ae897); waits his founder-install + my live Chrome look |
| 6 | QPERF mail latency p50/p90/p95/p99/p99.9 + SLO burn | SQL E172 (percentile_cont, append-only samples), Rust Tokio stage timing (accept, scan, seal, commit), Bridge card | not started |
| 7 | Q1d-1 DKIM | Ed25519 + RSA DKIM, passkey touch, DNS TXT | not started |
| 8 | Q1d-2 real outgoing mail | Rust Tokio SMTP, STARTTLS TLS 1.3 X25519MLKEM768, undo window, outgoing PQ TLS proof | not started |
| 9 | Q1b4 SPF/DKIM/DMARC + trust ring (U3) | Rust mail-auth, Framer Motion | not started |
| 10 | Q3 attachments + live over WebTransport + 8-segment ring (U4) | Rust Tokio WebTransport, Hetzner Storage Box, ClamAV, WASM kernel | not started |
| 11 | Qtls MTA-STS / DANE / TLS-RPT | RFC 8461 / 7672 / 8460 | not started |
| 12 | U1/U2 proof pill + Touch-to-Unseal live proof, PQC pill | kernel SHA-256/Merkle verify, passkey | not started |
| 13 | Q4 kernel pqmail | OpenPGP RFC 9980, ML-KEM-768 + X25519, ML-DSA-65 + Ed25519 | not started |
| 14 | U5 Who-can-read-this, Ctrl K, light theme (approved) | Radix Dialog, command palette | not started |
| 15 | Q1e calendar (E174-E175) | Rust + SQL RLS + React TS, same sealing | not started |

## What we were doing: P1+P2 hybrid (his question: where is the advance-level code?)
Why hybrid: research (Proton Key Transparency, Apple iMessage Contact Key Verification, IETF keytrans) = verification runs automatically in the background, the user sees a passive status, deep audit lives on an audit surface.
Where the code is (all in founder-web/src, additive, Scene3D.tsx and BridgeLanes.tsx untouched):
- mail_pure.ts `ledgerChip` (line 88) + 4 tests in mail_pure.test.ts: pure logic. Green ONLY for a ledger-scope proof with chain_ok; failure = red with reason; no answer = grey "off", never a fake tick.
- MailView.tsx: effect that runs `api.proof` by itself when the mailbox opens and when the ledger head moves (QUI-H comment), the chip in the header (line ~178, click = re-check), the two big buttons removed from the empty pane, deep-link start folder from sessionStorage `mail.openview`.
- BridgeMailLedger.tsx + bridgemailledger.css (NEW): Bridge audit card (head, Verify now, counts; a tap opens Mail on that folder). One-line mount in Bridge.tsx (line 107).
- mail.css: chip styles, 44 px on coarse pointers, reduced-motion safe.
Proof so far: tsc clean, bun 259 pass, sandbox 390/820/1280 no sideways scroll, no button under 44 px, no console error.
## HONEST: what is advance and what is still missing
- Advance and real now: automatic background verification, passive status, signed + kernel-verified server answers, hash-chain (SHA-256) ledger shared by mailbox and Bridge.
- NOT yet advance-level: the chain is recomputed by the SERVER; hashing the whole chain INSIDE the browser WASM kernel (rows streamed to it) = open gap Q-ledger-kernel (TECH-LAW-GATE.json, deadline 25 Nov). Merkle inclusion proof per message (U1) also still to come. Neither is called green.
## Closing QUI-H needs: his founder-install output, then my live Chrome look (chip + Bridge card at 390/820/1200). Rollback: fmail-ui-rollback.sh (backup /root/backups/ledger-hybrid-13nov) or commit 9fe8155e.
