> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 22 — MAIL QUEUE FIX (spf_result) (status: READY)

## Asli wajah (server log se sabit, andaza nahi)

```text
anexomail-deliver: supabase 400 {"code":"42703",
 "message":"column \"spf_result\" of relation \"mail_messages\" does not exist"}
status=deferred
```

Server par PURANI `mail_messages` table pehle se mojood thi. Phase 52 mein
`create table if not exists` hai — is liye woh table waisi hi rahi aur naye
column (`spf_result`, `dkim_result` …) usmein kabhi nahi bane. Aap ki mail **gum
nahi hui**: Postfix ne har mail queue mein rok li (`status=deferred`), column
banne ke baad ek `postqueue -f` se sab andar chali jayegi.

## Fix (ek dafa, tarteeb se)

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase57_mail_schema_heal.sql     # missing column add (koi delete nahi)
bash sql/run.sh sql/phase56_mailbox_final.sql        # final address list
bash server/mail/deploy-mail.sh                      # mailbox/alias/password refresh
postqueue -f                                          # ruki hui saari mail andar
sleep 20
bash server/gates/mail-gate.sh
```

## Verify (asli sabooti)

```bash
bash sql/run.sh --query "select count(*) from public.mail_messages;"   # 0 se barhna chahiye
bash sql/run.sh --query "select mailbox_address, subject, last_message_at from public.mail_threads order by last_message_at desc limit 5;"
postqueue -p                                                           # "Mail queue is empty"
curl -s -o /dev/null -w '%{http_code}\n' https://anexomail.com/app/mail
```

Gate mein ab yeh dots hain: `mailboxes = 12` · `postmaster/abuse/dmarc sirf
forward` · `nauman/support/trials delete ho chuka` ·
`mail_messages.spf_result column maujood` · asli round-trip.

Status **DONE** sirf tab jab gate ka output PASS-only ho.
