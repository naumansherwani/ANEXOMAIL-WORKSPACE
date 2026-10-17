# Loophole ledger — jo pakda gaya, jo band hua, jo khula hai (sach)

Rule 21 (founder, 17 Oct 2026 18:24 PKT). Yeh file har fix par update hoti hai; har summary ke aakhir mein isi ka khulasa. **DONE sirf live saboot par** (Rule 5): founder ka server output ya browser. Sandbox mein dekha hua = READY.

Aakhri update: **17 Oct 2026, 18:34 PKT** (`current_time` tool).

## A. Band hue (loophole tha → ab nahi)

| # | Loophole (user ya business ko kya nuqsan) | Kaise pakda | Fix | Status |
|---|---|---|---|---|
| L1 | Mail TLS cert 1 Jan 2027 ko expire — IMAP/SMTP sab band hota (URGENT) | founder ka 05:04 order | 8n cert + expiry watch | **DONE** (live: 993/587 naya cert, 76 din) |
| L2 | Cert/domain/DKIM expire ka kisi ko pata na chalta | CEO review | 8o expiry-watch (timer, email, Rust proc) | **DONE** (live: 26 items OK, report mail sent) · dashboard tile READY (browser baqi) |
| L3 | Basic user apni company address se bhej hi nahi sakta tha ("Send from" chhupa) | screenshot review | 8r | READY |
| L4 | Compose "Attach" file le kar chupke se chhod deta tha (jhoot) | screenshot review | button ab saaf "coming soon" bolta hai (asli fix 8p niche khula) | READY |
| L5 | Domains: user ko DNS ke intezar mein andhera / domain "taken" ka ulajha message / pehli mail ka rasta nahi | screenshot review | 8d, 8e, 8f, 8g, 8h | READY |
| L6 | **/auth login phone par dayen se kat raha tha** (email suffix, password aankh, buttons) — har phone par returning user ka pehla screen | site harness 390 | `AnexoMailField` input `w-0` | READY |
| L7 | **iPad par website header ka "Sign in / Get started" screen se bahar** (page 980px) | harness 744–1023 | SiteNav `md`→`lg` | READY |
| L8 | **Plan cards par 50–58 bullets ki deewar — Buy button hazaaron pixel neeche** (landing 390 par 17,902 px) | harness 390 | `PlanFeatureList` pehli 8 + "Show all N" (SEO ke liye DOM mein poori list) | READY |
| L9 | Hamburger 36px, menu links 40px (touch ke liye chhote) | harness 390 | `ax-tap` 44px | READY |
| L10 | /plans comparison table phone par side-scroll mein feature ka naam ghayab | harness 390 | pehla column + group naam sticky | READY |
| L11 | /plans Business tab: aakhri bullet aur Buy button chipke hue | harness 390 | CTA ke upar gap | READY |
| L12 | Server aur repo mein farq ka koi saboot nahi tha (installers se dirty tree) | founder ka output (41 "M" files) | `pull.sh` ab sync ke BAAD `src/` ki har file ka sha origin/main se milata hai: `same/differ/missing` | READY (agle pull par pehli reading) |
| L13 | `/rpc/health` ka `wt_port` khali (health jhoot-sa) | founder ka facts output | 8u (Rust ek line) | READY (server par Rust build ke baad) |
| L14 | "Node chalta hai?" ka andaza | founder ka sawal | TECH-MAP §10 + facts v2 har pm2 process ka interpreter chhapta hai | READY (output ka intezar) |

## B. Khule hain (agent kar sakta hai — agla kaam, tarteeb se)

| # | Gap | Kyun khula | Agla qadam |
|---|---|---|---|
| G1 | **Attachments (8p)** — bheji mail mein file ja hi nahi sakti | `mail.send` Bun par; Rust par laana (R1) pehle | R1 + 8p; bara kaam |
| G2 | M6 baqi: People, Calendar (phone par agenda), Work, CRM "Move to…", Billing, Account, Admin | audit baqi | harness mein ek ek section |
| G3 | R0 Rust latest: edition 2024, axum 0.8.9, wtransport 0.7.2, `opt-level` | sandbox mein compile nahi; server par scratch `cargo check` | founder ka ek command (scratch check), phir theek |
| G4 | R1 `mail.send` Rust par; R3 typed contract; R4 direct pool; R5 event-driven WebTransport push | bade Rust kaam, R0 ke baad | tarteeb se |
| G5 | 8s `/api/mail/send` fallback identity ignore karta hai | R1 mein khatam hoga | R1 ke saath |
| G6 | 8i/8j IMAP: Dovecot chalta hai par mail `anexopipe` se jati hai aur mail store 8 KB — phone ki Mail app khali ho sakti hai | facts v2 se confirm baqi | facts v2 ka output → dual delivery ya JMAP ka faisla |
| G7 | 8m catch-all/forwarding/vacation/signature — pehle se kya hai verify baqi | audit baqi | code + server dekhna |
| G8 | M9 Urdu/RTL + web push; M11 React Compiler | M11 ko `vite.config.ts` no-touch ki chhoot chahiye | M9 pehle; M11 founder okay |
| G9 | P1 plan-promise audit (plans.ts ki har line server par saabit?) | bada audit, abhi shuru nahi | `plan-promise-audit.md` |
| G10 | P3 passkey button hai — asli flow verify baqi | verify baqi | auth route + Rust proc dekhna |
| G11 | D2 Bun 1.4.0→1.4.3 | chhota script baqi | `upgrade-bun.sh` |
| G12 | Rust `anexomail-rust` restarts=48 — wajah nahi pata | facts v2 ka panic count | output dekh kar |
| G13 | Real-phone verification (Rule 5) — abhi sab sandbox/harness | founder ka phone | ek chhoti checklist (neeche) |

## C. Founder ke bina nahi ho sakte (chhupa nahi — saaf)

| # | Kya | Kyun founder | Kya chahiye |
|---|---|---|---|
| F1 | **8q MTA-STS + TLS-RPT** — DNS khali (`_mta-sts`, `_smtp._tls`, TLSA) | DNS panel founder ke paas | 3 DNS records (script ke baad) — text blueprint 8q mein |
| F2 | **8t `milter_default_action` accept→tempfail** | production mail config (GREEN) | founder "haan" |
| F3 | **D1 PostgreSQL 17.6→18** | database cutover | founder "haan" + staging window |
| F4 | **M8 viral (V1 "Sent with ANEXOMAIL" line)**, 8l ek-click DNS, P2 SSO, M11 vite.config | product faisle | founder faisla |
| F5 | **P1 wording**: Business Pro "12h priority support" vs /plans ke Priority Support "2 business days" | plan ka wada | founder wording |
| F6 | **R2 Stalwart (Rust mail server)** | mail ka production raasta | parallel staging + founder "haan" |

## D. Real-phone check (founder, 2 minute, pull ke baad)

1. Phone par `anexomail.com/auth` — sign-in card poora dikhe (email ka `@anexomail.com`, password ki aankh, saare buttons).
2. `anexomail.com` → neeche Plans: Business/Business Pro par "Show all N features" dabao; Get started upar nazar aaye.
3. iPad (portrait) par header mein Sign in / Get started dikhein (ya hamburger khule).
4. `/plans` → neeche table ko side mein sarkao: Feature ka column tika rahe.
