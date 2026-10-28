# FOUNDER PROTOCOL — Command Center ka asli dastoor (28 Oct 2026, 05:40 PKT)

> ## ⚙ TECHNOLOGY PEHLE (Rule 62 — founder ka STRICT usool, 28 Oct 05:25)
> Pehle technology dekho, phir blueprint likho; har section/phase mein saaf likha ho "yahan kis technology par code likhna hai". Galti founder bardasht nahi karega.
> **Founder = Rust binary `anexomail-founder` (axum 0.8, tokio, WebTransport/QUIC, Supabase, passkey, SHA-256 chain + HMAC) + React 19.2/Vite 8.2/TanStack Router static SPA/Tailwind 4.2/shadcn/Three.js WebGPU/Motion+GSAP/WASM kernel (Rule 52, enforce). Bun/Node founder mein KABHI nahi.** Detail: AGENTS.md Rule 61, TECH-MAP 0d. Look: CINEMATIC (Elon-level), awam UI se bilkul ALAG design.
Founder (28 Oct 04:45): login = DONO (password + passkey, dono pehle se hain); Bridge = paisa + "kya bigad raha hai" EK fold mein; "repo audit karo — founder ke email kaun se, dusra founder login, founder ko kaisa protocol milna chahiye". Yeh file FOUNDER-WORKSPACE-PLAN.md (F0–F9) ke upar protocol hai; takrao par yeh + plan dono dekho, privacy lock sab se upar.
ONE-ORDER-27OCT.md qadam 9 = "FOUNDER ACCOUNT (F, 32 endpoints)": Pro ke baad. Pro GREEN declared (27 Oct 11:06) => ab yahi agla kaam.

## 1. Founder kaun hai (repo audit — verified)
| Identity | Kahan | Halat |
|---|---|---|
| `naumansherwani.founder@anexomail.com` (uid 3e3a60ea-…, `founder_accounts` row, E phase45) | auth.ts, founder.ts, founder-gate, org-authz, Rust main.rs, analytics.ts | **PRIMARY.** business_pro top plan, trial 10 saal, passkey_set |
| `naumansherwani.founder@nexatect.com` (parent company Nexatect) | SAME hardcoded default list 6 jagah: founder.ts, founder-gate.ts, org.ts, analytics.ts, Rust main.rs:2448, ai.ts | **DUSRA founder login.** Repo mein sirf EMAIL ki list; uska auth user/`founder_accounts` row repo mein kahin nahi => server par hai ya nahi YEH PATA NAHI |
| `FOUNDER_EMAILS` env | override | list env se badal sakti hai |
| `hostflowaibuilder@gmail.com` | — | founder ka test/Chrome Gmail; founder identity NAHI |
**Khatra (asli):** founder = "email list mein hai" (6 jagah copy, alag-alag). Agar `nexatect.com` email Supabase mein verified-email ke baghair ban sake to koi bhi us naam se founder ban sakta hai. Qaida: founder = `founder_accounts.user_id` (uid) **AUR** verified email — email list sirf bootstrap. Ek hi jagah (Rust `resolve_founder`) se, 6 copy khatam.

## 2. Login protocol (founder faisla: DONO)
1. Password (Supabase asli password, argon2 server-side) — **env `FOUNDER_PASSWORD` plain-compare raasta band** (auth.ts:790-797: match par password UPDATE/user CREATE karta hai public route par; constant-time nahi) — pehle passkey login saboot, phir hatana (founder lock-out nahi).
2. **Passkey (WebAuthn, Google jaisa)** — founder ke liye LAZMI step-up har naye session par (test-account exemption founder par nahi).
3. **Device approval** (naya device => recovery address par approve) + **IP allowlist** Caddy + nftables (double lock) — founder host par.
4. Session: short-lived JWT + HMAC cookie/CSRF; 60 min idle; sensitive action par passkey dobara (do-tap).
5. Break-glass nahi (content access kabhi nahi). Account recovery: recovery email + passkey; dono ghaib => founder server console (Caddy ke baahar).

## 3. Privacy lock (founder ka apna hukm, sab se upar)
Customer ke mailbox/file/calendar/contact CONTENT founder ko KABHI nahi — metadata-only (counts, sizes, rates, health, security events). Code mein enforce: founder RPC ke SELECT mein content columns nahi + test jo dhoondhe.
**Farq (zaroori):** company ke apne 5 addresses (resolved@, moveyourbusiness@, hello@, billing@, leo@) mein customer ne KHUD hamein likha — wo company ki mail hai, Mail Desk mein padhna/jawab dena theek hai (mail-identities-locked-2026-10-14.md). Customer ke apne inbox ka content = band.

## 4. "Awam ke masle yahin se sune jayen" — Command Center ke input channels
| Awaaz | Source (repo mein) | Mail Desk/Bridge mein |
|---|---|---|
| Support mail | resolved@, hello@, moveyourbusiness@, billing@ (unified, address badge) | Mail Desk inbox, reply+AI draft (Leo), SLA 24h |
| App glitch / rage-click | glitch.ts + phase47 `glitch_crm_alert` | "Kya bigad raha hai" list |
| Appeals (blocked account) | E72 appeal_evidence + reviewer panel | Appeals queue |
| Safety/abuse | safety queue (privacy-preserving), abuse score, bounce/complaint | People > Abuse board |
| Billing masle | billing-support.ts, Polar (dekhna sirf; NO-TOUCH) | Money |
| Move-in | movein.ts / `founder.movein.*` | Move-In board |
Founder ka apna inbox ALAG (`naumansherwani.founder@`); company 5 = unified. `support@`/`leads@` repo mein HAIN HI NAHI (locked list nahi) — nahi banenge jab tak founder na kahe. `noreply@` inbound discard.

## 5. Bridge (pehla screen) — paisa + "kya bigad raha hai" ek fold mein (founder haan)
Upar ek patti: MRR/ARR vs target + sabse zaroori 3 faisle ("right now" ranked, Rust `founder.brain.command` attention) + system light (green/amber/red) + awam ki awaaz ka count (unread support, open appeals, glitches). Har number ke saath source + umar; naapa nahi = "Not measured".

## 6. Founder ki powers (do-tap + reason + audit) aur hudood
Level 1 dekhna (metadata), Level 2 actions (suspend/restore, rate-limit, force sign-out, revoke device, reset MFA, extend trial, comp plan, kill switch, IP block), Level 3 content = BAND. Har dekhna/karna `founder_audit` (append-only, SHA-256 hash-chain + HMAC signature). Polar: dekhna sirf (webhook/products NO-TOUCH). Family accounts (Humza/Raana/Masood) founder protocol mein nahi: apna private inbox.

## 7. Tarteeb (F-series, ONE-ORDER qadam 9 ke andar)
- **F1a Security fix (pehle):** `resolve_founder` ek jagah (Rust), nexatect.com/ list ka sach, host guard (.lovable.app/localhost client se hatao — localhost sirf dev build mein), pwa.ts Lovable hosts; `FOUNDER_PASSWORD` env path band (passkey saboot ke baad); `founder_audit` + `break_glass`(sirf log, content nahi) SQL (E102) RLS-on.
- **F1b Foundation:** Rust `server/founder/` (axum/tokio), static SPA serve, passkey+device+IP, audit chain, command bar.
- **F2 Bridge** (data = `founder.brain.command`) -> F3 Money+Release -> F4 People (global user/org 360) -> F5 Mail Desk -> F6 Systems+Move-In -> F7 3D -> F8 Control -> F9 cutover (36 purane Lovable route files band). AI pages (10) Rule 23: band rahengi.
- Har F: sandbox proof -> founder server output -> 390/820/1440 Chrome -> tab GREEN.

## 8. Nexatect (parent company) login — LATER (founder 28 Oct 04:59)
`naumansherwani.founder@nexatect.com` ke liye ALAG login/surface banega, jis mein parent company (Nexatect) ka sab kuch hoga. **anexomail.com puri website banne ke BAAD**, abhi nahi. Tab tak ANEXOMAIL founder protocol sirf anexomail.com identity par; nexatect ke addresses ka kaam phase F5+ ke baad (FOUNDER-WORKSPACE-PLAN §3).

## 2b. PASSKEY — EK BAAR, phir popup kabhi nahi (founder 28 Oct 05:55, STRICT)
Founder ko bar bar passkey popup irritate karta hai (awam user ko bhi — woh awam-side ka alag bug, backlog). Faisla: passkey sirf (1) pehle login par, (2) NAYE/na-approved device par. Device approve hone ke baad (`founder_devices`, E102) us device par session ke dauran aur agle logins mein dobara popup NAHI. High-danger action par popup nahi — do-tap + wajah + audit + approved device (E102 `needs_passkey` ka matlab ab "approved device session"). Passkey ka tareeqa wahi (passkey_core/glue: WebAuthn, google jaisa) — founder par saaf suthra apply, awam wale flow ki nakal nahi. Naya device = purane approved device se manzoori. Device revoke karne par session foran khatam.
