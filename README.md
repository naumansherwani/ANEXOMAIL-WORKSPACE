> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# ANEXOMAIL — FRONTEND ONLY

> **ONLY USE FOR FRONTEND.**
> Yeh repo sirf ANEXOMAIL ka **frontend** (UI + routes + client transport) hai.
> Backend (Bun brain :3100, Rust engine :3200, mail stack, Postfix/Dovecot, Supabase #4)
> **alag** hai aur is repo ka hissa nahi. Yahan koi backend logic add nahi hoti.

---

## Kya is repo mein hai (frontend)

| Folder | Kaam |
| --- | --- |
| `src/routes/**` | Public site + `/app/*` workspace pages (TanStack Start) |
| `src/components/**` | UI components, AppShell, ANEXOChat/VideoCall UI |
| `src/lib/**` | **Transport only** — backend APIs ko call karti hui hooks (`rpcOrRest`) |
| `src/styles.css` | Design tokens / theme |

## Kya is repo mein NAHI hai (backend — alag server par)

- Auth, sessions, permissions
- Mail delivery, Postfix/Dovecot, IMAP/SMTP
- AI (LEO), credits, billing authority, Polar reconciliation
- Supabase #4 schema execution, service-role keys
- Rust engine (`/rpc/*`), WebTransport/QUIC, coturn

Reference copies jo yahan rakhi jaati hain (deploy ke liye copy-paste source, **run nahi hoti**):

- `server/**` → Bun backend files ki repo copy (`/opt/anexomail` par deploy hoti hain)
- `sql/**` → Supabase #4 migrations (dashboard SQL editor mein chalti hain)
- `docs/**` → ops runbooks (Caddy, TURN, storage, Polar)

## Frontend env (sirf ye — koi secret nahi)

```
VITE_API_URL=
VITE_APP_URL=
VITE_BRAND=ANEXOMAIL
VITE_SUPPORT_EMAIL=
VITE_ENV=
```

Service role key, DB URL, OpenRouter key, mail passwords — **frontend mein kabhi nahi**.

## Deploy (frontend)

```sh
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
```

## Local dev

```sh
bun install
bun run dev
```
