> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 03 GATES — founder pehchan ke 7 alag tareeqe (sab purane, ek jaisa nahi)
| # | Jagah | Kaise pehchanta hai |
|---|---|---|
| 1 | server/lib/founder-gate.ts (+core) | FOUNDER_EMAILS email YA founder_accounts, `admin.auth.getUser` network call |
| 2 | server/routes/founder.ts ctx() | apni FOUNDER_EMAILS copy + founder_accounts |
| 3 | server/routes/org.ts founderGuard | FOUNDER_EMAILS (org-authz) + founder_accounts |
| 4 | server/routes/crm.ts founderOnly | alag check |
| 5 | server/routes/billing-support.ts requireFounder | sirf founder_accounts (sahi tareeqa) |
| 6 | server/routes/analytics.ts who() | FOUNDERS email list + getUser |
| 7 | server/routes/auth.ts ~790 | FOUNDER_PASSWORD login path (LOOPHOLE) |
Awam client: src/lib/host.ts isFounderHost() = founderworkspace.* (+ localhost, lovable.app) ; SiteLock.tsx founder host open; auth.tsx `is_founder` flag.
**Naya gate:** Rust authed(): Bearer ES256 JWT local verify (JWKS) + uid in founder_accounts. 401/403. Bas yehi ek rakhna hai (FC3).
