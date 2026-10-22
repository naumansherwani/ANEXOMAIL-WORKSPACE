# ANEXOMAIL — TECHNOLOGY LISTS (backend "beast mode" + frontend), 21 Oct 2026
> Founder ka hukm (08:27): "sab latest technology, fastest, backend beast mode; list repo mein; frontend list banao; faisla CEO karo."
> **CEO FAISLA (locked):** Founder workspace = **sulah**: React 19.2 / Vite 8.2 / TanStack Start-Router / Tailwind 4.2 / shadcn / Three.js (WebGPU) / Motion+GSAP **build-time par**, output = **static SPA** jo **akela Rust binary** serve karta hai + Rust SSE/WebTransport live refresh. Server par Node/Bun runtime nahi. (Leptos option band, jab tak founder na kahe.)
> Rule: har item ke saath status (LIVE / NEXT / LATER), faida, khatra, kis batch/phase mein, aur proof. Versions "verify at build" — install se pehle registry se check hota hai, andaza nahi.

## A. BACKEND — beast mode
### A1. LIVE abhi (TECH-MAP se)
Rust (rustc 1.99.1, edition 2024 — server output 23 Oct; axum 0.8.9, tokio 1.53.x, wtransport 0.7.2 / quinn 0.11 WebTransport udp/3443; upgrades DONE live 20 Oct, TECH-MAP 0a) [pehle yahan purani 2021/0.7.9/0.1.14 likha tha — GALAT/STALE tha, 23 Oct ko theek kiya], LTO + codegen-units=1 + strip, Supabase #4, Postfix/Dovecot/OpenDKIM, Caddy, Polar (NO TOUCH).
### A2. NEXT (B-series ke andar / foran baad)
| Item | Faida | Batch |
|---|---|---|
| Rust par har route (Brain ~504 endpoints) — Bun sirf standby fallback | ek runtime, kam latency/RAM | B5–B8 |
| axum 0.8 + tokio 1.54 + edition 2024 (`axum-upgrade.sh` taiyar) | naya router, behtar extractors | B8 |
| Concurrency: `JoinSet`, `tokio::select!`, bounded channels, timeouts, load-shed (tower) | ek dependency ka fail poore request ko nahi girata (B5 pattern) | har batch |
| Event-driven push (tokio broadcast hub per org + reconcile -> WebTransport), polling khatam | instant UI, zero idle load | **DONE — B4 GREEN 21 Oct 06:50** (LISTEN/NOTIFY use nahi hua; direct pool R4 ke baad dobara dekhenge) |
| Direct Postgres pool (`sqlx`/`deadpool-postgres`, prepared statements, pgbouncer) hot paths par — PostgREST hop hatana | 1 network hop kam, transactions | B8 |
| Allocator `mimalloc`/`jemalloc` + PGO build | 10–30% throughput (measure karke) | B8 |
| Zero-copy: `bytes`, `Cow`, streaming bodies, `sonic-rs`/`simd-json` hot JSON | CPU/RAM kam | B8 |
| In-process cache `moka` (TTL + single-flight), ETag/304 | repeat reads ~0 ms | B8 |
| Observability: `tracing` + OpenTelemetry + `/metrics` (hai) + SLO alerts | pehle pata chale | B8 |
| Security: rustls only, constant-time compare, argon2 jahan password, per-IP/user rate-limit (tower), HMAC email_hash (E24), passkeys | privacy-first | B2b+ |
### A3. LATER (naap kar apnao, andhi nahi)
HTTP/3 origin (quinn/h3) — abhi Caddy edge H3 deta hai; io_uring (`monoio`/`tokio-uring`) storage/attachments; `rkyv` internal cache; eBPF/`bpftrace` profiling; read-replica; multi-node + NATS JetStream; WASM plugins (sandboxed automation); SIMD spam/AV hot paths.
### A4. Backend budgets (measure karke daawa)
p50 < 15 ms, p95 < 60 ms RPC (Supabase hop ke baghair); mail send enqueue < 100 ms; 0 panics (panic counter alert); RSS stable (leak test 24h); graceful shutdown < 5 s; har release par load-test (k6-jaisa, Rust `oha`).

## B. FRONTEND — list
### B1. LIVE abhi
React 19, TanStack Start v1 + Router 1.17 + Query, Vite 8, Tailwind 4, Radix + shadcn/ui, Three.js (`Fx3D`, Logo/Orb/Gem/Mailbox scenes), Bun SSR :3000 (public site), design tokens (`success/warning/danger/steel`), `ax-tap` 44px, 16px inputs on coarse pointer.
### B2. Founder-stack (founder ne diya) — sab adopt
React **19.2** (Actions, `use`, View Transitions, Activity, React Compiler) · Vite **8.2** · TanStack Start/Router (type-safe), **TanStack Query/Virtual/Table** · Tailwind **4.2** (`@theme`, container queries) · Radix + shadcn/ui · **Three.js (WebGPURenderer/TSL)** + R3F/drei · **Motion** (Framer) + **GSAP** (ScrollTrigger, Flip) · Caddy **HTTPS + HTTP/3**.
### B3. Beast-mode frontend (meri addition)
| Item | Faida |
|---|---|
| Rust-served static SPA + SSE/WebTransport live refresh (founder) | page khud update, server par Node nahi |
| WebTransport client (datagrams) for live; SSE fallback | sub-100 ms push |
| Web Workers + OffscreenCanvas for 3D/heavy | UI thread free, 60 fps |
| Rust->WASM hot paths (search/diff/parse) jahan JS dheema | native-jaisa |
| Virtualised lists (TanStack Virtual) + `content-visibility:auto` | 100k rows smooth |
| Speculation Rules (prefetch/prerender) + route-level code split + `modulepreload` | agla page instant |
| CSS modern: `@layer`, container queries, `oklch`, anchor positioning, Popover API, View Transitions, `light-dark()` | kam JS, tez |
| PWA: service worker, offline outbox (hai), background sync, push | app-jaisa |
| Accessibility: reduced-motion, 3D ka text/table equivalent, focus-visible, WCAG 2.2 AA | sab ke liye |
| i18n (hai) RTL/Urdu ready | Pakistan/UK |
| Perf budgets: LCP < 1.8 s (4G), INP < 150 ms, CLS < 0.05, JS first-load < 180 KB gz (public), 3D lazy | CI gate |
### B4. Frontend rules (pehle se locked)
Har batch ke saath 390/820/1440 check; touch ≥ 44px; loading/error/empty state; do-tap destructive; koi invented number nahi; Polar/payments/landing NO TOUCH.

## C. Adoption process
Naya tech tabhi `LIVE` jab: sandbox proof -> founder ka server output -> GREEN-BOARD. Pehle `NEXT` mein likho, measure (before/after), phir apnao. Version bumps (Bun 1.4.3, tokio 1.54, axum 0.8) B8 mein.

## D. WASM · Kernel · SHA-256 · HMAC-SHA256 — kahan lagte hain (founder sawal 21 Oct 08:35)
**Aaj ki sachai (repo grep):** WASM = kahin nahi. Kernel-level features = kahin nahi (sirf ufw 3443/udp). SHA-256 aur HMAC = pehle se bahut jagah LIVE.

### D1. WASM
| Jagah | Kya | Status |
|---|---|---|
| ANEXOMAIL client (public app) | Rust->WASM crate `web-wasm/`, Web Worker mein lazy: mail search/diff, MIME preview parse, bade list sort/filter, attachment SHA-256 (streaming, upload se pehle integrity) | NEXT (B8 ke baad) |
| Server (Rust) | `wasmtime` sandbox: user automations/rules/plugins safe chalane ke liye (CPU/RAM/time limit, no network) | LATER |
| Founder side (static SPA) | audit-log **hash-chain verify browser mein** (WASM), 3D/data crunch Worker+OffscreenCanvas mein | F-phases |
Rule: WASM sirf hot path jahan JS dheema; baqi React. Module ka SHA-256 pin (D3).

### D2. Kernel (Linux, app code nahi — server hardening)
| Feature | Kahan | Status |
|---|---|---|
| nftables/ufw (3443/udp live) + founder host IP allowlist **kernel level par bhi** (Caddy ke saath double lock) | server | NEXT |
| systemd sandbox: founder/rust service alag user, `NoNewPrivileges`, `ProtectSystem=strict`, `PrivateTmp`, seccomp filter, Landlock — attachment/AV/WASM runner par | server | NEXT |
| sysctl tuning: BBR congestion control, `somaxconn`, UDP buffers (QUIC/WebTransport) | server | NEXT |
| eBPF: per-IP rate-limit/DDoS drop (XDP), syscall-level observability | server | LATER |
| io_uring (`monoio`): attachment/storage I/O | Rust engine | LATER |

### D3. SHA-256 (fingerprint — bina key, koi bhi nikal sakta hai)
LIVE: attachment dedup/integrity (`attach_glue.rs`, `attachments.ts`), release **lock signature** (`b5_glue.rs`), export, passkey/webauthn, mail MIME ids, events.
NEXT: **founder audit hash-chain** (har row = SHA-256(prev_hash + row)), static SPA asset hashes + **SRI** (`integrity=`), WASM module pinning, release artifact checksums (installer verify).
Rule: SHA-256 se kabhi email/phone/password hash nahi (guess-able) — wahan HMAC ya argon2.

### D4. HMAC-SHA256 (authenticity — secret key chahiye)
LIVE: device hash (E41 `device_hash`), Polar webhook verify (NO TOUCH), session/idempotency signed paths.
PENDING: **E24 `email_hash` HMAC migrate**, G34 purane device hash HMAC migrate (`device-hash-migrate.sh`).
NEXT: founder session cookie sign, CSRF tokens, **signed download URLs** (attachments, expiry), SSE/WebTransport session tokens, audit-chain **signature** (HMAC key server-only — tamper-evident), internal service-to-service calls (Rust<->Brain).
Rule: key `.env` mein, alag key har kaam ka (key separation), constant-time compare, rotation plan.
