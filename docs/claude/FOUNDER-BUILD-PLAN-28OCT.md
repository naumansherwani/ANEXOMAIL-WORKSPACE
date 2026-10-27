# FOUNDER COMMAND CENTER — BUILD PLAN (phases, technology, Chrome ka sach) — 28 Oct 2026
Founder hukm (28 Oct 04:53): plan pehle, jaldi nahi, phases smooth, Bun RETIRED (founder mein Bun nahi), UI + backend technology likho, saath ke saath likhte jao (compact-safe), Chrome dekho. Isse pehle padho: FOUNDER-PROTOCOL-28OCT.md, FOUNDER-CODE-INVENTORY-28OCT.md, FOUNDER-WORKSPACE-PLAN.md (F0-F9 asli plan), TECH-STACK-BEAST.md. Koi code is plan ko founder ke dekhne se pehle nahi.

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
1. nexatect.com founder account server par hai? Wo form se login nahi ho sakta — rakhna hai (to alag login raasta) ya list se hatana?
2. UI build-time JS toolchain (React sulah, mera default) ya pure-Rust Leptos?
3. Founder service ka port/naam (F1b par live Caddy + pm2 padh kar tay hoga).
