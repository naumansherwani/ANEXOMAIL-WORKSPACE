> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Personal pay — separate Polar products

**Status:** READY (repo). **DONE** nahi. Polar Rust webhook no-touch. SQL: `docs/cursor-work/sql/E13_personal_polar_products.sql`.

Do axes mix nahi:

1. **Kind** (signup): Personal | Business — `account_kind`. Polar product nahi.
2. **Paise** (signed-in `/app/billing`): Personal Basic £17 · Personal Pro+ £83 · Personal Premium £1,850.

Public home aur `/plans` par Business cards unchanged hain. Personal prices sirf signed-in Personal Billing par hain.

| Personal Polar product            | Kind     | Workspace naam       | Canonical power                                    |
| --------------------------------- | -------- | -------------------- | -------------------------------------------------- |
| Personal Basic £17 / £187         | personal | **Personal Basic**   | `basic`; Chat/full CRM nahi                        |
| Personal Pro+ £83 / £913          | personal | **Personal Pro+**    | `pro` billed; Business Pro feature power; Org nahi |
| Personal Premium £1,850 / £18,500 | personal | **Personal Premium** | `business_pro`; Org nahi                           |

Six Personal keys checkout ko alag price dete hain, lekin entitlement existing `basic` / `pro` / `business_pro` values mein rehta hai. Is se mail, CRM, chat aur video gates stable rehte hain.

Business account Personal key use nahi kar sakta; guest Personal checkout bhi blocked hai. Missing Polar ID par checkout fail-closed hota hai.
