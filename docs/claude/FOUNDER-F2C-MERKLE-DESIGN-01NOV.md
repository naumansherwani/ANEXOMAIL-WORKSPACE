# F2c — Audit Merkle (E107) — design note (master order step 5, founder order 1 Nov 08:11)

Master order: `FOUNDER-MASTER-ORDER-28OCT.md` step 5. Nothing is inserted before or after it. This note is Rule 63's "design first".

## What exists (do not rebuild)
- E102: `founder_audit` (seq, hash, prev_hash, append-only trigger), `founder_audit_append`, `founder_audit_verify`, `founder_audit_head`. Hash v1 = sha256 of length-prefixed fields.
- Rust `audit.rs`: chain + HMAC. WASM kernel `web-wasm/`: `hash.rs`, `ed.rs` (verify), no Merkle yet.

## What F2c adds
1. **SQL E107 (>=800 lines, + CHECK_E107):** `founder_audit_merkle_root(p_from,p_to)`, `founder_audit_merkle_proof(p_seq)` (inclusion path), `founder_audit_checkpoint` (append-only table of signed roots per N rows, hash-chained), `founder_audit_export(p_from,p_to)` (rows + root + proof set), selftest. RLS on, service_role only, pinned search_path.
2. **Tree rule (RFC 6962 style):** leaf = sha256(0x00 || row_hash bytes), node = sha256(0x01 || left || right); odd node promoted, not duplicated (no second-preimage ambiguity).
3. **Rust:** `merkle.rs` (same rule, tests incl. tamper, odd sizes, proof round-trip), routes `/founder/v1/audit/root`, `/audit/proof/:seq`, `/audit/export` (read-only, Ed25519-signed envelope).
4. **WASM kernel `merkle` (Rule 52, one kernel):** verify inclusion proof + root signature in the browser; cargo tests, no JS test runner.
5. **UI:** Dashboard "Ledger Integrity Gauge" (live numbers: rows, last checkpoint, proof verified in this browser) and Audit ledger page row "Verify this entry".
6. **Done = green:** E107 CHECK all OK on server, `cargo test` pass, Chrome shows gauge with a real verified root.

## Out of scope here
S2 (step 6), passkey (7), Decide (8). Mail/People/Systems etc. follow in master-order sequence after step 5 (steps 9–13).

## Order of work
SQL E107 + CHECK -> Rust merkle.rs -> kernel merkle -> UI gauge -> pull commands (sql-run.sh first, then founder-install.sh).
