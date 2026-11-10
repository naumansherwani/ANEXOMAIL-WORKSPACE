> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# F3 — Mail Inbox (Rust PRIMARY)

**Date:** Sep 10 2026  
**Status:** **READY** (repo). **DONE** nahi — live test + `bash server/rust/deploy.sh` baqi.

## Technology (constitution)

| Path | Role |
|---|---|
| Rust `:3200` `/rpc/mail.threads` · `mail.counts` · `mail.accounts` · `mail.labels` · `mail.star` | PRIMARY |
| Rust UDP 3443 `/wt/mail` hello `{ token, mode: "mail" }` | PRIMARY live stamp |
| Bun `:3100` `/api/mail/*` | FALLBACK only (Rust 404/502/503) |

Mail identity = `org_members` (Basic/Pro inbox chalti hai). `chat_access` nahi.

Frontend: `rpcOrRest` — pehle Rust, phir Bun. `rpc.ts` same-origin BASE empty-string fix.

## Hosts (parallel, same wire)

| Host | Mail |
|---|---|
| `anexomail.com` | Awam inbox |
| `ai.anexomail.com` | Coming Soon — SiteLock `/` only |
| `founderworkspace.anexomail.com` | Same inbox + founder rail |

Landing / Polar / packages / `host.ts` / `AppShell` — no touch this pass.

## Founder test

```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
bash server/rust/deploy.sh
```

Login → Mail. List Rust se (header chip: `Rust WT live` ya `Rust RPC · poll`). Inbox zero = real empty. Phir next (F4) founder ke test ke baad.
