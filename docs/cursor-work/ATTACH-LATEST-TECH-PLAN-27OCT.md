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

---
## 27 Oct 2026 09:11 PKT — FOUNDER HUKM: BADI FILE (7GB tak, 4K video) = "GOLI" (Email + ANEXOChat dono mein)
Founder: email attachment ya ANEXOChat mein **7GB tak ki file, 4K video tak** send ho; Google Drive jaisa **link** jaye (email mein ya jaise bhi aaye); receiver link kholega to **foran khule, ek dum samne**.
Yeh REPO MEIN HUKM DARJ HAI — abhi CODE NAHI bana (ghalat "ho gaya" nahi kehna).

### Design (CEO + engineer)
- **Upload:** A1 (instant dedupe) + A2 (resumable chunks, 8-16MB tukde, per-chunk SHA-256) + A3 (parallel chunks) — 7GB ke liye resumable ZAROORI (single request nahi). Tokio: semaphore (plan ke hisaab se concurrent), spawn_blocking hash, sweeper idle tmp.
- **Link (A4):** file mail body mein bhejne ki jagah **signed share link** (HMAC-SHA256 token, expiry, org-scoped, revoke ho sake, download count log). Mail mein sirf link + naam + size + preview thumbnail.
- **"Ek dum khule":** link kholte hi page foran: video **progressive stream** (HTTP Range / partial content, MP4 faststart; poori file download hone ka intezar NAHI), image/PDF preview, baqi par Download. 4K ke liye server par **transcode ladder (1080p/720p)** baad ka phase (CPU kharch — pehle original Range-stream, naap kar ke faisla).
- **Scan:** ClamAV bade files par chunk-stream (clamd StreamMaxLength dekhna) — nahi chale to file "scan pending" mark, link phir bhi (policy founder tay kare).
- **Storage/gate (FOUNDER FAISLA BAAQI):** 7GB sab plan par nahi ho sakta — Basic pool 15GB mein 7GB aadha kha jata hai. Plan-wise max single file + share-link quota tay karna: (suggestion) Basic ~2GB, Pro ~7GB, Business 7GB+, retention/expiry ke saath. E100 plan_catalog mein key 'large_file_gb' jodi jayegi tay hone par.
- **ANEXOChat:** wahi protocol (WebTransport par chunks), chat mein link-card + inline player.
- **Privacy:** link sirf token wale ko; dedupe org ke andar; server kabhi nahi batata ke file doosri org mein hai; token guess nahi (>=128-bit random + HMAC).
- **Order:** Pro GREEN ke live saboot -> A1+A2 -> A4 (link+stream) -> A3 (naap ke baad) -> transcode (agar zaroorat).

---
## 27 Oct 2026 09:14 PKT — FOUNDER SAHI KIYA (upar wale hukm ki jagah yeh MAANA JAYE)
- **Email attachment:** limit package ke hisab se wahi rahegi (Basic 25MB, Pro 35MB, Business 45MB, Business Pro 60MB, Business Premium 100MB). 7GB email attachment NAHI.
- **7GB / 4K video:** ANEXOChat ke apne package ke hisab se. Repo ka pehle se locked faisla (CLAUDE-CHAT-CONTEXT ~line 1058): ANEXOChat business ladder par **Business 2GB / Business Pro 5GB / Business Premium 7GB** (Basic/Pro ko ANEXOChat nahi); Personal ladder par **PRO+ 2GB, Premium 4GB**. Yani 7GB sirf Business Premium. Bandwidth overage har package ka apna. Mera pehla 'plan-wise sawal' (Basic ~2GB...) is se KHATAM — founder ka faisla pehle se maujood tha.
- Mail se chat-style link: email mein sirf link jaye to bhi bhejne wale ke ANEXOChat package ki limit lagti hai; email attachment ki alag MB limit apni jagah.
- Link, resumable chunks, foran-khulna, Range-stream ka design upar wala hi; sirf gate = ANEXOChat plan (E100 plan_catalog mein key 'chat_file_gb' jab banega).

## 27 Oct 2026 09:43 PKT — YAAD RAKHNA (FOUNDER): ANEXOChat LIVE hone ke BAAD E100 SQL dobara EDIT hogi (chat_file_gb ladder Business 2 / Business Pro 5 / Business Premium 7 GB aur baqi limits asli ANEXOChat ke hisaab se tay karke). E100 v3 (cc4802b) server par GREEN 14/14 (27 Oct 09:42 PKT). ANEXOChat live hone par: E100 ka chat gate asli upload code se jodna + sql-run AUTO dobara.
