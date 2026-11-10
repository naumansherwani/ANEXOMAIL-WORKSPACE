> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# Expiry watch — koi cheez chupke se expire na ho (blueprint 8o, 17 Oct 2026)

**Kyun:** mail TLS cert 2 Nov ko expire hone wala tha aur kisi ko khabar nahi thi (ab theek, 8n). Wohi galti dobara kisi aur
cheez ke saath na ho — isliye ek hi monitor sab dekhta hai, din mein 2 baar (03:47 aur 15:47 server waqt, UTC).

| Item id | Kya dekhta hai | warn / crit |
|---|---|---|
| `mail-tls` | IMAPS 993 + SMTP 587 (STARTTLS) par **live** cert: din, chain + hostname verify; 993 aur 587 ke cert alag ho to bhi | <21 din / <7 din, ya cert invalid |
| `web:<host>` | Caddyfile ke har HTTPS host ka live cert (127.0.0.1:443, SNI) | <21 / <7 din, ya browser trust nahi karega |
| `domain:<d>` | Domain registration expiry (RDAP, registry ka apna jawab; 20 ghante cache; lookup fail par aakhri date 14 din tak) | <60 / <30 din, ya `redemption`/`pending delete` |
| `dkim:<d>` | OpenDKIM private key se public key == DNS TXT `selector._domainkey.domain` | DNS mein nahi / mismatch / revoked = crit |
| `mx` `spf` `dmarc` `ptr` | mail domain ka DNS (record hata to nahi diya?) aur reverse DNS | MX nahi / 2 SPF = crit; SPF/DMARC nahi / PTR galat = warn |

* `unknown` = check nahi ho paya (jaise DNS ne jawab nahi diya). Pehle chup rehta hai; **3 run lagataar unknown** rahe to khud
  alert banta hai — monitor ka apna andha-pan bhi chup nahi rehta.
* Alert: sirf email (founder inbox + `/etc/anexomail/alert.env` ka `ALERT_TO`), har level (crit/warn) din mein ek baar, aur theek hone
  par ek "sab theek ho gaya". Sab theek ho to khamosh.
* Output: `/var/lib/anexomail/expiry-watch.json` — Rust `founder.expiry.watch` yahi file parhta hai (founder dashboard par "Mail TLS: N din").
  File 36 ghante se purani ho to dashboard khud "monitor chal nahi raha" dikhata hai.
* Sirf Python3 stdlib + `openssl`; DNS ke liye khud ka chhota resolver (1.1.1.1, 8.8.8.8, phir `/etc/resolv.conf`); `dig` ki zaroorat nahi.

**Install (founder, ek command):**
```bash
git -C /opt/anexomail-web fetch -q origin main && bash <(git -C /opt/anexomail-web show origin/main:docs/cursor-work/server/expiry-watch/install.sh)
```
Idempotent. Haath se: `anexomail-expiry-watch --dry` (sirf dikhao), `systemctl start anexomail-expiry-watch.service`,
log: `journalctl -u anexomail-expiry-watch.service -n 40 --no-pager`. Settings (optional): `/etc/anexomail/expiry-watch.env`.

**Test (sandbox):** `python3 docs/cursor-work/server/expiry-watch/selftest.py` — nakli par asli protocol: local TLS servers
(IMAPS, SMTP STARTTLS, web SNI) alag alag din ke certs ke saath, local DNS (UDP + TCP fallback), local RDAP, nakli sendmail.
40+ checks: healthy / trouble / ek din mein ek hi mail / all-clear / unknown 3 run / RDAP cache / DKIM mismatch / key table gayab.
Asli server par pehli run (domain RDAP, DKIM key path, Caddyfile hosts) founder ke install output se dekhni baqi → tab tak READY.
