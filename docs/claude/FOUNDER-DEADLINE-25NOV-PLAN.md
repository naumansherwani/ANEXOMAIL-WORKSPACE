# FOUNDER DEADLINE: WHOLE FOUNDER BLUEPRINT GREEN BY 25 NOV 2026 (his order 9 Nov 17:32 local, in anger: 'mainay founder ka pura kaam 100% complete kerna hai 25th november tak ... PURA FOUNDER KA ACCOUNT GREEN KERNA HAI YANI PURA BLUEPRINT 25TH NOVEMEBER TAK KI DEADLINE HAI')
Supersedes the 20 Nov window in NEXT-ORDER-09NOV-K5B-TO-20NOV.md for the founder lane. Awam work (K5b h3 AES-256, awam migration AW-K6/K7) runs AFTER the founder lane in the awam lane (separation law), Caddy's h3 keeps serving awam meanwhile. Every phase: WIRED: YES / REAL: YES with proof, looks 390 / 820 / 1200+, fresh ss before any listener, rollback FILE before any live switch, server lines without quotes, repo + chat context + codes updated with date and time after every step.

| Day (Nov) | Phase | Technology | He gets |
|---|---|---|---|
| 9-10 | **K6** | Rust wtransport (QUIC/HTTP3, AES-256) on a FRESH UDP port (fresh ss first; 3443 is already held), React live feed, WASM kernel frames | live founder events with no polling |
| 11 | **K7** | DBSC: Rust start/refresh routes + SQL ledger (Chrome TPM-bound session) | stolen cookie is useless |
| 12-13 | **L** | React-TS UI: Framer Motion + GSAP, Three.js WebGPU lazy (CINEMATIC stays pixel-equal) | motion and 3D, same look he loves |
| 14-15 | **M** | MoQ relay (Rust on wtransport) + kernel + React | low-latency live pulse/media |
| 16-17 | **N, N1** | SQL + Rust push + React-TS: Decide, Live Pulse, S4 push, Device Trust Map | one screen to decide |
| 18 | **O** | Rust (Polar webhook verify) + SQL + React-TS: Finance deck | real revenue and billing data |
| 19 | **P, P1, P2** | SQL (RLS, ledgers) + Rust + React-TS: People, org, CRM, insider guard | people and accounts |
| 20-21 | **Q (Q1-Q6)** | Rust + SQL + WASM kernel + React-TS: mail + calendar, attachments, PQM OpenPGP, sealed agreements | the mail system (mailboxes) |
| 22 | **R, R1-R3** | Rust + SQL + React-TS: systems health, analytics, mesh sync, Mail Desk | systems board |
| 23 | **S, S1** | Rust + SQL + passkeys: kill switch, flags, executor, poison pill (T3 two-key) | control |
| 24 | **T + U** | cutover (remove old Lovable founder routes after Rust == Bun) + WOPI Docs/Sheets | one Rust founder |
| 25 | **V + X1-X4 + FINAL** | Founder AI, restore proof, continuity, code seal, supply chain; full green check on every line | 100% founder |

## What I cannot force (said once, plainly; each is given to him as ONE numbered step when it comes)
- S (T3 two-key) and G3 need his 2 hardware keys; Q mailboxes need his Hetzner written confirmations (open since 7 Nov); U Sheets engine needs the licence read; looks 820 need his tablet. If one of these is late, that line stays on the OPEN list, never written green.
- Day plan is tight: if a phase fails its proof it is fixed the same day, the next one does not start (his rule), and the day plan shifts; the list stays honest.

## STANDING RULE (his 9 Nov 17:37, verbatim: 'IS PLAN KO SAVE KERO ISI TARGET PE HUM KAAM KARAY GAY YEH RULE TOP PE LIKHO KE HER PHASE KE LIYE DEADLINE PE KAAM HOGA')
EVERY PHASE HAS ITS OWN DEADLINE (the day column above) AND WORK RUNS TO IT. Each reply starts from the day plan: which phase is today, how far it is, what is left. A phase that slips is fixed the same day, and the list is shifted honestly, never written green.

## AWAM DEADLINE (his 9 Nov 17:37, verbatim: 'AUR YEH WEBSITE AWAM KE LIYE 16TH DECEMBER TAK 100% COMPLETE KERNI HAI WITH TEST ANEXOCHAT SAB KUCH')
The whole awam website 100% complete by 16 DEC 2026, WITH TESTS, AnexoChat and everything. Works in the awam lane AFTER the founder lane (26 Nov to 16 Dec): awam K5b (h3 AES-256), AW-K6, AW-K7, awam rows of every founder phase molded to the awam pattern (own awam pull commands), AnexoChat, mailboxes for awam, full test pass at 390 / 820 / 1200+ with his business test account. Day plan for awam is written on 25 Nov when the founder lane closes (unless he asks earlier).

## K6 SUB-STEPS AND THE WASM KERNEL RULE (his questions 9 Nov 18:43: when does WebTransport come, in how many phases, and is the Rust/Tokio/async WASM-kernel rule (Rule 52) kept?)
K6 has FOUR sub-steps; deadline 10 Nov (his day plan 9-10 Nov):
1. **K6.1 server** (Rust, native tokio + wtransport): `server/founder/src/wt.rs`. DONE and LIVE on his server 9 Nov 18:40 (UDP 4443, journal 'WebTransport ON udp 0.0.0.0:4443', ss shows anexomail-found).
2. **K6.2 SQL** E148 + CHECK_E148. DONE 9 Nov 18:00.
3. **K6.3 CLIENT = INSIDE THE WASM KERNEL (Rule 52: Rust, async, Tokio LocalSet, WebTransport -> WASM).** NOT plain TypeScript. New kernel module (founder live over WebTransport) in `web-wasm/` on the existing `live.rs` Transport/Host/Sink traits (WebTransport object belongs to the browser, Rust drives it through the host ABI), kernel VERSION bump, new pinned wasm + SHA-256 pin, worker bridge in `founder-web/src/kernel.worker.ts`; `livefeed.ts` only asks the kernel (kernel WebTransport first, SSE fallback as today). Every frame is still verified by the kernel BEFORE it is drawn (Ed25519, pinned key). Also: the founder page CSP `connect-src` must allow exactly https://<founder host>:4443 (found by my live Chrome test 9 Nov 18:50: 'Refused to connect ... violates the document's Content Security Policy'); done in main.rs csp_for() (only when FOUNDER_WT_* is set, one exact origin).
4. **K6.4 live proof**: my Chrome on the real founder origin (hello -> ERR 401 without a token, then live frames with the session), his phone, looks 390 / 820 / 1200+. K6 is GREEN only after this.
Rule check: the server code (wt.rs) is native Rust + tokio + async, as Rule 61/52 want; it is NOT in the kernel and does not break it. The kernel is untouched until K6.3, and then the work goes INTO it (shared kernel = shared lane: awam gets the new pinned wasm through its own pull command as a separate point, the awam site does not use the new module). Where WebTransport is reused later: M (MoQ relay on top of wtransport), Q (parallel attachment chunks), N (Live Pulse).

## UPDATE 10 Nov 2026 18:47 PKT (his 10 Nov 18:47): the day column above is the LATEST allowed day, not the plan. 25 Nov = last day; target = finish as EARLY as possible for the seminar launch. Each phase is pulled forward whenever its proof is green.
