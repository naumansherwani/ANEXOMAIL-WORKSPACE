> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->


# G-MIX 2b / S6 + S5 + S4: THE LOGIN PAGE USES THE PASSKEY DOOR (plan written 10 Nov 2026 19:42 PKT; founder order 10 Nov 19:42: "shuru karo, pehle technology plan top pe repo mein, rules, mobile + tablet, kal pe kuch nahi, aaj hi; koi loophole nazar aaye to bina poochay fix karo")
**LOGIN UI LAW stays absolute: the look of SignIn.tsx does not change (same markup, same classes, same buttons). Only what the buttons DO changes.**

## Technology (layer by layer, never mixed)
- **React 19 + TypeScript strict** (founder-web): new pure module `signin_passkey.ts` (decisions, no DOM) + a thin runner; SignIn.tsx gets only handlers.
- **Browser WebAuthn Level 3** (`navigator.credentials.get`, user verification REQUIRED, discoverable credential so the page never names an account; the same `prepareGet` / `credToJson` helpers the Keys card already uses). WebAuthn is a browser API, so Rule 52 (crypto clients in the Rust WASM kernel) is not bent: no key or hash is computed in page JavaScript; the server (Rust) verifies the signature.
- **Rust** (done in S2): `/founder/v1/auth/passkey/begin|finish`. **SQL** (E151/E152/E139): the rulebook. No new SQL, no new Rust surface, except the loophole fix below.
- Tests: bun test (sandbox tool, allowed) for the pure decisions; cargo test for the Rust fix; live probe + his phone for REAL.

## What each button does
1. **Continue with a passkey (S6):** begin -> browser sheet (phone fingerprint / face / security key) -> finish -> same session handling as the password (tokens into storage, "Activated", reload). Cancelled sheet = plain words, nothing changed. A refusal is ONE sentence for every cause (no oracle). If the password answer says `{step:"passkey", ticket}` (only if he ever sets the word to required) the same button path completes the parked ticket.
2. **Email me a sign-in link (S5):** an honest sentence, no request is sent: "Email links never sign the founder in. Use your password or your passkey." (The database already refuses a magic link; the page no longer pretends it is coming soon.)
3. **Lost your passkey? Use a recovery code (S4):** by his word the sign-in is ONE factor, so a lost passkey never locks him out: the password still signs in. The button says exactly that. Recovery codes (E117/E118) remain for the day he sets the word to required; Rust fails closed on any factor it cannot honour (tested in S2).

## Mobile / tablet / laptop (Rule 34 + 19)
One build, no new element, no new size rule: the passkey button already exists at 44 px. Proof still required before GREEN: harness at 390 / 820 / 1200+ (no sideways scroll, nothing cut off, buttons >= 44 px) + his phone.

## Loophole hunt done during S6 (fixed without asking, as ordered)
- L1 **network lock before the password is tried:** the E151 lock (founder AND network) was only asked AFTER the identity service had checked the password, so a locked network could still test passwords against the identity service once the in-memory limiter forgot (restart). Fix: ask `founder_signin_locked(null, net)` FIRST; a locked network is refused before any password is tried; a down door = 503 (closed).
- L2 passkey ceremonies: the global cap (256) could be filled by many addresses to block passkey sign-in for 120 s (password path unaffected). Fix: when the cap is full, the oldest ceremony of the SAME network is dropped first, a different network can never evict another's.
- Noted, not a hole: two sign-ins 9 s apart in the ledger are the splash reload; the second reads release_burst (risk 10), as designed.

## Proof order
a) bun test + tsc + vite build + cargo test; b) harness 390 / 820 / 1200; c) rules-gate; d) his founder-install (Rust + SPA) + live probe of the live bundle hash = repo build; e) S7: his phone passkey once (REAL). GREEN only after (e).


## RESULT 10 Nov 2026 19:52 PKT (coded, tested locally, NOT on his server yet)
- L1 became E153 (SQL) + Rust: a wrong password is written to the ledger (\`reject_ip\` / 'bad_password', network hash only, NO user id so a stranger can never lock the founder), and \`founder_signin_locked(null, network)\` is asked BEFORE the identity service sees a password. Down door = 503 (closed). Tests: cargo 278 pass (new: locked network refused with the identity service never called; wrong password reaches the ledger; down door before and after the password).
- L2 done: \`TtlMap::put_fair\`: a full ceremony map evicts the OLDEST entry of the HEAVIEST network, so a stranger only ever evicts his own (unit-tested).
- S6: \`signin_passkey.ts\` + \`signin_pure.ts\` ("step" answer, 4 new plain messages) + handlers in SignIn.tsx (markup and classes untouched). bun test: 159 pass (11 new). vite build OK (bundle index-P9z4PDu).
- S5: the email-link button answers honestly, nothing is sent. S4: the recovery button says the password signs in alone (one factor); recovery codes matter only if a second step is ever switched on.
- Look at 390 / 820 / 1280 (sandbox Chromium, built dist): no sideways scroll at any width, every action button 44 px high (Sign in, passkey, email link, recovery), no JS errors, the three buttons answer in plain words. Inputs stay 36-38 px because the page is the verbatim awam look (LOGIN UI LAW).
- Still needed for GREEN: his SQL E153 + founder-install, the live bundle = repo build, and S7: his phone passkey once.
