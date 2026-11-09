# ORDER FROM 9 NOV 2026 17:28 (local) TO 20 NOV: technology, why, what the founder gets (his order: 'tarteeb main next top pe likho kya hai technology kya hai sab details summary')

Target (his): 20 Nov 2026 founder, then business (awam), GREEN on the new technology WITH migration. Rules: founder lane and awam lane never mixed (own crate / user / env / service; the awam copy is molded from the preserved founder idea and written advanced in the awam lane, own awam pull command); no quotes in server lines; fresh `ss -lntup` before any listener (PORT RED LINE); rollback FILE before every live switch; 390 / 820 / 1200+ looks in every phase.

## DONE (WIRED: YES / REAL: YES unless noted)
- K4 GREEN: real :443 = Rust SNI front; founder host AES-256-only (rustls TLS 1.3); outside IP in the journal; E119 SQL posture ledger rows.
- K5a LIVE (9 Nov 16:56): awam WHOLE website (23 hosts) AES-256-only through its OWN program server/awam-edge (Rust, rustls + tokio-rustls) on 127.0.0.1:18081, tunnel to Caddy 18443, h2 + http/1.1; AES-128 refused; http codes equal to before; laptop OK, phone OK; awam server src == repo (610 same); compiled bundle .output/public/assets/index-Bqhlal5C.js found (= the live bundle). Open one-tap item: tablet 820 look (not blocking the next phase, he has no time: 17:28 'tu agay chalo').

## NEXT (in this order)
1. **K5b (10-11 Nov) = awam HTTP/3 with AES-256.** Tech: Rust QUIC + HTTP/3 (quinn + h3 + rustls ring, ONLY TLS13_AES_256_GCM_SHA384 for 1-RTT; RFC 9001 makes the first Initial packet AES-128 by design, nothing can change that), inside the awam-edge crate (awam lane), on a FRESH UDP port proven by fresh ss, requests forwarded to Caddy 18443 over loopback. Why: HTTP/3 must stay ON and AES-256 no compromise (his 15:39). Caddy's own h3 (Go cannot restrict TLS 1.3 suites) keeps running until our h3 is proven; Alt-Svc moves only after the proof, rollback file first. He gets: the whole awam site on HTTP/3 + AES-256.
2. **K6 (12-14 Nov) = Rust WebTransport/QUIC for the founder live channel** (wtransport, own fresh UDP port, AES-256 pinned, shares the QUIC learnings of K5b). He gets: live founder dashboard events over QUIC, no polling.
3. **K7 (15-16 Nov) = DBSC (Device Bound Session Credentials)**: the founder session cookie is bound to the device key (TPM) so a stolen cookie is useless; Rust start/refresh endpoints + SQL ledger; awam copy molded afterwards.
4. **Awam migration (17-19 Nov):** AW-G, AW-K5, AW-K6, AW-K7 molded into the awam lane, each with its own awam pull command and the 390/820/1200+ looks with his business test account.
5. **20 Nov:** final check, every line WIRED: YES / REAL: YES.
Outside this window: L..V (mailbox engine Q, MoQ M), AnexoSuite last.

## Side gaps (not caused by K5, on the open list)
9 hosts return 502 before and after (admin auth docs preview runtime sandbox settings status storage); pm2 anexomail-web restarts=500 (counter, check if it flaps); tablet 820 look; email question 1 or 2 (default keep order).
