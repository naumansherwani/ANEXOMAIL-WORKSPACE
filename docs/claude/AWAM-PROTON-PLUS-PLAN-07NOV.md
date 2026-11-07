# AWAM PLAN: everything a Proton-class product has, and then more (founder 7 Nov 2026 19:27 PKT)
His words: "Proton se aagay ka hi plan phases mein dalo; features aur technology SIRF mere Anexomail mein AWAM side mein dalo, jab FOUNDER ka kaam finish hoga." and "jab product banega to user mere paas hi aayega".
RULES: (1) NOTHING here starts before the founder lane is finished (after X). (2) These are AWAM-lane phases (AX-*). Founder code never imports them and they never import founder code (Rule 73). (3) Every awam change is delivered with the separate awam pull command (SHARED-CODE RULE). (4) Each phase is GREEN only with wired + real proof and is seen on 390 / 820 / 1200+ (Rule 34). (5) The founder side keeps only the CONTROL of these (kill switch, trust map, audit), never the features.
Honest base: Proton has years of audits, open-source clients and a real user base. The plan below is how Anexomail matches each product AND adds something Proton does not have. Marked "NEW" = beyond Proton.

| Phase | Product | Match (what Proton has) | NEW: beyond Proton | Technology (layer) |
|---|---|---|---|---|
| AX-P1 | Mail with zero-access encryption | end-to-end encrypted mail, encrypted at rest | post-quantum OpenPGP (ML-KEM hybrid) from day one; sealed agreements (Q6); delivery proof anyone can verify | Rust + WASM kernel (PQ) + SQL ledgers + React-TS (this is founder Q1-Q6 made user-facing) |
| AX-P2 | Calendar + Contacts, encrypted | encrypted calendar, contacts | same PQ keys; per-event signed audit | Rust + SQL + WASM kernel |
| AX-P3 | Drive (files) | encrypted file storage and sharing | resumable parallel chunks over WebTransport; every share link signed and expiring; dedupe without leaking content | Rust + wtransport (K6) + SQL (ANEXOChat file engine 13-15+61 already built) |
| AX-P4 | Pass (passwords + passkeys) | password manager, passkeys, 2FA codes | vault opened only by a live device lease (J8) and hardware key; dead-man crypto-shred | WebCrypto + WASM kernel + SQL + Rust |
| AX-P5 | VPN | no-log VPN | post-quantum key exchange in the tunnel; device-bound (DBSC-style) tunnel credentials | WireGuard + hybrid PQ handshake (Rust) + SQL |
| AX-P6 | Docs + Sheets (WOPI) | encrypted docs | co-edit with signed change history | Rust WOPI host + React-TS |
| AX-P7 | Private AI assistant | on-device / zero-retention AI | founder-visible audit of what the AI may read; never trained on user data | Rust + React-TS |
| AX-P8 | Account protection (Sentinel class) | risk engine, alerts | session bound to the device key (K7 DBSC), hardware-key recovery rule, trust map per user | SQL + Rust + passkeys |
| AX-P9 | Calls / live media | encrypted meetings | Media over QUIC relay of our own (M), PQ-secured | Rust + wtransport/MoQ + WASM kernel |
| AX-P10 | Transparency | open source clients | served-code seal (X3) + key transparency log + supply-chain board (X4): the user can verify the code they were served | Rust + SQL (Merkle) + WASM kernel |

Order inside AX: P1 (mail, because it is the core product) -> P3 -> P4 -> P2 -> P8 -> P10 -> P9 -> P6 -> P5 -> P7. The founder lane order stays: G2 -> G4 -> G5/G6/G7 -> K5 -> K6 -> K7 -> L -> M -> N -> O -> P -> Q -> R -> S -> T -> U -> V -> X -> then AX-P*.

## RESEARCH (7 Nov 2026 19:35 PKT, Proton's own roadmaps: proton.me/blog/2026-spring-summer-roadmaps and proton.me/blog/2026-autumn-winter-roadmaps)
What Proton ships or is shipping, and the AX phase where Anexomail MATCHES it (awam gets all of it) and then goes BEYOND it.
| Proton product | What they have / are building (2026) | AX phase that matches it | Beyond Proton (NEW) |
|---|---|---|---|
| Mail | categories (Primary/Social/Promotions/Newsletters/Transactions/Updates), send+receive from a Gmail address, full-body on-device search on mobile, merge accounts | AX-P1 | PQ OpenPGP; sealed agreements; verifiable delivery proof; search index that is itself encrypted and device-lease bound |
| Calendar | rewrite, offline mode, appointment booking pages, default calendar on Android | AX-P2 | signed booking pages (invitee can verify the host); per-event audit |
| Drive | faster up/down via SDK, folder sync macOS, Linux beta (headless daemon), Easy Switch from Google Drive, shared Drive for families/teams, wider search | AX-P3 | parallel resumable chunks over QUIC; signed expiring share links; Easy Switch for Google AND Proton AND Dropbox |
| Docs / Sheets | table of contents, dark theme, page breaks, ODT import/export, mobile editing, tables, quick stats | AX-P6 | signed change history; co-edit with per-user key |
| Pass | iFrame autofill, folders, SSH agent with biometric, share logins without revealing passwords, expiring shares/vaults, Monitor v2, credential exchange, org policies, vault transfer on off-boarding | AX-P4 | vault opened only by a live device lease + hardware key; dead-man crypto-shred; two-hardware-key rule for recovery |
| VPN | new client codebase, Linux GUI, stealth protocol, kill switch, pause/resume, country/city exclusion | AX-P5 | PQ handshake; device-bound tunnel credentials; kill switch tied to the account trust map |
| Meet | waiting rooms, chat threads (Oct 2026) | AX-P9 | own MoQ relay; PQ media keys |
| Lumo AI | Lumo API, desktop + mobile apps, creations canvas, Apertus model | AX-P7 | founder-visible audit of what the AI may read; zero-retention proof |
| Wallet, Authenticator, Business (SCIM, admin roles, free subdomains) | exists | AX-P4 (Authenticator inside Pass), AX-P8 (Business admin, SCIM) | trust map per user and per org |
| Sentinel (account protection) | risk engine | AX-P8 | session bound to device key (DBSC), hardware-key recovery |
Honest note: Proton's real lead is audits, years of trust and open clients. Anexomail's answer is AX-P10 (served-code seal + key transparency + supply-chain board) so the user can VERIFY, not just trust. Nothing here is built yet; no phase of this table is claimed GREEN.
Sources: https://proton.me/blog/2026-spring-summer-roadmaps , https://proton.me/blog/2026-autumn-winter-roadmaps
