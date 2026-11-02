# AWAM ENGINE BLUEPRINT — founder-proven features, rebuilt the awam way (founder 2 Nov 2026 07:52-07:57 PKT)

Docs only. No code, no price change, no new rule is locked by this file. Source of the order: `docs/cursor-work/founder/founder-commands.md` (07:57). Lane letters here are **AX1-AX8** so they never collide with the founder letters A-V or the awam W-rows in `BLUEPRINT-ABC-01NOV.md`.

> **2 Nov 08:14: Personal packages are retired (founder). The awam gets only the Business ladder below.** See `PERSONAL-PLANS-REMOVAL-PLAN-02NOV.md`.


## 0a. Awam: written work and where it stands (founder 2 Nov 11:04 order; updated 11:35 with his pastes)
| Phase | What | Technology | State |
|---|---|---|---|
| PX7a/b | Country mandatory on the server + friendly organisation errors | Rust `wsx` | **GREEN**: his `MODULES=wsx` 11:1x: 6 tests ok, files same as repo, probe 401 |
| AX9b | Latency middleware, p50/p95/p99 | Rust `latency` | **GREEN**: his install: 10 tests ok, one anchor patched, build OK, health OK, pm2 online. Numbers page `127.0.0.1:3601/latency` appears after the first requests (his one check: `curl -s http://127.0.0.1:3601/latency`) |
| PX8 | Passkey sign-in without a username | Rust `passkey_glue` | **GREEN**: his run: PROOF SAB PASS incl. "usernameless: options 200 + EMPTY allow-list" and "usernameless: verify -> 200 + token"; replay, clone, injection all pass |
| PX11/PX12 | Landing "Launching soon" notice | React/TS | **GREEN**: his pull.sh (610 files same) + my Chrome look: the notice is at the very top of anexomail.com |
| GEO1 | Block AF / IL / KP at the edge | Caddy | **GREEN (applied)**: his run: 23 site blocks wired, anexomail.com 200, founderworkspace.anexomail.com 200, backup `/root/i9/caddy-geoblock-1793599658`. Honest limit: a VPN exit outside those countries is not blocked |
| MB1 | Mail folders of the two deleted test accounts | server script | NOT run: only the read-only `plan` is waiting for him |
Already GREEN earlier: E125-E130, wsx first version, sign-up page, /signup, country search, hand cursor, copy sweep, stale-green fix.
NOT written (waiting for his word, no code exists): PX7c (hide deleted organisations, DNS check, organisation settings), `/wt/rpc` latency, Premium card, AX0-AX8, founder lane G5d onward.

## 0. Packages (from `src/lib/plans.ts` + the founder's 07:57 word)
| Package | Price | Users | In `plans.ts` today? |
|---|---|---|---|
| Basic | £40 / month | up to 5 | yes |
| Pro | £105 / month | up to 20 | yes |
| Business | £360 / month | up to 60 | yes |
| Business Pro | £2,850 / month | up to 570 | yes |
| **Business Premium** | **£21,000 / month**; yearly = 2 months free = **£210,000 / year** (founder 08:04, 08:11) | Backend cap **20,000 users**; the page shows no number (looks unlimited). Older locked docs already say "UNLIMITED users" for Premium | **NO card in `plans.ts` yet** |
| AI Pro / AI Business / AI Executive | "coming soon" until July 2027 | | no features from this file |

**Answered by the founder 08:04:** £21,000 is per month; Premium has a hidden backend cap of 20,000 users and looks unlimited to the user. **Two things I record but do not decide:** (1) (price is now updated everywhere in docs on 2 Nov 08:07-08:11; the line below is kept only as the record of why) older locked docs (`PACKAGE-FEATURE-FORMULA.md`, `PRICING-POSITIONING-26OCT.md`, `packages-pricing-v6-2026-10-25.md`) still say Business Premium **£18,500** — I changed no price file; the Polar product and `plans.ts` card are his step (P3). (2) A cap that is enforced but not shown must still be **written in the plan terms / fair-use page** (the bandwidth doc already requires "a written fair-use ceiling"), otherwise it reads as a hidden limit; the page can stay free of a number, the terms must say it.

## 1. How the engine reaches awam (the rule that needs his yes)
FC44 says: awam features go to the founder, same logic and UI. This file is the **other direction**: the founder's proven engine goes to awam, **but on awam's own lane and awam's own data** (a user sees only their own company's chain, never the founder's). Method = the one the kernel already uses: ONE pure Rust core file, included by `#[path]` in each place (founder server, awam server module, WASM kernel). Awam files are never edited from the founder lane (Rule 1 / FC18). **Proposed FC45 (NOT locked, waits for his "haan"): "founder engine -> awam, per-tenant, awam lane, shared core files, awam UI/UX in awam's own style".** The kernel pin already moves both lanes together (Rule 52, W6).

## 2. Features, in build order. Each starts only when the earlier AX row is GREEN with the founder's pastes and Chrome.
| Row | Awam name | Founder engine it reuses (already GREEN there) | Plans | Awam technology | Honest limit |
|---|---|---|---|---|---|
| **AX0** | **Bandwidth meter + throttle-first** (per the existing docs above) | — (new awam engine, not a founder reuse) | all (rates only Business and up) | Rust metering + SQL + Polar overage meter + live meter UI at 80/95% | Does not exist yet; docs only today. |
| **AX1** | **My account activity** (tamper-proof) | Merkle ledger E107 + signed checkpoints G5b + kernel `merkle@1/2`, `checkpoint@1` | Basic, Pro, Business, BP, Premium | SQL (per-tenant hash chain, RLS), Rust core `merkle_core.rs` / `checkpoint_core.rs`, awam page with kernel verify in the user's browser | Proves "nothing was changed after the log key signed it", not "an outsider watched". |
| **AX2** | **Outside time on my history** | G5c RFC 3161 + OpenTimestamps (`anchor_core.rs`, kernel `anchor@1`) | Pro and up (Basic sees the chain without outside time) | same cores; awam queue and gauge; uses the SAME public TSAs/calendars, no account | TSA signer is pinned not chained to a public root; Bitcoin proof takes hours. |
| **AX3** | **Live everywhere** (no refresh) | live feed SSE + signed events (`live.rs`) | all | Rust tick/SSE, kernel verify of events, awam UI | Only sources that really change. Never a fake tick. |
| **AX4** | **Trust page** (public `anexomail.com/trust`) | latest platform checkpoint + status | all (public) | Static page + one signed JSON; the visitor's browser verifies | Shows the platform log, not any customer data. |
| **AX5** | **Sealed Agreements** ("Seal this" on an important mail) | K1 design (`FOUNDER-KILLER-FEATURES-28OCT.md`), builds on AX1+AX2 | Business: a monthly number (proposal 20, founder decides); BP and Premium: unlimited | Rust seal + SQL + kernel `intent@1` finds the promise, human presses Seal; proof bundle verified offline | Evidence, not legal advice; cannot stop a mailbox deletion, only makes change provable. |
| **AX6** | **My devices** (where am I signed in, one-tap cut, Device Trust Map) | N1 Device Trust Map, device vault (Rule 45, no IP) | Pro: list + cut; Business and up: map | SQL + Rust + React | City is device-reported, never IP. |
| **AX7** | **Insider Guard** (admin alerts from metadata only) | P2 rules (founder design) | Business and up | Rust deterministic rules over metadata events, no content read, no AI | Alerts and a reversible hold; it does not read mail. |
| **AX8** | **Poison Pill + auditor pack** | S1 Poison Pill; G5 chain + AX2 proof bundle | BP: Poison Pill; **Premium (P): auditor read-only link** where an outside auditor verifies the chain in their own browser, plus a signed export pack | WebCrypto lease key (as S1), Rust export, kernel verify | Web cannot wipe disk sectors or Downloads (said on the page). |
| **AX9** | **Speed you can trust: p50 / p95 / p99** (founder 2 Nov 09:31: "mean/average par rely karna sab se bara gunah") | NEW awam+chat+web core `server/rust/latency_core.rs` (**written, 8 tests green, std only**): lock-free atomics, 496 log-linear buckets (<=12.5% error), zero allocation on the hot path, static probes `rpc, wt_rpc, auth, mail, chat, web, db, other`; percentile = bucket UPPER edge (never flatters). Fixes 3 bugs of the first sketch (0 us underflow, `p50==0` as "not found", floor rank). | all products (platform-level); per-tenant "your workspace speed" for Business Pro and up later | Rust only. Next phases: AX9b hook `record()` around `/rpc` dispatch + `/wt/rpc` + auth + mail (installer anchor patch), AX9c authed proc `speed.snapshot` + the existing founder "Speed" page (D5/G1 reads it instead of the Bun `perf.ts`), AX9d ANEXOChat (its Brain is Bun :3300 = moves to Rust first, W-row) and website pages (browser sends its own timing). | Honest: "third-party tools choke memory" is an exaggeration; the real wins are no dependency, no allocation, no lock, and the tail is visible. Snapshot while writing is blurred by a few samples, not torn. The ENDPOINT budget targets already exist in `T-SERIES-BLUEPRINT.md` (p50 < 15 ms, p95 < 60 ms RPC). |
| **AX10** | **Sign-up and sign-in doors (signx)** (PX2) | `signx_core.rs` + `signx_glue.rs` (**live on the server, GREEN 2 Nov 09:39**): HMAC-SHA256 door token, per-address rate window, phone blind index, country wall AF/IL/KP, Gmail-style red/green + suggestions | all (every new account) | SQL E127 (GREEN) + E128, Rust, Caddy `geoblock.sh`, then React UI. Full security reasoning: `SIGNUP-SECURITY-MILITARY-GRADE-02NOV.md`. | Founder + family exempt from the passkey rule. ASVS V6.3.8 says do not reveal existing accounts; the founder chose red/green, risk reduced by token + limit + same-shape answers. |

Everything not in the table (Ctrl K palette, device vault list, the status keywords) already has files on the awam side (keyword scan, not a full audit): they are **checked first** at the start of each row ("grep before building", Rule 1), never rebuilt.

## 2b. Bandwidth: already written, NOT repeated here
Per-package bandwidth (Business 10 TB @ £12, Business Pro 30 TB @ £11, Business Premium 50 TB @ £10 with a written fair-use ceiling; Basic/Pro fair-use throttle only), the competitor check, and the four user promises (throttle first then money, inbound never blocked, live meter at 80% / 95%, Premium unlimited-ish with a written ceiling) are already in the repo, awam side: `docs/cursor-work/PACKAGE-FEATURE-FORMULA.md` (section "Bandwidth: competitor check + honest-bandwidth promise", founder 28 Oct 08:30) and `docs/claude/CEO-DECISIONS-AND-FIX-PHASES-26OCT.md` (D). The ledger says "do not write again". The competitor figures there are the **verified** ones; the Google upload/IMAP GB-per-day numbers in the chat text are marked NOT verified in that doc, so they stay out. **Rust metering / throttle / Polar overage billing is NOT built** — it becomes the first awam code step (meter first, then the rate), as a row **AX0** before AX1, only when the founder says go.

## 2c. Business Premium (£21,000 / month): the whole website, on the latest technology (founder 08:07: "is package ki technology likhi jaye gi latest wali")
Business Premium = every awam feature (Business Pro's all features, Rule 23: no AI) + AX0-AX8 in full + the P rows. One code path (`resolve_plan`, no copy); the hidden 20,000-user cap is enforced in the backend there, and the page shows no number. Status words are the blueprint's: **GREEN** = proven on the server and in Chrome, **planned** = a letter in `BLUEPRINT-ABC-01NOV.md` that is not GREEN yet. Nothing below is claimed as shipped to awam unless its row says so.

| Layer | Latest technology for this package | Where it stands (2 Nov) |
|---|---|---|
| Server | Rust (axum 0.8 + tokio, `ring`, rustls); no Bun / Node (Rule 61) for Premium endpoints | founder lane GREEN; awam Bun-free move = lettered W-rows |
| Transport | HTTP/3 + WebTransport (QUIC, `wtransport`) for live data, calls stay WebRTC | **planned** K6 |
| Key exchange / cipher | X25519MLKEM768 (post-quantum hybrid), AES-256-GCM terminator | **GREEN** K1, K2 (founder hosts); awam hosts K5 **planned** |
| Mail content | OpenPGP post-quantum, RFC 9980 (PQM) | **planned** Q4 |
| Live data protection | PQN | **planned** Q5 |
| Tamper-proof history | Merkle log (RFC 6962/9162) + signed checkpoints (C2SP) + outside time (RFC 3161 + OpenTimestamps), verified in the browser by the WASM kernel | **GREEN** founder G5a-G5c; awam = AX1/AX2 |
| Browser engine | ONE WASM kernel (Rule 52, pinned, Worker), modules `merkle@2`, `checkpoint@1`, `anchor@1`, `intent@1`, `sha256@1` | **GREEN** (kernel 0.9.0) |
| Sign-in | Passkeys (`webauthn-rs`), device-bound sessions (DBSC) | **planned** J3-J6, K7 |
| Database | Postgres with RLS on, per-tenant hash-chained tables, append-only guards | **GREEN** pattern (E107, E123, E124) |
| Front end | React 19.2, Vite 8.2, TypeScript (strict), TanStack Router, Tailwind 4.2, shadcn, Framer Motion + GSAP, Three.js WebGPU (lazy) | awam is already on the latest line (FC44); L1/L2 **planned** |
| Streaming | MoQ on an own Rust relay (one-to-many only) | **planned** M |
| Metering and billing | Rust bandwidth meter, throttle-first, Polar overage meter at 50 TB @ £10 | **not built** (AX0) |
| Hidden user cap | 20,000 users, enforced in `resolve_plan`'s single path; written in the terms | **not built**; terms text is a founder item |

## 2d. State-actor defence map (founder 2 Nov 09:31, his table) - NOT new rows, each line points at the row that already carries it
| Threat (his table) | Defence he named | Where it already is in this blueprint | State |
|---|---|---|---|
| Advanced phishing / spyware, session hijacking | FIDO2 WebAuthn origin binding + Device Bound Session Credentials (DBSC) | Sign-in row (passkeys `webauthn-rs`, DBSC) and AX6 My devices; UV-required passkeys already in the Rust passkey door; discoverable / username-less login = PX2b-2 | passkey origin binding **GREEN**; DBSC **planned** (K7); honest: DBSC is a Chrome-only feature today |
| Memory intrusion, log manipulation | Rust + WASM kernel + Merkle tree ledger | Browser engine row (kernel 0.9.0), Tamper-proof history row, AX1 / AX2 | kernel + Merkle **GREEN** on the founder lane; awam = AX1 / AX2 **planned** |
| Network interception, packet harvest | Post-quantum TLS 1.3 hybrid X25519MLKEM768 over UDP (QUIC) | Key exchange row (K1 / K2 GREEN on founder hosts, Caddy go1.26.3); awam hosts K5; QUIC / WebTransport K6 | founder hosts **GREEN**; the awam host check is command 4 in PULL-COMMANDS (read-only) |
His answer to "is this for awam?": yes - all three are written as awam rows above; nothing is duplicated here.

## 2e. Phase ledger of the awam codes written 2 Nov (founder 09:57: "saray codes awam ke blueprint ki tarteeb main phases main dalo, green hai codes server pe hain, dobara nahi likhna")
GREEN = his pasted server output. Nothing below is written twice; a phase points at the file that already exists.
| Phase | What | Technology | Files | State |
|---|---|---|---|---|
| PX0 | Personal packages removed from repo, billing, SQL, Polar | SQL + React | E125 + `CHECK_PX0B`, `plans.ts`, billing UI | **GREEN** (his paste 08:49; Polar deleted by him 08:57) |
| PX1 | Test accounts removed, Masood on business / pro | SQL | E126 + `CHECK_E126` (uses `account_purge`) | **GREEN** (09:07) |
| PX2a | Sign-up country + many mobile numbers | SQL | E127, `account_phones` (max 5, one primary, RLS) | **GREEN** (09:17) |
| PX2a2 | Phone blind index | SQL | E128, `e164_hmac` (HMAC-SHA256, HASHING.md) | **GREEN** (09:34) |
| PX2b | Sign-up doors: token, rate window, Gmail-style red/green + suggestions, country wall | Rust | `signx_core.rs` (21 tests) + `signx_glue.rs`, installer entry `signx` | **GREEN** (install + probe 09:39) |
| GEO1 | Block AF / IL / KP at the edge | Caddy | `server/caddy/geoblock.sh` + `geoblock-gen.py` | plan **GREEN**; apply waits for his "go" |
| PX2c | Sign-up UI without Personal|Business, availability hint, contact fields | React/TS | `auth.tsx`, `onboarding.tsx`, `AvailabilityHint`, `ContactFields`, `countries.ts`, `signx.ts` | **GREEN** (pull OK 09:47); Chrome look pending |
| PX3 | Company domain optional | Rust | `wsx_core.rs` `normalize_org_domain_optional` + `wsx_glue.rs` | **GREEN** (`MODULES=wsx` build OK, probe 401, 09:57) |
| AX9a | Latency percentile core (p50/p95/p99, 496 buckets) | Rust | `latency_core.rs` (10 tests) | written |
| AX9b | Latency hook: one middleware on `/rpc/*` + `/file/*`, numbers on `:3600/metrics` | Rust | `latency_glue.rs`, installer module `latency` | written 11:00; waits for `MODULES=latency`; `/wt/rpc` not measured yet |
| PX11 | Hand cursor on every dropdown / opener; stale green answer under an empty email box fixed | React/TS (CSS + hook) | `styles.css`, `CountryPicker.tsx`, `AvailabilityHint.tsx` | cursor GREEN-pending-look (pulled 10:38); bug fix waits for pull |
| PX4 | Country search + first-letter ranking | React/TS | `CountryPicker.tsx` + test (5), used by `ContactFields` | **GREEN** (his pull.sh: CountryPicker.tsx + test on the server, server==repo 609 files); hint no longer names a country (his "pakistan print ker diya"); Chrome look pending |
| PX5 | Organisation NAME optional ("<Name> workspace") | Rust + React | `wsx_core.rs` `default_org_name` (5 tests), `wsx_glue.rs`, `onboarding.tsx` | **GREEN** (his `MODULES=wsx`: 5 tests ok, build OK, probe 401) + pull.sh; Chrome look pending |
| PX6 | Organisation layer hardened (guard trigger, limits, org_events chain, domain proof, last owner, soft delete, integrity report) | SQL | E129 (545 lines) + `CHECK_E129` (12) | **GREEN** (his `sql-run`: E129 ran, CHECK_E129 12/12, E65 sweep OK; E130 fixed a varchar/text bug in the report function) |
| PX9 | Clean address: sign-up lives at `/signup`, sign-in at `/auth` | React/TS | `signup.tsx`, `auth.tsx` (redirect + address follows mode), `routeTree.gen.ts`, links in `PlanCheckoutButton`, `get-started`, `join`, `onboarding` | **GREEN** on the server (his pull.sh wrote `src/routes/signup.tsx`); **my Chrome look 2 Nov 10:30: `/signup` opens, `/auth?mode=signup` redirects to `/signup`**; marketing pages not yet checked for other `/auth` sign-up links |
| PX7a | Friendly answers for E129 trigger errors (public mail domain, taken domain, org limits, reserved name) | Rust | `wsx_core.rs` `map_org_error` (6 tests) + `wsx_glue.rs` | written 11:00; waits for `MODULES=wsx` |
| PX7b | Country MANDATORY on the server (`country_required`), onboarding shows a country box on that answer | Rust + React/TS | `wsx_glue.rs`, `onboarding.tsx` | written 11:00; waits for `MODULES=wsx` + pull |
| PX7c (open) | Hide deleted organisations in listings, `org_ensure_default` at sign-in, DNS TXT lookup for `org_domain_claim_confirm`, org settings screen (rename, add domain later) | Rust + React | not started | open |
| PX8 | Passkey sign-in WITHOUT typing a username (empty allow-list, user found from the credential id; new passkeys are discoverable; browser autofill) | Rust `passkey_glue.rs` + React `auth.tsx` | written 11:00 (passkey_core 15 tests ok); waits for `rust-passkey-install.sh` + pull. Existing passkeys made before this may not be discoverable: they keep working with an email |

## 2f. Awam: how much is left (founder 2 Nov 10:25: "ab founder ki taraf, batao kitna kaam hai awam ka")
**Done and GREEN (sign-up lane, PX0-PX6, PX9, E125-E130):** nothing in this lane is rewritten. **My Chrome look 2 Nov 10:30 (live anexomail.com):** `/signup` opens with no Personal|Business step; typing P in Country lists Pakistan, Palau, Palestine, Panama ...; picking Pakistan shows +92; `masoodsherwani` shows red "That name is already taken" + 5 green suggestions; `zq7trial2026x` shows green "is available"; the new mobile hint is live. Still not looked at (needs a login, I do not type passwords): onboarding without domain / org name and Masood's account. The live page still showed the OLD country hint "type P for Pakistan" = the fix (commit 80344264) waits for his pull.sh.
**Small, needs only his word:**
| # | Item | Technology | Needs |
|---|---|---|---|
| 1 | GEO1 apply (block AF / IL / KP at Caddy) | Caddy | his "go" |
| 2 | Mail-server mailboxes of the two deleted test accounts | server | his explicit "haan" |
| 3 | Business Premium `plans.ts` card + Polar product + 20,000 cap in the terms | React + Polar | PARKED (his 10:38: it comes only after ALL packages exist) |
**Small, my work (1 phase each):**
| # | Item | Technology |
|---|---|---|
| 4 | PX7: Rust uses E129 (hide deleted organisations, `org_ensure_default` at sign-in, DNS TXT lookup, org settings: rename, add domain later) | Rust + React |
| 5 | Country mandatory on the SERVER (today client-side only; Bun sign-up route is banned and untouched) | Rust |
| 6 | PX8: passkey sign-in without typing a username (`residentKey: required`, conditional UI) | Rust `passkey_glue` + React |
| 7 | AX9b: hook `latency_core` into `/rpc`, `/wt/rpc`, auth, mail | Rust |
**Big (feature rows AX0-AX8, none built):** 9 rows. By his own rule ("awam ka pura nahi khol lena, founder ke baad") they stay CLOSED until he opens them, one row at a time, in order AX0, AX1 ... AX8.
**Count:** 3 waiting on him + 4 small of mine = 7 items before the awam lane is quiet. 9 big rows are parked on purpose. Founder lane (G5d onward: I2, J3-J6, K-V, X1-X4) is ON HOLD and starts the moment he says go.

## 2g. PENDING list (founder 2 Nov 10:56: "yeh sab kaam pending main dalo blueprint main"). One place, honest status, nothing hidden.
| # | Item | Technology | State at 2 Nov 11:20 | What is needed |
|---|---|---|---|---|
| 1 | PX7a/b wsx: country mandatory + friendly organisation errors | Rust | written, pushed; NOT installed | his `MODULES=wsx` command |
| 2 | PX8 passkey without username | Rust | his run at 10:56 ROLLED BACK safely: the proof account `basic.test@` was deleted in E126. Installer now picks a test account that exists, and the proof tests the username-less path | his `rust-passkey-install.sh` command again |
| 3 | AX9b latency hook | Rust | his run at 10:56 stopped BEFORE build (a main.rs anchor I guessed was missing; nothing changed). Now ONE anchor (`.layer(cors);`, found), numbers on `127.0.0.1:3601/latency` | his `MODULES=latency` command again |
| 4 | GEO1 apply (block AF / IL / KP at Caddy) | Caddy | plan GREEN; his words 10:56 = go | `geoblock.sh apply` |
| 5 | Mail-server mailboxes of `basic.test@` and `alikhan@` | server | new `mailbox-retire.sh` (plan = read-only; apply MOVES folders, never deletes) | his `plan`, then `apply` |
| 6 | PX7c: hide deleted organisations, `org_ensure_default` at sign-in, DNS TXT check, organisation settings screen | Rust + React | not started | my next phase |
| 7 | `/wt/rpc` latency (WebTransport) | Rust | not measured | my next phase |
| 8 | Onboarding + Masood Chrome look | browser | not looked at (login needed) | his own look or a logged-in tab |
| 9 | Business Premium plan card + Polar product + 20,000 cap in the terms | React + Polar | PARKED until ALL packages exist (his 10:38) | later |
| 10 | AX0-AX8 feature rows (bandwidth meter, activity chain, outside time, live, trust page, sealed agreements, devices, insider guard, poison pill / auditor pack) | mixed | closed on purpose | he opens them one at a time |
| 11 | Founder lane G5d onward (I2, J3-J6, K-V, X1-X4) | Rust + WASM + React | ON HOLD | his "go" |
Landing page shows a "Launching soon" notice at the very top (`LaunchBanner.tsx`, his 10:56 order) until he says remove it.

## 3. Not in this file
Plan prices, plan caps, Polar products and the plan copy on `/plans` are **not touched** here. Putting any AX row onto a plan card is a separate order from the founder after the row is GREEN.
