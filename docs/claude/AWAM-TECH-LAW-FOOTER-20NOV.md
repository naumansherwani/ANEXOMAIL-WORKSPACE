# AWAM TECHNOLOGY LAW (founder, 20.11.26 04:32 PKT): AWAM = ONLY THE LATEST ADVANCED TECHNOLOGY WRITTEN IN THE LANDING PAGE FOOTER. THAT LIST IS FINAL.

His word (20 Nov 2026 04:28 PKT): "ab se awam sirf latest sab kuch advance technology jo landing page ke footer pe likha hai wohi sirf website final hai, repo ke top pe likh do."
Source of truth = src/components/site/SiteFooter.tsx (const stack). Nothing older, nothing outside this list.

| Layer (footer) | The final technology |
|---|---|
| Built into your browser | A Rust WebAssembly kernel, one kernel for the whole site |
| Backend Engine | Rust, Tokio async runtime, Axum |
| Advance Network Layer | Live WebTransport over UDP, QUIC native pipeline, HTTP/3, Media over QUIC (MoQ, IETF standards track) with seamless cross-protocol HTTP fallback |
| Website | React 19, TypeScript, TanStack Start and Router, Vite 8, Tailwind CSS 4, Radix / shadcn, Framer Motion, GSAP, Three.js with 3D cinematic frontend |
| Data and files | PostgreSQL with row-level security, Hetzner Storage Box for attachments, ClamAV virus scanning |

Rule for every awam phase: write the code ONLY on this list, check each phase against it before GREEN (a listed technology missing = OPEN GAP, never green). Founder and awam stay separate; this law is the awam side.

## QC1e D4A checked against the list (20.11.26 04:32 PKT) - honest gaps (all OPEN, none hidden)
1. Picture bytes sit in PostgreSQL (bytea). The list says Hetzner Storage Box for files. E193 has the 'storage' column ready; move = D4A-G1.
2. No ClamAV scan on the upload yet. The list says ClamAV. Pure client written (server/rust/mail_inline_core.rs, clamd INSTREAM, fail closed); wire into emoji.pack.add = D4A-G2.
3. Browser calls go through the Rust WASM kernel RPC with a plain fetch fallback for large bodies (700 KB upload unproven live). Prove live or move the upload to the kernel path = D4A-G3.
4. Awam web DEPLOY builds with Bun (pull.sh: bun run build:bun). Bun/Node are not on the footer list. His decision needed; NOT changed by me = D4A-G4.
5. Live look pending: server build FAILED on his last pull (asli error in /root/i9/sync-20261119-232050/build.log, waiting his paste) = D4A-G5.

## QC1e D4A P-SERIES ON THE FOOTER TECHNOLOGY (20.11.26 04:34 PKT) - the one table to survive compaction
| P | What | Footer layer | State |
|---|---|---|---|
| P1 | SQL E193 (RLS forced, hash chain, quota) | PostgreSQL with row-level security | PROVEN on his server 03:15 (11/11, CHECK 8/8) |
| P2 | Rust core + image re-encode (image-webp + png) | Rust, Tokio, Axum | INSTALLED on his server 03:49 |
| P3 | Rust glue emoji.pack.* + installer module | Rust, Tokio, Axum | INSTALLED on his server 03:49 |
| P4 | TS pure module + tests | React 19 + TypeScript | pulled 03:50 |
| P5 | Picker Company tab, ':' list, screen now Org Center > Emoji | React 19, TanStack Router, Radix/shadcn | pull FAILED 04:24: manifest-sync lost the renamed route file (git mv shows 'old -> new'); FIXED 20.11.26 04:34 PKT (entry added, sync script patched); needs his pull again |
| P6 | Manifest + gates | n/a | done |
| G1 | bytes to Hetzner Storage Box | Hetzner Storage Box | SQL side WRITTEN 20.11.26 04:36 PKT (E193 edited: storage_key, store_move after clean); Rust upload to the Box = OPEN (needs his Storage Box access) |
| G2 | ClamAV on upload (fail closed) | ClamAV | SQL side WRITTEN 20.11.26 04:36 PKT (scan_state, scan_set, infected never active); Rust clamd call = OPEN (needs clamd address) |
| G3 | upload through the Rust WASM kernel RPC (700 KB) | Rust WebAssembly kernel, WebTransport | OPEN, unproven live |
| G4 | awam deploy builds with Bun | not on footer list | OPEN, his decision |
