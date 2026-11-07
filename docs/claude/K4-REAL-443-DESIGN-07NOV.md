# K4 — AES-256 on the real :443 for the founder host (design, 7 Nov 15:20 PKT; NOTHING LIVE CHANGED, waits for his "haan")

## What his curl proved (7 Nov 14:50, on :8443)
`/` 200 html, `/_cc/` 200 html, live bundle through :8443 = 200 (strip_cc works). `/founderlogin` 404 and `/app` 404: those two paths, and `/api/*`, belong to the OLD awam-app founder login, served by Caddy (see `server/caddy/patch-founder-host.py`: only `/`, `/_cc/*`, `/founder/v1/*` go to Rust :3210). So :8443 alone is not a usable site (the SPA redirects to /founderlogin when it has no session; the session lives on the :443 origin). K4 therefore cannot just "move the port".

## Goal
Founder host on :443 negotiates TLS 1.3 AES-256-GCM-SHA384 only (Go/Caddy cannot, golang/go#29349), awam site and every other host stay on Caddy untouched.

## Design (two small pieces, each with a rollback)
1. **SNI front on :443** (decides by the TLS ClientHello server name, never decrypts): `founderworkspace.anexomail.com` -> Rust terminator (127.0.0.1:8443 style, PROXY protocol or a unix socket); every other name -> Caddy moved to an internal port (e.g. 127.0.0.1:8444). Candidate tech: Caddy layer4 plugin is NOT installed; a tiny Rust SNI router in the same binary (tokio, `rustls::server::Acceptor` to read the ClientHello, then `copy_bidirectional`) is the clean fit and keeps "Rust only on the founder server".
2. **Rust terminator proxies the Caddy-owned founder paths** (`/founderlogin`, `/app*`, `/api/*`) to Caddy's internal port for the founder host, everything else stays in Rust. A path table in Rust with a test (like `strip_cc_path`).
3. **Rollback**: one command puts Caddy back on :443 and stops the front (documented before the switch). :8443 stays as the probe (E119 prober keeps recording what the handshake really ended on).
4. SQL E119 posture ledger records host + cipher + group after the switch; CHECK proves AES-256 only on :443 for the founder host.

## Risks (why it waits for "haan")
- A mistake in the front takes down EVERY host on :443 (awam, founder). Mitigation: front is built and tested on :8444/:8445 first with a throwaway name, rollback script ready, switch done in one command while he watches.
- Certificates: the Rust terminator needs the founder host cert (Caddy owns ACME): read Caddy's cert files read-only, or let Caddy keep ACME and share the files.
- PROXY protocol / client IP for the audit ledger must be preserved.

## Steps
K4.1 DONE: `/_cc` strip on :8443 (221 tests, his curl 200).
K4.2 path-proxy table + tests (Rust), tested on :8443.  K4.3 SNI front built, tested on spare ports.  K4.4 switch with rollback ready, his "haan".  K4.5 CHECK + my Chrome at 390/820/1200+ on the real host.

## FACTS FROM HIS SERVER (read-only command, 7 Nov 14:53) — they refine the design
- Caddy v2.11.4 owns `*:80`, `*:443` (tcp) AND `443/udp` (HTTP/3). Rust owns `127.0.0.1:3210` (plain) and `0.0.0.0:8443` (own TLS, cert `/etc/anexomail/tls/founderworkspace.anexomail.com.crt`). ufw: 80, 443 tcp+udp, 3443/udp (K6 WebTransport, already open), 8443 tcp.
- FINDING 1 (renewal): the cert Rust uses is a ONE-TIME COPY made by `founder-tls256.sh` from Caddy's Let's Encrypt store. Let's Encrypt renews about every 60 days, so the copy goes STALE and the founder host would show an expired certificate. Before any live switch: an automatic refresh (systemd timer or path unit: copy when Caddy's file changes, then reload Rust's TLS config without dropping connections) + a CHECK that the served cert's notAfter is > 20 days.
- FINDING 2 (HTTP/3): `443/udp` is Caddy's QUIC. A browser that already learned `Alt-Svc: h3` for the founder host would keep using Caddy's QUIC (AES-128 first) and bypass the AES-256 terminator. Rust's answers must send `Alt-Svc: clear` for the founder host, and the CHECK must prove the cipher a real browser ends on.
- FINDING 3 (proxy): `reqwest` (rustls) is already a dependency, so the path proxy for `/founderlogin`, `/app*`, `/api/*` needs NO new crate: Caddy gets one extra plain-HTTP listener on `127.0.0.1:8081` for the founder host (same routes as today), Rust forwards those paths there.
- FINDING 4 (SNI front): SNI is read by peeking the ClientHello (pure parser + tests), no decrypt; other names are copied byte for byte to Caddy on `127.0.0.1:8444` with the PROXY protocol v1 header so Caddy still sees the real client IP.
- Updated steps: K4.2 path-proxy + Alt-Svc clear + tests (on :8443) -> K4.3 cert refresh timer -> K4.4 SNI front on spare ports -> K4.5 switch with rollback (his "haan") -> K4.6 CHECK + Chrome 390/820/1200+.
