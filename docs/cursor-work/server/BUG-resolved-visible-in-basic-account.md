> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# BUG — `resolved@anexomail.com` basic (test) account mein nazar aa raha hai

Status: **TODO** (11 Oct 2026, founder ne report kiya)

## Kya dikha
- Basic account (org `16e02f4b-cc52-438f-a2e7-bef4ef7f81cb`) ke sidebar Accounts mein `resolved@anexomail.com`.
- Basic account ke inbox mein Google DMARC report thread (`noreply-dmarc-support@google.com`, "Report domain: anexomail.com") — yeh system/support mail hai.

## Sahi behaviour (docs/wire/20-final-addresses.md)
- `resolved@anexomail.com` = platform ka support/system inbox (postmaster@, abuse@, dmarc@, support@ sab yahin forward).
- Yeh sirf **founder** ko dikhna chahiye, kisi awam / test org ko nahi.

## Shak (diagnose se confirm hona hai, guess pe fix nahi)
1. `mailboxes` ya `mail_accounts` mein `resolved@` ki row ka `org_id` basic org ka hai (galat org).
2. Ya basic user `org_members` ke zariye founder wali org mein bhi hai.
3. `server/routes/mail.ts` `ctx()` fallback: `mail_accounts` se `ilike(address, userEmail)` — org resolve galat ho sakta hai.

## Fix rule
- Data fix = naya E-series SQL (`docs/cursor-work/sql/E16_…sql`), pehle diagnose output ke baad.
- DONE tab jab basic account mein `resolved@` aur DMARC thread nazar na aaye, aur founder account mein aaye.
