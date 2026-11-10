> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Auth — Create your account for workspace (login UX)

**Status:** READY (repo). **DONE** nahi jab tak live login + kind cards founder dekhe.

Polar / `plans.ts` / landing cards **no-touch**. `/plans` landing pe rehta hai. Login footer se **nahi**.

## Lovable pehle se (rakhha)

Signup POST `/api/auth/signup` — yahi fields:

- Full legal name, display name
- Work role + photo URL (optional, collapsed)
- Email, password 6–15, confirm
- Recovery kind + recovery email (SMS nahi)
- Device vault + family skip
- Passkey enrol after signup (awam)
- Then `/claim` → `@anexomail.com` → `/onboarding`

Login: email + password, passkey, magic link, forgot/reset. Social nahi.

## Ab flow (login pe)

1. **Sign in** — mail, people, calendar, work. Passkey / link neeche.
2. **New here? Create your account for workspace** (pehle “Choose your package” → `/plans` tha — hata diya).
3. **Kind cards** — Personal | Business (do columns). Polar SKU nahi.
4. **Create your account** — Lovable form. Kind `preferences.workspace_kind` mein save.
5. Passkey → **`/plans`** → Polar checkout. Payment success: Personal `/dashboard` · Business `/onboarding` (org name + domain). CRM Billing = `/app/billing`.

Masood / Humza **buyers** — is flow se nahi; seedha Sign in.

## Rust lock (next phases)

Naya backend **Rust :3200** `/rpc` + `/wt`. Auth **E2 Bun** rehta hai. Polar webhook no-touch.
