# E18 — `signup_device_gate` auto-block bug fix (13 Oct 2026)

Blueprint item #6 ki note: "an actual human click-through signup in a browser"
abhi tak baaqi thi. Aaj founder ne khud `/auth` pe live signup try kiya
(legal name "Ali Khan", classic form) aur pehle hi step pe ek real bug pakda.

## Kya hua

Submit ke baad screen pe aaya: **"This device already has accounts. Sign in
instead of creating another."** — aur signup create nahi hua (pre-auth 403).

## Root cause

`docs/cursor-work/sql/phase63_f3a_passkey_family.sql` ka `signup_device_gate()`
(12 Oct ko likha gaya) ek coarse "device shape" hash banata hai — sirf
platform/browser/timezone-hour/screen-bucket/language, koi persistent ID ya
cookie nahi. Jab isi hash par >=3 distinct accounts ban chuke hon (jaisa is
session ke test accounts se ho chuka tha), yeh function `ok:false` return
karta, aur `server/routes/auth.ts` usay seedha 403 de kar signup ko
**Supabase auth user banne se pehle hi** rok deta tha.

Yeh teen cheezon se takra raha tha:

1. **`anexochat/sql/phase24a_account_integrity.sql` ka locked Rule #2:**
   "Engine khud kisi ko block NAHI karti. Ladder: clean → suspicious (engine)
   → warned (insaan) → blocked (insaan, warning ke baad hi)." —
   `signup_device_gate()` seedha engine-level block kar raha tha, koi insaan
   involve nahi.
2. **Duplicate system (Rule 6 "No mix, no duplicate"):**
   `anexochat/sql/phase19_22_device_safety_work.sql` ka
   `device_vault_register()` — jo isi signup flow mein iske foran baad already
   call hota hai (`server/routes/auth.ts` ~line 552) — yehi "same device shape,
   >=3 accounts" case already sahi tareeqe se handle karta hai: sirf
   `state='suspicious'` mark karta hai, kabhi block nahi karta.
   `signup_device_gate()` isi logic ka ek dobara, lekin **galat (blocking)**
   version tha.
3. **Coarse hash = bucket, fingerprint nahi:** `src/lib/chat-safety.ts` mein
   saaf documented hai — "sirf 5 coarse signals, koi silent fingerprinting
   nahi." Yeh ek deliberate privacy-minimization commitment hai, is liye hash
   ko persistent ID add kar ke "zyada accurate" banana bhi sahi fix nahi tha
   (woh promise todta). Asli masla accuracy nahi, **auto-block** tha.

## Fix

- `docs/cursor-work/sql/E18_signup_device_gate_nonblocking.sql` —
  `signup_device_gate()` se account-count auto-block hata diya. Ab sirf
  `device_bans` table (insaan ka confirmed ban) check karta hai — woh locked
  ladder ke "blocked" stage ka hi enforcement hai, naya auto-block nahi.
- `server/routes/auth.ts` — dead `too_many_accounts` branch hata ke comment
  likha ke kyun (future mein koi dobara na likh de).
- Koi client-side / signal change nahi — "5 coarse signals" promise waisa hi
  hai. Koi naya table nahi, existing `device_vault_register()` + `device_bans`
  hi reuse hue.

## Verify (zaroori, deploy ke baad)

1. `docs/cursor-work/sql/E18_signup_device_gate_nonblocking.sql` Supabase #4
   SQL Editor mein paste → Run.
2. Server pull + build + restart (Rule 1 standard command).
3. Live browser test: naya email + password signup (jis device se pehle test
   accounts bane the, usi se) → ab signup **block nahi hona chahiye**,
   `device_vault` row `state='suspicious'` ban-na chahiye (block nahi).
4. Ek fresh/alag device-shape se bhi signup confirm karo (normal case,
   `state='pending'`).

**Status:** READY (repo mein, Supabase + server par abhi deploy/verify nahi
hui — Rule 5).
