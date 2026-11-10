> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# AWAM PASSKEY-ONLY PLAN (ORDER (his 21:23): founder first, this block starts AFTER the founder blueprint is complete (26 Nov+), D1 Devices & Sessions comes first; audit docs/claude/AWAM-PASSKEY-AUDIT-10NOV.md) (10 Nov 2026 21:08 PKT, founder order 21:07)
**His words:** awam passkey is REQUIRED; from MARCH 2027 the awam password is retired, sign-in = passkey only. The founder passkey code is copied for awam as REFERENCE (founder and awam are NEVER mixed: awam gets its own Rust door + its own SQL numbers; nothing is imported from the founder binary; the copies live only in `docs/claude/awam-passkey-reference/*.txt`, not in any build). Awam has NO 2FA at all (passkey = the first and only step).
## Honest note on "HMAC-256 passkey"
A passkey is NOT an HMAC: it is an asymmetric key pair (the private key never leaves the phone/key, the server stores only the public key; ES256 / EdDSA signatures, origin-bound so a phishing site cannot use it). That is already the strongest login there is. HMAC-SHA256 is used on top where it belongs: tickets and network hashes (HMAC-SHA256 with a server key), and the WebAuthn **PRF extension** (CTAP hmac-secret: the authenticator returns an HMAC-SHA256 secret bound to that passkey) for an OPTIONAL device-bound session secret. Sources: Chrome shipped PRF (blink-dev intent to ship), Yubico PRF docs, Bitwarden PRF article. Caveat from the same sources: PRF output can differ/vanish across synced passkeys and some managers, so it is NEVER the only gate and NEVER used as the only key to data.
## Awam phases (fill the GREEN stamp when each is live-proven, WIRED: YES / REAL: YES)
| # | Phase | Technology | Target | GREEN |
|---|---|---|---|---|
| AP1 | Remove every awam 2FA/TOTP screen and the "passkey with password" rule | awam UI + Rust | 26-28 Nov | ______ |
| AP2 | Awam SQL (own numbers): ceremony ledger, credential door by id with catalog posture proof (copy of E151/E154 pattern), password-fail ledger | SQL | 29 Nov | ______ |
| AP3 | Awam Rust door: passkey begin/finish, fair ceremony store, mint session, same generic 401, journald stage lines, warm database pool | Rust axum/tokio | 1-3 Dec | ______ |
| AP4 | Awam sign-in UI: passkey button as first option (existing awam look untouched) | React 19.2 | 4-5 Dec | ______ |
| AP5 | Enrol flow on first sign-in + MINIMUM 2 passkeys per account + recovery codes (so a lost phone never locks a company out) | Rust + SQL + UI | 6-9 Dec | ______ |
| AP6 | PRF optional device-bound secret (observe first, never the only gate) | WebAuthn PRF + Rust | 10-11 Dec | ______ |
| AP7 | Live proof 390/820/1200+ with real phone + laptop passkeys | live | 12-14 Dec | ______ |
| AP8 | PASSWORD RETIREMENT: switch off password sign-in for awam (his plan: MARCH 2027; code ready by 16 Dec, switch = his word + a date, with rollback) | SQL word + Rust | March 2027 | ______ |
Rule for AP8: the password door is closed only after every active account has 2+ passkeys or a recovery path; otherwise users are locked out. Said plainly to him before the switch.

## AP9 (added 11 Nov 2026 00:45 PKT, his question): AWAM DEVICES & SESSIONS (blueprint line, GREEN stamp blank, waits for founder-complete)
Awam gets the same advanced engine as the founder D1/D2 (E155/E156 design: session registry, per-request check, idle + absolute lifetime, device drift, flap detection, session cap, kill-all-others, tamper-evident ledger with anchor), MOULDED for awam: its own tables and own SQL numbers (never the founder tables or binary, SEPARATION LAW), per-user not per-founder, a customer-friendly "Your devices" card (revoke one / sign out everywhere, new-device alert), a plan-based live-session cap, location lock OFF by default (optional, customers travel), no 2FA, no founder wording. Written from the proven founder code as reference, after the founder blueprint is complete. WIRED: ___ / REAL: ___ / 390: ___ / 820: ___ / 1200+: ___ / date: ___

- 11 Nov 2026 00:50 PKT AP9 update: founder D2b Rust plan written (docs/claude/G-MIX-D2B-PLAN-11NOV.md). Awam copy later = same module shape, awam tables, per-user principal, plan-based cap, wording for customers. Stamp blank.

- 11 Nov 2026 01:05 PKT AP9: founder D2b Rust is written (sessions.rs shape: sid hash, families, cache, register-before-token, gate check, signed write failures feed a streak). Awam copy later = same module with awam tables and per-user principal. Stamp blank.

- 11 Nov 2026 01:15 PKT AP9 UI line: awam "Your devices" card = the same D3 anatomy in customer wording (this device, list, sign out one / everywhere, new-device alert), no ledger jargon, no location-lock by default. Stamp blank.

- 11 Nov 2026 01:30 PKT AP9 UI: founder D3 plan written (docs/claude/G-MIX-D3-PLAN-11NOV.md): Trust Ring, live rows, two-step close, alert strip, ledger timeline, honest states. Awam copy = same pure module + customer labels. Stamp blank.

- 11 Nov 2026 01:45 PKT AP9 UI: founder D3 screen written (sessions_pure.ts logic is label-free: awam copy swaps Founder wording only; Devices.tsx anatomy = Trust Ring, rows, two-step close, ledger). Stamp blank.

## AP9b (11 Nov 2026 01:52 PKT, his order 01:36): PRESERVE THE D-SERIES FOR AWAM + step-up policy change (blueprint line, GREEN stamp blank)
- ALL founder D-series code is PRESERVED for awam and will be reused LATER, moulded for awam (not now, not copied blindly): SQL E155/E156/E157 -> awam_session_* tables with their own numbers; server/founder/src/sessions.rs -> awam module (per-user principal, plan-based cap); founder-web sessions_pure.ts + Devices.tsx + devices.css -> awam "Your devices" in customer words; the passkey touch for a policy change -> awam "confirm with your passkey" (passkey only, NO 2FA ever). Plan: docs/claude/G-MIX-D2B5-PLAN-11NOV.md. Stamp blank until founder-complete.
- 11 Nov 02:58 AP9: Aurora seal hero becomes awam 'Your devices' look later (RULE 9)
- 11 Nov 03:20 RULE 9 (awam AP9): awam inherits K8 transport (h2/h3/ML-KEM/kernel RPC) when molded (K5b)
