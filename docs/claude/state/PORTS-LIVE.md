# LIVE PORTS OF HIS SERVER — READ BEFORE ANY LISTENER / PORT / CADDY WORK (PORT RED LINE)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 21:06 PKT** (real clock; re-pasted, same list as 03:30: nothing new listening; anexomail-rust pid 3902845, founder pid 4124221). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
Full law + older history: docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. QC1e D4A (company emoji) adds NO port: its procs live inside the existing /rpc/* on TCP 3200.

## AWAM Rust engine = process `anexomail-rust` (pid 3145875 at 20 Nov 03:30)
| Proto | Address:Port | Meaning |
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

## RESERVED BY HIS WORD 21 Nov 2026 07:5x PKT: TCP 127.0.0.1:4400 = ADMIN DESK (own Rust process `anexomail-desk`, loopback only; Caddy has the admindesk block since 21 Nov 07:51 PKT: reverse_proxy 127.0.0.1:4400, validated + reloaded; nothing listens on 4400 yet). His free-port check showed 4400, 4500, 7400, 8400 free. Never use 4400 for anything else.

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
