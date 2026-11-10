> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 25 — Account recovery and Brain sync

Status: READY

## One command

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
```

The command now applies phase57, phase58, phase59, then phase56; verifies the live v59 mail contract; builds the web app; and syncs the Brain API without touching `.env`.

## Safety stop

`server/deploy-brain.sh` checks every route imported by `server/index.ts` before restarting PM2. Existing valid modules under `/opt/anexomail/src/routes` are preserved. If any required module is absent from both the repo and the existing Brain installation, deployment stops with `RED Brain import missing` instead of replacing a working process with a broken one.

## Account contract restored

- Signup: legal name, display name, optional role/avatar/preferences, strong password, email confirmation.
- Login, session, logout and revocable device sessions.
- Forgot, reset and signed-in password change.
- Magic-link send and PKCE callback exchange.
- Profile, organisation membership and session storage from phase59.
- Founder/public role data stays outside the profile row.

## Proof required for DONE

```bash
curl -sS http://127.0.0.1:3100/api/health
curl -sS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3100/api/auth/session
bash server/gates/mail-gate.sh
postqueue -p
```

Expected: health JSON with `ok:true`, unauthenticated session `401`, mail gate PASS-only, and an empty queue. Browser proof must separately cover signup confirmation, login, forgot/reset/change password and every protected-route redirect; READY is not DONE until those live checks pass.