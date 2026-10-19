# Founder ki chat commands — jaisi di gayi waisi (verbatim) + unki halat

> **STRICT RULE 24 (founder, 19 Oct 2026 05:20 PKT): compact ke baad ya naye chat mein KAAM SHURU karne se PEHLE yeh file poori padho.**
> Founder jo bhi command/hukm chat mein deta hai, agent usi turn mein yahan **verbatim** paste karta hai (neeche "Commands" mein, naya sabse upar), aur har command ke saamne halat likhta hai.
> Jo kaam ho chuka hai uski **usi waqt pull command** founder ko di jati hai (technology ke hisab se alag alag — Rule 24).
> **Password/secret yahan KABHI nahi** — founder ne chat mein diya ho to bhi `[REDACTED]` likho.
> Halat sirf: DONE (live saboot) / READY (repo mein, server par chalana baqi) / TODO (Rule 5).

> **Nishan wala as-is version: `docs/cursor-work/founder/founder-command-2026-10-19-status.md`** (🟢 ho gaya / 🔴 nahi hua).

## ▶ ABHI KA KAAM — sirf yeh (founder ka hukm 19 Oct 05:47 PKT: "ek time pe sirf ek ya do point")

✅ **DONE (live saboot, founder 19 Oct 05:54 PKT):** E35 SQL live par chal gayi (COMMIT, error nahi). E36 / Business Pro login: `business_pro.test@anexomail.com` aur naya `bpro.test@anexomail.com` dono LOGIN OK (GoTrue 200, website /api/auth/login 200, Rust dashboard.summary plan=business_pro). **Founder: "yeh ab dobara touch nahi kerna hai."**

1. **E34 SQL live par chalana** (self-test ki galti theek, commit 5866900) — green = `E34 OK` + `PASSED`.
2. **Attachments ki files copy karna** (migration + live inbound dono) — design sawal founder se pehle (live inbound = production mail path, "haan" chahiye).

**Qaida:** is jagah sirf 1–2 point rehte hain. Jab inka server par pull/chalna green ho jaye (founder batata hai), tab hi agla point yahan aata hai. Agent apne se koi naya kaam nahi jodta.
**Baad mein (abhi nahi, tarteeb se):** Rust `MODULES=mig` -> Web pull -> Chat audit -> iMIP REPLY -> Bun routes Rust par (Business/Business Pro) -> Caddy read-only check script -> Business/Business Pro blueprint tarteeb. (Port 993 / asli TLS: installer server par batayega. OAuth: jaan-boojh kar baad mein.)

---

## Halat (aakhri update: 19 Oct 2026 05:20 PKT)

| # | Founder ka hukm (19 Oct 03:35 PKT wala bada message) | Halat | Server par chalane ki command (technology ke hisab se) |
|---|---|---|---|
| 1 | G29 — revoked member ko Rust `mail_identity` na roke: fix | READY | Rust: `rust-engine-install.sh` (GUARD step) |
| 2 | G30 — migration worker: App-Password IMAP, PRIMARY Rust :3200, walled garden + `migration_session_token`, SHA-256 chain, rustls/webpki crates | SQL E35 **DONE (live, 05:54)**; Rust `MODULES=mig` + Web pull baqi | SQL E35 -> Rust `MODULES=mig` -> Web pull |
| 3 | G31 — team ke baqi hisse: seat limit, audit chain, work address | E34 SQL galti theek (5866900), server par chalna baqi | SQL E34 -> Rust -> Web |
| 4 | G32 — Rust `manager` role rank 0 na ho | READY | Rust installer |
| 5 | Chat audit | TODO | — |
| 6 | Inbound iMIP REPLY (G26) | TODO | — |
| 7 | Bun routes -> Rust (Business / Business Pro pehle), differential tests ke saath | TODO | — |
| 8 | Caddy (Edge + HTTP/3) saath chalna; kabhi nahi tootna: read-only check, backup, `caddy validate`, reload | TODO (check script + TECH-MAP row) | Caddy: alag command |
| 9 | Har technology ki pull/install command ALAG (Web, SQL, Rust, Brain, Caddy) | Rule 24 mein likha | — |
| 10 | Sirf "AI plans open on ai.anexomail.com" pointer line anexomail.com par na dikhe; baqi AI zikr jaisa tha waisa | READY (Web pull) | Web pull |
| 11 | Business Pro test account `business_pro.test@anexomail.com` login theek + naya Business Pro test account (`bpro.test@anexomail.com`) | **DONE 19 Oct 05:54 (live: dono LOGIN OK) — dobara touch nahi** (`bizpro-login-fix.sh`, E36) | `bizpro-login-fix.sh` (E36 uski andar psql se chalti hai — editor mein paste NAHI; password script poochti hai, store nahi) |
| 12 | Focus: Business + Business Pro, blueprint tarteeb, latest technology, ek bhi point nahi bachna | JARI | — |
| 13 | Final jawab: sirf "kya theek hua" + "jo theek nahi uska mashwara"; ledger IDs / purane loophole dobara nahi; simple Roman Urdu | QAIDA | — |
| 14 | Attachments ki files copy (migration + live inbound dono) — agent ka mashwara: agla kaam yehi (founder ne "Nahi hua" list mein confirm ki, 05:40) | TODO | — |
| 15 | E31, E33 SQL | DONE (founder: "baki sql sab success hai") | — |

## Commands (verbatim, naya sabse upar)

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
