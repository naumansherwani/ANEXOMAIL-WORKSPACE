# Founder mailbox (phase Q): where we stand, 13 Nov 2026 03:05 PKT
Order of the phases, the advance technology of each phase, the frontend codes, the backend codes, the SQL. "REAL" only after his server + my Chrome look.

| Phase | Technology (his law) | Backend codes | Frontend codes | SQL | State |
|---|---|---|---|---|---|
| Q1a core | PostgreSQL RLS, hash-chained ledger | - | - | E167 | GREEN (his server) |
| Q1b-1/2 sealing, keys | AES-256-GCM, ML-KEM-768 + X25519, Rust, zeroize | fmail_seal.rs, fmail_kem.rs | - | E168 | GREEN (his server) |
| Q1b-3 read doors, intake, endpoints | Rust Tokio Axum, LMTP, ClamAV, passkey touch gates | fmail_core.rs, fmail_in.rs, fmail_ep.rs | - | E169 | INSTALLED, intake OFF, no real mail yet |
| Q1c Mail UI | React 19 TS, motion, Radix, kernel-verified SSE | - | MailView.tsx, mail_pure.ts, mail_api.ts, mail.css | - | LIVE in my Chrome (real boxes, lanes, ledger proof); polish pass waits his pull |
| Q1d compose / send / undo | Rust Tokio SMTP (STARTTLS 1.3), DKIM, ML-KEM wrap | fmail_out.rs | MailCompose.tsx | E170 | NEXT |
| Q1b-4 verdicts | Rust mail-auth (SPF/DKIM/DMARC) | in fmail_in.rs | chips exist | none | after Q1d |
| Q3 attachments + ring + live over WebTransport | Tokio + Rust + WebTransport, AES-256-GCM chunks, ClamAV, Storage Box | fmail_att.rs, fmail_wt.rs | StreamRing.tsx | E171 | OPEN |
| Q4 pqmail | WASM kernel ML-KEM decapsulation, OpenPGP RFC 9980 | kernel | MailKernel.ts | - | OPEN |
| Q1e calendar | Rust + RLS + React | fcal_*.rs | CalendarView.tsx | E172-E173 | OPEN |

## Technology audit of what exists (13 Nov 03:05), against the law in CLAUDE.md
- IN code and working: Rust + Tokio + Axum; AES-256-GCM; ML-KEM-768 hybrid wrap; PostgreSQL RLS; WASM kernel verifies every signed answer and every live frame; React 19 + TypeScript + Vite 8; motion (Framer Motion); Radix Popover; passkey touch on every Quarantine/Vault open.
- OPEN GAPS (registered in TECH-LAW-GATE.json, never called green): mail live is SSE only, not kernel WebTransport (Q-live-wt, Q3); attachments over WebTransport (Q-att-wt); ML-KEM mail cannot be opened by the browser kernel yet (Q-pqmail); SPF/DKIM/DMARC verdicts not computed; clamd daemon on his server not verified.
- Not used on purpose: Three.js / GSAP inside Mail (nothing to animate in 3D; BridgeMap mail lanes need his haan).
- Auto-fixed in this audit: (1) a move-out touch is now bound to the exact id set (sha256), before it was a 200-character prefix; (2) LMTP DATA has a 15-minute total limit (a slow sender could hold a connection); (3) protocol pill read "transport unknown" in his Chrome: now falls back to the newest same-origin request.
