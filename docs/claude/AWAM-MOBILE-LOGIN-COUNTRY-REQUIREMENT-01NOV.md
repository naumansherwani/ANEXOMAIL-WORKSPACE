> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Awam side — mobile-number login + mandatory country at sign-up (founder, 1 Nov 2026 12:45)
Founder: "main awam side ke liye ab mobile number se login wala system bhi leke aa raha hoon. account create ke andar awam side apni country bhi likhe gi, yeh lazmi hai. yeh awam side pe repo main likh lena."
**Status: REQUIREMENT ONLY. No awam code is written here** (awam is its own phase; founder side never mixes with awam, Rule 35; awam stays on its current stack until a written order).

## Requirements as given
1. **Mobile-number login** for awam users (a second way to sign in besides email). The number is a verified identity, stored in E.164.
2. **Country is mandatory at account creation** (awam sign-up form). Required field, not skippable; stored as ISO 3166-1 alpha-2.

## Questions the founder must settle before any awam build (not guessed here)
- Login = SMS OTP only, or OTP + passkey/password? (Awam already has passkey-required-by-deadline for business accounts, see FINAL-FOUNDER-BLUEPRINT.)
- SMS provider (cost per country; Pakistan and Gulf routes) and whether the same provider serves the founder recovery (founder step 7-5).
- Existing users: forced to add country on next login? (needed for the mandatory rule to mean anything).
- Number uniqueness: one number per account? Recycled-number handling.
- Abuse: OTP rate limits per number/IP/country, SIM-swap signals (awam "who changed what" ledger entry on a number change).

## Where it will live when ordered
Awam sign-up/sign-in routes + SQL (E-series, E-file + CHECK) + awam Settings → Privacy row ("Sign in with mobile number"), with Explain / Blast radius / History like every awam setting. It must not reuse founder tables; if a shared OTP provider is chosen it is called from each side separately.
