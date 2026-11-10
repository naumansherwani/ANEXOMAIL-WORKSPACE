> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Frontend — docs/cursor-work/frontend/

Ab se har frontend change ka record yahan.

## Pull + build command (hamesha yahi ek)
```bash
cd /opt/anexomail-web && git pull && bun install && bun run build:bun && pm2 restart anexomail-web && pm2 save
```

## Status
| File | Kya badla | Status |
|---|---|---|
| src/routes/auth.tsx | Password Eye icon fix | READY — pull se aayega |
| src/lib/api.ts | Error message fix | READY — pull se aayega |
| src/lib/host.ts | isPublicMailHost() | READY — pull se aayega |
| src/components/site/SiteLock.tsx | anexomail.com bypass | READY — pull se aayega |
| src/routes/app.tsx | /app → /auth redirect | READY — pull se aayega |
| src/components/app/AppShell.tsx | Awam nav hide | READY — pull se aayega |
| F3 mail inbox | ThreadList + MailRail + /api/mail/threads + counts | READY — live unproven |
| F3 A family testers | `f3a-family-awam-testers.md` + `sql/phase63_f3a_passkey_family.sql` — WebAuthn store, recovery, family grants | READY — live unproven |
| F3 B awam onboarding | `f3b-awam-onboarding-polish.md` — Personal\|Business, no day-1 domain, claim skip, org API fix | READY — live unproven |
| Personal vs Business kind | Polar SKU alag nahi — `personal-business-kind.md` + `sql/phase65_account_kind.sql` | READY — live unproven |
| Auth kind cards | Login “Choose your package” hata → Create your account for workspace + Personal\|Business cards | READY — live unproven |
| Personal Polar map | `personal-polar-map.md` — paise landing 4 cards; Personal Basic/Pro/Premium = Polar Basic/Pro/Business Pro + kind | READY — live unproven |
| Checkout + signup land | `checkout-signup-pattern.md` — Get started `/plans`; new account `/plans`; pay then Personal dashboard / Business org; Polar rust payment no-touch | READY |
