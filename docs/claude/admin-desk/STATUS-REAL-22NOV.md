# ADMIN DESK: WHAT IS REAL, WHAT IS CODE-ONLY, WHAT IS PLAN-ONLY (22 Nov 2026 01:47 PKT, his 01:47 order)
Rule: only "LIVE" counts as working. Matched against the repo (files named) and his server pastes.

## A. LIVE and proven (his server paste or my live check)
| Item | Proof |
|---|---|
| Desk own process anexomail-desk on 127.0.0.1:4400, own user, own unit | his desk-install pastes 21 Nov 08:58, 22 Nov 01:39 (health 200, wrong host 404) |
| Public https via Caddy + front, host admindesk.anexomail.com | his paste: HTTP/2 200 from Caddy (browser path) |
| Desk's own HTTP/3 server on UDP 4400 (PQ X25519MLKEM768, AES-256-GCM) | H3CHECK OK (21 Nov), ufw 4400/udp; BROWSER still h2 (not proven) |
| Alt-Svc header h3=":4400" | his paste 01:39 (alt-svc present) |
| Landing page + login page (eye, Save password) | on his server; his look on the new login pending |
| SQL AD1 + AD1b, owner admindesk@, desk_app DB login, ARGON2ID door | his paste: "database login live (desk_app), sign-in door ready" |
| His first real sign-in | he is signed in (his words 01:00) |
## B. CODE WRITTEN + TESTED, NOT LIVE yet
| Item | State |
|---|---|
| R3d Rule 52 (signed doors, own WASM kernel, deskCall, real /me dashboard, signing key step) | pushed 22 Nov 01:38; Rust 19/19, kernel 4/4, Playwright tamper refused. HIS PASTE AT 01:39 SHOWS THE OLD SCRIPT RAN (no "Rule 52:" line, "== 4/4" first line of tail -15): it ran before/without the new script. Inference from his paste, nothing broke. FIX: rerun the same pull command once. |
## C. PLAN ONLY (no code): everything else
R4-1 shell + bridge; inboxes (AD2 fadm_mailbox); auto mail; assign/reply/SLA; compose..shortcuts; attachments/outbound TLS/OpenPGP; DBSC; orb pulse/zoom; S1..S11 (50k staff); W1..W10 (world-advance); ON1..ON12 (employee accounts); Premium/Max (E201 + test domain); anexochat/anexovideo AAAA; browser real HTTP/3 proof.
## Numbers (honest)
- "Desk complete" = the 12 rows in REMAINING-LIST-22NOV.md: green = 1 (row 2 first sign-in); row 1 half (header live, browser still h2); row 3 code done, not live. So 1.5 of 12 = about 12%.
- Whole written plan (12 rows + S1..S11 + W1..W10 + ON1..ON12 = 45 lines): live = 1.5 lines, code-only = 1, plan-only = 42.5. About 3% live.
- The BASE under it (process, TLS, HTTP/3 server, SQL, login, owner) is live and real; that is why the rest can be built fast.
## Record fix
Ledger lines written 01:3x-01:4x carried hand-typed times 02:05 to 02:55 PKT by my mistake (real clock 01:3x-01:4x). Real times are in git commit dates. From now every stamp comes from the clock.
