# PACKAGES PRICING v6 — flat per-month + Enterprise (FOUNDER LOCKED 25 Oct 2026)

> **UPDATE 26 Oct 2026 05:07 PKT (founder, 'sab kuch sochne ke baad'): ENTERPRISE = £18,500 / month** (pehle £15,000). Yearly (CEO x10 proposal) £185,000. Enterprise ko Business Pro ke BAAD alag banaya jayega -- yeh poori website ka chehra hoga, isliye price zyada. Enterprise abhi zero: koi gate/code nahi, advanced technology par, bug nahi chalega. Repo mein jahan jahan Enterprise price tha update kiya.


Source: founder verbatim 25 Oct 2026 21:30 UTC (26 Oct 02:30 PKT) — `docs/cursor-work/founder/founder-commands.md`.
> **UPDATE 26 Oct 2026 03:09 PKT (founder, verbatim):** "bussiness pro email attachment limit hai 60MB aur 100MB enterprise walon ke liye." Business Pro ka File Transfer Limit **100 MB se 60 MB** final-confirmed (neeche ki table/bullets isi update ke mutabiq). Enterprise 100 MB wohi rehta hai — ab yeh unko alag karne wala ek aur dimension hai (pehle sirf user-cap + storage farq karta tha).

Status: **READY (docs)** — code (`src/lib/plans.ts`, `server/config/billing-products.ts`) aur Polar abhi v5 prices par hain; founder ne kaha codes woh khud karenge. Polar products banne + IDs aane tak yeh pricing READY hai, DONE nahi (Rule 5).

## Naya rule (v6)

- Har package **per-month flat** hai — per-user pricing KHATAM. Seats package ke saath included hain.
- Yeh pricing v5 (£23/£46/£97) ki jagah le rahi hai. Personal tiers (£17/£83/£1,850) is change mein NAHI aaye — woh alag cheez hai, badli nahi.
- Yearly numbers abhi founder ne NAHI diye — sirf monthly final. Yearly toggle ko chhedna mana hai jab tak founder naye yearly numbers de.

## Master table (founder-confirmed final numbers)

| Plan Name | Monthly | User/Mailbox Cap | Strict Shared Storage (Pool) | Effective Per-User | File Transfer Limit (instant email attachment) |
|---|---|---|---|---|---|
| Basic Flat | £40 | Up to 5 users | 15 GB shared, 3 mailboxes (founder 26 Oct 05:45: 25GB galat tha) | £8.00 / user | 25 MB |
| Pro Package | £105 | Up to 20 users | 300 GB (15 GB per user × 20) | £5.25 / user | 35 MB |
| Business Flat | £360 | Up to 60 users | 1,500 GB = 1.5 TB (25 GB per user × 60 — backend pool) | £6.00 / user | 45 MB |
| Business Pro | £2,850 | Up to 570 users | 10 TB | £5.00 / user | **60 MB** |
| **Enterprise (NAYA)** | **£18,500** | **Unlimited users** | **15 TB shared (logical)** | n/a (unlimited → per-user sab se sasta) | **100 MB** |

Founder ne confirm kiya (table vs bullets ke farq): Basic **25 GB**, Pro **300 GB**, Business transfer **45 MB**, Business Pro **10 TB** (taake Enterprise ke 15 TB se alag rahe).

## Per-package detail

### Basic Flat — £40 / month
- User/Mailbox Cap: **up to 5 users max**
- Logical Storage: **15 GB shared, 3 mailboxes** (founder correction 26 Oct 05:45 -- pehle 25 GB likha tha)
- File Transfer Limit: **25 MB** instant email attachment
- Effective per-user: £8.00

### Pro Package — £105 / month
- User/Mailbox Cap: **up to 20 users max**
- Logical Storage: **300 GB** (15 GB per user × 20)
- File Transfer Limit: **35 MB** instant email attachment
- Effective per-user: £5.25

### Business Flat — £360 / month
- User/Mailbox Cap: **up to 60 users max**
- Logical Storage: **1.5 TB** (25 GB per user × 60 = 1,500 GB — **backend par pooled storage pool** ke taur par aayega)
- File Transfer Limit: **45 MB** instant email attachment
- Effective per-user: £6.00

### Business Pro — £2,850 / month
- User/Mailbox Cap: **up to 570 users max**
- Logical Storage: **10 TB shared** pool
- File Transfer Limit: **60 MB** instant email attachment
- Effective per-user: £5.00

### Enterprise — £18,500 / month (NAYA)
- User/Mailbox Cap: **Unlimited users**
- Logical Storage: **15 TB shared (logical)** pool
- File Transfer Limit: **100 MB** instant email attachment
- Enterprise = Business Pro ka poora power **+ unlimited seats + 5 TB extra storage**. Koi 570 ki cap nahi — jitne chaho users/mailboxes.

## Business Pro vs Enterprise — sab se bara kya farq

**Sab se bara farq: user cap.**
- **Business Pro: maximum 570 users.** Uske baad company ko Enterprise lena parta hai.
- **Enterprise: UNLIMITED users** — koi cap nahi, jitni bhi company barhe.

Doosra farq: storage — Business Pro **10 TB**, Enterprise **15 TB** (+5 TB).
**Ab yeh bhi farq hai:** attachment limit Business Pro **60 MB**, Enterprise **100 MB** (pehle dono 100 MB the, 26 Oct update ke baad alag). Price 6.32× (£2,850 → £18,500) ka matlab: Enterprise company jitni bhi barhe, per-user kharcha nammumkin had tak neeche jaata hai (Business Pro 570 par ~£5.00/user; Enterprise par unlimited seats).

## Feature gating — kya badla, kya nahi

- **Prices/seats/storage/transfer limit naye v6 numbers** (upar wali table).
- **Features ki gating wahi purani locked formula rahegi** (`PACKAGE-FEATURE-FORMULA.md` RULE 4): Basic = mail/people/calendar; Pro+ = chat/CRM; Org = business tiers; AI hamesha ai.anexomail.com (Enterprise mein bhi workspace plans par AI ZERO — AI alag AI plans ka hissa hai, jab tak founder Enterprise mein AI shamil karne ka hukm na de).
- **Naya dimension — file transfer limit (RULE 4A):** 25 MB → Basic · 35 MB → Pro · 45 MB → Business · **60 MB → Business Pro** · 100 MB → Enterprise. Backend enforcement founder ke "codes update" ke hukm par banegi.

## Polar mein kaise update hoga (founder khud karega)

1. **Polar dashboard → Products → har package ka NAYA product banao.** Purane product ki price dashboard se badalna sahi tareeqa nahi — purane checkout links purana price dikhate hain; isliye naya product banao, purana baad mein Archive karo.
   - Recurring monthly: Basic **£40** · Pro **£105** · Business **£360** · Business Pro **£2,850** · Enterprise **£18,500**.
   - Har product ke metadata mein: `brand=anexomail`, `kind=plan`, `plan=<basic|pro|business|business_pro|enterprise>`, `cycle=monthly`, `account_kind=business`.
   - Enterprise ka plan identifier repo/backend ke liye **`enterprise`** hoga (naya tier — 5th tier, backend/SQL/Rust mein alag qadam, founder ke hukm par).
2. **Har naye product ki Product ID (UUID) copy karo.**
3. IDs chat mein bhejo — main repo ki `server/config/billing-products.ts` + server `.env` keys (`POLAR_PRODUCT_*`) + tests ki wiring ka poora block bana dunga. (Founder ne kaha codes woh khud karenge — wiring sirf unke hukm par.)
4. **Server `.env` mein** har product ka env key set hota hai; Rust Polar engine (:3400) `POLAR_PRODUCT_*` auto-discover karta hai — restart ke baad checkout naye products par jayega.
5. **Webhook nahi banana dobara:** Polar webhook already wired hai (HMAC → :3400 → instant 200). Naye products ke events usi webhook par aayenge.
6. Purane Basic/Pro/Business checkout naye par jaane se PEHLE naye products ka **live checkout test** karo (ek chhota order), phir purane products Archive.
7. Yearly: founder abhi sirf monthly de — yearly products is round mein nahi banane, jab tak naye yearly numbers na aayen.

## Status

- Docs: **DONE** (yeh file + `PACKAGE-FEATURE-FORMULA.md` v6 section + `founder-commands.md`).
- Code (plans.ts, billing-products.ts, plan-surface.ts, SQL, transfer-limit enforcement): **BAQI — founder ke hukm par** (unhone kaha codes woh khud karenge).
- Polar products + IDs: **BAQI — founder khud banayenge**; IDs aane ke baad wiring ke qadam.
