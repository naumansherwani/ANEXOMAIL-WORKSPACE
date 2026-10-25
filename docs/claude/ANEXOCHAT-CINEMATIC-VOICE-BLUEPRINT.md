# ANEXOChat — cinematic voice message + "memory-less" infra blueprint (founder, 26 Oct 2026, docs-only)

Founder ne yeh sab chat mein diya (duplicate "Frontend Audio Extraction" block do baar paste hua tha — neeche sirf ek baar hai, founder ke apne hukm "duplicate ko delete ker daina hai" ke mutabiq). Koi code abhi nahi likha — yeh implementation-order blueprint hai; jab founder "ab likho" bole tabhi.

## Scope — 2 alag cheezein, do alag jagah

1. **General ANEXOMAIL WASM compute kernel** — founder: "yeh humne anexomail ke browser main dalna hai yaad rakho" — yeh poori website ke liye hai, sirf chat ke liye nahi. Client-side heavy-lifting (jahan bhi website par bhari calculation ho) ko Rust→WASM module se browser ke andar hi microseconds mein karna. Scope abhi general hai — konsi exact cheezein is WASM kernel mein jayengi (search, file hashing, bade CRM/calendar filters, PDF/preview processing) founder decide karega jab implement hoga.
2. **AnexoChat voice messages + cinematic Moon UI** — yeh poora hissa `anexochat/docs/anexochat-blueprint.md` ke future phases ka hissa hai (AGENTS.md ke mutabiq ANEXOChat Phase 32+ sirf founder paste karne par banta hai — yeh us blueprint ka naya material hai, is file mein full spec, phase-numbering blueprint file mein jaayegi jab founder paste karne ko kahe).

## A. Voice message pipeline (AnexoChat)

### A1. Capture + encode (client)
- **Web Audio API + MediaRecorder API** — native browser mic capture.
- **Opus codec** — chota size, high-fidelity, already website par listed hai.
- **Opus In-Band FEC (Forward Error Correction) + DTX (Discontinuous Transmission)** — packet-loss survival aur khamoshi ke waqt bandwidth bachana; founder ne dono explicitly mangwaye.
- **WASM Opus encoder (Rust→WASM)** — JS se 10x tez encoding ka claim; is number ko bhi sirf benchmark ke baad publish karna (jhoota "10x" kabhi mat likhna jab tak khud measure na kiya ho).

### A2. Backend (Rust, ANEXOMAIL ki existing stack par)
- WebTransport unidirectional stream se Opus frames receive.
- `rkyv` se raw `&[u8]` par zero-copy deserialize (heap allocation nahi).
- `tokio-uring` + `O_DIRECT` se seedha NVMe disk par stream (network→disk zero-copy path).
- Opus FEC/DTX server-managed adaptation (bad connectivity par packet-loss concealment).

## B. Cinematic Moon UI (button-hold voice recording)

### B1. AnalyserNode ka alternate — founder ne khud poocha "alternate technology aye gi suggest kero"
**Suggestion:** `AnalyserNode` (main thread, smoothed byte data, 0-255 range) ki jagah **`AudioWorkletNode` + Rust/WASM FFT** istemal karo:
- `AudioWorkletNode` audio ko ek dedicated real-time audio thread par process karta hai (main thread/DOM se bilkul alag) — raw `Float32Array` PCM samples milte hain, `AnalyserNode` ke smoothed/byte-capped data se zyada sahi aur kam-latency.
- Un raw samples par khud ka FFT Rust mein (`rustfft` crate) WASM mein compile kar ke chalao — yehi "fastest latest" tareeqa hai jo founder mangwa rahe hain, aur yeh asli mein `AnalyserNode` se behtar hai (dedicated thread + custom precision), sirf "WASM hai isliye tez" wali marketing baat nahi.
- Pipeline: `Mic → AudioWorkletNode (raw PCM, audio thread) → WASM/Rust FFT → WebGL2/PixiJS buffer → canvas render`.

### B2. Teen layers (founder ka design, verbatim se)
1. **Dark Phase → Full Moon Glow (hold state):** button hold par Deep Midnight Blue overlay + realistic Moon texture + silver ambient glow, khamoshi mein bilkul static.
2. **Moon Surface Tidal Waves (sound reaction):** bolte hi silver glow "liquid waves" ki tarah vibrate; bass/treble frequencies "tides" ki tarah moon surface par asar karen (loud = glow phail jaye, dheema = glow sameT jaye).
3. **Star Dust Particle Dispersion (release/send):** button release par saari ambient waves ek jhatke mein lakho chamakte star-dust particles mein toot kar chat thread mein float karti hui upar jaayein.

### B3. Render stack
- **WebGL2 raw vertex/fragment shaders** ya **PixiJS** (WASM-backed, dunya ka sabse tez 2D WebGL renderer) — custom GLSL shaders GPU par seedhe.
- **Perlin/Simplex noise algorithm** (WASM compiled) — audio data noise ko modify karta hai taake waves asal fluid jaisi harkat karein.
- **Fragment shader glow/blur** — `mix(MidnightBlue, MoonSilver, SoundIntensity)` jaisa real-time color blend.

## C. "Memory-less" infra list — founder ke exclusive technology points, CEO review ke saath

Founder ne yeh "dunya mein kisi ke paas nahi" ke taur par diya. Har point tech-wise asli hai, lekin kuch dawe marketing mein overstate ho sakte hain — CEO ki taraf se saaf flag, taake jab publish karein to sach bole:

| Technology | Kya karta hai (asli) | CEO flag |
|---|---|---|
| `tokio-uring` (Linux io_uring kernel bypass) | Network↔disk ke darmiyan copy/syscall overhead kam karta hai, partial zero-copy | **"Server memory na hone ke barabar"** overstatement hai — io_uring copies kam karta hai, RAM ki zaroorat khatam nahi karta. Honest wording: "kam memory-copy, kam syscall overhead", number sirf benchmark ke baad. |
| `O_DIRECT` writes | OS page-cache bypass, seedha disk I/O | Sahi hai, lekin alignment/sector-size constraints hote hain — production mein galat use se data corruption ka risk; feasibility review zaroori hai implement se pehle. |
| `DashMap` / lockless shared state | Multi-core par mutex-free concurrent map | Asli hai, Rust mein maujood crate, scope ekdum fit karta hai (resolve_plan jaisi hot-path state ke liye). |
| PostgreSQL WAL binary replication (seedha consume karna) | Polling/webhook ke bajaye seedha DB ke replication log se events | **Bada architecture badlav hai** — abhi REST/webhook pipeline hai; WAL consumer banane ka matlab crash-safety, replica-slot management, aur ordering guarantees khud handle karna. Yeh M-series migration se bhi bada infra-level kaam hai, apna alag phase/review chahiye. |
| `rkyv` zero-copy serialization | WebTransport payload ko bina parse kiye seedhe raw bytes par kaam | Asli aur fit hai, risk kam. |
| Cryptographic append-only DAG (chat tasks/promises/decisions) | Immutable hash-chain audit trail | Achha enterprise/legal-audit feature hai, lekin naya data model + storage hai — scope ka ek poora phase. |
| WebGPU/WebGL2 raw shaders, physics-gravity UI | Hardware-accelerated cinematic frontend | Visual feature, kam risk, B section mein cover ho chuka. |
| **"Dunya ki pehli..." / "world's first"** label | — | **Publish mat karo jab tak literally verify na ho** — koi bhi "world's first" ka dawa competitors/press challenge kar sakte hain; internal engineering story ke taur par theek hai, public marketing copy mein "class-leading" / "jo zyada tar SaaS stack nahi karte" jaisi safe wording behtar hai. |

## D. Implementation order (CEO ka tajweez, founder confirm kare)

Low-risk, jald dikhne wale se shuru, phir bade infra bets:

1. **V1 — Voice message basic pipeline:** MediaRecorder+Opus capture → upload → Rust decode/store → playback (existing attach/storage infra reuse). Sabse pehle, kyunke baaki sab isi par khara hai.
2. **V2 — Opus FEC + DTX tuning:** V1 ke upar adaptive bitrate/packet-loss handling, real device/network test.
3. **V3 — AudioWorklet + WASM FFT:** `AnalyserNode` replace karna, UI ke liye frequency data ka foundation.
4. **V4 — Moon UI Layer 1** (hold state, static moon, no audio-react) — pure visual, kam risk.
5. **V5 — Moon UI Layer 2** (tidal-wave shader, V3 ka FFT data use karke) — WebGL2/PixiJS + GLSL + Perlin/Simplex.
6. **V6 — Moon UI Layer 3** (release → star-dust transition).
7. **V7 — General ANEXOMAIL-wide WASM compute kernel** (chat se bahar, poori website) — alag workstream, scope founder decide karega.
8. **V8 — Bade infra bets** (tokio-uring/io_uring, O_DIRECT, WAL binary replication, DAG ledger) — **M1-M6/L/F/B8 migration mukammal hone ke baad apna alag phase**, feasibility + crash-safety review ke sath pehle, kyunke galat kiya to data-pipeline tootne ka risk hai ("website kabhi nahi tootni" wale locked rule se takrata agar bina review ke kiya gaya).

Koi bhi V-number abhi shuru nahi hua. Yeh sirf order ka faisla hai — founder confirm kare phir shuru hoga.
