# T-SERIES — technology track (founder order 23 Oct 2026 02:29 PKT: "kya aye ga yeh repo main likho")

Audit 23 Oct (repo grep): R3, R4, B8, R2, speed — KUCH BHI BANA NAHI. R5 (event-driven WebTransport push) DONE (B4 GREEN 21 Oct 06:50). Is file ke kaam dobara audit kiye bina mat banao.
**FOUNDER HAAN 23 Oct 02:36 PKT: 'meri haan hai sab pe' — T1..T11 sab manzoor (T5 Stalwart aur T8 Postfix-log ke sath bhi; haan ka matlab ijazat hai, tarteeb locked order ke baad hi).** **T12 (page auto-refresh) par bhi haan (23 Oct 02:47); tarteeb nahi badli — pehle calendar #5..#8 + W3..W5, founder account, identity tests, M-series, G16, phir T-series.**
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

## CEO SUGGESTIONS (23 Oct 02:35, founder: "user hil jaye") — T6..T11. Har ek: user ko kya dikhega / technology / tokio async kahan / pehle kya naapna / honest hadd. Founder "haan" ke baghair shuru nahi.

| # | Kya (user ko) | Technology | Tokio / async kahan | Pehle naap | Honest hadd |
|---|---|---|---|---|---|
| **T6** | **Instant search**: type karte hi 20 ms mein mail + meetings + notes, galat spelling par bhi. Aaj ka asli sach (E64 proof): rare shabd 9-21 ms, par aam shabd 1.4 s (60k meetings) — yeh kamzori pakki hai | `tantivy` (Rust ka full-text index, Lucene-jaisa) ya PostgreSQL FTS ki tuning — **pehle dono ka mukabla**; index org-wall ke saath, background mein update | index build/update `tokio::task::spawn_blocking`; search query async, `JoinSet` se mail + calendar + CRM ek saath; hub event se index taza | E64 ke 60k-row harness par p50/p95 dono | Index ek aur cheez hai jo sync rakhni parti hai; agar PG tuning 100 ms de de to tantivy nahi |
| **T7** | **Mail turant khulti hai**: koi spinner nahi — agli mail pehle se tayyar (prefetch), list scroll par 60 fps | Web: Speculation Rules + service-worker stale-while-revalidate + IndexedDB cache; Rust: ETag/304 + `moka` cache; list ka pehla hissa **stream** (axum chunked) | axum `Body::from_stream` (tokio stream) se pehli 20 mail ~50 ms mein, baaqi peeche | INP (150 ms target), LCP 1.8 s — Chrome DevTools/CrUX | Offline likhna (outbox) alag kaam (PWA) hai; privacy: cache sirf user ke device par, logout par saaf |
| **T8** | **Delivery live + sach**: bheji hui mail ke saamne Delivered / Deferred (wajah: "inbox full", "greylisted") / Bounced, aur "Delivered securely (TLS 1.3, DANE/MTA-STS)" — jhoota "sent" kabhi nahi | **Latest tareeqa (founder: duniya ki latest):** (1) **systemd-journald ka structured JSON stream** (`journalctl -o json --follow` ya `sd-journal`) — file tail + fragile regex nahi; agar Postfix `maillog_file` use karta ho to `inotify` (`notify` crate) fallback. (2) **Join key = Message-ID <-> Postfix queue-id** (cleanup line `message-id=<..>` + smtp line `status=`). (3) **RFC 3461 DSN request** (NOTIFY=SUCCESS,DELAY,FAILURE, ORCPT) bheji mail par + **RFC 3464 DSN parser** (`mail-parser` crate) aane wale bounce ke liye — doosre hop ki sachai. (4) TLS/DANE/MTA-STS nateeja log se (`Verified/Trusted TLS connection established ... TLSv1.3`). (5) Status `mail_outbox_log` (E-series SQL, RLS ON) + hub event -> WebTransport push (B4). Per-recipient timeline. | async log stream `tokio::process::Command` (journalctl) + `tokio::io::BufReader::lines()`, parse `spawn_blocking` nahi (halka), `mpsc` bounded -> batch DB writer (JoinSet, 200 ms coalesce), restart par cursor (journal cursor) se wahin se; backpressure + drop-oldest metrics | **T8-0 PROBE PEHLE (server par, sirf padhna):** Postfix log kahan jata hai (journald ya /var/log/mail.log), format, kitni lines/din, message-id log mein hai ya nahi, queue-id se status milta hai ya nahi | Postfix log ka format version par nirbhar (hamara Postfix 3.10.6); DSN sab server nahi dete; sirf apni domain ki outbound mail; Postfix ko SIRF PADHA jata hai, config nahi badalta (RFC 3461 request Rust SMTP client mein, Postfix config mein nahi); founder haan mil chuki |
| **T9** | **Collision guard live**: shared inbox mein "Ali yeh mail padh raha hai / jawab likh raha hai" — do log ek hi jawab nahi bhejte | WebTransport **datagrams** (kam latency, kho jaye to koi masla nahi) org hub par; presence sirf org ke members ko | `broadcast` hub (B4) + per-session task, 5 s heartbeat, TTL expire | Pro package ka wada ("collision guard") jo abhi poora nahi | Presence privacy: sirf us thread par, sirf org ke andar; band karne ka switch |
| **T10** | **Bade attachment tez**: 25 MB file seconds mein, resume (net toote to wahin se) | tus-jaisa resumable upload Rust mein; Storage Box par `io_uring` (`tokio-uring`/`monoio`) sirf naap ke baad | chunk stream `tokio::io` + semaphore (E72 jaisa pattern) | Storage Box network mount ki asli write speed | io_uring Linux kernel version par nirbhar; resume ke liye chunk table SQL |
| **T11** | **Server "kabhi nahi girta"**: ek dependency (Supabase/clamd/Polar) slow ho to baaqi app tez rahe; status page sach | tower: timeout + load-shed + circuit-breaker, per-dependency bulkhead; OpenTelemetry `tracing` + `/metrics` alerts (p95 > 60 ms) | `tokio::time::timeout`, `select!`, bounded channels, `JoinSet` | Aaj kaun si dependency kitni der leti hai (metrics) | Circuit-breaker galat set ho to khud outage banata hai — pehle shadow mode |

**Tarteeb (CEO sifarish):** T1 -> T2 -> T6 (search, sabse zyada user ko mehsoos hoga, aur 1.4 s ki kamzori asli hai) -> T7 -> T3 -> T8 -> T9 -> T11 -> T4 -> T10 -> T5. Naap pehle, badlav baad mein.

## T12 — "Page khud taza ho" (founder sawal 23 Oct 02:38) — CEO jawab + naya kaam (founder "haan" baaqi)
- **Data ka auto-refresh PEHLE SE HAI (B4, GREEN):** WebTransport hub har org ko "kuch badla" bhejta hai (mail, calendar, crm, work, people, org); `src/lib/live-core.ts` us topic ke React-Query keys invalidate karta hai, page bina reload ke taza (naya mail, naya event, RSVP). Calendar ke outside-feed events bhi `["calendar", ...]` key ke andar hain, to wahi mechanism lagta hai (lekin ek feed ka asli refresh abhi "padhne par" hota hai, background mein nahi — T12 isse bhi theek karega).
- **GAP (sach):** naye deploy ke baad purana tab purani JavaScript chalata rehta hai — isi liye aap ko Ctrl+Shift+R karna parta hai. User ko "naya version tayyar" ka koi signal nahi milta.
- **T12 kya aye ga (user ko):** deploy ke baad khule tabs par chhota banner "Naya version tayyar — Update" ya idle hone par khud soft-reload; draft likhte waqt KABHI zabardasti reload nahi (draft pehle save). Feed refresh: Rust background mein due feeds ko taza karke hub se calendar event bhejta hai (page khulne ka intezar nahi).
- **Technology:** Vite build id (`version.json`, content-hash) + service-worker update flow (waiting -> `skipWaiting` sirf user ki marzi se) + hub mein naya topic `app` (deploy par `pull.sh` -> `POST /internal/event` loopback, B4 mechanism); Rust: tokio interval task (per active org, bounded) due ICS feeds refresh karta hai (`ics_glue::refresh_due` dobara use, JoinSet, semaphore 4 pehle se).
- **Hifazat:** reload ke waqt draft/compose state `localStorage` se bachao (mail drafts pehle se), version check sirf ek chhota file (bytes), bandh karne ka koi switch nahi chahiye par reduced-motion/accessibility theek; tokio task per-org cap.
- **Naap:** deploy ke baad kitne % tabs 60 s mein naye version par aaye.

## Tokio / async KAB aye ga (saaf jawab)
- **Rust + Tokio + axum + wtransport PEHLE SE LIVE hain** (20 Oct se, rustc 1.99.1, edition 2024). Naya kaam (E72 evidence upload, #4c ICS fetch, B4 hub) pehle se Tokio async par hai: semaphore, per-user slot, `spawn`, `spawn_blocking`, timeouts.
- **Naya Tokio kaam jo aye ga:** T1 `sqlx` async pool (har query non-blocking, PostgREST hop khatam) · T3 `JoinSet` fan-out + tokio 1.54 · T6 index `spawn_blocking` + parallel search · T7 streaming responses · T8 async log watcher + `mpsc` · T9 hub + datagrams · T10 chunked async I/O · T11 timeout/select/bulkhead.
- **Jo async NAHI hoga:** Bun fallback (Node-style event loop, naya kaam nahi), Postfix/Dovecot (C), Polar (no-touch).

## Compact ke liye
Is file + NEXT-TASKS (row 11) + DONE-DO-NOT-REPEAT (23 Oct 02:50 audit). Founder ka standing role: khud live dekho, galti/loophole usi waqt theek karo.
