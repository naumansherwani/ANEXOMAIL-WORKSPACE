# FOUNDER WORKSPACE — "HQ" (plan, locked 21 Oct 2026, founder: Muhammad Nauman Sherwani)

> **FOUNDER KA HUKM (21 Oct 08:15, LOCKED): "Main kabhi kisi user ki privacy breach nahi karunga." => customer ka mail/file CONTENT founder workspace mein KABHI nahi dikhta (break-glass bhi nahi). Founder side tab shuru hogi jab B-series poori GREEN ho.**
> Status: **PLAN ONLY.** Build starts AFTER B-series (B5–B8) is complete. Nothing here is deployed.
> Founder ka hukm (21 Oct 08:12): "main admin hoon, mere pas God ke baad wali powers hain, har user ko dekh sakta hoon, kaun kaam kharab kar raha hai,
> mails ke jawab dunga, duniya ka advanced 3D frontend, tokio async, sab repo mein tarteeb se phases ke saath. Bun/Node founder mein kahin nahi."
> Compact-safe: yeh file + `/home/claude/sandbox-state/` copy + DONE-DO-NOT-REPEAT.md mein entry.

## 0. Ek line mein
Founder host par ek **akela Rust-only** mission-control: Rust server (tokio/axum) + Rust frontend (Leptos 0.8 SSR + WebAssembly, WebGPU 3D),
jahan se founder poori ANEXOMAIL **dekhta, samajhta, faisla karta aur jawab deta** hai. Dashboard nahi — **command bridge**.

## 1. Locked usool
1. **No Bun, no Node, no npm** founder host par. Build = `cargo` (+ wasm-bindgen). Runtime = ek Rust binary, alag pm2 process, sirf founder host, IP allowlist ke peeche.
2. **Data ek jagah se:** Rust engine (`/rpc/founder.*`). Founder UI sirf dikhata aur hukm bhejta hai; business rule UI mein kabhi nahi (jaise `attention` rules `b5_core.rs` mein, unit-tested).
3. **Sach pehle:** jo naapa nahi gaya wahan "Not measured". Jhoota "sab theek" kabhi nahi. Har number ke saath uska source aur umar (kitni purani reading).
4. **Do-tap rule:** paisa, delete, lock, release, kill-switch, user suspend — hamesha do-tap confirm + reason + audit row.
5. **Audit sab kuch:** founder ka har dekhna-karna `founder_audit` (append-only, hash-chained) mein. Founder khud bhi apne aap ko jawabdeh rakhe.
6. **Founder view ≠ andha content-access.** (neeche §3) — yeh founder ki hifazat hai (UK GDPR, ICO) aur customers ka bharosa.
7. **Fast hai to hi premium:** budgets: first paint < 1.0 s (4G), live update < 300 ms, WASM bundle gz < 600 KB core (3D alag, lazy).
8. **Har phase:** sandbox proof → founder ka server output → tab hi GREEN (founder rule). Har phase ke saath frontend 390/820/1440 check.

## 2. Technology (latest, Node-free)
| Layer | Choice | Kyun |
|---|---|---|
| Server | Rust, tokio multi-thread, axum 0.8, `tower` middleware | async end-to-end; concurrency `JoinSet`, backpressure, graceful shutdown |
| Frontend | **Leptos 0.8** (SSR + hydrate, fine-grained signals), `leptos_router` | Rust-only UI, no VDOM, tiny re-render cost |
| 3D | **wgpu → WebGPU** (WebGL2 fallback), WGSL shaders, instanced rendering; scene state in Rust | duniya ka advanced browser GPU path; same Rust code |
| Live | WebTransport (datagrams+streams) primary, SSE fallback; server push on change (event-driven, B4 pattern) | refresh kabhi nahi |
| Style | modern CSS: `@layer`, container queries, `oklch`, view transitions, popover/anchor positioning, `prefers-reduced-motion`, `prefers-color-scheme` | koi CSS framework/Node tool nahi |
| Auth | Supabase JWT (JWKS, local verify as `jwt_core`) + **passkey (WebAuthn)** + device gate + IP allowlist | purana `FOUNDER_PASSWORD` plain compare (A5) khatam |
| Data | Supabase #4 via Rust engine; tenant-wide reads via founder-only RPC/views | ek source of truth |
| Build | `cargo` + `wasm32-unknown-unknown` + `wasm-bindgen` (sandbox mein build, server ko tayyar artifact) | server par bhari build nahi (mail safe) |
| Test | `cargo test`, sandbox mock Supabase + real binary (b5 pattern), headless Chromium screenshots 390/820/1440 | "green sirf proof ke baad" |

Feasibility (sandbox, checked 21 Oct): Leptos 0.8 + `wasm32` target yahan mil jate hain (NO_PROXY clear karna padta hai); 2 cores / 5 GB disk free => build sandbox mein, artifact server par.


## 2b. FOUNDER KA STACK (founder ne diya, 21 Oct 08:25 — repo mein darj; is se upar §2 ki jagah yeh WINS jahan takrao ho)
**Edge:** Caddy reverse proxy; HTTPS + **HTTP/3** dual-stack (low-latency handshake).
**Frontend/Client UI:** React 19.2 · Vite 8.2 · TanStack Start v1 + TanStack Router 1.17 (type-safe routing) · Tailwind CSS v4.2 · Radix UI + shadcn/ui · **Three.js** (3D workspace) · Framer Motion + GSAP (premium micro-interactions).
**Rust SSE/live:** Rust se push -> "webpage khudi refresh ho jaye ga" (SSE/WebTransport; page refresh ke baghair khud update).
**Backend:** Rust (tokio async), Supabase, Polar (NO TOUCH) — jo pehle se hai.

### TAKRAO jo founder ko batana hai (mera faisla nahi, tumhara)
Pehle hukm: "founder mein Bun/Node kahin nahi". Ab frontend stack React/Vite/TanStack Start — yeh Node-tooling hai (Vite build Node par chalta hai; TanStack Start SSR runtime Node/Bun par).
**Meri sulah (dono hukm poore):** React/Vite/TanStack/Tailwind/shadcn/Three.js/Framer/GSAP **build-time par** sandbox/CI mein build -> **static SPA assets** -> founder host par **sirf Rust binary** unhein serve kare (SPA mode, TanStack Start SSR runtime nahi) + Rust SSE/WebTransport live refresh. Server par na Node na Bun chalta hai, phir bhi frontend wohi world-class stack. (Leptos/wgpu wala §2 option badal sakta hai agar founder pure-Rust chahe.)
Founder se ek lafz chahiye: **"sulah theek"** ya **"pure Rust (Leptos)"**. Tab tak F0 design dono ke liye ek jaisa (tokens/mock) hai.

## 2c. Email addresses (founder ka hukm 21 Oct 08:25) — ALAG kaam, B6 + B-series ke BAAD
Repo ki list `src/lib/founder-plan.ts` (PLANNED_MAILBOXES, 10 address): naumansherwani.founder@, humzasherwani@, raanasherwani@, masoodsherwani@, resolved@, moveyourbusiness@, hello@, billing@, noreply@, leo@ (anexomail.com).
Kaam: har address **build (provision) + working wire** (Postfix/Dovecot/DKIM/inbound->app/send), server par proof ke saath. Founder ka alag email system bhi. Nexatect (parent company) ke addresses uske baad.

## 3. Founder view — metadata-only (privacy locked)
> Naam: "God view" ki jagah **Founder view** (founder ka hukm 21 Oct 08:20).
> **Email:** founder ka ALAG email system (apna). ANEXOMAIL ke baqi banaye hue addresses (founder@, support@, leads@ ...) aur parent company **Nexatect** ke addresses BAAD ka kaam hain (phase F5+ ke baad), abhi scope mein nahi.
**Level 1 — Operational (hamesha on):** har user/org: plan, seats, state, trial, last seen, devices, storage, mailboxes, DNS health, send volume, bounce/complaint rate,
failed logins, payment state, support tickets, abuse score, security events. Search "kaun kaam kharab kar raha hai": spam/abuse ranking, bounce spikes, impossible-travel, credential stuffing, bulk-send, storage hogs.
**Level 2 — Actions:** suspend/restore, rate-limit, force sign-out, revoke device, reset MFA, extend trial, comp plan, refund request, kill switch (per user/org/global), IP block. Do-tap + reason + audit.
**Level 3 — Content: HAMESHA BAND (founder ka locked hukm).** Mail/file/calendar content, subject, contact list founder ko kabhi nahi dikhta. Sirf metadata (counts, sizes, rates, health, security events). Support ke liye customer khud kisi ticket mein share kare to wahi dikhta hai jo usne share kiya.
Kyun: customer privacy hi product hai (UK GDPR). Code mein bhi enforce: founder RPCs ke SELECT mein content columns hain hi nahi, aur test unhein dhoondta hai.

## 4. Screens ("decks")
1. **Bridge (home):** "Right now" ranked decisions (Rust `attention`), 3D live system, paisa vs target, light (green/amber/red).
2. **Money:** MRR/ARR, target gap, pipeline, leads, Priority Support, partner commission, move-in cash, refunds, cohort/churn, forecast.
3. **People (Founder view):** global search, user/org 360°, abuse board, timeline, actions (§3).
4. **Mail Desk:** founder ka apna inbox + **support/leads inbox** — reply yahin se; AI draft (Leo) + tone/translate, canned replies, SLA clock, snooze, assign, "reply & close", bulk triage. (Mail send/Rust queue B3 pehle se.)
5. **Release:** QA run, blockers, lock, deployments, rollback button, canary.
6. **Move-In:** migrations board, cutover tonight, evidence bundle, cash.
7. **Systems:** Brain/Rust/Caddy/Postfix/Dovecot/DB health, certificates expiry, DNS (SPF/DKIM/DMARC/MTA-STS), queue depth, backups, disk, error budget, incident log.
8. **AI:** Leo kaam, receipts, cost, prompts, kill switch.
9. **Control:** founder settings, feature flags, kill switches, audit log viewer, access (IP/passkeys), break-glass log.
10. **Command bar (Ctrl/Cmd-K):** koi bhi user/org/page/action; "suspend user X", "show failing sends" — natural-language + typed commands.

## 5. 3D / "duniya ka advanced" frontend
Sab WebGPU (wgpu), 60 fps, kam power; mobile par automatic 2D/low-detail; `prefers-reduced-motion` par static.
- **Globe:** live users/sends/logins as instanced points + great-circle arcs (mail flow), threat heat.
- **System topology:** services (Brain, Rust, Caddy, Postfix, DB…) 3D graph; edges = live traffic; node colour = health; click = drill-down.
- **Mail flow rivers:** inbound/outbound particles, bounces as red sparks; queue depth as volume.
- **Money terrain:** MRR/pipeline as height-field; target plane; gap visible.
- **Depth UI:** parallax cards, view-transition morphs between decks, spatial audio-free (no sound by default).
- Rules: lazy-load (3D bundle alag), GPU memory budget, FPS auto-downgrade, a11y: sab 3D ka text/table equivalent hamesha.

## 6. Tokio / async architecture
- `tokio` multi-thread runtime; har data source `JoinSet` concurrent fetch with per-source timeout (3 s) → ek source fail = blind-spot, 500 nahi.
- Change feed: Postgres `LISTEN/NOTIFY` (ya Supabase realtime) → `tokio::sync::broadcast` → WebTransport/SSE fan-out; debounce/coalesce 100 ms.
- Bounded channels + backpressure; `tokio::select!` graceful shutdown; request-scoped tracing (`tracing`), `/metrics`.
- Cache: short TTL (5–20 s) + stale-while-revalidate; reads never block writes.
- Writes: idempotency keys (outbox pattern as B5 `outbox.send`), `RUN_IN_FLIGHT`-style single-flight for heavy jobs (QA run).

## 7. Phases (build tarteeb) — **sab B-series ke BAAD**
| Phase | Kya | Proof/exit |
|---|---|---|
| **F0 Design** | design system (tokens, components, motion), 3 breakpoints mock + 3D concept clips; founder approval | screenshots 390/820/1440 founder ne manzoor kiye. Kuch deploy nahi |
| **F1 Foundation** | crate `server/founder/` (axum+Leptos), auth (JWT + passkey + IP + device), shell, nav, command bar, audit table, live channel, Caddy route (live file dekh kar) | login → empty shell live, audit row, 401/403 tests, sandbox PASS |
| **F2 Bridge** | Command Center (data = `founder.brain.command`), light, ranked list, tiles, live push | seeded-truth proof (b5 4b pattern) + 3 screenshots |
| **F3 Money + Release** | pages 2 & 5 (Rust procs already B5) | differential vs old pages |
| **F4 People (Founder view L1+L2)** | new RPCs `founder.people.*`, abuse scoring (pure core, tested), actions + audit | hostile tests, audit hash-chain verify |
| **F5 Mail Desk** | founder inbox/support desk, reply, AI draft, SLA | send via Rust queue, idempotency, undo-send |
| **F6 Systems + Move-In** | pages 6 & 7 | probes real, blind-spot honest |
| **F7 3D** | globe, topology, flow, terrain (WebGPU) | FPS budget, fallback 2D, a11y tables |
| **F8 Control + AI** | kill switches, flags, audit viewer; test: koi founder RPC content column nahi padhta | audit tamper test + no-content grep test |
| **F9 Cutover** | purane React founder pages band, root redirect, docs, runbook | server==repo, old routes 301/404 |

## 8. Founder se faisle (jab F0 shuru ho)
1. (Band: content kabhi nahi — locked.)
2. Login: passkey + device approval (meri raaye) — password bhi?
3. Bridge par sab se pehle: paisa ya "kya bigad raha hai"? (meri raaye: dono ek hi fold mein, light + ranked list upar)
4. Mail Desk: kaun se inbox (founder@, support@, leads@…)?

## 9. Pehle se maujood jo reuse hoga
Rust: `b5_core.rs` (`attention`, `gate`, revenue maths), `b5_glue.rs` (`founder.brain.command`, release, movein, revenue), `mail_*` (send/queue), `jwt_core`, `passkey_*`, `security_*`, `team_*`, `events_*` (event-driven push).
Naya zaroorat: `founder_audit` table, `founder.people.*`, abuse core, break-glass table, Mail Desk procs.
