# DK = DEVICE-KEY PHASE: the Rust WASM kernel opens post-quantum mail (written 20 Nov 2026 10:15 PKT, his order 10:04)
His words: the kernel must have all of this; world-shaking code; these modules are later copied for awam Business Premium and Business Max (awam shield). Awam inherits pure modules only (AWAM-INHERITS-FOUNDER-TECH-LAW-13NOV.md); founder glue stays founder.

## WHY IT DOES NOT EXIST TODAY (checked in code, 20 Nov)
- The sealing side was built (Q1b): server/founder/src/fmail_kem.rs wraps every message key to the founder public key = ML-KEM-768 + X25519 hybrid (blob v1, 1181 bytes, HKDF-SHA256, AES-256-GCM). Its header says "decapsulation is in the kernel, not here".
- The OPENING side was never planned as a phase: no line in FOUNDER-MAILBOX-PHASES-18NOV.md or FOUNDER-MAILBOX-PLAN-12NOV.md; only a UI sentence ("arrives with the device-key phase", MailBox.tsx 124, MailView.tsx 138). The vault mode (server opens with its master key) was finished first, so mail worked and the pq open side was left behind. This is a real gap, not a QC4 bug.
- web-wasm has: sha256, hmac, ed25519, ML-DSA, merkle, envelope, rpc ... and NO mail parser, NO ML-KEM, NO X25519, NO AES-GCM.

## TECHNOLOGY (all Rust, no_std-friendly, no new vendor; BAN LIST respected)
- DK1 `mailparse@1`: RFC 5322 / MIME parse in the kernel: headers (Subject, From, To, Cc, Date, Message-ID, References max 40, Reply-To), text body, attachment list (name, type, size). Remote content NEVER loaded. Same output shape as Rust fmail_core summarize()/render(). One shared golden vector file used by BOTH the server tests and the kernel tests (parity proof). Check first: wasm size with opt-level s; pick the parser crate or a small own parser by measurement.
- DK2 `kemopen@1`: ML-KEM-768 decapsulation (fips203, no_std, no rng) + X25519 + HKDF-SHA256 (same salt/info as fmail_kem.rs kdf) + AES-256-GCM open. Byte-compatible with fmail_kem::wrap; vectors produced by the server wrap, opened by the kernel (cross-test both ways).
- DK3 device key custody: private halves (ML-KEM decapsulation key 2400 B + X25519 32 B) are made IN THE BROWSER, never leave it unwrapped; stored wrapped by the passkey (WebAuthn PRF extension when present) in IndexedDB; public half (1216 B) goes to the server through the existing key door; rotation with key id; recovery through his two hardware keys (his hands, one step at a time). Zeroize on lock. Needs the contract in tech-contracts/CURRENT.md first.
- DK4 UI: a sealed_for_kernel mail opens through the kernel RPC into the SAME read pane (no new look); Reply/Reply all/Forward work with References + Reply-To from DK1. UI law: additive only.
- DK5 proof: cargo (server + web-wasm), pure-TS, real-CSP harness, his install, my live Chrome look with one real pq mail he sends to himself, 390/820/1280.
- AWAM: DK1 + DK2 are inheritable modules (no founder names inside); awam Business Premium / Max get them through the manifest, awam files stay frozen, awam gets its own key custody glue.

## ORDER
DK1 -> DK2 -> DK3 (needs his hardware keys) -> DK4 -> DK5. One install per his rule (at most 2 subphases: DK-a = DK1+DK2 kernel + tests, DK-b = DK3+DK4 key + screen).
## STATE
PLAN WRITTEN, NO CODE YET (20 Nov 2026 10:15 PKT). Starts on his word; his earlier order put QC5/QC7/QC8/Q3 in the evening.
