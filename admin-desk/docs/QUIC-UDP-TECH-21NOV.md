# ADMIN DESK: QUIC / UDP ADVANCED TECHNOLOGY, ALL OF IT (his 21 Nov 2026 09:52: "quic udp jitne bhi advance technology sab likho")
Rule: a listed technology missing from the code is an OPEN GAP, never green. CODE rows are enforced on every commit by the Desk gate (admin-desk/gates/DESK-FEATURES.json, markers in admin-desk/server/src/h3.rs). Transport is HTTP/3 only; HTTP/1 and HTTP/2 are banned.
Status 21 Nov 09:58 PKT: in code and tested on the build machine (loopback PQ handshake test); LISTENING on his server (UDP 4400); the over-the-wire proof (`anexomail-desk h3check`) is still to be pasted by him.

| Technology | What it gives the Desk | State | Gate row |
|---|---|---|---|
| QUIC transport (RFC 9000), Rust quinn 0.11 on Tokio, UDP 4400 | one encrypted multiplexed connection, no head-of-line blocking | CODE | QUIC-core |
| HTTP/3 (RFC 9114) + QPACK (RFC 9204), ALPN `h3` only | the only HTTP the Desk speaks | CODE | QUIC-h3 |
| TLS 1.3 in QUIC (RFC 9001), ONE cipher suite TLS_AES_256_GCM_SHA384 | AES-256-GCM only, no AES-128, no ChaCha | CODE | QUIC-tls |
| X25519MLKEM768 hybrid key exchange (ML-KEM-768, FIPS 203) FIRST | post-quantum key exchange on every connection | CODE | QUIC-pq |
| QUIC Retry address validation under flood | no spoofed-source amplification | CODE | QUIC-retry |
| Connection migration (RFC 9000 s9) ON | Wi-Fi to mobile data keeps the session | CODE | QUIC-migration |
| 0-RTT OFF (max_early_data_size = 0) | no replayable early data | CODE | QUIC-no0rtt |
| BBR congestion control | steady speed on lossy mobile links | CODE | QUIC-bbr |
| Alt-Svc (1 year, persist) + host check 421 | browsers return to the Desk's own port; wrong host refused | CODE | QUIC-altsvc |
| Own proof client `h3check` (PQ + AES-256 only) | proves the handshake really used both | CODE | QUIC-selfcheck |
| Built into quinn (no extra code, on by default): UDP GSO/GRO batching, ECN, DPLPMTUD path-MTU discovery, stateless reset, loss detection (RFC 9002), spin-bit off | fast and safe on the wire | CODE (quinn) | (library) |
| DNS HTTPS record (RFC 9460) `1 . alpn="h3" port=4400` + AAAA | browser goes straight to QUIC on the Desk's own port | HIS HANDS, Namecheap | not in code |
| QUIC DATAGRAM (RFC 9221) + WebTransport (Rule 52 kernel RPC over QUIC) | live Desk events without polling | PLANNED, fail 5 Dec | QUIC-datagram |
| Media over QUIC (MoQ) | live voice / updates, later phase | PLANNED, fail 20 Dec | QUIC-moq |
| QUIC version 2 (RFC 9369) | ossification-proof wire image | PLANNED, fail 10 Jan 2027 | QUIC-v2 |
| Encrypted Client Hello (ECH) | hides the host name in the handshake | PLANNED, fail 10 Jan 2027 | QUIC-ech |
