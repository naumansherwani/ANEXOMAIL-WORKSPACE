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
| FX-22 | Founder ka mailbox aur awam-masle wale addresses (resolved@, moveyourbusiness@, hello@, billing@, noreply@, leo@) ek hi plan list mein mile hue (founder-plan.ts) | founder ka apna mailbox ALAG surface (Mail Desk F4 mein "Founder inbox"); awam-support addresses alag "Support desks" (Leo); family testers alag; sab alag provision actions | F4 |
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

## 8z. RAKHO + BEHTAR BANAO (founder hukm 28 Oct 06:38) — FC14
| Achha (purana) | Kaise behtar |
|---|---|
| Expiry-watch (27/27 checks, asli server report) | Systems deck mein, history + alert, signed data |
| Dark premium look ka base | cinematic design system (tokens), aankhon ko aasaan, kam cluster |
| Planned mailboxes (locked list: founder/family/support/AI) | asli halat + audited one-click provision |
| billing-support requireFounder (sirf founder_accounts) | wahi tareeqa Rust gate ban gaya |
| founderGate sab se pehle mount + order test | naye Rust mein bhi test |
| Release lock / checklist / deployments / roadmap, movein cockpit, CRM state, org god-view, revenue pipeline | feature-by-feature naye mein, audit ke saath (FX-3) |
| Two-tap, audit chain, E102 (naya) | Merkle + signed checkpoints (V1) |
### Frontend technology (Rule 62, locked, sab isi mein)
React 19.2 (Actions, `use`, View Transitions, `<Activity>`) · Vite · TypeScript · Three.js WebGPU (WebGL2/2D fallback) · WASM kernel (Rust, verify+audit) · WebTransport/QUIC (fetch fallback) · Web Workers + OffscreenCanvas (3D/parse thread se bahar) · Service Worker (offline shell) · WebAuthn passkey · CSS: container queries, `@layer`, `light-dark()`, `color-mix()`, popover/anchor · virtualised lists · a11y (WCAG AA, reduced-motion) · code-split per deck, FPS/LCP budget CI mein.

## 9z. HOST FAISLA (founder FINAL 28 Oct 06:46) — founderworkspace.anexomail.com hi founder ka ghar
- Naya founder usi host par: `/f/` (SPA, vite base "./") + `/founder/v1/*` (Rust :3210). `founder.anexomail.com` radd; founder.Caddyfile hata di.
- Purana awam-app founder (/app/founder*, /api/*, awam SSR) usi host par chalta rahe jab tak naye mein har feature ka ghar live na ho (FC2/Rule 65); F9 mein `/` -> `/f/` aur purane hatenge.
- Caddy: `server/caddy/founder-host.sh` + `patch-founder-host.py` (idempotent, sirf is host ka block; IP allowlist mile to ruk jata hai; validate fail = rollback). deploy-sites.sh ko nahi chhedta.
- Landing (FX-7) ke waqt: founder login ke baad `/` -> `/f/`.

## 10z. CRYPTO FINAL (founder 28 Oct 06:49) — docs/claude/founder/FOUNDER-CRYPTO-FINAL-28OCT.md
Phase tarteeb LOCKED: F0 live (/f/) -> F1a login/passkey/device/allowlist -> F2a Ed25519+HMAC+HKDF -> F2b WASM kernel enforce+SRI -> F2c audit v1 align+Merkle -> F3...
Badlav purane plan se: server->browser envelope HMAC se **Ed25519** (HMAC key browser mein rakhna = nakli data ka darwaza); HMAC ab browser->server request MAC + audit_sig.

## 11z. TECHNOLOGY PER PHASE + PULL COMMAND (Rule 66, founder 28 Oct 06:57) — LOCKED tarteeb
Pull command ke 4 qism (sab `git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:…)`):
- **[SQL]** `docs/cursor-work/server/sql-run.sh` (aakhir mein `<sql_naam> CHECK_<n>`)
- **[BUILD]** `docs/cursor-work/server/founder-install.sh` (Rust test+build+SPA dist)
- **[CADDY]** `server/caddy/founder-host.sh`
- **[WEB]** awam `pull.sh` — SIRF F9 (awam app se purani files hatane par)
| Phase | Technology | Kaun se codes | Pull |
|---|---|---|---|
| **F0** ✅ LIVE 28 Oct 06:58 (login screen /f/ Chrome par dikha; server 28 tests, SPA/healthz 200, me/bridge 401) | Rust (axum+tokio), React 19.2 + Vite static SPA, Three.js (WebGPU->WebGL2->2D), Caddy | server/founder/*, founder-web/*, founder-host.sh | [BUILD] [CADDY] done |
| **F1a** Login+passkey+device | Rust `webauthn-rs`, `jwt_core` ES256 (aud=anexo-founder), lockout, IP allowlist (Rust+Caddy), Postgres (founder_devices) | login.rs/passkey.rs/devices.rs, E104 SQL+CHECK_E104, SPA login (passkey once/device) | [SQL] [BUILD] [CADDY] |
| **F1c** Landing (FX-7) | React 19.2 (View Transitions, Actions), CSS `@layer`/container queries/`light-dark()`, Three.js | Landing.jsx (welcome, quote, COMMAND CENTER, profile menu), styles | [BUILD] |
| **F2a** Signing | Rust `ed25519-dalek`, `hmac`, `hkdf`, `sha2`, `subtle`; signing key file 0400 | sign.rs (Ed25519 envelope bytes), request-HMAC verify, HKDF session key; key-gen step (server) | [BUILD] (+ ek key-gen command) |
| **F2b** WASM kernel | Rust -> wasm32 (`server/founder-kernel`), wasm-bindgen, Web Worker, SRI SHA-256 | founder-kernel crate (verify_envelope, hmac, hkdf, chain/merkle verify), tests RFC vectors, SPA enforce | [BUILD] |
| **F2c** Audit v1 + Merkle | Postgres (pgcrypto SHA-256), Rust, WASM verify | E105 SQL (Merkle checkpoints)+CHECK_E105, audit.rs v1 align | [SQL] [BUILD] |
| **F3 Money** | Rust Polar/Supabase reader, SQL views (read-only), React deck, Web Worker charts | bridge money, MRR/ARR, dunning, mismatch | [SQL?] [BUILD] |
| **F4 People + Mail Desk** | Rust (orgs/users/mailboxes), SQL actions, mail server interface (audited provision), founder inbox alag (FX-22) | people.rs, maildesk.rs, E10x if needed | [SQL?] [BUILD] |
| **F5 Systems** | Rust systemd/expiry-watch reader, glitch/perf/security readers, signed data | systems.rs, deck | [BUILD] |
| **F6 Control + one-click** | Rust action engine, WebAuthn step-up + two-tap, `founder_actions` (E102) | actions executors per action, wajah+audit | [SQL?] [BUILD] |
| **F7 3D** | Three.js WebGPU, OffscreenCanvas + Workers, lazy chunks, 2D fallback, FPS budget | Scene modules (globe/topology/flow) | [BUILD] |
| **F8 Executor** | Rust executor (allow-listed commands), systemd, audit | executor.rs, enable actions in DB | [SQL] [BUILD] |
| **F9 Cutover** | Caddy final block (sirf Rust), git rm legacy, awam rebuild | purani 36 routes+FounderBar+gates hatao, FOUNDER_PASSWORD hatao, `/`->`/f/` | [CADDY] [WEB] [BUILD] |
| **V1-V4** | Merkle/Ed25519/ZK(halo2)/edge | §7z | alag faisla |
Rule: har phase ka exit = tests + server saboot + Chrome live (Rule 64). Is table ko phase se pehle update karna lazmi.

### FX-23 (Chrome live, 06:58): `/f/` login card screen ke TOP-LEFT mein chipka hua — center nahi, cinematic nahi. Fix F1c (login ka design: center, bada type, aankhon ko aasaan). Login form asli (awam jaisa nahi) — theek.

### FX-24 (founder 28 Oct 06:58): /f/ ka text Roman Urdu tha aur card ajeeb — "pehle wala English jo user ko milta hai woh sahi". Fix: poori founder SPA ka copy English (Rule 67), look = purane achhe dark-premium ka behtar version; /app (purana) bilkul nahi chheda gaya, intact hai. Phase: pehla chhota fix (copy+centering) F0-polish, phir F1a.

### F0-polish (28 Oct 07:05) — DONE in repo: SPA copy poora English + login card center (desktop/mobile Playwright: card centered, 0 JS errors, no h-scroll); Rust messages English (28 tests ok); E103 SQL = founder_actions titles English (+CHECK_E103; sandbox PG16: E102 9/9, E103 3/3, dobara chalana safe). Technology: React/Vite + Rust + Postgres. Pull: [SQL] sql-run.sh (bare, phir `E103_founder_actions_english CHECK_E103`) + [BUILD] founder-install.sh. (F1a ki SQL ab E104, F2c ki E105.)

## 12z. LOGIN FAISLA (founder 28 Oct 07:03): "jo login existing hai woh like karta hoon wohi rahega" — Rule 68
- Existing /auth login (UI+passkey+recovery) UNTOUCHED, founderworkspace par founder ka front door.
- FX-6 REVISED: "alag login page" ki jagah **alag host-rule + token exchange**: (1) awam hosts par founder login refuse (host check, auth.ts) — loophole band; (2) `/f/` bina session ke -> `/auth?next=/f/`; (3) login ke baad /f/ maujooda session se `POST /founder/v1/exchange` -> founder-scoped short token (aud=anexo-founder, 15 min, memory only, uid in founder_accounts, device approved); (4) /f/ ka apna password form + `/founder/v1/login` F1a ke baad hata diya jaye (ya sirf dev).
- Maujooda session token awam app ki localStorage mein hai (wahi purani halat, hum behtar nahi kar rahe); naya founder token memory-only — FC15 safe.
- FOUNDER_PASSWORD env-path (auth.ts) alag cheez: founder passkey-proof ke baad hata dena (FX-1). Aap ka login-UI nahi badalta.
- Phase: F1a (technology: Rust jwt_core + `/exchange` + founder_devices SQL E104 + auth.ts host-gate + /f/ redirect). Pull: [SQL] [BUILD] + [WEB] (auth.ts awam server change => Bun restart: awam pull.sh) — F1a ki pull command wahin dunga.

### 12z-b. Chrome live: existing login dekha (28 Oct 07:08, founderworkspace.anexomail.com/auth)
Achha (rakho, jaisa hai): "Sign in — Your mail, people, calendar and work — one surface.", Email `yourname@anexomail.com`, Password (eye), Sign in, "Continue with a passkey", "Email me a sign-in link", "Lost your passkey? Use a recovery code", left cinema panel ("Mail when it matters.").
Kharabi (founder host par awam cheezein): 
| # | Dekha | Fix | Phase |
|---|---|---|---|
| FX-25 | "New here? Create your account for workspace" — founder host par awam SIGNUP khula | founder host par signup link/route band (isFounderHost() par hide + server refuse) | F1a |
| FX-26 | "Save password" checkbox + "Forgot your password?" (awam flows) founder host par | founder host par hata do; recovery sirf passkey+recovery code (founder ke liye password reset = founder khud server se) | F1a |
| FX-27 | "FOUNDER PREVIEW" pill login par bhi | hata do (sirf founder host hai, preview ka matlab nahi) | F1a |
Login ka look/flow NAHI badalta (Rule 68) — sirf in teen awam cheezon ka founder host par hide.

### 12z-c. NAYA LOGIN HATA DIYA (founder 28 Oct 07:12: "existing login like karta hoon, tumne jo naya login banaya woh nahi hoga")
- /f/ SPA se apna email/password form POORA hata diya. Ab: session nahi to sirf ek saaf screen "Command Center — Go to sign in" jo maujooda `/auth` par bhejti hai. Session hai to Bridge seedha.
- Token: SPA sirf maujooda login ka token PADHTI hai (localStorage `anexo.session.token`, kabhi likhti/copy nahi), Rust usay verify karta hai (ES256 + founder_accounts, 403 = founder nahi). Playwright: gate / bridge (stub) / 401->gate, 0 JS errors.
- Rust `/founder/v1/login` endpoint ab UI se bilkul nahi judta (dead) — F1a mein hata diya jaye (/founder/v1/exchange aayega).
- Chhoti kami (F1a): login ke baad /auth seedha /app bhejta hai (`next` support nahi) — founder /f/ bookmark se kholta hai; F1a mein `?next=/f/` support.

### 12z-d. FX-25/26/27 FIXED in repo (28 Oct 07:20) — [WEB] technology (awam React app, auth.tsx + FounderBar.tsx)
Founder host (isFounderHost) par /auth se HIDE: "New here? Create your account…" (FX-25), "Save password" checkbox + "Forgot your password?" (FX-26), "FOUNDER PREVIEW" pill (FX-27). Login ka baqi design/flow bilkul waisa (passkey, email link, recovery code). Awam host (anexomail.com) par kuch nahi badla. tsc 0 error. Pull: [WEB] pull.sh. Server-side signup refuse F1a mein (abhi sirf UI hide, founder ke hukm ke mutabiq "sirf yeh").

### E103 SUPER-ADVANCED (28 Oct 07:30, founder hukm "sql 103 super advance"): sirf "English titles" nahi — 
(1) advisory-lock + preflight SKIP, (2) updated_at/text_rev columns, (3) English text sirf jo badle (`IS DISTINCT FROM`, dobara chalane par 0 rows), (4) text constraint NOT VALID->VALIDATE (printable ASCII, title 3..60, summary 3..200), (5) **SAFETY RATCHET** trigger: key/deck immutable; danger sirf badhta; passkey/two-tap sirf on; reversible sirf kam, (5b) **DELETE/TRUNCATE band** — Supabase default privileges service_role ko DELETE dete the: E102 ka asli gap (delete+reinsert se ratchet bypass) — revoke + trigger, (6) `founder_actions_selftest()` (rollback). CHECK_E103 = 8 rows. Sandbox PG16: E102 9/9, E103 8/8, dobara chalana safe, service_role ke delete/truncate/danger-kam = ERROR.

### 12z-e. /founderlogin (founder 28 Oct 07:22: "founderworkspace.anexomail.com/founderlogin ana tha") — [WEB] + [BUILD]
- `src/routes/founderlogin.tsx` = maujooda AuthPage (EXACT wohi sign-in UI: cinema panel, passkey, email link, recovery code) `founderLogin` mode mein. Founder host par awam extras hide (FX-25/26/27). Login ke baad `window.location.assign("/f/")`; is_founder na ho to session saaf + "This sign-in is for the founder account only."; awam hosts par `/` par redirect. Already-signed-in founder -> seedha /f/.
- `/f/` gate ab "Go to founder sign in" -> /founderlogin; login ke baad khud /f/ par aata hai (`?next` ki zaroorat khatam).
- routeTree.gen.ts regenerate (vite build ok), tsc 0 error. Caddy badlav NAHI (/founderlogin default app handle se jata hai).
- Chrome live test pull ke baad.

### 12z-f. "/f/" KHATAM (founder 28 Oct 07:40: "yeh end ka f khatam kero, i hate it") — Command Center ab `https://founderworkspace.anexomail.com/` (root)
- Caddy v2 snippet (founder-host.sh/patch-founder-host.py, v1->v2 auto-upgrade, sandbox-tested): `/` -> Rust (Command Center), `/_cc/*` -> Rust (assets, prefix strip), `/founder/v1/*` -> Rust, `/f` & `/f/` -> 308 `/`. Purana awam-app `/app`, `/auth`, `/founderlogin` waise hi.
- SPA vite `base: "/_cc/"` (assets purani app ke /assets se takrao nahi); login ke baad `window.location.assign("/")`; /f/ wali har jagah "/" hui.
- Test (Node stub Caddy-jaisa + Playwright): `/` gate, token ke saath Bridge, link /founderlogin, 0 JS error, 0 failed request.
- Pull TARTEEB (lazmi): [WEB] -> [BUILD] -> [CADDY]. BUILD CADDY se PEHLE (warna naya `/` purane relative-asset build ko serve karega).

## 13z. FOUNDER-ADVANCED-FEATURES (33 features) -> locked phase order (28 Oct 08:20; plan wins on any clash)
Source list: `docs/claude/FOUNDER-ADVANCED-FEATURES-28OCT.md` (A-H). That file uses an older F-numbering; the LOCKED order here (§11z) is the one that counts. Technology everywhere: Rust anexomail-founder + React SPA + WASM kernel, Bun/Node never.
| Features | Phase here | Pull type |
|---|---|---|
| A1-A5 Bridge (5-sec fold, live push, Cmd-K, tamper-visible, attention engine) | F2a-F2c (crypto + kernel), then Bridge polish | Rust+SPA (`founder-install.sh`); A4 needs F2b kernel |
| B6-B10 Money (Polar MRR/ARR read-only, churn, mismatch, forecast, biggest leak) | F3 | SQL + Rust + SPA |
| C11-C14 People (360, abuse board, two-tap powers, appeals) | F4 | SQL + Rust + SPA; metadata-only test |
| D15-D18 Mail Desk (unified inbox, deliverability cockpit, LEO draft, SLA) | F4 (Mail Desk) | SQL + Rust + SPA |
| F22-F24 Systems (probes, capacity, DNS/cert/backup) | F5 | Rust + SPA |
| G25-G27 Control (kill switches, audit viewer, break-glass log) + E19-E21 Release (deploy history, canary, gate) | F6 (+ F8 executor for deploy/rollback) | SQL + Rust + SPA |
| H28 3D topology | F7 | SPA (Three.js WebGPU, 2D fallback) |
| H29-H33 voice, incident replay, PWA, copilot, kernel truth | after F9, one by one on founder "yes" | per feature |
Already in the blueprint before this list: Cmd-K, forecast, appeals, kill switch, break-glass, PWA, topology, SLA, abuse, dunning, ExpiryWatch, mismatch. NEW from this list: canary rollout, incident replay, ask-anything copilot, deliverability cockpit, voice command.

## 13z-b. Sign-in default + chairman level (founder 28 Oct 08:12)
- Default entry = `founderworkspace.anexomail.com/founderlogin` (existing page, Rule 68): `/` without a session redirects there; `/auth` on the founder host redirects there. A stale token shows the gate card (no redirect loop).
- Founder sign-in: existing page INTACT (founder 08:16 rejected the dot-network animation). Only "Founder protocol / Welcome, Founder" above it + activating/activated screen.
- "FOUNDER PREVIEW" pill REMOVED from the founder host everywhere (FounderBar OFF state returns nothing).
- Chairman level = the founder lands on the Command Center, not an awam business page. The old `/app` stays reachable (Workspace link) until F9 cutover.

## 13z-c. THE 33 FEATURES IN BUILD ORDER — technology written next to each (founder 28 Oct 08:24; Rule 62/64/66)
Rule: one phase at a time, each green + seen live in Chrome before the next. Order follows DEPENDENCIES (trust first, then money, then people ...). Common base for every row: Rust `anexomail-founder` (axum + tokio, forbid(unsafe)) + Postgres/Supabase (RLS on) + React 19 SPA; pull = `all-pull.sh` / the matching single script. "No data = Not measured" (Rule 63).
**Foundation before any feature (not in the 33):** F1a (E104 devices SQL, `/founder/v1/exchange`, awam-host refusal, signup refusal, remove `/founder/v1/login`) -> F2a (Ed25519 sign + HMAC/HKDF, Rust: ed25519-dalek, hmac, hkdf, sha2) -> F2b (WASM kernel) -> F2c (audit v1 align + Merkle, SQL E105).
| # | Feature | Phase | Technology used here (and why) |
|---|---|---|---|
| 1 | A4 Tamper-visible data | F2b | Rust signs every answer (Ed25519); WASM kernel (Rust->wasm32, ed25519-dalek + sha2, SRI-pinned) verifies BEFORE parsing; UI shows TAMPERED. Everything below depends on this. |
| 2 | H33 Kernel usage truth | F2b | SPA reads `anexoKernel.stats` (Rule 52). Tiny; proves the kernel runs. |
| 3 | G26 Audit viewer | F2c | SQL `founder_audit` hash chain + Merkle root (E105); kernel re-computes SHA-256 chain in the browser; SPA virtualised list. |
| 4 | A5 Attention engine | F2 Bridge | Rust pure ranking function over real metric tables (error rate, bounce, failed payment, appeal age); unit-tested; NO AI, no guessing. |
| 5 | A1 5-second fold | F2 Bridge | SPA (React + Motion); numbers from `/founder/v1/bridge`; 3D stays optional behind the toggle. |
| 6 | A2 Live push | F2 Bridge | Rust: poll-with-change-detect (or Postgres LISTEN on a session-mode connection — verify first, Supabase Realtime is banned) -> tokio `broadcast` -> axum SSE now; WebTransport (wtransport) once the kernel is in. |
| 7 | A3 Cmd-K | F2 Bridge | SPA command palette; fixed command grammar + fuzzy match (kernel `rank`) mapped to the `founder_actions` registry (E102/E103); every action two-tap + reason + audit. Natural-language/LLM is NOT here (see #31). |
| 8 | B6 Real MRR/ARR | F3 | SQL views over the tables the Polar webhook already fills (webhook untouched, Rule 4); Rust reads only. Polar API (reqwest + rustls, read-only token in founder.env, never in repo) only for reconciliation. |
| 9 | B8 Mismatch alert | F3 | SQL view: `revenue_accounts` vs webhook-fed totals; Rust serves; red when different, never a fake 0. |
| 10 | B7 Churn + failed payments | F3 | SQL views; actions (reminder mail, extend grace) via existing Rust mail proc + two-tap + audit. |
| 11 | B10 Biggest leak | F3 | SQL aggregate over the ledger, ranked; one number + proof rows. |
| 12 | B9 Forecast | F3 | Rust deterministic (trend of last N months, labelled "estimate", range shown); no ML. |
| 13 | C11 User/Org 360 | F4 | SQL views with a column allow-list (metadata only); a Rust test greps every query so no content table/column can ever be selected. |
| 14 | C13 Two-tap powers | F4 | Rust -> Supabase auth admin (service key, server only) for suspend/sign-out/device revoke; `founder_actions` ratchet + audit chain. |
| 15 | C14 Appeals queue | F4 | SQL table (RLS on, append-only decisions) + Rust + SPA queue. |
| 16 | C12 Abuse scoring | F4 | Rust scoring over the vault device-shape signals (Rule 45; never IP); review queue only, no auto-block. |
| 17 | D15 Unified company inbox | F4 Mail Desk | Rust reads through the existing mail procs (Dovecot/Postfix untouched); address badge; founder inbox separate (locked identities). |
| 18 | D18 SLA clock | F4 Mail Desk | SQL timestamps + Rust calc; shows where the 24h is breached. |
| 19 | D16 Deliverability cockpit | F4 Mail Desk | Rust: hickory-resolver for SPF/DKIM/DMARC; Postfix `mail.log` bounce/complaint counts; failed-sends re-queue via the existing proc. |
| 20 | F22 Real health probes | F5 | Rust tokio concurrent probes (HTTP + TCP connect to Postfix/Dovecot ports, systemd status); a blind spot is printed as "not probed". |
| 21 | F24 DNS/cert/backup board | F5 | Rust: hickory (DNS), x509-parser on the TLS handshake (cert expiry), backup file mtime/ledger; ExpiryWatch (FX-13). |
| 22 | F23 Capacity + cost | F5 | Rust `sysinfo` (disk/mem/cpu); Supabase/Hetzner usage only if a read-only API token is provided, else "Not measured". |
| 23 | G25 Kill switches / flags | F6 | SQL `feature_flags` (RLS on) + Rust endpoints + audit. NOTE: making the awam app READ the flags touches awam Rust/Web (Rule 35 no-touch) — needs your "yes" as a separate step. |
| 24 | G27 Break-glass log | F6 | SQL append-only log + Rust; there is no access path, it only records attempts. |
| 25 | E21 Release gate | F6 | Rust read-only checks (health, migration count, kernel pin SHA) before a release is allowed. |
| 26 | E19 Deploy history | F6 | The deploy scripts write a row (sha, exit, health) to SQL; SPA timeline. |
| 27 | E20 Canary + instant rollback | F6 + F8 | Needs #23 (percent flags) + F8 executor (tiny allow-listed privileged Rust binary, no shell input, systemd). Last of the control block. |
| 28 | H28 3D topology globe | F7 | Three.js WebGPU + TSL, lazy chunk, 2D fallback, 60fps budget; draws data from #20-#22, never the source of truth. |
| 29 | H30 Incident replay | after F9 | SQL audit chain + metrics history; SPA timeline scrubber (Motion/GSAP); kernel verifies the chain it replays. |
| 30 | H31 Founder mobile PWA | after F9 | Vite PWA + service worker; offline = view-only of the LAST signed snapshot (no actions offline); 390/820/1440 (Rule 34). |
| 31 | H32 Ask-anything copilot | after F9 | Rust picks from FIXED read-only query templates (never free-text SQL); a model only chooses the template; content questions refused. BLOCKED by Rule 23 (AI closed) until you lift it. |
| 32 | D17 LEO draft | after F9 | Same block as #31: LEO is the AI surface (Rule 23). Until lifted: template drafts only; you always press send. |
| 33 | H29 Voice command | after F9 | Kernel module: on-device speech-to-text (whisper.cpp -> WASM, model downloaded once, SRI-pinned), audio never leaves the browser; Rule 52 version bump. Browser Web Speech API is NOT used (sends audio to a third party). |
**Founder decisions still needed (asked once, when we reach them):** (a) #23 awam app reading flags = touches no-touch Rust/Web; (b) Polar read-only API token for reconciliation (#8); (c) Rule 23 lift for #31/#32.


## 14z. FOUNDER CEO ORDER + POLAR LIVE SYSTEM (founder 28 Oct 10:10 PKT) — LOCKED addition, detail: docs/claude/FOUNDER-NEEDS-ORDER-28OCT.md
Founder ka hukm: yeh sab baatein blueprint mein tarteeb se; Polar ke endpoint se connect; WASM kernel + Rust + tokio async.

### Technology (Rule 62/66) — ek hi rasta
Polar API (read-only, `metrics:read` token) -> **Rust tokio poller** (`server/founder/src/polar.rs`, GET only, 60 s, backoff, last-good + stale flag) -> `tokio::sync::watch` change feed -> signed envelope (HMAC now; Ed25519 F2a) -> fetch now / WebTransport push (F2) -> **WASM kernel verifies in browser (F2b, enforce + SRI)** -> React SPA. Polar :3400 webhook engine NO-TOUCH; payment/webhook token kabhi nahi, sirf alag read-only token (`founder-polar.sh` server par chhupa kar leti hai; chat mein token nahi).
Verified Polar API: `GET https://api.polar.sh/v1/metrics/` (start_date, end_date, interval, metrics[]) scope `metrics:read`; amounts cents; slugs monthly_recurring_revenue, active_subscriptions, new_subscriptions, canceled_subscriptions, revenue. Subscriptions list/orders: scope verify karke F3 mein (failed payments, churn rows).

### Tarteeb (har ek proved live, phir agla — FC8)
| # | Phase | Kaam | Technology | Pull |
|---|---|---|---|---|
| 1 | F1a-1 | device approval + founder token exchange | SQL E104 (done on server) + Rust + SPA | founder-install.sh |
| 2 | **F3-a (built 28 Oct)** | **Polar read-only reader**: `/founder/v1/finance/polar`, bridge.polar, card "BILLING · POLAR", greeting strip; no token = "not connected" | Rust tokio + SPA | founder-install.sh, phir founder-polar.sh |
| 3 | F1a-2 | awam hosts founder login refuse | awam web | pull.sh |
| 4 | F2a/b/c (+ founder Settings S1; S2 after F2c — full plan: FOUNDER-SETTINGS-CENTER-PORT-28OCT.md) (+ founder Settings page, founder faisla 28 Oct 11:24: Settings F2a ke saath banegi) | Ed25519 + request HMAC/HKDF, WASM kernel verify, audit v1 + Merkle; Settings = security (device status, sign-out), graphics, notifications, theme | Rust + WASM + SQL E105 | founder-install.sh, sql-run.sh |
| 5 | F2-d | **Decide (N)** one button: wrong things + permissions queue | SQL (10/10, FC27) + Rust + SPA | sql-run.sh, founder-install.sh |
| 6 | F2-e | **Live Pulse** (signed-in now/today/week, sign-ups, failed logins, plan, device class; real vs Test accounts split) pushed by tokio broadcast -> WebTransport/SSE | SQL + Rust tokio + SPA | same |
| 7 | F3-b | Polar failed payments, churn rows, mismatch vs revenue_accounts, forecast | Rust + SQL views | same |
| 8 | F4 People, F5 Mail Desk, F6 Systems, F8 Control, F9 cutover | as plan | | |
| 9 | Founder desk | Docs + Sheets (Collabora/OnlyOffice via WOPI; engine choice pending licence read) | separate sandbox service + Rust WOPI | later |
Responsive: har phase 390 / 820 / 1440 par proof (Rule 34). Sab data authentic (FC26).
