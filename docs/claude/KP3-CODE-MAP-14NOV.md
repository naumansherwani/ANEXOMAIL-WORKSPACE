# KP3 CODE MAP AND AUDIT (14 Nov 2026 05:20 PKT) - READ THIS BEFORE WRITING ANY WEBTRANSPORT / HTTP3 / LIVE-FEED CODE. IT ALL EXISTS. DO NOT REWRITE IT.

Founder's question 05:15: "did you remove Rust? can Rust, WebTransport and async Tokio not run together?" ANSWER: NOTHING of Rust, Tokio, axum, quinn, h3, h3-webtransport or WebTransport was removed. Step 5 removes ONE thing only: the SECOND, separate listener on UDP 4443 (the old `wtransport` crate endpoint). WebTransport itself runs on UDP 443 inside the HTTP/3 endpoint (h3.rs, `enable_webtransport(true)`), same origin, same Tokio runtime, same quinn.

## Server (Rust, tokio, axum 0.8, quinn, h3 0.0.8, h3-webtransport 0.1.2), server/founder/src
- h3.rs (249 lines, 6 tests): HTTP/3 on UDP 443, ALPN h3 only, Retry when handshakes in flight >= 32, WebTransport enabled on the same endpoint (/wt/live, /wt/rpc), Alt-Svc.
- wt.rs (414 lines): the SHARED session code (live_session, count_session, Active slots MAX 64, origin_ok, PATH, RPC_PATH, quic_config_n idle 30 s / keep-alive 10 s / migration true). The old UDP 4443 listener functions (endpoint, from_env, serve, one_session, quic_config) are now #[cfg(test)] only (KP3 step 5 step 2).
- wtrpc.rs (197 lines): kernel RPC over a WebTransport stream; only /founder/v1/ paths (so /healthz is refused), never live/stream, dbsc start/refresh.
- tls256.rs (536 lines): TLS 1.3, AES-256-GCM only, X25519MLKEM768, CertStore hot-reload; tcp_closed = TCP 443 accepts then drops (proven on his server 14 Nov 04:02, receipt 22: TLS alert access_denied).
- main.rs: csp() = connect-src 'self' ONLY (step 5 step 1); no SSE routes (deleted 4b); live_stream_core is used ONLY by the WebTransport handlers.
- Env that UDP 443 really uses: FOUNDER_H3_ADDR, FOUNDER_H3_HOST, FOUNDER_H3_WT (off = rollback), FOUNDER_TLS256_*. FOUNDER_WT_* is IGNORED now.
## Browser (React 19 + TypeScript, Rust WASM kernel flive@1 + rpc@1), founder-web/src
- kernel.host.ts (the thin host shim: OP table, EMIT kinds 6-12, pre-connect, 8 s handshake timer, measured RTT), kernel.worker.ts, kernel.ts (routes kinds 9-12 to pathhealth).
- pathhealth.ts + pathprobe.ts: the honest "QUIC path" chip (probe = GET /founder/v1/keys every 15 s). livefeed.ts: WebTransport only, polling every 15 s after 3 fails, "Retry now". mail_api.ts live(): signed GETs counts+lanes every 5 s. livemerge.ts: LiveEvent merge + backoff only.
- NO SSE anywhere, NO WebSocket, NO Bun/Node on his server.
## Status of KP3 (his server facts: receipts 21, 22, 23 in docs/claude/state/SERVER-FIRST.jsonl)
- GREEN on his server: K8e, steps 1, 2, 3, 4, 4b (his install 04:20 + my live Chrome: both SSE routes 404, chip QUIC 178 ms, 0 requests to :4443; his phone screenshots 04:21).
- STEP 5 (remove UDP 4443), 6 steps, ONE AT A TIME by his order: 1 CSP DONE (e0e73ec9), 2 listener DONE (a523a16b), 3 installers (founder-wt-off.sh, delete founder-wt.sh + founder-wt-proof.sh, ports-audit) NEXT, 4 build + all tests, 5 his ONE install + ss paste, 6 my live Chrome then GREEN.
- His server still has: udp 4443 listener (old binary), FOUNDER_WT_* x4 in /etc/anexomail/founder.env, ufw 4443/udp v4+v6.
## Rules that cost hours (do not repeat): never ask "commit kero?" (commit+push myself); 0.1% doubt about his server = one read-only command, never a guess; build AND run all tests before giving an install command; never state "TCP closed" (it is accept-and-drop); one step at a time, next step only after the previous is accepted.
