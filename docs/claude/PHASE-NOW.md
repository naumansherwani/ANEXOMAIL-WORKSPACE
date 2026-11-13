# PHASE NOW (ONE phase only; Claude opens THIS file first after any compaction / new chat). Written 13 Nov 2026 21:25 PKT, his order 21:14.
## Phase: KP1 = PORTS / CADDY / SNI FRONT / UDP / DNS AUDIT (read-only), the gate in front of K8e (HTTP/3 only)
## Advance technology of this phase
HTTP/3 ONLY (no h2, no HTTP/1.1), QUIC on UDP 443 (anexomail-founder, quinn + h3, TLS 1.3 AES-256-GCM, X25519MLKEM768), WebTransport on UDP 4443, DNS HTTPS record (RFC 9460) alpn=h3, Alt-Svc 1 year persist. Everything else advance stays intact (Rust WASM kernel, kernel WebTransport RPC, DBSC, ML-DSA hybrid).
## Summary (why)
Port scares came from guessing. His server facts (his paste 13 Nov 20:49): udp 443 = anexomail-founder (HTTP/3, FOUNDER_H3_ADDR=[::]:443), udp 4443 = anexomail-founder (WebTransport), udp 3443 + 3501 = anexomail-rust, udp 18443 = caddy, tcp 8443 = founder TLS terminator. UFW has udp 443; 4443 not yet seen. DNS HTTPS record is missing. The old founder-h3-check.sh gave a FALSE STOP (ss cuts names at 15 chars).
## Codes (detail)
- `docs/cursor-work/server/founder-ports-audit.sh` (READ-ONLY, changes nothing): 7 parts: (1) real owner of tcp 443/8443/3210 and udp 443/4443/3443/18443 from /proc/<pid>/exe, exact-name checks for udp 443 + 4443; (2) every listener on those ports; (3) Caddy's own admin API listen addresses; (4) founder.env H3/TLS256/WT/FRONT ports only, secrets filtered; (5) journal lines (HTTP/3 ON, terminator, WebTransport, tcp closed); (6) dig HTTPS must name h3, A/AAAA compared with this server's own addresses; (7) firewall per port (udp 443 and udp 4443). Ends GO / STOP for K8e.
- Sandbox-tested with a stub `ss` (parsing of `*:443`, `0.0.0.0:4443`, real name from /proc): works; ss itself is absent in the sandbox, the real proof is HIS output.
- SERVER-FIRST gate (done, phase SF): serverfirst.py receipts, rules-gate "SERVER FIRST" + "H3 ONLY".
## Plan (strict order, one at a time)
1. KP1: he runs the audit, pastes the output (receipt recorded). 2. His DNS HTTPS record (Type HTTPS, Name founderworkspace, Priority 1, Target ., Value alpn="h3", TTL 300); audit again until GO. 3. K8e install (founder-install.sh), my live Chrome look: assets on h3. 4. KP2 UDP-blocked break-glass (SSH tunnel to 127.0.0.1:3210), tested at home. 5. QUI-H3 (E172 on server, Rust ledger-rows door, kernel chain hash). 6. QUI-H4, QPERF (E173), Q1d-1 ...
## Rules that always apply (his words)
Roman Urdu, short; ONE phase at a time; every doubt of 0.1% about the server = a read-only command to his server FIRST (SERVER-FIRST law, one year); K-series code never touched outside its own phase; no push/commit surprises: every server step is command-first; repo + state ledger + this file updated after every step; mobile 390 / tablet 820 / laptop 1200+ before any green; end every reply with the Rule-70 table + "Abhi code mein NAHI".

## STATUS 13 Nov 21:30 PKT
- KP1 step 1 DONE: his audit output received (SF receipt 2). OK: udp 443 + 4443 = anexomail-founder, firewall open both. tcp 443 still anexomail-founder (old binary, K8e not installed). Caddy only on 18443/80. STOP reason: DNS HTTPS record missing (A 62.238.98.98 = this server, no AAAA). NEXT (his hands): add the HTTPS record, then dig + audit again until GO.

## STATUS 13 Nov 21:55 PKT
- His dig (SF receipt 3): NS = dns1/dns2.registrar-servers.com (Namecheap BasicDNS); HTTPS record empty at 1.1.1.1. Namecheap docs list no HTTPS/SVCB type (not 100% sure; his screen decides: Advanced DNS > Add New Record dropdown). LOOPHOLE: tcp 443 closed + no HTTPS RR = new browsers cannot reach the site. K8e install HELD. Options for him: 1) DNS to Cloudflare DNS-only (own phase, full record dump first), 2) delegate only founderworkspace, 3) keep tcp 443 (breaks his H3-only order, needs his word).

## ALWAYS (his 13 Nov 21:54): the banned CDN/DNS-proxy vendor (docs/claude/FOUNDER-VENDOR-BAN-13NOV.md) is never named to him and never offered. The 21:48 reply offered it by mistake: RETRACTED. KP1 DNS answers: his Namecheap panel (HTTPS type?), or his own Rust authoritative DNS for the one subdomain `founderworkspace` delegated by NS (read-only port 53 check first). Caddy cannot publish DNS records.

## ALWAYS (his 13 Nov 21:59): no third-party vendor, lifetime. Allowed: Caddy, Namecheap (his hands), Hetzner, own Rust. Steps are given for HIS Namecheap panel and HIS server; he does them.

## STATUS 13 Nov 22:08 PKT (KP1b)
- His screenshots (22:03): Namecheap Add New Record dropdown = A, A+Dynamic, AAAA, ALIAS, CAA, CNAME, NS, SRV, TXT, URL Redirect. NO HTTPS TYPE. DECISION (Claude, he said "faisla tum ker lo"): his OWN Rust authoritative DNS for the ONE zone founderworkspace.anexomail.com, delegated by NS records at Namecheap (mail records untouched), no third-party vendor.
- Step now: `founder-dns-audit.sh` (read-only, port 53 + DS + what the subdomain holds today). Next after GO: Rust DNS (tokio, UDP+TCP 53, HTTPS RR type 65 alpn=h3, A/AAAA/NS/SOA/CAA copy), contract in CURRENT.md first, sandbox-proven with dig-style tests; then his Namecheap steps (A record ns1, NS record for founderworkspace), then K8e.

## KP1b ADVANCE TECHNOLOGY (his 13 Nov 22:04 "advance level, hamesha ke liye masla solve"): written BEFORE code, waits for his port 53 audit output (SERVER-FIRST)
Rust + tokio, hickory-proto wire format; authoritative ONLY (no recursion, so no open-resolver abuse), zone founderworkspace.anexomail.com ONLY; UDP + TCP 53 (EDNS0, TC bit, TCP fallback); records SOA, NS, A, AAAA, CAA, HTTPS (type 65, `1 . alpn="h3"` per RFC 9460), SVCB; DNSSEC-signed zone (Ed25519 / ECDSA P-256, NSEC3, key kept in his server vault); DNS cookies (RFC 7873) + response rate limiting against reflection; zone read from a PostgreSQL table with append-only hash-chain ledger (every record change = one ledger row, like fmail_ledger); a CHECK that queries itself with dig; second NS on his server 2 if he names its address. DS record goes to Namecheap only if the parent supports it, otherwise the zone stays signed-but-unanchored and is said so plainly. Systemd unit, runs as an unprivileged user with CAP_NET_BIND_SERVICE only. Rollback = remove the NS record at Namecheap (the old A record returns).
