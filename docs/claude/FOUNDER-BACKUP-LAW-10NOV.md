> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->


# BACKUP LAW — by order of the Chairman / Founder, Nauman Sherwani (10 Nov 2026 02:06 PKT, STANDING RULE)

1. **Founder-side code and awam-side code are backed up SEPARATELY.** Each backup is its own archive built from its lane lists (`lanes/founder.txt` / `lanes/awam.txt` + shared + docs + the frozen `lovable-*` lane), named `anexomail-<founder|awam>-backup-<date>-<time>-<commit>.tar.gz`, with a SHA-256 file, and sent to him.
2. **A backup is taken (a) when he orders it, (b) before any risky step (K-phase cut-over, SQL that rewrites data, a UI rebuild), (c) at the end of every phase that turns GREEN.** The commit hash is written here and in the chat-context checkpoint.
3. **Restore point = the git commit on `origin/main`** (the proxy refuses tag pushes with HTTP 403, so tags stay local only): `git checkout <commit> -- <lane paths>`. Never restore over newer work without his word.
4. **No awam file and nothing under `lovable-gold/` is ever edited** by a founder step (LOGIN UI LAW). A backup is read-only and changes no code.
5. Founder and awam are never mixed in one backup archive name or one restore step.

## Backup #1 — 10 Nov 2026 02:06 PKT
- Commit **1b94ed4f** (founder login = awam login code in the founder lane, /founderlogin).
- Founder archive: 691 files, SHA-256 `4d42267510bcf9d97540a82b01cb5e79f87e33615d5e14b2ae99fc65d371f3be`.
- Awam archive: 1722 files, SHA-256 `2c57f013a89c22eb5c0a95a5d96ff32860e7d5477b5295198e5e81b69414dcaf`.
- Delivered to the Chairman in chat as two files.

## Backup #2 — 10 Nov 2026 02:53 PKT (after the login rebuild + incident fix; the founder saw the site healthy 3 times)
- Commit **3450d945**. Founder archive 694 files, SHA-256 `bbff9ff2d8adec6416e33e17fdde68ea4293a96f7262881f1c65784931b37d49`. Awam archive 1724 files, SHA-256 `87e92022d07f724087bb18d5a02edd38fe5d71a337c30524db7f3ae1c046937d`. Sent to him as two files. Restore point = this commit.
