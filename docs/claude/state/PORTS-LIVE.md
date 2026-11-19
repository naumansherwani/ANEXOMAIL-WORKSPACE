# LIVE PORTS OF HIS SERVER — READ BEFORE ANY LISTENER / PORT / CADDY WORK (PORT RED LINE)
Source = HIS fresh paste: `ss -tulnp | head -40` and `ss -tlnp | grep anexomail-rust`, **20 Nov 2026 03:30 PKT** (real clock). Printed by ckpt.sh (into WORKING-NOW.md) and by rules-read.py, so a fresh Claude after compaction sees it first.
UPDATE RULE: every time he pastes a new `ss`, replace the table below + the date in the same step (rec.sh), and append one line to docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. Never guess a port: no fresh paste = ask for a read-only command.
Full law + older history: docs/claude/SERVER-PORTS-RED-LINE-08NOV.md. QC1e D4A (company emoji) adds NO port: its procs live inside the existing /rpc/* on TCP 3200.

## AWAM Rust engine = process `anexomail-rust` (pid 3145875 at 20 Nov 03:30)
| Proto | Address:Port | Meaning |
|---|---|---|
| TCP | 0.0.0.0:3200 | HTTP/RPC `/rpc/*` (behind Caddy) |
| TCP | 127.0.0.1:3500 / 3600 / 3601 | internal (local only) |
| UDP | *:3443 | WebTransport |
| UDP | 0.0.0.0:3501 | awam Rust UDP (internal channel) |

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
