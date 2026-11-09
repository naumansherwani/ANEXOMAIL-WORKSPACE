# PHASE SUMMARY: what each phase does, what the founder gains, what AWAM gets (founder 8 Nov 2026 13:07 PKT)

His standing orders behind this file (verbatim gist, 8 Nov 13:07): (1) every phase gets a DETAIL SUMMARY: what we do inside the phase and what the founder gains; (2) when a founder technology is also meant for awam, the FOUNDER CODE IS PRESERVED as it is; later the same code is molded a little into the AWAM pattern and built for awam on the latest technology; (3) next to each phase it is written what awam will get ("yeh awam ko mile ga, awam ke pattern ke hisab se, latest technology par").

**Awam-from-founder rule (never mixed):** founder code stays untouched in the founder lane (Rule 73: founder never imports awam code and the reverse). Awam gets a COPY of the idea, molded into the awam UI pattern and the awam package surface (`plan-surface.ts`), on the latest technology, in the awam lane AFTER the founder lane, with its own separate awam pull command (SHARED-CODE RULE). Mobile 390 + tablet 820 + laptop 1200+ in every phase, both lanes.

| Phase | What we do inside it | What the founder gains | What AWAM gets (awam pattern, latest tech, after the founder lane) |
|---|---|---|---|
| J8d, G1, G2 (GREEN) | device-bound vault lease with a 15-minute key; phone alerts; the browser session snapshot sealed AES-256-GCM by the vault key | a stolen browser or laptop shows nothing; real alerts on his phone lock screen | optional sealed snapshot + device alerts for users (new mail, calendar), inside Settings > Privacy in the awam look |
| K4.1-K4.4 (GREEN) | own Rust TLS 1.3 AES-256-GCM-only terminator, cert hot-reload, SNI front on a spare port | the founder site speaks only AES-256 (Caddy cannot) | K5 below |
| K4.5 (coded, installed OFF) | terminator reads the real client IP from the front (PROXY v1, loopback only, strict) | logs, limiter and device records see the real person, not 127.0.0.1 | same IP honesty for users automatically via K5 |
| K4.6 | CHECK + SQL E119 posture ledger (advanced SQL) + Chrome 390/820/1200+ on the real :443 switch | proof, written in SQL, that the founder host really negotiates AES-256 | K5 reuses the check |
| K5 | the same terminator for the user site | n/a | AES-256 on anexomail.com for every user (his "HAAN" 1 Nov), separate awam command |
| K6 | WebTransport over QUIC (Rust wtransport) | live push without polling | live inbox/calendar without refresh |
| K7 | DBSC: session bound to the device's TPM key | a stolen cookie is useless elsewhere | the same protection for every user session |
| L | motion (Framer Motion, GSAP) and Three.js WebGPU, CINEMATIC pixel-equal | the look he loves, smoother | calmer motion in the awam pattern (no founder cinematic copy) |
| M | MoQ live media relay | live pulse, low latency | MQ0-MQ4 live media features |
| N, N1 | Decide + Live Pulse + push; Device Trust Map | one screen to decide; sees every trusted device | founder only; users get their own device list in Settings |
| O | finance deck (Polar, revenue, billing, release, move-in) + Enterprise contract form + Max near-cap alert | real money data; contract and cap handling in one place | billing portal for users: invoices, free months shown first (2 months, Max 3), then paid months |
| P, P1, P2 | people: org, CRM, team, account 360, insider guard | knows every account and every staff action | CRM/team per package surface |
| Q, Q1-Q6 | mail + calendar depth: attachments (dedupe, resumable, signed links), PQ OpenPGP, sealed agreements | strongest mail controls | the same mail engine; own-domain mailboxes for Premium/Max |
| R, R1-R3 | systems: health, analytics, mesh sync, Mail<->Chat bridge, Mail Desk | sees the platform's health | public status page; chat bridge |
| S, S1 | control: kill switch, flags, poison pill (two hardware keys, G3) | can stop anything in seconds | founder only |
| T | CUTOVER: old Lovable founder routes removed after Rust == Bun | one clean founder codebase | n/a |
| U | Docs + Sheets (WOPI host in Rust) | built-in office | AX-P11 AnexoSuite (Word/Excel/Docs/Sheets for everyone), last |
| V | founder AI (founder only) | AI help inside his workspace | AI is a SEPARATE product at ai.anexomail.com |
| X1-X4 | restore proof, founder continuity, served-code seal, supply-chain board | survives accidents and tampering | n/a |
| G3, G5, G6, G7 | G3 two hardware keys panic lock; G5 ANEXOChat founder screen; G6 phone view of the other tabs; G7 tablet 820 | the panic button for real; chat; phone and tablet proofs | ANEXOChat reaches awam in the awam pattern later |

Honest notes: awam rows are the PLAN, nothing of awam is built or live; prices, Polar, landing and plans.ts stay untouched until he says "go".

- 9 Nov 2026 16:05 PKT K4 = GREEN founder. Awam counterpart: AW-K5a (AES-256-only TLS for the WHOLE awam website, all 23 hosts, h2+h1) and AW-K5b (HTTP/3 stays, AES-256 keys); see AWAM-PROTON-PLUS-PLAN-07NOV.md rows 1 and 1b. K5a DESIGN (chosen 16:05, reuses the K4 code): a Rust TLS 1.3 AES-256-GCM-only terminator with a multi-host certificate store (all certificates of Caddy's directory, SNI picks, hot reload like K4.3) on a loopback port from a fresh ss list (18081 was FREE in his 9 Nov 15:52 output), ALPN h2 + http/1.1, and a RE-ORIGINATION TUNNEL: after the client handshake it opens an inner TLS connection to Caddy 127.0.0.1:18443 with the SAME ALPN and SNI, sends the PROXY v1 line (real client IP) first, and copies bytes both ways, so no HTTP parsing is needed and h2, WebSockets, SSE, streaming all pass unchanged; the front sends all non-founder names to this terminator (FOUNDER_FRONT_OTHER=127.0.0.1:18081, PROXY on). No Caddy change. Cost: double TLS on loopback (cheap). Proof = per awam host openssl (AES-256 ok, AES-128 refused), E119 rows, Chrome 390/820/1200+ on anexomail.com.
