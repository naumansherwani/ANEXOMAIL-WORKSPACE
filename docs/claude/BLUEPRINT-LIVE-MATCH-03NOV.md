# Blueprint vs LIVE founder site (founder order 3 Nov 12:23 PKT) — checked in his Chrome 12:19-12:30
Method: every row of `BLUEPRINT-ABC-01NOV.md` compared with the live page text, headers and endpoints. Status words: LIVE = seen in his Chrome; NOT LIVE = blueprint says pending and the site agrees; MISMATCH = blueprint said GREEN, live disagrees (fixed in the blueprint the same turn).
| Row | Blueprint says | Live (his Chrome) | Result |
|---|---|---|---|
| A device approval + signatures | GREEN | Dashboard: 'Approved device Chrome on Windows'; write signature enforced (founder-install output) | LIVE |
| B Settings S1 | GREEN | Personal (name, photo, Lahore), Workspace, Appearance (text size, animations), Notifications tabs load | LIVE |
| C1 Polar Metrics token | GREEN (was) | Dashboard Billing: 'Polar webhook live, API metrics not connected' | **MISMATCH**: the founder DROPPED C1 (no token); Polar goes through the existing webhook into a ledger in letter O. Blueprint row now says DROPPED. Dashboard text is the honest state until O |
| C2 awam host guard | parked | n/a | parked |
| D UI stack | GREEN | bundle index-DsCUO6qP.js, hash router, shadcn look | LIVE |
| E loophole fixes | GREEN | headers: CSP, HSTS, nosniff, COOP, COEP, no-store LIVE; Permissions-Policy, X-Frame-Options, manifest/worker CSP were MISSING -> fixed in repo d804dd2e, needs founder-install | LIVE + 1 gap fixed (awaiting install) |
| F WASM kernel | GREEN | 'Answers verified', 'Signed answers: checked in this browser', '7 of 7 entries proven in this browser' | LIVE |
| G audit ledger G1-G5d | GREEN | Audit ledger page 'INTACT head #46'; Ledger seal #6 Ed25519 checked by kernel; Portable pin; Time anchor '3 TSA' | LIVE |
| H Time machine + Drift | GREEN | both tabs load, no error text | LIVE |
| I Appearance, Ambient Studio | GREEN | Appearance tab loads | LIVE |
| J1-J5 passkey | GREEN | Security keys panel, 'Laptop' key, Healthy | LIVE |
| J6 phone alerts | server GREEN, phone proof open | Phone alerts panel: 'No phone yet' | matches (phone proof open) |
| J hardware toggle (E142) | GREEN | 'Hardware keys: 0 of 2 needed', Laptop = platform | LIVE |
| K1, K2 | GREEN | not re-provable from here (sandbox openssl has no X25519MLKEM768; Chrome cannot read cipher) | proven earlier on his server; NOT re-proven now |
| K3 padlock on :8443 | pending | https://...:8443/healthz does not load in Chrome (error page) | NOT LIVE (matches). Likely firewall; `ufw allow 8443/tcp` is the plan's step |
| K4-K7, L, M | pending | none present | NOT LIVE (matches) |
| N-V, X | pending | Mail/People/AI/Systems/Control/Finance/Release/Move-In pages exist as read-only decks of the old features ('Real data from the original features ... Read-only'); Release shows 'Not measured'; AI settings 'coming, step 16' | NOT GREEN (matches); no fake data seen |
Note: the sidebar route id for Move-In is `move_in` (hash `#/move-in` falls back to the dashboard).
