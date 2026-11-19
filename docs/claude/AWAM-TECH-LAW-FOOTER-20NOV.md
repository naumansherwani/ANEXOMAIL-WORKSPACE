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
| G1 | bytes to Hetzner Storage Box | Hetzner Storage Box | SQL side WRITTEN 20.11.26 04:36 PKT (E193 edited: storage_key, store_move after clean); Rust WIRED 20.11.26 04:52 PKT: emoji.pack.add writes sha-addressed file emoji/<org>/<sha>.webp on the existing Box mount /mnt/anexomail-box, read-back sha check, then SQL store_move; emoji.pack.get reads it back verified; remove deletes it. Needs his SQL E193 rerun + Rust install |
| G2 | ClamAV on upload (fail closed) | ClamAV | SQL side WRITTEN 20.11.26 04:36 PKT (scan_state, scan_set, infected never active); Rust WIRED 20.11.26 04:52 PKT: clamd 127.0.0.1:3310 (the one already on his server; EMOJI_CLAMD/FMAIL_CLAMD override), FAIL CLOSED before anything is saved. Needs his SQL E193 rerun + Rust install |
| G3 | upload through the Rust WASM kernel RPC (700 KB) | Rust WebAssembly kernel, WebTransport | OPEN, unproven live |
| G4 | Bun | not on footer list | 20.11.26 04:41 PKT his order 'D4A ko Bun se hata do': D4A code has ZERO Bun (Rust endpoint + SQL + React/TS; only a unit-test file imports bun:test, a sandbox test tool). The Bun that remains is the SITE-WIDE host of ALL awam (pull.sh build:bun; 306 of 475 endpoints still Bun-only): removing it now would take the whole awam site down. Tracked in docs/claude/LOVABLE-BUN-MIGRATION-PLAN-03NOV.md (Bun endpoint goes only after its Rust twin is GREEN + his cutover word). NOT a D4A item any more. |

## G4 = REMOVE BUN FROM AWAM (his order 20.11.26 04:42 PKT: "sab bun se hata do, sirf advance technology") - PLAN, nothing changed on his server yet
Facts (repo): awam web = TanStack Start SSR built by Nitro 'bun' preset, run by pm2 with interpreter Bun on :3000 (ecosystem.config.cjs); the only server route is /health; pull.sh builds on the server with 'bun run build:bun'.
Proven in my sandbox 20.11.26 04:42 PKT: with tanstackStart spa.enabled the SAME code builds to pure static files (.output/public with _shell.html, assets, sw.js): no JS runtime is needed to serve it.
Target (footer list only): build in the repo/sandbox (like founder-web/dist), commit the static bundle; Caddy serves it as files (try_files then /_shell.html), the 1-line /health moves to Caddy respond; Rust :3200 stays the engine. No Bun, no Node on the server runtime, NO new port (Caddy already owns 443).
Trade-off to confirm with him: no server-side rendering; public pages (landing) are filled by the browser; prerender of the landing page is possible to keep search text.
Steps (each ends with proof): S1 his read-only Caddy paste; S2 spa build committed; S3 Caddy test host on a spare name, my Chrome look; S4 switch with rollback to the Bun process; S5 stop pm2 anexomail-web; S6 pull.sh stops calling bun.
