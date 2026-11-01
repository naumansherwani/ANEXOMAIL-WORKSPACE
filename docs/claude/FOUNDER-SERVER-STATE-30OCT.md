# WHAT IS ON THE SERVER vs ONLY IN THE REPO — read this after any compaction, do NOT rewrite installed code (30 Oct 2026, 23:05 PKT)
Source of truth for "is it installed": the founder's own pasted output + Chrome. Update this file every time he installs something.

## INSTALLED + seen in Chrome (green)
| Item | Evidence |
|---|---|
| Rust `anexomail-founder` through the 66-test build (auth sharing, immutable assets, early kernel) | installs 22:14, 22:24, 22:37 |
| SPA through commit 35867e0: Dashboard plane look, splash with real logo, HealthOrb (green 2/2), BridgeMap, real `LogoMark` in sidebar/splash/profile, Founder blue top bar + eyebrow, greeting v2 | Chrome 22:59 (logo on profile clear of the real long name; top bar text gradient) |
| SQL E100-E106, E108, **E109 founder_live** (CHECK_E109 9/9 OK, founder paste 22:44) | server |
| Awam web: probe-mode log version of the host guard (auth.ts, pulled earlier) | status shows mode probe |

## IN THE REPO ONLY (not installed yet; do not rewrite, just give the founder the pull)
| Item | Needs |
|---|---|
| SPA greeting REVERTED to v2 (1 Nov): v3 centring was rejected by the founder; server already has v2, nothing to pull for the greeting | none |
| L5 v2: SQL E110 + CHECK_E110, Rust `hostproof.rs` (70 tests) + `/founder/v1/hostguard`, awam `auth.ts` DB record, `founder-hostguard.sh` DB status, Dashboard "Host separation" card | 4 pulls in order: sql-run (E110) -> awam pull.sh -> founder-install -> founder sign out/in -> status (see PULL-COMMANDS 22:58) |

## NOT STARTED (order unchanged)
Rust `/founder/v1/live` + SSE (uses E109 `founder_live_snapshot/tick/since`) -> Dashboard auto-update -> F2c Merkle (E107) -> S2 -> F2d passkey -> Finance -> People -> Mail Desk -> Systems -> Control -> F9 cutover. `pending_channels` hard-coded list in bridge.rs must move to the E109 registry.

## FOUNDER RULES THAT KEEP BEING BROKEN (check before every UI change)
1. Real logo only (`LogoMark` in Brand.tsx), never redraw. 2. No mock data. 3. Founder blue (#5ec8ff to #4aa3f0) on the title and pill. 4. Backend = Rust + tokio async 24 h + WASM kernel; 3D only draws kernel-verified values. 5. User side code is never edited (the one allowed touch: `server/routes/auth.ts` host guard).

## UPDATE 1 Nov 05:10 PKT
- Greeting v3 (centred eyebrow/heading, date under clock) was REJECTED by the founder ("woh pehle wala sahi tha"). Bridge.tsx and dx.css are back to v2 (same as 35867e0). The server already runs v2. Never centre anything in the greeting again without his exact sentence.
- New design note (docs only, no code): docs/claude/BRIDGE-EMAIL-CHAT-ENGINE-DESIGN-01NOV.md (Email <-> Chat Bridge, phases B1-B7, SQL E111-E116 proposed). Awam-stack feature; nothing installed.

## UPDATE 1 Nov 05:25 PKT (founder paste)
- INSTALLED and verified by founder: E110 (CHECK_E110 7/7 OK), Rust 70 tests + hostproof + /founder/v1/hostguard (founder-install OK, service alive). hostguard status: ready_to_enforce True, rust:exchange 5, web_guard_last_seen None => awam `pull.sh` (step 2 of L5 v2) NOT done yet; mode still probe. Next for founder: awam pull.sh, then `founder-hostguard.sh enforce`.
- REPO ONLY (needs founder-install): top bar title removed + date under the clock (this commit). Everything else in SPA = what the server has.
- Bridge (Mail<->Chat) = master order 12b, after steps 11 and 12.
- 1 Nov 05:30 PKT: g-clip fix in repo; pending founder-install together with 05:25 UI (top bar title removed, date under clock).

## UPDATE 1 Nov 05:35 PKT - founder-install (44e1661) DONE by founder (70 tests, SPA 200, healthz 200). Chrome live: g of "morning" now complete, top-bar title gone, eyebrow stays. Date under the clock is on the page (clock column).
### NEXT, in master-order terms (FOUNDER-MASTER-ORDER-28OCT.md)
| # | What | Owner | Rule |
|---|---|---|---|
| N1 | Finish step 3 / L5: awam `pull.sh` (web_guard_last_seen is None), then `founder-hostguard.sh status` -> `enforce` | founder (2 commands) | green = status shows web_guard_last_seen set + enforce on |
| N2 | Founder order 22:17 "live data, auto updates": Rust `/founder/v1/live` + SSE over E109 (`founder_live_snapshot/tick/since`), then Dashboard auto-update (React-TS, kernel-verified frames). Replace hard-coded `pending_channels` with registry here too | Claude | CHECK + Chrome (watch a number change without reload) |
| N3 | Step 5 F2c audit v1 + Merkle (E107), design note first (Rule 63), kernel `merkle` | Claude | then 5a I1 Ledger Integrity Gauge |
| N4 | Step 6 S2 Settings (Time machine, Drift) -> step 7 F2d passkey + S3 -> step 8 Decide/Live Pulse/S4 -> 8a I3 | Claude | in this order |
| N5 | 9 Finance, 10 People (+10a I2, 10b K4), 11 Mail Desk (+11a K1), 12 Systems/AI (+12a K2), **12b Mail<->Chat Bridge**, 13 Control (+13a K3), 14 F9 cutover, 15 Founder desk | Claude | one phase at a time |
Not asked and NOT next: Mail<->Chat Bridge build (12b). Leftover checks: orb amber/red under a real warning; F5 refresh 50-100 ms target; awam-side kernel 0.5.0 / E90 release publish.

## UPDATE 1 Nov 05:55 PKT (founder paste 05:46)
- DONE by founder: awam `pull.sh` (web online, restarts 432, build OK), then `founder-hostguard.sh enforce`: .env now FOUNDER_HOST_GUARD=enforce, pm2 restarted by the script. ("mode (running process)" is blank only because the script cannot read the pm2 env from /proc; the .env line is the truth.)
- Still unproven: `web_guard_last_seen_at` is None until a founder attempt hits the awam host. FOUNDER TEST (1 step): private window, https://anexomail.com/auth, sign in with the founder email -> must show the "founder portal" 403; then `founder-hostguard.sh status` shows last_founder_on_awam_host_at + web_guard_last_seen_at set + refused_30d 1. Then L5 = GREEN.
- Safety: founder login at founderworkspace.anexomail.com/founderlogin must still work (verify in Chrome, sign in is founder's click). Rollback: `founder-hostguard.sh probe`.
- The server's "memory stamp" (pull.sh) now reads the 1 Nov line of the chat context file.

## UPDATE 1 Nov 05:55 PKT - L5 is NOT green (Chrome proof)
Founder opened anexomail.com/auth, logged in, and the tab shows him inside the awam Business dashboard (anexomail.com/app, account naumansherwani.founder@anexomail.com). Enforce is set but did not refuse; E110 shows web_guard_last_seen None, refused 0. Likely causes: (1) login through a path without the guard (passkey / saved session / magic-link / oauth / refresh), (2) a session that already existed. Guard exists only in POST /api/auth/login and /signup.
Repo-only change: src/routes/auth.tsx: on founder_portal_only the awam login page sends the browser to https://founderworkspace.anexomail.com/founderlogin (founder wish: any host, auto-recognised, then the founder portal). Needs awam pull.sh.
TODO next (one phase): add founderHostGate to passkey login verify, magic-link verify, oauth callback, mfa verify and refresh for founder identities; retest from a signed-out incognito window.

## UPDATE 1 Nov 06:10 PKT - L5 ROOT CAUSE FOUND (founder diag paste 06:03)
- The Bun "Brain" that serves /api/auth is a SEPARATE service: pm2 `anexomail-leo` (:3100), live code in /opt/anexomail/src (routes/auth.ts, lib/...), env /opt/anexomail/.env. It is installed by the dedicated `brain-*-install.sh` scripts (surgical patch + backup + restore-on-fail), NOT by pull.sh. pull.sh only updates /opt/anexomail-web (frontend, pm2 `anexomail-web`, `.output/server/index.mjs`).
- No script ever installed founderHostGate / founder-host-guard.ts into the Brain (grep: only founder-hostguard.sh mentions it). `founder-hostguard.sh` writes FOUNDER_HOST_GUARD into /opt/anexomail-web/.env and restarts `anexomail-web` = the WRONG process. So enforce had no effect anywhere; the founder session on anexomail.com/app is explained. Nothing is locked out (safe). diag shows `[founder.host]=0` and `FOUNDER_EMAIL set: no-default-email` for the same reason.
- FIX (next phase, awam Brain lane, one phase): `brain-hostguard-install.sh` in the pattern of brain-identity-install.sh: copy lib/founder-host-guard.ts, surgical anchor-patch live routes/auth.ts (login, signup, plus passkey/magic-link/oauth/mfa/refresh), write FOUNDER_HOST_GUARD (start `probe`) + FOUNDER_HOSTS into /opt/anexomail/.env, pm2 restart anexomail-leo, bun build pre-flight, health check, restore on fail; update founder-hostguard.sh (BRAIN_ENV, APP=anexomail-leo, status/enforce). Then founder retest from signed-out incognito. Frontend redirect (auth.tsx, 09fc877) is already pulled.

## 1 Nov 06:07 PKT - FOUNDER DECISION CONTEXT: whole awam website will be migrated to the latest technology AFTER the founder deck, as the business package (all endpoint gates on new tech). So legacy Bun Brain is NOT to be patched more than needed. Recommendation given: PARK L5 (brain-hostguard-install.sh not built) -> host separation is built natively in the Rust auth at awam migration; interim state: enforce line sits in the wrong .env (harmless), founder can use awam host as a normal user, auth.tsx redirect stays. Founder asked: 'abhi mere liye kya kaam hai, credits zaya ho rahe, kaam ki baat kero'. Founder-side own tasks now: none mandatory; one word 'haan' to start 4b-1 (tick 5 s, Dashboard first).

## UPDATE 1 Nov 06:35 PKT - step 4b-1 CODE DONE (repo only, NOT green)
RUST: `GET /founder/v1/live` (main.rs `live_ep`, one RPC `founder_live_snapshot`, signed, honest fallback `live_missing`), 71 tests pass. UI: endpoint added to the Dashboard probe list (now 9) + feature card "Live feed" (version, sources, stale). No SQL needed (E109 already on server). Founder pull: founder-install.sh only. Green = Dashboard shows "Live feed: Version N, K sources" in Chrome. Next: 4b-2 tick task + SSE stream.

## UPDATE 1 Nov 06:25 PKT - 4b-1 GREEN (founder-install paste 06:22 + Chrome)
Server: 71 tests, SPA 200, healthz 200. Chrome (reloaded): Dashboard "9 of 9 endpoints answering", card "Live feed: Version 0, 12 sources, all fresh", /live answered in ~1013 ms, date under the clock, Host separation card shows founder session 6:22 AM. Version 0 = the change feed is empty because nothing calls `founder_live_tick` yet: 4b-2 (one tokio tick task + SSE) fills it. NEXT = 4b-2.

## COMPACTION-SAFE CHECKPOINT 1 Nov 06:30 PKT - what is on the server, what is next
ON SERVER + CHROME GREEN: everything through 4b-1 (Rust 71 tests, SPA with Live feed card, E100-E106, E108-E110, host-proof record). Git head when written: 157771c+.
NEXT = 4b-2 (starts only on the founder's "haan"; he has not said it yet): in `server/founder/src/`: new `live.rs` = ONE tokio task every 5 s calling RPC `founder_live_tick(true)` and publishing the new version on a `tokio::sync::broadcast`; `GET /founder/v1/live/stream` = SSE (snapshot frame, then `founder_live_since(last_id)` delta frames, each a signed envelope, 15 s heartbeat, bounded per-client queue); tests for broadcast/delta/bounded client; start the task in `main()`. NO SQL, NO UI in 4b-2. Pull = founder-install.sh. Green = `curl -N` with a valid token shows heartbeat + a change frame, and Dashboard "Live feed: Version N" is above 0 and grows.
THEN 4b-3 (SPA `useLive()` fetch-stream + kernel verify + Dashboard auto-update + Live/Reconnecting chip), 4b-4 (`pending_channels` from `founder_live_sources`), then step 5 F2c Merkle (design note first).
IF COMPACTION HITS MID-CODE: run `git status` + `git diff --stat` in /home/claude/anexomail-workspace, read this section, finish the file in progress, never restart the phase. Master index: FOUNDER-MASTER-AUDIT-01NOV.md. Rule: every turn ends with the Rule-70 report AND a short list "which blueprint features were added and what effect on the founder side" (founder order 06:22).

## UPDATE 1 Nov 07:00 PKT - 4b-2 CODE DONE (repo only, NOT green) - founder said "haan" 06:28
RUST ONLY. New `server/founder/src/live.rs`: ONE tokio task (started in main) calls `founder_live_tick(true)` every 5 s and broadcasts `Tick{version,changed,at,ok}`; a failed tick is published `ok:false` (honest). New `GET /founder/v1/live/stream` (SSE, same token): `snapshot` frame, then a `tick` frame per tick, an `events` frame (founder_live_since) when the version grew, `: hb` heartbeat every 15 s, max 20 streams, 10 min lifetime, slow client dropped, every frame is a signed envelope (`envelope()` refactor of `signed()`, same JSON). `futures-core` added (no other crate). Rollback switch: env FOUNDER_LIVE_TICK=off. 75 tests pass; real-binary mock e2e (server/founder/tests/e2e_live_stream.py): status 200 text/event-stream, snapshot at 0 s, tick every 5 s, events frame on change, 401 without token.
GREEN = founder-install.sh, then Dashboard "Live feed" card keeps its state AND `curl`-free proof: Claude checks `journalctl`-free via Chrome later in 4b-3 (the SPA reads the stream). Note: "Version" only grows when a real source changes (a new lead, a queue change); ticks themselves do not bump it.
NEXT: 4b-3 (SPA `useLive()` fetch-stream + kernel verify + Dashboard auto-update + Live/Reconnecting chip), 4b-4 (`pending_channels` from `founder_live_sources`).

## COMPACTION-SAFE CHECKPOINT 2 - 1 Nov 06:40 PKT (read this FIRST after compaction)
ON SERVER (founder-install paste 06:38: 75 tests ok, release build ok, SPA 200, healthz 200, token + Ed25519 ON): everything through 4b-2. 4b-2 = Rust `live.rs` (one tokio tick every 5 s -> RPC `founder_live_tick`) + signed SSE `GET /founder/v1/live/stream`. The founder-install ran AFTER the code, so it is installed. Not yet proven end to end in Chrome because the SPA does not read the stream yet (that is 4b-3).
Git head at this point: 3969add (+ this docs commit). Working tree clean except docs.
NEXT = 4b-3 (UI + kernel, founder-install only, no SQL, no Rust change expected):
 1. `founder-web/src/live.ts` (or hook in Surface.tsx): `useLive()` opens `fetch("/founder/v1/live/stream", {headers:{authorization: Bearer <founder token>, "last-event-id": lastId}})`, reads `response.body` with a TextDecoder, splits SSE frames on a blank line, parses `event:` + `data:`; the data is a signed envelope {data, ts, sig, alg, kid, sig_ed}; SEND IT TO THE KERNEL WORKER (same path every other answer uses in the SPA, find it in `founder-web/src/` api/trust code) and use `data` ONLY if verified; unverified frames are dropped and counted.
 2. Dashboard (Surface.tsx): `snapshot` frame replaces the Live feed card data, `tick` frame updates "last tick HH:MM:SS", `events` frame appends to a small "Recent changes" list (source, kind, delta). Chip next to the Live feed card title: "Live" (frames arriving, last tick < 15 s) / "Reconnecting" (backoff 1,2,4,8 s, max 15) / "Paused" (tab hidden: close the stream, reopen on focus). Fallback: if the stream cannot open 3 times, poll `/founder/v1/live` every 15 s and show "Polling".
 3. Stream ends by itself after 10 min: reconnect with `Last-Event-ID`. No mock data, no fake "Live" label.
 Green = Chrome: chip says Live, the "last tick" time moves every 5 s with NO reload, and when a real source changes (e.g. a new lead) a change line appears. (Version stays 0 until a real change: ticks alone do not bump it.)
THEN 4b-4 (`pending_channels` from `founder_live_sources` registry instead of the hard-coded list in `server/founder/src/bridge.rs` line ~53; Rust + SQL read only), THEN step 5 F2c Merkle (design note first).
Parked / later: L5 host guard (awam Brain `anexomail-leo` never had the guard; Brain installs use brain-*-install.sh, NOT pull.sh; solved natively at the awam migration), Mail<->Chat Bridge = step 12b. Master index: FOUNDER-MASTER-AUDIT-01NOV.md. Per-turn reply format: Roman Urdu "Nauman bhai", short, Rule-70 table, plus "features added per blueprint + effect on founder side".
