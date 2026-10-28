# FOUNDER COMMAND CENTER — BUILD PLAN (phases, technology, Chrome ka sach) — 28 Oct 2026

> ## ⚙ TECHNOLOGY PEHLE (Rule 62 — founder ka STRICT usool, 28 Oct 05:25)
> Pehle technology dekho, phir blueprint likho; har section/phase mein saaf likha ho "yahan kis technology par code likhna hai". Galti founder bardasht nahi karega.
> **Founder = Rust binary `anexomail-founder` (axum 0.8, tokio, WebTransport/QUIC, Supabase, passkey, SHA-256 chain + HMAC) + React 19.2/Vite 8.2/TanStack Router static SPA/Tailwind 4.2/shadcn/Three.js WebGPU/Motion+GSAP/WASM kernel (Rule 52, enforce). Bun/Node founder mein KABHI nahi.** Detail: AGENTS.md Rule 61, TECH-MAP 0d. Look: CINEMATIC (Elon-level), awam UI se bilkul ALAG design.
Founder hukm (28 Oct 04:53): plan pehle, jaldi nahi, phases smooth, Bun RETIRED (founder mein Bun nahi), UI + backend technology likho, saath ke saath likhte jao (compact-safe), Chrome dekho. Isse pehle padho: FOUNDER-PROTOCOL-28OCT.md, FOUNDER-CODE-INVENTORY-28OCT.md, FOUNDER-WORKSPACE-PLAN.md (F0-F9 asli plan), TECH-STACK-BEAST.md. Koi code is plan ko founder ke dekhne se pehle nahi.

## 1z. DATA KA RAASTA — LOCKED (founder ne pasand kiya, 28 Oct 05:26; Rule 62/63)
Supabase (data) -> `anexomail-founder` Rust (axum+tokio; padhta hai; har jawab par HMAC) -> ek WebTransport/QUIC connection (fallback sadi fetch) -> WASM kernel (Rule 52 builtin; HMAC + audit-chain browser mein verify; `ANEXO_TAG_MODE=enforce`; fail = screen par nahi) -> React 19.2 + TanStack Router (sirf verified data) -> Three.js (sirf draw; 3D kabhi data ka source nahi). 3D fallback: WebGPU -> WebGL2 -> 2D. Pehle 5 second mein numbers saaf parhe jayen; cinematic numbers ke PEECHE.
CEO faisle (founder ne CEO ko diye): (1) Bridge mein SIRF ASLI data — koi dummy/mock nahi; jo data abhi nahi (paisa) woh "abhi connect nahi" likha, F3 mein Polar/Billing se; (2) rang space-black + ek green accent; (3) F1a (alag founder login host) PEHLE, cinematic Bridge uske peeche.

## 3z. F3 MONEY — baqi kaam (CEO ki list, 28 Oct 05:50)
Abhi (F1b) Bridge ka paisa = `revenue_accounts` (active MRR, founder ke haath ke darj kiye accounts) — yeh Polar ki billing NAHI. F3 mein poora hona hai (technology: Rust `anexomail-founder`, Supabase, Polar webhook data jo `anexomail-rust`/polar-rust-payment :3400 mein hai; UI React+Three, kernel verify):
1. Polar se ASLI: subscriptions, MRR/ARR, naye/cancel/refund/chargeback — Polar ka sach read-only (webhook/WAL ko haath nahi, Rule B6a).
2. Plan-wise mrr (Basic £40 / Pro £105 / Business £360 / Business Pro £2,850) aur sab se bara kharch/leak.
3. Target vs asli (revenue_targets) + forecast; pehle 5 second mein ek number + ek rang.
4. Failed payments / dunning list (kiska card fail), har amal do-tap + reason + audit.
5. `revenue_accounts` (manual CRM) aur Polar ka farq dikhana (mismatch alert) — dono ek jagah, jhoota 0 kabhi nahi.

## 4z. UI/UX ADVANCE + ONE-CLICK SYSTEM + SQL — phase-wise blueprint (founder hukm 28 Oct 05:55; Rule 62 TECHNOLOGY PEHLE)
**Technology (yahan code kahan):** UI = `founder-web/` (React 19.2, Vite 8.2, three 0.185 WebGPU->WebGL2->2D, Motion/GSAP, WASM kernel Rule 52); backend = `server/founder/` (Rust axum+tokio, WebTransport); data = Supabase SQL `docs/cursor-work/sql/E102+` (Postgres 16, RLS default-deny, service_role sirf founder binary). Bun/Node founder mein nahi.
**Pehle se maujood purani (Lovable) files:** `docs/claude/founder/LEGACY-FOUNDER-FILES.md` — alag gine gayi, naye kaam mein nahi, F9 mein hatengi.
**UI/UX usool:** (1) 3D toggle HAMESHA (ON/OFF, yaad rehta hai; OFF = 2D, kuch nahi chhupta) — BANA; (2) numbers pehle 5 second, cinematic unke peeche; (3) har screen par ek hi sawal: "kya ab mujhe kuch karna hai?"; (4) keyboard-first (Cmd-K command bar), har action ek click + do-tap + wajah; (5) har halat saaf: loading / khali / 'abhi connect nahi' / kharab — jhoota 0 kabhi nahi; (6) reduced-motion + 2D mein poora kaam; (7) mobile par bhi Bridge.
**ONE-CLICK SYSTEM (kis ke liye):** founder ko server par terminal na chalana pade. Catalogue `founder_actions` (E102, seed 12 action, sab DISABLED): Release (web pull, SQL AUTO, Rust install, rollback) · Systems (health dobara, Rust restart) · Mail Desk (failed mail dobara queue) · People (suspend/unsuspend) · Control (maintenance ON/OFF, signup freeze). Har action: darja (low/medium/high), high = passkey + do-tap lazmi (DB constraint), wajah lazmi, `founder_audit` mein entry, rollback jahan mumkin. Executor F8 mein, har action alag saboot ke baad enable.
| Phase | Kaam | Technology | Exit saboot |
|---|---|---|---|
| F0 | design canvas (sober, v1) + cinematic v2 | claude canvas -> founder-web | founder dekh kar manzoor |
| F1a | founder alag login host (Caddy) + passkey step-up + awam login se founder band | Rust + Caddy + passkey_core | founder uid awam login=403; awam uid founder host=403; passkey bina andar nahi |
| F1b | founder-install.sh (Rust+SPA) | Rust, systemd | install ke curl saboot (SPA 200, healthz 200, me/bridge 401) |
| E102 | audit chain + actions + devices SQL | Postgres | selftest OK + tamper pakda |
| F2 | Bridge live + 3D + kernel verify (F2b) | React+three+WASM | Chrome live, sig verify |
| F3 | Money (Polar) + Release | Rust + Polar read-only | asli MRR, mismatch alert |
| F4 | People | Rust + SQL | metadata-only |
| F5 | Mail Desk (5 company address + founder inbox) | Rust | customer content kabhi nahi |
| F6 | Systems | Rust | health sab |
| F7 | 3D deepen (zones, drill-down) | three WebGPU | 60fps / 2D fallback |
| F8 | Control + one-click executor | Rust | har action audit + rollback |
| F9 | cutover: legacy files + Bun founder routes hatao | — | Rust saboot ke baad hi |

## 0. Chrome ka sach (28 Oct 05:00, founder ka Chrome "LENOVO")
- `founderworkspace.anexomail.com/app/founder` kholne par **awam wala hi Sign-in page** aata hai, upar "FOUNDER PREVIEW" badge. Yaani founder host abhi **wohi ek app** hai (awam ka UI), alag founder UI nahi.
- Us page par **"Create your account for workspace"** (awam signup) founder host par bhi dikhta hai => founder host par signup band hona chahiye.
- Email box = `username` + fixed `@anexomail.com` => **`naumansherwani.founder@nexatect.com` (dusra login) is form se sign-in kar hi nahi sakta**: wo identity abhi sirf allowlist mein hai, login raasta nahi. (Server par uska auth user hai ya nahi: ab bhi unknown.)
- Is Chrome profile mein founder host par login abhi nahi (alag origin = alag session). Main password kabhi nahi likhta; founder khud passkey se sign-in kare, phir main sirf dekhta hoon.

## 1. Founder ki technology (LOCKED sulah — TECH-STACK-BEAST CEO faisla)
### 1a. Backend — SIRF Rust, Bun NAHI, Node NAHI
| Layer | Choice | Kaam | Halat |
|---|---|---|---|
| Founder service | **naya Rust binary `anexomail-founder`** (crate `server/founder/`), alag pm2/systemd service, alag Linux user | sirf founder API + static SPA serve | NAHI bana (F1) |
| Runtime | rustc 1.99.1 edition 2024, tokio 1.53.x multi-thread (JoinSet, select!, bounded channels, timeouts) | async har jagah | live toolchain |
| Web framework | axum 0.8.9 + tower (rate-limit, load-shed, trace) | `/rpc/founder.*` typed RPC | live version |
| Live | wtransport 0.7.2 / quinn 0.11 (WebTransport/QUIC, UDP) + SSE fallback; Postgres change feed -> `tokio::sync::broadcast` | page khud update | B4 hub reuse |
| Data | Supabase/Postgres (source of truth), SQL sirf `sql-run.sh` se (RLS-on, E102+) | `founder_audit`, break-glass log, abuse scores | E102 TODO |
| Auth | JWT local verify (`jwt_core`), **passkey WebAuthn** (`passkey_*` reuse), device gate + HMAC, IP allowlist (Caddy + nftables) | founder-only | reuse + naya founder step-up |
| Crypto | SHA-256 audit hash-chain + HMAC-SHA256 signature/cookie/CSRF/signed URLs (alag key har kaam), constant-time compare | tamper-evident | NEXT |
| Edge | Caddy HTTPS + HTTP/3, founder host IP allowlist | — | live (founder "haan" ke baghair nahi chhoona) |
| Mail/Polar | Postfix/Dovecot unchanged; Polar :3400 NO-TOUCH (sirf dekhna) | — | — |
**Bun:** founder ke 53 BUN-ONLY endpoint (movein 16, release 13, admin 11, perf 9, founder 6, glitch 4, org 4 ...) **Rust par port**, phir founder ke liye Bun route hata (Rule 56/59: pehle Rust==Bun saboot). Brain (:3100 Bun) awam ke fallback ke liye rehta hai — founder us par depend nahi karega.
### 1b. Frontend (UI) — founder ka stack, build-time par, server par runtime nahi
| Layer | Choice | Kyun |
|---|---|---|
| App | React 19.2 + Vite 8.2, **TanStack Router (SPA mode — TanStack Start SSR runtime nahi)** | type-safe routes; output = **static assets**, akela Rust binary serve karta hai |
| Data | TanStack Query (+ Table, Virtual: 100k rows) | cache, live-invalidate |
| Style/UI | Tailwind 4.2 + Radix/shadcn, modern CSS (`@layer`, container queries, oklch, view transitions) | awam app ke tokens reuse |
| Motion/3D | Motion + GSAP; **Three.js WebGPURenderer/TSL (WebGL2 fallback), lazy chunk**, Web Worker + OffscreenCanvas | globe, topology, flow, terrain (F7) |
| Compute | **WASM kernel (Rule 52, web-wasm/)** reuse: sha256/hmac -> audit chain browser mein verify; WASM module SHA-256 pin + SRI | tamper-visible |
| Live | WebTransport client (kernel ke through), SSE fallback | refresh nahi |
| a11y/mobile | 390/820/1440, reduced-motion, har 3D ka text/table equivalent, WCAG 2.2 AA | Rule 19/34 |
| Build | sandbox/CI mein build -> artifact + SHA-256 manifest -> server par sirf copy | **server par na Node na Bun** |
**Sach ek baat:** UI ko *build* karne ke liye JS toolchain (Vite) sandbox/CI mein chalta hai, server par nahi. Agar founder ko build-time par bhi Node/Bun nahi chahiye to pure-Rust UI (Leptos 0.8 + wgpu) option hai (FOUNDER-WORKSPACE-PLAN §2) — mera default: React sulah (locked), kyunke awam ka design system/3D/passkey UI reuse hota hai.

## 2. Founder "tumhare hisab se" kaisa hoga (CEO soch)
Ek **command bridge**, dashboard nahi. Pehle 5 second mein founder ko 3 cheezein: (1) paisa (MRR vs target), (2) kya bigad raha hai (ranked), (3) awam kya keh rahi hai (unread support, appeals, glitches). Neeche decks: Money · People (global user/org 360, abuse) · Mail Desk (5 company inbox unified + founder ka apna) · Release · Move-In · Systems · Control. Ctrl-K se "suspend user X", "show failing sends". Har action do-tap + reason + audit. Sach pehle: naapa nahi = "Not measured". Mobile par bhi poora (phone se founder faisla le sake).

## 3. Phases (har ek: kaam -> exit saboot; ek ke baad agla; founder ka "haan" har phase par)
| Phase | Kaam | Exit (saboot) |
|---|---|---|
| **F0 Design** | design system (tokens/components/motion), Bridge + People + Mail Desk ke mock 390/820/1440, 3D concept; kuch deploy nahi | founder screenshots manzoor |
| **F1a Security fix** | `resolve_founder` EK jagah (Rust: founder_accounts uid + verified email), 6 hardcoded list hatao; client host guard (.lovable.app/localhost sirf dev build); pwa.ts; **founder host par signup band**; E102 `founder_audit`(+hash-chain) + break-glass LOG; `FOUNDER_PASSWORD` env path band **sirf passkey login saboot ke baad** | cargo test + SQL CHECK + founder passkey login live + 401/403 hostile tests |
| **F1b Foundation** | crate `server/founder/`, static SPA serve, passkey step-up + device + IP, session HMAC/CSRF, audit chain, command bar, live channel, Caddy founder route (live file dekh kar, backup+validate) | login -> khali shell live, audit row, 401/403 |
| **F2 Bridge** | `founder.brain.command` (b5 reuse), ranked list, paisa+bigad+awam fold, live push | seeded-truth proof + 3 screenshots |
| **F3 Money + Release** | revenue/pipeline/billing view, release/QA/lock (Rust procs mojood) | old page vs new differential |
| **F4 People (Founder view)** | `founder.people.*` metadata-only, abuse scoring (pure core, tested), actions + audit | hostile + no-content grep test |
| **F5 Mail Desk** | founder inbox + 5 company unified, reply, Leo draft, SLA 24h, undo-send | Rust queue send, idempotency |
| **F6 Systems + Move-In** | health probes real, DNS/cert/queue/backups, move-in board | probes real, blind-spot honest |
| **F7 3D** | globe/topology/flow/terrain (WebGPU, lazy, 2D fallback) | FPS budget, a11y tables |
| **F8 Control** | kill switch/flags/audit viewer | audit tamper test |
| **F9 Cutover** | 36 purane Lovable founder route files band, Bun founder routes hatao (Rust==Bun saboot ke baad), docs/runbook | server==repo, old routes 301/404 |
AI founder pages (10): Rule 23 — in phases mein nahi, band.

## 4. Likhte jao (compact-safe) — har phase ke saath
founder-commands.md (verbatim hukm + halat) · DONE-DO-NOT-REPEAT.md (kya ho chuka) · yeh file (phase table ki halat) · ENDPOINT-PACKAGE-MAP (naya proc) · manifest sync/verify · commit+push.

## 5. Khule sawal (founder se, ek ek)
1. **FAISLA (founder 28 Oct 04:59): nexatect.com = ALAG login, parent company ka sab kuch usi mein; ANEXOMAIL.COM puri website banne ke BAAD banega.** Tab tak founder = sirf `naumansherwani.founder@anexomail.com`; F1a mein nexatect email ko dusri identity ke taur par rakhna/hatana us waqt tay (abhi koi kaam nahi, koi risk list se hat'ta hai to bhi founder ko asar nahi).
2. UI build-time JS toolchain (React sulah, mera default) ya pure-Rust Leptos?
3. Founder service ka port/naam (F1b par live Caddy + pm2 padh kar tay hoga).

### F1a addendum (28 Oct 05:10) — user/founder login alag
Awam `/auth` login se founder andar na aa sake aur founder session awam API par na chale: (1) auth.ts login par `isFounderUser` => refuse + founder portal ka pata; (2) founder-gate awam routes se session-type alag (founder token alag audience); (3) `FOUNDER_PASSWORD` auto-create/upsert wala raasta band (passkey proof ke baad); (4) test: founder uid + awam login = 403, awam uid + founder host = 401/403.

## 6z. FIX LIST (numbered) — Lovable ki gadbad, purani founder files ko awam se alag dikhana (founder hukm 28 Oct 06:32)
Maqsad: purana founder code awam se ALAG nazar aaye; jo galat mile uska number yahan. Detail: docs/claude/founder/CODES/ (rules FC1-11, 04-MIX, 05-AUDIT).
| # | Kharabi | Fix | Phase |
|---|---|---|---|
| FX-1 | auth.ts `FOUNDER_PASSWORD` (password overwrite + createUser) | founder passkey login live proof ke BAAD hatao | F1a |
| FX-2 | 7 alag gate tareeqe, FOUNDER_EMAILS 4-5 jagah | ek Rust gate (founder_accounts uid + ES256 local); purane gate ek-ek kar ke `founder-gate-core` par, phir hatao | F1a/F9 |
| FX-3 | Founder writes bina audit (provision, approve, kill-switch, impersonate, movein, release, storage, crm toggle) | har write /founder/v1/action + hash-chain + wajah | F6/F8 |
| FX-4 | `safe()`/`catch{}` fake khali data | null/connected:false (Rule 63) | har phase |
| FX-5 | FounderBar awam __root.tsx mein har page par | root se hatao, founder host par hi | F9 |
| FX-6 | Founder login awam login se | alag host founder.anexomail.com + passkey + device approval | F1a |
| FX-7 | Founder landing nahi (seedha deck) | LANDING page — niche FX-7 spec | F1c |
| FX-8 | Do founder hosts (founderworkspace.* vs founder.*) + lovable.app/localhost "founder host" | ek host, baqi hatao | F1b/F9 |
| FX-9 | Rust audit hash DB v1 se alag | align + test | F2 |
| FX-10 | org impersonate/kill-switch bina passkey+two-tap | high-danger rule | F6 |
| FX-11 | public aur founder routes ek file (revenue, movein, glitch, storage) | founder hissa Rust, public wahi | F9 |
| FX-12 | 33 founder pages awam JS bundle mein | naya founder-web mein, awam bundle se nikalo | F9 |
| FX-13 | awam dashboard par ExpiryWatch (founder patti) | Systems deck mein | F5 |
| FX-14 | ensureFounderOrg: founder ke liye awam org + mail_account banta hai | founder awam org se alag | F1a |

### FX-7 Landing page spec (login ke baad seedha yahan)
- Pehli screen: "Khush aamdeed, Nauman bhai" + waqt ke hisaab se salaam (subah/dopahar/shaam), aaj ki tareekh (Asia/Karachi).
- Top-right: "COMMAND CENTER" label; **Dashboard** button (click par decks/Bridge); profile picture menu: Profile, Passkeys/Devices, Audit, 3D toggle, Sign out.
- Motivation quote (roz ek, repo mein curated list, asli quote; koi jhoota attribution nahi).
- Aaj ka snapshot (sirf asli data, warna "connected nahi"): PAISA, KYA BIGAD RAHA HAI, AWAM KI AWAAZ (Bridge cards).
- Suggestions panel (CEO ki raaye): "aaj kya karna chahiye" top 3 (asli signal se: failed payment, expiry-watch, naye leads); audit chain status; pending approvals.
- Design: cinematic, awam UI se bilkul alag, 3D toggle hamesha.
- Command Center = user ka sab kuch yahin se (people, mail desk, systems, control) — F4-F8.

### 6z-b. Chrome live dekha (28 Oct 06:45, founderworkspace.anexomail.com, founder ka khula tab) — nayi kharabiyan
| # | Dekha | Fix | Phase |
|---|---|---|---|
| FX-15 | Founder login ke baad AWAM dashboard khulta hai ("Good morning", plan label "Business", 15 unread, awam sidebar: Mail/People/Calendar/Work/CRM/Org/Analytics/Safety/ANEXOChat/AI/Speed/Founder). Founder ek menu item hai awam app ka | founder ko seedha FX-7 landing; awam sidebar founder par nahi | F1c |
| FX-16 | `/app/founder` deck awam shell ke andar; page khud likhta hai "same session, same data, one build, no separate codebase" — FC1 ke ULTA | naya founder alag binary/host; yeh text hatao | F9 |
| FX-17 | Founder deck: Provisioned 0/10, saare mailboxes "Not created / DNS unchecked" (founder inbox bhi) + "Provision missing" button bina audit/passkey | asli halat dikhao, provision = audited one-click action | F4 |
| FX-18 | "FOUNDER PREVIEW" pill + "COMMAND CENTER" label awam dashboard par (FounderBar) — awam jaisa look | cinematic alag design | F0/F1c |
| FX-19 | Awam dashboard par "Add backup passkey" nag + Install ANEXOMAIL banner + Storage 750 GB awam widget founder par | founder par awam widget nahi; passkey = ek baar per device (FOUNDER-PROTOCOL §2b) | F1a |
| FX-20 | Boot splash "Opening your workspace" awam wala | founder ka apna cinematic boot | F0 |
| FX-21 | ExpiryWatch ("Mail TLS 65 days") awam dashboard par | Systems deck | F5 |
Achhi cheez (rakho): Expiry watch ka data (27/27 checks fine) asli server report se; dark premium look ka base.

## 7z. VISION (founder ke 4 suggestions, latest technology par) — tarteeb ke saath, abhi sirf likha
Rule 62: technology pehle. Yeh F9 ke BAAD ka roadmap hai; pehle F0b-F2 pakke. Honest note: "Elon/Starlink appeal" kisi ki tasdeeq nahi — yeh hamare apne product ki taqat ke taur par likhe hain.
| # | Idea | Technology | Hamare paas kya hai | Tarteeb |
|---|---|---|---|---|
| V1 | Append-only transparency ledger | SHA-256 chain (E102 ready) + Merkle tree (RFC 6962 style) + signed checkpoints (Ed25519), public verify WASM mein | founder_audit chain + triggers | **pehla** (F2 ke baad) |
| V2 | Data provenance (har data par signature) | Ed25519 signature + content hash + timestamp; envelope HMAC -> asymmetric (browser verify) | Rust HMAC envelope, WASM kernel | **doosra** (F2b ke saath natural) |
| V3 | ZK-proofs (data safe hone ka saboot bina data dikhaye) | Rust: arkworks/halo2 (Groth16/PLONK), verify WASM mein; pehle chhota statement ("chain mein X entries, root R, koi hata nahi") | audit Merkle root | **research spike** V1 ke baad |
| V4 | Edge/decentralised encrypted storage | content-addressed (IPFS-jaisa), client-side encryption, edge nodes; Starlink hamare control mein nahi | Storage volumes (storage.ts) | **sab se aakhir**, bari research; abhi commitment nahi |

### 6z-c. UI usool (founder 28 Oct 06:36) — FC12/FC13
"Mujhe cluster wala nahi chahiye": ek screen ek maqsad; kam cards; aankhon ko aasan (bari likhai, kam rang, khali jagah); admin mein sab kuch magar menu/decks ke peeche. Har phase: Lovable ki us page ki feature list + blueprint saath rakh kar. Phase F0b = jo repo mein hai (login, Bridge 3 cards, 6 decks, do-tap, audit) server par; F1c landing mein is usool par design polish.
