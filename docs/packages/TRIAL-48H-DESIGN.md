# TRIAL 48 GHANTE — CEO DESIGN (03:18 PKT, 27 Oct 2026) — founder ka hukm, abhi sirf design; BANEGA: Pro green -> Founder account -> Trial

## Founder ne kya kaha (verbatim ka matlab)
- Trial = user ko attract karne ke liye. Landing par **Get started** se aata hai. 2 din (**48 hours**) user use karta hai, usay **48 hours ka countdown nazar aata hai**.
- Isme **Pro package jaisi cheezein** hongi taake user ko idea ho ke hum kya offer karte hain.
- Trial ka **gate sab se alag**, trial ka **data real/paid data se mix nahi hoga** (Lovable ne mix kar diya tha).
- 48 ghante baad user ka mann na bane to **jab bhi login kare seedha "Choose your plan" par redirect** (gate).
- **Real working** trial, **latest technology (MUST rule)**, user ko deewana karna hai. Pro ke baad founder account, phir trial.

## CEO design (mere faisle)
1. **Alag identity, ek hi code path:** plan id `trial` resolve_plan mein (Rule 57: server gate asli, UI sirf aaina). Koi alag copy-paste gate nahi. Feature set = Pro ka, lekin trial limits ke saath.
2. **Data alag (no mixing):** trial ka apna workspace `kind='trial'`. Kabhi bhi real orgs ki storage pool / CRM stats / analytics / billing / search mein ginta nahi. Paid banne par user ke saamne ek saaf choice: **"Keep my trial data"** (in-place upgrade: kind trial -> paid, ek transaction) ya **"Start fresh"**. Na chune to purani rule: **30 din address reserved, mailbox frozen, mail kabhi silently discard nahi** (trial.ts ka lock #4 barqarar).
3. **Trial limits (anti-abuse, sach mein kaam karne ke saath):** ek address `@anexomail.com` (handle claim mojooda), 1 GB storage, bahar bhejne par rozana hadd, custom domain nahi, AI **HARD ZERO** (mojooda lock), ek insaan = ek trial (Device Safety Vault + signup holds pehle se maujood).
4. **Countdown server se:** `hours_left` DB (`account_state`) se, client claim trust nahi. UI mein hamesha dikhta banner; live update WebTransport event se (poll nahi).
5. **48h baad gate:** server sab business procs par domain error `trial_expired` (4xx, 404 nahi — Rule 59) deta hai; client us code par **seedha `/plans` ("Choose your plan")** bhejta hai. Recovery raasta (account, billing, data export) khula rehta hai kyunke koi account permanently band nahi hona chahiye.
6. **Latest technology (must):** UI React 19 + TanStack + Vite 8 -> WASM kernel -> WebTransport/QUIC -> Rust Tokio -> Supabase. Cinematic "deewana" magic (three/GSAP/WebGPU) sirf **landing + get-started + welcome moment** (Rule 60); trial ke working screens (mail, calendar, CRM) non-cinematic aur tez.
7. **Conversion funnel:** trial ke dauran Pro-only features par chhota "Pro feature" nishan; antim 6 ghante mein saaf, shor-sharaba-free reminder; plans page par Basic/Pro/Business (hamari asli qeematein).

## Mojooda trial code (mix wali jagah) — abhi NA chheden
`server/routes/trial.ts` (9 routes), `trialx` Rust (security/events/holds 3 proc LIVE, green), `src/routes/trial-ended.tsx`, `get-started.tsx`, `lib/trial.ts`, app.tsx gate. Trial ke baaqi 6 Bun endpoints (state, address, start, claim, subscribe, sweep) **ab migrate NAHI** — naye design par dobara banenge (do baar code nahi likhna).

## Tarteeb
Pro green (Batch D/E/login baaqi) -> Founder account -> **Trial rebuild** (SQL `trial` plan + kind, Rust `trial.*`, gate, countdown event, UI) -> live proof (probes + Chrome).
