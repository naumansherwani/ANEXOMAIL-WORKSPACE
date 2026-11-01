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
