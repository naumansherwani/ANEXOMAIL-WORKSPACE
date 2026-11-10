> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# FRONTEND TECHNOLOGY PLAN — kaun si technology browser/UI mein, kab, kis feature mein (CEO PROPOSAL, 27 Oct 2026 00:50)
Founder (00:43): "frontend technology kahan aayegi, apne mind se soch ke batao." Yeh CEO ki soch hai (repo ke sach par); founder ne pehle se locked cheezein (Rule 52/56, kernel) neeche alag likhi hain. Calendar tareekh nahi — sirf tarteeb (MASTER-GREEN-PLAN steps).

## 1. Aaj frontend kya hai (package.json se, sach)
React 19.2 + TanStack Start 1.168 / Router 1.170 / Query 5 + Vite 8 + Tailwind 4 + TypeScript 5.8 + framer-motion/motion 13 + Radix. **Data/compute browser ke WASM kernel (Rust, v0.2.0)** se; UI React mein. SSR host abhi `bun .output/server/index.mjs` (pm2 anexomail-web) — yeh **Bun hai**: Business Premium "Bun-free" ke liye aakhir mein hatana hoga (neeche step F5).

## 2. Faisla: React/TanStack **rewrite nahi**. Latest technology "UI ke neeche" aur "UI ke hisaab ke andar" aayegi
Kyun: React 19 + TanStack + Tailwind 4 already latest hain; poori UI dobara likhna paisa/risk, user ko kuch naya nahi dikhta. Asli faida: data/compute kernel mein, live push, kam JS, tez screens.

## 3. Kahan kya aayega (tarteeb)
| # | Technology | Kya badalega | Kis feature/package mein | Kab (MASTER step) |
|---|---|---|---|---|
| F1 | **Sab data kernel se** (fetch -> 0) | har page `rpc()`; baaqi REST (auth.session...) | sab packages | steps 2-7 (abhi chal raha) |
| F2 | **WebTransport live events** (polls khatam) | 23 `refetchInterval` -> push; inbox/calendar/CRM khud refresh, battery/data kam | sab packages | step 8 (L) |
| F3 | **Kernel mein heavy compute (Rust->WASM)**: mail search index, MIME/HTML sanitiser, dedup/merge, analytics rollups | UI thread halka; bade inbox mein jhatke nahi | Basic+ (search/inbox), Pro (analytics/CRM merge) | steps 7, 10 |
| F4 | **React Compiler + virtualised lists + route-level code split** | kam re-render, 10k+ rows (inbox/leads) smooth, chhota bundle | sab | step 7 ke saath (measure pehle: bundle KB, INP) |
| F5 | **SSR host Bun se bahar**: SPA/prerender static shell Caddy se, data sab kernel se; TanStack Start server functions NAHI | Business Premium "Bun-free" poori website | Business Premium | step 13 |
| F6 | **ANEXOChat media**: WebAudio + WebCodecs + WASM Opus (FEC/DTX) kernel mein, ek QUIC session (K3) | voice/video | Business+ | step 9 |
| F7 | **Office suite UI**: canvas/DOM editor + Rust CRDT (WASM) + live cursors WebTransport | Writer/Sheet/Show (Rule 58) | Business+ | step 9b |
| F8 | **Offline/PWA**: service worker + IndexedDB cache, kernel sync queue (draft/send offline) | mail drafts, calendar read offline | Pro+ (CEO guess) | Business phase ke baad |
| F9 | **Passkeys (WebAuthn) mandatory** (27 Oct banner) + device-bound session | login | sab | already shuru; auth step M4 |
| F10 | **View Transitions API + motion** (progressive; support na ho to seedha) | page badalna smooth | sab (polish) | sabse aakhir, kam darja |

## 4. Jo NAHI karenge (aur kyun)
- Asli npm **tRPC** library / Next.js / koi naya framework: Rule 56 (Bun/Node par depend) + faida nahi.
- Browser se seedha Supabase: Rule 52 (browser -> kernel -> Rust -> Supabase).
- "10x tez" jaise numbers bina benchmark ke likhna: mana (blueprint rule).

## 5. Naya UI code likhte waqt
`rpc()` hi (kernel-first), REST/Bun twin nahi; plan gate server par, UI aaina (Rule 57); text English; bundle/INP measure karke likho.

(Cinematic 3D: docs/claude/CINEMATIC-FRONTEND-STACK-27OCT.md)
