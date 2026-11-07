# CLOSE THE GAPS (founder 7 Nov 2026 15:36: "adhoora kaam nahi kerna hai, jaise bhi kerna hai steps batao")
Every row below was marked GREEN while only partly real. Each becomes truly GREEN (wired + really working, with proof) or stays here. Claude does what Claude can; what needs his hands is ONE numbered step at a time.

| # | Gap | What closes it | Who | Technology | State |
|---|---|---|---|---|---|
| G1 | Android phone not added to alerts (J6) [17:25: code DEPLOYED on his server (Add fingerprint, Alert number); E146 GREEN wired+real 4/4; phone proof still missing] | Settings > Privacy > Phone alerts: name it, Add (allow notifications, touch the key), Send test, tap the alert | HIS PHONE (step given) | Web Push + service worker | OPEN |
| G2 | Vault key encrypts nothing (J8d) | First consumer: the session snapshot kept in the browser is sealed with AES-256-GCM under the vault key while a lease is live and unreadable after the lease ends; proof by a test + live Chrome (snapshot is ciphertext, comes back after renew, gone after lock) | CLAUDE | React-TS + WebCrypto AES-GCM + kernel key | NEXT |
| G3 | T3 / panic lock never run for real | Needs TWO trusted hardware keys (two FIDO2 keys, allow-listed with "Trust this model"), then the real flow: start (key 1) -> wait 10 min -> approve (key 2) -> confirm; test on a spare device first so no real device is locked by mistake | HIS HANDS + Claude | SQL E118/E145 + Rust + WebAuthn | OPEN (needs keys) |
| G4 | Real site on :443 still Caddy (AES-128 first) | K4.3 cert refresh, K4.4 SNI front, K4.5 live switch (his haan, rollback ready), K4.6 CHECK + Chrome | CLAUDE + his haan | Rust rustls + Caddy + SQL E119 | IN PROGRESS |
| G5 | ANEXOChat files/quotas have no founder screen | A read-only founder panel from the real SQL (per-organisation file usage vs quota, plan caps, the Premium 21,000 cap) with the same wired/real proof | CLAUDE | SQL read + Rust + React-TS | OPEN (after G2) |
| G6 | Only Settings > Privacy proven on a phone | His phone screenshots of Home, Bridge, Finance, People, Mail, AI, Systems, Control, Release, Move-In, Audit, Profile, Settings tabs; Claude fixes each crowded screen the same way (same code, only spacing) | HIS PHONE one screenshot at a time + Claude | CSS | OPEN |
| G7 | Real tablet (820) never seen | His tablet, or laptop Chrome DevTools device mode (F12, device toolbar, iPad, width 820): screenshots of the same tabs | HIS SCREEN | CSS | OPEN |
Order: G1 now (2 minutes on his phone) while Claude writes G2; then G4 (K4.3..), G5, G6/G7 as his screenshots arrive, G3 when he has two keys.

## GREEN with proof (moved out of the open list)
- E146 banned countries + alert-number wall, 7 Nov 2026 17:25 PKT: WIRED: YES / REAL: YES. Proof: his sql-run output CHECK_E146 4/4 OK, founder-install OK (healthz 200, Ed25519 ON), awam pull OK (build OK, server==repo 610/0/0), repo 7a87410e. Not yet seen on a phone/Chrome, so the SCREENS (Add fingerprint, Alert number) stay OPEN under G1 until his screenshot + live bundle hash = repo build.
