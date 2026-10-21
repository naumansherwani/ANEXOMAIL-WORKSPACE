# DONE — yeh kaam ho chuka hai, DOBARA NAHI KARNA (Rule 30, founder 20 Oct 2026 20:09 PKT)

Founder (verbatim): "mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo update kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai … latest technology pe kaam kero sirf."
Compact ke baad: pehle `founder-commands.md` + yeh file padho. Neeche ki cheez dobara banane/jaanchne ki zaroorat nahi — sirf "TODO" wali par kaam. Naya kaam hote hi yahan ek line jodo.

## Tareeqa jo test ke liye ban chuka hai (dobara mat banao)
- Local Postgres (`/var/run/postgresql`, DB e39–e45 stubs) — SQL test; real Rust crates offline: scratchpad `realchk`/`fullchk` (`cargo check --offline`); `ptmp.py` = installer ka patch script; Playwright `live/integ.mjs` (blocked/warned/appeal, 3 sizes), `live/pkgate.mjs`, `live/recov.mjs`; local web `build/` + bun :3999 + `proxy.py` :8090.
- DHYAAN: `pkill -f` / `xargs kill` jisme apni command ka text ho shell ko maar deta hai (exit 144) — pid se maro.

## SQL — **E41–E47 + CHECK_E42_E47 sab GREEN (founder 20 Oct 20:21)**
| File | Kya | Halat |
|---|---|---|
| E41 family=real buyer | `\set` line hata di | DONE (live chala) |
| E42 device hash HMAC | `device_hash_v2` + migrate fn | DONE SQL (migrate script chalana: `device-hash-migrate.sh`) |
| E43 passkey/recovery codes | | DONE (live chala) |
| E44 export (scope/page/ticket) | | DONE (live chala) |
| E45 72h purge + tombstone (HMAC email) | `account_integrity_purge_due(_key)` | DONE (live: purge runner `{ok,purged:0,blocked:0}`) |
| E46 notices + appeal + email_hmac migrate | warn/block/24h/purged email outbox, `account_integrity_appeal` | DONE (live chala) |
| E47 device revoke = asli `auth.sessions` kill + links | `device_session_link`, naya `device_trust_set` | DONE (live chala) |
Check: `docs/cursor-work/sql/CHECK_E42_E47.sql` (17 row, sab true).

## Rust (`rust-engine-install.sh`, `MODULES="device export"`)
- export module (ZIP stream, ticket, `account.integrity.me`) + **blocked guard** `export_glue::blocked` — DONE, founder ne chalaya (build OK, 401 saboot).
- `account.integrity.appeal` proc + `device_glue` session link (E47) — DONE, founder ne chalaya (20:21: device 4 tests, export 11 tests, build OK, 401 saboot).

## Brain (`brain-integrity-install.sh`) — DONE, founder ne chalaya (guard + Leo bridge guard, health 200).
## Timers (`integrity-purge/install.sh`) — purge timer DONE (founder chalaya). notify worker (5 min, Postfix) + device_vault_purge hourly — DONE (founder chalaya 20:21; notify claimed=0 sent=0 failed=0 = koi pending notice nahi, theek).
## Web (`pull.sh`) — IntegrityGate, export card, appeal form, "deleted automatically on" — DONE (founder 20:21, server==repo, build OK).
## File safety — `file-safety-check.sh`: clamd **DOWN (RED)** 20:21 -> founder `INSTALL=1` chalaye (ClamAV install); GREEN tab jab EICAR FOUND aaye.

## G38 attachments bhejna (20 Oct 2026) — CODE DONE + local test, server install baqi (founder pull)
- SQL `E48_outgoing_attachments.sql` (+ `CHECK_E48.sql`), Rust `attach` module, Bun `mail/attachments.ts` + `brain-attach-install.sh`, GC timer `attach-gc/`, `attach-check.sh`, Compose UI + thread download — sab ban chuka, local test GREEN (SQL 37/37, Rust 12, Bun 27, real browser 3 sizes). Dobara mat banao; sirf server par chalwana.
- Policy: dedup SIRF org ke andar; bytes `/mnt/anexomail-box/attachments` (mount na ho to 503, NVMe par nahi likhta); DB mein sirf metadata; cap = min(plan, 7 MB raw); clamd down => `scanned:false` (jhoot nahi).
- Founder HAAN 21:38: Caddy `/files/*` band (`attach-caddy-close-files.sh`) + badi hadd. Postfix pehle se 52428800 (attach-check 21:38) => Postfix ko haath nahi lagta; E49 se ceiling 18 MB raw (base64 ~25 MB). Local: 17.5 MB upload OK, 19.5 MB 413, Bun wrap 17.5 MB 193 ms.
- Server par chale (founder 21:34-21:38): Rust `attach` OK (12 tests, build, 3x401); attach-check: storage mount OK, 1.0T khali, clamd DOWN, Caddy /files/* FAIL (band hoga).
- Pending (kaam): G38b inbound bytes, phase48 ledger se quota milana, ClamAV green.
- Test infra: `docs/cursor-work/server/tests/attach/` (README). Dobara mat banao.

- **SQL ab server se (founder 21:28):** `docs/cursor-work/server/sql-run.sh` — ek command, tarteeb se E37..E48 + CHECK_E42_E47 + CHECK_E48; ledger; fail par ruk jata hai (local test: chali, 2nd run skip, FORCE, bad file ruki, CHECK false => exit 1). Editor mein paste ab zaroori nahi. E28/E36 isme nahi (password).

## G38b aane wali mail ke attachments (20 Oct 2026) — CODE DONE + local test, server install baqi
- SQL E50 (+CHECK_E50), `inbound_attach.rs` + `deliver_bin.rs` (spool + `--spool-run`), `mig_mime` `attachment_src`/`attachment_bytes`, `rust-inbound-attach-install.sh` (+ `inbound-attach/` timer), attach-check section 4b, thread chip (download/blocked/pending). Tests: Rust 35, SQL 19/19, `tests/attach/e2e_inbound.sh` 20/20, installer sim OK. Dobara mat banao.
- `rust-engine-install.sh` replace pre-pass ab idempotent (`unless`) + `blocked` flag; patched/unpatched/live-like main.rs par test (duplicate nahi banta).
- Pending (server): sql-run (E50) -> Rust `MODULES="attach"` (blocked flag) -> `rust-inbound-attach-install.sh` -> Web pull.

## Loopholes jo band ho chuke (dobara audit nahi)
- Export sirf queue thi -> asli streaming ZIP (e2e real crates) DONE.
- Block kahin enforce nahi hota tha -> Rust + Brain + Leo guard, fail-open, 30s cache DONE (unit tests).
- purge sirf chat mitata tha -> full `account_purge` + tombstone + log trigger in-transaction DONE (local DB test).
- Block/warn par email nahi -> E46 + notify worker DONE (mock SMTP test).
- Appeal ke liye device hash maangte the -> in-app appeal form DONE (UI test 3 sizes).
- Revoke sirf app-list mitata tha -> `auth.sessions` kill (linked + UA fallback) DONE (local DB test).
- Device deletion date UI "kept until" -> "deleted automatically on"; `device_vault_purge` kisi ne schedule nahi kiya tha -> hourly runner DONE.
- File safety: ClamAV ka sach check/install script `file-safety-check.sh` DONE (mock clamd test); server par chalana baqi.
- Export download tab ko JSON error par le jata tha -> hidden iframe DONE.
- Hash policy `HASHING.md` DONE; E24 `account_deletions.email_hash` -> HMAC migrate fn (E46) DONE.

## TODO (sirf yeh)
1. Founder pulls: SQL E46 -> E47 -> CHECK; Rust `MODULES="device export"`; Timer install; Web pull; `file-safety-check.sh`.
2. Review queue UI + device deletion date UI ka live dekhna (code maujood: AccountIntegrityPanel, DeviceVaultPanel).
3. G38 server install + G38b inbound bytes; G40 Rust RPC (work/crm/org/integrations/settings); G42 passkey Rust port (Bun exception, TECH-MAP).
4. Founder protocol/profile (AnexoChat) — maujooda code modify karna, shuru se nahi.
5. Basic/Pro/Business remaining audit 1440/820/390; father ka account sab ke baad.

## Basic kab "perfect" (founder 20 Oct 22:08) — sach ka hisab
- Code: Basic ki sab maloom cheezein repo mein (G33 audit chhor kar). Basic live (Chrome Browser 1, basic.test) dashboard + inbox khule theek.
- Basic ko GREEN banne se roakne wali SIRF yeh cheezein: (1) server pulls: sql-run (E37–E50), Rust attach + inbound installer, Brain attach, Web pull, Caddy /files/* band; (2) ClamAV green (clamd DOWN); (3) pulls ke baad live: Compose attach bhejna + aane wali mail ka download + 3 screen size; (4) G33 PROMISES.md har wade ka live saboot; (5) G35 passkey gate live (27 Oct deadline) check.
- Basic GREEN = upar ke 5 live-verified. Us ke baad Pro. G40/G42 (Rust speed) Basic ko nahi rokte.

## Server par GREEN (founder 20 Oct 23:50): SQL E37–E50 + CHECK sab green · Rust attach (3x401) · attach-gc timer · Caddy /files/* band (probe 404) · attach-check GREEN (clamd WARN chhor kar)
- Brain install: "check FAIL" jhootha tha — mail-worker "Gateway Timeout" Supabase ka wakti masla, E48 nahi; installer ab sirf schema error par fail (commit). Purani Brain files wapas hain => Brain attach DOBARA chalana hai.
- clamd: service chal raha hai par 127.0.0.1:3310 band (Debian socket-activation, TCPSocket ignore) => `clamd-tcp-fix.sh` (localhost ListenStream drop-in, backup/wapas).
- Pending founder pulls (tarteeb): Brain attach · Rust inbound (`rust-inbound-attach-install.sh`, abhi chala nahi) · Web pull · clamd-tcp-fix.
- MASTER hisaab ek jagah: docs/cursor-work/MASTER-GAP-LEDGER.md (20 Oct 23:59). Compact ke baad pehle wahi.

- 21 Oct: Account page SMS line -> honest copy ("SMS recovery planned, not available yet"); Brain sms_note untouched. Calendar/Compose live tests: Chrome tab was on /auth (not logged in) -> waiting founder login.
- 21 Oct 00:20: technology consolidation DONE — TECH-MAP.md section 0d (ek faisla); founder/TECH-MAP.md = pointer; sandbox /home/claude/TECH-DECISION.md. Dobara mat karo.
- 21 Oct 00:11: Rule 31 (3-command had) RADD by founder. Pull ka sahi raasta: bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)
- 21 Oct 00:14: 3D plan alag file PLAN-3D-PARKED.md (parked), ledger mein note.
- 21 Oct 00:25: A1 script repo-vs-server-audit.sh likha (founder ko chalana baqi); 3D plan mein plan-orb rang (Business Pro = Imperial Ruby+Platinum).
- 21 Oct 00:35: calendar.create 500 = response_check ('needs_action') — E51_calendar_response_fix.sql (local proved). A1 audit natija MASTER-GAP-LEDGER mein. Calendar GREEN abhi nahi (live E51 + Chrome retest baqi).
- 21 Oct 00:40: repo-capture-server.sh likha (A2-A4). SQL run sirf server se psql (sql-run.sh) — confirm.
- 21 Oct 00:50: Calendar Basic LIVE GREEN (meeting banti hai, list mein, Load tab chalta hai) after E51. capture script safety check theek (SQL dump redact + sirf lambi literal rokti).
- 21 Oct 01:00: Undo button (30s) code likha (ComposeStudio+notify+compose.ts), tsc saaf apni files par; Web pull ke baad live test. Compose open + To/Subject/Body + Send held = Chrome par chala.
- 21 Oct 01:25: G38b download GREEN, Undo-send GREEN (Chrome). Thread action row HScroll (code). capture script: UUID/underscore literals ab RED nahi.
- 21 Oct 01:45: 390 GREEN (inbox/calendar/thread). 820 mail master-detail fix (code). Test method: Chrome same-origin iframe viewport (window resize kaam nahi karta).
- 21 Oct 02:00: Basic 21-page sweep clean; PROMISES #12 GREEN; SMS copy live GREEN.

## 21 Oct 2026 (compact ke baad ka poora hisaab — dobara mat karo)
- Calendar create (E51 constraint) GREEN; inbound hello.txt download GREEN; Compose send hold + Undo GREEN (server-side hold, cancel 200); SMS recovery copy honest; 21 Basic pages clean; 390/820 mail master-detail + HScroll header drag.
- Settings -> Appearance: "Graphics & visual effects" toggle (experience.graphics, html[data-ax-fx]) — LIVE GREEN.
- Left nav scrollbar hidden (styles.css) — LIVE GREEN.
- Brain CRM tenant isolation installed (brain-crm-install.sh) — health 200, unauth 401.
- SiteNav hamburger until xl (1024-1268 overflow) — pushed 138de99, live retest pending.
- 39-load sweep (13 routes x 390/820/1200): 0 empty/0 error.
- Checkout: Basic -> Pro Upgrade opens Polar (Pro £46/mo); not paid.
- Capture script: pg_dump OK 40772 lines, snapshot PUSHED af24025 (live-snapshot/sql/schema-public.sql etc.); false RED (alphabet constant) filtered.
- Passkey: test accounts exempt in repo auth-passkey.ts; live Brain file differs from repo => use brain-passkey-exempt.sh (surgical), NOT brain-passkey-install.sh.
- 3D v1 BUILT 216b00c: src/lib/fx.ts + src/components/fx/* (mailbox hero, logo loader, plan orb, empty gems, plans tilt). Live test after Web pull.
- Rule 34 (mobile/tablet priority + test accounts exempt from passkey deadline) in AGENTS.md.
- Manifest: sync only auto-tracks git-status src changes; pass explicit paths for new/committed files, always verify 0 bad.
- FOUNDER LOCK 21 Oct 02:20: public/landing pages par 3D/graphics NAHI. MailboxScene.tsx file rakhi hai par kahin wire nahi; dobara landing mein mat lagao.
- FOUNDER LOCK 21 Oct 02:31: dashboard plan-orb HATA (bura laga). Dobara nahi.
- 21 Oct LOGIN-LOOP fix code (auth-harden.ts + client retry + /auth redirect for signed-in) — READY; live verify baqi (founder login ke baad).
- 21 Oct 02:45 FxAmbient (edge glow + aurora blobs, plan colours, toggle-controlled) READY; Web pull + live test baqi.
- FOUNDER LOCK 21 Oct 02:50: FxAmbient aurora blobs HATA (hard blue stain bura laga). Sirf patli edge-light + 3D scenes + hover glow. Brain installer pre-flight node_modules upar se dhoondta hai (pehle FAIL tha, kuch install nahi hua tha).
- 21 Oct 03:15 Rule 35 + login-probe.sh. Rust no-touch. Bun-only edits listed in AGENTS Rule 35.
- 21 Oct 03:30 Rust auth_user hardened (cache 20s + transient retry) READY: rust-auth-harden.sh. Chrome = sirf final look (Rule 36).
- 21 Oct 03:28 login-probe v2: koi typing nahi (admin magic-link token, Brain+Rust parallel probe). Founder ne v1 par empty Enter dabaya tha.
- 21 Oct 03:35 PROBE RESULT: Brain 4 auth routes x72 calls sab 200 (login-loop server-side band). Web bb9007e pulled OK. Rust auth cache already live. Probe Rust path fixed (billing.subscription).
- 21 Oct 03:50 Calendar desktop week = real TimeGrid (hour rows, now-line, overlap columns, drag move + resize, notify-guests confirm). Frontend only: data/update stay on Rust calendar.update (founder: calendar Rust pe hi rahega). Live check baqi.
- 21 Oct 04:05 G-DOM fix: Domains cap note neutral+singular ('Basic includes 1 domain — all in use...'), not warning-orange.
- 21 Oct 04:20 G-ALIAS (Option A): E52_alias_cap.sql trigger (Basic/Pro 5 aliases, Business unlimited) — local PG16 test OK; UI 'n of 5 aliases' + alias_limit message. SQL server par chalana baqi: sql-run.sh E52_alias_cap CHECK_E52
- 21 Oct 04:30 E52 alias-cap REVERT (founder: reality = server/repo). Card text reality par: 'Free aliases — no extra seat'. Plan cards ka har wada product se match hona chahiye.
- 21 Oct 04:10 CEO faisla: Basic card = domain/mailboxes/5GB/undo/ownership/contacts/cmd+K/'Free aliases' (cap card par NAHI); chhupa fair-use cap 25 alias via E52_alias_fair_use.sql (local PG16 test OK; server par chalana baqi: sql-run.sh E52_alias_fair_use CHECK_E52). Card: '1 company domain' / Pro '3 company domains'.
- 21 Oct 04:20 Plans compare table: 'Company domains you can host' 1/3/Unlimited (E15 org_domain_cap NULL=unlimited). Cards single-source plans.ts.
- 21 Oct 04:25 Calendar drag LIVE VERIFIED (Rust calendar.update, move+day change, persisted). Optimistic update added (no jump-back). Test event restored to Wed 02:30.

## B1 — Long-lived auth (repo-written, install pending live proof)
- Rust: ES256 local JWT verify (`server/rust/jwt_core.rs`, JWKS cached, kid match; fallback to GoTrue only for UnknownKid/UnsupportedAlg) + real revocation via `public.auth_session_alive` (E53, 5s cache) + one shared pooled `http()` client.
- Brain: `POST /api/auth/refresh`; login/oauth/passkey return `refresh_token` + `expires_at`.
- Client: `api.ts` one-shot 401→refresh→retry (parallel calls share one refresh), `ensureFreshToken` timer in `auth.tsx` (last 5 min, 60s tick, visibility/online). Tests: `src/lib/api-refresh.test.ts` (8), `jwt_core` (9).
- Install order: SQL E53 → Brain `brain-refresh-install.sh` → Web pull.sh → Rust `rust-jwt-install.sh`. GREEN only after live proof (login stays, refresh works, logout revokes).

## FOUNDER RULE (21 Oct 04:37, LOCKED): pull commands HAMESHA poori copy-paste form mein, technology ke hisab se alag block (SQL / Brain / Web / Rust). Sirf script ka naam NAHI. Batch ke saath-saath memory (repo + sandbox-state) update, compact ka intezar nahi.
Format: `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/<script>.sh) [args]`

## B1 GREEN (21 Oct 04:55) — server par live: SQL E53, Brain refresh, Web pull, Rust jwt. Logout 26s baad token 401 (revocation asli), refresh asli. Dobara mat banao.

## Universal UI mechanism (21 Oct 05:00): AGENTS Rule 37 + `src/lib/tier-guard.test.ts` (ratchet, baseline 18) + `tier-sweep.sh`. Package-wise alag edit nahi; tier farq sirf plan-surface.ts capability se.

## B2 GREEN (21 Oct 05:50): passkey/recovery login Rust par server par chala, proof SAB PASS + Web pull. Dobara mat likho.

## B2b READY (21 Oct 05:40): Bun fallback passkey hardening + Rust passkey list/delete — repo mein, server par chalna baqi (brain-passkey-harden-install.sh, rust-passkey-install.sh dobara, Web pull). Dobara mat likho.

## B3 READY (21 Oct 07:00): R1 mail pipeline Rust par — repo mein, server par chalna baqi. `mail_core.rs`+`mail_glue.rs` (mail.send, mail.schedule, mail.schedule.cancel, Rust queue worker, org.mailboxes.list/create), SQL E54 claim, Brain claim/cancel patch, client Rust-first. Sandbox proof SAB PASS (Bun bytes ke barabar). Install: SQL E54 -> Brain brain-mail-install.sh -> Rust rust-mail-install.sh -> Web pull. Dobara mat likho.

## B2b GREEN (21 Oct 05:50): founder output — Brain passkey-harden OK, Rust passkey-install proof SAB PASS (list/delete included), Web pull OK. Dobara mat likho.
## B3 server par: SQL E54 OK, Brain brain-mail-install OK, Web pull OK. BAQI: rust-mail-install.sh output -> phir B3 GREEN.
## Technology (founder locked): Tokio/axum/QUIC(wtransport 0.7.2)/tRPC-style /rpc = pehle se LIVE, poori website ke liye (plan-wise nahi). Baqi sirf B4 (event-driven WT push) + B8 (tokio 1.54, Bun 1.4.3, Brain->Rust).

## B3 GREEN (21 Oct 06:00): mail.send + undo-send + Rust queue worker + org.mailboxes Rust par server par chala, proof SAB PASS (asli Postfix). Dobara mat likho.
## Tarteeb (founder locked 05:53): technology migration B4->B8 pehle, phir Pro -> Business -> Business Pro. Agla: B4 (WT push), B5 G40, B6 G16, B7 G26/G27, B8 Brain->Rust.


## B4 READY (21 Oct 07:30): R5 event-driven WT push (events_core/events_glue/events_patch/rust-events-install/events-proof, client live-core.ts+live.ts, deliver_bin hub push). Asli QUIC sandbox proof SAB PASS (family org bhi). Install: rust-events-install.sh -> rust-deliver-install.sh -> Web pull. Dobara mat likho.

## B4 install fix (21 Oct): live main.rs mein router end ka exact text alag tha => events_patch.py ab regex anchor (`.layer(cors);` ek hi) se judta hai. EVENT_SECRET live .env + mail.env mein likha ja chuka. deliver install OK (35 tests, asli Postfix->Rust OK) — hub push wali binary lag chuki. Baqi: rust-events-install.sh dobara.

## GREEN-BOARD (21 Oct 06:50): docs + repo ka green/not-green hisaab `docs/cursor-work/GREEN-BOARD/` (+ `NOT-GREEN/` side folder) — bana diya. Dobara mat banao; status badalne par sirf wahi row update.

## B4 GREEN (21 Oct 06:50): event-driven push Rust par server par chala, proof SAB PASS (family bhi). Dobara mat likho.

## EK BLUEPRINT (21 Oct 06:55): docs/claude/FINAL-FOUNDER-BLUEPRINT.md bana; MASTER-BUILD-PLAN + anexomail-blueprint par pointer. Naya blueprint mat banao, isi mein update.

## GREEN RULE (21 Oct 06:56): file server par + wire = GREEN. GREEN-BOARD isi se regrade (live dekha / server par). Dobara strict "live proof only" se mat grade karo.

## founder-commands.md vs server (21 Oct 07:10): GREEN-BOARD/07 bana — poori file padhi. Server par NAHI: chat audit, iMIP, Bun->Rust baqi, Caddy check script, /terms page, Domains ke 7 features. Dobara mat padho; naya command aaye to sirf 07 mein row.

## ops-ufw-passkey.sh (21 Oct 07:10): ufw 3443/udp + passkey test-exempt ek idempotent command. Founder output aane par D11 ufw + passkey-exempt GREEN.

## B5 (G40) SHURU 21 Oct 07:20 — IN PROGRESS (green nahi)
Kaam: founder pages ki Bun-only calls Rust /rpc/* par (movein capacity/request/deal/cockpit/deal-id; release checks/run/checklist/item/deployments/lock/roadmap; revenue pipeline/lead; public status; ai chat; mail thread; outbox/send). mail.send B3 mein ho chuki.
Plan: server/rust/b5_core.rs (std-only, rustc --test) + b5_glue.rs; b5_patch.py; rust-b5-install.sh; b5-proof.py; client rpcOrRest. Sab Supabase #4 (Rust sb_* wahi). Bun REST fallback rahega.
Live Brain routes pehle dobara padhi (movein.ts, release.ts, revenue.ts). Green sirf founder ke server output ke baad.
- B5 21 Oct ~08:10: server/rust/b5_core.rs (19 tests) + b5_glue.rs + engine-installer `b5` module (public_call w/ headers) + docs/cursor-work/server/b5-sandbox-proof.py (+tests/b5/{bun-harness.ts,express-shim.js}) => SAB PASS (~80 checks, ASLI Bun routes vs Rust, ek hi mock DB). Baaki: client rpcOrRest wiring, memory, manifest, push, founder pull. AI chat B8 mein (Leo memory+OpenRouter stream). mail.thread pehle se Rust.

## STANDING ROLE 21 Oct 07:35: CEO-agent — advance code + 4 devices (mobile/tablet/laptop/desktop) UX + frontend tech audit; Lovable/Cursor ki galtiyan khud fix.

## STANDING RULE 21 Oct 07:35: frontend (mobile/tablet/laptop/desktop UX) + Lovable/Cursor ki galtiyan khud fix karna — CEO ka kaam (CHAT-CONTEXT dekho).
- B5 frontend+backend combo audit 21 Oct 08:50: FIXED (a) pricing bug: Bun revenue.ts PLAN_PRICE 20/40/85 + SLA 700 and release.ts pipeline (SLA 500, seat 40) were STALE vs locked Basic £23/Pro £46/Business £97/Priority £790 -> Bun + Rust b5_core now 790/46 (sandbox proof re-run SAB PASS); (b) founder Move-In cockpit: no confirm before Execute/Arm cut-over -> new ConfirmButton (two-tap), fake 0 while loading -> "—", error+retry, deal detail loading/error, scroll-into-view on phone, Roman Urdu UI strings -> English, off-token colours -> success/warning/danger; (c) launch tabs/buttons/checklist cycle 28-32px -> ax-tap (44px on touch); QA detail no longer truncated on phone; roadmap sort divide-by-zero; status page unknown-state fallback + smaller h1 on phone; customer movein retry/break-all. NOTE: iOS input zoom was ALREADY handled globally (styles.css pointer:coarse 16px) - not a bug.
- LIVE Chrome check 21 Oct 08:45 (Pro account, nayi tab, iframe 390/820/1440 trick because window resize has a minimum width): /status OK all 3 sizes; 12 app routes x 3 widths = 36 loads: 0 page-level horizontal overflow, 0 errors. /app/team = 404 (route does not exist, my guess). Founder pages (/app/founder/*) return "Not found" on the public host (founderworkspace host + IP allowlist) -> founder must view those. status.tsx: odd last tile spans 2 cols on sm+ (empty grey cell at 820 fixed).

## 21 Oct 2026 08:0x — Logo + Brain price-fix installer
- A logo = `src/components/site/BrandMark.tsx` (repo == server). Page-load par pehle se use: `CinematicSplash` (sign-in ke baad) aur `WorkspaceLoader` (/app khulte waqt). Lovable ki base64 BrandMark command server par chalane ki zaroorat nahi — pull.sh use overwrite kar deta. Agar Lovable ka alag version chahiye to .tsx file repo mein aayegi, server par seedha nahi.
- `docs/cursor-work/server/brain-pricefix-install.sh`: Bun `revenue.ts`/`release.ts` ke 4 stale daam (20/40/85/700, 500, 40) -> 23/46/97/790, 46. Surgical + idempotent + bun build preflight + restore. Sandbox PASS (purani file par lagta hai, dobara = "same").
- Server par abhi baqi: Web pull (9b6c254/6c9f997), `MODULES=b5 rust-engine-install.sh`, `brain-pricefix-install.sh`.

## 21 Oct 2026 08:3x — FOUNDER COMMAND CENTER (founder.brain.command) — founder ne kaha "founder home dump hai, brain banao"
- Lovable BrandMark command server par chali: file repo se byte-for-byte same (3755 bytes) => kuch nahi bigda. Server par `BrandMark.tsx.bak` extra hai (hata dein).
- Rust (b5 module mein, naya installer nahi): `b5_core.rs` mein `Signals`/`attention`/`overall`/`blind_spots`/`parse_iso_ms` (23 tests PASS); `b5_glue.rs` mein `founder.brain.command` (10 sources ek saath, ek fail => blind_spot, 500 nahi). `committed_numbers()` ab pipeline page aur command center dono ka ek hi hisaab.
- Sandbox: `b5-sandbox-proof.py` SAB PASS (naya section 4b: 8 checks).
- Frontend: `src/lib/founder-brain.ts`, `src/components/app/founder/CommandCenter.tsx`, `src/routes/app.founder.tsx` (command center sab se upar, "Run the company" mein SAB 14 founder surfaces — pehle Move-In/Analytics/Calls/Integrations/Safety/Settings/Admin ka link hi nahi tha, mailboxes neeche).
- Rule: Bun twin NAHI (naya kaam). Rust band ho to screen saaf likhti hai, andaza nahi lagati.
- Server par chalana: Web pull + `MODULES=b5 rust-engine-install.sh` (+ `brain-pricefix-install.sh`).

## 21 Oct 2026 08:1x — FOUNDER KA HUKM (locked): founder workspace = NO BUN, NO NODE, shuru se
- Founder ne React CommandCenter (b4c3666) pull karne se mana kiya => repo se HATA diya (app.founder.tsx purani, CommandCenter.tsx + founder-brain.ts delete). Rust `founder.brain.command` + `attention` rules (b5_core.rs) RAHENGE — naya founder service wohi data use karega.
- Naya founder workspace: akela Rust binary (`anexomail-founder`), server-rendered, koi Node/Bun/React/npm build nahi; founder host par hi; premium, latest tech. Banana shuru.
- Web pull ka sahi form: `bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/pull.sh)` ( /opt/anexomail-web/pull.sh maujood NAHI — founder ka pehla try "No such file").
- Brain price-fix installer server par OK (backup /root/anexomail-backups/brain-pricefix-20261021-025455). Rust b5 installer ne "files same" kaha kyunki Web pull nahi hua tha (working tree purani) — Web pull ke baad `MODULES=b5` dobara.

## 21 Oct 2026 08:2x — FOUNDER WORKSPACE PLAN likha (docs/claude/FOUNDER-WORKSPACE-PLAN.md)
- Founder: God-level admin view (har user, abuse), Mail Desk (jawab dena), duniya ka advanced 3D (WebGPU/wgpu), tokio async, Rust-only (no Bun/Node). **B-series (B5–B8) KHATAM hone ke BAAD** shuru (F0 design pehle). Abhi kuch build/deploy nahi — React CommandCenter repo se hata diya, dobara mat banao.
- Sandbox: crates/wasm target ke liye `NO_PROXY= no_proxy=` karna padta hai; Leptos 0.8 + wasm32 mil jata hai.
- God view L3 (content) = break-glass raaye (founder faisla karega).

- 21 Oct 08:15 LOCKED: founder customer ki privacy kabhi breach nahi karega — content access (break-glass samet) HATA diya, sirf metadata. Founder side B-series GREEN hone ke baad shuru.
- 21 Oct 08:20: "God view" ka naam => **Founder view**. Founder ka alag email system; baqi ANEXOMAIL addresses + Nexatect (parent company) addresses baad ka kaam. B5 verification: repo se alag, server par seedha command. B6 shaam ko.
- 21 Oct 08:25: founder ka frontend stack repo mein darj (PLAN §2b): Caddy HTTP/3, React 19.2, Vite 8.2, TanStack Start/Router, Tailwind 4.2, Radix/shadcn, Three.js, Framer, GSAP + Rust SSE auto-refresh. TAKRAO (no Node vs Vite) => meri sulah: build-time only, Rust binary static serve. Founder jawab: 'sulah theek' ya 'pure Rust'. Email addresses (10, founder-plan.ts) build+wire = alag kaam B-series ke baad. Founder kaam B6 + B-series ke baad.
- 21 Oct 08:3x: CEO faisla founder stack = SULAH (React/Vite/TanStack build-time -> static SPA, Rust binary serve + SSE). Lists: docs/claude/TECH-STACK-BEAST.md (backend beast A, frontend B). B5 server verification (founder output 08:27): services online, health 200, Rust public procs live, founder procs 401, Rust SLA 790/seat 46, Brain 23/46/97/790, ConfirmButton + BrandMark on web => B5 GREEN. founder.brain.command server par abhi nahi (Web pull + MODULES=b5 baad mein, koi jaldi nahi).
- 21 Oct 08:33: B5 GREEN; shaam ki list `docs/claude/EVENING-PENDING-2026-10-21.md` (B6 -> B7 -> B8 -> migration test -> live package tests -> founder side). Koi duplicate code nahi.
- 21 Oct 08:4x LIVE Chrome check calendar (Basic, anexomail.com/app/calendar, founder login): form fields = Title, Guests, datetime-local, duration 15-90m, Find a time, Location/link, Agenda (agenda gate: no agenda no meeting), Create/Cancel; views Month/Week/Day, Avail. (free slots + copyable availability API link), Load, .ics import/export. Recurrence/booking page/iMIP/CalDAV NAHI => B7 shaam ko, in sab ko dobara dhoondna nahi.
- 21 Oct 21:14: WASM/kernel/SHA-256/HMAC founder workspace plan §2d mein add (TECH-STACK-BEAST §D reference). Shaam shuru: B6 pehle, phir B7; 'naya calendar' Pro/Business check founder ke account-switch par.
- 21 Oct 21:22 Polar engine recon (founder server output): nakshа docs/claude/POLAR-ENGINE-MAP.md. Polar service mein portal/cancel endpoint NAHI; read_billing/create_checkout bina auth (public Caddy exposure verify baqi). Founder: 'polar source of truth, pehle samjho phir B6'. Polar ko ijazat ke baghair haath NAHI. Dobara recon mat maango.
- 21 Oct 21:24 SUPABASE EMAIL (30 Oct 2026 se): public schema mein NAYI tables ko Data API (supabase-js/PostgREST) ke liye explicit GRANT chahiye; purani tables par asar NAHI. **NAYA RULE (SQL):** har naye `create table` ke saath usi file mein grants — server-only table (Rust/Brain service_role use karte hain) => sirf `grant select,insert,update,delete ... to service_role`; user-facing (RLS) => `authenticated` + RLS policy; **`anon` kabhi default nahi** (privacy). Repo audit: ~50 SQL files mein se phase17/phase18/E37 mein koi grant nahi (purani tables, asar nahi; sirf db reset/naya project/preview branch par dikkat). Pehle se thin: phase26, phase27, phase37, E35, phase61 (grant < tables) — 30 Oct se pehle ek 'grants heal' SQL (idempotent) likhni hai.
- 21 Oct 21:41 FOUNDER HUKM: Polar = control plane meri server par; payment tootna nahi chahiye; checkout click par instant. B6 isi par shuru. Plan: docs/claude/POLAR-CONTROL-PLANE-PLAN.md. Polar engine par kaam ki ijazat mili (surgical + backup + restore-on-fail). Webhook receiver pehle se WAL-first hai — usay mat chhedo. Caddy logs saboot: billing/ 1 (founder curl), checkout 0, webhook 264 => 2 public darwaaze band karna safe. Caddy kabhi nahi tootna (founder: over my dead body).
- 21 Oct raat B6a BANA (GREEN nahi): Polar engine pcp.rs muhar + portal + kill switch (54 pass), Rust billing.portal module b6 (13 pass), Bun fallback + mount-order fix, ManageBilling UI, caddy-polar-lockdown.sh, installers. Dobara mat likho. Checkout prewarm B6b (Brain intent + landing-adjacent => founder ijazat).

## B6a (21 Oct 2026, 22:05) — CODE LIKHA JA CHUKA HAI, DOBARA MAT LIKHO (commit 0a32282, repo + sandbox-state/b6/)
Status: BANA + SANDBOX-PROVEN (polar-cp-proof 54/0, b6-sandbox-proof 13/0, pcp 10 tests, b6_core 5 tests). SERVER PAR ABHI CHALA NAHI => GREEN NAHI (founder ka output chahiye).
Files (sab maujood, naya likhne se pehle parho):
- server/rust/polar-payment/pcp.rs (muhar HMAC/nonce/kill-switch/allowlist) · main.rs (pcp_gate middleware, POST /api/v1/portal, PAUSE_PORTAL/PAUSE_CHECKOUT, PCP_POLAR_API test-only env) · deploy.sh (pcp.rs copy) · pcp-call.sh · polarpayments.Caddyfile (sirf polar-webhook*)
- server/rust/b6_core.rs + b6_glue.rs (billing.portal, module b6 in rust-engine-install.sh)
- server/routes/billing-sync.ts (POST /api/billing/portal + pcpHeaders) · server/index.ts (billingSync auth router polar se PEHLE) · docs/cursor-work/server/brain_portal_patch.py + brain-portal-install.sh (patcher(original)==repo exact)
- docs/cursor-work/server/polar-control-plane-install.sh · caddy-polar-lockdown.sh (MODE=plan|apply) · polar-cp-proof.py · b6-sandbox-proof.py
- src/components/app/billing/ManageBilling.tsx · src/lib/billing-platform.ts (useBillingPortal) · src/routes/app.billing.tsx ("email us" hata)
Server install tarteeb (founder ke output ka intezaar): 1 Web pull -> 2 polar-control-plane-install.sh -> 3 MODULES=b6 rust-engine-install.sh -> 4 brain-portal-install.sh -> 5 caddy-polar-lockdown.sh (plan, phir MODE=apply) -> 6 Manage billing asli click (390/820/1440).
BAQI (B6b/c): checkout prewarm (Brain /intent + PlanCheckoutButton landing-adjacent => founder ijazat + shadow mode), pool/index tuning, alarms, diary chain, .env chmod 600, non-root user.
Sach ki hadd: asli Polar customer-sessions jawab sandbox mein nahi; frontend screenshots sandbox mein nahi (npm DNS band) — dono server/Chrome par.
Sandbox tips: engine binaries /tmp/engine-orig,/tmp/engine-new; rust app /tmp/claude-0/rs (b6 patched); pkill -f apni shell maar deta hai — pkill -x use karo.
- 21 Oct 22:10 FOUNDER RULE DECLARED PUBLIC: package badalna = naye package ka POORA price, purane ka credit/adjust/refund nahi (E22 code pehle se). Page: src/routes/billing-policy.tsx (/billing-policy) + link ManageBilling mein. routeTree.gen.ts build par regenerate hoti hai (haath se nahi chheda). Footer/landing link NAHI joda (landing no-touch) — founder ijazat par.
- 21 Oct 22:40 BootSplash (src/components/site/BootSplash.tsx + __root.tsx): /app ka HTML khali tha (ssr:false) => mobile par khali kala screen; ab asli BrandMark "A" + ANEXOMAIL + progress bar turant (inline CSS/JS), page/loader paint hote hi fade; public pages par band; 15 s failsafe; reduced-motion. Real Chromium 390x844 dpr3 mein test (screenshots), observer release test. NOTE sandbox ab bun install (NO_PROXY=, package.json bina lock => /tmp/full/node_modules, repo mein symlink) + tsc + vite build + Playwright chalta hai. routeTree.gen.ts build se regenerate (billing-policy shamil).
- 21 Oct 23:55 BILLING PORTAL BLUEPRINT likha: docs/claude/BILLING-PORTAL-BLUEPRINT.md (founder ki 16-point list ka CEO verdict table + phases P0-P8 + arch). P1 bana: portal/public/index.html (branded placeholder, asli A) + docs/cursor-work/server/caddy-billingportal.sh (plan/apply, additive Caddy file, rollback) — 390/820/1440 par overflow nahi. DNS A record founder ne Namecheap par add kiya. Server par abhi nahi chala (founder ka output chahiye).
  Founder se faisle baqi: (#5) churn discount (prices locked => founder likhit hukm), (#8) SMTP 421 grace — MAIN NAHI KARUNGA (read-only + sending pause, inbound hamesha), auth cookie vs ticket, finance role v1/baad. Dobara blueprint mat likho.
- 22 Oct 00:05 FOUNDER HUKM (final): (1) portal build ROKA — pehle B6a server install + saare maslay GREEN, phir hi billingportal. (2) Discount KABHI NAHI (churn 50% bhi nahi). (3) Grace 3 din theek: countdown banner -> read-only + sending pause; inbound hamesha qabool, data kabhi delete nahi, SMTP 421 NAHI. (4) CEO faisle: shared cookie + passkey step-up, finance role CEO tay karega. (5) Founder ne Caddyfile dikhaya: billingportal block abhi MAUJOOD NAHI, `import /etc/caddy/sites/*.caddy` maujood => caddy-billingportal.sh (additive) safe; portal Caddy step B6 green ke BAAD.
- 22 Oct 00:15 billingportal.anexomail.com founder ne haath se /etc/caddy/Caddyfile ke akhir mein joda (respond "coming soon", validate OK). Doosra pura-Caddyfile-overwrite command (billingportal par /api/v1/billing/* -> :3400 unsigned) CHALANA NAHI — lockdown ke khilaf. caddy-billingportal.sh ab duplicate host par skip karta hai.
- 22 Oct 00:40 DESKTOP LOADER BUG THEEK: WorkspaceLoader mein 2D fallback logo + 3D A + doosra wordmark teen logo ek ke upar (purana "3D layer v1" bug, BootSplash nahi). Fix: Fx3D prop hideFallbackWhenLive (3D chalte hi fallback fade; 3D fail => fallback wapas), fallback ab compact A; .ax-loader-sweep ab fixed box ke andar background-position se chalta hai (pehle khara hua grey rectangle). Real Chromium 1440/820/390 (swiftshader WebGL) mein test. Harness: vite config + AuthProvider/QueryClientProvider wrapper (useLocale ko provider nahi chahiye).
- 22 Oct 00:55 LOADER HERO = ASLI A (founder ka hukm): WorkspaceLoader se generic silver 3D A (Fx3D logo scene) HATA diya; hero ab asli BrandMark A (96px, glow, perspective swing), neeche sirf wordmark (A dobara nahi). Fx3D ka hideFallbackWhenLive prop code mein rehta hai (doosre scenes ke liye) par loader use nahi karta. NIYAM: koi generic/naya logo asli A ki jagah NAHI — loading, splash, hero sab jagah sirf BrandMark A. Real Chromium 1440/390 test. Dobara 3D logo loader mein mat daalna.
- 22 Oct 00:50 B6a SERVER STATUS (founder ka server output dekha): 
  Step 1 Web pull ✔ (516d0a3 tak, baad mein bc59368 loader fix pull hona baqi/founder karega).
  Step 2 polar-control-plane-install.sh ✔ GREEN (2 run; pehle run mein proof-bug: metrics counter restart par zero => baseline restart ke BAAD, fix d567a36; doosre run: ready true, secrets loaded, test events dono 200, received 0->2, bina muhar portal 401, XFF billing 403, signed call asli Polar tak => no_billing_account 404). Script Rust sources origin/main git objects se leta hai (web tree mein nahi hote) fix 8b270b3.
  Step 3 MODULES=b6 rust-engine-install.sh ✔ GREEN (unit tests b6 5 pass; main.rs pehle se judi; Rust ne billing.portal pakda: nakli token => 401 Session invalid; anexomail-rust online).
  BAQI B6a: Step 4 brain-portal-install.sh · Step 5 caddy-polar-lockdown.sh (plan phir MODE=apply) · Step 6 asli "Manage billing" click 390/820/1440 · phir loader/favicon/WORKSPACE-lockup faisle.
- 22 Oct 00:50 billingportal.anexomail.com LIVE: founder ne Caddyfile mein haath se block joda, phir asli placeholder (A logo, title "Billing center — ANEXOMAIL", file_server /var/www/billingportal, headers) laga diya; HTTP 200, h3 advertised, ufw 443/udp allow. Gemini ka "poori Caddyfile overwrite + billing proxy" command CHALANA NAHI.
- 22 Oct 00:50 LOGO FAISLA PENDING: BootSplash/loader mein "A" ke neeche WORKSPACE lockup — Option 1 (BrandMark jaisa, meri sifarish) ya Option 2 (wide, lines) founder ka jawab baqi. Favicon (public/favicon.svg) asli BrandMark gradient se ek-source banane ka demo founder ko dikhana hai (haan/na baqi). Landing/profile/AppShell/loading sab ek hi BrandMark; profile gol button mein user avatar ya UserCircle2 icon (logo nahi).
- 22 Oct 00:55 FOUNDER FAISLE: (1) Loading mein WORKSPACE lockup/Option 1-2 NAHI — BootSplash jaisa abhi hai (A + ANEXOMAIL + bar) wahi rahe. (2) "Command center" label (dashboard Greeting eyebrow) SIRF founder (session.user.is_founder) ko; real user ko nahi dikhta. Favicon demo ka jawab abhi nahi aaya => favicon NAHI badla.
- 22 Oct 01:10 B6a STEP 4 ✔ (brain portal route pehle se laga, POST /api/billing/portal => 401) · STEP 5 ✔ GREEN (caddy-polar-lockdown apply: checkout/billing 404 dono host, webhook 401 dono host, /health 200, site 200; backup /root/anexomail-backups/caddy-lockdown-20261021-195643). Baqi B6a: step 6 asli Manage billing click (Pro login founder ne diya, pull ke baad).
- 22 Oct 01:10 POLAR WEBHOOK AUTO-DISABLE ROOT CAUSE (founder: "hamesha disabled hota hai"): engine ka POLAR_ACCESS_TOKEN mein webhooks:read scope NAHI (Polar: 403 insufficient_scope; engine log "auto-sync rejected 403") => sirf ek env secret => Polar har endpoint ka alag secret => doosre endpoint ki asli deliveries signature_mismatch 401 => Polar auto-disable. FIX BANA: main.rs POLAR_WEBHOOK_SECRETS (comma/space/newline, dedupe) + /health secrets_complete (<2 => ERROR log) ; polar-secrets-install.sh (secrets hidden prompt, .env 600, control-plane installer se build/proof, rollback) ; polar-secrets-proof.py 9/9 (bug reproduce: 1 secret => doosra endpoint 401). Server par CHALA NAHI => GREEN NAHI. Founder ko Polar dashboard mein endpoint Enable + test event/redeliver karna hai. Option baad mein: naya Polar token webhooks:read(+write) => auto-sync + watchdog.
- 22 Oct 01:25 POLAR WEBHOOK FIX SERVER PAR GREEN: polar-secrets-install.sh chala (secrets_complete=true, webhook_secrets=2, received 0->2, backup /root/anexomail-backups/polar-secrets-20261021-201016); founder ne Polar mein Enable+Redeliver kiya => ab "200 OK" aata hai (founder ne bataya). 
  POLAR DOCS FACTS (founder ne docs di): secrets 8 Sep 2026 00:00 UTC se PEHLE = "Polar HMAC" (key = poori whsec_ string ke UTF-8 bytes); baad ke = Standard Webhooks (base64-decoded key). Hamare dono endpoints (Aug 12, Sep 7) PURANE => Polar HMAC; engine secret_keys() DONO try karta hai (b64-decoded + poori string) => theek, kuch badalna nahi. Endpoint 10 lagataar non-2xx par auto-disable; retries 10 baar exponential; timeout 10 s (2 s se kam rakho — WAL-first 200 pehle se instant); 3xx redirect = failure (URL final https rakho); Polar webhook IPs 3.134.178.243 (naya), 3.134.238.10, 3.129.111.220, 52.15.118.168, 74.220.50.0/24, 74.220.58.0/24 — ufw 443 sab ke liye khula hai, allowlist ki zaroorat nahi. Payload mein checkout client_secret hota hai — chat mein paste karte waqt hata do.
  BAQI: Polar token webhooks:read(+write) => auto-sync + watchdog (optional); B6a step 6 asli Manage billing click.
- 22 Oct 02:00 BRANDLOADER HAR JAGAH (founder hukm "ek bhi kona na bachay, her package, puri website"): src/components/state/BrandLoader.tsx = BrandSpinner (chhota A, button/inline), InlineLoading, SectionLoader, PageLoader — sab ASLI BrandMark A. 24 files mein saare Loader2/spinning RefreshCw => BrandSpinner (mechanical, tsc baseline same 9 pre-existing errors, naya koi nahi); 10 "Loading…" paragraphs => InlineLoading; router.tsx defaultPendingComponent=PageLoader (250 ms baad, min 450 ms); BootSplash ab saare ssr:false routes par (app, auth, auth_.callback, checkout/done, claim, join, onboarding, rsvp, trial-ended, founder/preview). /app ka WorkspaceLoader (panels + asli A) pehle jaisa. Skeleton rows (ListSkeleton) jaan-boojh kar rakhe (shape-preserving placeholders). LANDING/public SSR pages par overlay NAHI (landing no-touch + content pehle se server se aata hai) — founder ne mana kiya to hi badlo. Real Chromium 390/820/1440 overflow nahi. Dobara generic spinner mat daalna; naya loading ho to BrandLoader use karo.
- 22 Oct 02:20 POLAR ENGINE UPGRADE BANA (founder hukm: "yeh technology meri hai, engine update kero"): server/rust/polar-payment/Cargo.toml axum 0.7->0.8 (0.8.9), tower-http 0.5->0.6, edition 2021->2024; main.rs sirf route syntax (:id -> {id}); koi warning nahi; 10 unit tests; polar-cp-proof purane live engine ke muqable 54/0; polar-secrets-proof 9/9. Deploy = polar-control-plane-install.sh dobara chalao (Cargo.toml+main.rs git se leta, backup+rollback). hmac/sha2 0.10, sqlx 0.8, reqwest 0.12 jaan-boojh nahi chhede (crypto deps bina wajah churn nahi).
  NON-ROOT + .env 600: docs/cursor-work/server/polar-nonroot-install.sh (user polar nologin; .env 600 polar; pcp.key 640 root:polar; wal chown polar; pm2 start --user polar; proof: user=polar, wal_writable, secrets_complete, portal 401, signed call, test event, kill switch; fail => root par rollback). Sandbox mein asli user polar se engine chala kar permission model sabit kiya (nobody .env/key nahi padh sakta, kill switch root ki file se chalta). pm2 --user sandbox mein test nahi (pm2 nahi) => server par proof/rollback hi saboot.
  SERVER PAR CHALA NAHI => GREEN NAHI. Tarteeb: 1) control-plane-install (axum 0.8) 2) nonroot-install.
