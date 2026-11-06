# GREEN LIST (6 Nov 2026 20:15 PKT) — sent to the founder; truth source = the GREEN LEDGER in `BLUEPRINT-ABC-01NOV.md`
GREEN = his pasted server output + my own Chrome look. The last column is the honest gap he pointed at (6 Nov 20:09): mobile and tablet were never proven live for most phases.

| Letter | What is GREEN | Proof | Phone / tablet |
|---|---|---|---|
| A | Device approval + signatures | Chrome 3 Nov; his phone approved 6 Nov 19:45 ("Chrome on Android") | phone SEEN (his screenshot 7:31 PM: approval card fits); tablet not seen |
| B | Settings S1 | E108 + Chrome 3 Nov 12:19 | desktop only |
| D | UI stack (React 19, TS, Tailwind 4, shadcn, TanStack Router) | commit 425ec14, bundle live | phone SEEN on Bridge (7:59 PM screenshot); tablet not seen |
| E | Loophole fixes L1-L12 (L5 parked, lockfile open) | his install + Chrome 3 Nov 12:50 (headers) | n/a (server) |
| F | WASM kernel verify | Chrome 3 Nov 12:19 "Answers verified" | desktop only |
| G | Audit hash-chain + Merkle + seals + anchors + portable (G1-G5d) | G5d 3 Nov 08:25, Chrome seal #6 | desktop only |
| H | Settings S2 | server + Chrome 3 Nov 11:02 | desktop only |
| I | Appearance, Ambient Studio | 3 Nov 08:58 | desktop only |
| J1-J5 | Passkey, step-up, protocol (E117, E118, E139) | 3 Nov 09:44 | desktop only |
| J | Hardware toggle (E142) | his paste + Chrome 3 Nov 12:19 | desktop only |
| J | Device exchange fixes: per-device limiter + a lock never blocks an approved device + real browser names | his installs 6 Nov 19:42 and 20:09 (service alive, token ON, signature ENFORCED); phone banner gone: his reload NOT yet confirmed | phone: confirm pending |
| J6 | Phone alerts (E140, E141, flare.rs, panel) | desktop Chrome 3 Nov 13:25 with his key touch | REAL PHONE PROOF OPEN (phone is now approved, next step is Add + allow notifications) |
| K1, K2 | Post-quantum key exchange; AES-256 terminator on :8443 | earlier server openssl; prober rows 1 Nov | n/a (server) |
| K3 | Padlock on :8443 | his ufw paste + my Chrome 3 Nov 13:55 (note: /_cc 404 on that test port, fixed in K4) | n/a |
| ANEXOChat 13-15 + 61 | File engine, chart 500 MB / 1.5 GB / 4 GB, monthly quota, Premium 21,000 cap | his paste 3 Nov 13:48 (CHECK all OK, E65 OK) | n/a (SQL) |

NOT GREEN: J8, K4-K7, L, M, N, O, P, Q, R (+R3), S, T, U, V, X, J7, J9. DROPPED: C1 (Polar token; Polar goes through letter O).

## OPEN GAP (his words 6 Nov 20:09): "itne phases ka kaam mobile aur tablet ke bina kiya hai"
Before J8, a mobile + tablet pass over every founder tab (Rule 19/34): 390 px and 820 px, touch targets 44 px, no sideways scroll, nothing cut off, every panel readable, NO empty screens. Method: his phone is the live proof (he sends screenshots per tab), plus sandbox Playwright measurements at 390 / 820 for each route. Each tab gets a phone/tablet mark in this table when seen.

## UPDATE 6 Nov 20:55 PKT: mobile + tablet pass, part 1 (sandbox, real built SPA, shell + empty states; NOT real data)
- Harness: START-HERE section 6. 13 views (dashboard, bridge, mail, people, ai, systems, control, finance, release, move_in, audit, settings, profile) x 3 sizes (390 / 820 / 1024) = 39 rows: zero page-level horizontal overflow. All 7 Settings tabs x phone + tablet: zero overflow.
- Bugs found and fixed in CSS (founder-web/src/dx.css, ui.css, styles.css): (1) phone: "Working features" cards cut off on the right (grid `1fr` -> `minmax(0,1fr)` everywhere + safety net); (2) phone: Settings tab names overlapped each other (flex:1 shrink) -> scrolling strip, no shrink; (3) Settings "Save" left its card -> field rows wrap; (4) touch targets under 44 px (avatar, Review, Details, Search, sidebar, Explain/Blast radius/History, All/5 s/Off) -> 44 px on touch screens and up to 1100 px; (5) my own first attempt made toggle switches 44 px ovals; caught on the tablet screenshot, switches keep their look, tap area grows with ::after.
- 97 SPA tests (4 new CSS-rule tests), tsc clean. On his server only after founder-install (PULL-COMMANDS 20:55).
- STILL OPEN: his phone screenshots are the live proof per tab (Home, Bridge, Settings, Finance, People, Mail, AI, Systems, Control, Release, Move-In, Audit, Profile); tablet live proof (needs a real tablet or his Chrome device mode); inside-deck panels with real data (the sandbox has none).

## UPDATE 6 Nov 21:15 PKT: PHONE PROOF from his screenshots (Android, Chrome-type browser, 390-ish px) vs my laptop Chrome look (same live bundle `index-BzbVyi6l.js`, same numbers)
| Screen | Phone (his screenshot, time) | Laptop Chrome (mine, 21:00) | Result |
|---|---|---|---|
| Home / Dashboard | 8:50: greeting, "2 of 2 checks passing", 2/2 ring "Everything is running, 11 of 11 endpoints answering, Answers verified", Monthly revenue £0, Subscriptions 0, bottom bar Home/Bridge/Finance/People/More; nothing cut off | same text and numbers; sidebar instead of bottom bar, 4 tiles in one row | **GREEN phone** (top of page seen) |
| Bridge | 8:51: Needs attention 2 checks OK, Polar webhook "0 events in 24 h", 301 old rejects; wraps cleanly | same panels, bridge map visible beside the counters | **GREEN phone** (lower half seen; top half seen at 7:59) |
| Settings > Appearance | 8:53: tab strip scrolls sideways (Personal, Workspace, Appearance, Not...), segmented buttons fit, Explain / Blast radius / History fit | sidebar layout, same controls | **GREEN phone** (Appearance); Personal not sent yet |
| Finance | 8:56: tabs Live / All / From today's app / New / Gates, tiles MRR £0, Features 14, Gates 10-3-1 | MRR £0, Features 14, Gates 10-3-1 (identical) | **GREEN phone**. Cosmetic: "Gates" sat alone on a 2nd row, now one scrolling strip (fixed in code, waits for founder-install) |
| People | 8:56: Features 13, Gates 8-4-1, real organisations list ("Pro Buyer Two Test") | Features 13, Gates 8-4-1, same organisation (identical) | **GREEN phone** |
| Mail | 8:57: Features 15, Gates 10-5-0, Mail Desk company mailboxes | Features 15, Gates 10-5-0 (identical) | **GREEN phone** |
Same data on both screens: ONE build, only the layout flexes. Still open: tablet (820) live proof, phone proof of the other tabs (AI, Systems, Control, Release, Move-In, Audit ledger, Profile, Settings Personal/Workspace/Notifications/Privacy/Time machine/Drift), J6 phone alerts.

UPDATE 21:30: parity pass built; sandbox audit clean at 390/768/820/1024. Live proof pending his install.
