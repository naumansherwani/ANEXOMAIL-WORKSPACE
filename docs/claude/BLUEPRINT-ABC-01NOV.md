# ANEXOMAIL blueprint, lettered order (founder 1 Nov 15:17 PKT)

One letter per step, in build order. **GREEN** only where the proof exists (server output and/or the founder's Chrome). Old master-order numbers stay in `[brackets]` so nothing is duplicated. Source of truth for detail: `FOUNDER-MASTER-ORDER-28OCT.md`. The website says only what `tech-proof.py` shows PROVEN.

## FOUNDER lane (founderworkspace.anexomail.com)

| Letter | Step | Old # | Status |
|---|---|---|---|
| **A** | Device approval + Ed25519 request signatures | [1] | **GREEN** (Chrome) |
| **B** | Settings S1 (photo, name, adaptive city, graphics, sidebar) | [2] | **GREEN** (E108 CHECK 6 OK on the server + founder-install green, context lines 1903/1920; Settings page lives in his Chrome and H runs on it). The master-order row text was stale |
| **C** | Server leftovers: C1 Polar Metrics token **GREEN** · C2 awam host guard (L5) PARKED to the awam migration (same rule written on the awam side as W5 / A8) | [3] | C1 GREEN, C2 parked |
| **D** | T1 UI stack: TypeScript, TanStack Router, Tailwind 4.2, shadcn | [3a] | **GREEN** (425ec14) |
| **E** | Loophole fixes L1-L12 | [3b] | **GREEN** except L5 (parked) and lockfile (open, step 4e) |
| **F** | WASM kernel verify in the browser (Rust kernel, Worker, pinned .wasm) | [4] | **GREEN** (Chrome) |
| **G** | Audit + Merkle: G1 SQL E107 **GREEN** · G2 Rust + UI card **GREEN** · G3 kernel `merkle@1` **GREEN** · G4 Ledger seal gauge hardening (E120; the gauge itself is GREEN since 1 Nov 09:00, G4 closes its loopholes: written + tested 2 Nov, server + Chrome pending; honest limits = G5 external anchor / kernel consistency proof, `G4-LEDGER-GAUGE-HARDENING-02NOV.md`) (I1) · **G5 Un-forgeable history (founder 2 Nov 03:37, god-level): G5-0 finish the technology read · G5a RFC 9162 consistency proofs (SQL + Rust + kernel `merkle@2`) · G5b C2SP signed checkpoints (own audit-log key) · G5c external ANCHORS with no outside accounts (founder decision G5-D 2 Nov 04:00: no signups): OpenTimestamps + RFC 3161 receipts sent by the server; "time-anchored", never "witnessed" · G5d pin portability; design + review gate in `G5-UNFORGEABLE-HISTORY-02NOV.md`** | [5], [5a] | G1-G3 **GREEN**; G4 = **GREEN** (server: founder-install 122 tests + CHECK_E120 4/4, 2 Nov 04:00; founder ordered GREEN 2 Nov 04:14); G5a SQL E121 **GREEN on the server** (CHECK_E121 3/3 + E65 sweep OK, pasted 2 Nov 04:14); G5a Rust/kernel 0.7.0/UI: founder-install FAILED at tests (consistency_vectors.json not copied), fixed in founder-install.sh, re-run pending; G5b-d pending |
| **H** | Settings S2: Time machine + Drift | [6] | **GREEN** (server + Chrome 11:02) |
| **I** | Settings S1b: key registry, Appearance, Ambient Studio. I1 SQL E114 **GREEN** · I2 Rust + UI written, install + Chrome pending | [6b] | I1 GREEN, I2 pending |
| **J** | Passkey + Privacy: J1 SQL E117 **GREEN** · J2 SQL E118 chairman protocol **GREEN** · J3 Rust `webauthn-rs` (7-2) · J4 UI Privacy tab (7-3) · J5 enforce T2/T3, remove `FOUNDER_PASSWORD` (7-4) · J6 mobile flare + cancel (7-5) | [7] | J1, J2 **GREEN**; J3-J6 pending |
| **K** | Transport and security: K1 post-quantum key exchange X25519MLKEM768 on both hosts **GREEN** (openssl) · K2 AES-256 terminator on :8443 + E119 ledger **GREEN** (server, openssl, prober rows 1 Nov 15:15) · K3 Chrome padlock on :8443 · K4 AES-256 on :443 per host · K5 **awam T256-2 (founder "HAAN" 15:17, builds after K3 is green)** · K6 WebTransport `wtransport` (7a) · K7 DBSC (7b) | [7a], [7b], [7b-T256] | K1, K2 **GREEN**; K3-K7 pending |
| **L** | Look: L1 Framer Motion + GSAP · L2 Three.js WebGPU (CINEMATIC stays pixel-equal) | [7c], [7d] | pending |
| **M** | MoQ-F (IETF draft; own relay on staging; awam MQ0-MQ4 after) | [7e] | pending |
| **N** | Decide + Live Pulse + S4 push · N1 Device Trust Map | [8], [8a] | pending |
| **O** | Finance deck (Polar, Revenue, Billing, Release, Move-In) | [9] | pending |
| **P** | People: Org, CRM, Team, Account 360, Work · P1 Chain Dependencies · P2 Insider Guard | [10], [10a], [10b] | pending |
| **Q** | Mail + Calendar: Q1 founder Mail/Calendar/Mail Desk · Q2 common attachments (dedupe, resumable chunks, signed link) · Q3 parallel chunks over WebTransport (after K6) · **Q4 PQM post-quantum mail content, OpenPGP RFC 9980 (PQM0-PQM5)** · **Q5 PQN post-quantum network + live-data protection (PQN0-PQN5; PQN1 sits on Q2, PQN3 after K6 + Q3)** · Q6 Sealed Agreements | [11], [11b], [11c], [11d], [11f], [11a] | pending |
| **R** | Systems: health, analytics, speed, admin, safety, chat · R1 Mesh sync · R2 Mail<->Chat Bridge | [12], [12a], [12b] | pending |
| **S** | Control: kill switch, flags, executor · S1 Poison Pill | [13], [13a] | pending |
| **T** | CUTOVER: remove old Lovable founder routes + Bun-only endpoints after Rust == Bun | [14] | pending |
| **U** | Docs + Sheets (WOPI; engine after a licence read) | [15] | last |
| **V** | Founder AI (founder only) | [16] | pending |

## AWAM lane (anexomail.com), follows each founder proof

| Letter | Step | Status |
|---|---|---|
| **W1** | Landing footer "Built with" (founder's wording) | `pull.sh` ran OK on the server; Chrome look pending |
| **W2** | Sync 3 files (CommandPalette, dashboard.ts, admin.addresses) via DEPLOY-MANIFEST | **GREEN on the server** (pull.sh 2 Nov 03:37: 3 files `wrote`, build OK, differ=0, /app/domains 200); Chrome menu check pending |
| **W3** | = K5 T256-2 awam AES-256 (approved, after K3) | approved, pending |
| **W5** | **Host guard (= founder C2 / L5)**: awam and founder hosts never serve each other; probe -> enforce. **RULE (founder 1 Nov 06:07, repeated 15:22): PARKED, runs together with the awam migration (A2), awam login is in the old Brain.** Not skipped | PARKED (founder decision), ONE-ORDER row A8 |
| **W6** | Kernel `merkle@2` (G5a) moves the ONE kernel pin (Rule 52), so the awam pin follows the founder's proof; awam publishes through its own kernel lane (E90 `kernel_release_publish`) when it pulls | after G5a is GREEN |
| **W4** | Catch-up A1-A7: Bun-free pages, webauthn-rs, DBSC, WebGPU, MoQ (MQ0-MQ4), PQM, PQN | after each founder letter turns GREEN |

## Rules
0. **The blueprint runs in LETTER ORDER (founder 1 Nov 15:21).** Next letter = the first one that is not GREEN. Today that is: C2 (host guard, parked by the founder's 1 Nov 06:07 decision), E (L5 parked + lockfile), G4 (Integrity Gauge), I2 (install + Chrome of S1b), then J3. A parked item stays in its place until the founder says skip or do it; nothing later starts before that.
1. One letter at a time: green on the server + live in his Chrome before the next letter starts.
2. No duplicate: PQM = Q4, attachments = Q2/Q3, WebTransport = K6; PQN only adds on top.
3. Open decision (founder): Q2 "instant dedupe" vs end-to-end encryption in PQN0.
