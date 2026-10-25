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
