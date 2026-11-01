# FOUNDER TECHNOLOGY ADOPTION — every locked technology gets a home in the code (founder order 30 Oct 2026, 18:54 PKT)
Founder: "technology kahan use hogi yeh top pe likha hai woh use kero." The locked stack (AGENTS.md top block, Rules 52/61/62) is no longer a "gap list" — it is the build order. Rule 64 still holds: one phase at a time, green on the server + Chrome before the next. Look stays CINEMATIC (FC43): every phase is pixel-compared against the current look before it ships.

## Where each technology is used (the home), in build order
| Phase | Technology | Where it is used in the founder code | Proof (green = all three) |
|---|---|---|---|
| **T1** UI stack foundation | **TypeScript**, **TanStack Router** (hash history, same URLs), **Tailwind 4.2** (tokens in `@theme`, no preflight so the look does not change), **shadcn pattern** (Radix Switch/Popover/Slot + cva + tailwind-merge) | every `founder-web/src/*.jsx|js` becomes `.tsx|ts`; `App.tsx` routes become TanStack routes; Settings switches and the city popover use the shadcn components; new screens are written in Tailwind from now on | `tsc --noEmit` clean, `vite build`, Playwright 1440/820/390 pixel compare vs today, server install, Chrome |
| **F2b** WASM kernel (Rule 52) | **Rust -> wasm32** (`server/founder-kernel`), `ed25519` verify + `sha2` + `hmac`/`hkdf`, loaded in a **Web Worker**, **SRI** pinned | every `/founder/v1/*` response is verified in the browser before it is parsed; Trust chip goes amber -> green; version bumps with each feature (Rule 52) | cargo tests with RFC vectors, kernel `.wasm` served with SRI, Chrome shows "verified" |
| **F2c** audit v1 + Merkle | **Postgres (pgcrypto/SHA-256)** + Rust + kernel verify | Ledger Integrity Gauge (Dashboard D1) | CHECK_E107 + Chrome |
| **F2d** passkey | **webauthn-rs** (Rust) + browser WebAuthn | G3 gate for money/kill switch; `FOUNDER_PASSWORD` path removed afterwards | server + Chrome |
| **Live Pulse** | **WebTransport / QUIC** (`wtransport`) with Caddy HTTP/3, fetch fallback | Bridge live feed (no 15 s polling), Live Pulse B6 | server + Chrome |
| **3D** | **Three.js WebGPU** (lazy) | Device Trust Map D3, topology | FPS budget + 2D fallback |
Why this order: T1 first because every later screen is then written once in the final stack (no rewrite later); F2b next because it is the trust foundation and the amber "Review" chip is the founder's visible gap.

## Honest limits (no mock, Rule 69)
- WebTransport needs UDP/QUIC reachable on the founder host (Caddy HTTP/3 is on; the Rust listener and cert wiring is its own phase, not a flag).
- Tailwind is added without its CSS reset so the existing cinematic CSS stays byte-for-byte in effect; existing `ui.css`/`cinema.css` tokens are mapped into Tailwind's `@theme`, not thrown away.

## WebTransport (Live Pulse) — kab (founder 30 Oct 19:48 "webtransport kab aye ga?")
Tarteeb (Rule 64, ek waqt ek phase): F2b WASM verify -> F2c Merkle (E107) -> F2d passkey -> **WebTransport `wtransport` (Live Pulse D10)**. Is ka ghar: founder Rust binary mein alag UDP listener (QUIC, HTTP/3), Caddy QUIC proxy nahi karta, isliye alag UDP port + TLS cert chahiye (awam engine par udp/3443 pehle se live hai, `kernel-check.sh`; founder ke liye alag port founder se poochh kar). Fetch fallback pehle se maujood. Tab tak Dashboard par "Live pulse: after WebTransport" likha hai.

## F2b — STATUS (30 Oct 20:25): IN CODE, server + Chrome proof pending
- Kernel = web-wasm v0.5.0 (ek hi kernel, Rule 52; alag `server/founder-kernel` crate NAHI banega — CRYPTO-FINAL §3 ka purana naam). Naye modules `ed25519@1` (RFC 8032 vectors) + `envelope@1` (kachchi body: duplicate-key reject, ts window, kid pin, verify PEHLE phir parse). 52 Rust tests; ring-sign -> kernel-verify cross test.
- Browser: `founder-web/src/kernel.ts` + `kernel.worker.ts` (Worker, SHA-256 pinned wasm, Trusted Types policy). `api.ts` har `/founder/v1` jawab (keys/exchange chhor kar) pehle verify karta hai; fail = data hide (enforce). Trust chip ab asli state se (Starting / Verified / Failed).
- Pinned key s1 = `BvK2K2SrpbZoJAHblaB2c1DwXAzEmv4J-m27rVft7RQ` (server `/founder/v1/keys`). Key badli to naya kernel build.
- Honest limit: kernel server se hi aata hai (wasm hash pin JS mein); poori chain ka bharosa TLS + repo-signed manifest par; F2c Merkle aur signed asset manifest isse mazboot karenge.

## 1 Nov 2026 09:45 PKT — founder ne awam landing/splash ki 3 technology lines dikhayin ("256-bit TLS · device-bound sessions", "Your data · export anytime · delete means delete", "Rust + WebTransport · async Tokio engine") aur kaha founder side par bhi milni chahiyen, ya is se naya aaya ho to search karke batao
Research (1 Nov 2026, web): 
| Cheez | Taza halat | Founder side ke liye |
|---|---|---|
| **Device Bound Session Credentials (DBSC)** | Google ne 9 Apr 2026 ko Chrome 146 (Windows) par public availability di; session key hardware (TPM) mein, nikal nahi sakti, churai hui cookie bekaar. macOS "aane wale release" mein. [blog.google](https://blog.google/security/protecting-cookies-with-device-bound-session-credentials/) | Founder Windows par Chrome chalata hai => **seedha faida**. Hamara abhi ka "device approval + signed requests" app-level hai; DBSC browser-level hardware binding hai. Plan: step 7 (F2d passkey) ke saath hardening: Rust founder service DBSC registration/refresh endpoints (session cookie short-lived + browser TPM key). Awam ki "device-bound sessions" line bhi isi se sach-mach hardware-bound hogi |
| **Post-quantum hybrid TLS (X25519MLKEM768)** | Chrome mein default; Cloudflare ke mutabiq Chrome ke ~25% TLS 1.3 handshakes. Go crypto/tls 1.24+ mein support, OpenSSL 3.5+ mein. [unveilscan](https://unveilscan.unveiltech.com/blog/post-quantum-tls.html) | Founder host Caddy (Go) ke peeche hai: Caddy ka Go version PQ default deta hai ya nahi => server par read-only check chalana hai (command niche), phir sirf Caddy upgrade. Chori hui encrypted traffic aaj store karke kal quantum se kholne ("harvest now, decrypt later") ke khilaf founder ke liye munasib |
| **WebTransport** | Safari 26.4 (Mar 2026) ke baad **Baseline**: Chrome/Edge/Firefox/Safari sab. [webrtc.ventures](https://webrtc.ventures/2026/04/webtransport-is-now-baseline-what-it-means-for-real-time-media/) | Master order 7a (step 7 ke baad) safe: founder ka apna UDP listener |
| **256-bit TLS** | TLS 1.3 (AES-256-GCM / ChaCha20) + HSTS preload (founder host par header maujood) | Awam host par paste mein TLSv1.3 verify; founder host same Caddy: read-only check niche |
Check (server par, kuch badalta nahi): `openssl s_client -connect founderworkspace.anexomail.com:443 -tls1_3 </dev/null 2>/dev/null | grep -E "Protocol|Cipher|Verification|Server Temp Key"`
Sach ki hudood (founder side par kya likhna jaiz hai): "256-bit TLS 1.3" aur "signed answers checked in your browser" abhi sach; "device-bound sessions" app-level sach (device approval), hardware-level DBSC step 7 ke baad; "WebTransport" step 7a ke baad. Founder splash/login par yeh 3 lines tab lagengi jab ek ek sach ho (jhoot nahi likhte).

---

## TECHNOLOGY CHART UPDATE — 1 Nov 2026 10:00 PKT (founder order 09:51, verified by fetch, nothing copied from unverified text)

| Technology | Verified fact (source seen 1 Nov 2026) | Awam side | Founder side | Phase |
|---|---|---|---|---|
| WebTransport (browser) | Baseline: Chrome, Edge, Firefox, Safari 26.4 (Mar 2026) | LIVE: Rust `wtrpc`, UDP 3443, `wtransport` 0.7.2 + quinn 0.11.11 (server Cargo.lock read 1 Nov 14:19; the earlier 0.1.14 value was stale) | PLANNED, step 7a, `wtransport` 0.7.1 (latest on docs.rs) | no awam upgrade needed: already on 0.7.2 |
| Caddy and WebTransport | quic-go gives HTTP/3 (default since Caddy 2.6). Caddy does not proxy WebTransport itself; maintainer points to `caddy-l4` for HTTP/3 passthrough. Issue 5086 page did not mention WebTransport, so the status stays unconfirmed | UDP 3443 is bound directly by Rust, not through Caddy | same: Rust binds UDP itself; Caddy L4 only if needed, tested first | 7a |
| MoQ (Media over QUIC) | `draft-ietf-moq-transport-22` dated 1 Oct 2026, still a WG draft, NO RFC; IESG milestone Dec 2026. Wire format still changes between drafts. Cloudflare relay: tech preview since Aug 2025 (draft-07 subset); self-serve relay beta Jul 2026 (secondary source). Cloudflare and moq.dev relays were not interoperable as of Jun 2026 | PLANNED for ANEXOChat one-to-many (channels, live rooms, announcements) behind a flag, pinned to one draft | same module, shared | after ANEXOChat core; never before |
| MoQ claims NOT verified | "Meta relay", "production ready", "kills WebRTC" from the pasted text. Do not write these anywhere as fact | - | - | - |
| Two-way calls | MoQ is NOT the right fit for 2-way calling; WebRTC stays (TURN doc: anexovideochat-turn.md) | WebRTC | WebRTC | unchanged |
| DBSC | Chrome 146 on Windows since 9 Apr 2026, macOS later | PLANNED | step 7b | 7b |
| Hybrid post-quantum TLS (X25519MLKEM768) | Chrome default; needs Go 1.24+ in Caddy. NOT yet checked on our server, so NOT claimed | check pending | check pending | 7b |
| TLS symmetric cipher | Server negotiated TLSv1.3 + TLS_AES_128_GCM_SHA256 (founder's openssl output). So "256-bit TLS" on the splash is inaccurate; use "TLS 1.3" | fix splash wording on awam only with founder word | founder splash says TLS 1.3 | 7b |
| Merkle audit ledger (E107) | RFC 6962-style; kernel 0.6.0 `merkle@1` | n/a | GREEN | step 5 done |

Honest answer to "tumhay ati hai kya": yes, Rust + tokio + wtransport + quinn are written here already (awam `wtrpc`). The website's WebTransport was NOT rewritten; it is old (0.1.14) and works.


## 1 Nov 2026 14:25 PKT — 1 Nov 14:25 SERVER CHECK (founder paste 14:19): awam live Cargo.lock = wtransport 0.7.2 + quinn 0.11.11 (the '0.1.14 / quinn 0.10.2' chart row was STALE, now corrected). Founder host TLS: TLSv1.3, TLS_AES_128_GCM_SHA256, certificate Verification OK; openssl printed no 'Server Temp Key' line so post-quantum hybrid is still UNKNOWN (not claimed; 7b needs a check that can see the group).


## 1 Nov 2026 14:35 PKT — 1 Nov 14:35 TLS '256-bit' research (founder 14:20 'kab milega, 256 se latest kaun sa'): (1) Go crypto/tls (so Caddy) CANNOT configure TLS 1.3 cipher suites; maintainers closed golang/go#29349 keeping that position -> forcing AES-256-GCM through Caddy config is not possible; server picked TLS_AES_128_GCM_SHA256 (seen 14:19). AES-128 is not broken; 256 matters for compliance wording (e.g. CNSA) not for a known attack. (2) Symmetric keys do not go above 256; the newer layer is post-quantum KEY EXCHANGE: hybrid X25519MLKEM768 (on by default in Go 1.24+, tlsmlkem=0 turns it off; Go later added SecP256r1MLKEM768 and SecP384r1MLKEM1024). One secondary blog said Go has it off by default; the Go commit text contradicts it, so unverified until we read our own Caddy build. (3) Founder + awam share ONE Caddy edge, so both get the same result; no per-lane difference. Splash/landing wording: say 'TLS 1.3', never '256-bit', until a build proves AES-256. Next: 7b read-only check = caddy version + go version -m + openssl>=3.5 group test.
