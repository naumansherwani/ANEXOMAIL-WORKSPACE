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
