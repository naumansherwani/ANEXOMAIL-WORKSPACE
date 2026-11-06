# J8 — dead-man vault lease, ADVANCED design (founder order 6 Nov 2026 22:17 PKT: "aur advance kero")

Goal: a stolen or lost device's vault (AnexoChat local DB, mail cache) locks itself, offline too, and copies of it become unreadable for ever once the device is revoked.

| Layer | Technology | Why this and not something simpler | Status |
|---|---|---|---|
| J8a E143 SQL | Postgres: constraints, triggers, RLS, TWO hash chains (global + per device), gapless unique serials, rate limits, clock-back guard, refusal de-dup, audit-chain link, panic lock, sweep | decision lives in the database so no code path can bypass it; ledger is tamper-evident | **GREEN 6 Nov 22:04** (his paste) |
| J8b Rust | `server/founder/src/lease.rs`: strict `lease_data`, refusal map, sweep loop; routes `POST /founder/v1/vault/lease`, `GET /founder/v1/vault/status`; Ed25519 envelope (`type vault-lease@1`) | one signing key already pinned by the browser kernel; fail-closed (bad answer = 502, never signed) | installed 6 Nov 22:17 (his paste: 215 tests, 401 without token); route proof with a real token comes with J8d |
| J8a2 E144 SQL | key split + proof of possession + crypto-shred (this file's sections 1-4) | clock-only locks can be wound back and a copied vault file stays readable; E144 makes it cryptographic | written, sandbox PASS (upgrade, fresh, rerun); NOT on his server |
| J8b2 Rust | switch the route to `founder_vault_lease_grant`; verify the ES256 device proof (ring); derive the server half = HKDF-SHA256(master from env `FOUNDER_VAULT_MASTER`, device_id \|\| half_salt); return it inside the signed lease (TLS only) | master only in Rust, salt only in SQL: neither alone can derive; revoke nulls the salt so the half is gone for everyone | written 6 Nov 23:15, 220 tests; waits his founder-install |
| J8c WASM kernel | Rule-52 kernel `lease@1`: verify Ed25519 + `type` + expiry using a MONOTONIC clock (performance.now) anchored at receipt, serial never backwards | browser checks the server; wound-back device clock cannot extend a lease | after J8b2 |
| J8d React 19 + TS + WebCrypto | non-extractable ECDSA P-256 device key (IndexedDB), DPoP-style renewal proof, half held in memory only and wiped at expiry, Settings > Privacy card (live / expired / revoked, panic lock behind T3), auto-renew ~5 min | WebCrypto non-extractable key = the stolen token alone cannot renew | after J8c |

Key schedule: vault key = HKDF-SHA256(local half (device, never leaves) , server half (released per lease, memory only)). Revoke => `shred_nonce` NULL for ever => server half underivable by anyone.

Honest limits: a thief who has the unlocked device can use the vault until the lease ends (max 15 min, shorter ttl possible); data already decrypted in memory cannot be recalled; the Postgres superuser plus the Rust master together could derive a live (not revoked) half; the 15 minute window is the price of working offline; the vault covers only AnexoChat DB + mail cache, not the phone.
Not built here on purpose: NIDD (IoT only, needs an operator contract).
