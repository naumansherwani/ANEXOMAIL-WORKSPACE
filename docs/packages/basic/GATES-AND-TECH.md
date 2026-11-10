> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# BASIC — gates aur technology (26 Oct 2026)
| Feature | Haalat | Gate kahan | Technology |
|---|---|---|---|
| 5 users cap | REAL | SQL `team_seat_calc` (E87) | Postgres |
| 3 mailboxes | REAL | `storage_plans.mailbox_limit`, Rust `mail_glue.rs` | Postgres + Rust |
| 15GB shared | REAL | `storage_plans.pooled_bytes` (E87) | Postgres |
| 25MB attachment | REAL | `storage_plans.max_send_bytes` (E87) | Rust `attach_core.rs` |
| 1 company domain | REAL | `org_domain_cap` (E15) | Postgres |
| 1 booking link | REAL (accident: `unique(user_id)`); E88 isse EXPLICIT cap bana deta hai | E88 trigger | Postgres + Rust `book_glue.rs` |
| 2 trusted devices | E88 se REAL (pehle server par cap NAHI tha) | `device_trust_set` (E88) | Postgres + Rust `device_glue.rs` |
| Response debt only | E88 se REAL (analytics ka plan gate nahi tha) | `showAnalytics*` in plan-surface | TS + route guard |
| Billing card (price/users/storage) | REAL | `get_billing_subscription` (E87) | Postgres |
