> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 08 — ANEXOChat (feature-by-feature) — sirf copy-paste

ANEXOChat ka engine wahi Rust :3200 hai (Wire 04 se already deployed).
Bun :3300 sirf fallback hai.

## A · fallback process deploy

```bash
cd /opt/anexomail-web && git pull && bun install && pm2 restart anexochat --update-env && pm2 save
```

## B · gate (har feature: message · file · search · continuity · receipts · timeline · health · provenance · collisions · decisions · promise · work · safety · device vault · integrity · email bridge · file context · cost)

```bash
cd /opt/anexomail-web && bash server/gates/chat-gate.sh
```

Gate teen cheezein padhta hai: Rust arm ka asli response, fallback ka `200`,
aur DB mein us feature ki table + RLS. Jo arm ya table missing hai, uska naam
FAIL list mein aayega — main usi ko theek karunga.
