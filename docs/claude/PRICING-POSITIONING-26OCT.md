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
