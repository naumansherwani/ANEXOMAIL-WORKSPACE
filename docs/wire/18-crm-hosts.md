> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 18 — CRM DO HOST (aicrm + AI-free crm) — sirf copy-paste

Founder: Muhammad Nauman Sherwani

Do host, ek hi pipeline:

- `aicrm.anexomail.com` → `/app/crm` — **AI CRM** (Leo insight panels ON)
- `crm.anexomail.com` → `/app/crm` — **AI-free CRM** (same leads/pipeline, AI panels OFF)

Dono ab repo-managed hain (`server/caddy/aicrm.Caddyfile`, `server/caddy/crm.Caddyfile`),
is liye deploy script khud wire karti hai — koi nano nahi.

## A · DNS (sirf yeh manual hai)

Registrar/Hetzner panel mein do A record, wahi IP jo `anexomail.com` ka hai:

| Type | Host | Value | TTL |
|---|---|---|---|
| A | `aicrm` | server ka public IP | Automatic |
| A | `crm` | server ka public IP | Automatic |

## B · deploy (Caddy blocks + cert + reload)

```bash
cd /opt/anexomail-web && git pull && bash server/caddy/deploy-sites.sh
```

## C · gate (asli HTTP code + h3 + founder-leak check)

```bash
cd /opt/anexomail-web && bash server/gates/web-gate.sh
```

Gate in dono host ka `/`, `/app/crm`, `/app/crm/leads`, `/app/crm/pipeline`,
`/app/crm/activity` padhta hai, HTTP/3 (`alt-svc: h3`) confirm karta hai, aur yeh
bhi ke `/app/founder` in host par band hai (404/403/302). Poora output mujhe do.
