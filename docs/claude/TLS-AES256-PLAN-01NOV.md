# TLS AES-256 FOR FOUNDER + AWAM — plan (1 Nov 2026 14:55 PKT; founder 14:24/14:28: "256 hoga har keemat pe", "founder aur awam dono ko advance 256 bit tls do")
## What is true today (server, founder pastes 14:19-14:28)
- Both hosts: TLS 1.3, certificate OK, **post-quantum hybrid X25519MLKEM768 negotiated** (Caddy built with go1.26.3, v2.11.4).
- Both hosts CAN do `TLS_AES_256_GCM_SHA384` (when the client offers only it). A normal browser still gets `TLS_AES_128_GCM_SHA256` because Go's TLS 1.3 suite order is fixed and not configurable (golang/go#29349).
- So the missing piece is only: make every client land on AES-256. Not possible inside Caddy; needs a TLS terminator we configure.
## Honest notes
- QUIC / HTTP/3: the Initial packets are always protected with AES-128-GCM keys derived from public values (RFC 9001); that is by design and carries no secret. The negotiated session suite after the handshake can be AES-256-GCM. Wording to use: "TLS 1.3 · AES-256-GCM · post-quantum hybrid key exchange (X25519MLKEM768)" ONLY after it is proven per host, never before.
- AES-128 is not broken; 256 is the founder's decision (compliance wording, margin).
## Phases (one at a time, Rule 66; nothing touches the live edge until the test port is proven in his Chrome)
| Phase | What | Layer | Proof |
|---|---|---|---|
| T256-0 | Read-only inventory on the server: who owns 80/443/8443/UDP 443/3443, is HAProxy installed (and its OpenSSL), where Caddy keeps the certificates | server check | his paste |
| T256-1 | **Founder host first:** a TLS 256-only terminator on test port 8443 for founderworkspace.anexomail.com (design A: Rust `rustls`, only AES-256-GCM, inside the founder binary together with 7a; design B: HAProxy with OpenSSL 3.5.5 `ssl-default-bind-ciphersuites TLS_AES_256_GCM_SHA384`). Chosen from T256-0. Live 443 untouched | Rust or proxy | `openssl s_client -connect host:8443` shows AES_256 with a normal client; Chrome DevTools > Security shows AES_256_GCM |
| T256-2 | Same for the awam host anexomail.com on 8443, only after T256-1 is green; awam site never goes down (Caddy keeps 443) | proxy | same |
| T256-3 | Switch 443 per host, one host at a time: backup config, validate, switch, 1-minute rollback ready | server | both checks again + site loads |
| T256-4 | UDP side: HTTP/3 (443) and awam WebTransport (3443) restricted to AES-256 session suite where the library allows it; document what cannot be | Rust + proxy | openssl/curl --http3 check |
| T256-5 | Footer / splash wording updated to the proven sentence only | React | `tech-proof.py` row + live Chrome |
Rule: no step runs on awam without his written "haan" for that step. This plan changes no code.
