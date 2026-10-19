# Founder ki chat commands — jaisi di gayi waisi (verbatim) + unki halat

> **STRICT RULE 24 (founder, 19 Oct 2026 05:20 PKT): compact ke baad ya naye chat mein KAAM SHURU karne se PEHLE yeh file poori padho.**
> Founder jo bhi command/hukm chat mein deta hai, agent usi turn mein yahan **verbatim** paste karta hai (neeche "Commands" mein, naya sabse upar), aur har command ke saamne halat likhta hai.
> Jo kaam ho chuka hai uski **usi waqt pull command** founder ko di jati hai (technology ke hisab se alag alag — Rule 24).
> **Password/secret yahan KABHI nahi** — founder ne chat mein diya ho to bhi `[REDACTED]` likho.
> Halat sirf: DONE (live saboot) / READY (repo mein, server par chalana baqi) / TODO (Rule 5).

> **Nishan wala as-is version: `docs/cursor-work/founder/founder-command-2026-10-19-status.md`** (🟢 ho gaya / 🔴 nahi hua).

## ▶ ABHI KA KAAM — founder ka hukm 19 Oct 06:27 PKT: "is tarteeb se codes likhna hai. lekin SHAAM KO."

✅ **DONE (live saboot):** E36 / Business Pro logins (05:54, dobara touch nahi) · E35 SQL (05:54) · E34 SQL (06:06) · Rust cal+people+team+mig (06:16: build OK 1m43s, health 200, GUARD 2 reads, port 993 khula) · Web pull db11a0b (06:16, /health 200) · **Import mail live test GREEN (06:27: asli imap.gmail.com se `auth_failed` jawab, nakli login)**.

**Shaam ko, is tarteeb se (ek ek, jab ek green tab agla):**
0. **PRIORITY (founder 06:34): technology version upgrades** — TECH-MAP 0a: tokio -> axum 0.8 -> wtransport/quinn/rustls -> rustc/edition 2024 -> Bun. Ek ek, restore-on-fail, har ke baad health + `mig-live-test.sh` GREEN. (Pehla qadam: official source se versions dobara verify.)
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

### 19 Oct 2026 06:44 PKT — founder ne sandbox ko `anexomail.com` kholne ki ijazat di; agent ne LIVE website khud dekhi (public pages)
Live check (Chromium, 4 pages x 390/820/1366/1440): `/`, `/plans`, `/auth`, `/get-started` — sab HTTP 200, **kisi width par horizontal overflow nahi**, h1 sahi, "AI plans open on ai.anexomail.com" **nazar nahi aati**. Mobile (390) landing + sign-in theek dikhte hain (screenshots agent ke scratchpad mein).
**Finding (naya kaam nahi — sirf record, queue ke baad):** har page par console error "bad HTTP response code (404) fetching the script" — `src/lib/pwa.ts` `/sw.js` register karta hai, par `public/` mein `sw.js` hai hi nahi (live `/sw.js` = 404). Matlab "PWA offline" abhi kaam nahi karta (manifest 200 hai). TECH-MAP "PWA / service worker LIVE" sach nahi — shaam ki queue ke baad sudharna (ya sw.js bana-na, ya register band).
Login ke andar ke screens: founder test account email+password denge (repo mein KABHI nahi, sirf test accounts).

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
