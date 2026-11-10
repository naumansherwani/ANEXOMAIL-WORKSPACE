> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 09 — ANEXOVideoCall (signaling · ICE · relay · SFU · recording) — sirf copy-paste

## A · relay + host ingress (coturn cert copy Caddy se, ports khud khulte hain)

```bash
cd /opt/anexomail-web && git pull && bash server/caddy/deploy-sites.sh
```

## B · TURN secret sync + SFU media engine (Rust :3500 control / :3501 media)

```bash
cd /opt/anexomail-web && git pull && bash server/rust/deploy.sh && bash server/rust/turn-env-sync.sh
```

Secret sirf server par rehta hai (coturn conf + `/opt/anexomail-rust/.env`, chmod 600),
kabhi print ya repo mein nahi. Readiness ka public arm `chat.turn.health` sirf
`"credential_ready":true` deta hai — asli username/credential sirf authenticated
`chat.turn.credentials` se, is liye bina token 401 hi sahi jawab hai.

Isi deploy mein SFU bhi zinda hota hai: media forwarding **udp 3501** (public,
`ufw allow 3501/udp` script khud karti hai) aur control/readings **tcp 3500**
(sirf loopback). Deploy ke aakhir mein do participants ke darmiyan asli packet
forward hota hai — output mein `OK forwarding: ... bytes` aana zaroori hai.

## C · SFU ka asli proof (jab bhi shak ho, alag se)

```bash
cd /opt/anexomail-web && curl -s http://127.0.0.1:3500/ready; echo && python3 server/gates/sfu-packet-proof.py && curl -s http://127.0.0.1:3500/metrics
```

Yeh khali port nahi khoolta: do UDP participants ek room mein register hote hain,
ek packet bhejta hai, doosre ko wahi bytes milte hain. Na milen to command RED.

## D · gate (signaling arms · ICE creds · coturn 3478/5349 · SFU forwarding · recording · DB · UI)

```bash
cd /opt/anexomail-web && bash server/gates/videocall-gate.sh
```

Signaling Rust :3200 par hai (Wire 04), relay apna coturn hai, SFU apna Rust
media forwarder — koi external video API nahi. SFU sirf forward karta hai
(mixing/transcoding nahi) aur SRTP payload kholta nahi. Recording sirf consent
row ke saath.
