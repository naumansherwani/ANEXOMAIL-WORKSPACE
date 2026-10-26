# RULE 52 — jumla-ba-jumla saboot (26 Oct 2026 19:50 PKT)
Guard test (hamesha chalta hai, `bun test`): `src/lib/kernel/rule52.test.ts` — 16 checks. Yeh tootay to Rule 52 toota. Server: `kernel-check.sh`.
Status sirf: DONE = repo test + live saboot dono | READY = repo test pass, live deploy baaqi | TODO = abhi nahi.

| # | Rule 52 ka jumla | Repo test | Live saboot (Chrome, Pro, anexomail.com, 26 Oct) | Status |
|---|---|---|---|---|
| 1 | WASM kernel browser mein BUILTIN, poori website ke liye | [5][7] AppShell warmKernel | `anexoKernel` har /app page par maujood | DONE |
| 2 | Rust -> WASM, async, Tokio (LocalSet) | [1] Cargo cdylib+tokio, exec.rs | wasm 200 load, abi 1 | DONE |
| 3 | Modules: sha256, hmac, sniff, rank, live, rpc (v0.2.0) | [4] | `anexoKernel.info.modules` = 6 | DONE |
| 4 | EK kernel, version har module ke saath (Cargo = lib.rs = pin) | [2] | version 0.2.0 | DONE |
| 5 | Pin: public/kernel/anexo-kernel-<ver>.wasm + SHA-256, loader mismatch par inkaar | [3] | SHA-256 pin se mila (server kernel-check 19:25 PASS) | DONE |
| 6 | App ka darwaza `src/lib/kernel/boot.ts`; rpc.ts aur live.ts pehle kernel, phir purana raasta | [5][6] | stats.kernel > 0 aur fetch fallback chalta | DONE |
| 7 | Har proc `/wt/rpc` se WOHI server dispatch() (wahi gates) | [12] | gates Pro: Basic par 403 (probe 42/42) | DONE |
| 8 | Request tag HMAC-SHA256(key,"<proc>.<ts>.<sha256hex(input)>"), ticket 15 min, key sirf memory | [9][10] | tagged=3 untagged=0 ticketOk=1; server valid=76 missing=0 invalid=0 | DONE |
| 9 | ANEXO_TAG_MODE observe default / enforce | [11] | server log mode=Observe | DONE (enforce = founder env, ab tayyar) |
| 10 | warmKernel AppShell mount par idle mein | [7] | | DONE |
| 11 | `anexoKernel.stats` = kernel vs fetch asli ginti | [13] | stats dikhti hai | DONE |
| 12 | Typed contract rpc-contract.ts (+test) | [14] | | DONE |
| 13 | Browser mein quinn nahi (browser ka apna WebTransport); quinn/wtransport server par | [1] | | DONE |
| 14 | 3 round test: cargo test / bun test wasm / asli Chromium + asli QUIC | build-kernel.sh [15] + kernel.test.ts | asli Chromium + asli server: yeh doc | DONE |
| 15 | Early-boot: pehli calls fetch par na girein (`kernel_not_used`) | [8] + boot.ts `kernelForCall` | PEHLE: 3 kernel / 8 fetch. BAAD: deploy ke baad naapna | READY (Web pull + Chrome ginti) |
| 16 | "EK QUIC connection" (live@1 /wt/events aur rpc@1 /wt/rpc alag session) | todo [G2] | | TODO (Business phase, founder haan) |
| 17 | "naya feature = naya endpoint NAHI" (ANEXOChat live `/wt/chat` kernel ke bahar, chat-transport.ts) | todo [G1] | | TODO (Business phase, founder haan) |
| 18 | crm.live + org.members Rust par (Bun par `kernel_status_404`) | todo [G3] | fallbackProcs mein dikhta hai | TODO |

## G1/G2 ka design — FOUNDER "HAAN" 26 Oct 19:47 PKT, lekin Business phase mein (Pro green ke BAAD), ANEXOChat ke 25-26 Oct 02:00 wale notes ke upar. Plan: docs/packages/business/ANEXOCHAT-K3-PLAN.md
(wasm + server dono badalte hain, isliye alag deploy)
Ek session `/wt/rpc`; uske andar alag bidi streams: pehle frame par `{"stream":"rpc|events|chat"}`. wtrpc_glue `serve()` events/chat stream ko unke handlers ko deta hai. Kernel `live@1` aur ANEXOChat usi session ko use karein. Version 0.3.0, SHA pin naya, 3 round dobara.

## Live ginti kaise naapen (browser console, Pro login ke baad, page reload ke 6 s baad)
`JSON.stringify(window.anexoKernel.stats)` -> kernel vs fetch; `window.anexoKernel.fallbackProcs` -> kaun se procs fetch par gaye.
