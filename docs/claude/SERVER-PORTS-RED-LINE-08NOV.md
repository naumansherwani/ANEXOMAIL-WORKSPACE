# SERVER PORTS RED LINE (founder 8 Nov 2026 13:31 PKT, in anger)

His words (gist): these ports carry parts of his server 1 and server 2 TUNNEL and HANDSHAKE traffic; save them in the repo and keep them on TOP; before anything, look at the server DIRECTLY with a command so the red line is never crossed.

RULE: before ANY new listener, test instance, firewall or Caddy change, Claude first gives him a read-only command that lists the listening ports WITH their process names and the live connections to the other server; a port is used only if it is absent from that fresh list AND from this file; ports are never chosen from memory or from the repo. A listed port is never stopped, rebound or reused by a test.

## Ports in use on server 1 (his ss output, 8 Nov 2026 13:28 PKT)
- TCP: 22 25 80 143 443 465 587 993 2019 (Caddy admin, 127.0.0.1) 3000 3100 3200 3210 3300 3310 3400 3478 3500 3600 3601 5349 5678 5679 6379 8443 (founder TLS terminator) 8445 (SNI front, 127.0.0.1) 8891 9201 10023 11332 11333 11334 (+ local DNS 53).
- UDP: 68 323 443 (Caddy HTTP/3) 3443 (WebTransport) 3478 3501 5349 9200 9300 60192.
- Which of these belong to the server 1 / server 2 tunnel and handshake is NOT yet read from the server (process names missing): his next paste fills this in.

## Proposed spare ports for the Caddy test copy (NOT confirmed, not yet used by anything)
HTTPS 18443, HTTP 18080, admin 127.0.0.1:12019. They stay a proposal until his fresh process-name list confirms them free. Nothing was bound, nothing on the server was changed.
