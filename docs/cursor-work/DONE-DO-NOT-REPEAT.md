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
