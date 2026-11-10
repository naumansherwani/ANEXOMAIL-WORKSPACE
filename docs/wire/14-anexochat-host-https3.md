> **FOUNDER TECHNOLOGY LAW (CAPITALS, HIS WORD 11 NOV 2026 03:21): BUILT INTO YOUR BROWSER: A RUST WEBASSEMBLY KERNEL, ONE KERNEL FOR THE WHOLE SITE. BACKEND ENGINE: RUST, TOKIO ASYNC RUNTIME, AXUM. ADVANCE NETWORK LAYER: LIVE WEBTRANSPORT OVER UDP, QUIC NATIVE PIPELINE, HTTP/3 (PRIMARY; H2/H1.1 ONLY FALLBACK), MEDIA OVER QUIC (MOQ, IETF STANDARDS TRACK) WITH SEAMLESS CROSS-PROTOCOL HTTP FALLBACK. WEBSITE: REACT 19, TYPESCRIPT, TANSTACK START & ROUTER, VITE 8, TAILWIND CSS 4, RADIX / SHADCN, FRAMER MOTION, GSAP, THREE.JS WITH 3D CINEMATIC FRONTEND. DATA & FILES: POSTGRESQL WITH ROW-LEVEL SECURITY, HETZNER STORAGE BOX FOR ATTACHMENTS, CLAMAV VIRUS SCANNING. POST-QUANTUM ON TOP: X25519MLKEM768 (ML-KEM-768) HYBRID KEY EXCHANGE ON EVERY TLS/QUIC LISTENER, AES-256-GCM ONLY, THEN POST-QUANTUM SIGNATURES (ML-DSA HYBRID WITH ED25519) AND OPENPGP PQC (RFC 9980) WHERE LISTED. NEVER BUILD OLDER TECHNOLOGY THAN THIS; A LISTED ITEM MISSING FROM THE CODE = OPEN GAP, NEVER GREEN. AUDIT: docs/claude/FOUNDER-TECH-AUDIT-11NOV.md.** <!--TECHLAW-->

# 14 — ANEXOChat host HTTPS + HTTP/3 (server terminal) + Phase 01 SQL heal

Do alag jagah ka kaam. Confusion na ho is liye saaf likha hai.

## A · SERVER TERMINAL (SSH par, `root@mail:/opt/anexomail-web#`)

Ek command, tarteeb se:

```bash
cd /opt/anexomail-web && git checkout -- . && git pull && bash server/caddy/deploy-sites.sh
```

Kya badla:
- `anexochat.anexomail.com` ka apna repo-managed block ban gaya
  (`/rpc/*` `/file/*` `/wt/*` → Rust :3200 · `/api/chat/*` → Bun :3300 fallback ·
  baqi → SSR :3000 · `request_body 32MB`).
- Agar wahi host main Caddyfile mein bhi purana pada tha to `caddy validate`
  "duplicate site address" par mar raha tha aur poora reload fail — host 000.
  Ab `strip-dup-hosts.py` woh duplicate block khud hataata hai (backup ke saath).
- Script ab DNS ka asli reading bhi print karti hai.

Verify (sirf 200 approved):

```bash
cd /opt/anexomail-web && bash server/gates/rust-gate.sh
```

```bash
curl -sI --http3 https://anexochat.anexomail.com/rpc/health | head -3
curl -s https://anexochat.anexomail.com/rpc/health
```

HTTP/3 sab hosts par global options se on hai (`protocols h1 h2 h3`).
Agar `--http3` line na de to yeh chalao:

```bash
grep -n -A4 'servers {' /etc/caddy/Caddyfile
```

`/file/*` par token ke bina `401` sahi hai — woh authenticated arm hai, fail nahi.
Sirf `/rpc/health` aur `/file/ping` ka `200` gate ka sach hai.

## B · SQL EDITOR (Supabase, browser — server par NAHI)

`anexochat_phase01_foundation.sql` ka `column "file_id" does not exist` is liye
tha ke database mein `chat_file_chunks` purani shape (kisi purane replace-cycle ki)
mein pehle se maujood thi, `create table if not exists` use chhor deta tha, aur RLS
policy naye column par lagti thi.

Ab file khud heal karti hai: jis purani table mein is phase ka lazmi column nahi,
usko `<table>_legacy` (indexes samet) rename karke fresh banati hai — purana data
delete nahi hota, `_legacy` mein zinda rehta hai.

Editor mein dobara chalao:

1. GitHub par `sql/editor/anexochat_phase01_foundation.sql` kholo
2. poora content copy → Supabase SQL Editor → Run

Phir tarteeb se `docs/wire/13-chat-video-sql.md` ki baqi files.

Purani legacy tables ka sach dekhne ka command (editor mein):

```sql
select table_name
from information_schema.tables
where table_schema = 'public' and table_name like '%\_legacy'
order by 1;
```

Jo naam yahan aayega, woh purana data hai — awam ko dena ho to hum us se naye
table mein migrate karenge (delete kuch nahi hua).
