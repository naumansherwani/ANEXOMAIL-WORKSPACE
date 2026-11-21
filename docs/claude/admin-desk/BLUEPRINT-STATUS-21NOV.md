# ADMIN DESK BLUEPRINT: BUILT / LEFT / WHERE WE STAND (21 Nov 2026 23:10 PKT)
Host admindesk.anexomail.com. Own security domain (own binary anexomail-desk, own DB role desk_app, own tables fadm_*, own session anexo.desk.session, audience desk). Commands: INSTALL, SQL, RESTART only.

## LIVE ON HIS SERVER (proven by his pastes)
| Phase | What | Technology | Proof |
|---|---|---|---|
| R3a0 | Own Desk process, host gate (wrong host 404), security headers, own page bundle | Rust, Tokio, axum 0.8, CSP | install 23:08: health 200, wrong host 404 |
| R3a0-s1 | Public TLS path | TLS 1.3, AES-256-GCM only | his openssl 08:53 |
| R3a0-s2 | Desk's own HTTP/3 listener UDP 4400 | QUIC (quinn), h3, X25519MLKEM768 first, AES-256-GCM, BBR, Retry, 0-RTT off | H3CHECK OK 09:55 |
| R3a1 | Login page + home page (his design, ball off, one light, @anexomail.com, awam Sign in colour) | React 19, Vite 8, TypeScript, Tailwind 4, Three.js scene | install 23:08 |
| R3a2-1 | AD1 + AD1b SQL: schema desk, 5 fadm tables, RLS forced, SHA-256 hash-chained ledger, session functions | PostgreSQL RLS, SECURITY DEFINER, append-only ledger | ad-auto 3/3 + AD1 already run |
| R3a2-2 | Owner admindesk@anexomail.com, password typed on the server | ARGON2ID (64 MiB, t=3), constant-time | desk-owner 10:5x |
| R3a2-3 | Login door /desk/v1/auth/login, /me, /logout; own DB login desk_app; Supabase CA pinned | Rust door, HttpOnly Secure SameSite=Strict cookie, 5 fails/15 min, rustls to the DB | install 23:08: "database login live" |

## WRITTEN, NOT YET PROVEN
- His first real sign-in (admindesk + password) and the page after it.
- Sign-in flash (demo shown, waits his pick A / B / A+B).

## OPEN GAPS (never green until closed)
- HTTP/3 law: the PUBLIC path still answers browsers over TCP through Caddy (his install shows "HTTP/2 200"); the Desk's own HTTP/3 on UDP 4400 is proven, but browsers reach it only after his Namecheap AAAA + HTTPS record (alpn h3, port 4400) and an Alt-Svc for 4400 on the public answer.
- Rule 52 on the Desk: API answers are not yet signed and kernel-verified; the Desk page still imports shared sign-in files and the shared kernel.

## NEXT, IN ORDER (each with its technology)
1. His sign-in test now (password).
2. Rule 52 for the Desk: own kernel RPC, audience desk; server signs every answer (Ed25519, ML-DSA hybrid where listed), the Rust WASM kernel verifies; Desk gets its own copies of the sign-in files.
3. DBSC: device-bound session (Secure-Session-Registration, ES256 key in the browser, 15 min refresh).
4. Orb pulse/zoom into the 3-pane workspace (Three.js, GSAP).
5. Passkey ceremony, optional (WebAuthn, rp_id admindesk.anexomail.com).
6. R4-1..R4-10: founder mailbox phases copied in order (PLAN-DESK-UI-COPY-21NOV.md): shell, company inboxes, compose, rich text, send tools, PQ mail, delete/follow-up, shortcuts, attachments (WebTransport, Storage Box, ClamAV), TLS policy + OpenPGP PQC.
7. R3p plans: Business Premium + Max first, Desk palette preserved for them (codes/DESK-PALETTE-PREMIUM-MAX.md).
8. R3b-g: assign/reply/SLA engine, dashboard, final.
His hands: Namecheap AAAA + HTTPS record.
