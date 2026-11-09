# K7 DBSC — design + technology (written BEFORE the code, 9 Nov 2026 20:45 PKT; code landed the same evening)

**Founder order (9 Nov 20:28):** "likho repo ke top claude read katay, duniya ke super advance codes aur sql agar zarurat hai likho, duniya ka best kero meri website ke liye." Deadline K7 = 11 Nov.

## What DBSC is (checked 9 Nov 2026: developer.chrome.com DBSC page + Andrew Lock's write-up; W3C spec link could not be fetched)
Chrome (Chromium only) creates an ES256 key pair in the TPM / secure hardware (never exportable) and proves it on every refresh of a short-lived cookie.
A stolen cookie or login token is useless on another machine because it cannot refresh. Phones/Firefox/Safari do not take part: honest limit, written on the screen.

## Our shape (the founder token is a bearer in memory, not a cookie, so we bind the MINT of it)
1. `/founder/v1/exchange` (mints the 15-min founder token) answers an unbound approved device with `Secure-Session-Registration: (ES256); path="/founder/v1/dbsc/start"; challenge="<signed>"`.
2. Chrome POSTs `/founder/v1/dbsc/start` + `Secure-Session-Response` JWT (typ dbsc+jwt, ES256, key). No bearer on that request, so account + device are INSIDE the HMAC-signed 60-s challenge (minted only on an authenticated, approved exchange). Single use (SQL jti ledger).
3. We store the PUBLIC key (E149), answer the session JSON, Set-Cookie `__Host-anx_fdbsc` (10 min, Secure HttpOnly SameSite=Strict, no Domain).
4. Refresh: 403 + `Secure-Session-Challenge`, Chrome signs, we verify against the STORED key only (a key inside the JWT is ignored), consume jti, new cookie.
5. exchange: bound device without a valid cookie of ITS session -> `401 dbsc_required` (mode enforce). Unbound devices are never blocked.

## Modes (env FOUNDER_DBSC, script `docs/cursor-work/server/founder-dbsc.sh`)
`off` (binary default, routes 404) -> `observe` (registers, refreshes, ledger, would_block logged, never blocks) -> `enforce` (ONLY with his word). Rollback = MODE=off.

## Technology (Rule 70)
- Rust: `server/founder/src/dbsc.rs` (ring ES256 verify, hmac/sha2, axum routes start/refresh/status), wired in `main.rs` (St.dbsc, exchange gate + registration header). 10 unit tests (forged challenge, wrong key, alg none/HS256, typ, jti, iat, aud, tampered payload, cookie forgery/expiry, decision matrix). Full suite 256 pass.
- SQL: `E149_founder_dbsc.sql` + `CHECK_E149.sql` (8 rows). Sessions (frozen core, one-way revoke, one active per device), jti replay cache, SHA-256 hash-chained append-only event ledger (advisory lock, reject spam capped), trigger that ends bound sessions when a device is revoked, RPCs service_role only with pinned search_path + statement_timeout, behaviour selftest that rolls back. Tested in pglite twice (idempotent).
- React-TS UI: `Dbsc.tsx` (fetch, every 30 s) + `DbscCard.tsx` (pure card) + `dbsc_pure.ts` (+5 bun tests) inside Settings > Privacy under Security keys. One build, all sizes: measured 390 / 820 / 1280 in the sandbox: no sideways scroll, 0 touch targets under 44 px (the card has no buttons).
- No kernel change: NO awam pull needed. No WebSocket, no Bun/Node at runtime.

## GREEN means (WIRED: YES / REAL: YES)
E149 + CHECK_E149 green on his server; new binary installed; `founder-dbsc.sh MODE=observe`; a REAL Chrome with a TPM signs in and the card + ledger show `registered` then `refreshed` (his paste of CHECK_E149 + the card seen on his laptop and phone at 390/820/1200+). `enforce` is a separate step with his word.

## UPDATE 09 Nov 2026 21:15 PKT: his order = EVERY browser and phone (verbatim: "yeh her browser aur Phone aur Firefox/Safari par ye kaam kerna chaiye hain woh bhi live wire working ke saath")
Truth first: the DBSC PROTOCOL (Secure-Session-Registration / Secure-Session-Response) is implemented only by Chromium today. Firefox and Safari have no implementation, so no server code can make DBSC "work" there. What CAN work everywhere is the same security property with the same ledger:
- **K7a (done in repo): DBSC** for Chrome/Edge with secure key storage (TPM). Hardware-bound key, browser-driven refresh.
- **K7b (next, same ledger E149, same deadline): WebCrypto device key.** Every browser (Chrome, Edge, Firefox, Safari, Android, iPhone) makes an ECDSA P-256 key with extractable:false (WebCrypto, kept as a CryptoKey in IndexedDB, the private bytes can never be read, not even by the page). Exchange sends a signed server challenge (60 s, single use, same jti ledger) as proof; the server verifies against the stored public key (same ES256 code path in dbsc.rs) and writes registered/refreshed rows with kind source 'webcrypto'. A stolen login + device id replayed from another machine cannot sign. Honest limit: this key lives in the browser profile (software), not the TPM; malware ON the same device could still ask the browser to sign. Hardware strength on phones comes from the passkeys already in the product (Secure Enclave / StrongBox, J4).
- Mode enforce applies per device by its strongest proof (dbsc > webcrypto); a device with no proof yet is never blocked, it is invited to bind at its next exchange.
- Rule 52: the proof payload is built by a tiny pure TS helper + the browser's own WebCrypto signing (a CryptoKey cannot live in WASM); verification stays in Rust on the server. Said plainly, no pretence.
- GREEN for K7 = ledger rows from a real Chrome (DBSC), a real phone and one more browser (Firefox or Safari), plus the card on 390 / 820 / 1200+.

## Where he takes the phone screenshot
After founder-install (new SPA) and founder-dbsc.sh observe: founder site on the phone > More > Settings > Privacy tab > scroll under Security keys to the card "Device-bound sessions". Screenshot that card (it lists each device and Bound / Not bound).

## K7b BUILT (09 Nov 2026 23:09 PKT): device key for every browser and phone
- No challenge round trip (DPoP-style): proof JWT = header {alg ES256, typ dbsc+jwt, jwk only at registration}, payload {jti random nonce (single use, E149 jti ledger >= 1 day), iat within 120 s, aud = the exact route, dh = sha-256 of the device id}. Replay-proof, route-bound, device-bound.
- Browser: `founder-web/src/devicekey.ts` (WebCrypto ECDSA P-256, extractable=false, CryptoKey in IndexedDB) + `devicekey_pure.ts` (proof builder, tested against node crypto verify, raw r||s). Hooked in `api.ts` exchange: sends `x-device-proof` when the device has a key; when the server answers `dk.bound=false` with mode != off it makes the key and registers (fire and forget, never breaks sign-in).
- Server: `dbsc.rs` verify_proof + route POST /founder/v1/devicekey/register (session token + proof); exchange accepts the proof instead of the cookie for a device bound by webcrypto (consumes the nonce, counts a refresh). dbsc outranks webcrypto (E150 register_src: a software key never replaces a secure-chip session).
- SQL: `E150_founder_devicekey.sql` + `CHECK_E150.sql` (source column frozen, register_src, device_state with source+key, devices + report by_source, selftest that rolls back and looks only for its own device).
- Card: shows 'Bound by the secure chip' or 'Bound by a browser key'.
- Install order matters: SQL E150 first, then founder-install (the new Rust calls founder_dbsc_register_src).
- Tests: cargo 258 pass (+2 K7b), bun 148 pass (+4), pglite E149 + E150 twice, CHECK 8/8 + 7/7.
