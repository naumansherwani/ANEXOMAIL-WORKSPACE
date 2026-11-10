> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# WIRE 06 — MAIL (anexomail.com · final address list) — copy-paste + sirf DNS aap ka

Is block mein **ek hi manual hissa** hai: registrar par DNS records. Baqi sab command.

## A · DNS (aap ke registrar par — sirf yeh 6 records)

| Type | Name | Value |
|---|---|---|
| A | `mail` | server ka public IP |
| MX | `@` | `mail.anexomail.com` (priority 10) |
| TXT | `@` | `v=spf1 mx -all` |
| TXT | `mail._domainkey` | DKIM public key — **Step B ka server output** (Namecheap khud nahi banata) |
| TXT | `_dmarc` | `v=DMARC1; p=reject; rua=mailto:dmarc@anexomail.com; adkim=s; aspf=s` |
| PTR | server IP (Hetzner panel) | `mail.anexomail.com` |

> **DMARC (final):** `p=reject; adkim=s; aspf=s` ko badalna nahi. Step D local
> DKIM key ko DNS se exact match aur SPF/DMARC alignment verify karta hai.
> `dmarc@anexomail.com` mailbox final address list mein pehle se maujood hai.

> **DKIM Namecheap par:** Namecheap DKIM khud generate nahi karta. Key hamare server
> par banti hai (Step B), aur script screen par exact TXT value print karti hai.
> Namecheap → Advanced DNS → Add New Record → TXT Record → Host `mail._domainkey`,
> Value = wahi print hui line (`v=DKIM1; k=rsa; p=...`), TTL **Automatic** theek hai.

## B · mail stack deploy (Postfix + Dovecot + DKIM, passwords sirf server par)

```bash
cd /opt/anexomail-web && git pull && bash server/mail/deploy-mail.sh
```

Script DKIM key banati hai aur DNS ke liye exact TXT value print karti hai —
usay Step A ke `mail._domainkey` mein paste karo. Inbound pipe ke database values
existing protected server env se `/etc/anexomail/mail.env` mein khud sync hoti hain;
server ke authoritative `SUPABASE4_URL` / `SUPABASE4_SERVICE_ROLE_KEY` naam aur purane
fallback naam dono supported hain. Values screen ya repo mein kabhi print nahi hotin.
Deploy ke aakhir mein purani queue khud retry hoti hai.


## C · addresses + ingest ka SQL (dono idempotent)

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase52_mail_launch.sql
cd /opt/anexomail-web && bash sql/run.sh sql/phase54_mail_ingest_org_fix.sql
```

`phase54` `mail_ingest()` ko `org_id`/`account_id` deta hai (mailbox ke
`mail_accounts` row se, warna ANEXOMAIL System org) — legacy NOT NULL `org_id`
ki wajah se hi queue mein `temporary failure` aata tha.

## D · gate (DNS + PTR + services + final address list + asli round-trip)

```bash
cd /opt/anexomail-web && bash server/gates/mail-gate.sh
```

Gate khud ek mail bhejta hai aur dekhta hai ke woh `mail_messages` mein aayi ya nahi.
Aane par hi GREEN — warna FAIL saaf likha aayega.
