> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 23 — LAUNCH TODAY: proof order (status: READY)

Har dot ka apna sabooti command hai. Jo command green na ho, woh dot DONE nahi.

## 1. Mail andar aani chahiye (yahi asli rukawat thi)

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase57_mail_schema_heal.sql
bash sql/run.sh sql/phase58_mail_contract_final.sql
bash sql/run.sh sql/phase56_mailbox_final.sql
bash server/mail/deploy-mail.sh
postqueue -f && sleep 20
bash sql/run.sh --query "select count(*) from public.mail_messages;"
postqueue -p
bash server/gates/mail-gate.sh
```

Sabooti: `mb.org_id`/`cc_addrs` error khatam + message count barha +
`Mail queue is empty` + gate PASS-only.

## 2. Website (awam ka har page)

```bash
bun install && bun run build:bun && pm2 restart anexomail-web --update-env && pm2 save
bash server/gates/web-gate.sh
```

## 3. Login + founder side

```bash
bash server/gates/rust-gate.sh        # /rpc/* engine
curl -s -o /dev/null -w '%{http_code}\n' https://anexomail.com/auth
for p in mail calendar chat crm people work storage analytics settings billing devices; do
  echo "$p $(curl -s -o /dev/null -w '%{http_code}' https://founderworkspace.anexomail.com/$p)"
done
```

## 4. ANEXOChat + call

```bash
bash server/gates/chat-gate.sh
bash server/gates/videocall-gate.sh
```

## 5. Paisa + storage + final

```bash
bash server/gates/payments-gate.sh
bash server/gates/storage-gate.sh
bash server/gates/all-gates.sh
```

## Yaad rahe

- `/app/*` ka har page **login ke peeche** hai. Bina session woh `/auth` par
  bhejta hai — yeh khali page nahi, yeh gate hai. Login ke baad andar asli
  panels hain jo asli API se data lete hain (koi dummy data nahi).
- Jo cheez server par sabit nahi hui, yahan READY likhi hai — DONE sirf green
  output ke baad.
