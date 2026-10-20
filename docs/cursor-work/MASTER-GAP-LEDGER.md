# MASTER GAP LEDGER — blueprint + founder-commands + loophole-ledger + TECH-MAP ka EK hi hisaab (20 Oct 2026, 23:59 PKT)

Kyun: founder ne bar bar kaha: "jo ho chuka dobara nahi; jo nahi hua uski tarteeb". Yeh file wahi ek jagah hai. Compact ke baad pehle yeh + `DONE-DO-NOT-REPEAT.md` + `founder/founder-commands.md` + AGENTS.md rules parho.
Zubaan: **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) · **CODE** = repo mein bana + local test, server/live par chalana baqi · **TODO** = bana hi nahi · **CHECK** = shayad server par hai, repo mein nahi — pehle server se dekho (neeche Rule 32) · **FOUNDER** = founder ka faisla/haan/DNS chahiye.
Stale warning: blueprint ke "PHASES 1–62" ka "READY/Supabase run baqi" likha hua PURANA hai (Sep). Un phases ke SQL/routes server par chalte hue dekhe gaye (login, mail, billing, calendar live). Unhein dobara "baqi" mat samjho; sach server-vs-repo audit (A1) se tay hoga.

## A. SAB SE PEHLE (naya, har kaam ki buniyaad) — repo == live
| # | Kaam | Status | Kaise |
|---|---|---|---|
| A1 | **Repo vs server audit (read-only)**: Web (pull.sh sha) ✔ pehle se; Rust procs (`rust-procs-check.sh`, G23: live 182 procs) ✔ pehle se; **Brain files** (live `/opt/anexomail/src` vs `server/`) ✘; **SQL objects** (live functions/tables/policies vs E-files + phase-files) ✘; Caddyfile/Postfix/Dovecot/OpenDKIM/systemd/cron/pm2 env (naam, secrets nahi) ✘ | TODO (pehla) | ek `repo-vs-server-audit.sh` (sirf padhta, secrets chhapta nahi) -> output -> jo server par hai repo mein nahi wo repo mein lana, jo repo mein hai server par nahi wo gap list |
| A2 | Rule 31/32 sandbox + AGENTS.md mein | DONE (c25da5f + is commit) | — |

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
| D5 | R1 `mail.send` + `org.mailboxes.*` Rust (Bun fallback; G5 fallback identity); R3 typed contract; R4 direct pool; R5 event-driven WebTransport push | Rust |
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
