# FOUNDER MAILBOX: THE REAL BUILD (founder 13 Nov 2026 02:02: "demo apni gand mein rakho, real wire codes, endpoints, gates")
Read after: rules-read.py, RESUME-POINT.md, FOUNDER-MAILBOX-MOULD-PLAN-13NOV.md (sections 14, 15). Demo = docs/cursor-work/frontend/mailbox-demo/ (design reference only).
ORIGINAL ANEXOMAIL LOGO (his 02:02 word): the Mail page header uses `LogoMark` from founder-web/src/Brand.tsx (the one real mark), never a redrawn copy.

## 1. Every feature he listed (nothing dropped). Status column = what is REAL in code after Q1b-3.
| # | Feature | Backend (Rust / SQL) | Frontend | Status |
|---|---|---|---|---|
| 1 | 7 mail lanes in ONE compact row | fmail_bridge_feed (E168) + GET /mail/lanes | MailLanes row | Q1b-3 |
| 2 | Expandable left rail with labels + Vault | fmail_list169 views incl. vault, fmail_folder_counts | MailRail (hover / pin) | Q1b-3 |
| 3 | Header pill QUIC · DBSC verified · PQC sealed | values from REAL checks: /tls, /dbsc/status, key posture (E168 posture) | ProtoPill (hollow + word when a check fails) | Q1b-3 |
| 4 | Empty pane quick actions: Verify ledger anchor, Open encrypted vault | GET /mail/proof?head (ledger verify) | EmptyPane | Q1b-3 |
| 5 | Ledger Anchor chip per message + proof sheet | fmail_proof169 (E169): row hash, prev hash, seq, body sha256 now vs at delivery, chain verify; audit anchor seq if anchored | ProofChip | Q1b-3 |
| 6 | Live events, no spinner, smooth numbers | GET /mail/stream (SSE now; WebTransport event stream with Q-live-wt) | useMailLive + number tween (Framer Motion) | Q1b-3 SSE; WT later |
| 7 | 8-segment upload ring, per-stream speed + AES-256-GCM state | fmail_att_* (E167) + Tokio WebTransport upload (Q3) | AttachRing | Q3 (18-19 Nov) |
| 8 | Touch-to-Unseal for confidential / quarantine / vault | mail.unseal T2 action (E169 tier) + fmail_get169 refuses gated rows without a touch hash | TouchGate | Q1b-3 |
| 9 | Inbound mail real | fmail_in.rs LMTP (Tokio) behind Postfix, seal + ClamAV + fmail_deliver_inbound | none | Q1b-3 code; Postfix hook = his ss list first |
| 10 | Compose, DKIM sign, send, undo | fmail_out.rs SMTP client + fmail_outbox_* (E167) | Compose, UndoBar | Q1d (17 Nov) |
| 11 | ML-KEM-768 device-only sealing (server cannot open) | fmail_kem.rs DONE + kernel decapsulation | kernel pqmail | Q4 (21-22 Nov); until then seal_mode = vault (AES-256-GCM, key under the vault master, opens only inside a signed-in session) |
| 12 | SPF / DKIM / DMARC verification | mail-auth behind a trait | verdict chips | Q1b-4; until then verdict = 'none' (never a guessed pass) unless Postfix added Authentication-Results |
| 13 | Calendar | E172-E173 | Calendar | Q1e (20 Nov) |
| 14 | Command palette, j/k/c keys, density, 390/820/1200 | none | MailPalette | Q1b-3 |

## 2. BACKEND (Rust crate anexomail-founder) vs SQL vs FRONTEND
- SQL E169 (new): mail.* T2 actions in founder_action_tiers; fmail_touch_consume (the ONE place a mail passkey grant is spent; returns the action hash used as touch_hash); fmail_threads.vault; fmail_list169; fmail_get169 (gated rows give NO sealed bytes without a touch hash); fmail_vault_set169; fmail_proof169; fmail_mailbox_add169; ledger action list extended (inbound_ok, unseal_gated, vault_set); founder mailbox seeded.
- Rust fmail_in.rs: pure LMTP session state machine (tested), raw-message ingest (parse with mail-parser later; headers by own safe parser now), seal (AES-256-GCM, vault wrap), blind indexes, ClamAV INSTREAM client, delivery through fmail_deliver_inbound, ledger row inbound_ok. Loopback listener, OFF unless FMAIL_LMTP_BIND is set.
- Rust fmail_ep.rs: whitelisted query parsing, unseal in Rust for vault mode, endpoints + gates: reads `authed`, writes `authed_w`, gated open + vault-out + key + delete need a passkey grant (spent through fmail_touch_consume).
- Frontend: founder-web/src/Mail*.tsx, mail.css, mail_pure.ts (+ bun tests), mounted in App.tsx with ONE nav entry; Orb / BridgeMap code untouched (UI LAW).
## 3. Order of the pull commands (per technology)
SQL: E169 then CHECK_E169 (sql-run.sh). Rust + SPA: founder-install.sh. Postfix hook: only after his fresh `ss` list and his haan.
