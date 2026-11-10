> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 24 — FINAL MAIL CONTRACT (status: READY)

## Live error ka exact matlab

`phase57` ne `spf_result` add kar diya tha, magar live `mail_ingest()` purana raha
aur `mailboxes.org_id` maangta raha. Doosra `/api/mail/deliver` generation
`cc_addrs` maang raha tha jabke canonical naam `cc_addresses` hai.

## Ek auto-sync command

```bash
cd /opt/anexomail-web && git pull && bash server/deploy-all.sh
```

Deploy ka database step ab tarteeb se `phase57` → `phase58` → `phase56` chalata
hai. `phase58` koi mail/table delete nahi karta: function replace, dono address
column generations sync aur Data API schema reload karta hai.

## Auth ka current blocker

Is checkout ka `server/index.ts` auth/mail routers import karta hai, magar unki
source files repo mein nahi hain. Is liye login, signup, forgot/reset/change
password ko DONE kehna mana hai jab tak woh backend source isi repo mein restore
ho kar build aur live browser test pass na kare.

## Sirf mail ko foran prove karna ho

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase58_mail_contract_final.sql
bash server/mail/deploy-mail.sh
postqueue -f
sleep 20
postqueue -p
bash server/gates/mail-gate.sh
```

DONE sirf jab queue empty aur mail gate PASS-only ho. PTR ka DNS fail alag manual
dot hai; woh database delivery ko rollback nahi karta, magar launch gate RED rakhta hai.