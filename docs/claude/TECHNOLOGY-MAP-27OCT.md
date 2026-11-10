> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# TECHNOLOGY MAP — kaun si technology, kahan live hai, kab kahan aayegi (27 Oct 2026, founder sawal 00:19)
Rule 56: **naye code mein Bun NAHI.** Bun (:3100) sirf emergency fallback hai; naya proc/route/REST path Bun mein likhna mana hai. Naya kaam = Rust + WebTransport/WASM kernel (Rule 52).

## 1. Technology stack (ek jagah)
| Technology | Kya karti hai | Repo mein kahan | Halat AAJ |
|---|---|---|---|
| **Rust (axum 0.8)** | Server (:3200), har proc ka asli dispatch, package gate (`resolve_plan`) | `server/rust/*_core.rs` (hisaab, std-only tests) + `*_glue.rs` (I/O) | **LIVE** — 350+ procs, installer `rust-engine-install.sh` |
| **Async + Tokio** | Har glue `async fn`, ek runtime, `tokio::join!` parallel reads, task-local, semaphore limits | sab `*_glue.rs`, `main.rs` | **LIVE** (naya crmd bhi isi par) |
| **tRPC-style typed RPC** | Ek contract: proc naam -> input/output + min package. `POST /rpc/<proc>` | `src/lib/rpc-contract.ts` (+ test), `server/rust/main.rs` dispatch | **LIVE** (Rust-native contract; asli npm tRPC library NAHI — wo Node/Bun hai, Rule 56 ke khilaf; default yahi) |
| **QUIC (quinn) + WebTransport** (`wtransport` crate) | Browser <-> server ek tez encrypted link, har call ek stream | `wtrpc_glue.rs` (`/wt/rpc`), `events_glue.rs` (`/wt/events`), chat `/wt/chat` | **LIVE** (rpc + events + chat — abhi 3 alag sessions) |
| **WASM kernel** (`web-wasm/`, v0.2.0, SHA-pinned) | Browser ke andar Rust: har `rpc()` pehle kernel se, HMAC tag, reconnect, fallback | `web-wasm/src/*`, `src/lib/kernel/*`, `src/lib/rpc.ts` | **LIVE** — kernel 214 / fetch 100 (68%) |
| **Supabase / Postgres** | Data ki asli jagah (cemented), PostgREST helpers | `sb_select/sb_rpc/sb_insert/sb_patch/sb_upsert` | LIVE (browser seedha nahi, kernel -> Rust -> Supabase) |
| Bun :3100 | Emergency fallback sirf | `server/routes/*.ts` | 523 endpoints; 145 Rust-first; **naya kuch nahi** |
| Mail transport Postfix/Dovecot/OpenDKIM | SMTP/IMAP | server par | badal nahi raha |

## 2. "Kab aayegi" — website ke kis hisse mein (CEO tarteeb, MASTER-GREEN-PLAN section B)
| Qadam | Kya | Technology jo aayegi | Kis package/feature | Halat |
|---|---|---|---|---|
| 1 | Pro walk + Pro CRM desk | Rust+Tokio, `/rpc` + `/wt/rpc` | **Pro**: CRM, Work, Calendar tools, devices | **abhi chal raha** (crmd, meeting cost, devices limit LIVE) |
| 2 | `trial.state` + `auth.session` | Rust + kernel (har page par chalne wali 2 REST) | **Basic** (har page) | **agla** |
| 3 | M3: contacts, companies, storage, workspace, dashboard, billing-sync, support (51) | Rust+kernel | **Basic** | Polar :3400 haath nahi |
| 4-5 | M4 auth+trial (33), M5 org/settings/security/integrations (91) | Rust+kernel | Basic/Pro/Business | tarteeb se |
| 6 | Pro green close + `ANEXO_TAG_MODE=enforce` | kernel HMAC tag enforce | Pro | founder env |
| 7 | Basic baaqi 110 | Rust+kernel | **Basic** | |
| 8 | **L: 23 polls -> WebTransport events** (`refetchInterval` hatana) | WebTransport/QUIC push (`events_glue` hub) | **sab packages** (live inbox, calendar, CRM refresh) | NAHI SHURU |
| 9 | **ANEXOChat K3: ONE QUIC session** (rpc+events+chat ek link, kernel 0.3.0) + voice | QUIC/WebTransport, kernel 0.3.0 | **Business+** (ANEXOChat, file 2GB) | Business phase |
| 9b | Office suite Writer/Sheet/Show (N-DOC-01, Rule 58) | Rust CRDT + kernel, `/wt` live cursors | **Business+** | K3 ke baad |
| 10 | CRM P3-P6 | Rust+kernel | Business/Business Pro | |
| 11 | Business Pro | same | Business Pro | |
| 12 | Founder batch (admin/perf/movein...) | Rust-only | Founder host | |
| 13 | **Business Premium: poori website Bun-free** + toolchain (sqlx pool, mimalloc, moka cache, tracing) | Rust-only | **Business Premium** | aakhir |

## 3. Bun kab hatega
Har endpoint ka Bun route tab hatta hai jab Rust jawab Bun ke barabar saabit ho (Chrome Bun-vs-Rust proof, probe ALL PASS). Pehle Basic, phir Pro, phir Business; **Business Premium tak poori website Bun-free**. Calendar tareekh repo mein nahi — sirf tarteeb locked hai.

## 4. Naya code likhte waqt (checklist)
1. `ENDPOINT-PACKAGE-MAP` mein package dekho (Rule 57). 2. `X_core.rs` (std-only + tests) + `X_glue.rs` (async Tokio, `owns()`/`dispatch`). 3. Installer CFG + probe line + `rpc-contract.ts`. 4. Browser `rpc()` -> kernel; REST/Bun twin NAHI. 5. cargo check (poora crate, TLS ke saath) + bun test + tsc. 6. Deploy, probes, Chrome mein live dekho.

(Frontend: docs/claude/FRONTEND-TECHNOLOGY-PLAN-27OCT.md)

## 5. Website kaise banegi (founder 00:54 — "damkhao kaise kero gay")
Har screen ka raasta (Rule 52), upar se neeche:
1. **Screen = React 19 UI** (TanStack Router/Query, Tailwind 4). Cinematic magic (three/R3F, GSAP+ScrollTrigger, Theatre, WebGPU/TSL, Rapier, WebXR) SIRF is layer mein. Isay data ki parwah nahi.
2. **UI data mangti hai kernel se** (`rpc()` -> Rust WASM kernel, HMAC tag). UI direct `fetch`/Bun nahi karti (fetch sirf fallback `rpcOrRest`, Rule 59).
3. **Kernel -> QUIC/WebTransport (`/wt/rpc`) ya `/rpc`** -> **Rust server (async Tokio)**. Plan gate (`resolve_plan`) YAHAN lagta hai, UI sirf aaina (Rule 57).
4. **Rust -> Supabase/Postgres**.
5. Bun :3100 sirf emergency fallback; Business Premium tak hat jayega.

Misal "Lead capture": form (React, glow animation) -> `crm.createLead` kernel -> Rust `crmd_glue` (Pro gate, clean_lead_email) -> `leads` table -> jawab wapas -> UI card animate. Kaam wale screens (mail/work/CRM/Office) fast rehte hain, cinematic sirf landing/onboarding/chat/dashboard accent (Rule 60).

---

## TECHNOLOGY CHART UPDATE — 1 Nov 2026 10:00 PKT (founder order 09:51, verified by fetch, nothing copied from unverified text)

| Technology | Verified fact (source seen 1 Nov 2026) | Awam side | Founder side | Phase |
|---|---|---|---|---|
| WebTransport (browser) | Baseline: Chrome, Edge, Firefox, Safari 26.4 (Mar 2026) | LIVE: Rust `wtrpc`, UDP 3443, `wtransport` 0.1.14 + quinn 0.10.2 (old) | PLANNED, step 7a, `wtransport` 0.7.1 (latest on docs.rs) | awam upgrade 0.1.14 -> 0.7.x only on founder order after cutover |
| Caddy and WebTransport | quic-go gives HTTP/3 (default since Caddy 2.6). Caddy does not proxy WebTransport itself; maintainer points to `caddy-l4` for HTTP/3 passthrough. Issue 5086 page did not mention WebTransport, so the status stays unconfirmed | UDP 3443 is bound directly by Rust, not through Caddy | same: Rust binds UDP itself; Caddy L4 only if needed, tested first | 7a |
| MoQ (Media over QUIC) | `draft-ietf-moq-transport-22` dated 1 Oct 2026, still a WG draft, NO RFC; IESG milestone Dec 2026. Wire format still changes between drafts. Cloudflare relay: tech preview since Aug 2025 (draft-07 subset); self-serve relay beta Jul 2026 (secondary source). Cloudflare and moq.dev relays were not interoperable as of Jun 2026 | PLANNED for ANEXOChat one-to-many (channels, live rooms, announcements) behind a flag, pinned to one draft | same module, shared | after ANEXOChat core; never before |
| MoQ claims NOT verified | "Meta relay", "production ready", "kills WebRTC" from the pasted text. Do not write these anywhere as fact | - | - | - |
| Two-way calls | MoQ is NOT the right fit for 2-way calling; WebRTC stays (TURN doc: anexovideochat-turn.md) | WebRTC | WebRTC | unchanged |
| DBSC | Chrome 146 on Windows since 9 Apr 2026, macOS later | PLANNED | step 7b | 7b |
| Hybrid post-quantum TLS (X25519MLKEM768) | Chrome default; needs Go 1.24+ in Caddy. NOT yet checked on our server, so NOT claimed | check pending | check pending | 7b |
| TLS symmetric cipher | Server negotiated TLSv1.3 + TLS_AES_128_GCM_SHA256 (founder's openssl output). So "256-bit TLS" on the splash is inaccurate; use "TLS 1.3" | fix splash wording on awam only with founder word | founder splash says TLS 1.3 | 7b |
| Merkle audit ledger (E107) | RFC 6962-style; kernel 0.6.0 `merkle@1` | n/a | GREEN | step 5 done |

Honest answer to "tumhay ati hai kya": yes, Rust + tokio + wtransport + quinn are written here already (awam `wtrpc`). The website's WebTransport was NOT rewritten; it is old (0.1.14) and works.
