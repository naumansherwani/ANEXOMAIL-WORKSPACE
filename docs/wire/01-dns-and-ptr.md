# Step 1 — DNS chain + PTR

Chain jo banani hai:

```text
PTR / reverse DNS  →  mail.anexomail.com
MX anexomail.com   →  mail.anexomail.com
SPF                →  authorized sending server (yeh server)
DKIM               →  mail._domainkey (key step 3 mein banegi)
DMARC              →  policy + report mailbox
```

## 1A. DNS records (registrar / DNS provider par add karo)

`<IPV4>` aur `<IPV6>` step 0 ki table se.

| Type | Name              | Value                                                                       | TTL |
| ---- | ----------------- | --------------------------------------------------------------------------- | --- |
| A    | `mail`            | `<IPV4>`                                                                    | 300 |
| AAAA | `mail`            | `<IPV6>` (IPv6 na ho to yeh record add hi na karo)                          | 300 |
| MX   | `@`               | `10 mail.anexomail.com.`                                                    | 300 |
| TXT  | `@`               | `v=spf1 a:mail.anexomail.com -all`                                          | 300 |
| TXT  | `_dmarc`          | `v=DMARC1; p=quarantine; rua=mailto:dmarc@anexomail.com; ruf=mailto:dmarc@anexomail.com; fo=1; adkim=s; aspf=s` | 300 |
| TXT  | `mail._domainkey` | step 3 mein OpenDKIM se milegi (abhi khali chhoro)                          | 300 |

Website ke A/AAAA records (`@`, `www`, baqi hosts) ko **touch nahi karna** — woh Caddy par hain.

## 1B. PTR (reverse DNS)

Hetzner Cloud Console → apna server → **Networking** → IP ke aage `⋯` → **Edit reverse DNS**:

- IPv4 → `mail.anexomail.com`
- IPv6 → `mail.anexomail.com`

## 1C. Verify (yeh gate hai)

```bash
IP4=$(curl -4 -s https://ifconfig.co)
echo "--- A ---";     dig +short A    mail.anexomail.com
echo "--- MX ---";    dig +short MX   anexomail.com
echo "--- SPF ---";   dig +short TXT  anexomail.com
echo "--- DMARC ---"; dig +short TXT  _dmarc.anexomail.com
echo "--- PTR ---";   dig +short -x "$IP4"
```

Green ka matlab:

- A = tumhara IPv4
- MX = `10 mail.anexomail.com.`
- SPF line mein `v=spf1 a:mail.anexomail.com -all`
- DMARC line mein `v=DMARC1; p=quarantine;`
- PTR = `mail.anexomail.com.`

Kuch bhi mismatch = **rukna**. DNS propagate hone mein 5–30 min lag sakte hain; dobara chalao.
Iske baad `docs/wire/README.md` ki ledger table mein yeh 5 dots DONE likho.
