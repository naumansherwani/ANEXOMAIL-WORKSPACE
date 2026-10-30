# FOUNDER PROTOCOL — FINAL LOCKED DESIGN (founder hukm 28 Oct 06:49: "final faisla kero, mistake hui to dobara code nahi")
Host: `founderworkspace.anexomail.com`. Yeh host KABHI awam se connected nahi tha/hoga — protocol ka ghar. Is file ka har faisla LOCKED: badalna sirf founder ke likhit hukm se. Code isi ke mutabiq, ek baar.

## 0. Isolation (end-state, F9)
- Founder host ke Caddy block mein SIRF Rust `anexomail-founder` (127.0.0.1:3210). Bun (:3000/:3100/:3300), Rust awam (:3200), Polar kuch nahi.
- Founder session/token awam API par kabhi nahi chalta, awam token founder par kabhi nahi (alag JWT audience `aud=anexo-founder`, alag issuer-check).
- Founder ke liye awam org/mail_account banana band (FX-14). Founder login = sirf `/founder/v1/login`.
- Transition (F9 se pehle): purana awam-app usi host par `/app`,`/api` par — NAYA kuch usse nahi judta; F9 mein hat jata hai. Yeh sirf waqt ka samjhauta hai.

## 1. Crypto — kaun kya kaam karta hai (GALAT jagah galat primitive = bug, isliye yeh table LOCKED)
| Kaam | Primitive | Kahan | Wajah |
|---|---|---|---|
| Server -> browser response ki asliyat | **Ed25519 signature** (asymmetric) | Rust sign, **WASM verify** | HMAC symmetric hai: key browser mein ho to jo browser mein hai wohi nakli data bana sakta hai. Public key browser mein theek hai. (Purana "HMAC envelope" sirf server-side tha — browser verify ke liye Ed25519; HMAC ab doosre kaam ke liye.) |
| Browser -> server request integrity + replay | **HMAC-SHA256** per-session key | WASM sign, Rust verify | key HKDF se login par bani, sirf WASM memory mein |
| Session key derivation | **HKDF-SHA256** (RFC 5869) | Rust + WASM | login secret + server nonce + device id se; key kabhi storage mein nahi |
| Audit chain / Merkle | **SHA-256** | DB(pgcrypto), Rust, WASM | E102 chain v1, Merkle RFC 6962 (leaf 0x00, node 0x01) |
| SPA / WASM integrity | **SHA-256 SRI** + signed asset manifest | build, browser | kernel `.wasm` ka hash index.html mein pinned; badla to boot band |
| Login | **WebAuthn passkey** (ES256), UV required | browser/Rust | ek baar per device, phir popup nahi (PROTOCOL §2b) |
| Token | ES256 JWT, `aud=anexo-founder`, TTL 15 min, memory mein, refresh rotate | Rust jwt_core | localStorage kabhi nahi |
| Transport | TLS1.3 (Caddy) ; WebTransport/QUIC primary, fetch fallback | | |
| Compare | constant-time (`subtle`) | Rust/WASM | timing leak band |
Koi apna crypto nahi: sirf audited crates — `ring`/`ed25519-dalek`, `hmac`, `sha2`, `hkdf`, `subtle`, `webauthn-rs`. `#![forbid(unsafe_code)]` kernel mein.

## 2. Envelope (canonicalisation ki ghalti se bachne ke liye BYTES sign hote hain, JSON nahi)
`{ v:1, kid, payload_b64, sig_b64 }` — sig = Ed25519( "anexo-founder/v1|" || ctx || "|" || host || "|" || ts_ms || "|" || seq || "|" || payload_bytes ).
- ctx = endpoint ka naam (domain separation: bridge ka sig audit par nahi chalta).
- Pehle verify, PHIR parse. Verify fail = UI "TAMPERED", data render nahi.
- Replay: ts window ±30s + seq monotonic per session; request nonce echo.
- Key rotation: `kid`; browser mein pinned public keys ki list (kernel ke andar), purani 2 tak.

## 3. WASM kernel (CORRECTED 30 Oct: ek hi kernel `web-wasm/`, Rule 52 — alag `server/founder-kernel` crate NAHI; naye modules ed25519@1 + envelope@1, v0.5.0)
API: `sha256`, `hmac256`, `hkdf`, `ed25519_verify`, `verify_envelope`, `sign_request`, `audit_chain_verify`, `merkle_verify`, `ct_eq`, `sniff`. Koi network/DOM nahi — pure functions. Browser mein Worker mein chalta hai. `ANEXO_TAG_MODE=enforce` (Rule 52): kernel ready na ho / verify fail = data dikhta hi nahi (warn-mode nahi).
Tests (sab lazmi, jab tak sab pass nahi push nahi): RFC 8032 (Ed25519), RFC 4231 (HMAC), NIST SHA-256, RFC 5869 (HKDF), RFC 6962 Merkle vectors; Rust-sign -> WASM-verify cross test (node + Playwright); tamper (1 bit), replay, wrong ctx, wrong host, wrong kid, truncated; fuzz (cargo-fuzz) envelope parser.

## 4. Browser hardening
CSP strict (`default-src 'none'`, script-src 'self' 'wasm-unsafe-eval', Trusted Types `require-trusted-types-for 'script'`), COOP/COEP, `frame-ancestors 'none'`, SRI, no inline script/style, no third-party origin (fonts bhi self-hosted), no localStorage/sessionStorage secrets, Permissions-Policy band, no-store.

## 5. Server hardening
Rust memory-safe, `forbid(unsafe_code)`; systemd sandbox (already); secrets sirf `/etc/anexomail/founder.env` 0600; signing private key alag file 0400 (DB mein kabhi nahi); rate limit + lockout (login.rs); IP allowlist (Rust layer + Caddy, F1a); device approval (founder_devices); har write `founder_audit` hash-chain; Merkle root daily signed checkpoint (V1); `cargo audit` + `cargo deny` CI; reproducible build (locked Cargo.lock, vendored hash); dependency pin.

## 6. Phase tarteeb (LOCKED, ek waqt ek, Rule 64)
F0 live (/f/ Chrome) -> F1a login+passkey+device approval+allowlist -> F2a Ed25519 server signing + request HMAC + HKDF -> F2b WASM kernel verify (enforce) + SRI -> F2c audit alignment (v1 format) + Merkle -> F3.. features. Har phase ka exit = tests + server + Chrome.

## 7. Jo galti ka khatra tha, ab band
(1) HMAC key browser mein -> Ed25519. (2) JSON canonicalisation -> bytes sign. (3) apna crypto -> audited crates. (4) kernel warn-mode -> enforce. (5) token storage -> memory. (6) ek hi primitive sab jagah -> table. (7) awam se mix -> end-state host sirf Rust.
