# B13 T4 COMPLETE LIST (his 25 Nov 2026 02:23 PKT order: read this list line by line, tell the gate every line, build what is NOT there from the start). Written 02:3x PKT. Gate ids: F1..F7 (features), T4-1..T4-8 (his acceptance points), T4e..T4h (the four still-open lines, built next).
ADVANCE TECHNOLOGY (Rule 52, per line): SQL = PostgreSQL 16 (state machine, forced RLS, REVOKE PUBLIC, SECURITY DEFINER fixed search_path, partial unique index, FOR UPDATE + advisory lock, CHECKs, hash-chained ledger, selftest + CHECK file); Rust = Tokio + Axum doors over HTTP/3 (TLS 1.3 AES-256-GCM, X25519MLKEM768), passkey + DBSC session; screen = React 19 + TypeScript verified by the Rust WASM kernel, same code at 390 / 820 / 1200+. RULE 52 COMBO: S=yes (signed calls) M=N/A (no mail path) L=yes (OWASP Logging, one ledger line per step).
## A. HIS 7 FEATURES (state 02:3x)
| # | Feature | Where | State |
|---|---|---|---|
| F1 | staff proposes a manual company exception: reason from a closed list + short note (200) | AD34 fadm_bind_propose, bind_exception.rs propose, screen | DONE (tested) |
| F2 | a DIFFERENT staff member approves or denies; both hold case.assign | AD34 CHECK two_people + fadm_bind_may + same_person | DONE (tested) |
| F3 | 24 h expiry; proposer may withdraw | AD34 + expiry worker + fadm_bind_withdraw | DONE (tested) |
| F4 | one open proposal per case | partial unique index fadm_bind_proposal_one_open | DONE (tested) |
| F5 | approval binds ONLY through the old writer fadm_case_bind | AD34 decide | DONE (tested) |
| F6 | every proposal, approve, deny, expiry, refusal = one ledger line, closed words | AD34 bind.* kinds, closed keys CHECK | DONE (tested) |
| F7 | staff screen shows case ref, company UUID AND NAME, reason, proposer role, time left, nothing else | desk_bind_pure.ts parsePending, DeskBindException.tsx | PARTLY: UUID, reason, role, time shown; the company NAME needs the Control Plane = T4e (OPEN) |
## B. HIS 8 ACCEPTANCE POINTS: see D6-B13-T4-ACCEPTANCE-25NOV.md (1, 2, 3, 4, 8 DONE; 5, 6, 7 each have a DONE part and an OPEN part)
## C. THE FOUR LINES THAT ARE NOT THERE YET, BUILT NEXT, IN THIS ORDER (each its own step: research line in the blueprint first, then code, tests, gate, his install, my live look)
| Step | What | Technology | Closes |
|---|---|---|---|
| T4e | Control Plane method "tenant exists": the Desk asks (signed, audience desk-tenant, 15 s, replay cache, closed shape) whether a UUID is a real company and gets back its NAME; propose is refused (no_tenant) before the database is called; the screen shows the NAME | Rust Control Plane (quinn + h3, Ed25519 workload key, RFC 9421 style signed envelope as T3b) + PostgreSQL read on the awam database (cp schema) + Desk Rust client | F7 name, T4b-2 |
| T4f | literal RFC 9421 form for browser-to-Desk calls: Signature-Input + Signature + Content-Digest (SHA-256) covering method, target-uri, content-digest, nonce, created, expires; server verifies and keeps the replay cache; the kernel (Rust WASM) builds them; the HMAC request MAC stays until both ends are proven | Rust WASM kernel + Rust Axum verifier | acceptance 7 |
| T4g | DEFINER-OWNER: a NOLOGIN, NOBYPASSRLS, least-privilege role owns the T4 doors; RLS policies let ONLY that role read the tables the doors need; later phases move the older Desk functions | PostgreSQL 16 roles + RLS policies + CHECK | acceptance 6 |
| T4h | LEDGER CHECKPOINTS: every N minutes the Desk signs (Ed25519) the ledger head (seq, hash, time) and appends it to a file OUTSIDE the database (append-only, chattr +a when the server allows), plus a verifier that compares the file to the database; off-box copy to the Hetzner Storage Box needs his credentials (his hands) | Rust Tokio worker + Ed25519 + PostgreSQL read-only head function | acceptance 5 |
