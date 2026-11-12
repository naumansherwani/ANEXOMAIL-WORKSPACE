<!--TECHLAW-->
# AWAM INHERITS THE FOUNDER'S ADVANCED TECHNOLOGY (founder word, said 10000 times, written 13 Nov 2026 00:46 PKT)
"Founder ko advance technology do, baad mein yeh awam ko bhi mile gi. Iska tareeka repo mein har jagah likho, mistake ki gunjaish nahi."
## The rule
Every advanced technology built FIRST for the founder is built so that the awam site can take it LATER, when the awam migration from Bun/Node to the advanced stack happens (after the founder blueprint is complete, awam 100% by 16 Dec 2026). Nothing is built twice. Nothing of the awam code is edited now (CORE FREEZE, docs/claude/CORE-FREEZE.json).
## How (the mechanism, one list, every phase follows it)
1. **Pure core + thin glue.** New technology goes into a PURE module (no database, no HTTP, no founder-only names): e.g. `fmail_seal.rs` (AES-256-GCM sealing, blind indexes, HKDF), `fmail_kem.rs` (ML-KEM-768 + X25519 key wrap). The founder GLUE (endpoints, gates, tables) is a separate file. The awam migration later adds its OWN glue around the SAME pure module (copy the file or `#[path]` include it). A pure module never mentions "founder".
2. **Gates and endpoints are the founder's only.** Passkey touch, DBSC session, `fmail_*` tables, `/founder/v1/*` stay founder-side. The awam gets plan limits and its own endpoints.
3. **Tests travel with the module.** Each pure module carries its own unit tests (the proof); the awam migration runs them unchanged.
4. **No awam file is touched now.** The 43 frozen awam files are guarded by rules-gate (CORE FREEZE). The awam migration is a separate, later phase that needs his word (then CORE-UNFREEZE-OK.txt).
5. **Every phase records it:** the commit, the CURRENT.md row, the ledger line and the blueprint row say "INHERITABLE BY AWAM: <module names>" so a compacted Claude (and the migration) knows exactly what can be lifted.
## Inheritable modules so far (13 Nov 2026)
| Module | What it is | Awam use later |
|---|---|---|
| server/founder/src/fmail_seal.rs | AES-256-GCM sealing with bound AAD, vault wrap, HKDF domain separation, HMAC blind indexes, subject/address normalisation | sealed at-rest mail bodies, searchable-by-equality metadata |
| server/founder/src/fmail_kem.rs | hybrid ML-KEM-768 (FIPS 203) + X25519 key wrap, 1181-byte blob v1, kernel-compatible | post-quantum recipient-key wrap for premium mail |
| docs/cursor-work/sql/E167 pattern (state machines, append-only hash-chained ledger, keyset page, chunk map, self-rolling-back selftest) | SQL design | the awam migration writes its own numbered SQL on the same patterns |
| server/rust/*_core.rs (awam, frozen) | mail/calendar/attachment pure cores | already shared by `#[path]`; the founder wraps them |
Update this table every phase. Abhi code mein NAHI: awam migration itself (after the founder blueprint).
