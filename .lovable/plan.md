# ANEXOChat Primary Transport Correction

## Maqsad
ANEXOChat ko locked blueprint ke mutabiq chalana: **Rust + tRPC-style RPC + WebTransport/QUIC primary**, **Bun port 3300 sirf fallback**. Supabase/PostgreSQL durable source of truth rahega; Caddy HTTP/3 gateway rahega.

## Kaam
1. Repository ki har contradictory line (`Rust baad mein`, Bun-first claims) hata kar primary/fallback contract ek jaisa karna.
2. ANEXOChat browser transport ko primary-first banana:
   - `/wt/*` WebTransport/QUIC realtime path
   - `/rpc/chat.*` Rust command/query path
   - sirf unavailable/unsupported halat mein `/api/chat/*` Bun fallback
   - message states DB acknowledgement se; transport animation se kabhi fake `Sent` nahi.
3. Rust service ke **maujooda** source aur route contract ko inspect karke usi mein ANEXOChat handlers add karna; naya guessed endpoint ya duplicate database logic nahi banana.
4. Caddy contract lock karna:
   - `anexochat.anexomail.com/wt/*` → Rust `:3200` over HTTP/3
   - `/rpc/*` → Rust `:3200`
   - `/api/chat/*` → Bun fallback `:3300`
   - web app → Node SSR `:3000`
5. PM2 roles clear rakhna: `anexomail-rust` primary engine, `anexochat` fallback, dono same Supabase chat RPCs/gate use karein.
6. Verification: Rust health/RPC, WebTransport handshake, Bun fallback, `chat_access()` 403 gate, send idempotency, truthful Sent/Delivered/Read, aur 11 chat tables + 11 functions count.

## Zaroori input / blocker
Repository mein abhi Rust source (`Cargo.toml`/`.rs`) aur asal Caddyfile maujood nahi; sirf running PM2 process ka saboot hai. NO-ASSUMPTION rule ke mutabiq server files guess nahi hongi. Implementation ke server hissa ke liye pehle current Rust source aur relevant Caddy site block ka poora content lena hoga; phir poori replacement files repo mein banengi.

## Technical contract
```text
Browser
  ├─ primary realtime/files: WebTransport / HTTP/3 / QUIC → Rust :3200
  ├─ primary commands/queries: /rpc/chat.* → Rust :3200
  └─ fallback only: /api/chat/* → Bun :3300
                                      ↓
                         Supabase/PostgreSQL truth + RLS
```

Phase 1 foundation isi primary architecture par rahegi; Bun ko kabhi primary ya future Rust replacement nahi kaha jayega.
