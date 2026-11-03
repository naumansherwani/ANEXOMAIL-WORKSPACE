# ANEXOChat · PHASE 13 + 14 + 15 — FILE ENGINE (locked)

Technology: **PostgreSQL (Supabase #4) + Rust + tRPC-style RPC + WebTransport/QUIC + Caddy HTTP/3**.
Bun (`anexochat`, 3300) sirf FALLBACK. Koi duplicate feature nahi — Phase 11 image
attachments (200 MB, `chat_attachments`) alag rehta hai; yeh large-file engine hai.

## Phase 13 — File engine (transfer ≠ storage)

**FOUNDER CHART 3 Nov 2026 13:09 (replaces the old 2 GB / 5 GB / unlimited table; code = `phase61_file_limits_quota.sql`):**

| Cheez | Business | Business Pro | Business Premium |
|---|---|---|---|
| Single file max | 500 MB | 1.5 GB | 4 GB |
| Monthly transfer per user | 50 GB | 150 GB | 400 GB |
| Org transfer pool | 20 x 50 GB = ~1 TB | 570 x 150 GB = 85.5 TB fair-use | unlimited users, 400 GB per user |
| Pooled workspace storage | 256 GB | 1 TB | 1 TB (his word needed) |
| Versions kept | 10 | 30 | 50 |

Transfer is throttled at 100%, never blocked. Nothing is unlimited.

- Storage = jo bytes rakhi hui hain (`chat_file_versions` state `ready` ka jama).
- Transfer = jo bytes chali (`chat_transfer_ledger`, append-only). Dono kabhi mix nahi.
- **Versioning**: same naam dobara = nayi version, purani zinda (`file_versions`).
- UI: `ABC Ltd — 684GB / 1TB` wali reading `file_pool_state()` se aati hai, guess nahi.

## Phase 14 — Rust large-file engine

`Browser → WebTransport/HTTP3 (QUIC) → Caddy → Rust (3200) → Storage`

- Chunking 8 MB (`chunk_size` DB mein per version record).
- **Integrity**: client har chunk ka sha256 bhejta hai; Rust khud dobara sha256
  nikaalta hai. Match = `verified`, mismatch = `corrupt` (409) aur chunk storage
  tak jaata hi nahi.
- Concurrency plan se (`max_concurrent`), backpressure = 24 MB inflight cap.
- Progress sirf `verified` chunks ka jama — jhooti 100% kabhi nahi.

## Phase 15 — Resumable (up to the package's per-file max)

- Resume identity = workspace + conversation + naam + bytes + fingerprint
  (head 1 MB + tail 1 MB + size ka sha256). Wahi identity dobara = **wahi version**
  aur missing chunk list.
- Connection gaya → `Transfer paused` (bytes server par mehfooz). Wapis aaya →
  `Connection restored. Resuming from 94%`. Zero se kabhi nahi.
- Corrupt/missing chunk recovery: commit par server missing + corrupt list deta hai,
  engine sirf woh chunks dobara bhejta hai.

## Contract

Rust PRIMARY (`/rpc/*`, port 3200):
`file.state` · `file.begin` · `file.transfer.state` · `file.transfer.mark` ·
`file.commit` · `file.versions` · raw `POST /file/chunk`
(headers: `x-transfer-id`, `x-chunk-index`, `x-chunk-sha256`).

Bun FALLBACK (`/api/chat/file/*`, port 3300): `state` `begin` `chunk` `transfer`
`mark` `commit` `versions` — same contract.

DB: `sql/phase13_15_file_engine.sql` (idempotent).
Frontend: `src/lib/chat-files.ts` + `src/components/app/chat/FileTransfers.tsx`
(mounted on `/app/storage`).

## Deploy (koi nano nahi)

```bash
# 1) Supabase #4 SQL editor: sql/phase13_15_file_engine.sql paste karo
# 2) Rust primary
cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh
# 3) Bun fallback + frontend
cd /opt/anexomail && git pull 2>/dev/null; pm2 restart anexochat
cd /opt/anexomail-web && bun install && bun run build:node && pm2 restart anexomail-web
```

Caddy (anexomail.com block) mein Rust ke liye:

```
handle /rpc/* { reverse_proxy 127.0.0.1:3200 }
handle /file/* { reverse_proxy 127.0.0.1:3200 }
request_body { max_size 32MB }
```
