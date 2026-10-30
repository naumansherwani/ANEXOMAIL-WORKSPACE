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
