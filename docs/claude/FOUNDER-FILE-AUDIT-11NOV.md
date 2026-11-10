> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# FOUNDER FILE-BY-FILE AUDIT (11 Nov 2026 03:50 PKT, his order 03:40: "deep audit kero ek ek ek file codes ke saath")

Method: every founder source file listed with its layer and the technology MARKERS found in it by grep (counts), then a verdict per flagged file. Markers are facts; verdicts are mine and cite the line. Files not flagged carry no transport/old-tech marker.

| Layer | File | Lines | Markers found |
|---|---|---|---|
| UI React-TS | `founder-web/src/AmbientStudio.tsx` | 108 | - |
| UI React-TS | `founder-web/src/App.tsx` | 188 | ring×1, localStorage×4 |
| UI React-TS | `founder-web/src/Brand.tsx` | 60 | - |
| UI React-TS | `founder-web/src/Bridge.tsx` | 130 | localStorage×1 |
| UI React-TS | `founder-web/src/Dbsc.tsx` | 16 | - |
| UI React-TS | `founder-web/src/DbscCard.tsx` | 16 | - |
| UI React-TS | `founder-web/src/Decks.tsx` | 85 | - |
| UI React-TS | `founder-web/src/Devices.tsx` | 234 | ring×2, wasm-kernel×7 |
| UI React-TS | `founder-web/src/Finance.tsx` | 52 | Three×1 |
| UI React-TS | `founder-web/src/Flare.tsx` | 128 | - |
| UI React-TS | `founder-web/src/Keys.tsx` | 73 | wasm-kernel×1 |
| UI React-TS | `founder-web/src/Live.tsx` | 72 | - |
| UI React-TS | `founder-web/src/Palette.tsx` | 31 | - |
| UI React-TS | `founder-web/src/PolicyEditor.tsx` | 96 | - |
| UI React-TS | `founder-web/src/Profile.tsx` | 126 | localStorage×1 |
| UI React-TS | `founder-web/src/Scene3D.tsx` | 137 | Three×3, wasm-kernel×1 |
| UI React-TS | `founder-web/src/Settings.tsx` | 214 | ring×2 |
| UI React-TS | `founder-web/src/SettingsS2.tsx` | 233 | wasm-kernel×4 |
| UI React-TS | `founder-web/src/SignIn.tsx` | 138 | fetch(×1, ring×4, motion×1, localStorage×3 |
| UI React-TS | `founder-web/src/Surface.tsx` | 293 | fetch(×1, webcrypto×1, wasm-kernel×14 |
| UI React-TS | `founder-web/src/Trust.tsx` | 36 | wasm-kernel×4 |
| UI React-TS | `founder-web/src/Vault.tsx` | 58 | localStorage×3 |
| UI React-TS | `founder-web/src/ambient.ts` | 62 | - |
| UI React-TS | `founder-web/src/anchorgauge.test.ts` | 42 | wasm-kernel×8 |
| UI React-TS | `founder-web/src/anchorgauge.ts` | 48 | ring×1, wasm-kernel×13 |
| UI React-TS | `founder-web/src/api.ts` | 220 | fetch(×7, EventSource×1, WebTransport×1, webcrypto×3, localStorage×9, wasm-kernel×9 |
| UI React-TS | `founder-web/src/appearance.test.ts` | 70 | - |
| UI React-TS | `founder-web/src/appearance.ts` | 50 | ring×1 |
| UI React-TS | `founder-web/src/banned.test.ts` | 40 | - |
| UI React-TS | `founder-web/src/banned.ts` | 10 | - |
| UI React-TS | `founder-web/src/catalog.ts` | 140 | wasm-kernel×1 |
| UI React-TS | `founder-web/src/city.ts` | 44 | - |
| UI React-TS | `founder-web/src/components/ui/button.tsx` | 17 | - |
| UI React-TS | `founder-web/src/components/ui/switch.tsx` | 14 | - |
| UI React-TS | `founder-web/src/countries.ts` | 35 | - |
| UI React-TS | `founder-web/src/dbsc_pure.test.ts` | 27 | - |
| UI React-TS | `founder-web/src/dbsc_pure.ts` | 27 | - |
| UI React-TS | `founder-web/src/devicekey.ts` | 40 | fetch(×1, webcrypto×4, wasm-kernel×1 |
| UI React-TS | `founder-web/src/devicekey_pure.test.ts` | 39 | webcrypto×6 |
| UI React-TS | `founder-web/src/devicekey_pure.ts` | 33 | ring×1, webcrypto×1 |
| UI React-TS | `founder-web/src/devicelabel.ts` | 7 | - |
| UI React-TS | `founder-web/src/flare_pure.ts` | 35 | webcrypto×1 |
| UI React-TS | `founder-web/src/flare_sw.test.ts` | 68 | - |
| UI React-TS | `founder-web/src/greeting.ts` | 193 | - |
| UI React-TS | `founder-web/src/kernel.host.test.ts` | 58 | WebTransport×4, wasm-kernel×12 |
| UI React-TS | `founder-web/src/kernel.host.ts` | 79 | WebTransport×1, wasm-kernel×15 |
| UI React-TS | `founder-web/src/kernel.pin.ts` | 3 | wasm-kernel×4 |
| UI React-TS | `founder-web/src/kernel.test.ts` | 190 | wasm-kernel×20 |
| UI React-TS | `founder-web/src/kernel.ts` | 165 | WebTransport×4, wasm-kernel×31 |
| UI React-TS | `founder-web/src/kernel.worker.ts` | 127 | fetch(×1, WebTransport×4, webcrypto×1, wasm-kernel×47 |
| UI React-TS | `founder-web/src/lease.ts` | 106 | webcrypto×3, localStorage×2, wasm-kernel×5 |
| UI React-TS | `founder-web/src/lease_pure.test.ts` | 88 | webcrypto×6 |
| UI React-TS | `founder-web/src/lease_pure.ts` | 99 | wasm-kernel×4 |
| UI React-TS | `founder-web/src/lib/utils.ts` | 5 | - |
| UI React-TS | `founder-web/src/livefeed.test.ts` | 25 | - |
| UI React-TS | `founder-web/src/livefeed.ts` | 122 | WebTransport×4, Three×2, wasm-kernel×8 |
| UI React-TS | `founder-web/src/main.tsx` | 12 | - |
| UI React-TS | `founder-web/src/passkey.test.ts` | 140 | - |
| UI React-TS | `founder-web/src/passkey.ts` | 89 | wasm-kernel×5 |
| UI React-TS | `founder-web/src/passkey_pure.ts` | 39 | wasm-kernel×1 |
| UI React-TS | `founder-web/src/places.ts` | 214 | - |
| UI React-TS | `founder-web/src/policy_change.ts` | 69 | wasm-kernel×1 |
| UI React-TS | `founder-web/src/policy_flow.ts` | 28 | wasm-kernel×3 |
| UI React-TS | `founder-web/src/portable.test.ts` | 39 | wasm-kernel×5 |
| UI React-TS | `founder-web/src/portable.ts` | 39 | wasm-kernel×9 |
| UI React-TS | `founder-web/src/router.tsx` | 17 | - |
| UI React-TS | `founder-web/src/routes.test.ts` | 23 | - |
| UI React-TS | `founder-web/src/s2lib.ts` | 42 | ring×1 |
| UI React-TS | `founder-web/src/sealpin.test.ts` | 160 | wasm-kernel×4 |
| UI React-TS | `founder-web/src/sealpin.ts` | 177 | localStorage×4, wasm-kernel×13 |
| UI React-TS | `founder-web/src/session.test.ts` | 27 | - |
| UI React-TS | `founder-web/src/session.ts` | 46 | localStorage×1 |
| UI React-TS | `founder-web/src/sessions_pure.test.ts` | 184 | WebTransport×1, ring×13, wasm-kernel×7 |
| UI React-TS | `founder-web/src/sessions_pure.ts` | 236 | ring×1, wasm-kernel×8 |
| UI React-TS | `founder-web/src/settingsS2.test.ts` | 40 | - |
| UI React-TS | `founder-web/src/signin/AuthCinema.tsx` | 110 | WebTransport×1, motion×1 |
| UI React-TS | `founder-web/src/signin/BrandLoader.tsx` | 27 | - |
| UI React-TS | `founder-web/src/signin/BrandMark.tsx` | 101 | Three×1 |
| UI React-TS | `founder-web/src/signin/ui/button.tsx` | 59 | ring×1 |
| UI React-TS | `founder-web/src/signin/ui/checkbox.tsx` | 27 | ring×3 |
| UI React-TS | `founder-web/src/signin/ui/input.tsx` | 23 | ring×3 |
| UI React-TS | `founder-web/src/signin/ui/label.tsx` | 22 | - |
| UI React-TS | `founder-web/src/signin_passkey.test.ts` | 67 | - |
| UI React-TS | `founder-web/src/signin_passkey.ts` | 51 | fetch(×2 |
| UI React-TS | `founder-web/src/signin_pure.test.ts` | 36 | - |
| UI React-TS | `founder-web/src/signin_pure.ts` | 53 | Three×1 |
| UI React-TS | `founder-web/src/snap_seal.test.ts` | 60 | webcrypto×1 |
| UI React-TS | `founder-web/src/snap_seal.ts` | 35 | webcrypto×4 |
| UI React-TS | `founder-web/src/sse.ts` | 29 | wasm-kernel×1 |
| UI React-TS | `founder-web/src/types.ts` | 12 | - |
| UI CSS | `founder-web/src/cinema.css` | 50 | - |
| UI CSS | `founder-web/src/devices.css` | 129 | ring×20, wasm-kernel×1 |
| UI CSS | `founder-web/src/dx.css` | 170 | ring×7, Three×3 |
| UI CSS | `founder-web/src/signin/awam.css` | 349 | ring×7, Three×1 |
| UI CSS | `founder-web/src/styles.css` | 148 | ring×2 |
| UI CSS | `founder-web/src/tailwind.css` | 15 | - |
| UI CSS | `founder-web/src/ui.css` | 206 | - |
| WASM kernel Rust | `web-wasm/src/action.rs` | 116 | wasm-kernel×3 |
| WASM kernel Rust | `web-wasm/src/ed.rs` | 201 | ring×2, wasm-kernel×2 |
| WASM kernel Rust | `web-wasm/src/exec.rs` | 167 | wasm-kernel×2 |
| WASM kernel Rust | `web-wasm/src/filectx.rs` | 182 | - |
| WASM kernel Rust | `web-wasm/src/flive.rs` | 411 | WebTransport×5, ring×1, wasm-kernel×2 |
| WASM kernel Rust | `web-wasm/src/frame.rs` | 284 | wasm-kernel×1 |
| WASM kernel Rust | `web-wasm/src/hash.rs` | 164 | wasm-kernel×1 |
| WASM kernel Rust | `web-wasm/src/host.rs` | 110 | WebTransport×1 |
| WASM kernel Rust | `web-wasm/src/intent.rs` | 536 | Three×1, wasm-kernel×1 |
| WASM kernel Rust | `web-wasm/src/lease.rs` | 171 | wasm-kernel×4 |
| WASM kernel Rust | `web-wasm/src/lib.rs` | 386 | WebTransport×3, ring×1, wasm-kernel×23 |
| WASM kernel Rust | `web-wasm/src/live.rs` | 278 | WebTransport×4 |
| WASM kernel Rust | `web-wasm/src/portable.rs` | 233 | wasm-kernel×6 |
| WASM kernel Rust | `web-wasm/src/rank.rs` | 89 | - |
| WASM kernel Rust | `web-wasm/src/rpc.rs` | 157 | WebTransport×1, wasm-kernel×2 |
| WASM kernel Rust | `web-wasm/src/sniff.rs` | 90 | - |
| WASM kernel Rust | `web-wasm/src/sys.rs` | 53 | wasm-kernel×1 |
| Backend Rust | `server/founder/src/actions.rs` | 32 | - |
| Backend Rust | `server/founder/src/ambient.rs` | 164 | - |
| Backend Rust | `server/founder/src/anchors.rs` | 249 | ring×11, wasm-kernel×2 |
| Backend Rust | `server/founder/src/audit.rs` | 91 | - |
| Backend Rust | `server/founder/src/auth.rs` | 282 | rustls×1, Three×1 |
| Backend Rust | `server/founder/src/authcache.rs` | 69 | - |
| Backend Rust | `server/founder/src/bridge.rs` | 123 | - |
| Backend Rust | `server/founder/src/data.rs` | 87 | - |
| Backend Rust | `server/founder/src/dbsc.rs` | 465 | ring×4 |
| Backend Rust | `server/founder/src/flare.rs` | 345 | ring×4 |
| Backend Rust | `server/founder/src/fproxy.rs` | 158 | rustls×1, wasm-kernel×2 |
| Backend Rust | `server/founder/src/front.rs` | 201 | ring×1, rustls×6 |
| Backend Rust | `server/founder/src/ftoken.rs` | 193 | ring×6 |
| Backend Rust | `server/founder/src/gate.rs` | 49 | - |
| Backend Rust | `server/founder/src/h3.rs` | 196 | ring×4, rustls×13, quinn/h3×14 |
| Backend Rust | `server/founder/src/hostproof.rs` | 39 | - |
| Backend Rust | `server/founder/src/inbox.rs` | 75 | - |
| Backend Rust | `server/founder/src/lease.rs` | 188 | ring×12, wasm-kernel×1 |
| Backend Rust | `server/founder/src/ledger.rs` | 240 | Three×1, wasm-kernel×1 |
| Backend Rust | `server/founder/src/live.rs` | 162 | wasm-kernel×1 |
| Backend Rust | `server/founder/src/login.rs` | 56 | - |
| Backend Rust | `server/founder/src/main.rs` | 1181 | EventSource×1, WebTransport×7, wasm-kernel×21 |
| Backend Rust | `server/founder/src/passkey.rs` | 670 | ring×7 |
| Backend Rust | `server/founder/src/polar.rs` | 156 | fetch(×3 |
| Backend Rust | `server/founder/src/policy_step.rs` | 200 | - |
| Backend Rust | `server/founder/src/portable.rs` | 191 | Three×1, wasm-kernel×3 |
| Backend Rust | `server/founder/src/sessions.rs` | 373 | WebSocket×1, Three×3, wasm-kernel×21 |
| Backend Rust | `server/founder/src/settings.rs` | 146 | - |
| Backend Rust | `server/founder/src/settings_s2.rs` | 225 | - |
| Backend Rust | `server/founder/src/sign.rs` | 101 | ring×1, wasm-kernel×2 |
| Backend Rust | `server/founder/src/signedcp.rs` | 126 | ring×2, wasm-kernel×2 |
| Backend Rust | `server/founder/src/signin.rs` | 638 | WebSocket×1, ring×2, rustls×1 |
| Backend Rust | `server/founder/src/tls256.rs` | 565 | ring×4, rustls×15, MLKEM×6, Three×1 |
| Backend Rust | `server/founder/src/wt.rs` | 294 | WebTransport×8, ring×6, rustls×19, quinn/h3×14 |

SQL: 59 founder SQL files E100-E199 (RLS, ledgers, selftests; transport-independent, no change needed).

## VERDICTS FOR EVERY FILE THAT TOUCHES TRANSPORT (raw `fetch(` etc.)
| File | Line use | Verdict | Fix |
|---|---|---|---|
| `founder-web/src/api.ts` | get/getOnce/post/put/openStream = raw fetch (7 calls) | **GAP vs Rule 52** (the one door for 17 UI files) | K8d: kernel WebTransport RPC first, fetch only as fallback; with HTTP/3 + Alt-Svc live even the fallback fetch becomes h3 |
| `founder-web/src/devicekey.ts` | POST device-key register with x-device-proof | GAP (a write with custom headers) | route through the same kernel RPC (K8d) |
| `founder-web/src/kernel.worker.ts` | `fetch(KERNEL.url)` loads the pinned wasm | **ALLOWED EXCEPTION**: the kernel cannot carry its own download | none; keep hash pin |
| `founder-web/src/signin_passkey.ts` | pre-login passkey ceremony POSTs | ALLOWED until a session exists (WebTransport hello needs a token) | stays fetch; becomes HTTP/3 automatically through Alt-Svc once K8b is live |
| `founder-web/src/SignIn.tsx` | pre-login password POST | same as above | same |
| `founder-web/src/Surface.tsx` | probe GET of a /keys path | GAP (should use api.get, signed + verified) | K8d: use get() |
| `server/founder/src/tls256.rs` | TCP terminator | FIXED 11 Nov: h2 + http/1.1 fallback, ML-KEM first (K8a/K8c); h2 LIVE-PROVEN 03:40 | install done |
| `server/founder/src/h3.rs` | NEW HTTP/3 listener | CODED + e2e test; OFF until env | enable on [::]:443 (UDP 443 is free in his 03:40 ss) |
| `server/founder/src/wt.rs` | WebTransport live (UDP 4443) | OK; its quic_config now shared with h3 | K8d adds `/wt/rpc` |
| `server/founder/src/front.rs` | SNI front, TCP only | OK (UDP 443 is NOT fronted: the h3 listener binds it itself; awam hosts keep Caddy UDP 18443) | none |
| `server/founder/src/fproxy.rs` | legacy proxy via reqwest | OK; Alt-Svc now follows the bound h3 port | none |

## WHAT THE DEEP AUDIT DID NOT FIND
No WebSocket, no XHR, no Bun/Node in any founder runtime file (grep above). Every UI file except the six above reaches the server only through api.ts. SQL needs no change.

## THE ORDER (tarteeb), matched to the original blueprint (BLUEPRINT-ABC-01NOV.md lettered order is NEVER broken)
1. **K8b enable HTTP/3** on UDP 443 (his env line; UDP 443 free in his fresh ss 03:40) -> Path card must say QUIC. 2. **K8c live proof** of X25519MLKEM768 (read-only openssl on his server). 3. **K8d** api.ts + devicekey.ts + Surface.tsx on the kernel WebTransport RPC (`/wt/rpc`, same gates), `anexoKernel.stats.fetch` ~0, TECH-LAW check K8d-api-not-fetch -> ok. 4. **K7c** his browser key -> enforce. 5. **L** (Framer Motion + GSAP + Three.js WebGPU; fix three types). 6. **M** MoQ. 7. **N..V, X** per FOUNDER-NEXT-ORDER, each with its TECH LAW column. 8. **Q** adds ML-DSA hybrid signatures + OpenPGP PQC.
**D-SERIES (Devices D1-D4, D2b-5) = PAUSED by his word 03:40**: nothing new is added; the code stays preserved for awam (AP9). Only his own hands remain open (policy key-touch, phone/tablet screenshots).
