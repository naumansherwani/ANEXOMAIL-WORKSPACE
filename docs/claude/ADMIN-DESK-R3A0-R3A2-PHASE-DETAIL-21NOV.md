# ADMIN DESK: FIRST PHASES IN DETAIL FOR DISCUSSION (21 Nov 2026 08:30 PKT) nothing built beyond the login face

## The stop rule (his 07:34 word: "advance technology na ho to gate ruk jaye")
docs/claude/TECH-LAW-GATE.json now carries the Admin Desk technology per phase: 3 checks that must hold forever (own bundle, own session key, shared postJson) and 11 OPEN checks (host router, login door, ARGON2ID, SQL E201 + desk_app role, SQL E202 SLA, virtual list, RFC 3834 gate, kernel RPC, SLA pause rule, IMAP migrator, attachments core). Each OPEN check prints a warning on EVERY commit and FAILS the commit from its fail_after date (the existing his-11-Nov-21:59 mechanism). My proposed dates (he may change): R3 checks 24 Nov 2026 (the plan target is Mon 23 Nov 06:00), R4c IMAP 12 Dec, attachments core 20 Dec. A listed technology missing in code = OPEN, never GREEN.

## Attachments (his 07:34 word)
The big e-mail ATTACHMENTS phase comes AFTER Managed Move-In (R4), built on ONE advance technology (TOKIO + RUST + WEBTRANSPORT, chunked sealed streams, ClamAV, Hetzner Storage Box) shared by founder, Admin Desk and awam. Until then the Desk shows "attachment" mails honestly ("N attachment(s): available after the attachments phase"); no second attachment path is built. Existing OPEN checks D-clamav, D-hetzner-storagebox, Q-att-wt stay.

## R3a0 HOST (first) , what, in order
1. READ-ONLY CHECK on his server (one line, below): who owns ports, DNS of admindesk (A/AAAA/HTTPS alpn=h3/CAA) next to founderworkspace, Caddy knowledge of the name, certificate files, firewall udp 443. His paste = the facts (law: no guess).
2. DNS finish at Namecheap (HIS hands, one numbered step at a time, from the paste): A/AAAA to the same server, HTTPS record alpn=h3 (TTL 300), CAA.
3. CERTIFICATE for the host: reuse the K4.3 refresh timer path; written and proven before any switch.
4. RUST: SNI HOST ROUTER in fproxy.rs/tls256.rs: Host admindesk -> Desk doors + dist-desk files only; Host founderworkspace -> founder doors only; wrong host on a door = 404 and a ledger line (HOST-CONFUSION GUARD) with unit tests; PORT RED LINE: UDP 443 by SNI, no new port unless his fresh ss paste says it is free; Caddy law + installer-after-cut law apply.
5. HEADERS for the Desk host: CSP + TRUSTED TYPES, COOP/CORP same-origin, frame-ancestors none, HSTS, __Host- cookies.
6. HIS install (one line), then MY live Chrome: landing, /adminlogin, /dashboard on the real host AND the founder tab open at the same time (the two-tab proof), 390/820/1200+. GREEN only then, WIRED: YES / REAL: YES / TECH-LAW CHECKED.
Technology: RUST TOKIO AXUM, HTTP/3 + WEBTRANSPORT ON UDP 443, TLS 1.3 AES-256-GCM X25519MLKEM768, REACT 19 + VITE 8 SEPARATE ENTRY.

## R3a1 LOGIN FACE (written, not wired)
Landing + /adminlogin + /dashboard exist as design; becomes REAL when the door /desk/v1/auth/login (R3a2) exists. Passkey optional (R6).

## R3a2 CONTRACT + SQL (before the login can be real)
Contract in CURRENT.md; SQL E201 (read the schema that owns the tables first, schema-first law): fadm_staff (owner row only, password ARGON2ID hash, role owner), fadm_sessions (token audience desk, DBSC-ready), fadm_mailboxes (hello, moveyourbusiness, resolved, leo; billing/noreply send-only), fadm_threads/issues/assignments/notes, hash-chained append-only fadm_ledger, RLS on all, role desk_app with grants ONLY on fadm_* (zero founder grants; the gate gets a desk_app grant check in the same step), selftest + CHECK_E201; E202 business-hours SLA engine (clock stops only on a human reply or resolve). Then Rust door /desk/v1/auth/login (ARGON2ID, rate cap, constant-time) and the owner is created by HIS command (he sets the password; never in chat). Login becomes REAL.

## What I need from him to start R3a0
His "haan" for the read-only command (below), his fresh output, then the Namecheap steps one at a time.
