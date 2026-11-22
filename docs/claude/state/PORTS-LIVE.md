# LIVE PORTS OF HIS SERVER — READ BEFORE ANY LISTENER / PORT / CADDY WORK (PORT RED LINE)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
Full law + older history: docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. QC1e D4A (company emoji) adds NO port: its procs live inside the existing /rpc/* on TCP 3200.

## HIS FRESH `ss -ulnp | head -60` PASTE 22 Nov 2026 21:20 PKT (real clock 20:59 PKT): UDP listeners = turnserver 3478/5349; anexomail-rust 3501 + 3443; founder-dns 53 (62.238.98.98 + IPv6); axon_core 9200/9300; caddy 18443; anexomail-desk *:4400 (pid 536885); anexomail-found *:443; chronyd 323; systemd-resolve 53. NOT in the list: UDP 4410. D5a-3b Control Plane responder = UDP 127.0.0.1:4410 (loopback only, never public), RESERVED by this step.

## AWAM Rust engine = process `anexomail-rust` (pid 3145875 at 20 Nov 03:30)
| Proto | Address:Port | Meaning |
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## RESERVED BY HIS WORD 21 Nov 2026 07:5x PKT: TCP 127.0.0.1:4400 = ADMIN DESK (own Rust process `anexomail-desk`, loopback only; Caddy has the admindesk block since 21 Nov 07:51 PKT: reverse_proxy 127.0.0.1:4400, validated + reloaded; nothing listens on 4400 yet). His free-port check showed 4400, 4500, 7400, 8400 free. Never use 4400 for anything else.

## ADMIN DESK HTTP/3 (his fresh ss 21 Nov 2026 09:27 PKT, full `ss -ulnp` + ufw udp pasted): UDP 4400 was FREE (no listener, no ufw rule, outside the TURN 49152-65535 range) -> RESERVED for the Desk's own HTTP/3 (`anexomail-desk`, drop-in env DESK_H3_ADDR=[::]:4400, ufw rule by admin-desk/scripts/desk-h3-enable.sh). Seen in that paste: udp 3478/5349 turnserver, 3501+3443 anexomail-rust, 9200/9300 axon_core, 18443 caddy, 443 anexomail-found (founder), 53 founder-dns/systemd-resolve, 323 chronyd, 68 systemd-network. ufw udp rules: 3478, 5349, 49152:65535, 9200 (88.198.208.90), 49152:49500, 9300, 443, 3501, 3443, 18443, 53 (founder-dns).

## ANEXOCHAT UDP = PROVEN by his paste 21 Nov 2026 09:33 PKT: chat + call WebTransport = UDP *:3443 (anexomail-rust pid 3902845); internal UDP 3501 (anexomail-rust); TURN for calls = turnserver UDP 3478 (listening-port) + UDP 5349 (tls-listening-port), relay range min-port 49152 .. max-port 49500 (ufw has 49152:49500 and also 49152:65535). ANEXOCHAT_WT_PORT is not set in /etc/anexomail/*.env (no output: the code default 3443 applies). UDP 4400 (Desk HTTP/3) collides with none of these.

## FOUNDER + other processes in the same list (never touch)
| Proto | Port | Process |
|---|---|---|
| UDP | 443 | anexomail-found (founder HTTP/3 + WebTransport) |
| UDP | 53 | founder-dns (62.238.98.98 and the IPv6 address) |
| UDP | 18443 | caddy (HTTP/3 test/spare listener) |
| UDP/TCP | 3478, 5349 | turnserver |
| UDP | 9200, 9300 | axon_core |
| TCP | 127.0.0.1:6379 | redis-server |
| UDP | 53 (127.0.0.53/.54), 323 (127.0.0.1/::1), 68 | systemd-resolve, chronyd, systemd-network |
Note: the first paste was cut by `head -40` after the TURN lines (TCP 22/25/80/443/8443 ... not shown); those stay as in the red-line file until a full list is pasted.

## QCONNECT (21:06 PKT): PostgreSQL on his server = UNIX SOCKET ONLY (/var/run/postgresql), NO TCP port, NO port from this list is touched. Services seen running: anexomail-awam-edge, anexomail-founder, caddy, founder-dns. OS packages: postgresql candidate 18 (Ubuntu). Disk 22 GB free, RAM 12.9 GB available.

## (22 Nov 2026 00:58 PKT) HIS PASTE 22 Nov 00:47: Caddyfile admindesk block (line 194) = encode zstd gzip + reverse_proxy 127.0.0.1:4400 only; ufw has 4400/udp ALLOW (v4 + v6, comment anexomail-desk http3); current public alt-svc = h3=":18443"; ma=2592000 (Caddy's own). desk-install step 6/6 adds one header line to that block: Alt-Svc h3=":4400".

## HIS ss 22 Nov 2026 04:56 PKT (UDP 443/4400/18443): *:443 anexomail-found pid 138322 (founder), *:4400 anexomail-desk pid 360037 (Desk h3), *:18443 caddy pid 129597. So Caddy does NOT own UDP 443; awam h3 is NOT via Caddy 443. S0: 4 WebTransport tries 04:53 from his Chrome failed; pcap /tmp/h4400.pcap result pending.
