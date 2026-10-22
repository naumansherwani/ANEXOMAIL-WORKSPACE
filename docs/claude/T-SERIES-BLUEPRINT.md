# T-SERIES — technology track (founder order 23 Oct 2026 02:29 PKT: "kya aye ga yeh repo main likho")

Audit 23 Oct (repo grep): R3, R4, B8, R2, speed — KUCH BHI BANA NAHI. R5 (event-driven WebTransport push) DONE (B4 GREEN 21 Oct 06:50). Is file ke kaam dobara audit kiye bina mat banao.
Tarteeb locked: T1 -> T2 -> T3 -> T4 -> T5. Kab: calendar + world clock -> founder account -> 6 identity live tests -> M-series -> G16 ke BAAD; T1/T2 chhote hain, G16 se pehle aa sakte hain (shuru karne se pehle founder se EK sawal).
Har step Rule 46: SQL -> Rust installer -> Rust restart+health -> Brain installer -> Web pull, sirf jo badla. Har step: pehle naap, phir badlo, phir differential/live saboot; fail par rollback script.

## T1 — R4: seedha Postgres pool (Rust)
- **Kya aye ga:** `sqlx` (ya `tokio-postgres` + `deadpool-postgres`) Cargo.toml mein; ek shared pool (`DATABASE_URL` read-only/service role alag), prepared statements, statement_timeout, pool size naap kar.
- **Kahan:** sirf garam raaste pehle: `mail.list`/thread read, `calendar.events`, `dashboard.*`, `calendar.sub.events`. Baaqi PostgREST (`sb_select`/`sb_rpc`) par rehte hain — dheere dheere.
- **Kyun:** har query par ek extra HTTP hop khatam (p50 kam), transactions (multi-statement atomic), LISTEN/NOTIFY mumkin.
- **Hifazat:** RLS service_role ke zariye wahi rules; org wall SQL function mein rahe; connection string sirf env (/etc/anexomail), repo mein kabhi nahi; pgbouncer ke saath prepared-statement mode dekhna.
- **Saboot:** pehle/baad latency (oha), same JSON output differential test, 24 ghante RSS stable, pool exhaustion par graceful 503.
- **Phir:** LISTEN/NOTIFY dobara dekhna — kya B4 reconcile (2 s) ki jagah NOTIFY behtar hai (sirf naap ke baad).
- **Installer:** naya `pg` module `rust-engine-install.sh` mein + Cargo.toml surgical (mig jaisa), restore-on-fail.

## T2 — R3: typed contract (Rust -> TypeScript)
- **Kya aye ga:** `ts-rs` (ya `specta`) se Rust ke input/output structs ka TS type auto-generate; `src/lib/generated/rpc-types.ts`; haath ke duplicate types dheere dheere hatana.
- **Kahan:** pehle naye procs (calendar.sub.*, appeal.*), phir purane.
- **Saboot:** CI test — generate dobara chalao, `git diff --exit-code` (drift pakda jaye); tsc clean.
- **Hadd:** abhi RPC wire "tRPC-jaisa" hai (library nahi) — wahi rahega.

## T3 — B8: Bun/tokio upgrade, phir Brain -> Rust
- **Pehle:** Bun 1.4.0 -> 1.4.3 (sirf website SSR host) aur tokio 1.53.x -> 1.54 (`rust-crate-upgrade.sh`, patch release ek hafta purana hone par). Scratch par check, phir live.
- **Phir Brain (MEASURED 23 Oct: 304 endpoints, `server/routes/*.ts`, 41 files; purana "504" andaza tha):** har route file ke liye differential test (Bun jawab == Rust jawab), phir Rust par, Bun fallback standby. Tarteeb: kam-risk read routes -> write -> auth/billing sabse aakhir.
- **Naya kaam is raste se Rust mein hi** (Rule 25). Bun mein naya endpoint nahi.
- **Saboot:** har route ka endpoint-by-endpoint checklist file (docs/cursor-work/GREEN-BOARD) mein tick, live Chrome + nakli-token probe.

## T4 — Speed (naap pehle)
- **Naap:** k6/`oha` load test, targets p50 < 15 ms, p95 < 60 ms RPC (Supabase hop ke baghair), mail enqueue < 100 ms, 0 panics, RSS stable, graceful shutdown < 5 s.
- **Phir (sirf jahan naap kahe):** `mimalloc` allocator, `moka` in-process cache (TTL + single-flight), ETag/304, `sonic-rs`/`simd-json` hot JSON, PGO build.
- **Qaida:** naap ke baghair koi optimisation nahi; 10% se kam fayda ho to wapas.

## T5 — R2: Stalwart / JMAP
- **Sirf founder "haan" ke baad.** Parallel staging (alag port/domain), Postfix+Dovecot production raasta kabhi nahi tootta. Stalwart (Rust: SMTP/IMAP/JMAP/CalDAV) agar staging mein behtar saabit ho tab hi replace plan; JMAP native/phone client ke liye. CalDAV (#6) se milta-julta hai — ek saath dekhna.

## Compact ke liye
Is file + NEXT-TASKS (row 11) + DONE-DO-NOT-REPEAT (23 Oct 02:50 audit). Founder ka standing role: khud live dekho, galti/loophole usi waqt theek karo.
