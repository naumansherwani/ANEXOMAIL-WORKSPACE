- [ ] Implement actual Rust SFU media forwarding binary for Phase 31A
- [ ] Add AV1→VP9→H.264→VP8 codec ladder and 3-layer simulcast
- [ ] Add Opus DTX/FEC SDP settings
- [ ] Add truthful P2P/TURN relay badge UI
- [ ] Add Phase 31A features to Business, Business Pro, AI Pro, AI Business, AI Executive package cards
- [ ] Verify Phase 31A and re-check roadmap
- [ ] Phase 31B translation layer: wrap public site pages (landing, plans, security, ownership, move-in, anexochat, auth, footer) with t()
- [ ] Phase 31B: wrap /app/* workspace panels with t()
- [ ] Phase 31B: run server/i18n/translate.py on Hetzner for all 29 locales, review RTL output

## WIRE BOOK (mail launch — anexomail.com)
- [x] docs/wire/00-facts.md — server IP, hostname, PTR, port-25 check
- [x] docs/wire/01-dns-and-ptr.md — A · MX · SPF · DMARC · PTR + verify
- [x] docs/wire/02-postfix-dovecot.md — full configs, 10 mailboxes, TLS from Caddy
- [x] docs/wire/03-dkim-dmarc.md — OpenDKIM key + OpenDMARC
- [x] sql/phase52_mail_launch.sql — mail truth tables + mail_ingest/mail_outbox_record RPC
- [x] server/mail/deliver-to-supabase.ts — Postfix pipe (tempfail 75, no mail loss)
- [x] server/mail/sendmail.ts — outbound via local Postfix, proof in mail_outbox_log
- [x] docs/wire/04..08 — Supabase tables, inbound pipe, outbound, inbox UI, 18+4 launch gate
- [ ] SERVER: steps 0-8 run + gate GREEN (founder side; ledger DONE karna hai)
- [ ] /opt/anexomail/src/routes/mail.ts ka full overwrite (send + threads on Phase 52 tables) — `cat` output ka intezar
- [ ] NEXT wire book: frontend + Caddy deploy (step 10+)
- [ ] NEXT wire book: founder side surfaces
- [ ] NEXT wire book: ANEXOChat dot-by-dot
- [ ] NEXT wire book: ANEXOVideoCall dot-by-dot

## SQL WIRE (no delete — har SQL file server par apply + verify)
- [ ] docs/wire/09-sql-apply.md — sab 61 SQL files dependency order mein, per-file apply + verify query
- [ ] Har phase SQL ka green proof ledger docs/wire/README.md mein

## BRANDING WIRE (sirf founder ka naam)
- [x] docs/wire/10-branding-founder.md — repo cleanup + verify commands
- [ ] Site par platform badge OFF + step 10.3/10.4 green
