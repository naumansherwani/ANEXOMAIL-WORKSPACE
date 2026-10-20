# Server ki live jaankari — 20 Oct 2026 09:09 PKT (founder ne bheji, "yeh save ker lo")

Koi password / key ka mawad nahi — sirf naam aur raaste.

## Rust engine (`anexomail-rust`, pid 3525113, 03:30 se chal raha)
| Socket | Kya |
|---|---|
| TCP *:3200 | `/rpc/*` primary (Caddy ke peeche) |
| UDP *:3443 (IPv6 dual-stack) | WebTransport / QUIC — `wt_session` (mail stamp, chat, call signal) |
| UDP *:3501 | (ufw mein khula) |
| TCP 127.0.0.1:3500, 127.0.0.1:3600 | sirf andar |

`/rpc/health`: `webtransport: "live"`, `wt_port: 3443`, fallback Bun 3300.
Env naam: `ANEXOCHAT_WT_CERT`, `ANEXOCHAT_WT_KEY` (Caddy ki Let's Encrypt files).

## WebTransport certificate
- `/etc/caddy/certificates/acme-v02.api.letsencrypt.org-directory/anexochat.anexomail.com/anexochat.anexomail.com.crt`
- subject/SAN: **sirf `anexochat.anexomail.com`** — issuer Let's Encrypt YE1 — 14 Aug 2026 se 12 Nov 2026 tak (Caddy khud renew karta hai; Rust ko renew ke baad restart chahiye taake nayi file uthaye).

## Caddy
`caddy validate` = **Valid configuration** (sirf "not formatted" warning — chhedna nahi).

## Firewall (ufw active)
Khule: 22, 80, 443/tcp, 443/udp, 25, 465, 587, 143, 993, 110, 995, 3478 tcp/udp, 5349 tcp/udp, 49152-65535/udp, 3501/udp, 9300/udp; 9100/tcp + 9200/udp sirf 88.198.208.90.
**`3443/udp` ufw list mein NAHI hai.**

## Is se nikle 2 asli masle (20 Oct)
1. **3443/udp firewall mein band** => bahar ka koi browser WebTransport se jud hi nahi sakta; health "live" kehta hai magar sirf server ke andar. Hal: `ufw allow 3443/udp` (founder command, neeche).
2. **Naam mismatch:** website mail ke liye `https://anexomail.com:3443` se judti thi, certificate sirf `anexochat.anexomail.com` ka => QUIC handshake fail, hamesha HTTP poll. Chat/call ke liye `VITE_ANEXOCHAT_WT_URL` build mein nahi tha => WT bilkul band. Hal (repo): `src/lib/wt-url.ts` — sab ek hi pata `https://anexochat.anexomail.com:3443`.
