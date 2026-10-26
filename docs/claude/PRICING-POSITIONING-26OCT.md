> **SUPERSEDED (26 Oct 02:50 PKT):** attachment numbers neeche is file mein (30/35/45/50 MB) founder ke is baat-chait se PEHLE ki guess thi. Asli locked numbers ab `docs/cursor-work/founder/packages-pricing-v6-2026-10-25.md` mein hain (File Transfer Limit column): **Basic 25 MB · Pro 35 MB · Business 45 MB · Business Pro 60 MB · Enterprise 100 MB** (Business Pro 60 MB final-confirmed by founder 26 Oct 03:09 PKT — not the v6 file's original 100 MB; `packages-pricing-v6-2026-10-25.md` ka Business Pro column is se update hona chahiye). Is file ke baqi sections (per-user-nahi rule, positioning strategy, CRDT/Hybrid-Attachment CEO flags) abhi bhi valid hain — sirf MB numbers v6 se replace karo.

# Pricing + positioning — locked decisions (founder, 26 Oct 2026, STRICT)

Yeh decisions founder ne chat mein diye (sirf baat chait, code nahi). Jab founder "ab likho" bole tabhi implement hoga. Ab se compact ke baad bhi yeh file pehle padhi jaye.

## 1. NO PER-USER PRICING — EVER (founder verbatim, 26 Oct 02:32 PKT)
"ab se koi bhi package per user nahi hoga. shared mailboxes memory dun ga user ko aur competitors per user kerte hain hum per user nahi karay gay."
- **Rule:** koi plan (Basic/Pro/Business/Business Pro/naya Enterprise) seat/per-user charge nahi karta. Zoho Workplace, Google Workspace, Microsoft 365 — sab per-seat hain; yehi humara sabse bada differentiator hai.
- **Shared mailbox / memory:** plan ek workspace ko utni mailbox-memory deta hai, jitne bhi log org mein hon — team barhne par price nahi badalta sirf is wajah se ke ek naya banda add hua. (Exact GB/mailbox-count per plan abhi decide nahi hua — agla faisla.)
- Is rule ka code impact: `resolve_plan` / org-level entitlement se hi member count ANY WAY price ko touch na kare — jab implement honge tab yeh ek checklist item hai (koi per-seat billing hook kahin na ho).

## 2. Naya package: ENTERPRISE (founder verbatim)
"ek naya package bhi introduce hoga jis ka naam hoga enterprise"
- Business Pro ke upar ek naya tier: **Enterprise**. Scope, price, limits abhi TODO — founder decide karega.
- Jab banega: resolve_plan ke sab account-kind rule (basic/pro/business/business_pro/personal/basic_personal/family) ki tarah Enterprise bhi usi ek code path se, koi alag copy nahi (AGENTS.md ka base rule).

## 3. Attachment limits — exact numbers (founder ne diye, 24-26 Oct)
| Plan | Limit |
|---|---|
| Basic | 30 MB |
| Pro | 35 MB |
| Business | 45 MB |
| Business Pro | 50 MB |
| Enterprise | TODO (naya package decide hone ke baad) |

- **Seedha attach, cloud-link trick nahi.** Zoho ka seedha limit effectively ~40 MB tak hai (Mail Premium), uske aage "Huge Attachment" link-based hota hai — hum 50 MB tak **direct** attach dete hain, wahi selling point hai.
- Gmail: 25 MB bhejne ka seedha limit (kuch provider-pairs mein receive 50 MB tak dikh sakta hai, par yeh hamara seedha compare-point nahi).
- **Loophole mila (fix abhi baqi):** repo ke `src/routes/plans.tsx` mein comparison table abhi purane numbers dikhata hai ("25 MB, 25 MB, 5 GB" — Basic/Pro/Business ke against), jo naye 30/35/45/50 se match nahi karta. Jab implement hoga, yeh teeno jagah ek saath update honi hain:
  1. Landing page pricing cards + comparison table (`plans.tsx` aur jahan bhi "attachment" likha hai)
  2. Profile/Billing page ka plan summary
  3. Composer ka asli enforce (`mail.attach.limits` Rust proc) — number sach hona chahiye, sirf marketing nahi.
- Enforcement Rust mein honi chahiye (quota check), taake jo number landing page par likha hai wahi server bhi lagu kare — ek jagah ka number doosri jagah se mismatch na ho.

## 4. Landing/positioning copy strategy (CEO-level, founder ne "user mindset" mangwaya)
Core insight: "Rust + Tokio" akele ek engineering flex hai, sale nahi karta. Awam engineering paragraph nahi padhti — unko teen seedhe sawaalon ka jawab chahiye jab wo email provider badalte hain:
1. **"Mera bada attachment seedha jayega ya nahi?"** → attachment limit number (upar), "no cloud-link trick" ka seedha jawab.
2. **"Mera mail slow to nahi hoga jab bohot log use karen?"** → Tokio ka work-stealing/concurrency point ka translation: "peak hours mein bhi fast".
3. **"Agar kuch crash ho to mera poora account nahi gira?"** → Tokio ke isolated-task crash-containment ka translation: "ek masla, poori website nahi girti".

Branding word jaisa "Rust Beast Mode" rakha ja sakta hai, lekin har jagah uske neeche ek plain-language line honi chahiye jo user-benefit bataye, jargon nahi.

Zoho/Gmail dono ka selling point "safe, established" hai. Humara counter: "hum tumhein wo cheez dete hain jo Gmail/Zoho tumse chura rahe hain" — per-user pricing na hona, seedha bada attachment, aur latest-technology reliability (user-benefit zubaan mein) teen alag counters hain.

## 5. Tarteeb (founder: "ajj humne in cheezon ko theek kerna hai phir hum pro ko green karay gay")
1. (Is baat-chait ke baad) founder exact numbers/wording confirm kare → phir implement: attachment limits (3 jagah + Rust enforce) + per-user-pricing audit (koi seat-based hook na ho) + Enterprise package scaffolding.
2. Phir Pro GREEN: shared-inbox collision guard dobara live-verify (owner-name fix ke saath), `basic-gate-probe.sh` ka output, M2b/M3-M5 baqi migration.
3. Phir Business, Business Pro, phir Enterprise launch.
4. Founder account sabse aakhir mein (ab bhi locked rule).

## Server status check (26 Oct, is session mein)
M2 + M2b ka deploy abhi tak Nauman bhai ne confirm nahi kiya (last known commits: `11d7b94`, `6d4fe33`). Deploy ke baad handoff + owner-name ka live Chrome test aur basic-gate-probe ka output abhi baqi hai.

---

## 6. Founder ke 2 naye ideas (26 Oct 02:37 PKT) — note kiye, CEO review ke saath

### (A) CRDTs + WebTransport sub-10ms document collaboration
Founder: Rust kernel ke andar CRDTs (Conflict-free Replicated Data Types) implement karo, WebTransport/HTTP3 ki wajah se doc-collaboration latency Google se bhi kam (sub-10ms) ho sakti hai.
- **Tech sahi hai:** CRDTs + Rust + WebTransport ka combo real-time collaborative editing (jaise Google Docs) ke liye sahi hai, aur hamara stack (tokio, wtransport/QUIC) isko support kar sakta hai.
- **CEO flag (founder se confirm chahiye):** Abhi ANEXOMAIL mein koi "collaborative document editing" feature hi nahi hai (Google Docs jaisa shared-doc ya shared-note jahan 2 log ek saath type karein). Hamare paas Work/CRM/Calendar/Mail hai. Yeh ek **naya product surface** hoga — scope bada hai (naya data model, naya UI, naya Rust module). Sawal founder se: (1) yeh kis feature ke andar aayega — naya "Docs"/"Notes" tool, ya Work ke boards/notes ko hi collaborative banana hai? (2) "sub-10ms" ka number abhi sirf theory hai — jab tak build+measure nahi hota, marketing mein latency number claim nahi karna chahiye (jhooti green rule — DONE sirf live measured par). Scope + priority (kaunse phase mein, M-series ke kis number par) founder ka faisla.

### (B) Hybrid Attachment Engine — bari file ke liye storage + secure download link
Founder: jab user badi file (50MB/500MB/1GB) attach kare, backend Hetzner storage mein save kare, email ke andar ek "Secure ANEXO Download Link" bheje (SMTP ki size-limit se bachne ke liye). Smart Attachment Split: 25MB se badi file par khud-ba-khud link-based delivery, taake doosre provider (Gmail/Outlook, jin ki apni limit ~25MB hai) reject na karein; Enterprise tak 100MB tak smoothly bhej sake.
- **Tech-wajah sahi hai (yeh email ka physics hai, hamari marzi nahi):** koi bhi bada attachment jab doosre provider (Gmail ki 25MB, Outlook ki apni limit) ko jata hai, agar hum seedha SMTP attach karen to woh bounce/reject hoga chaahe hum kuch bhi karein — yeh unke server ki limit hai, hamari nahi. Is liye bari file ke liye link-based delivery zaroori hai agar cross-provider bhejni hai.
- **CEO flag — yeh pichli positioning se SEEDHA TAKRAATA hai, founder faisla chahiye:** 25 Oct ki baat mein humne Zoho ke "Huge Attachment" (cloud-link) tareeqe ko weakness bataya tha ("Zoho ka seedha limit 40MB tak, uske aage link-trick") aur apna selling point "seedha 50MB tak direct attach, link-drama nahi" rakha tha. Ab yeh naya idea kehta hai ke 25MB se upar hum khud link bhejenge — yani hum bhi wahi tareeqa karenge jo humne Zoho ki kamzori bataya tha. Do tareeqon mein reconcile karne ka ek raasta hai, lekin faisla founder ka hai:
  - **Option 1 — "seedha" sirf apne provider ke andar:** ANEXOMAIL-se-ANEXOMAIL (ya kisi aisi receiving party jiska server bari file accept karta ho) seedha attach; doosre provider (Gmail/Outlook jinki apni 25MB limit hai) ko bhejte waqt automatically link — aur UI mein yeh saaf bataya jaye "aapki file Gmail ki size-limit ki wajah se secure link ke zariye bheji gayi" (transparent, sharmindagi wali baat nahi — email ka universal usool hai).
  - **Option 2 — hamesha link for anything over X MB**, chahe recipient koi bhi ho, taake experience consistent rahe aur hum "always-fast, always-reliable" bol saken.
  - Landing-page wording iske mutabiq badalni hogi: "50MB tak direct attach (apne network ke andar), aur bade file ke liye hamara apna secure ANEXO link — Zoho ke cloud-trick jaisa complicated nahi, 1-click download, hamesha encrypted."
- Dono ideas abhi **sirf decide/likhe hain, implement NAHI hue.** Jab founder in do sawalon (scope ka doc-collab, aur Option 1 vs 2) ka jawab de, phir phases (M-series mein kahan fit honge) aur code likhna shuru hoga.

---

## 7. FINAL CONFIRMED (founder 26 Oct 03:05 PKT, verbatim "yeh 100% sahi hai yeh mera hukam hai") + ek contradiction jo founder se confirm karna hai

### Plan table — FINAL (per-month flat, per-user KABHI nahi, world isse ulta karta hai)
| Plan | Monthly | User/Mailbox cap | Shared storage | 
|---|---|---|---|
| Basic | £40 | up to 5 | 15 GB shared, 3 mailboxes (founder 05:45 correction) |
| Pro | £105 | up to 20 | 300 GB |
| Business | £360 | up to 60 | 1.5 TB |
| Business Pro | £2,850 | up to 570 | 10 TB |
| Enterprise | £18,000 | **Unlimited** (bandwidth-cap ke saath, neeche dekhein) | 15 TB |

### Attachment limits — FINAL CONFIRMED (founder 26 Oct 03:09 PKT, verbatim "bussiness pro email attachment limit hai 60MB aur 100MB enterprise walon ke liye")
| Plan | Attachment |
|---|---|
| Basic | 25 MB |
| Pro | 35 MB |
| Business | 45 MB |
| Business Pro | **60 MB** |
| Enterprise | **100 MB** |

### Bandwidth cap (naya rule) — "Unlimited Users" ka matlab "unlimited bandwidth" nahi
Founder: "Unlimited Users ka asloob theek hai, lekin code mein limit lagayein ke agar koi company 100TB ya 200TB data transfer se upar jaye, to us par extra charges lagein, warna data vendors yeh bhi likho."
- Enterprise "unlimited users" hai, lekin **bandwidth/data-transfer par cap honi chahiye** (threshold abhi TODO — 100TB ya 200TB, founder exact number confirm karega) — us se upar extra charge, automatic block nahi.
- "warna data vendors yeh bhi likho" — matlab: agar hum khud yeh cap enforce nahi karte, to humare upstream bandwidth providers (Hetzner) khud bill karenge, is liye apna cap pehle se likhna zaroori hai taake surprise bill na aaye. Implementation: Rust mein per-org monthly egress counter + threshold alert + billing hook — jab enforcement banegi.

### CRDT doc-collaboration — kis package ko milegi (CEO faisla, founder ne delegate kiya)
Founder: "yeh technology bhi add hogi lekin practical tareeke se kis package ko mile gi yeh decide hoga... tum CEO ho toh decide kero gay."
**CEO faisla (confirm karne ke liye):** CRDT collaborative docs/notes **Business, Business Pro aur Enterprise** ko milay (team/org collaboration feature hai, Basic/Pro single-operator jaisi zyada hoti hain). Business ko **basic collaboration** (2-5 simultaneous editors), Business Pro/Enterprise ko **full** (unlimited editors, version history, presence). Founder chahe to badal sakte hain.

### Hybrid Attachment Engine — package ke hisaab se
Founder: "yeh bhi technology link send karne wala bhi hoga, hum package ke hisaab se features dein ge."
**CEO faisla (confirm karne ke liye):** har package apni "instant attachment" limit (25/35/45/60/100 MB — FINAL) tak seedha attach karta hai; us se upar **har package ko secure-link delivery milti hai**, lekin max link-file-size package ke hisaab se: Basic 1 GB, Pro 5 GB, Business 20 GB, Business Pro/Enterprise 100 GB (storage quota ke andar). Doosre provider (Gmail/Outlook) ko bhejte waqt unki apni limit se upar hamesha link (chahe hamara instant-limit zyada ho) — "Option 1" (per-recipient) jeet gaya is logic mein, kyunke doosre provider ki limit hum nahi badal sakte.

### WASM kernel — standing rule (founder, naya qaida)
"Yeh mind main lock ker lo ke yeh WASM KERNEL browser main builtin hogay, yeh version update hote rahay gay, yeh rule hai feature ke saath."
→ Dekho AGENTS.md Rule 52.

---

## 8. 26 Oct 03:15 PKT — teen faisle (founder jawab + CEO suggestion)

### (a) Bandwidth/data-transfer overage — CEO price suggestion (founder ne khud mangwaya)
Founder: threshold **50 TB/month** (Enterprise org-level, "per user" nahi — unlimited-users plan mein per-user bandwidth cap ka koi matlab nahi, is liye yeh poori org ka monthly transfer-threshold hai). Polar/Rust payment + database mein har jagah likha jayega, **landing page par NAHI** — yeh hidden/backend charge hai, sirf bill mein dikhega jab system khud calculate kar ke user ko bhejta hai.
**CEO suggestion (price):** **£10 per extra TB, 50 TB/month ke baad** (Enterprise par). Wajah: Hetzner par raw bandwidth ki lagat bohot kam hai (dedicated/cloud par roughly €1/TB ke aas-paas, kabhi included bhi hota hai) — AWS jaisi cloud ki ~$90/TB egress ke muqable mein £10/TB hamare liye bohot healthy margin hai aur phir bhi customer ke liye bohot sasta aur predictable rehta hai. Billing granularity: monthly cycle ke end par actual usage - 50TB = overage_tb, round up to nearest TB, £10 × overage_tb bill mein line-item ("Data transfer overage"). **Founder confirm kare price.**

### (b) CRDT collaborative docs — LOCKED
Founder confirm kiya: **Business, Business Pro, Enterprise** — CEO suggestion ke mutabiq hi. (Basic/Pro ko nahi.)

### (c) Bara file bhejna — DO ALAG cheezein hain, confuse na ho

**Email attachment (instant, SMTP ke andar) — already locked:** 25 / 35 / 45 / 60 / 100 MB (Basic/Pro/Business/Business Pro/Enterprise).

**ANEXOChat ka apna bara-file-bhejna feature (alag, chat ke andar, email nahi) — FINAL (founder 26 Oct 03:34-03:42 PKT, section 9 dekho):**
| Plan | Max file (ANEXOChat send) |
|---|---|
| Basic / Pro (business) | **ANEXOChat NAHI** (founder: "main anexochat basic aur pro main offer nahi kerta") — purani CEO proposal 500MB/1GB VOID |
| Business | **2 GB** |
| Business Pro | **5 GB** |
| Enterprise | **7 GB** |
| Personal Basic | NAHI (wall) |
| Personal PRO+ | **2 GB** |
| Personal Premium | **4 GB** |

Yeh ANEXOChat ki apni storage/transfer pipeline hai (naya naya likha jayega), email attachment limit se bilkul alag cheez hai — koi confuse na kare.

**Hybrid Attachment Engine (>limit par EMAIL ke andar secure download-link) — yeh teesri, abhi tak khuli cheez hai, confirm baqi:** jab koi EMAIL attachment apni instant-limit (25/35/45/60/100 MB) se bari ho, uska max link-based size kya ho? CEO proposal (06. mein diya) abhi bhi khula hai: Basic 1GB / Pro 5GB / Business 20GB / Business Pro-Enterprise 100GB. **Founder confirm kare ya apne numbers de — yeh (c) ke ANEXOChat wale table se ALAG hai (email vs chat).**


## 9. 26 Oct 03:34-03:42 PKT — founder faisle: ANEXOChat dono axes, bandwidth overage sab packages, AI repricing

### (a) ANEXOChat gating — dono axes ALAG aur DONO real
- **Business ladder:** Basic NAHI, Pro NAHI, Business 2GB, Business Pro 5GB, Enterprise 7GB.
- **Personal ladder:** Personal Basic NAHI, Personal PRO+ 2GB, Personal Premium 4GB.
(Mera pehle ka "business pe chat bilkul nahi" samajhna GALAT tha — founder ne correct kiya.)

### (b) Bandwidth/data-transfer overage — Enterprise-only NAHI, har package ka apna (founder: "business, business pro sab ko hoga un ke package ke hisab se")
Mechanism sab ke liye same: org-level monthly transfer, database + Polar + Rust billing mein likha, landing page par KABHI nahi, bill mein backend-calculated line-item "Data transfer overage", usage upar ke TB round-up.
**CEO decision (founder ne delegate kiya: "jo zoho/google/hetzner se better ho, profitable bhi, user happy bhi") — veto founder ka:**
| Plan | Included transfer / month | Overage |
|---|---|---|
| Business | 10 TB | **£12 / extra TB** |
| Business Pro | 30 TB | **£11 / extra TB** |
| Enterprise | 50 TB | **£10 / extra TB** |
| Basic / Pro | founder ne nahi kaha -- koi overage charge nahi, sirf fair-use (abuse par throttle). Chahein to add kar dein |
Logic: Hetzner raw ~EUR 1/TB (kabhi included bhi) -> hamara margin ~8-10x; bara plan = zyada included TB + thora sasta rate (loyalty). Competitors VERIFIED (26 Oct 03:50 PKT, official pages): Zoho rates-and-limits page par koi bandwidth/data-transfer overage fee nahi (sirf fetch/rate limits, jaise POP 5GB/din, incoming attachment 40MB); Google Workspace ke official size-limits page par bhi koi per-TB overage fee nahi mili (bandwidth ke alag limits pages hain -- woh limit-throttle model hai, paid overage nahi; Gmail attachment 25MB, sirf Enterprise Plus 50MB Feb 2026 se). Caveat: yeh 'official page mein zikr nahi' wala saboot hai, har contract/edition ka har clause nahi dekha -- pakka legal claim landing par mat likhna -- hamara fixed, pehle se known, sasta overage bill-shock se bachata hai aur Hetzner cost ke upar profit deta hai.

### (c) AI product (ai.anexomail.com) — NAYI qeematein (founder verbatim list)
| Plan | Purani monthly | **NAYI monthly** | Yearly (CEO fix: purani convention 10x monthly) | Credits/mo |
|---|---|---|---|---|
| AI Pro | £400 | **£2,000** | £20,000 | 1,200 (unchanged abhi) |
| AI Business | £1,500 | **£5,000** | £50,000 | 5,000 (unchanged abhi) |
| AI Executive | £4,000 | **£25,000** | £250,000 | 10,000 (unchanged abhi) |
AI ek ALAG product hai; workspace plans (Enterprise samet) ko AI ZERO (Rule 23). `src/lib/ai-packages.ts` + Polar products abhi NAHI badle (no-code rule + Polar founder khud karta hai) -- sirf docs.
**CEO flags (founder faisla kare):**
1. Credits/top-up inversion: AI Pro £2,000/1,200cr = £1.67/credit, Executive £25,000/10,000cr = £2.50/credit, lekin top-up packs £0.22-0.40/credit hain -- top-up plan se SASTA ho gaya. Ya credits barhao (plan ke saath), ya top-up repricing, warna koi plan nahi khareedega.
2. "AI plan = base platform included" logic ladder: AI Pro (£2,000) = Business platform (£360), AI Business (£5,000) = Business Pro platform (£2,850), AI Executive (£25,000) = Enterprise platform (£18,000) -- CEO proposal, founder confirm kare.
3. Kya pehli chizen jo landing/ai.anexomail.com copy mein purani £400/£1,500/£4,000 likhi hain unhein badalna hai (founder ke hukm par).
