# SANDBOX LIVE TEST, REAL BINARY + REAL POSTGRES (22 Nov 2026 01:59 PKT, his 01:57 order)
Setup: real anexomail-desk binary, real Postgres 16 with his AD1 + AD1b SQL and AD1 selftest, owner created with the binary's own ARGON2ID hashpw, role desk_app, signing key, real headless Chrome (Playwright) at 390 / 820 / 1280. No mocks.
| Test | Result |
|---|---|
| Wrong password | 401, answer SIGNED, page says "did not match", no session stored |
| Real login | 200, answer signed, body only token + expires_in, cookie HttpOnly Secure SameSite=Strict |
| Dashboard 390/820/1280 | real email, role Owner, session end; no sideways scroll; no console errors |
| Reload | session kept, fresh nonce + MAC accepted |
| Forged MAC | 401 bad_mac (signed) |
| Sign out | goes to /adminlogin, old token then 401 |
| Tampered login answer | page: "The answer from the server could not be trusted", NO session stored in the browser |
| Installer step-5 check | without nonce 400, with nonce 401 (the fixed script wants 401) |
| Ledger | login.ok rows written |
Bugs found and fixed in this test: (1) "Session ends" showed raw Postgres time (offset +05 without minutes), now parsed and shown as a local date; (2) tiles touched the heading (margin), now 32 px at all three widths.
Honest note: the tampered login was refused by the browser, but the SERVER had already created that session row (12 h, token never kept). Harmless; a later phase (ON3) binds the token to the device so such a row is useless.
Not tested here: his real Supabase TLS DB, Caddy, HTTP/3 in a browser, his phone.
