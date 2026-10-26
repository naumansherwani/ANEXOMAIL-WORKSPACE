# CINEMATIC FRONTEND STACK — duniya ki latest 3D / cinematic technologies, kaun si hain, kahan lagengi (27 Oct 2026 00:55)
Founder (00:48): "three.js jaisi duniya ki jitni latest cinematic frontend technology hai woh use hogi — list batao." Yeh list repo ke sach (package.json + src) par bani hai; "ADD" wali cheezein CEO proposal hain, install ke waqt exact version pin + bundle measure.

## A. PEHLE SE INSTALLED aur KAHAN use ho rahi hai (sach, 27 Oct)
| Technology | Version | Kahan (files) | Halat |
|---|---|---|---|
| **three.js** (WebGL 3D) | 0.185.x | `components/fx/{Orb,Logo,Mailbox,Gem}Scene.tsx`, `Stage.tsx`, chat `cinema/Scene.tsx` | LIVE |
| **React Three Fiber** (R3F, React mein three) | 9.7 | wahi 6 files + `crm/CrmStage.tsx` | LIVE |
| **drei** (R3F helpers) | 10.7 | 1 file | LIVE (kam) |
| **@react-three/postprocessing** (bloom, glow) | 3.0 | 1 file | LIVE (kam) |
| **GSAP** (timeline animation) | 3.15 | 2 files | LIVE (kam); **ScrollTrigger plugin abhi use nahi** |
| **motion / framer-motion** (UI animation) | 13 | 16 files | LIVE (sab app) |
| **lottie-react** (After Effects animations) | 2.4 | 1 file | LIVE (kam) |
| **tone.js** (Web Audio engine) | 15.1 | 0 files | INSTALLED, use NAHI (voice/UI sound ke liye tayyar) |
| Globe view (calendar) | custom | `calendar/GlobeView.tsx` | LIVE |
| Recharts / Radix / vaul / cmdk / sonner | — | app UI | LIVE |

## B. ADD karne wali latest technologies (CEO list) — kahan, kis feature mein, kab
| # | Technology | Kyun / kya karti hai | Kahan lagegi | Package | Kab |
|---|---|---|---|---|---|
| 1 | **WebGPU renderer (three/webgpu + TSL shaders) + WebGL2 fallback** | agli peedhi ka GPU API, compute shaders (lakhon particles), zyada tez | landing hero, ANEXOChat Moon UI, dashboards ka accent | marketing + Business+ chat | CINEMA phase (K3 ke baad); WebGPU har browser mein nahi => WebGL2 fallback lazmi |
| 2 | **GSAP ScrollTrigger + ScrollSmoother / Lenis** | scroll-driven cinematic storytelling, smooth scroll | landing/pricing/marketing pages | public site | landing phase (Business/Business Pro plans page fix ke saath) |
| 3 | **Theatre.js** (3D/animation sequencer) | camera + scene ki timeline ek editor se, "film" jaisa control | landing hero, onboarding intro | public | landing phase |
| 4 | **Rapier physics (Rust->WASM, `@react-three/rapier`)** | asli physics (gravity, collisions) — hamare Rust/WASM stack se mel | ANEXOChat moon/orb interaction, playful empty states | Business+ chat | K3 ke saath |
| 5 | **Custom GLSL/TSL fragment shaders** | Moon glow, liquid waves, sound-reactive (blueprint section B) | ANEXOChat voice-hold Moon UI | Business+ | V4-V5 (voice blueprint order) |
| 6 | **Web Audio + tone.js + AudioWorklet (+ WASM Opus)** | sound-reactive visuals, UI sound design, voice | ANEXOChat voice, send/receive sounds | Business+ | K3 |
| 7 | **OffscreenCanvas + Web Worker rendering** (`@react-three/offscreen`) | 3D main thread se bahar => UI kabhi nahi atakta | har 3D scene | sab | jab 3D heavy ho |
| 8 | **KTX2/Basis textures + Draco/Meshopt model compression** | chhote 3D assets, tez load, kam GPU memory | har 3D model/texture | sab | pehle assets aate hi |
| 9 | **Rive** (interactive vector animation) | chhoti, state-driven, GPU animations (Lottie se halki) | onboarding, empty states, buttons | sab | polish |
| 10 | **CSS scroll-driven animations + View Transitions API** | bina JS ke scroll/page transitions (progressive enhancement) | app navigation, landing | sab | polish |
| 11 | **Spline / Blender -> glTF pipeline** | designer-made 3D hero assets | landing, plan cards | public | landing phase |
| 12 | **WebXR / spatial (sirf mansoobay ke taur par)** | VR/AR meeting rooms | NAHI — abhi plan mein nahi (CEO: demand dikhne par) | — | — |

## C. LAZMI QAIDE (cinematic ka matlab "bhaari" nahi)
1. **Cinematic sirf jahan kaam ka hai**: landing, onboarding, ANEXOChat voice/moon, dashboard accent, loaders. **Mail/Work/CRM ke kaam wale screens fast + saaf** rahenge (Office suite, tables = performance pehle).
2. **Har 3D/WebGL chunk lazy** (dynamic import), SSR par band (client-only), bundle KB + INP/FPS measure karke repo mein likho (jhoota "10x" nahi).
3. **GPU tier fallback**: kamzor device/`prefers-reduced-motion`/battery saver => static image ya halka animation; WebGPU na ho => WebGL2; WebGL na ho => CSS.
4. **Accessibility**: motion band karne ka option; contrast; keyboard; sab text English.
5. **Rule 52 ka asar**: 3D/animation sirf UI hai; data hamesha kernel se. WASM kernel mein physics/audio DSP wali heavy cheezein (Rapier, Opus) rakh sakte hain, taake React main thread halka rahe.
6. Naya dependency = pehle yahan list mein, phir install, exact version pin (founder ijazat jab Cargo/npm mein bada crate/package judta ho).

## D. Tarteeb (MASTER-GREEN-PLAN ke saath)
Abhi: Basic/Pro migration (kernel). Phir: step 9 Business — ANEXOChat K3 + Moon UI (items 1,4,5,6). Landing/plans page phase (items 2,3,11) = founder ka "Business/Business Pro plans landing/profile/billing" fix ke saath. Polish (9,10) aakhir mein. Calendar tareekh repo mein nahi.
