> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 20 — FINAL ADDRESS LIST + FAMILY ACCOUNTS (status: READY)

Founder ka faisla (locked 8 Sep 2026) — is list se bahar koi address nahi banti.

## Real mailbox (login wale)

| Address | Kis ke liye |
| --- | --- |
| `hello@anexomail.com` | First contact / sales |
| `moveyourbusiness@anexomail.com` | Move-in + Priority Support |
| `resolved@anexomail.com` | Support ka asli inbox (purana support/trials/abuse sab yahin) |
| `billing@anexomail.com` | Invoices, plan |
| `leo@anexomail.com` | LEO reply pipeline |
| `naumansherwani.founder@anexomail.com` | Founder ka **ek hi** inbox |
| `humzasherwani@anexomail.com` | Brother — aam user, AI Executive premium |
| `raanasherwani@anexomail.com` | Mother — aam user, AI Executive premium |

`noreply@anexomail.com` = send-only (inbound discard).

## Sirf forward (koi inbox, koi password nahi)

`postmaster@` · `abuse@` · `dmarc@` → seedha `resolved@`.
Yeh teen RFC/DMARC ke liye lazmi hain — mail server inhein na maane to bounce
reports aur DMARC rua (`rua=mailto:dmarc@anexomail.com`) khatam ho jate hain.

## Delete (backup ke baad root se)

`nauman@` · `support@` · `trials@` — maildir copy
`/var/backups/anexomail/maildirs-<timestamp>/` mein, phir `rm -rf`.
Database backup table: `public.mailboxes_backup_<timestamp>`.

## Family accounts ka rule

- Aam user ki tarah — awam ke saray rules unpar lagoo hain.
- Plan `business_pro` + AI `ai_executive` (10,000 credits) — poore premium features.
- Founder inbox mein unki mail **kabhi copy nahi** hoti; founder data access
  `family_no_founder_data` CHECK se band.
- Password founder ke password se alag: `FAMILY_HUMZASHERWANI_PASSWORD` /
  `FAMILY_RAANASHERWANI_PASSWORD` in `/etc/anexomail/mail.env` (repo mein kabhi nahi).

## Steps

```bash
cd /opt/anexomail-web && git pull
bash sql/run.sh sql/phase56_mailbox_final.sql
bash server/mail/deploy-mail.sh
bash server/gates/mail-gate.sh
```

Password dekhna (sirf server par):

```bash
sudo grep -E '^(FOUNDER_MAIL_PASSWORD|FAMILY_.*_PASSWORD)=' /etc/anexomail/mail.env
```

Verify:

```bash
sudo cut -d: -f1 /etc/dovecot/users                                   # 9 addresses
sudo postmap -q abuse@anexomail.com hash:/etc/postfix/valias          # resolved@…
sudo postmap -q nauman@anexomail.com hash:/etc/postfix/valias         # khali
sudo postmap -q humzasherwani@anexomail.com hash:/etc/postfix/vmailbox
ls /var/backups/anexomail/
```

Status **DONE** sirf tab jab gate green ho.

IMAP/SMTP: server `mail.anexomail.com`, IMAP 993 (SSL), SMTP 465 (SSL).
