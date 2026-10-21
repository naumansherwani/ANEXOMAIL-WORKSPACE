# MASTER GAP LEDGER — blueprint + founder-commands + loophole-ledger + TECH-MAP ka EK hi hisaab (20 Oct 2026, 23:59 PKT)

Kyun: founder ne bar bar kaha: "jo ho chuka dobara nahi; jo nahi hua uski tarteeb". Yeh file wahi ek jagah hai. Compact ke baad pehle yeh + `DONE-DO-NOT-REPEAT.md` + `founder/founder-commands.md` + AGENTS.md rules parho.
Zubaan: **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) · **CODE** = repo mein bana + local test, server/live par chalana baqi · **TODO** = bana hi nahi · **CHECK** = shayad server par hai, repo mein nahi — pehle server se dekho (neeche Rule 32) · **FOUNDER** = founder ka faisla/haan/DNS chahiye.
Stale warning: blueprint ke "PHASES 1–62" ka "READY/Supabase run baqi" likha hua PURANA hai (Sep). Un phases ke SQL/routes server par chalte hue dekhe gaye (login, mail, billing, calendar live). Unhein dobara "baqi" mat samjho; sach server-vs-repo audit (A1) se tay hoga.

## A. SAB SE PEHLE (naya, har kaam ki buniyaad) — repo == live
| # | Kaam | Status | Kaise |
|---|---|---|---|
| A1 | **Repo vs server audit (read-only)** — founder ne chalaya 21 Oct 00:27 (`/root/audit-A1.txt`); nateeja neeche "A1 NATEEJA". Web/Rust procs/Brain files/SQL objects/edge config/systemd/cron/pm2 sab audit hue | **GREEN (audit DONE)** — gaps ka kaam A2–A4 mein; sirf A5 khula | `repo-vs-server-audit.sh` + `repo-capture-server.sh` (live-snapshot af24025 repo mein) |
| A2 | Rule 31/32 sandbox + AGENTS.md mein; schema-only SQL + Brain/Rust farq + redacted Caddy/Postfix/Dovecot/OpenDKIM/cron `live-snapshot/` mein | **GREEN (DONE c25da5f + af24025)** | — |

## B. GREEN — live saboot mil chuka (dobara mat chhuo)
| Item | Saboot |
|---|---|
| tokio 1.53.3, axum 0.8.9, wtransport 0.7.2, rustc 1.99.1 + edition 2024 | live 20 Oct 03:28–06:07 |
| L1/L2 mail TLS cert + expiry watch | live (cert renewal 12 Nov se pehle dekhna — open item) |
| E37 (anjaan pata quarantine), E38 (thread count), R1a Rust inbound pipe | live 20 Oct 06:41–07:54 |
| G29 revoked guard, G31 seat/audit/work address (E34), G32 manager rank, G17/L76 team invites | live 06:06–06:16 |
| G30 Gmail/Outlook import (IMAP) worker | code + installer; live saboot ka record: founder-commands (CHECK — "Import mail" screen Basic mein dikhi) |
| E41–E47 + CHECK_E42_E47 (family real buyer, device hash HMAC, passkey/recovery tables, export, purge, notices/appeal, revoke sessions) | founder 20:21 GREEN |
| Rust `device` + `export` modules; purge + notify + device_vault_purge timers; Web pull (IntegrityGate etc.) | founder 20:21 |
| G38 SQL E48/E49/E50 + CHECKs; Rust `attach` (3x401); attach-gc timer; Caddy `/files/*` band (probe 404); attach-check (storage, Postfix 50 MB, spool, timer) | founder 23:50 |
| Basic account Chrome: login, dashboard, inbox khulte hain (Browser 1) | 20 Oct 22:00 |

## C. CODE bana, LIVE par chalana/verify baqi (tarteeb se)
| # | Kaam | Agla qadam |
|---|---|---|
| C1 | G38 Brain attach (bhejna) — installer ka "check FAIL" jhootha nikla, theek kiya | founder: `brain-attach-install.sh` |
| C2 | G38b Rust inbound (`rust-inbound-attach-install.sh`) | founder pull |
| C3 | G38 Web (Compose Attach + thread download/blocked chip) | founder Web pull; phir MERA Chrome test (attach bhejna — mail bhejne ke liye founder ki alag "haan") |
| C4 | clamd 127.0.0.1:3310 (Debian socket-activation) — `clamd-tcp-fix.sh` | founder pull; GREEN jab EICAR FOUND |
| C5 | G34 purane device hash HMAC migrate (`device-hash-migrate.sh`) | founder server par chalaye? (CHECK) |
| C6 | G35 passkey lazmi + 2 passkey + 10 recovery codes (E43 + UI) — 27 Oct deadline | live check (Chrome: banner "required from Oct 27" dikha) |
| C7 | G36 export/delete countdown + email; G37 review queue UI | live dekhna |
| C8 | G39 family lifetime label (Humza account) | founder login chahiye (live check) |
| C9 | D2 authoritative-NS verify, 8-series domains (D3 admin link, D1 zero-gap, catch-all/forwarding/vacation, health guard, DMARC reader, Domain Connect, BIMI) | tarteeb: founder haan 08:17; D2 READY, baqi NEXT |
| C10 | L3–L66 sab UI/copy fixes "READY" (pull.sh se live) | Chrome se ek baar har package par dekhna (G41) |

## D. TODO — bana hi nahi (founder ki tarteeb)
| # | Kaam | Technology |
|---|---|---|
| D1 | **G33 wade ka audit**: `PROMISES.md` (28 line) har wada -> code -> live saboot | docs + Chrome |
| D2 | **G41 live test Basic -> Pro -> Business -> Business Pro, 1440/820/390** (Basic dashboard+inbox dekha; baqi login chahiye) | Chrome |
| D3 | G40 Rust RPC: work.*, crm.*, org.*, integrations.*, settings.* (G18: founder routes 181 Rust-pehle, 19 sirf Bun) | Rust |
| D4 | G42 passkey/recovery login Bun -> Rust (`/rpc/auth.passkey.*`) | Rust |
| D5 | R1 `mail.send` + `org.mailboxes.*` Rust — **GREEN 21 Oct 06:00 (B3: send + undo-send hold + Rust worker + mailboxes; E54; live proof)**; R3 typed contract; R4 direct pool; R5 event-driven WebTransport push | Rust |
| D6 | G16 self-serve billing (cancel/card/VAT via Polar portal, naya Rust endpoint; polar-rust-payment :3400 NO-TOUCH) | Rust + Web |
| D7 | Business Pro baqi (G20: login/entitlement data, bpro.test) ; G21 baqi Brain routers authz audit; G22 org.ts sach-jhooth; G14 `crm-tenant-check.sh` live | SQL/Brain |
| D8 | G26 inbound iMIP REPLY (anexopipe hook; founder haan), G27 recurrence/scheduling link/2-way sync/CalDAV, G24 Personal Premium claims ka asli call/vault test | Rust/Chrome |
| D9 | G2 Admin ke baqi 9 pages + Chat harness; G9 plan-promise audit; G10 passkey flow verify; G6 IMAP phone sync; G7 catch-all etc. verify; G15 CRM SPA links | Web/audit |
| D10 | Walid ka account (basic -> business pro green ke BAAD) ; founder profile (maujooda website code modify) ; **AnexoChat** (chat audit; `anexochat/index.md`) | founder order |
| D11 | Open ops: ufw 3443/udp, Caddy cert renewal (12 Nov), Bun `/api/billing/subscription` bug, E24 email_hash HMAC migrate run, Bun 1.4.0->1.4.3, tokio 1.54 (hafta baad) | server |

## E. FOUNDER chahiye (agent akela nahi)
F1 MTA-STS/TLS-RPT/TLSA DNS records · F2 `milter_default_action` tempfail (haan) · F3 PostgreSQL 17.6->18 (haan + window) · F4 M8 viral line, P2 SSO, M11 vite.config · F5b Priority Support add-on wording · F6 Stalwart/R2 (haan) · G30 OAuth app registration (Phase 2) · Pro/Business/Business Pro/walid ke liye Chrome mein **khud login** (main asli site par password type nahi karta).

## F. Tarteeb (kaam ka silsila, ek ke baad ek — green par agla)
1. C1–C4 pulls (founder) -> mera Chrome attach test -> **G38 GREEN** (Basic ka sab se bada gap).
2. A1 repo-vs-server audit (founder ek read-only command) -> gaps repo mein / repo se server par.
3. D1 G33 + D2 Basic -> Pro -> Business -> Business Pro live test (har package GREEN, phir agla).
4. D3 G40, D4 G42, D5 R1, D6 G16, D7 Business Pro baqi.
5. D10: walid ka account -> founder profile -> AnexoChat.

**PARKED (founder 21 Oct 00:14):** 3D/Three.js -> `PLAN-3D-PARKED.md`. Tarteeb mein nahi.

## A1 NATEEJA (founder ne chalaya, 21 Oct 00:27 PKT; /root/audit-A1.txt) — repo != live
- **Brain:** DIFFERS anexochat.ts, index.ts, routes/crm.ts; SERVER-ONLY lib/*.ts (~65 files, frontend-jaisi lib ki purani copy Brain mein) + routes/index.ts, routes/storage-client.ts, server.ts, start.ts, routeTree.gen.ts; REPO-ONLY accounts/create-accounts.ts, mail/deliver-to-supabase.ts (Brain par nahi — Postfix ab Rust anexopipe).
- **Rust:** main.rs DIFFERS (installers live patch karte hain — mirror lena baqi); anexomail-deliver.rs SERVER-ONLY (repo mein deliver_bin.rs hai — mel dekhna).
- **SQL:** ~230 functions / ~300 tables / ~400 policies live mein, repo ke E-files mein NAHI (chat_*, ai_*, billing_*, movein_*, file_*, security_*, polar_*, safety_*, org_*, perf_*, setting_*, legacy/backup tables). Repo mein sirf E31-E51 + purane `sql/phase*.sql`. -> A2: schema-only dump (koi data nahi) repo mein.
- **Edge:** Caddyfile (147 lines), postfix main.cf/master.cf, dovecot.conf, opendkim.conf repo mein NAHI. -> A3: secret-redacted copy repo mein.
- **systemd:** 6 anexomail timers sab repo mein (OK). Cron: `anexomail-sync-domains.sh`, `anexomail-sync-maps.sh` (har minute, DUPLICATE line crontab + /etc/cron.d mein dono!) repo mein script nahi -> A4.
- **pm2:** env key naam repo se match (value nahi dekhi). `anexomail-leo` ke env key khali (Brain env file se padhta hoga).
- **Khatra jo mila:** `process.env.FOUNDER_PASSWORD` Brain mein use hota hai — dekhna (plain password env mein?). A5.
## G-CAL (21 Oct 00:29): calendar.create 500 — SABAB MILA
- Live check (CHECK_CAL_CREATE) ne dikhaya: `calendar_attendees_response_check` 'needs_action' ko rokta hai (live default 'pending'). Rust 'needs_action' bhejta hai -> attendee insert fail -> event yatim reh jata (2 yatim mile).
- Fix: `E51_calendar_response_fix.sql` (check badla, default needs_action, yatim cancel, selftest rollback, PostgREST reload) — local DB par pehle error reproduce, phir E51 2 baar chala OK. Rust `cal_glue.rs` mein error log + attendee fail par event auto-cancel (cargo check OK; live par Rust rebuild baqi).
- Live GREEN tab: E51 server par -> Chrome mein meeting grid mein + Load tab.
- **A2-A4 script:** `repo-capture-server.sh` (founder server se chalayega, push bhi wahi se): schema-only SQL, Brain/Rust farq, redacted config + cron -> `docs/cursor-work/live-snapshot/`. Secret mila to push nahi. Phir main merge karunga (repo ko live ke barabar).
- **A5 FOUNDER_PASSWORD:** `server/routes/auth.ts:631` — env password match par founder account ka password reset + login (plain `===` compare). Dizayn ka hissa hai par khatarnak: env khali ho to band; founder ki marzi par hata kar passkey/2FA par jana (G35 ke baad).
- Founder 21 Oct 00:35: SQL ab server se seedha Postgres (psql WORKING_URL, sql-run.sh) — pehle se aisa hi hai.
- **G-CAL GREEN (21 Oct 00:50, Chrome basic.test):** E51 ke baad meeting bani, list mein, detail + Load tab chalta. Baqi Basic: Compose attach/undo-send live, inbound download chip, 390/820.
- **G-UNDO (21 Oct 01:00, Chrome live):** Compose khulta, To/Subject/Body bharte, Send -> server hold OK (spinner, window band). GAP mila: toast "cancel from Sent" ka wada jhootha — Sent folder held mail nahi dikhata aur `useCancelScheduled` UI mein kahin nahi. Fix (code, repo): notify.undoable + ComposeStudio "Undo" button (30s) -> `cancelScheduledSend(id)` -> 409 "Already sent". Web pull ke baad live retest baqi. (To field mein subject type hona = test-tool timing, app bug nahi: plain input, koi blur/focus-steal code nahi.)
- Inbox design (founder sawal): ThreadList/MailRail/styles.css mein 20 Oct 10:10 ke baad koi diff nahi — design touch nahi hue.
- **G38b GREEN (21 Oct 01:15, Chrome basic.test):** inbound thread mein hello.txt chip -> click -> `GET /file/attach/get?id=…` 200 (download).
- **G-UNDO GREEN (21 Oct 01:20, Chrome):** Compose -> Send -> toast "Sending… Held for 30s" + Undo button -> `POST /api/mail/schedule/<id>/cancel` 200 -> 30s baad mail inbox mein NAHI aayi (control: bina undo wali mail aayi).
- **UX fix (code):** mail pane ka action row (Done/Archive/Meeting/Snooze/Label) md+ par `overflow-visible` tha: tang pane mein buttons kat-te the, drag/scroll nahi. Ab HScroll (‹ › + mouse drag). Live verify Web pull ke baad.
- **BUG (mila, fix baqi):** purani mail ke preview mein mojibake "5:31â¯AM" (U+202F UTF-8 ko Latin-1 padha) — preview/ingest charset; frontend par safe-clean + ingest source dekhna.
- **BUG (mila):** thread card ka upar ka hissa (sender line) kabhi kabhi andar scroll ho kar kat jata hai (click ke baad) — dekhna.
- **390 (Chrome iframe-viewport, basic.test) GREEN:** inbox (bottom nav, list, tabs), calendar (meeting list), thread (actions, attachment chip) — saaf. 820: calendar OK.
- **820 BUG (mila, fix code):** mail mein 3 tang columns (nav 220 + list 304 + thread ~270): action row (Snooze) kat-ti, thread pane mein horizontal scrollbar. Fix: tablet (<1024) par master-detail — `ListPanel/DetailPanel stackBelow="lg"`, thread header back arrow `lg:hidden`, X `lg:grid`. Laptop 1024+ par teen columns wahi. Live verify Web pull ke baad.
- **Basic sweep (21 Oct 02:00, Chrome basic.test, 21 pages):** sab render, koi "not wired/coming soon"; CRM/Admin/Settings-AI plan-gated (lock text). Account: SMS honest copy LIVE GREEN. Calendar, G38b download, Undo = GREEN.
- **Basic ke baqi (code live par chalna baqi):** Web pull (HScroll + 820 master-detail) -> live retest; G35 passkey banana = sirf founder (device authenticator, 27 Oct deadline); mojibake purani mail preview; thread card top clip.

## 21 Oct 01:45 — batch
- CODE: Settings -> Appearance "Graphics & visual effects" toggle (experience.graphics, html[data-ax-fx]); sidebar nav scrollbar hidden (styles.css). Live retest 390/820/laptop after Web pull.
- CODE: server/brain-crm-install.sh (CRM tenant isolation, live crm.ts purana) — Brain command pending founder run.
- NOTE: G35 deadline real users only; test accounts exempt. cron `.bak` file inert (Debian ignores dotted names).
- TODO: schema-public.sql capture rerun without Ctrl+C.
- 21 Oct 02:00: LIVE GREEN basic.test: Graphics toggle visible in Settings->Appearance; sidebar scrollbar gone; Brain CRM tenant isolation installed (health 200, unauth 401).
- CODE: auth-passkey.ts /passkey/status exempts test accounts (email local part ends "test") — Brain passkey installer to run. Capture script false RED (alphabet constant) filtered.
- NOTE: "graphics" abhi sirf aurora/glow/float par asar; 3D abhi bana hi nahi — toggle tayyar, 3D usay padhega.
- 21 Oct 02:20 BASIC FINAL LIVE (basic.test): 13 routes x 390/820/1200 = 39 loads, 0 empty, 0 error; only overflow = public SiteNav at 1024-1268px (fixed 138de99, hamburger until xl, needs Web pull). Billing -> Pro Upgrade opens Polar checkout (Pro £46/mo, not paid). Graphics toggle + sidebar scrollbar verified live. Brain CRM isolation live.
- BASIC = GREEN except: (a) passkey banner on test accounts until Brain passkey install, (b) SiteNav fix retest after pull. NEXT: PRO.
- 21 Oct 03:00 3D BUILT (code, live test pending Web pull): src/lib/fx.ts (tier off/lite/full, PLAN_ORB colours), src/components/fx/{Fx3D,Stage,MailboxScene,LogoScene,OrbScene,GemScene,TiltCard}.tsx. Wired: landing hero mailbox (desktop+mobile slot), WorkspaceLoader logo, Dashboard Greeting plan-orb (Basic blue/Pro violet/Business gold/Business Pro ruby+platinum rings+halo), empty inbox + empty calendar gem, Plans TiltCard. Lazy, IntersectionObserver, visibility pause, error-guard fallback, Settings toggle + calm + OS reduced-motion = off, lite on <1024px/touch/weak device. Typechecked in isolation (tsc clean).
- brain-passkey-exempt.sh = surgical patch (live auth-passkey.ts differs from repo -> full install STOPs).
- capture PUSHED af24025 (schema-public.sql + snapshots in live-snapshot/).
- 21 Oct 02:58 LIVE: Brain auth-harden installed (health 200; no-token 401, bad-token 401 not 503); Web 6c41307 pulled (src same=479, build OK). FxAmbient = sirf patli edge-light. LOGIN LOOP: fix live par, founder ke sign-out/login par live verify BAQI (recorder tab par laga hai; sessionStorage 'ax.dbg').
- TECH (sach): login/auth abhi Bun Brain :3100 (fallback tech) + Supabase GoTrue getUser. Rule 25 goal = Rust par: agla qadam "Rust JWT local verify (JWKS/secret) — Supabase network call khatam" (founder 'haan' + differential test ke baad).
- 21 Oct 03:10 TECH MIGRATION SNAPSHOT (GHALAT-ho-sakti NAAM-GINTI — asli sach TECH-MAP 0c, Rule 35; Rust ko touch NAHI): Brain Bun = 38 route files, ~504 endpoints (fallback, naya kaam nahi). Rust :3200 = 13 modules (attach, cal, device, dnsauth, export, locale, mig, people, security, team + main/deliver/inbound_attach), ~265 rpc/proc naam. Website = React 19 + TanStack Start + Vite 8 + Tailwind 4 (already latest). Auth (login/session/passkey) abhi Bun + Supabase GoTrue; Rust JWT-local-verify + G42 passkey Rust = agla bara qadam.
- 21 Oct LOGIN-LOOP: 3 parte (Brain auth-harden LIVE, client retry + /auth redirect LIVE 6c41307, app.tsx loader-guard READY). Live verify founder ke login par (recorder). Caddy mein access log nahi — server-side saboot nahi milta.

## 21 Oct 04:00 — Basic card vs asli product (founder ne card paste kiya)
- OK live: 1 domain (Domains '1 of 1'), 3 mailboxes, 5GB x3 (dashboard '5.0 GB x 3'), Undo send 30s, Contacts & calendar, Thread ownership, Cmd+K, 72h support (personal-tiers/plans.ts ek jaisa). Landing '/' saaf (koi 3D nahi, overflow 0).
- **GAP G-ALIAS:** card '5 free aliases' likhta hai par app + SQL (E15: 'alias ginti mein nahi') alias par koi cap lagata hi nahi, UI 'aliases are free' (unlimited). Faisla chahiye: (a) cap 5 enforce (SQL/Rust surgical) ya (b) card ko 'free aliases' likhna.
- **BUG G-DOM:** Domains page '1 of 1 domain' par narangi warning 'allows 1 domains. Remove one or upgrade.' — limit poori nahi hui (== cap), grammar bhi ghalat. Fix: warning sirf used>cap par + singular.

- **21 Oct 04:30 FAISLA (founder: 'jo server/repo par hai wahi reality, packages theek karo'):** G-ALIAS = card ko reality par laaya ('Free aliases — no extra seat'; plans table 'Included'). E52 cap-trigger WAPAS (kabhi server par nahi chala). G-DOM fixed 6deff50. Rule: plan card ka har wada asli product se milna chahiye — jhooti marketing nahi.

- **21 Oct 04:10 CEO FAISLA (plan cards):** Basic = pehle paisa-wali cheezein (1 company domain, 3 mailboxes, 5GB, Undo send, Thread ownership...), "Free aliases" baad mein, chhupa fair-use cap 25 (E52_alias_fair_use). G-ALIAS CODE; SQL server par baqi.

- **21 Oct 04:30 BASIC = GREEN (founder haan; saboot BASIC-AUDIT-DONE.md). NEXT: PRO.**

- B1 (Rust JWT local verify + session refresh): GREEN live 21 Oct.
- B2 (G42 passkey/recovery login Rust): GREEN live 21 Oct. Baqi: Bun fallback replay-hardening + passkey/list + DELETE passkey/:id -> Rust (in progress).

| D5b | R5 event-driven WebTransport push (polling khatam) — **READY 21 Oct (B4), server par chalna baqi; sandbox QUIC proof SAB PASS; family accounts included** | Rust |

- **21 Oct 06:45 A1/A2 stale-TODO theek kiya:** A1 audit pehle hi chal chuka tha (00:27) — table mein "TODO" reh gaya tha. Ab GREEN. Khula sirf **A5** (`FOUNDER_PASSWORD` env compare, auth.ts) — G35 passkey/2FA ke baad hatana; aur repo `main.rs` ko live ke barabar mirror karna (installers live patch karte hain) B-series ke saath.
