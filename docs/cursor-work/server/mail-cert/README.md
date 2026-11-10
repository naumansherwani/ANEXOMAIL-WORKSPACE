> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Mail TLS cert — khud taza + founder ko alert (17 Oct 2026)

**Masla:** `/etc/anexomail/mail-cert.pem` (IMAP 993/143, SMTP 587/465) Caddy ke Let's Encrypt cert ki ek BAAR ki copy thi
(`server/mail/deploy-mail.sh`, 18 Sep). Caddy apna cert har ~60 din khud renew karta hai, copy koi refresh nahi karta tha:
`notAfter = 2 Nov 2026`.

**Fix (hamesha ke liye):** `anexomail-mail-cert-sync.sh` + systemd timer (din mein 2 baar, 03:17 aur 15:17 server waqt).
1. Caddy ke store mein `mail.anexomail.com` ka sab se door expiry wala valid cert (cert aur key ka public key milta ho).
2. Installed se naya ho to atomic lagao (purana `/var/lib/anexomail/cert-backup/<ts>/`), `postfix reload` + `doveadm reload`.
3. LIVE verify: 993 (IMAPS) aur 587 (SMTP STARTTLS) wahi cert de rahe hain. Nahi to Dovecot restart; phir bhi nahi to purana wapas + alert.
4. Alert email (founder inbox `naumansherwani.founder@anexomail.com` + `/etc/anexomail/alert.env` ka `ALERT_TO`): 21 din se kam bache ho (`warn`), 7 din se kam (`urgent`), ya monitor ko masla mile (`problem`) — same level din mein ek baar. Cert khud taza ho to ek "renewed" email. Sab theek ho to khamosh.
5. `/var/lib/anexomail/cert-status.json` (`days_left`, `ok`, `problem`) — app/monitoring ke liye.

**Install (founder, ek command):**
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/mail-cert/install.sh)
```
Idempotent; dobara chalane se kuch nahi bigarta. Haath se sync: `systemctl start anexomail-mail-cert.service`; log: `journalctl -u anexomail-mail-cert.service -n 40 --no-pager`.

**Test (sandbox, 17 Oct):** simulation (openssl s_server ko Dovecot ki jagah) — naya cert lag gaya + live verify; galat key reject; reload fail par purana wapas; din mein ek hi alert; test alert. Asli server par Postfix/Dovecot reload ka asar abhi founder ke install output se dekhna baqi (Rule 5: isliye READY).
