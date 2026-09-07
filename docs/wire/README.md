# ANEXOMAIL — WIRE BOOK (poora project, dot by dot)

Yeh folder sirf **wiring** ke liye hai: har dot ka copy-paste step, koi feature talk nahi.
Rule: **jo dot green nahi, woh launch nahi.** Har step ke aakhir mein ek verify command hai —
uska output green aane tak next step start nahi karna.

Koi file delete nahi hogi. Repo ke saare 59 SQL files **step 09** mein hain — apply order,
per-file verify query, aur ek MASTER VERIFY jo 538 expected tables/functions ek saath check
karta hai. Uske baad frontend+Caddy, founder side, ANEXOChat, VideoCall ki wire books aayengi.

Server: Hetzner Server 2 (ANEXOMAIL dedicated). Mail stack: **Postfix + Dovecot + OpenDKIM +
OpenDMARC**, sab mere control mein. Koi external SMTP provider nahi, app ke andar koi SMTP
username/password nahi. Passwords sirf server par `/etc/anexomail/mail.env` (chmod 600) mein —
repo mein kabhi nahi.

## Steps (isi tarteeb mein)

| #   | File                                              | Kya hota hai                                                    | Gate                                     |
| --- | ------------------------------------------------- | --------------------------------------------------------------- | ---------------------------------------- |
| 0   | [00-facts.md](./00-facts.md)                      | Server IP, hostname, PTR, DNS provider — asli values likhna     | Table bhara hua ho                       |
| 1   | [01-dns-and-ptr.md](./01-dns-and-ptr.md)          | A · MX · SPF · DKIM · DMARC · PTR                               | `dig` + PTR check green                  |
| 2   | [02-postfix-dovecot.md](./02-postfix-dovecot.md)  | Postfix (25/587/465) + Dovecot (IMAP), virtual mailboxes        | `openssl s_client` login OK              |
| 3   | [03-dkim-dmarc.md](./03-dkim-dmarc.md)            | OpenDKIM key + OpenDMARC, signing chalu                         | `Authentication-Results: dkim=pass`      |
| 4   | [04-supabase-tables.md](./04-supabase-tables.md)  | `sql/phase52_mail_launch.sql` chalana (mail truth tables)       | Tables + 10 mailbox rows                 |
| 5   | [05-inbound-pipe.md](./05-inbound-pipe.md)        | Postfix pipe → `server/mail/deliver-to-supabase.ts` → Supabase  | Test mail `mail_messages` mein dikhe     |
| 6   | [06-outbound.md](./06-outbound.md)                | App → local Postfix `127.0.0.1:25` → Internet (no creds in app) | `/api/mail/send` se asli mail pohnche    |
| 7   | [07-inbox-wire.md](./07-inbox-wire.md)            | `/app/mail` inbox asli rows par (mock hataana)                  | Browser mein test mail dikhe             |
| 8   | [08-verify-gate.md](./08-verify-gate.md)          | Mail launch gate — 18 checks                                    | 18/18 green, warna launch nahi           |
| 9   | [09-sql-apply.md](./09-sql-apply.md)              | Repo ke **saare 59 SQL files** apply + per-file verify          | MASTER VERIFY zero missing row            |
| 10  | [10-branding-founder.md](./10-branding-founder.md) | Repo + site par sirf founder ka naam, koi platform credit nahi | repo `rg` zero output + site grep `0`     |

## Wire ledger (sach, koi "locked" nahi)

Status sirf teen: **DONE** (live test hua) · **READY** (code/config repo mein, server par nahi) ·
**TODO** (kuch nahi bana). Founder step complete karke yahan haath se DONE likhta hai.

| Dot                          | Status | Proof                              |
| ---------------------------- | ------ | ---------------------------------- |
| Server IP + hostname         | TODO   | `hostname -f`                      |
| PTR = mail.anexomail.com     | TODO   | Hetzner console + `dig -x`         |
| A mail.anexomail.com         | TODO   | `dig +short A mail.anexomail.com`  |
| MX anexomail.com             | TODO   | `dig +short MX anexomail.com`      |
| SPF                          | TODO   | `dig +short TXT anexomail.com`     |
| DKIM (`mail._domainkey`)     | TODO   | `dig +short TXT mail._domainkey…`  |
| DMARC                        | TODO   | `dig +short TXT _dmarc…`           |
| Postfix inbound 25           | TODO   | `ss -lntp \| grep :25`             |
| Postfix submission 587       | TODO   | `ss -lntp \| grep :587`            |
| Dovecot IMAPS 993            | TODO   | `ss -lntp \| grep :993`            |
| 10 real mailboxes            | TODO   | `doveadm user '*'`                 |
| Supabase mail tables         | READY  | `sql/phase52_mail_launch.sql`      |
| Inbound pipe → Supabase      | READY  | `server/mail/deliver-to-supabase.ts` |
| Outbound via local Postfix   | READY  | `server/mail/sendmail.ts`          |
| `/api/mail/send` real send   | TODO   | curl test                          |
| Inbox UI on real rows        | TODO   | browser                            |
| noreply inbound discard      | TODO   | mail to noreply@ → /dev/null       |
| DMARC report mailbox         | TODO   | `dmarc@` mein report aaye          |
| 59 SQL files applied         | READY  | step 09 MASTER VERIFY zero row     |
| Public tables ke GRANTs      | TODO   | step 09 GRANT check zero row       |
| Public tables par RLS        | TODO   | step 09 RLS check zero row         |

## Mailbox list (anexomail.com only — is launch ka scope)

| Address                                | Type       | Kahan use hota hai                                                        |
| -------------------------------------- | ---------- | ------------------------------------------------------------------------- |
| `hello@anexomail.com`                  | mailbox    | footer, get-started, AI page, checkout-done, trial-ended, AI top-up       |
| `moveyourbusiness@anexomail.com`       | mailbox    | landing hero CTA, migration, enterprise, plans, LeadForm                  |
| `support@anexomail.com`                | mailbox    | `/status`, `/docs`                                                        |
| `billing@anexomail.com`                | mailbox    | `/docs`                                                                   |
| `noreply@anexomail.com`                | send-only  | outbound system mail (glitch alerts) — inbound discard                    |
| `resolved@anexomail.com`               | mailbox    | silent BCC log of resolved support replies                                |
| `trials@anexomail.com`                 | mailbox    | trial start/expiry reply-to                                               |
| `abuse@anexomail.com`                  | mailbox    | RFC required                                                              |
| `postmaster@anexomail.com`             | alias      | → `abuse@`                                                                |
| `dmarc@anexomail.com`                  | mailbox    | DMARC rua/ruf reports                                                     |
| `naumansherwani.founder@anexomail.com` | mailbox    | Founder primary (`/app/founder`)                                          |
| `nauman@anexomail.com`                 | alias      | → founder primary                                                         |
| `leo@anexomail.com`                    | mailbox    | LEO auto-reply pipeline (`/app/founder`)                                  |

nexatect.com is launch mein **nahi** hai — woh alag phase.
