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
