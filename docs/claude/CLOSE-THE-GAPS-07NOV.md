# CLOSE THE GAPS (founder 7 Nov 2026 15:36: "adhoora kaam nahi kerna hai, jaise bhi kerna hai steps batao")
Every row below was marked GREEN while only partly real. Each becomes truly GREEN (wired + really working, with proof) or stays here. Claude does what Claude can; what needs his hands is ONE numbered step at a time.

| # | Gap | What closes it | Who | Technology | State |
|---|---|---|---|---|---|
| G1 | CLOSED 7 Nov 19:30 GREEN wired+real (his screenshots) - was: Android phone not added to alerts (J6) [17:25: code DEPLOYED on his server (Add fingerprint, Alert number); E146 GREEN wired+real 4/4; phone proof still missing] | Settings > Privacy > Phone alerts: name it, Add (allow notifications, touch the key), Send test, tap the alert | HIS PHONE (step given) | Web Push + service worker | OPEN |
| G2 | Vault key encrypts nothing (J8d) | First consumer: the session snapshot kept in the browser is sealed with AES-256-GCM under the vault key while a lease is live and unreadable after the lease ends; proof by a test + live Chrome (snapshot is ciphertext, comes back after renew, gone after lock) | CLAUDE | React-TS + WebCrypto AES-GCM + kernel key | NEXT |
| G3 | T3 / panic lock never run for real | Needs TWO trusted hardware keys (two FIDO2 keys, allow-listed with "Trust this model"), then the real flow: start (key 1) -> wait 10 min -> approve (key 2) -> confirm; test on a spare device first so no real device is locked by mistake | HIS HANDS + Claude | SQL E118/E145 + Rust + WebAuthn | OPEN (needs keys) |
| G4 | Real site on :443 still Caddy (AES-128 first) | K4.3 cert refresh, K4.4 SNI front, K4.5 live switch (his haan, rollback ready), K4.6 CHECK + Chrome | CLAUDE + his haan | Rust rustls + Caddy + SQL E119 | IN PROGRESS |
| G5 | ANEXOChat files/quotas have no founder screen | A read-only founder panel from the real SQL (per-organisation file usage vs quota, plan caps, the Premium 21,000 cap) with the same wired/real proof | CLAUDE | SQL read + Rust + React-TS | OPEN (after G2) |
| G6 | Only Settings > Privacy proven on a phone | His phone screenshots of Home, Bridge, Finance, People, Mail, AI, Systems, Control, Release, Move-In, Audit, Profile, Settings tabs; Claude fixes each crowded screen the same way (same code, only spacing) | HIS PHONE one screenshot at a time + Claude | CSS | OPEN |
| G7 | Real tablet (820) never seen | His tablet, or laptop Chrome DevTools device mode (F12, device toolbar, iPad, width 820): screenshots of the same tabs | HIS SCREEN | CSS | OPEN |
Order: G1 now (2 minutes on his phone) while Claude writes G2; then G4 (K4.3..), G5, G6/G7 as his screenshots arrive, G3 when he has two keys.

## GREEN with proof (moved out of the open list)
- E146 banned countries + alert-number wall, 7 Nov 2026 17:25 PKT: WIRED: YES / REAL: YES. Proof: his sql-run output CHECK_E146 4/4 OK, founder-install OK (healthz 200, Ed25519 ON), awam pull OK (build OK, server==repo 610/0/0), repo 7a87410e. Not yet seen on a phone/Chrome, so the SCREENS (Add fingerprint, Alert number) stay OPEN under G1 until his screenshot + live bundle hash = repo build.

## 7 Nov 17:55 G1 root cause + fix (built, not green)
Root cause: a second key is a T2 step-up proved by an EXISTING key; the phone has no key, so its browser asked for one it does not have (the 'Choose which device has your passkey' screen). Fix: E147 `founder_passkey_pending`, Rust `GET /founder/v1/passkey/pending`, `/passkey/finish` accepts an approver on another approved device, UI: phone 'Add fingerprint' parks the registration, any device with a key shows 'Waiting for approval' + Approve (5 min, expires by itself, no key body ever listed). GREEN needs: his sql-run (E147 CHECK 2/2), founder-install, the real round trip on his phone + laptop, live bundle = repo.

## 7 Nov 18:10 G1 status
E147 GREEN (WIRED YES / REAL YES): his sql-run CHECK_E147 2/2 OK, founder-install OK, live Chrome bundle index-B0BeZYkT = repo build with the feature, /founder/v1/passkey/pending live (401 without token). OPEN: the real round trip on his phone + laptop (phone Add fingerprint -> laptop Approve -> phone Add this phone / Send test), then 390/820/1200 look. Until his screenshot G1 stays open.

## 7 Nov 18:30 G1 simplified UI
Phone alerts = one Turn on button (auto name); Keys = Add this device's fingerprint + Add security key. Server unchanged. GREEN needs his phone round trip.

## 7 Nov 2026 18:35 PKT STATE (written before a compaction)
- CLOSED with proof: second key via the E147 approval flow (his key 'Muhammad Nauman Khan Sherwani', platform, synced, 2/5 keys, seen in my Chrome 18:07); E146 banned countries (AF IL KP SY) GREEN; Alert number saved (record + recovery only, reply-confirmation NOT built); Android vault lease running (#11, his 6:10 PM screenshot).
- G1 STILL OPEN: Android phone not listed in Phone alerts; no real alert received on the phone. His next step: phone -> Settings > Privacy > Phone alerts > 'Turn on' -> Allow -> fingerprint -> 'Send test' -> screenshot.
- Live bundle = repo: server index.html names index-KKNYbdOm.js (= repo dist), after his founder-install 18:25.
- G2 vault-key consumer next (seal the session snapshot with AES-256-GCM under the live vault key), then G4 K4.3.., G5, G6, G7, G3 (needs 2 hardware keys). Syria Caddy wall waits for his 'haan'. Email question 1/2 unanswered (default letter order).

## 7 Nov 18:50 G1: empty alert
SW v2 built (never an empty notification, reason code in odd pushes, update on card open) + real-worker test. GREEN needs his phone to show a readable 'Test alert / Phone alerts work.'.

## 7 Nov 19:05 G1: empty alert, observability
Worker records last received alert; card shows it. GREEN needs his phone screenshot.

## 7 Nov 19:15 G1
Alert worker v2 + 'Last alert' row LIVE = repo (his install, my Chrome fetch). OPEN: his phone Send test + screenshot (notification + Last alert row) decides whether the emptiness was content or display.

## 7 Nov 19:00 G1 CLOSED for delivery; tap fix open
G1 delivery GREEN (his screenshots: Android listed + confirmed, readable alert). Remaining G1 item: notification TAP (worker v3 built). Then 390/820/1200 look of the card.

## 7 Nov 19:20 G1
Worker v3 live = repo. Only open G1 item: his tap screenshot ('You opened this alert'). Then the 390/820/1200 look of the Phone alerts card, then G2.

## 7 Nov 19:30 G1 CLOSED
- 7 Nov 2026 19:30 PKT: G1 CLOSED = GREEN, WIRED: YES / REAL: YES. Proof = his phone screenshots 6:50-6:51 PM: lock-screen alert 'Test alert / Phone alerts work.'; he TAPPED it and Chrome opened the founder Settings > Privacy page scrolled to Phone alerts with 'You opened this alert: Test alert (tick) - The alert reached this phone and the tap brought you here. Phone alerts work end to end.'; list shows 'Chrome on Windows (desktop)' AND 'Chrome on Android (this device)', both 'Confirmed via fcm.googleapis.com, last receipt just now'. Seen: 390 (his phone) + 1200+ (my Chrome); 820 tablet = G7. Chain of fixes that closed G1: Add fingerprint (platform key), E147 approval from a trusted device, E146 banned countries + Alert number, simple one-tap UI, worker v2 (never empty), v3 (tap). NEXT = G2 vault-key consumer (technology below in the NEXT PHASE block).
G2 is now the open item in progress.

- 7 Nov 2026 19:40 PKT G2: CODED + BUILT, not GREEN (needs his install + Chrome proof).

- 7 Nov 2026 19:50 PKT G2: install done, purge fix built (index-D5tAR5ZQ), NOT GREEN until reinstall + Chrome proof.
