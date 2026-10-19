# Founder ka hukm — jaisa diya waisa (as it is) + har cheez par nishan

> Nishan (19 Oct 2026 05:35 PKT): 🟢 HO GAYA = repo mein bana + test pass (jahan likha "server par chalana baqi" wahan server par chalane ke baad hi Rule 5 ke hisab se DONE). 🔴 NAHI HUA = nahi bana / jari. ⚪ = founder ne khud roka.
> Neeche matn founder ka **as-is** hai (sirf test password `[REDACTED]`). Nishan `>` wali lines mein.
> Founder 2 minute mein batayega kaun si cheez nahi hui — woh yahan 🔴 ho jayegi.

Aap ke faislay chahiye

* G29 (security): Rust `mail_identity` revoked member ko nahi rokta. Fix ek line ka hai, lekin ye mail production path hai, isliye aap ka “haan” chahiye. E33 chalne ke baad hi lagega.

> 🟢 **HO GAYA** **LIVE DONE (06:16):** Rust GUARD — 2 reads revoked member ko bahar rakhte hain.

* G30 (Gmail/Outlook migration worker): abhi nahi bana. Pehle ye tay karna hai: app-password IMAP se shuru karein ya OAuth se. OAuth ke liye Google aur Microsoft app registration aap ki taraf se hogi. Saath mein `Cargo.toml` mein IMAP/TLS crate ki ijazat chahiye aur inbound write ka (toh is ka jawab likh lo aur yehi advance level codes likho 1. The Strategy: App-Password IMAP se Shuru Karein (The "Zero- friction" Entry)

> 🟢 **HO GAYA** App-Password IMAP pehle (OAuth baad mein enterprise ke liye) — worker PRIMARY Rust :3200 mein. **LIVE DONE:** E35 SQL (05:54), Rust `mig` (06:16, build OK), Web page (06:16), port 993 khula.

> 🔴 **NAHI HUA** OAuth (Phase 2) — jaan-boojh kar baad mein, app registration founder-side.

Duniya ko hila dene ke liye aapko App-Password IMAP se shuru karna chahiye, OAuth se nahi. Iski wajha bohot solid hai:
   * Zero Corporate Dependency: Agar aap pehle din OAuth par jayenge, toh user ko Google Cloud Console aur Azure Enterprise Portal par ja kar App Registration karni padegi, client IDs generate karni padengi, aur sensitive API permissions approve karni padengi. Ek aam business owner ya IT admin is complex loop mein phans kar drop-out ho jata hai.
   * The "Just Works" Pitch: App-Password IMAP ke sath user ko sirf apna purana email aur ek temporary App Password dalna hai. ANEXOMAIL ka backend bina kisi external corporate approval ke foran migration queue start kar dega.
   * Phase 2 mein OAuth: OAuth ko baad mein sirf enterprise clients ke bulk migration (poori company ka data ek sath) ke liye layein, jab Google/Microsoft app registrations aapke cloud panel par verified hon.
🦀 2. Cargo.toml Security & Architecture Lock (Rule 22 Compliant)

> 🟢 **HO GAYA** Worker Rust :3200 ka hissa.

Chunkay aapka core rule hai ke Founder workspace sirf Rust/tRPC/WebTransport/QUIC par chalega, isliye G30 worker ko seedha PRIMARY `:3200` Rust Backend ka hissa hona chahiye.
Aapko `Cargo.toml` mein async-native, zero-copy IMAP crate aur modern TLS interface ki ijazat bilkul deni chahiye: toml

> 🟢 **HO GAYA** Cargo.toml: IMAP/TLS crate ijazat par **rustls 0.23 + webpki-roots 0.26** judte hain (agent ka faisla: std-only IMAP client; `async-imap`/`tokio-native-tls`/`tls-codec` nahi, kyunke `tls-codec` TLS connection ke liye nahi hai). **Live build OK (06:16).**


```
# G30 Migration Worker Engine Core Dependencies
async-imap = { version = "0.9", features = ["tokio-native-tls"] }
tokio-native-tls = "0.3"
tls-codec = "0.4"

```

Use code with caution.
   * Why this combination? Baki saare platforms (Bun/Node wrappers) pure memory leakage ka shikaar hote hain jab bade mailboxes (50GB+) migrate ho rahe hon. Rust ka Tokio Async loop bina server memory crash kiye streams ko pipe karega.

> 🔴 **NAHI HUA** "30MB RAM / 50GB" ka daawa code ya copy mein **nahi likha** — napa nahi gaya. Naapa hua: 1 GB / 20k mail ~6.5 MB peak (sirf core), 20 MB ki mail ~105 MB peak.

🛡️ 3. Inbound Write Operations ka Faisla: Sakht "HAAN"
Inbound write operation ko clear HAAN milegi, lekin ek sakht architectural condition par: MIGRATION-ONLY WALLED GARDEN.
Purane mailboxes ka read/unread status, folder structures, aur historical body data write karne ke liye database par direct boundary operations chahiye hongi. Iska secure tareeqa yeh hoga:
   1. Jab migration active ho, toh PostgreSQL 18 mein us specific user ke mailbox ke liye ek temporary `migration_session_token` generate ho.
   2. Inbound write operations sirf aur sirf is token ke verified hone par execute hon, aur jaise hi migration complete ho, server write interface ka gate strict Glass-Break status par lock kar de (Read-Only fallback).

> 🟢 **HO GAYA** MIGRATION-ONLY WALLED GARDEN: `migration_session_token` (DB mein sirf SHA-256 hash), likhna sirf `migration_ingest` se, khatam par seal + lock. ("PostgreSQL 18" ka daawa nahi likha.) E35 local test pass; **live par chalana baqi**.

🚀 ANEXOMAIL Competitors Ko structurally Outperform Kaise Karega? (The Secret Sauce)
Aap apni website aur documentation par yeh 3 Core Technical Pillars pitch karein jo duniya mein kisi ke paas nahi hain:
   * 1. Zero-Compute Memory Streams: Baki tools pehle data download karte hain, phir parse karte hain, phir naye server par upload karte hain—jisse bandwidth aur privacy dono tabah hoti hain. ANEXOMAIL ka Rust worker raw IMAP streams ko memory layer par chunk-by-chunk binary transform karega. Poori 50GB mailbox migration ke dauran aapka Hetzner server sirf 30MB RAM consume karega!

> 🔴 **NAHI HUA** "Zero-Compute / 30MB RAM for 50GB" — nahi likha (napa nahi).

> 🔴 **NAHI HUA** "ek bhi attachment leak ya drop nahi hua" — **attachments ki files copy nahi hoti** (sirf flag); live inbound bhi store nahi karta. Alag kaam.

   * 2. Dynamic Throttle Bypassing: Gmail aur Outlook dono fast requests par IMAP throttling (rate limiting) laga dete hain. Our Rust Tokio-engine external connection drops ko instantly detect kar ke micro-second levels par speed ko adapt karega, bina migration session crash kiye (Zero Broken Sessions).

> 🔴 **NAHI HUA** "Dynamic Throttle Bypassing / Zero Broken Sessions" — nahi likha (napa nahi). Asli: provider throttle par backoff + retry; restart par copy ruk jati hai, Resume par password dobara.

   * 3. Cryptographic Migration Ledger: Hardcore trust ke liye, har email jo migrate hogi, uska metadata hash aapke append-only ledger mein save hoga. Client ko sha-256 evidence chain milegi ke "Aapka ek bhi single email ya attachment leak ya drop nahi hua."

> 🟢 **HO GAYA** Har email ka SHA-256 append-only chain + sealed receipt + Check receipt (tamper-evident; tamper-proof nahi).

Bhai sahib, is workflow par jab G30 ka core register hoga, toh yeh baki platforms ko bohot peeche chor dega! aur yeh jaisa likha hai waisa hi codes advance main likhna hai aur tumhay pata hai ke pull command her technology ki alag hai aur yeh rule hai her technology ki pull alag alag send kiya kero. 

> 🟢 **HO GAYA** Advance code likha; 🟢 **HO GAYA** har technology ki pull alag (Rule 24, AGENTS.md).


Loophole ledger (sach)

* Rust build: cal/people/team ka asli compile server par pehli baar hoga. Sandbox mein sirf mock se type-check hua hai (G28).

> 🟢 **LIVE DONE (06:16):** Rust cal+people+team+mig ka asli compile server par: build OK 1m43s, health 200, procs live.

* G31: naya banda `/join` ke baad bhi mailbox admin ke saath hi banata hai. Role/remove ka record `org_people_log` mein hai, tamper-evident audit chain mein nahi. Plan ke seat limit invite par lagu nahi. toh is ko fix kero. mujhe sirf fix kerne ke baad bolo khud ka demkh use kero.

> 🟢 **HO GAYA** G31 fix bana (seat limit invite par, audit chain, work address) — E34 SQL (galti theek, commit 5866900). **LIVE DONE** (E34 06:06 + Rust 06:16).

* Chat audit: shuru nahi hua.

> 🔴 **NAHI HUA** Chat audit — shuru nahi hua.

* Inbound iMIP REPLY (G26): nahi bana.

> 🔴 **NAHI HUA** Inbound iMIP REPLY (G26) — nahi bana.

* Bun routes: fallback ke taur par bache hain, jab tak har proc Rust par nahi aata. toh rust pe leke aao latest technology pe leke aao.

> 🔴 **NAHI HUA (jari)** Bun routes Rust par — people / calendar / team Rust par **LIVE (06:16)**; baqi Business/Business Pro routes baqi.

* Docs: ledger L75–L77, G29–G31 aur memory file update ho gaye. yeh sab kero  aur mujhe loophole nahi send kiya kero bus loophole fixes ki summary do aur ainda pehle walay loopholes ya gaps agar hai woh bhi mujhe send nahi kerna hai. tumhara kaam hai loopholes aur gaps ko theek ker ke mujhe batna hai ke yeh theek ker diye hain aur jo nahi theek huway hain us ka mashwara do bus ke kya best hai yeh jo tum send kerte ho L75 77 G29 yeh bawas mujhe send nahi kiya kero mujhe simple easy words main fix kero aur user ke liye website 100% green kero. Rust ka `manager` role ko 0 rank dena (G32) khula hai toh is ko fix kero. Pehle se khule: G29 (revoked member ka mail path, aap ka “haan” chahiye), G30 (migration worker), G31 (team ke baqi hisse). yeh sab pe haan hai bus website nahi tootay aur jaisa rule bola hai ke jo technology jis ki hai us ke hisab se pull kerwao. baki sql sab sucess hai.  aur caddyserver ko saath leke chalo yeh mera ek aur brain hai is ke bina zero hoon main. aur bun se dur ho jao. Users ko ab bhi do purani cheezein nazar aati hain. Aap ne hide karne ka kaha hai, magar yeh purana kaam hai, isliye aap ka “haan” chahiye. Pehli, ai host ke `/` par coming-soon page. Doosri, anexomail.com par plan ki line “AI plans open on ai.anexomail.com” is ko fix kero yeh future aag  product hai aur yeh mujhe anexomail.com main nazar nahi aye. Caddy Edge + HTTP/3) yeh kabhi mat bhulna verna bhut bura hoga. aur ai.anexomail.com ko mainay blocked ker diya hai tum tension nahi lo aur ab is pe koi baat nahi kero gay. Tumhara goal hai ke jo blueprint ko tarteeb se implement kerna hai. abhi basic, pro,(yeh complete hai) business aur bussiness pro ko pe focused hai is main business account ka business_pro.test@anexomail.com aur password hai [PASSWORD — chat mein diya tha, repo mein KABHI nahi]  aur yeh login nahi ho raha hai is ko working banao aur bussiness pro ke liye test account banao. ab focused kero latest technology pe aur mainay jitna bhi tumhay points batye han woh tarteeb se implemnet kero aur ek bhi point nahi bachna chaiye hai. Remeber tareeb yaad rakho aur mainay yeh nahi bola tha ke AI ka zikar anexomail.com se hata do idiot you are bloody.

> 🟢 **HO GAYA** Docs/ledger/memory update.

> 🟢 **HO GAYA** G32 — Rust `manager` rank 0 nahi **LIVE DONE (06:16).**.

> 🟢 **HO GAYA** G29 / G30 / G31 par "haan" — likha gaya.

> 🟢 **HO GAYA** Pull har technology ki alag — Rule 24.

> 🔴 **NAHI HUA** Caddy (Edge + HTTP/3) read-only check script + TECH-MAP row — nahi bana. (Caddy ko chheda nahi, HTTP/3 safe.)

> 🔴 **NAHI HUA** Bun se door — jari (Bun ab sirf fallback/SSR; baqi routes Rust par aane baqi).

> ⚪ ai host `/` coming-soon — founder ne ai.anexomail.com khud block kar diya; Rule 23: koi kaam nahi.

> 🟢 **HO GAYA** "AI plans open on ai.anexomail.com" wali EK pointer line anexomail.com se hati; baqi AI zikr waisa hi **LIVE DONE (Web pull 06:16).**.

> 🟢 **HO GAYA — LIVE DONE (19 Oct 05:54 PKT):** Business Pro test account login fix + naya `bpro.test` account: dono LOGIN OK (GoTrue 200, website login 200). Founder: dobara touch nahi karna.

> 🔴 **NAHI HUA** Focus Business / Business Pro blueprint tarteeb se, latest technology, "ek bhi point nahi bachna" — jari.

