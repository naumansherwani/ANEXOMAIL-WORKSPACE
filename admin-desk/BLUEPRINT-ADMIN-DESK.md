# ADMIN DESK BLUEPRINT (live copy of the Desk phases; his order 21 Nov 2026 08:19 PKT)
Updated: 21 Nov 2026 08:30 PKT. Plan with times: docs/claude/ADMIN-DESK-3DAY-PLAN-21NOV.md. The Desk is its OWN security domain (docs/claude/DESK-ISOLATION-GATE-21NOV.md). Rule 52: every browser call is signed and verified in the ONE Rust WASM kernel. SQL series for the Desk = AD1, AD2, ... (founder and awam keep the E series).
RULE (his word): in every phase, next to each FEATURE the CODE file and the ADVANCED TECHNOLOGY are written, and "HAAN" = yes only when the technology is really in that file AND seen working. The gate admin-desk/gates/DESK-FEATURES.json enforces this: missing technology = FAIL, NO COMMIT, shouted.

## PHASE R3a: Desk ka Ghar aur Darwaza (Sat 21 Nov 08:00 - 18:00)
### R3a0 HOST (admindesk.anexomail.com)
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Own process on loopback 4400 | admin-desk/server/src/main.rs | RUST, TOKIO, AXUM 0.8 | YES (his install 08:19: listener 127.0.0.1:4400) |
| Wrong Host = 404 + journal line | admin-desk/server/src/main.rs (host_gate) | AXUM MIDDLEWARE | YES (his install: wrong host 404) |
| Security headers | admin-desk/server/src/main.rs (desk_headers) | CSP SELF-ONLY + TRUSTED TYPES, COOP, CORP, HSTS | YES in code + sandbox; public look pending |
| Own installer + unit + user | admin-desk/scripts/desk-install.sh | SYSTEMD HARDENING (NoNewPrivileges, ProtectSystem, MemoryDenyWriteExecute) | YES (his install ran) |
| Own bundle | founder-web/vite.desk.config.ts, desk.html | VITE 8 SEPARATE ENTRY | YES (build ok) |
| HTTP/3 + AES-256-GCM X25519MLKEM768 for this host | planned: SNI front + UDP 443 route | HTTP/3, QUIC, TLS 1.3 AES-256-GCM, X25519MLKEM768 | NO (stage 2, gate date 23 Nov) |
| AAAA + HTTPS alpn=h3 DNS | his Namecheap hands | DNS | NO |
### R3a1 CINEMATIC LOGIN
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Night glass-walled office scene, gradient #060B19 / #0F3460 / amber rim | founder-web/src/desk/DeskScene.tsx (planned) | REACT 19, THREE.JS (LAZY) | NO |
| Mouse + phone-tilt parallax | DeskScene.tsx (planned) | POINTER EVENTS, DEVICEORIENTATION | NO |
| Smoked liquid-glass card, 1px luminous edge, Desk identity only | founder-web/src/desk/DeskSignIn.tsx | TAILWIND 4, CSS BACKDROP-FILTER | partly (skeleton) |
| Optional passkey button + honest hardware text | DeskSignIn.tsx (planned) | WEBAUTHN, KERNEL RPC (RULE 52) | NO |
| Orb pulse, shockwave, zoom into 3-pane workspace | DeskScene.tsx (planned) | THREE.JS, GSAP | NO |
| Real telemetry (handshake, kernel hash, Merkle) | founder-web/src/desk/DeskTelemetry.tsx (planned) | RUST WASM KERNEL VALUES | NO |
### R3a2 LOGIN DOOR
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Schema AD1: owner, sessions, ledger, desk_app | admin-desk/sql/AD1.sql (planned) | POSTGRESQL RLS, APPEND-ONLY SHA-256 HASH CHAIN | NO |
| /desk/v1/auth/login | admin-desk/server/src/auth.rs (planned) | ARGON2ID, CONSTANT-TIME, TOKEN AUDIENCE "desk" | NO |
| Device-bound session | auth.rs (planned) | DBSC | NO |
| Owner created by his command (password never in chat) | admin-desk/scripts (planned) | ARGON2ID | NO |

## PHASES AFTER R3a (each gets its own feature table when it starts; plan times in the 3-day plan)
R3b inboxes (Sun 06:00) / R3c auto mail RFC 3834 + Polar signed webhook (12:00) / R3d dashboard + mail UI (17:00) / R3e reply without passkey (Mon 06:00) / R3f SLA engine (09:00) / R3g verify + final (14:00-21:00) / R4 Managed Move-In + Priority Support (from Tue 24 Nov) / R5 LEO / R6.
