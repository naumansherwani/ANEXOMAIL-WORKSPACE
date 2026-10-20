# TECH-MAP — kaun si technology, kis kaam ke liye, aur SIRF usi kaam ke liye

**Founder ka hukm (17 Oct 2026, 06:04 PKT) = AGENTS.md Rule 20.** Backend par latest technology, koi compromise nahi; mail bhi Rust (ya jo sab se latest ho) par; website sirf latest technology par; aur yahan saaf likha ho har technology ka kaam. Yeh file **ek hi sach** hai. Map mein na ho to code mein naya tech nahi aata.

**Padhne ka tareeqa.** Status (Rule 5 ke mutabiq, sach):
- **LIVE** = server par chalta dekha gaya (founder ka output). Bina output ke LIVE nahi likhte.
- **READY** = code repo mein hai, server par live-verify baqi.
- **PLANNED** = faisla/plan hai, code nahi. Blueprint ID saath mein.
- **REJECTED** = soch kar mana kiya, wajah saath.

"Latest" ka matlab verify kiya hua: neeche har version ke saath tareekh aur source hai (17 Oct 2026 ko dekha). Jahan verify nahi hua wahan "verify baqi" likha hai — andaza nahi.

---

## 0. LAW — kaun si technology KAHAN aati hai (founder ka hukm 19 Oct 2026, 06:34 PKT — Constitution; Rule 25)

> Founder: "yeh technology jahan pe ani hai yeh **rule hai, law hai, constitution hai** aur **goal** hai ke **ahista ahista poori website, SQL likhna, advance level pe Bun se shift** karna hai is technology pe ya **is se bhi advance technology** pe."
> Is jagah se bahar koi technology kisi kaam par nahi lagti. Naya tech lagane se pehle neeche ki "Jagah" dekho; map mein na ho to pehle yahan likho (section 9).

| Jagah | Technology | Kaam (sirf yehi) |
|---|---|---|
| **Edge (browser ↔ server)** | Caddy (HTTPS + HTTP/3) | TLS, reverse proxy, HTTP/3. Business logic nahi. **Kabhi nahi tootna** (read-only check -> backup -> `caddy validate` -> reload). |
| | WebTransport over QUIC (Rust, UDP 3443) | Server se browser ko live push: naya mail, chat, call signaling. |
| **Backend (naya sab)** | Rust :3200 (Tokio, axum) | `/rpc/*`, file engine, calendar, people, team, Import mail, aane wale attachments. |
| | rustls | Import mail ka secure connection (Gmail/Outlook IMAP). |
| | reqwest + rustls | Rust se bahar ke HTTP (Supabase wagera). |
| | Bun :3100–3300 | **Sirf fallback** jab Rust 404/501/502/503 de. Naya kaam yahan nahi. |
| **Database** | PostgreSQL (Supabase #4) | Sach ka ek source: mail metadata, migration walled garden, quota, chain. |
| **Files / attachments** | Hetzner Storage Box (`/mnt/anexomail-box/attachments`) | Sirf file ke bytes. Database mein sirf metadata. (Storage Box network mount hai, local NVMe nahi.) |
| **Mail — app ka har hissa (founder "haan" 20 Oct 06:41)** | **Rust :3200 — tRPC-style `/rpc`, async Tokio, WebTransport/QUIC push** | `mail.send` (R1), `org.mailboxes.*` (R1), **aane wali mail ka pipe** (Postfix `anexopipe` -> abhi Bun `deliver-to-supabase.ts`; Rust `anexomail-deliver` par jana hai, MIME = `mig_mime.rs`), pane wale ki pehchan (E37 ka Rust twin), attachments (E38), inbox live push (R5: event-driven, 700 ms poll nahi). Bun sirf fallback jab tak Rust live verify na ho. |
| | Postfix, Dovecot, OpenDKIM | Sirf **transport** (SMTP le jana/lana, DKIM sign, IMAP). App logic yahan nahi. Badlav founder "haan" + backup + `postfix check` + reload. |
| | Stalwart, JMAP | PLANNED: sirf founder ke "haan" + parallel staging ke baad. |
| **Website (frontend)** — founder list 20 Oct 06:36 | React 19.2 | Saare pages/components. |
| | TanStack Start v1 + Router 1.17.0 (+ Query) | Routes, SSR wiring, data cache. |
| | Vite 8.2 | Build. |
| | Tailwind v4.2 | Styling (`src/styles.css`). |
| | Radix + shadcn/ui | UI blocks (dialog, sheet, menu...). |
| | Framer Motion | UI motion (page/panel transitions, micro-interactions) — app ke andar bhi. |
| | GSAP | Scroll/timeline cinematic sequences (landing, onboarding, feature tours). |
| | Three.js (aur 3D/WebGL cinematic graphics) | 3D cinematic scenes — **founder 20 Oct: server load uthayega, jahan behtar lage use karo** (landing, onboarding, empty states, dashboard hero). Mobile/tablet par halka version + `prefers-reduced-motion` par band (Rule 19). |
| | Bun SSR (Nitro) | **Sirf website ka server-side render**, API nahi. |
| **Payments** | Polar Rust webhook :3400 | **NO-TOUCH.** |

### 0b. Har technology ki PULL command (founder 20 Oct 06:36: "kaun si technology ki pull hai") — har jawab mein alag block, label ke saath
| Technology | Code kahan likha jata hai (repo) | Server par kaise aata hai (sirf yehi raasta) |
|---|---|---|
| **PostgreSQL (SQL)** | `docs/cursor-work/sql/E<n>_*.sql` (fail ho to wohi file theek) | **Founder hukm 20 Oct 21:28: SQL ab SERVER se** — `sql-run.sh` (bina naam = E37..E48 + CHECK; sha256 ledger `/var/lib/anexomail/sql-applied.tsv`, FORCE=1 dobara). Haath se: `. /etc/anexomail/sync.env && psql "$WORKING_URL" -v ON_ERROR_STOP=1 -f <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/sql/E<n>.sql)` — ya founder Supabase SQL Editor mein paste (isliye har E-file editor-safe: koi `\` psql command nahi, koi temp table statements ke beech nahi). |
| **Rust :3200** | `server/rust/<module>_core.rs` + `_glue.rs`; upgrades `docs/cursor-work/server/*-upgrade.sh` | `MODULES=<m> bash <(… rust-engine-install.sh)` / upgrade script — backup, build, restart, health, restore-on-fail. |
| **Website (React/TanStack/Vite/Tailwind)** | `src/**` | `bash <(… pull.sh)` — sha-guard, build, `pm2 restart anexomail-web --update-env && pm2 save`. |
| **Bun Brain :3100** | `server/routes/*.ts` (sirf fallback; naya kaam nahi) | Alag Brain block (`anexomail-leo` restart) — sirf jab zaroori. |
| **Bun Brain — apwad (founder ne G35 maanzoor kiya, 20 Oct)** | `server/routes/auth-passkey.ts` (WebAuthn register/verify/login, recovery-code redeem, status) | `bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/brain-passkey-install.sh)` — sha-guard + bun build pre-flight + restart `anexomail-leo` + restore-on-fail. **G42 = yeh Rust (p256 + ciborium + sha2, `/rpc/auth.passkey.*`) mein jayega**; tab tak yeh apwad. |
| **Caddy** | koi code nahi | Read-only check -> backup -> `caddy validate` -> reload. |
| **Server ops (cron, rustup, system)** | `docs/cursor-work/server/*.sh` | Seedha script (backup + check + restore). |
| **Mail (Postfix/Dovecot/OpenDKIM)** | `server/mail/*` | Founder "haan" + script (backup + `postfix check` + reload). |

### 0c. Aaj ka kaam kis technology mein gaya (log — har kaam ke saath update)
| Kaam | Technology (jagah) | Status |
|---|---|---|
| tokio 1.53.3, axum 0.8.9, wtransport 0.7.2 (+quinn 0.11/rustls 0.23), rustc 1.99.1 + edition 2024 | Rust :3200 | DONE live 20 Oct |
| WebTransport error frame (N7) | Rust :3200 (WebTransport) | DONE live 20 Oct |
| Language bundle/pref `/rpc/locale.*` (N3) | Rust :3200 (Bun `/api/locale/*` sirf fallback) | DONE live 20 Oct |
| Anjaan pate ki mail kisi aur org mein na jaye (E37) | PostgreSQL (`mail_ingest` gate + `mail_quarantine`) — DB ki aakhri deewar; Rust inbound pipe mein bhi wohi check aayega (R1a) | DONE live 20 Oct 06:41 |
| Device record (privacy page ka 5-signal wada) har plan ke liye — `chat.device.*` chat gate se pehle | Rust :3200 (`device_core.rs` + `device_glue.rs`) | READY — `MODULES=device rust-engine-install.sh` |
| Import mail customer ka darwaza `/app/import` + Mail rail + Inbox card; apna login pata nishana | Website (React/TanStack) | READY — `pull.sh` |
| Mail kholna (thread detail) Bun -> Rust `mail.thread` (Bun har thread par khaali `messages` deta tha) + band karne ka X / Esc | Website (React) -> Rust :3200 | READY — `pull.sh` |
| Thread ki mail ginti hamesha sach (trigger) | PostgreSQL (E38) | DONE live 20 Oct 07:54 (62 threads theek) |
| Mail padhne ka tareeqa: sirf mail, Reply/Reply all/Forward par composer; HTML mail sandboxed iframe (koi script nahi, tracking images band) | Website (React) | READY — `pull.sh` |
| **D2** Authoritative-NS live check (`mail.domains.verify` seedha domain ke nameservers se, RD=0, EDNS0 + TCP; public DoH sirf 'phail raha hai' + fallback) | Rust :3200 (`dnsauth_core.rs` std DNS wire + `dnsauth_glue.rs` Tokio UDP/TCP) + React (3s poll) | READY — `MODULES=dnsauth` + `pull.sh` |
| Security page sach: sessions = `auth.sessions` (asli kill), devices = `device_vault`, login replay = `auth.audit_log_entries`, encryption = live TLS handshake (443/993/587/25), ledger sha256 zanjeer; fake "rotate" hataya | SQL E39 + Rust :3200 (`security_core.rs` std + `security_glue.rs` Tokio/rustls) + React | READY — E39 -> `MODULES=security` -> `pull.sh` |
| D3 admin link, D1 zero-gap switch, catch-all/forwarding/vacation, health guard, DMARC reader, Domain Connect, BIMI (founder HAAN 08:17) | Rust + PostgreSQL + React (+ WebTransport) | NEXT, tarteeb se |
| Aane wali mail ka pipe Rust (R1a) | Rust + Postfix argv | DONE live 20 Oct 07:00 |
| `mail.send` + `org.mailboxes.*` Rust (R1), live push event-driven (R5) | Rust :3200 / Tokio / WebTransport | NEXT (tarteeb) |
| Cron `%` fix + root mail ka raasta padhna | Server ops (bash) | DONE (0 kharab lines mili) |
| Attachments BHEJNA (G38): upload/storage/dedup(org)/scan/download | Rust :3200 (`attach_core.rs`+`attach_glue.rs`); bytes Storage Box; metadata PostgreSQL E48; MIME jodna + SMTP bhejna Bun (`mail/attachments.ts`, mojooda sender, Rust `mail.send` aane tak) | CODE DONE — `MODULES=attach` + `brain-attach-install.sh` |
| Aane wali mail ke attachments (G38b): spool + scan + Storage Box + org-dedup | Rust (`anexomail-deliver --spool-run`, `inbound_attach.rs`) · metadata PostgreSQL E50 · systemd timer | CODE DONE — `rust-inbound-attach-install.sh` |
| Attachments (E38) | Bytes: Storage Box · dedup/patch: Rust · metadata: PostgreSQL | PLANNED |
| Import mail customer tak, Terms page, PWA offline | Website (React/TanStack) + PWA service worker | PLANNED (Basic list) |

**Aaj ke kaam kahan lagenge:** Attachments = bytes Storage Box par, SHA-256 dedup Rust se **sirf organisation ke andar**, DB mein sirf metadata + phase48 quota, live inbound ka chhota patch Rust mein · Chat audit + iMIP REPLY = Rust (iMIP ka SQL PostgreSQL) · Bun routes (Business/Business Pro) = Rust par; jab har Rust proc live verify ho tab Bun fallback band · Caddy = koi code nahi, sirf read-only HTTP/3 check script · Pull command har technology ki alag.

**GOAL (founder):** ahista ahista poori website + SQL likhna Bun se hata kar is table ki technology (ya is se bhi advance) par — har qadam differential test + live verify ke baad (Rule 5/22), website kabhi nahi tootti.

### 0a. Version upgrades — PRIORITY QUEUE (founder 19 Oct 06:34: "is ko que main dalo jaldi se aur yeh priority pe")
Server par asli vs latest (TECH-MAP section 3/10, 17 Oct; **har upgrade se pehle official source se dobara verify**, Rule 20). Ek ek, scratch copy par `cargo check` + unit tests, phir `rust-safe-deploy.sh` (restore-on-fail), phir live saboot:
**Verify 20 Oct 2026 03:20 PKT (crates.io API, official):** tokio **1.54.0** (19 Oct 2026, MSRV 1.85) / 1.53.3 (13 Oct) · axum **0.8.9** (14 Apr 2026) · wtransport **0.7.2** (11 Aug 2026) · quinn **0.11.12** (14 Sep 2026) · rustls **0.23.46** (14 Oct 2026).
1. **tokio** 1.53.1 -> **1.53.3** pehle (patch, kam khatra; script `rust-crate-upgrade.sh`), phir **1.54.0** jab ek hafta purana ho jaye (abhi sirf 1 din purana — naye release ki regressions se bachne ke liye).
2. **axum** 0.7.9 -> 0.8.x (path syntax `/:proc` -> `/{proc}`; saare routes ka test). **DONE live 20 Oct 03:59 (0.8.9).** `axum-upgrade.sh` (sandbox: 0.8.9 build OK, differential 26/26 same; `Option<Json>` ka 0.7 bartao `rpc_json_body` se bachaya).
3. **wtransport** 0.1.14 -> 0.7.x (saath mein quinn 0.10 -> 0.11, rustls 0.21 -> 0.23 — WebTransport live push par asar; sab se bada khatra, parallel staging). **DONE live 20 Oct 04:37 (0.7.2; N7 fix 05:03).** `wtransport-upgrade.sh` (sandbox: 0.7.2 build OK, Chromium 141 + native client handshake pehle/baad same, HTTP 26/26 same).
4. **rustc** 1.97.1 -> latest + edition 2024 (`opt-level = "z"` ka faisla alag). **DONE live 20 Oct 06:07: rustc 1.99.1 (project-pinned `rust-toolchain.toml`) + edition 2024.**
5. **Bun** 1.4.0 -> latest (sirf SSR host); Nitro beta ki nigrani.
**Qaida:** upgrade se live kuch tootna nahi chahiye — har ek ke baad `/rpc/health` 200, WebTransport sun raha, `mig-live-test.sh` GREEN.

---

## 1. Usool (har naya faisla in par parka jata hai)

1. **Ek kaam = ek technology.** Do cheezein ek kaam na karein (Rule 6: no mix, no duplicate).
2. **Naya kaam Rust (Tokio async) par.** Bun sirf emergency fallback. Node 22 normal kaam mein nahi.
3. **Realtime push = WebTransport/QUIC.** Chat/mail/call signaling ke liye. WebSocket nahi (Constitution). Jo browser WebTransport na de uske liye honest HTTP poll — "live" ka jhootha dawa kabhi nahi.
4. **Frontend mein pehle browser ki apni (native) taqat**, phir JS library: View Transitions, scroll-driven animation, popover/anchor, `dvh`, safe-area. Library tab jab native kaafi na ho. (Har native feature ka browser support use se pehle dekho.)
5. **Mail ka production raasta tab tak nahi badalta jab tak naya raasta parallel staging mein poora saabit na ho aur founder "haan" na kahe.** Mail send/receive GREEN hai (27 Sep) — use tod'na nahi.
6. **Server par kuch bhi Rule 15 se:** repo = copy, sach = server ka output.

---

## 2. Edge + transport (browser ↔ server)

| Technology | Sirf is kaam ke liye | Is kaam ke liye NAHI | Status | Verify (17 Oct 2026) |
|---|---|---|---|---|
| **Caddy** | TLS (Let's Encrypt auto), reverse proxy, HTTP/3 | Business logic, auth | LIVE (Constitution) | Latest 2.11.1 (25 Feb 2026): ECH key rotation auto, security fixes — **server par 2.11.4 chal raha (facts 17 Oct) — latest se aage** ([linuxiac](https://linuxiac.com/caddy-2-11-1-web-server-released-with-automatic-ech-key-rotation/)) |
| **HTTP/3 (QUIC)** via Caddy | Web page + `/rpc` + file chunk (`/file/*`) ka tez raasta, phone ke network badalne par connection nahi tootta | Server→browser push (woh WebTransport) | LIVE (Caddy HTTP/3) | — |
| **WebTransport over QUIC** (Rust, UDP 3443) | Server→browser **live push**: naya mail ka stamp, chat, call signaling | Bulk file upload (woh HTTP/3 chunk), page load | **LIVE (sun raha)** — facts 17 Oct: `anexomail-rust` UDP **3443** par bind, `/rpc/health` `"webtransport":"live"`. **Gap:** health ka `wt_port` khali aata hai (3443 batana chahiye); andar abhi 700 ms poll (R5) | **Browser support: Safari 26.4 (Mar 2026) ne bhi de diya → ab Baseline; iPhone par bhi chalega** ([webrtc.ventures](https://webrtc.ventures/2026/04/webtransport-is-now-baseline-what-it-means-for-real-time-media/)). Purane iOS ke liye HTTP poll fallback rehta hai. |
| **Encrypted ClientHello (ECH)** | Privacy: connection mein domain naam chhupana | — | PLANNED (R6, evaluate) | Caddy 2.11 mein hai; fayda/risk server par dekhna baqi |

## 3. Backend (Rust PRIMARY)

| Technology | Sirf is kaam ke liye | NAHI | Status | Verify |
|---|---|---|---|---|
| **Rust** | Poora backend: RPC, realtime, file engine, calls, mail ka naya hissa | Frontend, Bun-style scripts | LIVE (`anexomail-rust` :3200) — **server par rustc 1.97.1** (facts 17 Oct), 2 minor peeche | Latest **1.99.1 (15 Oct 2026)**, **edition 2024** ([blog.rust-lang.org](https://blog.rust-lang.org/releases)). Hamara `Cargo.toml` abhi **edition 2021** → **R0** |
| **Tokio** (async runtime) | Har I/O, har connection ek task, timers, `spawn` | CPU-bhari kaam seedha async mein (woh `spawn_blocking`) | LIVE — Cargo.lock: **1.53.1** | Latest **1.53.3 (13 Oct 2026)**, MSRV 1.71 ([docs.rs](https://docs.rs/crate/tokio/latest)). `tokio = "1"` khud naya uthata hai |
| **axum** | `/rpc/:proc`, `/file/*`, health, metrics ka HTTP routing | Realtime push | LIVE — Cargo.lock: **0.7.9** | Latest **0.8.9 (10 Apr 2026)** ([releasealert](https://releasealert.dev/github/tokio-rs/axum)). 0.8 mein path syntax `/:proc` → `/{proc}` badalta hai → **R0** (build server par) |
| **wtransport** (WebTransport server, Quinn par) | Rust ka WebTransport endpoint (UDP 3443) | HTTP routing | **LIVE** — Cargo.lock: **0.1.14** (bahut purana; saath mein purana quinn 0.10.2 + rustls 0.21 bhi isi ki wajah se) | Latest **0.7.2 (11 Aug 2026)**, Quinn ^0.11.6; README khud kehta hai "poori tarah production-ready nahi, spec draft" ([docs.rs](https://docs.rs/crate/wtransport/latest)). Hamara `Cargo.toml` **0.1** (bahut purana) → **R0** |
| **Quinn** (QUIC) | wtransport ke andar; hum seedha nahi chalate | — | LIVE (andar se) | Latest **0.11.12 (14 Sep 2026)**, rustls 0.23 ([docs.rs](https://docs.rs/crate/quinn/latest)) |
| **"tRPC-style" RPC** | Frontend↔Rust ka wire: `POST /rpc/<proc>` → `{result:{data}}` / `{error:{code,message}}`; frontend `rpc<T>()` | — | LIVE | **Sach:** yeh tRPC library nahi (woh sirf TypeScript server ke liye hai); yeh tRPC-jaisa wire hai. Types abhi haath se likhe (`src/lib/*.ts`) — drift ka khatra → **R3** (Rust se TS types generate). `rspc` 0.4.1 (Jul 2025) abhi pre-1.0 (specta RC par) → **REJECTED abhi** ([docs.rs](https://docs.rs/rspc)) |
| **reqwest + rustls** | Bahar ke HTTP (Supabase PostgREST, DNS/RDAP) | — | LIVE | OpenSSL nahi, rustls |
| **tracing** + `/metrics` (:3600) | Logs aur metrics | — | LIVE (Observability port) | — |
| **SFU / media engine** (:3500/:3501) | Group call media | Mail | READY | — |
| **Polar webhook (Rust, :3400)** | Payments | Kuch aur | LIVE, **NO-TOUCH** | — |
| **Bun fallback** (:3100–3300) | Sirf jab Rust 404/501/502/503 de | Naya feature | LIVE (fallback) — **server par Bun 1.4.0** (website SSR bhi isi par) | Latest Bun 1.4.3 (9 Oct 2026) ([endoflife.date](https://endoflife.date/api/v1/products/bun/)) |

## 4. Data

| Technology | Sirf is kaam ke liye | NAHI | Status | Verify |
|---|---|---|---|---|
| **PostgreSQL** (Supabase #4) | Sach ka ek source, RLS | Cache/queue | LIVE | **PostgreSQL 18 (25 Sep 2025)**: async I/O (3x tak), `uuidv7()`, OAuth ([postgresql.org](https://postgresql.org/about/news/postgresql-18-released-3142/)). **Server par asli: PostgreSQL 17.6** (facts 17 Oct) — 18 se ek major peeche; upgrade = `pg_upgrade` + staging, founder 'haan' ke baad (D1) |
| **PostgREST (HTTP) se access** | Abhi Rust DB tak REST se jata hai (`sb_select`) | Garam raaste | LIVE | **Sach:** har query ek extra HTTP hop. Garam raaston ke liye seedha pool (sqlx/tokio-postgres) → **R4** |
| **LISTEN/NOTIFY → broadcast hub** | Naya mail/chat event ek baar sun kar sab connected users ko bhejna | — | **PLANNED (R5)** | **Sach:** abhi WebTransport "mail live" har connected session ke liye **har 700 ms DB poll** karta hai (`wt_session`, `mail_inbox_stamp`) — chhote users par theek, bade scale par DB par bojh. Event-driven fan-out lagna hai |
| **Storage Box** (wire 16) | File/attachment bytes | Metadata | LIVE (file engine) | — |

## 5. Mail

| Technology | Sirf is kaam ke liye | NAHI | Status | Verify |
|---|---|---|---|---|
| **Postfix** | SMTP aana/jaana | App logic | LIVE (GREEN 27 Sep) — **3.10.6**, ports 25/465/587 sun rahe | C mein; replace sirf R2 ke baad aur founder "haan" par |
| **Dovecot** | IMAP (mailbox, phone/Outlook clients) | — | **LIVE — Dovecot 2.4.2** (facts 17 Oct): `protocols = imap lmtp`, `ssl = required`, auth `plain login`, passdb `pam` + `passwd-file`, userdb `passwd` + `passwd-file`, mail_home `/var/mail/vhosts/%{user\|domain}/%{user\|username}` | **Gap:** Postfix mail Dovecot ko nahi, `anexopipe` ko deta hai (neeche §10) |
| **OpenDKIM** | Outgoing mail par DKIM signature | — | LIVE — 2.11.0, milter `127.0.0.1:8891` | Expiry watch (8o) key == DNS check karta hai |
| **Rust mail-send path** (`mail.send`, `org.mailboxes.*`) | Compose se Postfix tak ka raasta | — | **TODO (R1)** — abhi Bun ke zariye (Rule "Rust-first" ke khilaf) | + attachments (8p) isi mein |
| **Stalwart Mail Server** (Rust: SMTP + IMAP + POP3 + **JMAP** + CalDAV/CardDAV, DANE, MTA-STS, TLS-RPT; AGPL-3.0) | **Mail ka agla server** agar parallel staging mein Postfix+Dovecot se behtar saabit ho | Seedha production replace | **PLANNED (R2: staging only)** | Latest **v0.16.26 (11 Oct 2026)**, abhi **1.0 se pehle** (upgrade manual, schema final nahi) ([upgrade docs](https://stalw.art/docs/install/upgrade/), [SSD Nodes](https://www.ssdnodes.com/learn/lang/es/stalwart-mail-server-on-a-vps)). **Faisla:** staging par chalao, 1.0 ya migration proof ke baad founder se poochho. AGPL ka matlab: bina badle chalana theek, badle to source dena |
| **JMAP** (RFC 8620/8621) | Naye native/phone client ke liye HTTP+JSON mail sync | Web app ka RPC (woh `/rpc` hi rahega) | PLANNED (R2 ke saath) | Stalwart deta hai |
| **MTA-STS / TLS-RPT / DANE / DMARC reports** | Mail ki security + deliverability (dusre server hamari mail ko TLS par majboor karein, reports aayein) | — | **PLANNED (8q)** | **Server par abhi (facts 17 Oct): `_mta-sts` aur `_smtp._tls` TXT KHALI, TLSA 25 KHALI**; DMARC maujood `p=reject; adkim=s; aspf=s; rua=dmarc@` |
| **expiry-watch** (Python stdlib + openssl, systemd timer) | Ops ki nigrani: TLS, domain, DKIM, DNS expire na hon | App logic | READY (8o) | — |

## 6. Frontend (website — sirf latest)

| Technology | Sirf is kaam ke liye | NAHI | Status | Verify |
|---|---|---|---|---|
| **React 19.2** | UI | — | LIVE | `package.json ^19.2.0` |
| **TanStack Start / Router** | SSR + file routes + type-safe links | Data fetching (woh Query) | LIVE | start 1.168.x, router 1.170.x (repo) |
| **TanStack Query 5** | Server data cache, refetch | Local UI state | LIVE | repo ^5.101 |
| **Vite 8.2 (Rolldown, Rust bundler)** | Build | — | LIVE | Vite 8 stable **12 Mar 2026**, 10–30x tez build ([vite.dev](https://vite.dev/blog/announcing-vite8.html)) |
| **Tailwind 4.2** | Styling (`src/styles.css`) | Inline hacks | LIVE | 4.2.0 (18 Feb 2026) ([InfoQ](https://infoq.com/news/2026/04/tailwind-css-4-2-webpack)) |
| **Radix + shadcn** | Accessible building blocks | — | LIVE | — |
| **Framer Motion / GSAP / Three.js** | Cinematic motion — landing, onboarding, transitions | **Inbox ke andar bhari 3D** (rafta pehle) | LIVE | repo: framer ^13, gsap ^3.15, three ^0.185 |
| **Bun SSR + Nitro** | Server-side render | API/backend | LIVE | **Flag:** `nitro 3.0.260603-beta` — beta SSR production mein; nigrani rakho, stable aate hi uthao |
| **React Compiler 1.0** | Auto-memoize: tez UI bina haath ke `useMemo` | — | **PLANNED (M11)** | **Stable 7 Oct 2025**, Meta par 12% tak load, 2.5x tak interactions ([react.dev](https://de.react.dev/blog/2025/10/07/react-compiler-1)). **Rukawat:** Vite config mein Babel plugin chahiye aur `vite.config.ts` **no-touch** hai → founder ki izazat chahiye |
| **PWA / service worker** (vite-plugin-pwa) | Install, offline reading | — | **PARTIAL (sach, 19 Oct live check):** manifest LIVE (200) · **service worker NAHI** — `src/lib/pwa.ts` `/sw.js` register karta hai par `public/sw.js` maujood nahi (live `/sw.js` = 404, har page par console error) => offline mode kaam nahi karta | Web Push (iOS installed PWA) → M9; sw.js banana ya register band karna: queue ke baad |
| **Passkeys (WebAuthn)** | Password-free login | — | PLANNED (P3) | Auth abhi GoTrue; fit dekhna baqi |

## 7. AI

LEO / AI sab se aakhir (blueprint #41). Workspace plans (Basic–Business Pro) mein **zero AI** (PACKAGE-FEATURE-FORMULA Rule 4). Technology tab chunenge jab #41 aaye.

---

## 8. "Dawa vs haqeeqat" — jo gap maujood hai (sach, ek jagah)

| # | Dawa | Haqeeqat (17 Oct 2026) | Item |
|---|---|---|---|
| 1 | "tRPC" | tRPC-jaisa wire; types haath ke | R3 |
| 2 | "Latest Rust" | edition 2021, axum 0.7, wtransport 0.1, `opt-level = "z"` (size, speed nahi) | R0 |
| 3 | "WebTransport live" | 700 ms DB poll har session ke liye; event-driven nahi | R5 |
| 4 | "Backend hamesha Rust" | `mail.send`, `org.mailboxes.*` Bun par jate hain | R1 |
| 5 | "Poora Rust engine" | ek 5,789-line `main.rs` — compile/review/test mushkil | R0 (modules mein torna) |
| 6 | "DB seedha" | PostgREST HTTP hop | R4 |
| 7 | Attachments | bheji mail mein attachment ka raasta hi nahi | 8p |
| 8 | SSR | Nitro beta | nigrani |

## 9. Naya tech lagane ka tareeqa

1. Is file mein pehle likho: kaam, NAHI-kaam, status, verify (tareekh + source).
2. Rust ho to server par **scratch copy** mein `cargo check` (production ko haath nahi), errors paste, theek, phir `rust-safe-deploy.sh` (build fail → purani src wapas; health 200 na ho → purani binary wapas). `polar-rust-payment` ko haath nahi.
3. Mail ka koi bhi hissa: parallel staging, founder "haan", phir cutover; rollback tayyar.
4. Blueprint mein item (R-series / P-series) — Rule 14.

---

## 10. Server ke asli facts (17 Oct 2026, founder ka `facts-tech-map.sh` output — yahi LIVE ka saboot hai)

| Cheez | Server par asli | Latest (verify 17 Oct) | Farq / kaam |
|---|---|---|---|
| Caddy | **2.11.4** | 2.11.x | theek |
| Bun | **1.4.0** | 1.4.3 | chhota upgrade (`bun upgrade`, build + restart) — D2 |
| Node | **v22.23.2 installed** | — | Website/backend Node par NAHI chalte. Node sirf `n8n` jaisi alag app ke liye ho sakta hai — facts v2 har pm2 process ka interpreter chhapta hai (saboot) |
| Rust toolchain | **rustc/cargo 1.97.1** | 1.99.1 | `rustup update stable` — R0 se pehle |
| Rust engine | edition **2021**, `opt-level="z"`, `main.rs` **5,789** lines | edition 2024 | R0 |
| axum | **0.7.9** | 0.8.9 | R0 (path syntax badalta hai) |
| tokio | **1.53.1** | 1.53.3 | `cargo update -p tokio` |
| wtransport | **0.1.14** (+ quinn **0.10.2** aur **0.11.11**, rustls **0.21.12** aur **0.23.43** — do-do copy) | 0.7.2 (quinn 0.11.12) | R0: ek hi naya quinn/rustls, bundle chhota |
| hyper / reqwest | 1.11.0 / 0.12.28 | — | theek |
| PostgreSQL | **17.6** | 18 | D1 (staging + founder haan) |
| Postfix | **3.10.6** | 3.10.x | theek |
| Dovecot | **2.4.2** | 2.4.x | theek |
| OpenDKIM | **2.11.0** | 2.11 | theek |
| Rust health | `status up`, `transport ["rpc","http3"]`, `webtransport live`, `wt_port ""`, fallback `anexochat-bun :3300` | — | `wt_port` khali = chhota gap (R5 ke saath 3443 batayein) |
| WebTransport | UDP **3443** par `anexomail-rust` bind | — | LIVE (sun raha) |
| pm2 | n8n, anexomail-rust (restarts 48), anexochat, anexvox-ai-swarm-s2, polar-rust-payment, anexomail-web (restarts 95), anexomail-leo | — | Rust ke 48 restarts ki wajah facts v2 ke error-log count se dekhenge |
| Mail ports | 25, 143, 465, 587, 993 (IPv4); 143/993 IPv6 | — | 110/995 band (theek) |
| Mail DNS | DMARC `p=reject; adkim=s; aspf=s; rua=dmarc@anexomail.com`; **MTA-STS khali, TLS-RPT khali, TLSA khali** | — | 8q |
| Postfix TLS | `smtpd_tls_security_level=may`, `smtp_tls_security_level=may`, cert `/etc/anexomail/mail-cert.pem`, `smtpd_milters=inet:127.0.0.1:8891`, **`milter_default_action=accept`** | `tempfail` behtar | 8t |
| Postfix delivery | `virtual_transport = anexopipe:` (mail ek pipe se app ko), `virtual_mailbox_maps/domains/alias_maps` hash files, `message_size_limit` 52,428,800 (50 MB) | — | 8i/8j: IMAP ka store khali lagta hai (neeche) |
| Mail store | `/var/mail/vhosts/anexomail.com` sirf **8 KB** | — | IMAP mailbox ka asli maal yahan nahi (verify: facts v2) |

**Seedha natija:** Constitution wale "Rust + QUIC + WebTransport" ke dawe sach hain (3443 bind, health live) — par versions purane hain (R0), aur mail ka "IMAP phone ke liye" raasta abhi aadha hai (8i/8j).
