# Attachments — sabse fast / reliable / advanced (plan, 27 Oct 2026 09:03 PKT)

## Repo mein ABHI KYA HAI (asli code dekh kar)
- server/rust/attach_glue.rs: `POST /file/attach` — **EK single request**, raw body. Tokio async: body `into_data_stream` -> `tokio::fs` par stream (RAM mein poori file nahi), SHA-256 saath-saath, cap paar hote hi rad, 30s per-chunk read timeout, ClamAV INSTREAM (async TcpStream), tmp -> rename (atomic), download 64KB mpsc stream. attach_core.rs: naam safai, bidi/control chars, khatarnak ext + asli exe/ELF bytes, path `<org>/<sha[0..2]>/<sha>-<nonce8>`, dedup sirf org ke andar.
- Browser kernel sha256@1 maujood (web-wasm).
- **NAHI hai (jhoot nahi):** resumable/chunked upload, parallel chunks, browser-hash-pehle "instant dedupe" (upload se pehle server se poochna), per-chunk checksum, secure download link (bade attachments).

## Target (latest, ek ke baad ek, har phase Rule 52 teen round + live proof)
1. **A1 Instant dedupe:** kernel sha256 browser mein -> `attach.have {sha,size}` (Rust, org-scoped; cross-org kabhi nahi, jawab sirf haan/nahi) -> mil jaye to upload zero, sirf nayi mail_attachments row.
2. **A2 Resumable chunked upload (tus-jaisa, apna Rust):** `attach.begin` -> upload_id + chunk size (4-8MB) -> `PATCH` chunk (Content-Range, x-chunk-sha256 per-chunk check) -> `attach.finish` (poori SHA-256 mel, ClamAV, rename). Net toote to `attach.status` se wahin se. Tokio: har upload ka task, tmp file par `File::seek` + write, idle timeout cleanup (tokio::time + sweeper).
3. **A3 Parallel chunks (3-6) over WebTransport/QUIC** (ek QUIC connection, Rule: EK connection) — browser Web Workers/streams se; backpressure Tokio mpsc channel se.
4. **A4 Secure download link** (bade files, expiry + HMAC-signed token, org-scoped) jab size mail cap se bada ho.
5. **Tokio async (founder ka hukm):** sab IO `tokio::fs`/`spawn`/`timeout`/`select!`; blocking kaam (hash bade chunk) `spawn_blocking`; semaphore se concurrent uploads par cap (org/plan ke hisaab se); graceful shutdown mein pending tmp saaf.
6. Gate (pehle jaisa): sirf bhejne wale ke apne plan ki attach_mb limit (E100 plan_catalog: Basic 25, Pro 35, Business 45, Business Pro 60 MB); contact har plan ke beech khula.

## Website ko highest level par — combined stack (Rule 60 ke andar)
- Request path ek hi: React 19/TanStack -> WASM kernel (HMAC tag, sha256, intent, filectx) -> WebTransport/QUIC -> Rust axum/Tokio -> Postgres. Mail/Work/CRM/Compose = fast/clean; cinematic sirf landing/onboarding/ANEXOChat.
- Pending order: ANEXO_TAG_MODE=enforce (tag-enforce.sh) sab se aakhir mein.

## Honest sthiti
Yeh PLAN hai, code NAHI bana. Pro GREEN se pehle ke baaqi live saboot alag (ledger dekhein).
