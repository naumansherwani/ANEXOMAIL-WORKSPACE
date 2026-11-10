> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 01 — SAARI SQL EK COMMAND SE (copy-paste)

## Pehli dafa connection — sirf yeh ek line copy-paste karo

```bash
cd /opt/anexomail-web && git pull && bash sql/connect.sh
```

Terminal aap se database ka **connection URI** maangega. Database dashboard ke
**Connect → URI / Transaction pooler** se poori URI copy karke paste karein aur Enter
karein. Paste screen par nazar nahi aayega, shell history mein nahi jayega, repo mein
nahi jayega. Script pehle login test karegi; sirf GREEN par protected file mein save hoga.

## Apply — connection GREEN ke baad sirf yeh ek line copy-paste karo

```bash
cd /opt/anexomail-web && git checkout -- . && git pull && bash sql/apply-all.sh
```

`git checkout -- .` server par ki hui local tabdeeliyan hata deta hai (repo hi asal hai),
warna `git pull` "local changes would be overwritten" par rukta hai.

## Beech se dobara shuru (jo phase RED thi us se aage)

Jab koi phase aap ne SQL editor mein khud chala li ho, ya deadlock aaya ho:

```bash
cd /opt/anexomail-web && bash sql/apply-all.sh --from sql/phase35_payment_safety.sql
```

`--from` ke baad us file ka naam likho jahan se aage chalana hai; us se pehli sab `SKIP` ho jati hain.
Deadlock (do sessions ek hi table par) par runner khud 3 dafa retry karta hai.


Output aisa aata hai:

```
GREEN  sql/phase12a_mail_prediction.sql
GREEN  anexochat/sql/phase13_15_file_engine.sql
...
GREEN=59  RED=0
ALL SQL GREEN
```

Runner pehle database connection check karta hai. Connection fail ho to 59 jhoote RED
nahi deta; foran ruk kar asli error screen par dikhata hai. SQL error ho to pehli failing
phase aur us ka exact error screen par dikhata hai; baqi dependent phases run nahi hotin.
`connect.sh` ka login-verified URI hamesha purani app/mail environment files se pehle use hota hai.
Idempotent `NOTICE` (misal: table pehle se mojood hai) GREEN hota hai; sirf asli
database `ERROR`/`FATAL` ya non-zero exit phase ko RED karta hai.
Purani function/view signature (`cannot change return type of existing function`)
runner khud `HEAL   drop function ...` line ke saath hata kar phase dobara chalata
hai — aap ko koi manual `DROP` nahi likhna.
