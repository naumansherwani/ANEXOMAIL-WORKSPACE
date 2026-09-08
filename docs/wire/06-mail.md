# WIRE 06 — MAIL (anexomail.com · 13 addresses) — copy-paste + sirf DNS aap ka

Is block mein **ek hi manual hissa** hai: registrar par DNS records. Baqi sab command.

## A · DNS (aap ke registrar par — sirf yeh 6 records)

| Type | Name | Value |
|---|---|---|
| A | `mail` | server ka public IP |
| MX | `@` | `mail.anexomail.com` (priority 10) |
| TXT | `@` | `v=spf1 mx -all` |
| TXT | `mail._domainkey` | DKIM public key (Step B ka output deta hai) |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:resolved@anexomail.com` |
| PTR | server IP (Hetzner panel) | `mail.anexomail.com` |

## B · mail stack deploy (Postfix + Dovecot + DKIM, passwords sirf server par)

```bash
cd /opt/anexomail-web && git pull && bash server/mail/deploy-mail.sh
```

Script DKIM key banati hai aur DNS ke liye exact TXT value print karti hai —
usay Step A ke `mail._domainkey` mein paste karo.

## C · addresses ka SQL (agar phase52 pehle nahi chali)

```bash
cd /opt/anexomail-web && bash sql/run.sh sql/phase52_mail_launch.sql
```

## D · gate (DNS + PTR + services + 13 addresses + asli round-trip)

```bash
cd /opt/anexomail-web && bash server/gates/mail-gate.sh
```

Gate khud ek mail bhejta hai aur dekhta hai ke woh `mail_messages` mein aayi ya nahi.
Aane par hi GREEN — warna FAIL saaf likha aayega.
