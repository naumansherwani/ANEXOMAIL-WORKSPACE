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

## UPDATE 1 Nov 07:20 PKT - 4b-3 CODE DONE (repo only, NOT green) - founder said "haan" 06:41
UI + KERNEL only (no Rust, no SQL). `founder-web/src/sse.ts` (pure: `takeFrames` SSE parser, `mergeEvents`, `backoffMs`), `livefeed.ts` (`useLive()` external store: `fetch` stream via `api.openStream` with the founder token + Last-Event-ID, EVERY frame verified by the kernel (`verifyBody`, 120 s skew) before it is parsed; failures dropped + counted; status connecting / live / reconnecting (backoff 1,2,4,8,15 s with jitter) / polling (signed GET /live every 15 s after 3 failed opens) / paused (tab hidden: stream closed); watchdog aborts a silent stream after 40 s; `gap` in an events frame forces a full re-snapshot), `api.ts` `openStream`, `Surface.tsx` (Live feed card shows the chip + "last check HH:MM:SS"; new "Recent changes" section; a real change re-reads every endpoint at once; the Bridge numbers now come from the freshest probe), `dx.css`, tests `livefeed.test.ts`. tsc clean, 7 bun tests pass, build ok, sandbox render ok.
GREEN = founder-install.sh, then Chrome: card chip "Live", "last check" time moves every 5 s with NO reload, "Recent changes" says "Nothing has changed yet. The check runs every 5 seconds." and shows a line when a real source changes. Hiding the tab shows "Paused".
NEXT: 4b-4 (`pending_channels` from `founder_live_sources`, Rust bridge.rs ~line 53 + read of the registry), then step 5 F2c Merkle (design note first).

## UPDATE 1 Nov 08:30 PKT — 4b-4 CODE DONE (awaiting founder installs)
- 4b-3 (SPA live stream) + 4b-4 both await founder: (1) sql-run.sh E111_founder_channels_telemetry CHECK_E111 (expect 9 t), (2) founder-install.sh. Then Claude proves in Chrome: chip Live, last-check moves every 5 s, Channels + Stream health cards, Dashboard "Not connected yet" now from DB (voice.registry = "db").
- E111: founder_channels (+transitions state machine, hash-chained founder_channel_events), sessions, tick minute buckets, SLO rules, reliability, tick_health, snapshot_v2, gauge, daily, stats, history, prune_v2, selftest. Rust: bridge::pending_from, live_snapshot (v2 -> v1 fallback), live::session_open/close, tick_report, sweep. Rollback FOUNDER_TELEMETRY=off.
- Next after green: step 5 F2c Merkle (E107 reserved, design note first). Every phase keeps the >=800-line SQL rule.

## UPDATE 1 Nov 07:05 PKT — 4b-3 + 4b-4 GREEN: SERVER PAR INSTALLED + CHROME PROOF (likho "server par", "repo only" nahi)
SERVER (founder paste): sql-run.sh E111 + CHECK_E111 = 9 ke 9 OK, E65 sweep OK; founder-install.sh = 77 tests, release build, SPA 200, healthz 200, token + Ed25519 ON.
CHROME (founder ki signed-in tab, reload ke baad, Claude ne khud dekha 7:04-7:05): Live feed chip "Live", text "Version 19, 12 sources, all fresh · last check 7:04:54" phir "7:05:04" (har 5 s badalta hai, bina reload); Channels card "0 of 3 connected" (asli registry); Stream health "22 checks in the last hour, none missed" (asli tick buckets); Dashboard "Not connected yet: Glitch, Support, Company Mail" ab database registry se; Customers "1 new lead"; Audit "Chain intact, entry 16".
SIRF EK CHHOTI BAAT (code nahi badla, founder ka hukam): Channels aur Stream health cards ka chip "Not connected" likhta hai jab state "unknown" ho (0 connected / abhi koi band stream nahi). Matlab sach hai par lafz "Not connected" Stream health ke liye ajeeb hai. Agla UI touch-up mein chip "Unknown"/"Collecting" karna hai (founder ki haan par).
NEXT: step 5 F2c Merkle (E107 reserved): design note pehle, phir Rust+WASM+SQL(>=800 lines). Start sirf founder ki "haan" par.

## CHECKPOINT 3 — 1 Nov 07:25 PKT (read FIRST after compaction)
ON SERVER + CHROME GREEN: everything through 4b-4 (E111 9/9, Rust 77 tests, Live chip, Channels + Stream health cards). Git head before this: 49c871f.
FOUNDER ORDERS: (07:11) har feature live wired, "Not connected" nahi; (07:17) "kaam shuru kero technology ke hisab se, tarteeb batao". = haan for step 4d P1.
BLUEPRINT TARTEEB: step 4d Founder Inbox (NEW, inserted before 5 Merkle) -> 5 F2c Merkle -> 5a -> 6 ... -> 11 Mail Desk (Company Mail live) -> 12 Systems. 4d: P1 SQL E112 (user_reports + groups + hash-chained events + SLA + severity + dedup + stats + selftest, >=800 lines) + CHECK_E112 + Rust read endpoints (`/founder/v1/inbox*`) + snapshot hook so channels `glitch`/`support` become `connected` ONLY via founder_channel_set once first real report exists; P2 Inbox UI; P3 reply (needs Mail Desk); P4 awam button = USER SIDE (needs founder's explicit ok; submit RPC `report_submit` is service_role only, called by the awam backend later).
HONEST: until P4 nothing can submit, so Glitch/Support stay "Not connected" (true). Stream-health chip: unknown -> if tick_health ok and reliability unknown, show ok from ticks (small UI/SQL tweak inside P1).
PULL ORDER P1: sql-run.sh E112_founder_inbox CHECK_E112 first, then founder-install.sh.
IF COMPACTION HITS MID-CODE: git status/diff --stat, read this, finish file in progress (E112 in docs/cursor-work/sql/), never restart.

## UPDATE 1 Nov 07:50 PKT — 4d P1 SQL DONE (E112, repo, NOT installed yet)
`docs/cursor-work/sql/E112_founder_inbox.sql` (815 lines, selftest OK + idempotent on local Postgres 16) + `CHECK_E112.sql` (10 checks). Tables: founder_reports, founder_report_groups, founder_report_events (hash chain), severity rules, SLA, transitions. RPC: report_submit (service_role, awam backend later), founder_report_set, founder_group_set, founder_report_verify, founder_inbox_list/get/stats/channels/prune/sla_watch/rules/week/search/timeline/snapshot, selftest. Live source `user_reports` registered.
STILL TO DO in 4d P1: Rust read endpoints `/founder/v1/inbox` (founder_inbox_snapshot) + `/inbox/list` + `/inbox/group`; Dashboard "Inbox" card (honest "no reports yet" until P4 button); Stream-health chip fix. Then pull: sql-run.sh E112_founder_inbox CHECK_E112, then founder-install.sh.

## UPDATE 1 Nov 08:10 PKT — 4d P1 CODE COMPLETE (repo, awaiting founder installs; NOT green)
SQL E112 (810 lines, CHECK 10 ok) + RUST `inbox.rs` (whitelisted query parser, 4 tests) and `GET /founder/v1/inbox`, `/inbox/list`, `/inbox/group?id=` (read only, signed, honest `connected:false` if E112 missing; 81 tests) + UI Dashboard card "Inbox" (chip Ready/Install, or open issues + reasons), Channels chip "0 of 3" + "Waiting for first data: ...", Stream health fixed (ok when ticks ok; chip "Collecting" while unknown). 10 endpoints probed on Dashboard.
GREEN = founder runs sql-run E112 + founder-install, then Claude Chrome: Inbox card "Ready", Stream health "Live"/ok, 10 of 10 endpoints answering.
HONEST: reports can only arrive via `report_submit` (service_role) from the awam backend => P4 (user-side button, needs founder's ok). Until then Inbox says "Ready", Glitch/Support stay waiting for first data.
NEXT: P2 Inbox UI page (list, filter, detail, status buttons = signed writes), then P3 reply with Mail Desk, P4 awam button. Merkle after.

## UPDATE 1 Nov 07:40 PKT — 4d P1 GREEN: SERVER PAR INSTALLED + CHROME PROOF
Server (founder paste): sql-run E112 CHECK 10/10 OK (+E65 OK); founder-install 81 tests, healthz 200, token + Ed25519 ON.
Chrome 07:34 (founder tab, reload): "10 of 10 endpoints answering"; card Inbox "Ready. Glitch and support reports appear here the moment a user sends one"; Channels "0 of 3 connected. Waiting for first data: Glitch, Support, Company Mail" chip "0 of 3"; Live feed Version 23, 13 sources (user_reports registered), last check moves; Bridge page unchanged (Arriving/Leaving/Needs attention).
FINDING L8: Stream health shows "75.00% of streams closed within 20 seconds | Down" (caused by my page reloads; SLO needs min sample 20 + ignore reload). Fix in P2 SQL (E113).
NEW DOC: FOUNDER-CHAIRMAN-MAP-01NOV.md (Dashboard vs Bridge vs deck pages; user UX parity list). NEXT: P2 Inbox page + E113 (>=800 lines: SLO sample rule, inbox write support, exceptions feed for Bridge), then P3, P4 (needs founder ok), Merkle.

## UPDATE 1 Nov 07:45 PKT — UI cleanup per founder 07:39 (repo, awaiting founder-install; NOT green yet)
SIDEBAR: group "Workspace (user app)" (User dashboard + 13 user links) REMOVED from App.tsx + Cmd+K list; sidebar = Dashboard, Bridge, Finance, People, Mail Desk, AI, Release, Move-In, Systems, Control, Audit ledger (+ Collapse). User-app features come to the founder as founder decks on founder endpoints/gates (FOUNDER-PARITY-30OCT.md), never as user pages.
STREAM HEALTH card REMOVED from Dashboard (it turned red on a reload). Rust `live::telemetry_on()` now defaults OFF (`FOUNDER_TELEMETRY=on` enables); e2e mock sets it on. E111 SQL stays installed (idle). L8 CLOSED by removal. Tests: tsc 0, bun 7, cargo 81.
PULL: founder-install.sh only (Rust + SPA). Green = Chrome: sidebar has no user-app group, no Stream health card, Inbox + Channels cards remain, 9 cards + Recent changes.
NEXT: P2 Inbox page (+ Bridge exception rows); sidebar item "Inbox" jodna (founder ki haan).

## UPDATE 1 Nov 08:00 PKT — Founder Workspace sidebar + bun purge (repo; founder-install baaki)
07:45/07:50 UI cleanup AND telemetry-off are SERVER PAR INSTALLED (founder paste 07:5x: 81 tests, healthz 200). Chrome proof of them = next step after the next install.
NEW (repo): sidebar = Dashboard, Bridge, group "Founder Workspace" (Mail Desk, People, AI, Systems, Control, Finance, Release, Move-In, Audit ledger) in the founder's list order; `ORDER` in catalog.ts reordered; founder-web/bun.lock removed. Doc: FOUNDER-WORKSPACE-ORDER-01NOV.md (14 user items -> founder pages + live source + step; loophole table L8-L14). New step 4e Kernel SSE port inserted before Merkle.
PULL: founder-install.sh only.

## UPDATE 1 Nov 08:20 PKT — GALTI SUDHARI: Mail vs Mail Desk (founder 07:57), repo; founder-install baaki
Founder: "mail desk mera baap nahi hai; Mail (inbox sab) alag page, Mail Desk us ke andar sab se end par." FIX: sidebar/deck key `mail_desk` -> `mail`, title "Mail" (intro + catalog: Inbox and folders, Compose and outbox, Calendar, phir "Mail Desk: ..." rows), shortcut g m = Mail. Master order step 11 + parity + audit + chairman map corrected. FOUNDER-WORKSPACE-ORDER-01NOV.md now has the true per-item table (page, master step, source, DONE / NOT DONE) and the list of what is DONE in the master order (steps 1-4b, 4d P1) vs next.
RULE (naya, hamesha): kisi bhi user-app item ko founder page ka naam dene se pehle FOUNDER-MASTER-ORDER-28OCT.md ka step padho; parent/child (Mail > Mail Desk, People > Org/CRM/Work, Systems > Analytics/Speed/Safety/ANEXOChat/Admin) wahan se lo, apni marzi se nahi.
PULL: founder-install.sh only.

## UPDATE 1 Nov 08:25 PKT — LIVE CHROME CHECK + order 08:06 recorded
Founder's Chrome tab read live: Dashboard, Bridge, Founder Workspace (Mail, People, AI, Systems, Control, Finance, Release, Move-In, Audit ledger); no user-app group, no Stream health card. Founder's laptop photos show the OLD Friday build (stale tab; index is no-store, hard refresh fixes). Mail Desk is INSIDE Mail, last (master step 11). Order 08:06 in founder-commands.md. NEXT: step 5 F2c Merkle (E107), design note first. PULL: none.

## UPDATE 1 Nov 08:50 PKT — 08:30 wording GREEN in Chrome; E107 SQL written (step 5)
08:30 wording (Bridge "2 of 2 checks passing", Channels "0 of 3 connected. Wiring next: Glitch, Support, Company Mail") SERVER PAR INSTALLED + dekha founder ke Chrome mein. E107_founder_audit_merkle.sql (830 lines) + CHECK_E107.sql (12 checks): local Postgres par 12/12 OK, selftest, selftest2 aur crosscheck (RFC 6962 recursive == iterative, 1..70 leaves) OK, dobara chalana safe. Tables: founder_audit_checkpoints (append-only, hash-chained), founder_audit_merkle_policy. RPC: root, proof, proof_check, checkpoint, due, verify, list, consistency, export, stats, pulse, vectors, preview, verify_range. SERVER PAR CHALNA BAAKI (pull command PULL-COMMANDS.md). NEXT: Rust merkle.rs, kernel merkle, UI gauge — E107 green ke baad.

## UPDATE 1 Nov 08:33 PKT — E107 SERVER PAR GREEN
Founder paste: E107 chali (sha 0fd28841f0b3b51f, ledger mein), CHECK_E107 12/12 OK, E65 sweep OK. Founder ko is phase mein koi webpull / pm2 restart nahi (SQL-only). NEXT: Rust merkle.rs + routes, kernel merkle, UI gauge (founder-install.sh).

## UPDATE 1 Nov 08:45 PKT — AWAM Rust engine paste (rust-engine-install.sh)
Server par awam pm2 `anexomail-rust` (:3200) online (uptime 3D, unstable restarts 0, restarts 231 cumulative): 32 modules (cal book overlap ics calfile rooms people team locale device dnsauth security export attach evidence dav b5 b6 mailx analytics workx crmx livex crmd trialx authx contx basx wsx billx setx calexp promx wtrpc), unit tests sab OK, main.rs patches pehle se judi, saboot theek, kuch nahi badla. Founder service alag (anexomail-founder, founder-install.sh). NOTE: awam wtrpc WebTransport udp/3443 par chalta hai — founder ka WebTransport (D10) alag port/listener lega, is se takrana nahi chahiye (phase mein port tay hoga).

## UPDATE 1 Nov 08:55 PKT — step 5 Rust + UI built (repo), server install pending
server/rust/merkle_core.rs (ek tree-qaida: leaf 0x00, node 0x01, odd promote; 9 tests, SQL E107 vectors n=1..9 se byte-for-byte), server/founder/src/ledger.rs (query whitelist, Rust second-witness check of every exported proof, auto_seal), routes GET /founder/v1/audit/merkle (pulse), /audit/merkle/stats, /audit/proof?seq=&upto=, /audit/export?from=&to=, POST /audit/checkpoint (G2 signed write); live tick seals the ledger every ~60 s when due. Dashboard card "Ledger seal" (real numbers). 94 cargo tests, tsc 0, vite build OK. PULL: founder-install.sh. Kernel (browser) verify = 5K: lib.rs MODULES + `merkle@1` ABI export + version bump + kernel publish (awam kernel lane) — not done, not in the pinned 0.5.0 wasm.

## UPDATE 1 Nov 08:58 PKT — founder-install FAIL fix (ccbea26): shared file path
Founder paste: `couldn't find file src/../../../web-wasm/src/merkle.rs` — server par sirf server/founder/src + server/rust/jwt_core.rs staged hote hain, web-wasm nahi. Kuch nahi badla (rollback sahi chala, purani binary chal rahi). FIX: shared tree file ab `server/rust/merkle_core.rs` (jwt_core ke bagal mein); founder `ledger.rs` `../../rust/merkle_core.rs`, kernel `web-wasm/src/lib.rs` `../../server/rust/merkle_core.rs`; founder-install.sh usay `$ROOT/rust/` mein stage karta hai. Simulated server layout par 94 tests + kernel 9 tests pass. RULE: server par jo bhi file crate ke bahar se aaye, installer use stage kare, warna test pehle hi fail (aur kuch nahi badalta).

## UPDATE 1 Nov 09:00 PKT — STEP 5 (5R + 5a) SERVER PAR GREEN + CHROME
Founder paste (founder-install.sh): tests 94 OK, build OK, saboot 4/4 (SPA 200, exchange 401, signing ON, healthz 200). Chrome (founder tab): Dashboard "Ledger seal" = "17 entries, the first seal comes at 50 new entries" (GET /founder/v1/audit/merkle 200, signed, kernel-verified); Audit ledger "Chain intact, entry 17"; Bridge "2 of 2 checks passing". Auto-seal ~60 s tick seals jab lag >= 50. GREEN: steps 1-4b, 4d P1 (E111, E112), 5 SQL (E107) + 5R + 5a. NEXT (founder haan 09:00): 5K kernel `merkle@1` (MODULES + export + version bump + kernel publish through awam kernel lane), phir step 6 S2.
COMMON TECHNOLOGY (attachments, founder note): ATTACH-LATEST-TECH-PLAN-27OCT.md = A1 instant dedupe (kernel sha256 -> attach.have), A2 resumable chunks (per-chunk SHA-256), A3 parallel chunks over WebTransport, A4 signed share link (HMAC, expiry, org-scoped). Awam attach_glue.rs live (E48/E72/E93). Founder side USES it (same File_Master / AttachmentChip), no second implementation: Mail compose (step 11), Mail<->Chat Bridge (12b, bridge_file_refs), AI. A3 needs WebTransport = after step 7.

## UPDATE 1 Nov 09:30 PKT — 5K kernel merkle@1 BUILT (repo), server install pending
Kernel 0.6.0 (module `merkle@1`, ABI `merkle_verify(row,path,root)`; path text `L:<hex>,R:<hex>`); wasm sha256 f7f9393d3dcf051f91d633970e4bbc188c523a692aa847b8ad059c0910d0ff52 (212282 bytes); one source `server/rust/merkle_core.rs` (95 server tests, 62 kernel tests, real-wasm test with the SQL E107 vector). Founder SPA: worker `merkle` message + `merkleVerify`, Dashboard Ledger seal fetches /audit/export for the 5 newest entries and the kernel proves them in this browser. PULL: founder-install.sh.
HONEST (awam lane): `scripts/build-kernel.sh` rewrote the AWAM pin (`src/lib/kernel/pin.gen.ts` -> 0.6.0, `public/kernel/` 0.6.0) because ONE kernel (Rule 52). The awam SITE on the server still serves 0.5.0 until its next web pull (banned lane, founder does not run it): until then `kernel-check.sh` would report a repo-pin vs live mismatch (expected, not a fault), and the awam release row (E90 `kernel_release_publish('0.6.0', ...)`) must be recorded when awam pulls. Founder side does not use E90.

## UPDATE 1 Nov 09:35 PKT — 5K SERVER PAR GREEN (founder paste + Chrome)
founder-install: 95 tests OK, build OK, saboot 4/4 (SPA 200, signing ON, healthz 200). Chrome founder tab: "Ledger seal | 18 entries, the first seal comes at 50 new entries. 5 of 5 newest entries proven in this browser" — kernel 0.6.0 `merkle@1` ne server ke export ke 5 proof khud verify kiye. GREEN poora: steps 1-4b, 4d P1, STEP 5 (E107 + Rust + kernel + UI). Chart "Founder purane 77" in FOUNDER-WORKSPACE-ORDER-01NOV.md. NEXT: step 6 S2 (Time machine + Drift & schedule) — design note first.

## UPDATE 1 Nov 10:00 PKT
N menu (Audit ledger removed, 348px, full email) installed on server AND verified in founder Chrome: GREEN. Tech chart: TECH-CHART-01NOV.md. Server install needed: none (docs only). Optional read-only check for 7b: `caddy version` and `openssl s_client -connect founderworkspace.anexomail.com:443 -groups X25519MLKEM768 </dev/null 2>&1 | grep -i "group\|Cipher"`.

## UPDATE 1 Nov 10:30 PKT
Step 6 SQL ready (E113, local 14/14). NOT yet run on the server. Founder runs the sql-run.sh command in PULL-COMMANDS.md (E113 section). After green: Rust `settings_s2.rs` + UI (Time machine, Drift & schedule), then Chrome check.

## UPDATE 1 Nov 10:20 PKT
Settings Center decision doc added (7 awam tabs mapped, S1b/E114 added after step 6). Server action pending is still only E113 (sql-run command in PULL-COMMANDS.md).

## UPDATE 1 Nov 10:30 PKT
E113 first server run FAILED at crosscheck (my bug, fixed, 981 lines). Rerun the same sql-run command; paste output.

## UPDATE 1 Nov 10:45 PKT
E113 run #2: selftest passed on server, selftest2 failed (service_role over-granted by Supabase default ACL) - fixed, rerun #3 command in PULL-COMMANDS.md.

## UPDATE 1 Nov 10:40 PKT
E113 GREEN on the server (CHECK_E113 14 OK, E65 OK). No server action pending. Next code: Rust settings_s2.rs + UI.

## UPDATE 1 Nov 10:55 PKT
Step 6 Rust + UI written and green in the sandbox. Server action: founder-install.sh (PULL-COMMANDS.md). Chrome check of the founder site only after the founder says to open it.

## UPDATE 1 Nov 11:00 PKT
STEP 6 SERVER GREEN: founder-install 105 tests OK, build OK, saboot 4/4 (Time machine / Drift & schedule routes + SPA installed). Chrome check pending (founder opens founder site when he says). No server action pending. Rule 71: AI founder-only, last.

## UPDATE 1 Nov 11:05 PKT
STEP 6 GREEN: server + founder Chrome (Time machine 18 versions with proven ticks, Drift 92/100, scheduled form live). Next S1b (E114).

## UPDATE 1 Nov 11:15 PKT
No server change. Awam settings list written to repo (docs only). E114 SQL drafted, not yet run anywhere.

## UPDATE 1 Nov 11:40 PKT
E114 not yet on the server (his first paste was the unfixed draft; failed and rolled back, nothing stored). Fixed version green locally; waits for his sql-run.sh paste.

## UPDATE 1 Nov 11:26 PKT
E114 INSTALLED + GREEN on the server (registry, 11 appearance keys, ambient catalog 301,989,888,000 looks). Rust/UI of S1b not yet on the server.

## UPDATE 1 Nov ~12:00 PKT
S1b Rust + UI pushed, NOT yet installed. After founder-install.sh: Appearance tab = 2 blocks + Ambient Studio.

- 1 Nov 11:42 S1b Rust+UI installed on server (founder-install OK). Polish SPA pending install.

- 1 Nov 11:55 S1b polish SPA: install saboot OK; live Chrome mein abhi purani SPA (diagnosis pending).

- 1 Nov 12:20 S1c written, install pending: first `sql-run.sh E115_founder_settings_s1c CHECK_E115`, then founder-install.sh.
