> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# SERVER PORTS RED LINE (founder 8 Nov 2026 13:31 PKT, in anger)

His words (gist): these ports carry parts of his server 1 and server 2 TUNNEL and HANDSHAKE traffic; save them in the repo and keep them on TOP; before anything, look at the server DIRECTLY with a command so the red line is never crossed.

RULE: before ANY new listener, test instance, firewall or Caddy change, Claude first gives him a read-only command that lists the listening ports WITH their process names and the live connections to the other server; a port is used only if it is absent from that fresh list AND from this file; ports are never chosen from memory or from the repo. A listed port is never stopped, rebound or reused by a test.

## Ports in use on server 1 (his ss output, 8 Nov 2026 13:28 PKT)
- TCP: 22 25 80 143 443 465 587 993 2019 (Caddy admin, 127.0.0.1) 3000 3100 3200 3210 3300 3310 3400 3478 3500 3600 3601 5349 5678 5679 6379 8443 (founder TLS terminator) 8445 (SNI front, 127.0.0.1) 8891 9201 10023 11332 11333 11334 (+ local DNS 53).
- UDP: 68 323 443 (Caddy HTTP/3) 3443 (WebTransport) 3478 3501 5349 9200 9300 60192.
- Which of these belong to the server 1 / server 2 tunnel and handshake is NOT yet read from the server (process names missing): his next paste fills this in.

## Proposed spare ports for the Caddy test copy (NOT confirmed, not yet used by anything)
HTTPS 18443, HTTP 18080, admin 127.0.0.1:12019. They stay a proposal until his fresh process-name list confirms them free. Nothing was bound, nothing on the server was changed.

## PROCESS MAP read from his server (8 Nov 2026 15:05 PKT, his ss -ltnup output 13:33)
- Public/mail: sshd 22; postfix master/smtpd 25 465 587; dovecot 143 993; caddy 80 443 (tcp) + 443 (udp, HTTP/3), caddy admin 127.0.0.1:2019; turnserver 3478 + 5349 (tcp+udp); opendkim 127.0.0.1:8891; rspamd 11332-11334 (local); postgrey 10023 (local); clamd 127.0.0.1:3310; redis 127.0.0.1:6379; chronyd udp 323 (local); systemd-resolved 53 (local).
- App: bun 3000, 3100, 3300; anexomail-rust 3200 (tcp), 127.0.0.1:3500 3600 3601, udp 3501, udp 3443 (WebTransport); anexomail-founder 0.0.0.0:8443 (TLS terminator), 127.0.0.1:3210 (founder HTTP), 127.0.0.1:8445 (SNI front); axon_core tcp 9201, udp 9200 + 9300; polar-rust-payments 127.0.0.1:3400; node 5678 (all) and 127.0.0.1:5679 (n8n-style, local).
- Established connections seen: Cloudflare (172.64.149.246:443, 104.18.38.10:443), AWS Singapore 52.74.252.201:5432 (Postgres), ONE outbound connection 62.238.98.98 -> 91.98.240.58 port 23 (probably the server-to-server link; NOT confirmed, never touched), ssh sessions, loopback.
- Ephemeral range (outgoing ports) = 32768-60999.
## RESULT: 18443 (tcp+udp), 12019 (tcp) are in NO list above and below the ephemeral range, so they are FREE. 18080 is free but NOT needed (the test config has no http listener). Nothing of the server 1 / server 2 link listens on them.

- 9 Nov 2026 17:50 PKT 18081/tcp (127.0.0.1 only) = anexomail-awam-edge (K5a spare port, free in his 9 Nov 15:52 ss list, proven on 16:14 by the first build; now owned by the separate awam-edge service). 18443 tcp+udp = Caddy (since 9 Nov 15:15). 18080, 18444 stay free.
- UDP 443 is FREE since the K4 switch (his fresh ss 11 Nov 03:40: udp 4443 founder, 18443 caddy, 3443 anexomail-rust); older lines above that list Caddy on UDP 443 are superseded.
