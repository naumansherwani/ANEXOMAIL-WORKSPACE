# !!! HIS LAW, 21 NOV 2026 23:35 PKT (IN ANGER), WRITE IT LOUD: !!!
# !!! THE FRONTEND IS HANDLED BY CADDY (HIS "CADDYSERVER"). HETZNER HANDLES ONLY THE BACKEND. !!!
# !!! DNS RECORDS FOR A WEBSITE NAME (A / AAAA) POINT TO THE CADDY SERVER'S IP, NEVER BLINDLY TO A BACKEND IP. !!!
His words: "yeh yahan caddyserver ka IP aayega; mera frontend repo mein cheekh cheekh ke likho; mera frontend caddyserver sambhalta hai, Hetzner sirf backend sambhalta hai."
Facts in the repo, for checking against this law (no guess):
- ADMIN-DESK-R3A0-FACTS-21NOV.md (his paste 21 Nov): "dig +short admindesk.anexomail.com = 62.238.98.98 = THIS server"; he edited /etc/caddy/Caddyfile and reloaded Caddy on that same machine (root@mail); Caddy there listens TCP 18443 / UDP 18443 behind the TCP 443 front.
- His desk-restart paste 21 Nov 23:30 on root@mail: server IPv6 2a01:4f9:c014:5df6::1; anexomail.com + admindesk A = 62.238.98.98.
- So the Caddy that answers anexomail.com and admindesk today runs on the machine whose IPv4 is 62.238.98.98 and IPv6 is 2a01:4f9:c014:5df6::1. If his Caddy server is a DIFFERENT machine, the AAAA value must be THAT machine's IPv6: he gives it, Claude never guesses.

- 21 Nov 2026 23:39 PKT HIS FACT: 62.238.98.98 = the Caddy server IP. Its IPv6 (same machine, his desk-restart paste 23:30) = 2a01:4f9:c014:5df6::1 -> AAAA value.
