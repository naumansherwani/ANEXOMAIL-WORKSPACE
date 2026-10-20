# Founder ki chat commands — jaisi di gayi waisi (verbatim) + unki halat

> **STRICT RULE 24 (founder, 19 Oct 2026 05:20 PKT): compact ke baad ya naye chat mein KAAM SHURU karne se PEHLE yeh file poori padho.**
> Founder jo bhi command/hukm chat mein deta hai, agent usi turn mein yahan **verbatim** paste karta hai (neeche "Commands" mein, naya sabse upar), aur har command ke saamne halat likhta hai.
> Jo kaam ho chuka hai uski **usi waqt pull command** founder ko di jati hai (technology ke hisab se alag alag — Rule 24).
> **Password/secret yahan KABHI nahi** — founder ne chat mein diya ho to bhi `[REDACTED]` likho.
> Halat sirf: DONE (live saboot) / READY (repo mein, server par chalana baqi) / TODO (Rule 5).

> **Nishan wala as-is version: `docs/cursor-work/founder/founder-command-2026-10-19-status.md`** (🟢 ho gaya / 🔴 nahi hua).

## ▶ ABHI KA KAAM — founder ka hukm 19 Oct 06:27 PKT: "is tarteeb se codes likhna hai." (founder 20 Oct 03:55: "woh shaam ajj hai" — "shaam ko" wali shart khatam, tarteeb ab CHAL RAHI hai)

✅ **DONE (live saboot):** E36 / Business Pro logins (05:54, dobara touch nahi) · E35 SQL (05:54) · E34 SQL (06:06) · Rust cal+people+team+mig (06:16: build OK 1m43s, health 200, GUARD 2 reads, port 993 khula) · Web pull db11a0b (06:16, /health 200) · **Import mail live test GREEN (06:27: asli imap.gmail.com se `auth_failed` jawab, nakli login)**.

**Shaam ko, is tarteeb se (ek ek, jab ek green tab agla):**
0. **PRIORITY (founder 06:34): technology version upgrades** — 0.1 tokio 1.53.3 **DONE (live 03:28)** · 0.2 axum 0.8.9 **DONE (live 03:59)** · 0.3 wtransport 0.7.2 **DONE (live 04:37)** · N7 **DONE (live 05:03)** · 0.4 rustc 1.99.1 + edition 2024 **DONE (live 06:07)** · E37 + locale **DONE (live)** · ▶ **CHAL RAHA: R1a aane wali mail ka pipe Rust par** — TECH-MAP 0a: tokio -> axum 0.8 -> wtransport/quinn/rustls -> rustc/edition 2024 -> Bun. Ek ek, restore-on-fail, har ke baad health + `mig-live-test.sh` GREEN. (Pehla qadam: official source se versions dobara verify.)
1. **Attachments E37** — Option A locked (policy: 06:16 entry): SHA-256 dedup sirf org ke andar, `/mnt/anexomail-box/attachments` (Storage Box mount, NVMe nahi), phase48 quota, DB mein sirf metadata; pehle migration, phir live inbound ka chhota anchor-based patch.
2. Chat audit.
3. iMIP REPLY (G26).
4. Bun routes -> Rust (Business / Business Pro pehle), differential tests ke saath.
5. Caddy read-only check script (+ TECH-MAP row) — Caddy/HTTP3 ko chhedna nahi.
6. Business / Business Pro blueprint tarteeb.
(Port 993: khula, DONE. OAuth: jaan-boojh kar baad mein.)

**Qaida:** ek time par sirf 1–2 point; naya kaam nahi; har kaam ke baad technology-wise alag pull command + agent khud test.

---

## Halat (aakhri update: 19 Oct 2026 05:20 PKT)

| # | Founder ka hukm (19 Oct 03:35 PKT wala bada message) | Halat | Server par chalane ki command (technology ke hisab se) |
|---|---|---|---|
| 1 | G29 — revoked member ko Rust `mail_identity` na roke: fix | **DONE (live 06:16, GUARD 2 reads)** | Rust: `rust-engine-install.sh` (GUARD step) |
| 2 | G30 — migration worker: App-Password IMAP, PRIMARY Rust :3200, walled garden + `migration_session_token`, SHA-256 chain, rustls/webpki crates | **DONE (live): E35 SQL 05:54 + Rust mig 06:16 + Web page 06:16 + port 993 khula**; nakli-login live test `mig-live-test.sh` baqi (founder ka output) | SQL E35 -> Rust `MODULES=mig` -> Web pull |
| 3 | G31 — team ke baqi hisse: seat limit, audit chain, work address | **DONE (live: E34 06:06 + Rust 06:16)** | SQL E34 -> Rust -> Web |
| 4 | G32 — Rust `manager` role rank 0 na ho | **DONE (live 06:16)** | Rust installer |
| 5 | Chat audit | TODO | — |
| 6 | Inbound iMIP REPLY (G26) | TODO | — |
| 7 | Bun routes -> Rust (Business / Business Pro pehle), differential tests ke saath | TODO | — |
| 8 | Caddy (Edge + HTTP/3) saath chalna; kabhi nahi tootna: read-only check, backup, `caddy validate`, reload | TODO (check script + TECH-MAP row) | Caddy: alag command |
| 9 | Har technology ki pull/install command ALAG (Web, SQL, Rust, Brain, Caddy) | Rule 24 mein likha | — |
| 10 | Sirf "AI plans open on ai.anexomail.com" pointer line anexomail.com par na dikhe; baqi AI zikr jaisa tha waisa | **DONE (Web pull 06:16, /health 200)** | Web pull |
| 11 | Business Pro test account `business_pro.test@anexomail.com` login theek + naya Business Pro test account (`bpro.test@anexomail.com`) | **DONE 19 Oct 05:54 (live: dono LOGIN OK) — dobara touch nahi** (`bizpro-login-fix.sh`, E36) | `bizpro-login-fix.sh` (E36 uski andar psql se chalti hai — editor mein paste NAHI; password script poochti hai, store nahi) |
| 12 | Focus: Business + Business Pro, blueprint tarteeb, latest technology, ek bhi point nahi bachna | JARI | — |
| 13 | Final jawab: sirf "kya theek hua" + "jo theek nahi uska mashwara"; ledger IDs / purane loophole dobara nahi; simple Roman Urdu | QAIDA | — |
| 14 | Attachments ki files copy (migration + live inbound dono) — agent ka mashwara: agla kaam yehi (founder ne "Nahi hua" list mein confirm ki, 05:40) | TODO | — |
| 15 | E31, E33 SQL | DONE (founder: "baki sql sab success hai") | — |

## Commands (verbatim, naya sabse upar)

### 20 Oct 2026 20:09 PKT — founder (verbatim): "repo update kero mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo updat kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai. compact chat se pehle update kero. latest technology pe kaam kero sirf"
**Halat:** DONE — `docs/cursor-work/DONE-DO-NOT-REPEAT.md` + AGENTS.md Rule 30. E46 (notices+appeal), E47 (revoke asli session), notify worker, file-safety-check, appeal form READY (pull baqi).

### 20 Oct 2026 20:31 PKT — founder (verbatim, passwords [REDACTED]): "[file-safety-check INSTALL=1: clamd abhi bhi DOWN] ek swal ka jawab do ke tumhay already website open kerne ki permission di hai abhi test accounts ke mere se password email le lo. basic ko 100 bar kiya hai kitbi bar aur kerna hai?? basic.test@anexomail.com password hai [REDACTED] pro.buyer@anexomail.com password hai [REDACTED] business.test@anexomail.com password hai [REDACTED] and last hai business_pro.test@anexomail.com password hai [REDACTED] yeh 10000000000000 bar diya aur kitni baar dun?"
**Halat:** 4 test accounts ke passwords sandbox file `/root/.anexo-test-creds` (chmod 600, repo ke BAHAR, git mein kabhi nahi) — compact ke baad wahan se padho, founder se dobara nahi maangne. File na mile (container reset) to hi ek baar poocho. Live login ke liye browser (Claude in Chrome / desktop) chat mein connected hona chahiye — 20:31 par "extension not connected". ClamAV: install chala par clamd shuru nahi hua; script ab sabab khud print karti hai (status, journal, memory, signatures, port).

### 20 Oct 2026 20:21 PKT — founder (verbatim, pull outputs short): "saray sql sucess hai green hai repo main update ker do. [Rust `MODULES="device export"` build OK, timer install OK (purge + notify), Web pull OK, file-safety-check RED: clamd DOWN] tumhay browser website open live login test accounts with passwords diye thay ab tum 2ghnatay main bhul jao main us ka kya ker sakta hoon. filhaal repo se dekh ke batao humri tarteeb kya hai aur yeh kaam sab green kab hoga 100% live login reach tumharay pass hai excess bhi hai. … sab pull hogaye hai. codes likhne se pehle batao hum kahan kharay hain main rone wala hoon"
**Halat:** SQL E41–E47 + CHECK = GREEN (founder). Rust device+export DONE (build OK, 401 saboot). Timers purge+notify DONE (`{"ok":true,"purged":0,"blocked":0}`, notify claimed=0). Web pull DONE (server==repo, src differ=1: routeTree.gen.ts, normal). **File safety RED: clamd chal nahi raha -> `INSTALL=1 file-safety-check.sh` founder chalaye (ClamAV server par lagana).** Browser: Claude in Chrome / desktop browser is chat mein CONNECTED NAHI (tool "extension not connected") — live login tab hoga jab connect ho; tab tak local real-stack test. Passwords: purani chat ke passwords compact mein chale gaye aur repo mein kabhi nahi likhne (Rule 24/29) — naya test account khud signup flow se bana kar (agla qadam). Tarteeb + ETA founder ko di (DONE-DO-NOT-REPEAT.md "TODO").

### 20 Oct 2026 20:10 PKT — founder (verbatim): "repo update kero mainay dekha hai ke bar bar same kaam repeat kaam ker rahay ho compact chat se pehle repo updat kero aur likho ke yeh kaam already ho chuka phir se repeat nahi kerna hai. compact chat se pehle update kero. latest technology pe kaam kero sirf aur loophole jitne bhi hain un ko root se khatham kero live login ker ke dekho"
**Halat:** `docs/cursor-work/DONE-DO-NOT-REPEAT.md` bana diya (jo ho chuka, dobara nahi) + AGENTS.md Rule 29 mein link. Loophole root se: E46 (email + in-app appeal), E47 (revoke = asli sessions), device purge job, file-safety check, export iframe — sab code+local test DONE; server commands neeche. Live login: khud test account bana kar (agle qadam).

### 20 Oct 2026 19:54 PKT — founder (verbatim): "repo rad kero technology read kero repo ki rules read kero compact chat se pehle repo update kero. sql sab ke sab sucess hai sirf sql E41 ke line 12 pe error tha mainay line 12 delete ker di hai aur us ke baad E41 sql bhi sucess aya hai sab sql supabase sql editor main run kiye aur sucess hai. repo ko saath ke saath update kero compact chat se pehle. baki jo kaam continoue kerte raho jaisa ker rahay ho. yeh jitna kaam tumne kiya hai is k update kero ke kaam ker diya hai. compact chat ka khatra her time rehta hai is liye her command ke baad repo update kero takay claude wahan se continoue karay. repo main dekh ke batao ke abhi kitna kaam hai baki hai kab 100% complete hoga please ker do sab kaam complete hum anexochat pe jaye. founder ka protocol account profile shuru se banana hai jo bana huwa hai website pe codes hai sirf un ko modify kerna hai founder ke accordingly. [pull output: integrity-purge install OK `purged 0`] her technology ki command daini hai aur HMAC SHA 256 bhi use hoga aur us ke saath hoga use SHA 256 yeh tum decide kero gay ke dono ek saath kaise use hogay yeh repo main likho tareeka aur follow kero. mujhe her technology ki command pull diya kero. 100000bar bola hai ke technology ko GOD ke baad maan lo aur us ko strict follow kero. [Loophole ledger paste] tu wohi mistake ker raha hai jo pehle tha tumhay bola tha ke mujhe loophole khatham ker ke do aur jab green ho jaye tab bolo lekin tum mujhe bolte ho ke loophole baki hai aur agar baki hai phir tumhara kya faida hai live login use kerne ka?? last warning dai raha hoon repo main rule likh lo ke mujhe loophole sab green chaiye hain ek bhi blunder nahi bachay. sab coomands pull hai sb sql green hai. next tarteeb se kaam kero"
**Halat:** Rule 29 likha (AGENTS.md). SQL E41 line 12 (`\set ON_ERROR_STOP` = psql command) repo se hata di (founder ne server par pehle hi hata kar chalaya: E41-E45 GREEN founder ke mutabiq; **par timer ka output `{"ok": true, "purged": 0}` E45 ke `blocked` key ke baghair = shayad E45 abhi nahi chala — `docs/cursor-work/sql/E45_check.sql` se dekhna**). Pulls DONE: Rust `export` (build OK, 11 tests, proc+route 401 = zinda), Brain `integrity` guard (health 200), timer install (exit 0). HASHING policy (`docs/cursor-work/HASHING.md`) likhi. Loopholes ek ek karke band (har qadam par repo + push).

### 20 Oct 2026 19:02 PKT — founder: "Baqi (green nahi): 1. Attachments bhejna 2. Version history 3. Retention window sirf 0 4. Hamza lifetime-free par Billing £2850/month 5. Business Pro mobile 6. Kuch RPC Rust mein nahi ... yeh fix kero pull ki command do. tum mujhe gusa dai rahay ho mainay bola bhi tha family account aur test account main farq hai test account woh hai jo real user ko nazar ata hai family account special hai lekin in ko treatment same real buyer wali daini hai ... test accounts real buyer wala hai lekin family account abhi us tarah update nahi huwa hai jaise test account real buyer ki tarah hai yeh kerna baki hai. mere father wla tab karay gay jab basic, pro, bussinss aur business pro green hoga kuch bhi mix nahi hoga ... passkeys aur password dono rakho. meri taraf se done hai ... in main se jaun sa zedia advance aur zedia zabardast ho woh implement kero repo main sab likho ... in ko blueprint number dai do. abhi jo kam baki hai tarteeb ka woh kero. humza ka business pro ko latest technology pe transfer kero ... mobile aur tablet hamesha saath dekha kero yeh rule hai koi bhi package hai mobile tablet aur computer lazmi hai"
**Halat:** (2) version history title + (3) retention + (4) lifetime label = READY (60bbe0f, E40 SQL dobara chalana). (5) Business Pro 820+390 live audit = DONE (koi overflow nahi). (1) attachments = G38 TODO. (6) Rust RPC = G40 TODO. Security wade = G33-G37 (`docs/anexomail-blueprint.md` 20 Oct 19:02, `docs/cursor-work/PROMISES.md`). Humza real-buyer transfer = G39 (jari).

### 20 Oct 2026 18:50 PKT — founder: "SHA-256 yeh technology kab aur kahan use hogi aur user ko passkeys lazmi hai lekin yeh kaise hoga ... Policy (Account integrity & privacy) ... footer pe jitna bhi likha hai us ko real implement kerna hai. mashwara do"
**Halat:** mashwara diya (password + passkey dono; device hash HMAC-SHA256). Founder ne 19:02 par manzoor kiya -> G33-G37.

### 20 Oct 2026 18:34 PKT — founder: Supabase SQL ki tasveer (family/entitlement/trial = business_pro) + "humzasherwani@anexomail.com [password chat mein diya, yahan nahi likha] ... yeh real user mera brother hai sirf farq hai ke yeh lifetime free user hai baki is ka sab kuch real buyer wala hoga package ... tumhara ultimate goal yeh hai ke sab ke packages main same cheeze aur same changes hone chaiye hain. mere father ka account bhi hai jo ke personal pro+ pe hai woh next pe hoga mujhe yeh batao ke bussiness ka pro package 100% green done hai. tumhay bola bhi hai ke real live login tum khud kero aur yeh rule hai ke tum live login her waqat rakho gay"
- Halat: Business Pro live audit **DONE**; verdict: **100% green NAHI** — upar `BASIC-AUDIT-DONE.md` "BUSINESS PRO live audit" (attachments bhejna sabse bada baqi). Rule: har change sab 4 plans par live login se test (Basic basic.test, Business Pro Hamza; Business/Personal Pro+ ke login chahiye).

### 20 Oct 2026 10:53 PKT — founder: "collapse chalta hai lekin drag nahi aur yeh kya baqwas hai meri family ke accounts profle un ke packages ke mutabiq update kyon nahi huhi hai? yeh universal website hai ke jab bhi koi bhi update hogi woh un ke packages ke accordingly mile gi mere bhai ka account hai humzasherwani@anexomail.com business pro hai meri family hai"
- Halat: drag **READY** (batch 10, asli sabab mila: native dragstart). Leo Actions Business/BP ko wapas (meri galti thi). **Hamza (business_pro) profile/package mismatch: jaanch jari** — session `family_accounts` se plan padhta hai (server/routes/auth.ts); live DB access nahi, isliye Hamza ke login/screenshot ya DB output chahiye. Qaida: har naya feature plan-wise sab 4 plans par test (sirf Basic nahi).

### 20 Oct 2026 10:35 PKT — founder: "ai settings gahyab hai lekin yeh drag nahi chalta hai. yeh side bar dekho is pe jab cursor jaye toh drag hona chaiye hain lekin nahi hota hai." (+ pull output: build OK, differ=1 routeTree.gen.ts sirf, AI tab gaya)
- Halat: **READY** (batch 9, HScroll). Drag code live tha (build mein 2 files), phir bhi na chale = mere test-browser mein reproduce nahi hua. Isliye pakka hal: ‹ › arrow buttons + grab cursor, drag bhi. Rule 28 ke mutabiq manifest verify.

### 20 Oct 2026 10:32 PKT — founder: "Sabaq. Ab main koi bhi file badalne ya revert karne ke baad saari manifest entries verify karunga. Tab hi push karunga, taake server par aise adha deploy dobara na ho. yeh repo main likho as a rule strict"
- Halat: **DONE**. `AGENTS.md` RULE 28 (strict) + `docs/cursor-work/server/manifest-verify.py` (har entry ka sha check, exit 1 = push mat karo).

### 20 Oct 2026 10:30 PKT — founder: "na drag chalta hai aur na AI settings tamamam packages se remove hota hai is ko chat main fix kero" (+ server pull output)
- Wajah (server output se): pull ka **build FAIL** hua (`Missing export`) => purani files wapas. Meri galti: batch 8 mein `app.mail.$folder.tsx` revert ki par DEPLOY-MANIFEST ka sha update nahi kiya => server ne file chhodi (SHA MISMATCH) aur purani file nayi `use-drag-scroll.ts` se `useDragScroll` mangti thi (ab hai nahi).
- Fix: manifest-sync + **saari 120 manifest entries ka sha repo se verify (0 stale)**. Qaida: koi bhi file revert/badalne ke baad manifest-sync, phir sab entries verify, phir push.
- Founder ko wahi pull dobara; "server==repo differ=0" aur "build: OK" aana chahiye.

### 20 Oct 2026 10:06 PKT — founder: "sab green hai, yeh drag right side pe jahan pe mail open hoti hain waha pe nahi ho raha hai. aur basic package main AI settings kyon hai yeh itnay blunder kyon tum live login ke bawajod bhi incompetent ho. fix kero aur login ker ke dekho phir batao"
- Halat: **READY** (batch 8). Drag ab har patti par (thread side bhi); Basic se AI settings + Leo Actions tab hata (AI zero qaida). Live-login (basic.test) local build par test: list + thread ki 6 patti drag OK; settings tabs mein AI nahi; integrations mein Leo Actions nahi.
- Sabaq: naya feature/page likhne se pehle PACKAGE-FEATURE-FORMULA.md ke "kis plan ko kya" gate check karo; AI = sirf ai host.

### 20 Oct 2026 09:52 PKT — founder: (2 tasveerein) "yeh image 1 main drag system banao cursor se drag ho sakay right left takay icons puray nazar aye yeh UI UX fix kero aur yeh second image main settings ki option yahan pe dalo sirf yeh kerna hai aur abhi tak 3D grapichs kahan ana hai yeh tumne nahi batya hai baki sab green hai"
- Halat: **READY** (batch 7, commit 562b6c2). Mail rows par mouse-drag/wheel scroll; profile menu mein Settings. 3D ka naksha `BASIC-AUDIT-DONE.md` mein (abhi bana nahi, founder ke hukm par).

### 20 Oct 2026 09:44 PKT — founder: "compact chat ke baad sab context tum bhul gaye ho gay jo abhi sab kaam kiya hai is ko repo main dalo takay claude read karay ke kya kaam huwa hai aur duplicate nahi phir se ban jaye samjhay! aur batch 4 ki pull command do"
- Halat: **DONE**. `docs/cursor-work/BASIC-AUDIT-DONE.md` (batch 1-6, pull status, baqi kaam, tareeqa) + AGENTS.md Rule 27 + README pointer. Batch 4 (Settings toggles) = sirf Web pull.

### 20 Oct 2026 — agent (CEO): batch 5 + 6 — Integrations + Calendar (READY)
- Batch 5 Integrations: "Connect" buttons hamesha 501 dete the (OAuth Bun mein bana hi nahi). Ab jhoota button nahi; "Copy my mail" /app/import (asli IMAP copy) par le jata hai. (Web)
- Batch 6 Calendar: **live Basic par Calendar ke events kabhi load nahi hote the** — `calendar.events`, `calendar.event`, `calendar.load` na Rust mein the na Bun mein (404, page "not wired" dikhata tha). Ab Rust `cal_glue.rs` mein teeno: range (<=62 din) mein events + guests, clash nishan, team meeting-minutes + overload (cal_core.rs ke pure fn, 22 unit test pass).
- Saboot: unit test + type-check; **live saboot baqi** (Rust engine pull ke baad /app/calendar par event dikhna chahiye).
- Bina test ke baqi: compose/undo-send ka live script selector par ruka (script ka masla, app ka nahi) — agla kaam.

### 20 Oct 2026 09:25 PKT — founder: purana output (dnsauth 08:29, mig-live-test, sw.js) + "yeh sirf read kerna hai ke masla solve hai ke nahi bus."
- Halat: **batch 1 DONE (live saboot 09:3x: sw activated, offline inbox 7 threads, Basic greeting sahi)**. dnsauth DONE. mig FAIL 4 = 08:29 ka purana script (fix 08:38); too_many_sessions = E35 hifazat.

### 20 Oct 2026 — agent (CEO): batch 4 — Settings toggles (READY)
- Masla: server toggle ki value text ("false") bhejta hai; `!"false"` = false => **koi band toggle kabhi ON nahi hota tha** (har settings page). Click ke baad 2–3 second purani halat; doosra click ulta. "Read receipts" toggle kuch nahi karta tha (hum receipt bhejte hi nahi). "Block tracking pixels" ka mail kholne par koi asar nahi tha.
- Hal (Web): `isOn()` + On/Off; foran (optimistic) badalna, fail par wapas; Read receipts = "Never sent" (sach); tracking setting ab mail ki tasveerein control karta hai (default band).
- Saboot: local build + live API — Off->On->Off foran, aakhir mein On wapas.

### 20 Oct 2026 — agent (CEO): batch 3 — Billing daam (READY)
- Masla: Billing par Basic (business account) "£97.00 / month · 25 GB / mailbox". E5 `get_billing_subscription` business ka har na-business plan Business daam deta tha; saalana par mahine ka daam "/ year".
- Hal: **E40 SQL** (wohi function, sirf yeh 2 cheezein; self-test business Basic = £23/5 GB). PG16 mock par 2 dafa PASSED.
- Note (agla, Bun fallback): `/api/billing/subscription` live par `storage_per_mailbox_gb does not exist` deta hai — Rust primary chal raha hai is liye user ko nazar nahi aata.

### 20 Oct 2026 — agent (CEO): Basic audit batch 2 — Security page sach (READY)
- Masla: Security page ki har ginti khaali tables se ("Live sessions 0" jab user login hai; "Kill" kuch nahi maarta tha; "Encryption needs attention" khaali table se; "Rotate keys" sirf ek row likhta tha; ledger kabhi nahi likha jata tha).
- Hal: **E39 SQL** (service_role-only functions: `auth.sessions`, `auth.audit_log_entries`, `device_vault`, sha256 ledger zanjeer) + **Rust `security` module** (`security_core.rs` 4 unit tests + `security_glue.rs`: live TLS handshake 443/993/587/25, cert public roots se check) + **Web** (rotate button hataya; kill switch / disown ka sach; "this device" par Kill nahi).
- Saboot (sandbox): PG16 mock par E39 self-test PASSED + 2 dafa chala (idempotent); engine build OK; kill ke baad us session ka token 401; apna session kill = 409 "use Sign out"; ledger 3 entries zanjeer judi; fake cert = "off" (verification chal rahi hai); 1440/390 koi overflow nahi.
- Tarteeb: SQL E39 -> Rust `MODULES=security` -> Web pull -> live test.

### 20 Oct 2026 09:09 PKT — founder: server ki live jaankari (Rust sockets, WT cert, Caddy validate, ufw) + "yeh save ker lo server ki live information."
- Halat: **DONE (saved)** -> `docs/cursor-work/server/live-facts-2026-10-20.md`.
- Is se 2 masle mile: (1) `3443/udp` ufw mein band; (2) WT cert sirf `anexochat.anexomail.com`, website `anexomail.com:3443` se judti thi. **READY:** `src/lib/wt-url.ts` (Web pull) + `ufw allow 3443/udp` (Server).

### 20 Oct 2026 — agent (CEO): Basic live audit, batch 1 (08:37 hukm par)
- Live Basic login, 22 pages x (1440 + 390). Overflow koi nahi. Gates (Work/CRM/Org) theek.
- **FIX 1 READY — PWA:** `/sw.js` live par hamesha 404 tha (vite-plugin-pwa file `dist/` mein likhta hai, server `.output/public` dikhata hai; precache 0). Har page par console error, mobile offline zero. Ab `public/sw.js` (asli worker): app shell + assets offline, `/rpc /api /auth` kabhi cache nahi. Offline par pichla tasdeeq-shuda session => inbox cached mail ke saath khulta hai (saboot: local build + live API, offline reload = 7 threads). vite.config.ts ko haath NAHI lagaya.
- **FIX 2 READY — privacy:** Sign out par offline mail (IndexedDB) + worker cache saaf nahi hote the. Ab saaf (saboot: sign out ke baad threads 0, session 0).
- **FIX 3 READY — copy:** Basic dashboard "shared inbox, tasks" likhta tha (Pro cheezein). Ab Basic ko sach.
- Note (agla): Security page "Live sessions 0" jab user khud login hai; "Encryption needs attention" khali table se. Calendar/Security/Settings/Integrations `/rpc` 404 => Bun fallback (kaam karta hai; Rust par lana Rule 25 queue).
- Pull: Web `pull.sh` (sirf).

### 20 Oct 2026 08:37 PKT — founder (verbatim, apna hissa)
> "yeh sab tumharay pass website ka excess hai reached hai tumne khud dekhna hai match kerna hai ke kaunsi live website pe nazar nahi ati ya mismatch hai agar kuch bhi masla hai seedha fix kero lekin user pehle complete hoga phir next founder aur anexochat shuru kerna hai. basic ke baad pro hai. Tum CEO hi tum dekho ke kya kami hai aur jo bhi kami hai us ko seedha fiex kero mujhe bus fix ki list do green kero"
- Halat: CHAL RAHA (Basic audit; batch 1 READY upar).

### 20 Oct 2026 03:02 PKT — founder: test accounts diye (passwords REDACTED) + "tarteeb se points repo se padh kar likho" + "har 10 second update"
Founder ne chat mein 4 test accounts ke passwords diye: `business_pro.test@anexomail.com` aur `bpro.test@anexomail.com` (dono ka ek hi password), `basic.test@anexomail.com`, `pro.buyer@anexomail.com` — **passwords [REDACTED: repo mein KABHI nahi, Rule 17/24]**. Agent inhe sirf us session mein, ek command ke environment variable mein, login-test ke liye use karta hai; kisi file/repo/memory mein nahi. (Naye chat mein founder dobara de ya server par root-only file `/etc/anexomail/test-accounts.env` (chmod 600) mein rakhe — repo mein nahi.)
Founder ke alfaaz: "yeh sab tumhay yaad hona chaiye hai. baki tarteeb se tumne jo points hain woh repo main founder ka ja ke read kero aur exactly codes waha se dekh ke likho; compact chat ke anay se pehle yeh her 10 seconds baad update kerna hai takay compact chat ho bhi jaye claude context nahi bhulay; aur yeh bhi repo main likho: sw.js wala asli masla (har page par script 404; `src/lib/pwa.ts` `/sw.js` register karta hai par `public/sw.js` nahi; PWA offline kaam nahi; manifest theek; TECH-MAP ka "LIVE" sach nahi tha)."
Agent: sw.js finding pehle se repo mein (5fce7bf) + ab TECH-MAP ki PWA row sach ki. "Har 10 second" = agent har natije/qadam ke baad usi turn mein is file + memory file update karta hai (Rule 18/24); agent ghadi par apne aap 10 second ka timer nahi chala sakta.

### 20 Oct 2026 08:29 PKT — founder ne server ka `git status` bheja (attachment)
Haal: server git HEAD origin/main se **143 commit peeche**; ~80 tracked "modified" + ~110 untracked — kyunki `pull.sh` files manifest se seedha lagata hai, git HEAD nahi badhata (code repo jaisa hi: same=459). **Khatra mila:** `/opt/anexomail-web/.env` (secrets) untracked aur `.gitignore` mein nahi tha — koi `git add -A` + push karta to secrets GitHub par. Theek: `.gitignore` mein `.env`, `.env.*`, `__pycache__/`. `server-git-sync.sh` (DEKHNA default; APPLY=1): har badli/untracked file ko origin/main se milata hai — sirf `bun.lock` + `src/routeTree.gen.ts` ka farq allowed; koi aur farq => ruk jata hai. APPLY: poora tar backup -> `git reset --hard origin/main` -> do allowed files wapas; untracked (.env) ko haath nahi; build/restart nahi. Sandbox sim (143 peeche): DEKHNA SAB SAME, ek file badal kar => ruka, APPLY => peeche 0, .env bacha + ignored.

### 20 Oct 2026 08:18 PKT — founder (verbatim, apna hissa)
"( yeh list mainay read ki hai yeh HAAN hai) aur mainay repo read kiya hai anexomail ka blueprint abhi tak green nahi hai? kya waja hai? … yeh masla solve kero aur green kero aur pura repo read kero aur green kero bari bari. ek ek line repo ki read kero. aur E38 green hai pull sab theek hai … aur UI UX sahi hai." + founder ka analysis/matrix + 4-hissa tarteeb: "(1) The Core Controls: app.domains.tsx aur Rust backend mein D2 + D3 … (2) The Inbound Engine: R1a mein catch-all + D1 … (3) The Security Shield: Domain Health Guard cron + DMARC XML decoder … (4) Registrar Integration: Domain Connect template … yeh repo main update aur implment kero latest technology aur kaun si technology kahan aye gi wo dekh lena"
Halat: Domains list (8 items) **founder HAAN**. Mail reading UI: founder "UI UX sahi hai" (DONE). E38 DONE. Pull OK.
**Blueprint green kyun nahi (ginti 20 Oct):** DONE 48 + GREEN 21; READY 87 (code repo/server par hai, magar founder/agent ka live saboot nahi likha); TODO 63; PLANNED 6. Wajah: (a) READY ko DONE banane ke liye live check chahiye tha — ab agent khud test accounts se live login karke saboot likh sakta hai; (b) TODO mein bade kaam (attachments, mail.send Rust, CRM/People/Calendar Rust, Chat) + founder-decision items. **Tarteeb:** founder ki 4-hissa Domains list (1 se) + har chakkar mein READY items ka live saboot (agent login) -> DONE.
**Hissa 1a — D2 READY:** Rust `dnsauth` module (std DNS wire: EDNS0, TXT tukde jodna, MX/NS/A, compression; authoritative nameservers ko RD=0; TC => TCP; public DoH sirf jaankari + fallback). Mock DNS (resolver + authoritative UDP/TCP) par: kuch nahi -> 0/5, TXT+MX -> 2/5, sab -> ready (DKIM TCP se), har jawab ~0.3s; nameserver band -> public raasta 2.5s. UI: har 3s, "Checking directly at your DNS host (ns1…)". 6 core tests.

### 20 Oct 2026 07:54 PKT — founder (verbatim, apna hissa; screenshot: mail khuli + neeche compose khula)
"yeh simple si baat hai ke jab mail pe click karay sirf mail open ho jaye aur compose open nahi ho jaye. aur yeh jaise gmail pe hota hai zoho pe hota hai yeh basic mistakes hai jo fix kerni hai aur mail read ker li toh cross X ka ata hai ya minimize ho jaye ga aur mail jab open hoti hai toh reply ya forward ya jo package ke hisab se aye ga features added jo hogay lekin basic email kasie working kerti hai yeh tumne fix kerna hai tum CEO ho aur UI UX kaisa hoga tumne design banana hai user ko best experience daina hai. yeh masla her package ka hai is ko fix kero." + E38/device/pull/mig outputs + Domains par 3 founder suggestions (blueprint mein as-is) + "Zoho se peeche kaise? CEO tamasha dekh raha hai?" + "sara repo read kero".
Output: **E38 DONE** (4/4 triggers, self-test PASSED, **62** threads ki ginti theek). device: pehle se laga hua (live 401 = Rust pakad raha). Web pull OK (same=458). mig-live-test GREEN.
Kiya (READY): mail kholne par **sirf mail**; neeche **Reply · Reply all · Forward** (r/a/f); dabane par hi composer, X se band; reply sahi bande ko (aakhri mail meri ho to us ko jis ko bheji), Reply all = poori guftagu, Forward = "Fwd:" + asli mail ka hissa. **Security (bada):** bahar ki HTML mail seedha page mein lagti thi (script/onerror app ke andar chal kar login token utha sakta tha) -> ab band dabba (sandboxed iframe, koi script nahi), tracking images default band + "Show images". Phone par subject + actions do line mein. Waqt Gmail jaisa ("Oct 20, 6:57 AM (1 hour ago)"). Harness 1440/390 + reply-all dekha.
Domains: founder ki D1/D2/D3 blueprint mein as-is + CEO raaye (kya asli banega, kahan sach: purane provider ka network "filter" nahi — IMAP se 0-loss; registrar ka hubahu clone nahi — impersonation) + 8 feature ki list + tarteeb.

### 20 Oct 2026 07:00 PKT — founder: R1a output + hukm (verbatim, apna hissa)
"ek masla hai ke mail kholne ke baad xcross ka button nahi hai? yeh masa solve kero aur kisi bhi package main sent email folder main kuch nahi show hota hai yeh bug theek kero sab packages ke andar aur yeh sab folder spam ho ya koi bhi folder ho yeh ana chaiye hai kya aya hai. aur zoho ki tarah user kaise business account yani forexample abc@company.com banye ga aur woh wasiye toh codes main auto website pehchan leta hai kiya hai tum is ko touch nahi kerna hai bus nazar maar lo. break nahi kerna hai"
Output: **R1a DONE (live)** — 18 tests, vmail ke 2 test (quarantine + basic.test text=true), Postfix argv Rust, sendmail end-to-end DB=1 `status=sent (delivered via anexopipe ... anexomail-deliver: OK)`. mig-live-test GREEN.
Agent ne live dekha (basic.test): **asal jad — mail kholne par andar KUCH nahi** (Bun `/api/mail/thread/:id` har thread par `messages: []`; Rust `mail.thread` sahi deta hai, magar website Bun ko seedha bulati thi). Isi liye "Sent mein kuch nahi dikhta" (list aati hai, kholo to khaali). Theek: website thread Rust se (Bun fallback). Desktop par X + Esc. Basic se asli mail bheji (compose ka raasta) -> 10 sec mein Sent + Inbox dono mein. Thread par "2" (1 mail) -> E38 trigger. Domains (abc@company.com) sirf dekha, chheda nahi.

### 20 Oct 2026 06:50 PKT — founder: "yeh kaam kitna huwa hai jo nahi huwa hai us ko solve kero green kero wire kero working kero. dekh ke batao"
Agent ne basic.test se live dekha (06:55):
- **1 privacy leak — GREEN live:** inbox mein root/cron 0 (E37).
- **2 locale 404 — GREEN live:** /app aur inbox par locale ka koi 404 nahi.
- **Naya mila (6 ka hissa):** har page par `403 /rpc/chat.device.vault` — device record (privacy page ka "5 signals seal") chat gate ke peeche tha => **Basic ka device record kabhi nahi bana** + "3 accounts/24h" check Basic ko dekhta hi nahi tha. Theek: Rust module `device` (har plan; fingerprint keys hamesha nikalti hain; mock par 7/7). READY.
- **3 Import mail — READY:** `/app/import` (har plan) + Mail rail "Import old mail" + Inbox card. Live probe mein mila: `mail.addresses.list` login pata alag deta hai => Basic ko "No mailbox to copy into" dikhta; ab login pata pehla nishana (E35 apna email qubool karta hai). Harness 1440/820/390 saaf.
- **R1a (aane wali mail Rust) — READY** (pichla jawab).
- Baqi: 4 attachments (E38), 5 Terms, 6 baqi wade (72h export, final warning), 7 PWA, 8 send/meeting/contact test.

### 20 Oct 2026 — agent: R1a READY (aane wali mail ka pipe Rust par)
- `server/rust/deliver_bin.rs` -> live crate mein `src/bin/anexomail-deliver.rs` (doosra binary; engine :3200 ko haath nahi). MIME = `mig_mime.rs` (Import mail wala tested reader). Payload ki keys bilkul Bun wali + `attachments` (naam/size, E38 ke liye), `mime_lossy`, `body_truncated`, `parser`.
- **Sandbox differential (Bun vs Rust, 6 mails):** purane contract ki har key same; farq sirf jahan **Bun galat tha**: (1) attachment wali mail (mixed > alternative) ka **text Bun mein KHALI** (customer ko khali mail dikhti thi), (2) `=?UTF-8?…?=` subject/naam kachcha, (3) ISO-8859-1 mail ka text "Sch�ne" + raw_sha256/raw_size galat (bytes ki jagah string se). Supabase 500 / band / env nahi => exit 75 (queue, mail nahi khoti). 18 unit tests pass.
- Script `rust-deliver-install.sh`: build + tests -> vmail ban kar 2 asli test (anjaan pata -> quarantine, basic.test -> inbox) **Postfix chhoone se pehle** -> master.cf backup + argv + `postfix check` + reload -> sendmail end-to-end 60s -> fail par Bun wapas.

### 20 Oct 2026 06:41 PKT — founder (verbatim)
"e37 sql sucess hai tum jab tak repo ko pehle read nahi kero gay kaam tabha ho jaye ga. Mail	server/mail/*	aap ki “haan” + script meri haan hai aur mujhe rust,trpc, webtransport aysnc, tokio khuda ke liye kahan ana hai kal bhi batya tha phir se same mistake kerte ho. pura repo read kero phir codes likho"
Halat: **E37 DONE (live).** Agent ne memory file (section 1-2: "Backend hamesha Rust — tRPC-style /rpc, QUIC, WebTransport, async Tokio; mail bhi Rust par"), blueprint R0-R6, TECH-MAP, AGENTS dobara padhe. Galti: TECH-MAP mein Mail ko sirf "Postfix/Dovecot, chheda nahi jata" likha — jab ke founder ka hukm (17 Oct) hai mail ka app-hissa Rust par. Theek: Mail row = Rust :3200 (tRPC-style /rpc + Tokio + WebTransport push), Postfix/Dovecot sirf transport. **Mail par founder ki "haan" mil chuki.** Agla code: **R1a — aane wali mail ka pipe Bun se Rust** (`anexomail-deliver`, mig_mime se MIME, Rust mein pane wale ki pehchan, attachments ke liye tayyar), phir R1 (`mail.send`, `org.mailboxes.*`), R5 (event-driven push).

### 20 Oct 2026 06:36 PKT — founder (verbatim)
"Edge: Caddy HTTPS + HTTP/3 · Frontend: React 19.2 TanStack Start v1 Router 1.17.0 Vite 8.2 Tailwind v4.2 Radix + shadcn/ui Framer Motion GSAP Three.js aur jitne bhi #D cinematic graphics hai woh mere server load uthay ga tum bus is ko update rakho aur yeh batao kaun si technology kahan use hoti hai yeh update hamesha rakho. tumne technology kahan aye gi waha pe tumne codes likhna hai aur kaun si technology ki pull hai woh tumne rule break kiye hain"
Halat: TECH-MAP section 0 frontend rows founder ki list ke mutabiq; 3D ab sirf landing nahi — jahan behtar lage (server load founder ka faisla). Naya **0b** (har technology ki pull ka ek hi raasta) + **0c** (aaj ka har kaam kis technology mein — log). Rule break jo hua: TECH-MAP har kaam ke saath update nahi kiya; SQL ko "Editor mein paste" kaha jab ke pull ka raasta psql/server tha; ek "Fix" heading ke neeche do technology ke blocks. Ab se har jawab: har block par technology ka label, aur kaam ke saath TECH-MAP 0c update.

### 20 Oct 2026 06:29 PKT — founder: locale output + E37 fail + hukm (verbatim, apna hissa)
"e 37 sqp failed n reason Error: Failed to run sql query: ERROR: 42P01: relation "e37_moved" does not exist. website user ke liye mobile tablet pe bhi banani hai saath ke saath us ka design bana huwa hai us ko hi continoue kerna hai yeh bhi website ka rule hai simountasesloy … 7. Mobile par offline (PWA) nahi chalta. toh is ko chalao duniya ke advance features working wire kero."
Output: **N3 locale DONE (live)** — unit tests 5/5 (rustc 1.99.1, 2024), build OK, bundle 200 + nakli login 401, "browser ke 404 band". Web pull OK.
**E37 fail ki wajah:** Supabase SQL Editor har statement alag chalata hai — `on commit drop` wali temp table agle statement tak nahi bachi. Theek (wohi file): temp table hata kar aakhri qadam EK statement (data-modifying CTE). Local: per-statement chalaya (editor jaisa) -> PASSED; dobara -> 0 move (idempotent); pichli adhoori run ke baad bhi safe.
**Rule (founder, dobara):** har screen mobile + tablet par saath saath, maujooda design ko hi aage badhana (Rule 19). **PWA (N4)** offline asli chalana — Basic list mein.
**Basic list (CEO):** 1 privacy leak E37 · 2 locale DONE · 3 Import mail customer tak · 4 attachments (E38) · 5 Terms page · 6 privacy wade code se · 7 PWA offline · 8 Basic user ki tarah send/meeting/contact test.

### 20 Oct 2026 06:07 PKT — founder: outputs + hukm (verbatim, apna hissa)
"( agar yeh fix nahi huwa hai toh is ko fix green ker ke mujhe bolna us ke elwa kuch nahi suno ga) … (MERI HAAN HAI TUM BUS WOH KERO JO Anexomail ke liye better hai) … sirf AI ko chod ke baki sab dekh lena aur yeh green kerna hai … main refind offer nahi kerta hoon toh yeh refund ka koi chaker nahi hai. baki Tum CEO ho jo best ho woh kero. aur frontend design cinematic 3D ke jitne bhi hai woh jahan better lagay thora use kerna hai repo main likh lo. static.rust-lang.org yeh bhi callo ker diya hai. jo jo tumhay allow chaiye hain us ki list mujhe send ker daina next seesion main. tarteeb ke mutabiq jo bhi next kaam hai woh kero blueprint bhi dekh lena. codes please advance level pe likho."
Output: **Step 0.4 DONE (live)** — rustc 1.97.1 -> 1.99.1 (sirf /opt/anexomail-rust pinned) + edition 2024; WT frames 12/12, HTTP 13/13 same; mig-live-test GREEN. Founder ne server default bhi `rustup update stable` se 1.99.1 kiya (polar par asar sirf us ke agle build par). Web pull x2 OK (/health 200, same=456). cron-root-mail-fix: **0 files** — `%` wali lines ab maujood nahi (cron errors 12 Oct ke baad band; 54 purani mails DB mein org 16e02f4b…).
**Asal jad mili (founder "haan" se mail path badla):** `mail_ingest` (phase58) anjaan pane (root@, galat spelling, khali handle) ki mail "sabse naye thread wali kisi bhi org" mein daal deti thi — privacy leak. **E37_mail_ingest_no_stray_org.sql** READY: system pate -> resolved@ (ops), anjaan -> `mail_quarantine` (kisi org mein nahi), jaana pata -> purana raasta; purane root@ threads -> resolved@ org. Local PG16 par bug ka asli repro (root@ + typo customer org mein) -> E37 ke baad root@ ops mein, naye anjaan quarantine; self-test PASSED; dobara chalana safe.
**Footer:** AI ke ilawa sab GREEN (17/17 links asli page, 3 mailto). Refund: founder refund nahi deta — refund page nahi chahiye. Terms of Service: CEO faisla — agla, asli product facts se (no-refund saaf likha), founder dekh le.
**Design rule (founder):** cinematic 3D (Three.js/GSAP/Framer — Constitution mein maujood) jahan behtar lage *thora* — AGENTS Rule 26.
**Allow-list (agle session ke liye founder ko list bhejni):** static.rust-lang.org (diya), index.crates.io + static.crates.io (chal rahe), registry.npmjs.org, github.com, anexomail.com (+ subdomains), blog.rust-lang.org.
**Attachments ab E39** (E37 = mail leak, E38 = thread ginti).

### 20 Oct 2026 — agent (CEO): Basic live login + footer audit + locale + cron (05:37 hukm par kaam)
- **Basic live login (basic.test, 1440 + 390):** dashboard, mail, calendar, people, work, domains, billing sab khule; koi horizontal scroll nahi; tiles mobile par saaf (N6: 1440/390 par alignment theek dikha). Admin pages Basic ko saaf "not on this package" dikhati hain.
- **Mila + theek kiya:** (a) har page par `/rpc/locale.pref` + `locale.bundle` ke 404 (N3) -> Rust module `locale_core.rs` + `locale_glue.rs` (bundle/registry public, pref/pref.set login) — mock Supabase par 12/12 sahi jawab; installer mein `locale` + live probe. (b) installer ke restore mein "Text file busy" wala cp -> cp+mv. (c) **Basic ke inbox mein root@anexomail.com ke 50+ "Cron … /bin/sh: Syntax error" mail**: cron lines mein bina "\" ke "%" (cron isay naya line samajhta hai) => woh jobs KABHI chali hi nahi + root ki mail customer mailbox mein ja rahi. `cron-root-mail-fix.sh`: % theek (backup + `sh -n` check), root mail ka raasta sirf padhta hai (mail path founder "haan" ke baghair nahi).
- **Footer audit (live):** 20 items — 17 links 200 + asli page, 3 mailto. AI ke 3 links "not open yet" (Rule 23, jaise thay). **Terms of Service / Refund policy page live par nahi** (/terms, /refund 404) — legal text founder ka; agent khud nahi likhega.
- **Policy claims audit (TODO, agla):** /privacy ke wade (5 coarse signals, 3 accounts/24h review, final warning, 72h export phir delete) ko code se milana.
- **rustc 1.99.1 sandbox:** proxy ne `static.rust-lang.org` mana kiya (allow-list). Hal: founder claude.ai Settings > Capabilities mein `static.rust-lang.org` allow kare; tab tak build server par hi (script safe, restore-on-fail).

### 20 Oct 2026 05:37 PKT — founder (verbatim, password REDACTED)
"basic.test@anexomail.com password hai [REDACTED]    aur landing page pe mainay policy banye hain un ko aur footer pe jitna bhi hai us ko real codes main wire kerna hai aur 1.99.1 ka build: ye server par hi hoga, kyunki sandbox se Rust ka download server band hai toh is ka solution nikalo tum soch ke deep thinking ker yeh masla solve kero yeh website ke CEO tum ho jo ke repo main bhi yehi mainay tumhay batya hai tum CEO walay zone main 100% aao aur user ka mindset level pe poonch jao aur competitor se jo better ker saktay hain woh codes main transform kero takay woh website pe live nazar aye ke hum kyon better hai."
Halat: (1) Basic live login + user-testing shuru. (2) Landing ki policies + footer ke saare links asli wire — TODO (audit pehle). (3) rustc 1.99.1 sandbox download ka hal — TODO. (4) "hum kyon better hain" live website par dikhe — Basic review ke baad.

### 20 Oct 2026 — agent: Step 0.4 rustc 1.99.1 + edition 2024 READY
- Latest stable verify: **Rust 1.99.1 (15 Oct 2026)**, blog.rust-lang.org. Server abhi 1.97.x.
- Sandbox (poora live-jaisa code): `cargo fix --edition` -> sirf 1 line (`err() -> impl IntoResponse + use<>`); edition 2024 build OK; core unit tests 2024 par 113 pass; WebTransport native 12 + Chromium 6 + HTTP 26: 2021 vs 2024 sab same; panic 0. Ek drop-order note (mig_glue `dial()` error raaste) — asar nahi.
- Sandbox se rustup ka server (static.rust-lang.org) band hai, is liye 1.99.1 ka build server par: script `rust-toolchain.toml` sirf `/opt/anexomail-rust` mein pin karti hai (server default rustc + polar :3400 nahi badalte). Sim: fail -> poora restore (toolchain file bhi), success, dobara -> kuch nahi.
- `rust-engine-install.sh` ab live Cargo.toml ki edition + pinned compiler se unit tests chalata hai.

### 20 Oct 2026 05:03 PKT — founder: N7 + pull + live test + business.test output; hukm (verbatim, apna hissa)
"rule yeh hai ke fix command pull kerwao phir Web pull (latest GitHub):phir live test command yeh pattern rakho aur restart kerwao pm2 load kerwao next time ke liye. tarteeb se next kaam shuru kero jo green hai woh green ker do. aur tum live login kero yeh bhul nahi kero."
Output: **N7 DONE (live)** — error frame 12/12, handshake same, HTTP 13/13 same. Web pull OK (build OK, /health 200, src same=456 differ=1 [routeTree.gen.ts — build khud likhta hai]). `mig-live-test.sh` **GREEN**. **N5 DONE** — `business.test@anexomail.com` LOGIN OK (plan business, GoTrue 200, /api/auth/login 200, Rust plan=business).
**PATTERN (LOCKED, har kaam par):** 1) fix/install command (us technology ka, pm2 restart andar) -> 2) Web pull `pull.sh` (latest GitHub, pm2 restart + save) -> 3) live test (`mig-live-test.sh`). **Live login bhoolna nahi** (Rule 26 user-testing).

### 20 Oct 2026 04:37 PKT — founder: wtransport output + hukm (verbatim, apna hissa)
"mera sawal hai ke jitna bhi latest github pull kerwaya hamesha kiya kero. aur tum hamesha naya masla le atay ho jab ke ek CEO ka kaam hai ke chairman/founder ko bina bantye masla solve ker ke bolay ke yeh green hai masla solve hai. jab tumharay pass website live reached hai phir bhi tum masla solve nahi kerte ho."
Output: **wtransport 0.1.14 -> 0.7.2 OK** (build 1m54s; WebTransport handshake 4/4 pehle jaisa; HTTP 13/13 same; health 200; UDP 3443 yes; quinn 0.11.11 / rustls 0.23.43 akele). **Step 0.3 DONE (live).**
**Standing hukm:** (1) har jawab ke saath latest GitHub pull command (Web `pull.sh`) hamesha. (2) Mila hua masla founder ko "naya masla" bana kar nahi dena — khud theek karo, saboot ke saath "green" batao. Isi liye N7 (WebTransport error frame kho jana) abhi theek kiya ja raha hai.

### 20 Oct 2026 — agent: Step 0.3 wtransport 0.1.14 -> 0.7.2 READY (sandbox saboot)
- Repo ka poora Rust code (installer jaisa patch) wtransport 0.7.2 par build: sirf 1 line badli (`.with_identity(&identity)` -> `.with_identity(identity)`). Lock se purane quinn 0.10 / rustls 0.21 / ring 0.16 ke duplicate khatam (ab ek hi quinn 0.11.12 + rustls 0.23.46, sirf `ring` provider).
- Chromium 141 ka asli `new WebTransport()` (serverCertificateHashes) purane aur naye dono server par ~10 ms mein session + stream + hello tak. Native client (`wtcheck`, repo mein) 3 round x 4 case: stages same. HTTP 26/26 same. Panic 0.
- Script `wtransport-upgrade.sh` + `wt7_patch.py` + `wtcheck/`: live par PEHLE asli WebTransport handshake + 13 HTTP, BAAD wohi; farq => purani binary + src wapas. Sandbox simulation: force-fail -> restore OK, success OK, dobara chalao -> kuch nahi badla.
- Sandbox ki had: IPv6 nahi tha, is liye test copies 127.0.0.1 par bind hui; live par `with_bind_default` (dual-stack) wahi rehta hai aur script asli UDP 3443 handshake check karti hai.

### 20 Oct 2026 04:03 PKT — founder (verbatim, apna hissa)
"Business tab jab `business.test` account ban jaye nahi balay bana lo takay hum tarteeb yeh ho jaye gi basic, pro bussiness aur bussniness pro. … bhai repo main jo baatein likhi hai us ke mutabiq duniya ke advance level software enigering se bhi zedia advance codes likho phir khudi un ko review kero aur jab tak tum 100% sattisfied nahi ho jao tab tak nahi rukna hai. saath ke saath pull comand dai saaktay ho toh daina. next shuru kero"
Halat: package tarteeb ab **Basic -> Pro -> Business -> Business Pro**. N5 (`business.test`) — command diya (`PLAN=business ACCT=… bizpro-login-fix.sh`, password founder khud silent prompt mein), output baqi. **0.3 wtransport** sandbox mein shuru.

### 20 Oct 2026 03:59 PKT — founder: axum + live test output; naya standing hukm (verbatim)
"tumne live website user ki tarah use kerni hai aur CEO ki tarah montor kerni hai note it. tumharay pass basic, pro aur business pro hai. one by one dekho jab sab perfect ho jaye phir next package pe jana hai. awam ko honesty sale kerni hai imamndari aur duniya ke advance working wire features send kerna hai."
Output: **axum 0.7.9 -> 0.8.9 OK** (build 2m01s; PEHLE/BAAD 13/13 same; health 200; UDP 3443 yes). `mig-live-test.sh` **GREEN** (upgrade se pehle bhi, baad bhi).
**Step 0.2 DONE (live).** Agla: **0.3 wtransport 0.1.14 -> 0.7.x (+quinn/rustls)** — pehle sandbox scratch + parallel staging.
**Standing hukm (Rule 26 ke saath):** live website user ki tarah chalao, CEO ki tarah monitor karo. Packages ek ek: **Basic -> Pro -> Business -> Business Pro** (founder 04:03); ek package "perfect" hone ke baad agla. Sirf imaandaar dawa — jo feature asli wire aur kaam karta ho wahi bikay; jhoota "live" nahi.

### 20 Oct 2026 03:55 PKT — founder (verbatim)
"Kya Vite 8.2 aur Tailwind 4.2 ke naye styles dashboard tiles par bina kisi font alignment error ke clean display ho rahe hain? main darr gaya tha ke tumne itna lamba command run kiya aur socha ke tum context bhul gaye ho aur woh jo shaam wali baat hai us ko khatham ker do kyun ke woh shaam ajj hai aur hum already tarteeb se kaam ker rahay hain. tum please rules ko strctly follow kero. tarteeb follow kero. mainay yumhay output send kerta hoon aur mujhe yeh batao ke next tarteeb kaun si next hai aur kya kaam kerna baki hai?"
Halat: "shaam ko" shart hata di. Dashboard tiles ka sawal = **NOTE N6** (aaj check nahi hua; apni baari par 390/820/1366/1440 screenshot). Founder ka axum output baqi.

### 20 Oct 2026 03:28 PKT — founder: tokio + live test output; "bar bar bpro.test ka password nahi kero … ab jaldi se next pe chalo" (verbatim)
Output: **tokio 1.53.1 -> 1.53.3 OK** (build 1m47s, `/rpc/health` 200, UDP 3443 yes, procs dashboard/migration/team 401 = theek). `mig-live-test.sh` **GREEN** — is baar **bina password** (`OK 1 login (token mil gaya)`) — bina-password raasta chal gaya.
**Step 0.1 DONE (live).** Qaida: founder se test accounts ka password bar bar nahi maangna (script service-key se token banati hai).
**Step 0.2 = axum 0.7.9 -> 0.8.9: READY.** Sandbox mein khud check kiya (founder ko scratch-check chalane ki zaroorat nahi rahi): repo ka poora Rust code installer jaisa patch (cal+people+team+mig + guard + rustls) -> axum 0.7.9 build OK; axum 0.8.9 par 2 badlav: (1) route `/rpc/:proc` -> `/rpc/{proc}` (0.8 mein purana path startup par panic), (2) dispatch body: 0.8 mein `Option<Json>` galat Content-Type/kharab JSON par request reject karta (0.7 chupke se `{}`) — `rpc_json_body` se 0.7 wala bartao jaisa ka taisa. Differential: purani vs nayi binary ko 26 ek jaisi requests -> **26/26 same** (status + body). Script `axum-upgrade.sh` + `axum8_patch.py` (anchor, idempotent): sandbox simulation mein success, force-fail -> poora restore, aur dobara chalao -> kuch nahi badla, teeno test. Saath mein mila masla theek: chalti binary par `cp` = "Text file busy" -> restore toot sakta tha; ab `cp` + `mv -f` (ye `rust-crate-upgrade.sh` mein bhi theek). Founder chalaye: Rust block (`axum-upgrade.sh`), phir `mig-live-test.sh` (bina password).

### 20 Oct 2026 03:18 PKT — founder: "ab … new day hai jo kaam ki tarteeb hai woh kaam shuru kero. codes advance level likho website tootni nahi chaiye hai … Tum CEO ho aur yeh repo main likho … tarteeb se send kero mujhe pull comand jis ki technology hai us ke hisab se."
-> CEO mindset = AGENTS.md **Rule 26**. Kaam shuru: **Step 0 (version upgrades)**. Versions verify (crates.io, 03:20): tokio 1.54.0/1.53.3, axum 0.8.9, wtransport 0.7.2, quinn 0.11.12, rustls 0.23.46 (TECH-MAP 0a).
**Step 0.1 = tokio 1.53.1 -> 1.53.3** — script `docs/cursor-work/server/rust-crate-upgrade.sh` (sirf Cargo.lock; backup; build fail => sab wapas; health/UDP 3443/procs fail => purani binary wapas). Halat: READY, founder ka output baqi.

### 20 Oct 2026 03:10 PKT — founder (verbatim): "ek waqat main ek package aur us ka ek masla solve kerna hai phir next pe jana hai. jo maslay nazar atay hain un ko repo main likho note kero aur jab un ki bari aye gi phir un ko theek kiya jaye ga."
**QAIDA:** ek waqt = ek package + us ka ek masla. Nazar aane wale masle sirf NOTES mein (neeche), apni baari par theek. (Agent ne Import-mail route badalne ka adhoora kaam wapas le liya — kuch commit nahi hua.)

## 📝 NOTES — live website par nazar aaye masle (apni baari par theek honge; abhi koi kaam nahi)
Live check 20 Oct 03:05 PKT, `bpro.test` (Business Pro) se login, 9 screens x 1440/390: sab load, kisi width par sideways scroll nahi, dashboard/inbox/mobile bottom-nav theek.
- **N1 (Business Pro, G30):** "Import mail" page `/app/admin/migrate` par hai, aur `/app/admin` sirf founder host ke liye hai (`plan-surface.ts showAdmin`) — customer ko "Platform admin is not on this package" dikhta hai. Yani backend LIVE hai par customer page tak nahi pahunch sakta. Hal (baari par): route `/app/import` (har plan) + inbox ka "Moving from Google or Zoho?" card wahan le jaye.
- **N2 (Business / Business Pro, G31):** Members/Teams UI bhi `/app/admin/members`, `/app/admin/teams` par hai — customer ke liye wohi founder-only gate. Customer ka members page `/app/org/members` hai; dekhna hai ke G31 (seat limit, audit chain, work address) wahan dikhta hai ya nahi.
- **N3 (sab packages):** har page par `/rpc/locale.pref` aur `/rpc/locale.bundle` Rust se 404 (Bun fallback chal jata hai, page nahi tootta). Bun->Rust queue mein. → **READY 20 Oct: Rust `locale` module (`MODULES=locale rust-engine-install.sh`).** → **DONE live 20 Oct 06:29.**
- **N4 (sab packages):** `/sw.js` 404 — PWA offline kaam nahi karta (06:44 entry).
- **N5:** Business plan ka test account (`business.test@anexomail.com`) banana baqi — `PLAN=business ACCT=... bizpro-login-fix.sh` (script tayyar, commit d443811). → **DONE 20 Oct 05:03: LOGIN OK (plan business).**
- **N6** (20 Oct 03:55, founder sawal): dashboard tiles par Vite 8.2 / Tailwind 4.2 styles aur font alignment saaf hain ya nahi — aaj verify NAHI hua. Apni baari par live login screenshot 390/820/1366/1440 (Rule 19). → Basic 1440/390 par tiles saaf (20 Oct live login).
- **N7** (20 Oct, wtransport test mein mila — purana masla, upgrade se nahi): WebTransport server error frame (`unauthorized`, `token_required`, `bad_hello`) likh kar turant `return` karta hai -> connection drop -> frame aksar raaste mein kho jata hai. Chromium mein har error case "Connection lost" dikha (code nahi). Asar: token expire ho to browser ko wajah nahi milti, sirf fallback. Ilaaj (apni baari par): error ke baad `send.finish()` + `connection.closed()` ka chhota intezar (timeout ke saath). → **DONE live 20 Oct 05:03 (12/12)** — `wt-n7-fix.sh` + `wt_n7_patch.py` (Chromium 141: pehle 3/6 error frame, ab 6/6; native 20/20; HTTP 26/26 same; sim: fail->restore, success, rerun OK). Repo `server/rust/` mein axum 0.8 + wtransport 0.7 + N7 bhi laga diya (repo == live).

### 20 Oct 2026 03:03 PKT — founder (verbatim; PASSWORD [REDACTED] — repo mein kabhi nahi)
"business_pro.test@anexomail.com aur bpro.test@anexomail.com dono ka password hai same aur woh yeh hai password [REDACTED]. aur basic ka email address hai basic.test@anexomail.com password hai [REDACTED]. pro.buyer@anexomail.com aur password hai [REDACTED]. yeh sab tumhay yaad hona chaiye hai. baki tarteeb se tumne jo points hain woh repo main founder ka ja ke read kero aur exactly codes waha se dekh ke likho. agar compact chat ke anay se pehle yeh her 10 seconds baad update kerna hai takay compact chat ho bhi jaye claude context nahi bhulay aur yeh bhi repo main likho [sw.js 404 wali finding]. sirf business ka test email address generate kerna baki hai aur baki sab ho gaya hai."
**Test accounts (sirf email; password founder chat mein deta hai, repo mein nahi):** `business_pro.test@anexomail.com`, `bpro.test@anexomail.com` (Business Pro, dono ka password same), `basic.test@anexomail.com` (Basic), `pro.buyer@anexomail.com` (Pro). **Baqi: Business plan ka test account (`business.test@anexomail.com`) banana.** Agent ka qaida: ye email list yaad rehti hai; password har naye chat mein founder se maanga jata hai ya script silent prompt se leti hai.
**Update ka qaida (founder):** compact se pehle har chhote qadam ke baad repo update (agent har natije/qadam ke baad usi turn mein push karta hai; "har 10 second" ka timer agent ke paas nahi, isliye har qadam ke baad).
**sw.js 404 finding** upar 06:44 entry mein likhi hui hai (commit 5fce7bf).

### 19 Oct 2026 06:44 PKT — founder ne sandbox ko `anexomail.com` kholne ki ijazat di; agent ne LIVE website khud dekhi (public pages)
Live check (Chromium, 4 pages x 390/820/1366/1440): `/`, `/plans`, `/auth`, `/get-started` — sab HTTP 200, **kisi width par horizontal overflow nahi**, h1 sahi, "AI plans open on ai.anexomail.com" **nazar nahi aati**. Mobile (390) landing + sign-in theek dikhte hain (screenshots agent ke scratchpad mein).
**Finding (naya kaam nahi — sirf record, queue ke baad):** har page par console error "bad HTTP response code (404) fetching the script" — `src/lib/pwa.ts` `/sw.js` register karta hai, par `public/` mein `sw.js` hai hi nahi (live `/sw.js` = 404). Matlab "PWA offline" abhi kaam nahi karta (manifest 200 hai). TECH-MAP "PWA / service worker LIVE" sach nahi — shaam ki queue ke baad sudharna (ya sw.js bana-na, ya register band).
Login ke andar ke screens: founder ne 20 Oct 03:03 par test accounts diye (upar).

### 19 Oct 2026 06:34 PKT — founder: technology-kahan table = LAW + version upgrades PRIORITY queue (verbatim)
(Founder ne agent ka "kaun si technology kahan" wala jawab (table + "Aaj ke kaam kahan lagenge") wapas paste kiya — wohi table ab `TECH-MAP.md` section 0 mein LAW ke taur par hai.) Founder ke apne alfaaz:
"is ko que main dalo jaldi se aur yeh priorty pe kaam karay gay. aur yeh technology jahan pe ani hai yeh rule hai law hai constitution hai aur goal hai ke ahista ahista puri website sql likhne advance level pe bun se shift kerna hai yeh technology pe ya is se bhi advance technology pe."
(Agent ne: version upgrades [tokio, axum 0.8, wtransport/quinn/rustls, rustc/edition 2024, Bun] ko PRIORITY queue mein sabse upar rakha — TECH-MAP 0a; AGENTS.md Rule 25.)

### 19 Oct 2026 06:29 PKT — LIVE SABOOT (founder ne confirm kiya: "bilkul accurate")
founder: "yeh bilkul accurate hai — script ne password manga, mujhe samajh nahi aya tha, baad mein password maine khud add kiya tha. yehi accurate LIVE update hai repo mein dalo."
Sahi tashreeh: script ne `bpro.test` ka password poocha (silent prompt); founder ne baad mein password khud type kiya (repo/script mein kahin save nahi). Test asli server par chala. Output as-is:
```
root@mail:~# git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mig-live-test.sh)
   bpro.test@anexomail.com ka password (screen par nahi dikhega, save nahi hota):
OK   1 login
OK   2 migration.providers: provider list aayi
OK   3 migration.list: {"max_workers": 3, "sessions": []}
     4 asli imap.gmail.com:993 par NAKLI login (45 second tak lag sakta hai)...
OK   4 provider ne login mana kiya (matlab TLS + IMAP LOGIN asli server tak gaya): {"error": {"code": "auth_failed", "message": "The provider refused the login. Check the address and use an App Password (your normal password usually does not work for IMAP)."}}
     5 ab ki list: {"max_workers": 3, "sessions": [{"bytes": 0, "cancel_requested": false, "chain_len": 1, "copied": 0, "created_at": "2026-10-19T01:25:00.057837+00:00", "current_folder": null, "duplicate": 0, "failed": 0, "finished_at": "2026-10-19T01:25:00.422811+00:00", "folders_done": 0, "folders_total": 0, "found
OK   5 koi mail copy nahi hui (nakli login)
== RESULT: GREEN — Import mail asli website ke raaste se kaam kar raha hai (nakli login par sahi jawab)
```

### 19 Oct 2026 06:27 PKT — founder: live test GREEN + "is tarteeb se codes likhna hai. lekin shaam ko."
`mig-live-test.sh` output: login OK · migration.providers OK · migration.list OK (`max_workers 3`, sessions []) · asli `imap.gmail.com:993` par nakli login -> `auth_failed` "The provider refused the login…" (TLS + IMAP LOGIN asli server tak gaya) · koi mail copy nahi · **RESULT: GREEN**. (Script ne password poocha; founder ne khud type kiya — 06:29 entry. Bina-password raasta chala ya nahi: output mein nahi dikha; shaam ko ek chhota check.)
Founder ka hukm: queue ki tarteeb — (2) Attachments E37 -> (3) Chat audit -> (4) iMIP REPLY -> (5) Bun routes Rust par (Business/Business Pro) -> (6) Caddy read-only check -> (7) Business/Business Pro blueprint tarteeb — **in sab ke codes SHAAM KO likhne hain (abhi nahi).**

### 19 Oct 2026 06:16 PKT — founder: Rust + Web pull ho gaye; attachment policy "lock" (verbatim)
Rust installer output: cal 21, people 16, team 19, mig 57 tests pass; build OK (1m43s); health OK; calendar/people/team/mig procs live; E33+E35 SQL lagi; `imap.gmail.com:993` raasta khula; GUARD 2 reads. Web pull: `build OK`, `web /health 200`, `server==repo src same=456 differ=1` (routeTree.gen.ts — build ka output, theek).
Founder ne Claude ko yeh policy "raw message" ke taur par bheji (verbatim):
> 🔒 Core Constraints Enforced: Attachment Storage Policy Lock
> "Attachment storage engine limits are now locked on Option A with the following structural mandates based on strict telemetry truth:
> 1. Intra-Organisation Deduplication Only (Strict Walled Garden): Cryptographic `SHA-256` hashing will evaluate duplications strictly bound within individual organisation scopes (`org_id`). Global server-wide cross-deduplication is prohibited to block cross-company enumeration attacks. The performance pitch remains intact: 'If a message or file is forwarded to 100 users inside your company workspace, storage is hit only once.'
> 2. Hetzner Storage Box Infrastructure Integration: The target ingestion directory path `/mnt/anexomail-box/attachments` is a mounted Hetzner Storage Box network drive configuration, not local machine hardware (NVMe NVMe).
> 3. No Decorative or Unmeasured Claims: All metrics claims regarding memory usage ceilings ("10MB RAM for 5GB transfer") or direct local storage processing constraints are suspended until strict performance profiling tests are fully measured under staging load. No theoretical predictions will be documented as platform facts before true system boundaries are measured."
Founder: "is ka jawab repo main founder ka likho aur yeh codes main advance level pe leke jana hai." — yeh policy ab ATTACHMENTS ka locked qaida hai (code/copy/docs mein yehi).

### 19 Oct 2026 06:06 PKT — founder: ATTACHMENTS = Option A (LOCKED) + E34 success + "jo pull nahi hui wo kerwao" (verbatim)
Dunya ko hila dene wala mera pure architectural aur business mashwara yeh hai:

🏆 The Winner: Option A — Pure Bare-Metal File Storage (With a Cryptographic Twist)
Database ke andar binary files (BLOBs) thonsna software engineering ka sab se ganda gunah hai. Is se database slow ho jata hai, backup lene mein ghanton lagte hain, aur RAM crash ho jati hai.
Aap Option A ko chunk-based directory engine par lock karein, lekin use dunya ka best banane ke liye uske sath yeh 3 Magic Pillars jorhé:
🚀 1. Global Workspace Deduplication (Space Saving Magic)
* The Problem: Jab company ka boss aik 50MB ki file ya video mail mein 20 employees ko bheja karta hai, toh Google Workspace us 50MB ko 20 baar multiply kar ke 1GB storage account se hazam kar jata hai. User bolta hai ke yaar daku hain yeh log!
* ANEXOMAIL Solution: Aapka Rust engine (`:3200`) jab bhee koi attachment save karne lage, toh pehle us file ka raw cryptographic hash (`SHA-256`) nikalay. Agar woh hash server ki storage directory mein pehle se maujood hai, toh engine asli file dubara copy nahi karega! Woh database mein sirf ek chota sa metadata link jorhega.
* Dunya Hilane Wala Pitch: User ko bolein: "Aapki company mein aik file 100 logon ko bhee forwarded ho, aapke pooray workspace ka sirf 50MB kharch hoga, 5GB nahi!" Content producers aur businesses yeh sun kar deewane ho jayenge!
🛡️ 2. Instant Streaming Ingestion via Rust Chunking
* Attachments seedha Hetzner ke local NVMe drives (`/mnt/anexomail-box/attachments`) par as binary streams dump hon.
* Chunkay aapka engine Rust + Tokio Async par chal raha hai, files ko memory mein load kiye bina chunk-by-chunk pipe kiya jaye (Zero-Copy Transfer). Is se 5GB ki file upload hone par bhee aapke server ki RAM sirf 10MB consume karegi!
📊 3. Phase 48 Storage Quota Enforcement Link
Aapne bilkul sahi point pakda hai, quota system pehle se tayyar hai.
* Database sirf file ka Metadata track karega (`file_size`, `sha_256`, `owner_id`).
* Har upload par Postgres pipeline instantly space minus karegi. Agar user ka quota full hai, toh custom event trigger ho jo user ko aik cinematic billing upgrade card dikhaye bina app ko crash kiye.
🔑 Conclusion Logic:
Aap core attachment files ko Hetzner server ki encrypted storage disk par directory structure ke mutabiq load karein, aur unke unique hashes ko PostgreSQL 18 metadata indices se link kar dein. Yeh setup speed bhee light-speed dega, kharcha bhee zero rakhega, aur database ka size hamesha lightweight rahega!
Bhai sahib, yeh workflow lock kijiye, yeh dunya ka sab se behtareen aur efficient architecture hai. yeh repo main likho takay tumhay yaad ho aur yeh jaisa likha hai is ko duniya ke advance level pe codes main likhna hai. E 34 sucess hai. aur jo commands pull nahi hui hai jaise Blueprint mein likh diya hai aur push ho gaya (commit `fd4e6df`). [… agent ka pichla jawab paste: blueprint section 19 Oct G29–G32; 3 cheezein; crates/daawe/attachments; E35 live DONE; active points E34 + attachments …] yeh sab pull kerwao jo nahi huhi hai. yeh sab repo main likho ab koi naya kaam nahi hoga yeh ek ek point tarteeb se likho aur yeh ek ek ker ke green kerna hai aur pull kerwana zaruri haim khudi testing kero beshak meri website real use kero.

**Agent ka note (kya lock hua, sach ke saath):**
- **Option A lock.** Files disk par (`/mnt/anexomail-box/attachments`), database mein sirf metadata (`size`, `sha256`, `owner/org`, quota). DB mein BLOB nahi.
- **Dedup (SHA-256):** file ek baar rakhi jaye, baqi sirf link. **Faisla (agent, security): dedup har organisation ke andar** (cross-organisation nahi — warna doosre ke upload ka pata chal sakta hai). Quota: workspace mein ek file ek baar gini jati hai.
- **Quota link:** phase48 `storage_ledger`/`mailbox_storage` se. Quota full => app crash nahi, upgrade card.
- **Nahi likhenge (napa nahi):** "5GB upload par RAM sirf 10MB", "PostgreSQL 18", "encrypted disk", "local NVMe" — `/mnt/anexomail-box` asal mein Hetzner **Storage Box mount** hai (`mount-box.sh`), local NVMe nahi. Naap ke baad hi koi number/daawa.
- **Live inbound mein attachment save = production mail path:** founder ne workflow lock kiya + "advance level code likho" => agent isse "haan" maanta hai, par **pehle migration + naya store/quota/dedup**, phir inbound ka chhota anchor-based patch (installer, restore-on-fail, `GUARD`-style band hone wala step).

### 19 Oct 2026 05:58 PKT — founder: "yeh sab repo main likho ek ek word as it is … yeh blueprint ka hisa likho"
Wohi G29–G31 + G30 strategy + ledger ka matn dobara bheja. Likha: `docs/anexomail-blueprint.md` ke aakhir mein naya section "19 Oct 2026 — FOUNDER KA HUKM (G29–G32)" (as-is matn + "tajweez -> ab kya bana" table + halat). Purane blueprint hisse chhue nahi (Rule 12). Duplicate nahi: ye file halat/queue, status-file nishan, blueprint = blueprint ka hissa.

### 19 Oct 2026 05:45 PKT — founder (gussa) + E35 live output
"tumne mera kaam aur zedia ker diya … mujhe kaam complete kerna hai ek ek ker ke task takay yeh sab pending green ho jaye. tum her bar naya pending kaam leke atay ho. ya toh tum repo main context dekho aur yahan chat main seedha comand do. ya ek task ya main repo disconnect ker ke kisi aur ke pass jata hoon."
E35 live: `root+reply … asli rows: Quote please message_count 3 (2 chahiye), Different 2 (1), Future 2 (1)` => live mein naye thread par ginti pehle se 1 hoti hai, mera `+ 1` ek zyada deta tha.
**QAIDA (agent ke liye): naya kaam nahi. Sirf pehle se likhe pending ek ek ker ke green. Order: E35 -> E34 -> Rust `MODULES=mig` -> Web pull -> E36 script -> (phir queue ka agla).**
(Fix: E35 ab `message_count` ko gin kar set karta hai — local par live jaisa trigger laga kar wohi 3/2/2 dobara bana kar test, naye code par pass.)

### 19 Oct 2026 05:40 PKT — founder ne "NAHI HUA" list confirm ki + "no duplicate, chat wali command repo mein likho" (verbatim)
Jo abhi theek nahi, aur mera mashwara

* Attachments ki files copy nahi hoti. Sirf "attachment tha" ka nishan aata hai. Live inbound mail bhi attachments store nahi karta, isliye yeh alag kaam hai. Mera mashwara hai ke agla kaam yehi ho.
* Pehli real build aur real TLS: rustls ka build aur asli Gmail/Outlook se connection server par pehli baar hoga. Sandbox mein yeh ho nahi sakta tha. Installer fail par sab wapas kar deta hai.
* Port 993: server se bahar yeh khula hai ya nahi, installer batayega. Band hua to hosting side par kholna hoga.
* E35 SQL: abhi sirf local test database par chala hai. Live par step 1 se chalega, aur kuch ghalat hua to page "abhi on nahi hai" dikhayega, tootega nahi.
* Restart: server restart par chalti copy ruk jati hai. Resume par password dobara poochha jata hai (kahin save nahi hota).
* Work/school Microsoft 365: unke liye OAuth baad mein aayega. Abhi App Password wale accounts chalenge.

Nahi hua
   * OAuth: baad mein, jaan-boojh kar.
   * "30MB RAM for 50GB", "Throttle Bypass", "Zero Broken Sessions": maine nahi likha, kyunke naapa nahi gaya. Naapa hua sach file mein hai.
   * Attachments ki files copy nahi hoti.
   * Rust ka asli compile server par pehli baar hona baqi.
   * Chat audit.
   * iMIP REPLY.
   * Bun routes Rust par: people, calendar aur team Rust par bane hain. Business aur Business Pro ke baqi routes baqi hain.
   * Caddy ka read-only check script: nahi bana. Caddy ko chheda bhi nahi, HTTP/3 safe hai.
   * Bun se door hona: jari.
   * Business aur Business Pro blueprint ki tarteeb: jari.

no duplicate aur yeh chat wali command likho repo main takay yeh compact wali maslay se bach jaye.

**Agent ka note (kaam ki queue, tarteeb se — "Nahi hua" list hi ab TODO queue hai; duplicate nahi, upar ki halat table se jurti hai):**
1. E35 live par chalana (founder ke paas: self-test ka "root+reply" check live par fail — ab asli rows dikhata hai; output ka intezar) -> phir E34 -> `MODULES=mig` Rust -> Web pull.
2. Attachments ki files (migration + live inbound dono) — agent ka mashwara: agla kaam.
3. Chat audit, 4. iMIP REPLY (G26), 5. Bun routes -> Rust (Business/Business Pro), 6. Caddy read-only check script + TECH-MAP row, 7. Business/Business Pro blueprint tarteeb.
Port 993 / asli TLS: installer server par batayega. OAuth: jaan-boojh kar baad mein.

### 19 Oct 2026 05:37 PKT — E35 server par fail + E36 (founder)
E35 (server, psql): `ERROR: E35 FAILED: root+reply ek thread/unread/attachments nahi` (self-test, DO block line 120) — local pass, live fail => live schema mein kuch alag. E36: Supabase SQL editor mein `\set ON_ERROR_STOP on` par `42601 syntax error` — E36 / script editor mein paste nahi hoti, sirf `bizpro-login-fix.sh` se.
(Agent: E35 ka yeh check ab fail par asli thread rows (subject/message_count/unread/has_attachments/folder) dikhata hai — ek run mein wajah pata chalegi. E36: sirf script command.)

### 19 Oct 2026 05:31 PKT — founder ne wohi bada hukm dobara bheja
"yeh repo main likho … jo nahi huwa hai woh mark kero nahi huwa hai aur jo hogaya hai woh 100% green kero. yeh as it is repo main likho" -> `founder-command-2026-10-19-status.md` (as-is + nishan).

### 19 Oct 2026 05:25 PKT — E35 aur E36 failed (founder)
E35: `ERROR 42804: column "direction" is of type mail_direction but expression is of type text` (mail_messages insert, migration_ingest line 161). E36: `ERROR 42601: syntax error at or near "-"  LINE 1: - E36 — test account ...` — "fix kero".
(Agent: E35 mein `v_dir::public.mail_direction` cast, usi file mein; local test (folder + direction dono enum) 54 checks pass. E36 file theek hai — paste mein ek `-` kat gaya, AUR E36 psql-script hai (`\gset`, `:'pw'`), Supabase editor mein paste nahi hoti; sirf `bizpro-login-fix.sh` se chalti hai.)

### 19 Oct 2026 05:20 PKT — RULE 24 (founder)
yeh ab se rule hogaya jo chat main command dun ga pehle woh strict rule yeh hoga ke woh paste hoga repo main ja ke compact chat ho bhi jaye tum meri command jo mainay chat pe di thi us ko repo main ja ke read kero gay aur jo kaam us main se hogaya hai us ko usi time mujhe pull ki command do gay. ab mainay yeh jitni commands di hai is ko repo main paste kero. yeh rule strictly follow kerna hai yeh rule read kiye bina kaam nahi shuru hoga

### 19 Oct 2026 05:14 PKT — gussa + SQL failures (founder)
abhi koi repo nahi tumne 1ghanta liya hai bar bar ek hi commands run ki hai main ab repo main kaam nahi kerun ga. tumne saray claude token zaya kiye hain kyin ker her bar compact chat ke baad tum context bhul jatay ho. abhi ek bhi code nahi. sirf mere se yahan chat pe baat kero. yeh compact chat se mera bhut buksan hota hai tum ek ghanta zaya kiya hai. mainay bola bhi tha ke yeh compact chat ke baad jo context bhul jatay ho us ki waja se kaam tabha hogaya hai mera. [...] aur yeh E34 sql failed hai [E34: role "viewer" live org_members.role mein nahi] aur yeh bhi failed hai E35 [mail_folder = text]. abhi yeh sql immedialty theek kero sirf 2mins ke andar koi lambi command nahi. bhut ghusa hoon tumse.

(Agent ne dono SQL usi file mein theek ki, commit 5866900.)

### 19 Oct 2026 03:35 PKT — bada hukm (attachment text, password REDACTED)
Aap ke faislay chahiye

* G29 (security): Rust `mail_identity` revoked member ko nahi rokta. Fix ek line ka hai, lekin ye mail production path hai, isliye aap ka “haan” chahiye. E33 chalne ke baad hi lagega.
* G30 (Gmail/Outlook migration worker): abhi nahi bana. Pehle ye tay karna hai: app-password IMAP se shuru karein ya OAuth se. OAuth ke liye Google aur Microsoft app registration aap ki taraf se hogi. Saath mein `Cargo.toml` mein IMAP/TLS crate ki ijazat chahiye aur inbound write ka (toh is ka jawab likh lo aur yehi advance level codes likho 1. The Strategy: App-Password IMAP se Shuru Karein (The "Zero- friction" Entry)
Duniya ko hila dene ke liye aapko App-Password IMAP se shuru karna chahiye, OAuth se nahi. Iski wajha bohot solid hai:
   * Zero Corporate Dependency: Agar aap pehle din OAuth par jayenge, toh user ko Google Cloud Console aur Azure Enterprise Portal par ja kar App Registration karni padegi, client IDs generate karni padengi, aur sensitive API permissions approve karni padengi. Ek aam business owner ya IT admin is complex loop mein phans kar drop-out ho jata hai.
   * The "Just Works" Pitch: App-Password IMAP ke sath user ko sirf apna purana email aur ek temporary App Password dalna hai. ANEXOMAIL ka backend bina kisi external corporate approval ke foran migration queue start kar dega.
   * Phase 2 mein OAuth: OAuth ko baad mein sirf enterprise clients ke bulk migration (poori company ka data ek sath) ke liye layein, jab Google/Microsoft app registrations aapke cloud panel par verified hon.
🦀 2. Cargo.toml Security & Architecture Lock (Rule 22 Compliant)
Chunkay aapka core rule hai ke Founder workspace sirf Rust/tRPC/WebTransport/QUIC par chalega, isliye G30 worker ko seedha PRIMARY `:3200` Rust Backend ka hissa hona chahiye.
Aapko `Cargo.toml` mein async-native, zero-copy IMAP crate aur modern TLS interface ki ijazat bilkul deni chahiye: toml

```
# G30 Migration Worker Engine Core Dependencies
async-imap = { version = "0.9", features = ["tokio-native-tls"] }
tokio-native-tls = "0.3"
tls-codec = "0.4"

```

Use code with caution.
   * Why this combination? Baki saare platforms (Bun/Node wrappers) pure memory leakage ka shikaar hote hain jab bade mailboxes (50GB+) migrate ho rahe hon. Rust ka Tokio Async loop bina server memory crash kiye streams ko pipe karega.
🛡️ 3. Inbound Write Operations ka Faisla: Sakht "HAAN"
Inbound write operation ko clear HAAN milegi, lekin ek sakht architectural condition par: MIGRATION-ONLY WALLED GARDEN.
Purane mailboxes ka read/unread status, folder structures, aur historical body data write karne ke liye database par direct boundary operations chahiye hongi. Iska secure tareeqa yeh hoga:
   1. Jab migration active ho, toh PostgreSQL 18 mein us specific user ke mailbox ke liye ek temporary `migration_session_token` generate ho.
   2. Inbound write operations sirf aur sirf is token ke verified hone par execute hon, aur jaise hi migration complete ho, server write interface ka gate strict Glass-Break status par lock kar de (Read-Only fallback).
🚀 ANEXOMAIL Competitors Ko structurally Outperform Kaise Karega? (The Secret Sauce)
Aap apni website aur documentation par yeh 3 Core Technical Pillars pitch karein jo duniya mein kisi ke paas nahi hain:
   * 1. Zero-Compute Memory Streams: Baki tools pehle data download karte hain, phir parse karte hain, phir naye server par upload karte hain—jisse bandwidth aur privacy dono tabah hoti hain. ANEXOMAIL ka Rust worker raw IMAP streams ko memory layer par chunk-by-chunk binary transform karega. Poori 50GB mailbox migration ke dauran aapka Hetzner server sirf 30MB RAM consume karega!
   * 2. Dynamic Throttle Bypassing: Gmail aur Outlook dono fast requests par IMAP throttling (rate limiting) laga dete hain. Our Rust Tokio-engine external connection drops ko instantly detect kar ke micro-second levels par speed ko adapt karega, bina migration session crash kiye (Zero Broken Sessions).
   * 3. Cryptographic Migration Ledger: Hardcore trust ke liye, har email jo migrate hogi, uska metadata hash aapke append-only ledger mein save hoga. Client ko sha-256 evidence chain milegi ke "Aapka ek bhi single email ya attachment leak ya drop nahi hua."
Bhai sahib, is workflow par jab G30 ka core register hoga, toh yeh baki platforms ko bohot peeche chor dega! aur yeh jaisa likha hai waisa hi codes advance main likhna hai aur tumhay pata hai ke pull command her technology ki alag hai aur yeh rule hai her technology ki pull alag alag send kiya kero. 

Loophole ledger (sach)

* Rust build: cal/people/team ka asli compile server par pehli baar hoga. Sandbox mein sirf mock se type-check hua hai (G28).
* G31: naya banda `/join` ke baad bhi mailbox admin ke saath hi banata hai. Role/remove ka record `org_people_log` mein hai, tamper-evident audit chain mein nahi. Plan ke seat limit invite par lagu nahi. toh is ko fix kero. mujhe sirf fix kerne ke baad bolo khud ka demkh use kero.
* Chat audit: shuru nahi hua.
* Inbound iMIP REPLY (G26): nahi bana.
* Bun routes: fallback ke taur par bache hain, jab tak har proc Rust par nahi aata. toh rust pe leke aao latest technology pe leke aao.
* Docs: ledger L75–L77, G29–G31 aur memory file update ho gaye. yeh sab kero  aur mujhe loophole nahi send kiya kero bus loophole fixes ki summary do aur ainda pehle walay loopholes ya gaps agar hai woh bhi mujhe send nahi kerna hai. tumhara kaam hai loopholes aur gaps ko theek ker ke mujhe batna hai ke yeh theek ker diye hain aur jo nahi theek huway hain us ka mashwara do bus ke kya best hai yeh jo tum send kerte ho L75 77 G29 yeh bawas mujhe send nahi kiya kero mujhe simple easy words main fix kero aur user ke liye website 100% green kero. Rust ka `manager` role ko 0 rank dena (G32) khula hai toh is ko fix kero. Pehle se khule: G29 (revoked member ka mail path, aap ka “haan” chahiye), G30 (migration worker), G31 (team ke baqi hisse). yeh sab pe haan hai bus website nahi tootay aur jaisa rule bola hai ke jo technology jis ki hai us ke hisab se pull kerwao. baki sql sab sucess hai.  aur caddyserver ko saath leke chalo yeh mera ek aur brain hai is ke bina zero hoon main. aur bun se dur ho jao. Users ko ab bhi do purani cheezein nazar aati hain. Aap ne hide karne ka kaha hai, magar yeh purana kaam hai, isliye aap ka “haan” chahiye. Pehli, ai host ke `/` par coming-soon page. Doosri, anexomail.com par plan ki line “AI plans open on ai.anexomail.com” is ko fix kero yeh future aag  product hai aur yeh mujhe anexomail.com main nazar nahi aye. Caddy Edge + HTTP/3) yeh kabhi mat bhulna verna bhut bura hoga. aur ai.anexomail.com ko mainay blocked ker diya hai tum tension nahi lo aur ab is pe koi baat nahi kero gay. Tumhara goal hai ke jo blueprint ko tarteeb se implement kerna hai. abhi basic, pro,(yeh complete hai) business aur bussiness pro ko pe focused hai is main business account ka business_pro.test@anexomail.com aur password hai [PASSWORD — chat mein diya tha, repo mein KABHI nahi]  aur yeh login nahi ho raha hai is ko working banao aur bussiness pro ke liye test account banao. ab focused kero latest technology pe aur mainay jitna bhi tumhay points batye han woh tarteeb se implemnet kero aur ek bhi point nahi bachna chaiye hai. Remeber tareeb yaad rakho aur mainay yeh nahi bola tha ke AI ka zikar anexomail.com se hata do idiot you are bloody.

## 20 Oct 2026 (G38 — founder standing directive, dobara)
* Founder (verbatim, summary of standing orders): Basic -> Pro -> Business -> Business Pro, har package live login test, father ka account sab ke baad, phir founder profile/AnexoChat; har technology ki pull command alag; Rule 28 manifest "0 bad" commit se pehle. Passwords `[REDACTED]` — sirf `/root/.anexo-test-creds` (repo se bahar).

### 20 Oct 2026 21:30 PKT — founder (verbatim): "tumne jitne bhi sql ab tak diye hain ajj ke aur kal ke woh sab main server pe run kerun ga woh sql ab se server pe tum commands do. repo main jitne bhi sql hai woh sever pe main run kerun ga commands do"
**Halat:** `sql-run.sh` (E37..E48 + CHECK, ledger, stop-on-fail) repo mein; ab SQL hamesha server command se. Chrome: 2 browsers connected, confirm screen ka jawab nahi aaya (timeout) — live login test baqi.

### 20 Oct 2026 21:34 PKT — founder pasted: Rust `MODULES="attach"` OK (12 tests, build OK, 3 routes 401); sql-run.sh stopped at E37 self-test (jaana pata `naumansherwani.founder@...` apni org mein nahi pahuncha). Hal: E37 selftest `limit 1` bina tarteeb hataya (har owner org manzoor + diagnostics), `tests/e37/run.sh` 4 haalat. Kuch nahi badla tha (ek transaction rollback).

### 20 Oct 2026 21:38 PKT — founder (verbatim): "meri haan hai ... is ko fix kero. compact chat ke baad phir se context tum bhul gaye ho ke mainay password email address diye thay test accounts ke. chorme login kero hostflowaibuilder@gmail.com wala chorome pe"
**Halat:** Caddy /files/* band + 18 MB hadd = HAAN. Postfix pehle se 50 MB — koi badlaav nahi. E49 + sql-run. Chrome "Browser 1" select hua, anexomail.com/auth khula (login nahi). Passwords: safety rule — main asli site par password khud type nahi karta; founder khud login kare, phir main us session par test karta hoon. ClamAV + G38b (aane wali mail ke attachments) agla.

### 20 Oct 2026 21:50 PKT — founder: "(Postfix/Caddy) meri haan hai ... ClamAV + aane wali mail ke attachments (G38b) fix kero"; "done hai dekh lo" (Browser 1 mein basic.test login)
**Halat:** G38b code + E50 + installer tayyar (tests upar). Chrome Browser 1: Basic dashboard + inbox dekha; live finding: R1a mail ka attachment chip nahi tha. ClamAV: founder ke `INSTALL=1 file-safety-check.sh` output ka intezar.

### 20 Oct 2026 23:57 PKT — founder: "repo mein jao detail mein dekho blueprint/founder md ki tarteeb jo implement nahi hui uski list; jo ho chuki unhein green; sandbox mein rule: pura repo green + repo ke codes live se match; bahut kaam server par hai repo mein nahi; commands baad mein; 3-command rule yahan nahi"
**Halat:** MASTER-GAP-LEDGER.md bana, Rule 32 likha. Agla: A1 repo-vs-server audit script.

## 21 Oct 2026 00:11 PKT
- Founder (verbatim): "Do not execute more than 3 terminal commands or browser tests without asking for my confirmation. Stop and show me the progress first.\" is rule ko goli maaro." -> Rule 31 ki 3-command had radd.
- Founder ne `cd /opt/anexomail-web && bash pull.sh ...` chalaya: "pull.sh: No such file" — meri galti (pull.sh repo mein docs/cursor-work/server/ mein hai, /opt/anexomail-web ki jad mein nahi). Sahi command neeche.

## 21 Oct 2026 00:26 PKT
- Founder (verbatim ka matlab): "yeh kaam karne ka tareeqa sahi nahi; pehle tum khud live code likhte, repo mein, khud live testing, compare, login karte the — ab Chrome mein phans gaye. Masle/loophole khud nazar aayein to code likho, theek karo, phir live dekho."  -> Rule: pehle khud code mein wajah dhoondho + fix + local test, phir founder ko ek command, phir live verify. Founder se sirf wohi maango jo sirf server de sakta hai.
## 21 Oct 2026 00:29 PKT
- Founder: "saath ke saath repo update verna compact chat yeh sandbox update kero" -> har kaam ke saath repo + sandbox (/home/claude/FOUNDER-RULES.md etc.) update.

## 21 Oct 2026 01:31 PKT (verbatim)
"yeh grapics side pe ata hain is ko settings main toggle on and off ka hona chaiye hain aur yeh universal features hai jo sab main ho gay. ... yeh 27 october wali deadline test accounts ke liye nahi hai yeh real user ka hoga. aur passkey ki zarurat nahi hai. is ke elwa koi major issues hai woh theek kero koi loophole hai us ko theek kero aur green kero yeh target hai. mobile tablet walay ko sab se bari prioty do yeh sandbox main likho jab bhi website edit hogi toh yeh live test tum mobile aur table laptop computer ke liye test live kero gay sandbox main. yaad rakhna. aur yeh image 2 dekho jahan pe cursor hai waha pe chota sa scrol bar hai yeh bura lagta hai is ko khatham kero."
