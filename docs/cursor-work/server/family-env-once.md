> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Family passwords — ek dafa /opt/anexomail/.env (no terminal ask)

**LOCK:** Founder password is script **kabhi nahi** touch karti. Lovable `read -s` ask **banned**.

## Nano (server pe ek dafa)

```bash
nano /opt/anexomail/.env
```

File ke **akhir** mein yeh teen lines (values aap ke — chat mein mat paste):

```
HUMZA_PASSWORD=
RAANA_PASSWORD=
MASOOD_PASSWORD=
```

Save: `Ctrl+O` Enter · `Ctrl+X`

Phir:

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-brain.sh && bash server/accounts/create-accounts.sh
```

Expected pehli line: `GREEN create-accounts — no terminal password...`
Agar `Founder (...) password` poochhe → purani file; `git pull` incomplete.

SQL pehle: Supabase #4 → `docs/cursor-work/sql/phase63_f3a_passkey_family.sql`
