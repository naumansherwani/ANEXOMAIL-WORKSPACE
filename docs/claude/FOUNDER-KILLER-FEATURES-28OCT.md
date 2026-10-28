# FOUNDER KILLER FEATURES — 4 features + 3 indicators (founder 28 Oct 2026, 12:47 PKT)
Founder's verbatim order is in docs/cursor-work/founder/founder-commands.md (top entry). This file = duplicate scan, TECHNOLOGY FIRST (Rule 62), honest limits, gates, order. **Docs only (Rule 63/64): no feature code until the earlier phase is green in his Chrome.** Mock data never (Rule 69): until a source exists a tile says "Not measured / Not connected".

## 0. Technology (Rule 61/62 — same for every item below)
Supabase Postgres (RLS on, append-only tables + deny-update/delete triggers) -> Rust `anexomail-founder` (axum 0.8, tokio; `ring` Ed25519/HMAC/HKDF, sha2) -> fetch/WebTransport (HTTP/3) -> browser WASM kernel verifies (F2b) -> React 19.2 + Vite 8.2 SPA. Passkey (WebAuthn, F2d) for G3. No Bun/Node in the founder server. Pull commands per Rule 66: SQL = `sql-run.sh`, Rust+SPA = `founder-install.sh`.

## 1. Duplicate scan (repo docs + code searched 28 Oct)
| Item | Already in repo? | Verdict |
|---|---|---|
| 1 Cross-Company Escrow | no ("escrow" appears nowhere) | NEW. Builds on: F2c Merkle audit chain, Promise/Decision detector (user side Phase 23, E97-E101), F5 Mail Desk |
| 2 Mesh air-gapped workspace | no. Neighbour: H31 founder PWA = view-only offline snapshot (FOUNDER-BUILD-PLAN #30) | NEW, different (two-way sync). PWA stays view-only |
| 3 Poison Pill shred vault | no. Neighbour: #14 device revoke / force sign-out + E104 token revoke kill SERVER access only | NEW (data on the device) |
| 4 ZK Internal Auditor | no. Neighbours: #13 User/Org 360 (metadata only), #16 abuse scoring (device-shape, review queue only) | NEW. Reuses their metadata rules; adds insider export/provenance rules |
| I1 Ledger Integrity Gauge | audit viewer (#26) verifies the chain on a page; no live gauge | NEW view of F2c data |
| I2 Active Work Chain Dependencies | Promise board exists on the user side (`promise_board()`, Phase 23) | NEW founder/company view; no dependency edges exist yet (needs `depends_on`) |
| I3 Device Trust Map | founder device list planned (after F2c); user device vault exists (Rule 45) | NEW view; location = device-reported city/zone, never IP (Rule 45) |

## 2. Per feature: how it is built, honest limits, gate
### K1 Sealed Agreements (Cross-Company Cryptographic Escrow) — order 11a
- Flow: Mail Desk finds a confirmation with the existing deterministic Promise/Decision detector (no AI) -> shows "Seal this" -> a human seals (never silent: privacy). Seal = canonical JSON {message-id, header hashes, body SHA-256, parties, deadline, time} signed Ed25519 by the company key + the signer's passkey assertion (G3) -> row in append-only `sealed_agreements` + Merkle leaf (F2c, signed checkpoints). Counterparty on Anexomail countersigns with their passkey = two-party seal; if not on Anexomail the seal is one-sided with a public verification link.
- Tamper proof: a Rust job re-hashes the stored message; mismatch -> generated proof bundle (hashes, Merkle path, signatures) mailed to the configured legal address. Anyone verifies the bundle offline with the WASM kernel and the public key.
- Limits (honest): it cannot stop a mailbox deletion — it makes any change provable. External timestamp anchoring (RFC 3161 TSA) shows "Not connected" until a TSA is configured. Legal weight differs by country; it is evidence, not legal advice.
### K2 Local Mesh Sync (Air-Gapped Workspace) — order 12a, starts with a research spike
- Browsers cannot discover peers or accept LAN connections. Needs a small Rust LAN node `anexo-mesh` on one office machine (mDNS discovery, local TLS via a local CA because browsers need secure contexts), CRDT documents (Rust `yrs`) for chat, calendar and tasks, SPA service worker + IndexedDB op-log. On reconnect the op-log is pushed as a hash chain; the server verifies the chain, merges, rejects gaps.
- Limits: email delivery itself (SMTP) still needs the internet; the mesh covers chat/calendar/tasks. Requires installing the LAN node (founder decision when reached).
### K3 Poison Pill (Zero-Trace Remote Shred) — order 13a (after F8 Control)
- Crypto-shredding: everything cached on a device (IndexedDB / OPFS / Cache) is encrypted under a per-device key (WebCrypto, non-extractable) that only works while a short server lease is fresh (15 min, renewed while approved). Button (G3: two-tap + reason + passkey) marks the device `shred`; lease stops, the device deletes key and storage at next contact, and an offline stolen laptop becomes unreadable when the lease expires (dead-man switch).
- Limits (honest): a web app cannot overwrite disk sectors or reach files saved outside the browser (Downloads). True disk-level wipe needs an optional desktop agent/MDM — a later, separate decision. The UI never claims more than "cached workspace data destroyed".
### K4 Insider Guard (metadata-only auditor; the "ZK Auditor") — order 10b (after F4)
- Deterministic rules in Rust over metadata events only (who exported/downloaded what, how much, when, from which device, new device, file-hash duplicates, message header provenance). No message content read, no AI. Every hit is explainable ("rule X: 40 exports in 10 min").
- Action: unauthorised-export rule -> **hold** that account's export/session (reversible, G2 two-tap + reason to release) + founder review item; consistent with Rule 45 (no IP) and the review-queue principle.
- Wording: we call it "metadata-only, deterministic". Real zero-knowledge proofs would be added only for narrow claims later; we do not label rule checks as ZK.

## 3. The three indicators (Dashboard)
- **I1 Ledger Integrity Gauge** — order 5a (right after F2c). Verified entries / total, newest checkpoint age, "verified in this browser" (F2b). Shows "Not measured" before F2c.
- **I2 Active Work Chain Dependencies** — order 10a (with F4/Work). Graph of open promises per department and which later items they block (deterministic graph, counts of dependants). Needs one SQL step: `depends_on` edges on work items.
- **I3 Device Trust Map** — order 8a (after devices screen + Live Pulse). Each device: sealed-token state, last seen, coarse place (device-reported city/zone, never IP).

## 4. Bridge vs Dashboard (founder: "Bridge mein founder ke features alag, Dashboard mein jo dashboard se related")
- **Bridge** (founder only; cross-tenant; acts) = Decide, Live Pulse, Sealed Agreements console (all tenants), Poison Pill control, Insider Guard review queue, Mesh fleet status, money + attention.
- **Dashboard** (a company's live health view; first for ANEXOMAIL itself, later the same component per business account under FC22) = the three indicators (I1, I2, I3) + their drill-downs. Read-only (G1).
- Navigation: "Dashboard" becomes a Command-center item next to Bridge when I1 ships (step 5a). Until then the sidebar link "Dashboard" under Workspace still opens the user app dashboard.

## 5. Order (numbers match docs/claude/FOUNDER-MASTER-ORDER-28OCT.md)
5a I1 Ledger Integrity Gauge · 8a I3 Device Trust Map · 10a I2 Work Chain Dependencies · 10b K4 Insider Guard · 11a K1 Sealed Agreements · 12a K2 Mesh (spike first) · 13a K3 Poison Pill.
Decisions asked once when reached: K1 legal contact + optional TSA; K2 installing a LAN node; K3 whether an optional desktop agent is wanted for real disk wipe.
