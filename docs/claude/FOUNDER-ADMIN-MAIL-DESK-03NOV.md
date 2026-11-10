> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Admin > Mail Desk: a separate advanced mailbox for the awam problems (founder order 3 Nov 12:37 PKT) — PLAN, nothing built
Letter **R3** (inside R = Systems / Admin). Not the founder's own Mail (that is letter Q).

## What he said (verbatim in founder-commands.md, 3 Nov 12:37)
Awam problems are heard and solved in **Admin**. Inside Admin there is a **whole advanced mailbox system of the world's latest technology, in its own separate folder**. Sidebar path: **Admin** -> (below it, in the sidebar) **Mail Desk** -> click -> the **Mail** section -> click -> the mailbox, either like the awam one (same code logic) or an even more advanced mailbox. **It is different from the founder's own mailbox in EVERY respect.**

## Separation rules (written so nothing mixes)
| Thing | Founder Mail (Q) | Admin > Mail Desk (R3) |
|---|---|---|
| Whose mail | the founder's own mailbox | company mailboxes: support, billing, abuse, glitch/inbox, appeals (the awam promises, `docs/cursor-work/PROMISES.md`) |
| UI folder | `founder-web/src/mail/` (planned) | `founder-web/src/admin/maildesk/` (planned, own folder, own routes `#/admin/mail-desk/...`) |
| Rust routes | `/founder/v1/mail/*` | `/founder/v1/admin/maildesk/*` |
| SQL | its own tables | own tables with prefix `fadm_mail_*`, own hash-chained ledger |
| Gates | personal | Admin gates (G1/G2/G3 tiers; passkey for sends on behalf of the company) |
| Code shared | only the common cores (`attach_core.rs`, kernel `sha256@1`, PQM) | the same common cores, never the other's pages or tables |
Sidebar: the Admin entry gets a child **Mail Desk**; Mail Desk opens the **Mail** section. The founder's personal Mail stays a separate top-level item.

## What goes inside (candidates; final list decided in the R design note with the 2026 technology chart, then his word)
- Unified inbox of the company mailboxes, 24 h SLA clocks per issue, assign / escalate / resolve, one-click replies from the awam problem context (blueprint D1-D4).
- Deliverability (SPF/DKIM/DMARC/MTA-STS/TLS-RPT checks), held mail, outbox with undo.
- Advanced mail technology on top: PQM post-quantum content (Q4), shared attachments (Q2) and parallel chunks over WebTransport (Q3 after K6), signed sent-log verified in the browser by the WASM kernel, JMAP-style (RFC 8621) clean API between Rust and the UI as a candidate.
- Real data only. No AI here (AI is founder-only letter V).

## Order
Letter order is never broken: R comes after Q. Nothing here starts before then.
