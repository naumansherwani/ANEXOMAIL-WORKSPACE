> **21 Nov 2026 10:20 PKT: his db list = anexo_copy, anexo_founder, postgres. DESK ISOLATION: the Desk gets its OWN database `anexo_desk` (created by ad-sql-run.sh, no other name). Runner tested end to end on a local PostgreSQL 16 with his broken PGHOST reproduced (creates the database, applies AD1, 8/8 checks true, second run skipped). The Desk now has its own WORKING-NOW.md inside this folder (state/WORKING-NOW.md, refreshed by ckpt.sh and the 2-minute loop) and state/PHASES.md (feature, code, technology, HAAN per phase).**

> **21 Nov 2026 10:05 PKT: his db-list paste failed (PGHOST has literal quotes in his root shell, fact only); ad-sql-run.sh fixed (own PSQL() with -h /var/run/postgresql, PG* cleared); NEXT his corrected read-only db list, then AD1 on his server.**

> **21 Nov 2026 10:40 PKT, HIS WORD 09:59 (in anger): the Admin Desk folder lives INSIDE the Claude docs folder: CANONICAL = docs/claude/admin-desk/ (edit only there); ONE IDENTICAL COPY stays at the repo root admin-desk/ ('main': the server installers and gates fetch it from origin/main). Sync: `python3 docs/cursor-work/server/desk-copy-sync.py sync`; the commit gate (rule DESK COPY) fails if the two differ.**

> **21 Nov 2026 10:30 PKT: R3a2 step 1 = AD1.sql WRITTEN + TESTED on PostgreSQL 16 (schema `desk`, role desk_app NOBYPASSRLS, 5 fadm_* tables with RLS ENABLED+FORCED, SHA-256 hash-chained append-only ledger, ARGON2ID-shaped hash check, audience `desk`, rp_id admindesk.anexomail.com, support@ banned, SECURITY DEFINER login lookup, selftest; 8/8 CHECK rows true). Runner admin-desk/scripts/ad-sql-run.sh (own ledger, no founder env). Gate row R3a2-sql = code. NOT run on his server yet (needs his database name). NEXT in order: auth.rs ARGON2ID + constant-time -> DBSC -> orb pulse/zoom -> passkey ceremony -> R3p.**

> **21 Nov 2026 10:15 PKT: R3a0-s2 HTTP/3 = PROVEN on his server (his paste 09:55): `anexomail-desk h3check` = H3CHECK OK, HTTP/3 200 on loopback AND 62.238.98.98 (client offered ONLY X25519MLKEM768 + AES-256-GCM). Gate row R3a0-stage2 = CODE, the HTTP/3 block is LIFTED. Page pill now says HTTP/3 QUIC . TLS 1.3 . AES-256-GCM . X25519MLKEM768 (needs his desk-install.sh once). STILL HIS HANDS: AAAA + HTTPS record (alpn=h3 port=4400). PHASE ORDER NOW: R3a2 = AD1 SQL -> auth.rs ARGON2ID -> DBSC -> orb pulse/zoom -> passkey ceremony -> R3p plans.**

> **21 Nov 2026 10:05 PKT (his word 09:52): ALL QUIC/UDP advanced technology written and gated: admin-desk/docs/QUIC-UDP-TECH-21NOV.md (QUIC, HTTP/3+QPACK, TLS1.3 AES-256-GCM only, X25519MLKEM768, Retry, migration, no 0-RTT, BBR, Alt-Svc, h3check = CODE; DATAGRAM/WebTransport, MoQ, QUIC v2, ECH = PLANNED with dates; DNS HTTPS record = his hands).**

> **21 Nov 2026 09:58 PKT: new Desk page LIVE (pill = TLS 1.3 . AES-256-GCM, no HTTP/2 word). HTTP/3 listener runs but the h3check proof did not run on his server (old binary behaviour + two pids): diagnosis line added to desk-h3-check.sh; the HTTP/3 words go on the page the moment H3CHECK OK is pasted; then AD1 ... in order.**

> **21 Nov 2026 09:55 PKT: Desk HTTP/3 IS LISTENING on his server (UDP 4400, journal line + ss). Proof tool `anexomail-desk h3check` + desk-h3-check.sh written; NEXT his desk-install.sh then desk-h3-check.sh (H3CHECK OK flips row R3a0-stage2 and opens AD1 ...), then his AAAA + HTTPS record port=4400 (browsers must reach the Desk's own port, not Caddy's 18443).**

> **21 Nov 2026 09:50 PKT (his anger 09:38): the Desk page may NEVER write HTTP/2 or HTTP/1 (pill shows only HTTP/3 QUIC when the browser reports h3, else just TLS 1.3 . AES-256-GCM; gate allowlist empty). desk-h3-enable.sh failed on cert Permission denied (rolled back, Desk up, h3 off); fixed with systemd LoadCredential; NEXT his re-run of desk-h3-enable.sh (one line) and desk-install.sh once for the new page.**

> **21 Nov 2026 09:45 PKT: desk-install.sh RAN OK on his server (h3 binary live, h3 still OFF); desk-h3-enable.sh ran first and rolled back by design. NEXT his ONE re-run of desk-h3-enable.sh, then AAAA + HTTPS record, curl --http3. AnexoChat UDP proven = 3443 (no clash with Desk UDP 4400).**

> **21 Nov 2026 09:40 PKT: Desk HTTP/3 port = UDP 4400 (from his fresh ss 09:27). h3.rs has a REAL loopback PQ test (X25519MLKEM768 + AES-256-GCM handshake + h3 request: PASS). Scripts desk-install.sh + desk-h3-enable.sh committed; the HTTP/3 block stays ON until his curl --http3 proof; then his AAAA + HTTPS record (port=4400).**

> **21 Nov 2026 09:30 PKT, HIS WORD 09:23: HTTP/1 AND HTTP/2 ARE BOTH BANNED (gate). Desk HTTP/3 listener CODE WRITTEN (admin-desk/server/src/h3.rs: quinn+h3, TLS 1.3 AES-256-GCM only, X25519MLKEM768 first, 5 tests pass); NOT live until his ss (UDP port) + AAAA/HTTPS record + curl --http3 proof. Order after that: AD1 SQL, auth.rs ARGON2ID, DBSC, orb pulse/zoom, passkey ceremony, R3p plans.**

> **21 Nov 2026 09:25 PKT, HIS WORD: HTTP/3 HARD BLOCK. HTTP/2 is BANNED for the Desk. No later phase (AD1 SQL, auth.rs ARGON2ID, DBSC, orb pulse/zoom, passkey ceremony, R3p plans) may exist in the repo until the Desk's own HTTP/3 + X25519MLKEM768 listener (R3a0-stage2) is in code and proven (his curl --http3). The gate fails the commit. Technology = founder's or more advanced.**

# ADMIN DESK BLUEPRINT (live copy of the Desk phases; his order 21 Nov 2026 08:19 PKT)
Updated: 21 Nov 2026 08:30 PKT. Plan with times: docs/claude/ADMIN-DESK-3DAY-PLAN-21NOV.md. The Desk is its OWN security domain (docs/claude/DESK-ISOLATION-GATE-21NOV.md). Rule 52: every browser call is signed and verified in the ONE Rust WASM kernel. SQL series for the Desk = AD1, AD2, ... (founder and awam keep the E series).
RULE (his word): in every phase, next to each FEATURE the CODE file and the ADVANCED TECHNOLOGY are written, and "HAAN" = yes only when the technology is really in that file AND seen working. The gate admin-desk/gates/DESK-FEATURES.json enforces this: missing technology = FAIL, NO COMMIT, shouted.

## PHASE R3a: Desk ka Ghar aur Darwaza (Sat 21 Nov 08:00 - 18:00)
### R3a0 HOST (admindesk.anexomail.com)
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Own process on loopback 4400 | admin-desk/server/src/main.rs | RUST, TOKIO, AXUM 0.8 | YES (his install 08:19: listener 127.0.0.1:4400) |
| Wrong Host = 404 + journal line | admin-desk/server/src/main.rs (host_gate) | AXUM MIDDLEWARE | YES (his install: wrong host 404) |
| Security headers | admin-desk/server/src/main.rs (desk_headers) | CSP SELF-ONLY + TRUSTED TYPES, COOP, CORP, HSTS | YES in code + sandbox; public look pending |
| Own installer + unit + user | admin-desk/scripts/desk-install.sh | SYSTEMD HARDENING (NoNewPrivileges, ProtectSystem, MemoryDenyWriteExecute) | YES (his install ran) |
| Own bundle | founder-web/vite.desk.config.ts, desk.html | VITE 8 SEPARATE ENTRY | YES (build ok) |
| HTTP/3 + AES-256-GCM X25519MLKEM768 for this host | planned: SNI front + UDP 443 route | HTTP/3, QUIC, TLS 1.3 AES-256-GCM, X25519MLKEM768 | NO (stage 2, gate date 23 Nov) |
| AAAA + HTTPS alpn=h3 DNS | his Namecheap hands | DNS | NO |
### R3a1 CINEMATIC LOGIN
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Night glass-walled office scene, gradient #060B19 / #0F3460 / amber rim | founder-web/src/desk/DeskScene.tsx | REACT 19, THREE.JS (LAZY DYNAMIC IMPORT, city-light points) | sandbox YES at 390/820/1280 (his design approved 08:31); his server NO until install |
| Mouse + phone-tilt parallax (wall, points and card move at different speeds; off with reduced motion) | DeskScene.tsx | POINTER EVENTS, DEVICEORIENTATION, requestAnimationFrame | code YES, live motion NOT yet seen by his eyes |
| Smoked liquid-glass card, 1px luminous edge, Desk identity only, ORIGINAL BrandMark logo + HoverA "A" kept | founder-web/src/desk/DeskSignIn.tsx | CSS BACKDROP-FILTER, original signin/BrandMark + BrandLoader | sandbox YES 390/820/1280 |
| Optional passkey button + honest hardware text (real PublicKeyCredential check) | DeskSignIn.tsx | WEBAUTHN detection; the passkey ceremony itself arrives with the Desk door R3a2 | detection YES; ceremony NO |
| Orb pulse, shockwave, zoom into 3-pane workspace | DeskScene.tsx (planned) | THREE.JS, GSAP | NO |
| Real telemetry: protocol (browser-reported), kernel state; Merkle only when the door reports a head; NO cipher line until stage 2 | founder-web/src/desk/DeskTelemetry.tsx | RUST WASM KERNEL (kernel.ts trust), PerformanceNavigationTiming | YES (values real; Merkle + cipher hidden on purpose) |
| Principle line + "Built on" technology line (only real technologies) | founder-web/src/desk/DeskSignIn.tsx, DeskPages.tsx | RUST, TOKIO, AXUM, WASM KERNEL, WEBAUTHN, THREE.JS (all in code) | YES in code (promise rows P5 proven, P6 open until R3f) |
### R3a2 LOGIN DOOR
| Feature | Code | Technology | Haan |
|---|---|---|---|
| Schema AD1: owner, sessions, ledger, desk_app | admin-desk/sql/AD1.sql (planned) | POSTGRESQL RLS, APPEND-ONLY SHA-256 HASH CHAIN | NO |
| /desk/v1/auth/login | admin-desk/server/src/auth.rs (planned) | ARGON2ID, CONSTANT-TIME, TOKEN AUDIENCE "desk" | NO |
| Device-bound session | auth.rs (planned) | DBSC | NO |
| Owner created by his command (password never in chat) | admin-desk/scripts (planned) | ARGON2ID | NO |

## DESK PRINCIPLE (his 21 Nov 2026 08:40, shown on the landing + login): "Our engine runs in milliseconds; our support should too. Own the issue, fix the root, leave zero open loops." It is a PROMISE (WEBSITE-PROMISES P6): R3f builds it (one owner per issue, SLA clock, an issue closes only with a root-cause note; no open loops).

## ONE ENGINE FOR ALL PLANS (his 21 Nov 08:53 question, answer YES): the awam plans Basic, Pro, Business, Business Pro, Business Premium, Business Max are DATA in the Desk (table fadm_plans in AD1: plan name, support lane, first-response hours, priority weight), not six builds. A company's plan reaches the Desk only through its own channel (Polar signed webhook / the Desk's own record), never by reading awam tables (isolation). The inbox, SLA clock and labels read the plan row. Open: which awam packages are live (his D answer) and the Business Max / Premium support terms.

## PLAN R3p (his 21 Nov 09:02): Premium + Max lanes first, founder technology only, no mix with awam: full plan with feature/code/technology/haan table = admin-desk/docs/PLAN-PREMIUM-MAX-21NOV.md (R3p0 terms from him, R3p1 AD2 SQL, R3p2 Polar webhook door, R3p3 lanes UI, R3p4 SLA clock, R3p5 named contact + quarterly review, R3p6 other four plans as rows).

## PHASES AFTER R3a (each gets its own feature table when it starts; plan times in the 3-day plan)
R3b inboxes (Sun 06:00) / R3c auto mail RFC 3834 + Polar signed webhook (12:00) / R3d dashboard + mail UI (17:00) / R3e reply without passkey (Mon 06:00) / R3f SLA engine (09:00) / R3g verify + final (14:00-21:00) / R4 Managed Move-In + Priority Support (from Tue 24 Nov) / R5 LEO / R6.
