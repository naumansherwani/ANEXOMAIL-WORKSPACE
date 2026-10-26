# ANEXOChat + K3 (ek QUIC session) — Business phase ka kaam (founder 26 Oct 2026 19:47 PKT)
Founder: "G1/G2 haan, lekin tarteeb se. ANEXOChat ka kal raat 2 baje (25-26 Oct) ke aas-paas jo bahut kuch note karwaya tha, yeh us ke UPAR hi chalega. Pro green ke baad Business par aayenge, us mein yeh sab hoga."
Tarteeb: Pro green (abhi) -> Business phase: ANEXOChat + K3 -> CRM P3-P6 -> Business Pro -> Enterprise. Pro green hone tak K3/ANEXOChat par code NAHI.

## Jin purane notes ke upar banega (pehle yeh padho, naya mat ghadho)
- `docs/claude/ANEXOCHAT-CINEMATIC-VOICE-BLUEPRINT.md` (voice Opus+FEC+DTX+WASM, Moon UI, memory-less infra list, implementation order)
- `docs/claude/PRICING-POSITIONING-26OCT.md` sections 7, 8, 9 (ANEXOChat file ladder Business 2GB / Business Pro 5GB / Enterprise 7GB, Personal PRO+ 2GB / Premium 4GB, bandwidth overage, CRDT lock, attachment gating)
- `docs/claude/BULLETPROOF-RELIABILITY-26OCT.md` (bulletproof 5 points)
- `docs/claude/CEO-DECISIONS-AND-FIX-PHASES-26OCT.md`, `docs/cursor-work/founder/packages-pricing-v6-2026-10-25.md`
- `docs/cursor-work/founder/founder-commands.md` 26 Oct 03:10 / 03:15 / 03:30 / 03:42 blocks (founder ke verbatim faisle)
- Chat context file ke 26 Oct 02:30-03:54 blocks. Package gate: Pro mein ANEXOChat NAHI; Business se.

## K3 (Rule 52 G1 + G2) — Rule 52 ka baaqi hissa
- G1: `src/lib/chat-transport.ts`, `chat-signal.ts` ka apna `new WebTransport(/wt/chat)` -> kernel ke andar.
- G2: kernel `live@1` (/wt/events) + `rpc@1` (/wt/rpc) -> EK session, andar alag bidi streams (pehle frame par `{"stream":"rpc|events|chat"}`).
- Server: `wtrpc_glue::serve()` stream ko events/chat handlers ko de; main.rs `wt_session` (chat/mail/signal) ka logic usi session ke stream par. Installer main.rs replace nahi karta — anchor-patch ya naya `_glue` module.
- Kernel 0.3.0 + naya SHA pin + 3 round test dobara (cargo test, bun wasm, asli Chromium + asli QUIC) + rule52.test.ts ke 3 todo (G1, G2, G3) test ban kar green.
- G3: `crm.live`, `org.members` Rust par (Pro page ke liye bhi chalte hain; Rust port Pro green ke andar hi ho sakta hai).
