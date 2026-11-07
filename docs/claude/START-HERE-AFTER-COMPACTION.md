# START HERE after a compaction or a new chat (updated 6 Nov 2026 20:30 PKT, founder order 20:00 "rules her cheese top pe rakho")

## BEFORE EVERY REPLY (checklist, founder 6 Nov 20:45; the rules-gate enforces the machine-checkable parts)
1. His order pasted verbatim into founder-commands.md first. 2. ONE website, ONE build; mobile + tablet + laptop at 390 / 820 / 1200+ for anything visual. 3. Chat context checkpoint + DONE line + PULL-COMMANDS note in the SAME commit as the code (gate fails otherwise). 4. At most 1-2 pull points, in Rule 46 order. 5. Roman Urdu, short, no padding, no repeated lists; his own task stated in ONE line. 6. End with the Rule-70 table and "Abhi code mein NAHI". 7. Never fake GREEN; never touch the footer; never offer the Polar token.


## ONE WEBSITE, ONE BUILD (top of everything, founder 6 Nov 20:38)
One codebase, built once, computer + laptop + tablet + mobile together. No separate mobile/tablet/desktop versions, no JS screen-size switch (`isMobile`-style), no feature that exists on one size only. Only the layout flexes. A new feature is written responsive in the same change. Audit 6 Nov: the founder SPA already has no JS device switch (0 hits); only CSS media queries; what collapses on small screens is labels and secondary text (`.dx-what` endpoint column, settings tab descriptions/icons, the "coming soon" list, sidebar text labels become icons, the sidebar becomes a bottom bar on phone), never a feature.

## RULE 34 / 19 (top of everything)
The site runs on laptop, computer, mobile AND tablet. A founder phase is GREEN only after 390 / 820 / 1200+ px are seen (his phone screenshot + sandbox measurement), 44 px touch targets, no sideways scroll, nothing cut off, no empty screen. Existing founder code is brought to mobile/tablet, never rewritten. He is angry that this was skipped (6 Nov 20:09, 20:17, 20:24).

## 0. Who and how
Nauman Sherwani = founder and chairman, Asia/Karachi. Talk Roman Urdu, "Aap" / "Nauman bhai", short. He gets angry at stale, repeated or missed things: fix directly, never hand him a list of problems. Never fake GREEN (GREEN = his pasted server output + my own Chrome look). Never skip a letter. ONE phase at a time. Founder code is SUPER ADVANCED, SQL above that. No mock data anywhere.

## 1. Read in this order (10 minutes)
1. `AGENTS.md` top blocks + Rules 70-74 (Rule 70 = every reply ends with the technology table + a line "Abhi code mein NAHI: ..."; Rule 73 lanes; Rule 74 pinpoint: open `lanes/FOUNDER-INDEX.md` first, never grep the repo).
2. `docs/claude/founder/CODES/00-README-RULES.md` (FC1-FC42).
3. `docs/claude/BLUEPRINT-ABC-01NOV.md`: the GREEN LEDGER table at the top + the letter order.
4. `docs/cursor-work/CLAUDE-CHAT-CONTEXT-WITH-FOUNDER-NAUMAN-SHERWANI.md` (line 13 = stamp, bottom = newest checkpoint) and the top of `docs/cursor-work/founder/founder-commands.md`.
5. `docs/claude/founder/PULL-COMMANDS.md` bottom block (what he must run next). Rule 24: at most 1-2 pull points per reply; Rule 46: all pull commands in order SQL, CHECK, Rust+SPA, Caddy, Web.

## 2. Process rules that bite
- Paste his order verbatim into `docs/cursor-work/founder/founder-commands.md` BEFORE working.
- Before a commit: `python3 lanes/lane-sync.py`; `git add -A`; `manifest-verify.py | grep PURANI | awk '{print $2}' | xargs python3 manifest-sync.py` (pass files explicitly), lane-sync again, twice; `manifest-verify.py` = 0 bad; `python3 docs/cursor-work/server/rules-gate.py --staged` (needs a DONE-DO-NOT-REPEAT.md line when code changes, and a PULL-COMMANDS note when the server changes).
- Commit trailers: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: https://claude.ai/code/session_01M4RARCpqskLVTeA3hiUMVX`. Push to origin main (the repo moved note in the output is harmless).
- Pull command form: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>) [args] 2>&1 | tail -N` (`sql-run.sh <name> [CHECK_name]`, `founder-install.sh`, `founder-device.sh approve <CODE>`, `pull.sh`).
- Sandbox: scratch Postgres on port 5546 (start: `su postgres -c "/usr/lib/postgresql/16/bin/pg_ctl -D /tmp/pg5546 -o '-p 5546 -k /tmp' -l /tmp/pg5546.log start"`); Rust offline test via scratchpad `fb/sync.sh` then `cargo test --offline` in `fb/founder` (about 1 minute); SPA `cd founder-web && bun test && npx tsc --noEmit && npx vite build && bash precompress.sh`.
- Founder-side code stays ON HOLD until he says "go" (CLAUDE.md top line) unless he orders the specific fix.

## 3. Decisions that are LOCKED (never re-offer)
- C1 Polar API token is DROPPED (three times). Polar goes through the two existing webhook endpoints + a hash-chained ledger, in letter O. Never offer `founder-polar.sh` or a token.
- ANEXOChat chart is reality: per file Business 500 MB / Business Pro 1.5 GB / Business Premium 4 GB; monthly per user 50 / 150 / 400 GB (100 sends); 80% warn, 100% throttle, NEVER block; users 20 / 570 / **21,000 cap for Premium (NOT unlimited; only the PRICE page says Unlimited)**. No AI for awam in ANEXOChat (founder only, on demand). SQL: `anexochat/sql/phase13_15_file_engine.sql` + `phase61_file_limits_quota.sql` + `CHECK_phase61.sql` (GREEN on his server 3 Nov 13:48).
- Business Pro is NEVER unlimited (570 users).
- Landing footer "Built with" is his wording: never touch it; MoQ stays "planned" until letter M is GREEN.
- Device trust: every browser/profile is its own device and is approved once (`founder-device.sh approve <CODE>`). Do not switch that off.
- `FOUNDER_PASSWORD`: he asked 6 Nov 20:09 "kyun delete kerun?": do NOT keep asking or listing it in replies; leave it exactly as is. T3 two-key proof only when Control (S) arrives.

## 4. STATE (6 Nov 2026 20:30 PKT)
GREEN: A, B, D, E (L5 parked), F, G, H, I, J1-J5, J hardware E142, J6 on desktop, K1, K2, K3, ANEXOChat SQL 13-15 + 61.
Today: the founder phone (Android) was approved (19:45). Two bugs found from his screenshots and fixed in code: (1) exchange rate-limit was per ACCOUNT, now per account+device (`ftoken::exchange_key`); (2) the lock was checked BEFORE approval, so an approved phone still showed "Too many device attempts": now a lock never blocks an approved device (`ftoken::exchange_blocked`). Fix (1) is on his server (install 19:42); fix (2) + device-label names (`devicelabel.ts`) wait for his `founder-install.sh` (PULL-COMMANDS bottom block).
His honest "Not connected" tiles on Bridge/Finance are real (sources arrive in letters O, P, Q); they are not a bug.

## 5. ORDER (no letter skipped)
1. (DONE 6 Nov 20:09, his paste OK) `founder-install.sh` with the lock fix. Waiting: his phone reload shows the banner gone.
1b. MOBILE + TABLET pass over every founder tab (his anger 20:09: phases were built without phone/tablet proof). See `docs/claude/GREEN-LIST-06NOV.md` last column. Do it before J8. Rule 19/34.
2. J6 real-phone proof (phone: Settings > Phone alerts > Add, allow notifications; I send the test; I read the receipt in the ledger) -> J6 fully GREEN.
3. J8 vault lease (no operator needed; only after his "go").
4. K4 AES-256 on :443 (also fixes the `/_cc` 404 on :8443), K5 awam T256-2, K6 WebTransport `wtransport` (UDP open), K7 DBSC.
5. L Look (Framer Motion + GSAP, Three.js WebGPU globe; CINEMATIC stays pixel-equal), M MoQ own Rust relay.
6. N Bun cutover begins, O Polar ledger (C1 emerges), P, Q (awam Mail/Calendar), R (+R3 Admin > Mail Desk), S, T (Bun off), U, V. J7/J9 only when he names an operator/aggregator.
Open words from him: Premium storage number (1 TB copied from Business Pro, needs his word), Premium plan card in `plans.ts`.

## 6. Founder responsive harness (sandbox, not shipped)
Files live in the session scratchpad and are re-creatable: a tiny Node static server over `founder-web/dist` (map `/_cc/` to dist), Playwright Chromium (`/opt/npm-tools/node_modules/playwright/index.mjs`), localStorage `anexo.session.token` set, every `/founder/v1/**` answered with `{"data":{}}`, wait about 4.6 s (the app gives up on the bridge after 4 s and then shows the shell). It measures per view at 390x844 / 820x1180 / 1024x768: horizontal overflow, elements past the right edge, touch targets under 40 px. Views: dashboard, bridge, mail, people, ai, systems, control, finance, release, move_in, audit, settings, profile. It proves the layout and empty states, NOT real data (his phone screenshots are the data proof).
First run 6 Nov 20:20: found phone cards cut off on the right (grid `1fr` grew to the width of a nowrap line); fixed by `minmax(0,1fr)` everywhere + a safety-net block at the end of `dx.css`; then 13 views x 3 sizes = 39 rows with zero overflow.

## 7. PARITY: phone and laptop are the same code (founder 6 Nov 21:06: "sab codes same to same, sirf mobile tablet layout ka farq")
Audit 6 Nov 21:25: (a) JS: no screen-size switch anywhere (the only size reads are Scene3D resizing its own canvas); a test guards it. (b) Same bundle, same live numbers on phone and laptop (screens compared). (c) Every page is reachable on a phone: the bottom bar has Home, Bridge, Finance, People and "More", and "More" opens the same search/jump palette that lists every page (Mail, AI, Systems, Control, Release, Move-In, Audit ledger...). (d) LOOPHOLE FOUND AND FIXED: the device trust label ("Trusted" / "Review") was hidden on a phone, only a dot; now shown. (e) Dead CSS (`.dx-what`, `.setsoon`, `.fxtoggle` match no component) = nothing is hidden by them. (f) The ONLY deliberate layout differences left: sidebar -> icon rail (tablet) -> bottom bar (phone); the centre search box -> a search icon on a phone (same palette); Settings tab icons and one-line descriptions are hidden under 1024 px (the section itself explains itself); a decorative separator dot. Anything new that hides content on a small screen must be written down here first.


## 8. LIVE CHROME = REPO (founder 6 Nov 21:17)
Live Chrome must match the repo code on every device, founder AND awam site. Same codes, only layout differs. Check the live bundle hash against the repo build, then 390 / 820 / 1200+.
Update 21:30: tablet no longer has its own rail; labelled sidebar from 768; search box always in the top bar; Bridge map stacks under 1000 px; Settings tabs keep icons + descriptions.


## 9. TECHNOLOGY PER LAYER (founder 6 Nov 22:17: every phase names its technology; never mix layers)
- SQL (Postgres, above super advanced: constraints, triggers, hash chains, RLS, selftest, CHECK file) = decisions + ledgers.
- Rust `anexomail-founder` (axum 0.8, tokio, ring) = server, signing, key derivation. No Node/Bun on the founder server.
- WASM kernel (one Rule-52 kernel, `web-wasm/`) = browser-side verification.
- React 19 + Vite + TS strict + TanStack Router + Tailwind 4 + shadcn, WebCrypto = screens. CINEMATIC look stays.
- J8 detail and layer table: `docs/claude/J8-LEASE-ADVANCED-DESIGN-06NOV.md`. Current: J8a GREEN, J8b installed, E144 written (waits his pull), then J8b2, J8c, J8d.


## 10. SHARED-CODE RULE (founder 6 Nov 22:46)
Any founder change that also changes a file the awam site carries (kernel pin, shared lib, public/kernel) => in the SAME reply give him the awam pull.sh command as its own point. If awam is not affected, say so in one line. Founder and awam commands stay separate; the awam one never replaces the founder one.


## 11. STATE AT 6 Nov 2026 23:20 PKT (founder going on a 1 hour break; the chat is about to compact)
- GREEN this evening (all with his pastes): K3, ANEXOChat 13-15+61, phone screens (6), parity pass live (bundle matched), J8a E143 (22:04), J8a2 E144 (22:24), J8b Rust lease route installed (22:17), J8b2 HKDF half + ES256 proof + vault master file (22:36).
- UPDATE 7 Nov 13:20: J8c is GREEN (kernel 0.13.0 200 + pin hash on both sites, his pastes + my Chrome), E144 issue core closed and GREEN. NOT GREEN: J8d UI (not written), J8 as a whole.
- NEXT IN ORDER (no letter skipped): (1) DONE 7 Nov 13:20 (awam pull + 200 check). (2) J8d UI NOW: `founder-web/src/lease.ts` (pure logic + tests: WebCrypto non-extractable ECDSA P-256 key in IndexedDB, proof text `anexo-lease-proof@1|<device>|<ts_ms>`, signature as raw r||s base64url, JWK {kty,crv,x,y}; local half 32 random bytes in IndexedDB; server half only in memory; pinned serial in localStorage; renew every ~5 min and on focus; monotonic = performance.now(); wipe the half at expiry), Settings > Privacy card per device (live/expired/revoked, seconds left, chain head, panic lock behind T3), 390/820/1200 check, live proof. (3) then K4 (AES-256 on :443), K6 WebTransport, K7 DBSC, L, M, N-V; K5 awam only after founder is 100%.
- Code map J8: SQL docs/cursor-work/sql/E143_founder_vault_lease.sql + E144_founder_vault_lease_keysplit.sql + CHECK_E143/E144; Rust server/founder/src/lease.rs (+ main.rs vault_lease_ep needs body {jwk, ts, proof}, vault_status_ep, spawn_sweep, --gen-vault-master); kernel web-wasm/src/lease.rs (lease_check, lease_vault_key); SPA founder-web/src/kernel.ts leaseCheck / leaseVaultKey; design docs/claude/J8-LEASE-ADVANCED-DESIGN-06NOV.md.
- Server facts: master file /etc/anexomail/founder-vault-master.key (NEVER delete); installer creates it once; vault lease key ON in journal.
- His standing rules this evening: ONE WEBSITE ONE BUILD; LIVE CHROME = REPO (founder and awam); SHARED-CODE RULE (give the awam pull.sh as a separate point whenever shared files change); founder SQL = world-class (above super advanced); technology named per layer in every answer; Rule-70 table at the end of every reply plus 'Abhi code mein NAHI' line; no padding; Roman Urdu; do not repeat the FOUNDER_PASSWORD line; never touch the landing footer; Business Premium cap 21,000 users.
- Commit procedure reminder: lane-sync, git add -A, manifest-sync for PURANI + explicit paths for non-src deployed files, manifest-verify 0 bad, rules-gate --staged 0 fail (the pipe to tail hides failures: read it before pushing).


## 12. NEXT ORDER + TECHNOLOGY (founder 7 Nov 13:23)
Open `docs/claude/FOUNDER-NEXT-ORDER-07NOV.md`: 18-row table (phase, what, technology per layer, why). The same one-paragraph version is at the very top of AGENTS.md and CLAUDE.md and the gate keeps it there. Next = J8d.

- 7 Nov 14:20: J8d = GREEN (his sql-run E145 4/4 + CHECK_E143 5/5 + founder-install pastes; my live Chrome on founderworkspace.anexomail.com: bundle index-xABp9PqM = repo build, card shows lease #3 live 14 min left, 3 devices with chain heads, key held in memory only; sandbox harness 390/820/1280: no sideways scroll, nothing cut off, every button 44 px high, same code). HONEST NOTES: (1) Chrome window could not be resized to 390 live, phone/tablet were measured in the sandbox harness on the same bundle; his phone screenshot of Settings > Privacy still welcome. (2) Panic lock request/approve/confirm not exercised for real: needs his 2 trusted hardware keys. (3) Vault key encrypts nothing yet (consumers later). (4) Polish: the last 'Not yet' line of the card is slightly larger text than the rest; goes in the next SPA build. J8 as a whole = GREEN except those notes. NEXT: J6 real-phone receipt (his phone) then K4.

- 7 Nov 14:25: HIS PHONE SCREENSHOT (Android Chrome, 390-wide, old build): Device vault lease card shows 'Chrome on Android (this one) unlocked 11 min left lease #1 chain f18b9fc13d' + Windows lease #6 + 3rd device never unlocked: J8d phone proof DONE (real phone lease issued). He found the mobile layout congested ('world class app level'): written PHONE BREATHING block at end of founder-web/src/dx.css (<768 px only: panel padding 16/14, tabs one-line pills with hint kept for screen readers, Explain/Blast/History as 3 equal 44 px buttons, content clears the bottom dock, Renew full width), Settings keeps the chosen tab in view, Vault last line same size as other helper text. Sandbox 390/820/1280: sideways scroll 0 (a first try broke it to 1065, fixed with position:relative). NEW SPA BUILD, not yet installed: needs founder-install, then his phone screenshot again. Same code on every screen; only spacing/type changes under 768 px.

## 13. STATE AT 7 NOV 14:35 PKT (read this first after a compaction; newest wins)
- GREEN: J8 whole (J8a E143, J8a2 E144, J8b Rust lease signer, J8b2 vault master key, J8c kernel lease@1 0.13.0 on both sites, J8d UI + panic lock E145). J8d proof: his sql-run (E145 CHECK 4/4, CHECK_E143 5/5 after fixing my check for `security_invoker=on`), my live Chrome (lease live, 3 devices), his Android phone screenshot (lease #1, 11 min). J6 GREEN by his order (real phone receipt still unseen).
- INSTALLED 14:30: "phone breathing" SPA build (live bundle index-C-QmgGnG.js + index-Og622Jck.css = repo build, checked in live Chrome). Roomier mobile spacing in `founder-web/src/dx.css` (end of file, under 768 px only), Settings tab kept in view, same code on every screen. WAITING for his new phone screenshot (Settings > Privacy top) to confirm he likes it.
- Panic lock needs 2 trusted hardware keys to run for real (T3 = two keys + 10 min delay). Not exercised for real.
- NEXT, one step at a time (he does each step and pastes): Step 3 = J6 real-phone receipt (phone: Settings > Privacy > Phone alerts > add this phone > Test). Then K4 (Rust rustls AES-256 on :443; technology is in the top block), K5, K6, K7, L...X. Also open: tablet 820 on a real tablet, phone proof of AI/Systems/Control/Release/Move-In/Audit.
- Gate lessons: read rules-gate output (never `| tail` alone), DONE-DO-NOT-REPEAT must be updated in docs/cursor-work/ AND docs/cursor-work/founder/ (gate checks docs/cursor-work/DONE-DO-NOT-REPEAT.md); PULL-COMMANDS is docs/claude/founder/PULL-COMMANDS.md; manifest-sync twice after build.
- Sandbox: harness in scratchpad `h/run.mjs` (static server over founder-web/dist + Playwright, API stubbed with unsigned data so "Answer hidden" red lines appear: harness artefact, not a bug). Chrome window cannot be resized to 390: phone proof comes from his screenshots.

- 7 Nov 14:50 UPDATE: J6 GREEN with evidence, mobile Settings>Privacy GREEN, NOW = K4 (see top block of AGENTS.md).

- 7 Nov 15:05: K4 step 1 WRITTEN (not GREEN): Rust main.rs strip_cc middleware (+1 test, 221 pass): the own TLS terminator on :8443 now serves /_cc/assets/* like Caddy does (fixes the K3 note '/_cc 404, page unstyled'). Behind Caddy it is a no-op (Caddy already strips). Proof needed from him: founder-install, then curl of the live bundle through :8443 = 200, then my Chrome look at https://founderworkspace.anexomail.com:8443/ styled. K4 step 2 (real :443 for the founder host) needs an SNI front because Caddy owns :443 for awam too: DESIGN DECISION written for him before any change.

- 7 Nov 15:20: his curl on :8443: / 200, /_cc/ 200, bundle 200 (K4.1 works), /founderlogin 404 and /app 404 (they live in Caddy = old awam login). K4.1 = GREEN narrowly (assets/shell through the own TLS terminator); :8443 is NOT a usable full site, so K4 as a whole is NOT green. Design written: docs/claude/K4-REAL-443-DESIGN-07NOV.md (SNI front in Rust + path proxy table + rollback; nothing live changed; waits for his haan before any :443 change). My Chrome look at :8443 landed on the 404 login redirect (error page), which is exactly that limit.

- 7 Nov 15:30: his read-only server output for K4 (ports, Caddy v2.11.4 on 443 tcp+udp, Rust 3210 + 8443, cert copy at /etc/anexomail/tls, ufw). 4 findings written in docs/claude/K4-REAL-443-DESIGN-07NOV.md: stale cert copy (renewal timer needed), Caddy QUIC on 443/udp bypass (Alt-Svc clear), reqwest already present (no new crate), SNI by peek + PROXY v1. Nothing live changed. He also asked: shorter replies, commands first; and raised that the email system has not been reached yet (order question asked: 1 = K4.. in order, 2 = email first; waiting for his word).

- 7 Nov 15:50: K4.2 WRITTEN (not GREEN): server/founder/src/fproxy.rs (closed path table /founderlogin /app /api, validated upstream host:port, never own port, hop-by-hop + forwarding headers stripped both ways, redirects not followed, 25 MB cap, answer streamed chunk by chunk, Alt-Svc: clear on every founder answer), outermost layer in main.rs, env FOUNDER_LEGACY_UPSTREAM (installer adds 127.0.0.1:443 = Caddy today; moves to the internal port at K4.5), futures-util direct dep. 225 Rust tests pass (+4). NEEDS: founder-install, then curl :8443/founderlogin = 200 (was 404) and /app, then my Chrome on :8443 login page. Nothing on :443 changed.

- 7 Nov 15:25: his K4.2 install + curl: / 200, /founderlogin 200, /app 200, journal 'legacy path proxy ON'. My Chrome on :8443/founderlogin: title 'Founder sign in', isSecureContext=true, BUT unstyled: old app assets /assets/* 404 (the old app serves its own /assets). FIX (not yet installed): fproxy now uses an inverted closed table 'is_ours' (/, /f, /_cc/*, /founder/v1/*) and everything else goes to the old app, like Caddy; the layer + Alt-Svc clear are applied ONLY to the :8443 TLS router (NOT :3210: behind Caddy the founder SPA assets also arrive as /assets/* after Caddy strips /_cc, so a global proxy would have broken the live site). 225 tests. Status table sent to him: docs/claude/FOUNDER-STATUS-TABLE-07NOV.md.

- 7 Nov 15:35: he asked 'green ke agay likho wired hai real working': added the WIRED / REAL WORKING column to docs/claude/FOUNDER-STATUS-TABLE-07NOV.md. Honest gaps: vault key has no consumer, T3/panic not run for real, Android phone not added to alerts, real site still on Caddy AES-128, ANEXOChat has no UI, K4.2 unproven. From now on every GREEN line in ledgers states wired + really working.

- 7 Nov 15:30: K4.2 = GREEN. His install after the is_ours fix + my Chrome on https://founderworkspace.anexomail.com:8443/founderlogin: secure context, 51/51 files 200, bg dark, full 'Welcome, Founder' login styled. Wired + really working on :8443 only; real :443 still Caddy. NEXT = K4.3 cert refresh timer (stale one-time cert copy), K4.4 SNI front on spare ports, K4.5 live switch with his haan, K4.6 CHECK + Chrome 390/820/1200+. Email-first question still unanswered by him.

## 14. STATE AT 7 NOV 15:40 PKT (newest; supersedes section 13 where they differ)
- GREEN now: everything in the CURRENT GREEN LEDGER at the top of `BLUEPRINT-ABC-01NOV.md`, including J8d, J6 (desktop receipt), mobile Privacy, K4.1, K4.2.
- NOW: K4.3 (certificate refresh: Rust uses a ONE-TIME COPY of Caddy's Let's Encrypt cert at /etc/anexomail/tls, it goes stale in ~60 days) -> K4.4 -> K4.5 (live :443 switch, ONLY with his "haan", rollback ready) -> K4.6. Facts from his server and the design are in `K4-REAL-443-DESIGN-07NOV.md` (Caddy v2.11.4 owns 80/443 tcp and 443/udp; Rust 3210 plain + 8443 TLS; env FOUNDER_LEGACY_UPSTREAM=127.0.0.1:443 added by the installer; proxy only on the :8443 router).
- HOW HE WANTS REPLIES (7 Nov 14:53-15:23): short; command first then one line; "green ke agay likho wired hai real working" on every GREEN; repo/context/codes/top-of-file updated silently every step; one step at a time for things he must do; no long recaps. He is tired of the length: do not paste the table again unless asked.
- Open question to him: email system (Mail Desk) not reached; "1" = keep order, "2" = email first. Unanswered; default = keep order.
- Sandbox facts: scratch Postgres on :5546 stops between turns (start line in section 3 of the summary notes / DONE file); e143b now has E103-E118 applied; Rust tests via scratchpad fb/sync.sh + `cargo test --offline` (225 tests); `reqwest` `stream` feature does NOT build offline (use `chunk()` + futures-util unfold).

- 7 Nov 15:36: NEW STANDING RULE (top of AGENTS.md/CLAUDE.md, gate-enforced, head window 9500 chars): NO UNFINISHED WORK: GREEN only when wired AND really working; every GREEN says wired/real with proof; gaps live in docs/claude/CLOSE-THE-GAPS-07NOV.md (G1 Android phone alerts, G2 vault key consumer, G3 T3/panic with 2 hardware keys, G4 real :443, G5 ANEXOChat founder screen, G6 phone proof all tabs, G7 real tablet) until closed. His words: 'adhoora kaam nahi kerna hai, jaise bhi kerna hai steps batao'.

- 7 Nov 16:14 PHONE FINGERPRINT PASSKEY (his Android screenshot: chooser showed only NFC/USB/other device): founder: Settings>Privacy>Security keys has a new 'Add fingerprint' button (register kind=phone: authenticatorAttachment platform, hints client-device, UV required, server refuses non-platform answers); 'Add key' hardware path UNCHANGED; a fingerprint passkey never counts as hardware (E142) so T3 still needs 2 hardware keys. Awam (separate lane, no mixing): optional 'Add this device's fingerprint' button on app.account (enrolPasskey(label,'platform')), default 'Add a passkey' unchanged. Rust 225 tests, SPA 114 tests, tsc clean. NOT GREEN until his phone: Add fingerprint -> Phone alerts Add this phone -> Send test (G1).

- 7 Nov 16:30 BANNED COUNTRIES + ALERT NUMBER (his words 16:22: number with country code in Phone alerts, every country except the banned, folder named banned-countries): NEW folder banned-countries/ (banned.json = the ONE list + README): AF +93, IL +972, KP +850, SY +963 (Syria added by him; Iran/Cuba NOT banned). Copies updated + drift test (founder-web/src/banned.test.ts reads the json): Rust signx_core.rs (awam engine), awam src/lib/countries.ts + ContactFields, Caddy geoblock-gen.py (SY ripe; NOT live until his server runs geoblock.sh apply), founder-web/src/banned.ts + countries.ts, SQL E146 (append-only founder_banned_countries, founder_e164_banned, founder_mobile_flare_set refuses banned BEFORE the key grant, selftest, CHECK_E146 4/4 in sandbox). Founder UI: Phone alerts > Alert number row (country select, number, Save number, Remove) on the existing E118 doors flare_set/flare_remove; purpose chosen by him = record + recovery contact ONLY, no SMS is sent, confirmation by inbound reply is NOT built so the number stays 'not confirmed' (honest). Tests: Rust 225, signx 21, SPA 118, tsc clean. NOT GREEN until his server run + phone screenshot.
