> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Founder pattern — Get started / Sign in / Polar / land

**Status:** READY in repo. Polar rust payment `:3400` no-touch.

ANEXOChat Polar pe **Business account** ka offer hai. Personal Pro ko wahi **power** milti hai (Org nahi).

## Door 1 — Get started

Get started → `/plans` → card Get started → Polar checkout.

Payment success → recovery account pe Polar/engine wali email. Codes no-touch.

## Door 2 — Sign in then create workspace

`/auth` Sign in. Footer: **Create your account for workspace** → Personal | Business → form.

Account create ke baad → `/plans` (dashboard nahi, claim skip nahi tore — pehle plan).

`/plans` → Polar. Success:

- **Personal** → `/dashboard`. CRM → Billing = existing `/app/billing` (Supabase entitlement, Polar messenger).
- **Business** → `/onboarding` organisation name + domain, phir dashboard. CRM Billing wahi.

Existing buyers Sign in → workspace. `/plans` nahi.

## Files (polish only)

`SiteNav` Get started · `auth.tsx` signup land `/plans` · `PlanCheckoutButton` `return_to` · `billing-sync.ts` success_url query · `checkout.done.tsx` · CRM nav Billing → `/app/billing`.

**Banned:** `plans.ts` · Polar product IDs · `server/rust/polar-payment/` · polar webhook bridge.
