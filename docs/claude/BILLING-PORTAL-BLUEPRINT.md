# BILLING PORTAL — `billingportal.anexomail.com` (blueprint + phases). Founder hukm 21 Oct 2026 23:50 PKT
> Founder: "Yeh bhi backend latest technology pe hoga, page bhi; meri features list add hogi; blueprint tarteeb se likho, phases likho, phir implement shuru. Namecheap par A record `billingportal.anexomail.com` add kar diya."
> Locked rules jo is portal par bhi lagte hain: **Polar payments/prices/landing NO TOUCH · Caddy kahin nahi jata · user ki privacy (metadata-only, mail content kabhi nahi) · Polar engine = source of truth · "block kabhi nahi, grace 3 din" · "One flat price, no usage meter" · package badalna = naye ka poora price, purane ka credit/refund nahi (`/billing-policy`)**.

## 0. Vision (aasaan lafzon mein)
Customer ko lage ke yeh *aap ka apna* billing center hai: tez, khoobsurat, mobile-first, asli "A" logo. Polar sirf piche payment karta hai. **Card number ka form Polar ki taraf hi** (PCI) — baqi sab hamara.

## 1. Founder ki list + CEO ka faisla (sach pehle — kuch cheezein sahi design chahti hain, warna nuqsan)
| # | Founder idea | Faisla | Asal design |
|---|---|---|---|
| 1 | 3D cube/mesh plan card (Three.js+OffscreenCanvas) | **HAAN, progressive** | Lazy-load, mobile par halka; static SVG fallback + `prefers-reduced-motion`; INP<150 ms budget. Seats/tier/storage "fluid containers" |
| 2 | "Predictive overhead" 10x usage pricing simulator | **BADAL KE HAAN** | Hamara wada "flat price, no usage meter" — usage se price badalti hi nahi. Isliye simulator = **what-if calculator**: seats ×N / storage / yearly vs monthly => saaf total. "Asymmetric load" nahi |
| 3 | Web Worker se invoice PDF banana | **ADHA** | Legal VAT invoice **Polar ka** hai (merchant of record) — uska PDF link/proxy. Hamara bana PDF = "statement/receipt copy" (tax invoice nahi) |
| 4 | ZKP invoice verifier | **HAAN, asli naam se** | Asli zero-knowledge proof nahi chahiye. **Verifiable receipt**: SHA-256 + Ed25519 signature + hash-chain position; auditor `verify` page par proof check kare |
| 5 | Cancel par "downsell 50% discount" | **ruko — founder ijazat** | Prices locked. Discount = Polar discount code, sirf founder ke likhit hukm par. v1: cancel ka saaf end-date + resume + (agar chahen) downgrade ka rasta. Hours-saved metadata-only se compute ho sakte hain |
| 6 | Polar window "inject" (overlay/iframe) | **REDIRECT + glass transition** | Polar page iframe mein nahi khulta (X-Frame/CSP) aur PCI bhi nahi chahta. Framer Motion glass transition → seedha Polar secure session (full navigation) |
| 7 | Atomic no-state-leak router | **HAAN** | Entitlement switch ek atomic DB call (`billing_apply_entitlement`, pehle se) + token/auth cache invalidate. "Lock jab tak Polar update na kare" NAHI — wahan user payment ke beech phans sakta hai. Intent-pehle design (pehle se) rehta hai |
| 8 | Chaos-Grace: payment fail par SMTP **421 drops inject** | **NAHI KARUNGA (founder se baat)** | Customer ki mail ko yarghmaal banana = trust/deliverability/qanooni khatra + hamara locked rule "grace 3 din, block kabhi nahi" aur privacy wada. **Badal:** live countdown banner → grace ke baad **read-only + sending pause (inbound HAMESHA accept, data kabhi nahi mitta)** → payment par foran restore. Founder final faisla de |
| 9 | Hash-chain ledger | **HAAN** | Append-only `billing_ledger` (prev_hash→hash), har event; roz chain verify job |
| 10 | HSM + multi-sig + "absolute self-lockout" | **BADAL KE** | Hetzner par HSM nahi. Ed25519 signing key alag process/file 600 + passkey step-up + founder multi-approve. Mismatch par **billing mutations freeze + alarm** (customer ka mail/lockout NAHI — warna ek DB galti = sab ka nuqsan) |
| 11 | Hot-swap seats, Tokio microsecond | **HAAN** | Seat badalna = entitlement row + cache invalidate, process reload nahi; proof: queue/latency test |
| 12 | Finance role "zero-knowledge" | **HAAN (capability isolation)** | Role `billing_admin`: token mein sirf `billing.*` scopes; mail/people/calendar procs 403. Test: har non-billing proc 403 |
| 13 | WASM 100k req/min telemetry canvas | **CHHOTA** | Billing telemetry chhoti hai (seats, storage, invoices). WASM tab jab zaroorat ho (chart parse); pehle plain Web Worker + OffscreenCanvas |
| 14 | SSE live state | **HAAN** | Polar webhook → engine WAL → inbox → trigger; Rust SSE (`/sse/billing`) push; UI GSAP/Motion se smooth update, loading flash nahi |
| 15 | Zero-bundle l10n + Speculation Rules | **HAAN** | Pehle se `locale.bundle` rpc (28 zubanen); portal ko bundle mein nahi; hover par prefetch |
| 16 | PWA + offline cached ledger | **HAAN** | Service worker + IndexedDB (sirf non-sensitive summary, encrypted-at-rest nahi mumkin => paise ke amounts/invoice numbers hi, card kuch nahi) |

## 2. Architecture
- **Host:** `billingportal.anexomail.com` (DNS A record ho chuka). Caddy **additive** site block (`/etc/caddy/sites/billingportal.caddy`): static SPA (`file_server`, immutable assets, SPA fallback) + `/rpc/*`→Rust:3200 + `/sse/*`→Rust. Caddy khud rehta hai; HTTP/3 + auto TLS.
- **Frontend:** alag chhoti app `portal/` (React 19 + Vite + TanStack Router + Tailwind 4 + Radix + Motion/GSAP; Three.js lazy). Main app ka BrandMark/BootSplash/i18n/rpc reuse (shared `@/` alias, NO DUPLICATE). Build static, kisi Node/Bun runtime ke baghair serve.
- **Auth:** ek hi login (Supabase JWT). Shared-session handoff: `anexomail.com` se "Open billing center" ek-dafa-wala 60 s ticket (Rust `portal.ticket`) → portal par token exchange; passkey step-up bade kaamon par. (Cookie `.anexomail.com` shared option founder decide.)
- **Backend:** Rust `portal.*` procs (anexomail-rust) → Polar engine (muhar-band, B6a) → Polar. Data Supabase mirrors (`get_billing_subscription`, `get_billing_invoices`). Nayi SQL: `billing_ledger` (append-only hash chain), `billing_roles`; **har naye table mein explicit GRANT** (30 Oct Supabase rule).
- **Security:** CSP strict, no card data kabhi, rate limits, muhar-band engine, kill-switch files, audit chain, step-up passkey for cancel/seat/role changes.

## 3. PHASES (har phase: sandbox proof + 390/820/1440 asli Chromium screenshots + founder server output → GREEN)
- **P0** Blueprint + faisle (yeh doc) ✔ ; founder decisions: #5 discount, #8 grace behaviour, auth cookie vs ticket, finance role v1 ya baad.
- **P1 Foundation (isi raat shuru):** DNS check, `caddy-billingportal.sh` (plan/apply, rollback), branded placeholder (asli A boot), `portal/` skeleton + build, health. Koi billing data nahi.
- **P2 Core read:** `portal.summary` / `portal.invoices` (Rust, proof), plan card (static+3D lazy), invoices list + Polar PDF link, policy block, Polar handshake (glass transition → portal.url via B6a `billing.portal`), payment-failed banner + grace countdown (read-only).
- **P3 Actions + ledger:** cancel/resume (end-date), step-up passkey, `billing_ledger` hash chain + verify job + verifiable receipt page, audit log UI.
- **P4 Realtime:** Rust SSE, webhook→push (<40 ms target in sandbox), GSAP state morph, offline ledger (PWA/IndexedDB).
- **P5 Seats + roles:** seat slider (what-if), hot-swap seats, `billing_admin` role + 403 matrix tests, invite finance user.
- **P6 Insight:** what-if calculator, meters, spend chart (Worker+OffscreenCanvas), WASM only if measured need; renewal reminder emails (logo header).
- **P7 Grace/dunning engine:** countdown, read-only mode switch (inbound never dropped), restore on payment — founder ke #8 faisle ke mutabiq.
- **P8 Hardening:** load test, chain-mismatch freeze drill, a11y, 28 languages sweep, Lighthouse (LCP<1.8 s, INP<150 ms), GREEN.

## 4. Performance budget (matrix)
3D canvas INP<150 ms · hash compute <5 ms · role check <10 ms · LCP<1.8 s · SSE state sync <40 ms (sandbox measure, server par re-measure). Sandbox honest hadd: asli Polar jawab/asli network sandbox mein nahi.

## FOUNDER SPEC 22 Oct 2026 23:34 — GRACE PERIOD + WORKSPACE PAUSE (billing portal mein BANANA LAZMI, bhoolna nahi)
- **Billing cycle:** user ka cycle usi din se shuru jis din us ne package/plan subscribe kiya (anchor = subscribe date, calendar month nahi).
- **Grace:** cycle ka payment due par na ho to user ko paise jama karne ke liye **3 grace days**. Plan ke andar (billing/plan card mein) **3-day grace countdown** chalta hai, rang din ke hisab se:
  - Grace din 1 = **purple**
  - Grace din 2 = **yellow**
  - Grace din 3 = **red**
- **3 din khatam => workspace PAUSE.** Pause tab tak rehta hai jab tak payment na ho (data delete nahi, sirf pause).
- **Pause screen / plan card ke buttons:**
  - **Resume workspace** -> user ko uske *current plan* ke **checkout** par le jata hai (payment ke baad workspace resume).
  - **Upgrade** -> upgrade flow.
  - **Downgrade** -> downgrade flow. **Basic plan wale ko Downgrade button dikhana hi nahi.**
- Design notes for implementation: state machine active -> grace(1..3) -> paused -> active (on paid webhook); grace day server-side (Rust/SQL) se nikalna, client clock par nahi; Polar webhook se resume; paused workspace par Brain/Rust gate (read-only ya block) alag decide karna (founder se poochna); countdown colours theme tokens mein; email reminders har grace din (optional, poochna).
- Kab: G16 billing portal P2+ ke saath. Dobara founder se poochne ki zaroorat nahi — yeh spec final hai; sirf pause ka exact behaviour (login par kya dikhe, mail aati rahe ya nahi) shuru karte waqt poochna.

### Claude ki SUGGESTIONS (grace + pause) — founder "haan" par shamil, warna sirf yaad-dasht
1. **Pause = read-only, block nahi:** inbound mail HAMESHA accept (kabhi drop/bounce nahi), purani mail/calendar/contacts padh sakta hai, sirf bhejna/naye events/invites band. Isse "block kabhi nahi" aur privacy wada bhi bacha rehta hai. Login par seedha "Workspace paused" screen + Resume button.
2. **Rang sirf rang par nahi:** har din ke saath text bhi ("Grace day 2 of 3 · 1 day left") + icon — colour-blind users ke liye. Rang theme tokens (light/dark dono).
3. **Din server se:** `grace_day` SQL/Rust se, `due_at` + Polar ke `past_due` status se; client clock par kabhi nahi. Time zone: user ke time zone mein din ka hisab, saaf likha ho "pause hoga: 25 Oct, 11:59 PM".
4. **Polar source of truth:** retry hone par Polar khud payment dobara try karta hai — payment aate hi webhook se turant active (grace/pause dono khatam), koi manual step nahi. Webhook late ho to portal "Check payment status" button se re-sync.
5. **Reminders:** grace din 1, 2, 3 par email (aur app banner), pause par ek final mail; sirf billing contact ko; mail content kabhi nahi chhuta.
6. **Pause se pehle data safety:** pause mein data delete nahi; 30/60 din ke baad bhi delete se pehle alag warning + export option (founder policy tay kare).
7. **Upgrade/Downgrade rules:** `/billing-policy` ke mutabiq (naye ka poora price, credit/refund nahi). Downgrade par agar naye plan ki limit se zyada data/users hon to pehle bataye (kya band hoga). Basic par Downgrade hidden.
8. **Team/workspace:** workspace paused ho to members ko "owner ko billing issue hai" dikhe, payment ka button sirf owner/billing role ko.
9. **Abuse:** baar baar subscribe-cancel se grace ka fayda na uthaye — ek cycle mein grace sirf ek baar; naye subscribe par grace nahi, pehla payment lazmi. Founder/test accounts exempt.
10. **Test:** SQL proof (din 0/1/2/3/4 ki boundary, timezone, webhook se resume), Rust test (grace_day), Chrome par teeno rang + paused screen + Basic par Downgrade gayab.
