# QUI-H4 ACTION PLAN (written 15 Nov 2026 21:0x PKT, his order: "advance technology pe codes likho, action plan likho, phir execute")
GOAL: for ONE mail, the browser kernel proves (not the server) that the mail's ledger row is inside the founder audit Merkle tree.
CHAIN OF PROOF (all checked in the WASM kernel): mail ledger row (fmail-ledger-v1, kernel mailledger@1) -> its anchor row in founder_audit (E167 writes meta {fmail_seq, fmail_hash} with audit_seq) -> founder_audit row hash re-computed with the E102 formula (_fa_hash, 4-byte big-endian length prefix) -> RFC 6962 inclusion path (E107 founder_audit_merkle_proof, kernel merkle_core.rs verify) -> the root.
HONEST LIMIT: this step proves "row is in the tree with this root". That the root is signed by the audit key is the existing checkpoint verify (kernel line "checkpoint note"); wiring it into this chip is a later step and the report says root_signed=false until then.
SQL NUMBER: E173 = this phase door (like E172 was for H3). QPERF moves to E174, calendar to E175-E176.
STEPS (one at a time, each closes with proof):
1. E173 + CHECK_E173 (door fmail_anchor_proof173(mailbox, message), service_role only, stable, tamper-tested in sandbox)  [PostgreSQL RLS door, E107 proof reuse]
2. kernel module auditproof@1 in web-wasm/src/auditproof.rs (+ tests with a vector made by the real SQL), kernel 0.17.0 via scripts/build-kernel.sh + kernel-sync.sh  [Rust WASM kernel SHA-256 + RFC 6962]
3. Rust door /founder/v1/mail/anchor-proof in fmail_ep.rs + main.rs (closed-list query, signed answer)  [Rust Tokio/Axum, WebTransport RPC]
4. UI: proofChip in MailView uses the kernel report ("anchored in audit tree, checked in your browser")  [React 19 TS]
5. rec.sh, then HIS lines: 1 sql-run (AUTO) 2 founder-install; separate awam pull for kernel 0.17.0; then my Chrome look; then qstate done.
