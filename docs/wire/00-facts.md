# Step 0 — Asli values (koi andaaza nahi)

Yeh table bharna lazmi hai. Jab tak khali hai, aage ka koi step start nahi karna.
Server par yeh commands chalao aur output isi file mein likh do (commit karna theek hai —
inme koi secret nahi).

```bash
# public IPv4 + IPv6
curl -4 -s https://ifconfig.co; echo
curl -6 -s https://ifconfig.co; echo

# current hostname
hostname -f

# current PTR (reverse DNS) — dono IP par
dig +short -x "$(curl -4 -s https://ifconfig.co)"
dig +short -x "$(curl -6 -s https://ifconfig.co)" 2>/dev/null

# port 25 outbound khula hai ya nahi (Hetzner naye accounts par band hota hai)
timeout 5 bash -c 'cat < /dev/null > /dev/tcp/gmail-smtp-in.l.google.com/25' && echo "PORT25 OPEN" || echo "PORT25 BLOCKED"
```

| Fact                    | Value (bharo)              |
| ----------------------- | -------------------------- |
| Public IPv4             |                            |
| Public IPv6             |                            |
| `hostname -f`           |                            |
| PTR (IPv4) abhi         |                            |
| PTR (IPv6) abhi         |                            |
| Outbound port 25        | OPEN / BLOCKED             |
| DNS provider / registrar|                            |

## Do zaroori baat

1. **PTR** app ya Caddy se set nahi hoti — sirf **Hetzner Cloud Console → Server → Networking →
   Reverse DNS** se hoti hai. Wahan IPv4 aur IPv6 dono ke liye `mail.anexomail.com` likho.
2. **PORT25 BLOCKED** aaya to Hetzner support par ek unblock request lagegi
   (Robot/Cloud Console → Support → "please unblock outgoing port 25 for mail server").
   Unblock ke baghair outbound mail kabhi nahi jayegi — is dot ko chhoruna mana hai.

Hostname permanently set karna:

```bash
hostnamectl set-hostname mail.anexomail.com
grep -q 'mail.anexomail.com' /etc/hosts || echo "127.0.1.1 mail.anexomail.com mail" >> /etc/hosts
hostname -f
```
