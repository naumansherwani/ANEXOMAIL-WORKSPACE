# AWAM PASSKEY-ONLY PLAN (10 Nov 2026 21:08 PKT, founder order 21:07)
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
