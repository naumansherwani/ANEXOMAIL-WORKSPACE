# D5a-4 LOOKUP AUDIT PROOF: the point list (written FIRST, his order 23 Nov 2026 00:56 PKT)

His word: "yeh sab se sensitive hai ... points likho, test live kero, duniya ka advance, sql maximum lines". List first, then code. File of code: `sql/AD4b.sql` (+ `sql/checks/AD4b-check.sql`), built ON TOP of AD1..AD4 (schema-first law read: AD4 `fadm_lookup`, `fadm_lookup_begin/finish/history`). Numbering: AD9/AD10 stay for runbooks and escalate, this is AD4b (same style as AD1b, AD6b).

## Web research (23 Nov 2026) and what each source gave
| Source idea | Point taken |
|---|---|
| Tamper-evident logging (hash chain, fixed genesis) | P1 per-lookup SHA-256 chain, length-prefixed canonical encoding |
| RFC 6962 / RFC 9162 Merkle trees (inclusion + consistency proofs) | P3 Merkle checkpoints, P4 inclusion proof per lookup |
| AWS CloudTrail digest files chained to the previous digest | P3 checkpoint hash includes the previous checkpoint hash |
| Separation of duties, INSERT-only application role | P9 nobody reads his own audit; desk_app has EXECUTE only |
| Write the audit line BEFORE the action (same transaction) | already AD4; P6 proves no data path without a request line |
| Completeness (gaps, idempotency, orphan requests) | P5 contiguous seq, orphan sweep, 'abandoned' result |
| Insider-threat analytics (bulk viewing, repeat, off-hours, probing) | P7 five live signals feeding the alert centre |
| Logging access to the log itself | P8 reading history / proof is itself a ledger line |
| Server-side UTC time, out-of-order detection | P2 monotonic `linked_at` under lock |

## The points (status column is honest; "planned" until the test line below it says passed)
| # | Point | Advance technology | Where |
|---|---|---|---|
| P1 | Every lookup row gets ONE chain link: seq, prev_hash, hash = sha256(prev ‖ length-prefixed row fields). Genesis fixed. Links are append-only, RLS forced, no desk_app right. Rows already on his server are back-filled in id order. | PostgreSQL trigger + advisory xact lock, SHA-256 | AD4b |
| P2 | Link time is the database clock under the lock and can never go backwards (monotonic `linked_at`). The app cannot choose a time. | clock_timestamp(), monotonic guard | AD4b |
| P3 | Checkpoints: cumulative Merkle root (RFC 6962 leaf 0x00 / node 0x01) over all links so far, chained to the previous checkpoint hash. Sealed by the owner, or automatically when 25 new links or 1 hour. | RFC 6962 in SQL, hash-chained digests | AD4b |
| P4 | Inclusion proof for any one lookup (path of sibling hashes) and a verifier that recomputes the root. Export of proof is owner-only and logged. | RFC 6962 audit path | AD4b |
| P5 | Completeness: seq contiguous, link count = lookup count, orphan requests (no result after 120 s) are closed as 'abandoned' by a sweep (no data was ever shown for them) and raise an alert. | sweep, closed outcome list | AD4b |
| P6 | Reason quality: at least 3 words, at least 2 distinct words, a blocklist (test, asdf, checking ...), no repeated-character filler. Sensitive fields (suspension, payment-flag flavour) need 25+ characters and 4+ words. | closed blocklist table, per-field sensitivity | AD4b |
| P7 | Five live signals on every request: many companies in an hour (bulk), same company again and again, after hours (Karachi), probing (many refused/unavailable), copy-paste reason, plus daily total. Alerts are de-duplicated; thresholds live in a table changed only by an admin door that logs. | alert centre (AD3), threshold table | AD4b |
| P8 | Self-audit: reading history, a person's lookups, or a proof is itself a ledger line (who read what). | ledger kinds | AD4b |
| P9 | Separation of duties: nobody can read his OWN lookups or proofs (even an owner); history needs audit.read. | policy + door check | AD4b |
| P10 | Maintenance without a scheduler: every begin and the health door run `fadm_lookup_maintain()` at most once a minute (sweep + auto seal). | try-advisory-lock, state row | AD4b |
| P11 | Health door for the Bridge: counts only (links, chain ok, last checkpoint age, orphans, signals 24 h). No company, no reason. | SECURITY DEFINER jsonb | AD4b |
| P12 | Retention: NO purge door exists; nothing is ever deleted, not even by the owner (a decision, written, tested: delete/update/truncate refused on rows, links, checkpoints). | append-only guards | AD4b |
| P13 | Concurrency proof: parallel sessions keep ONE valid chain with no gap. | live parallel psql test | test script |
| P14 | Upgrade proof: AD1..AD4 database (as on his server) + AD4b = CHECK all true; second run = nothing changes (idempotent). | scratch DB `anexo_up4` | test |

## Honest limits (written, not hidden)
1. The chain proves nothing was changed or removed INSIDE the database. A superuser who rewrites the whole table AND all later hashes is only caught if a checkpoint was copied OUTSIDE. Next phase (planned, his haan not needed, no new vendor): the Desk Rust signs each checkpoint hash with its Ed25519 key and stores the copy on his Hetzner Storage Box.
2. 'abandoned' means no answer reached the screen; it does not prove the customer data was not computed by the Control Plane (the Control Plane keeps its own refusal log).
3. After-hours window is Karachi time (07:00-23:00 allowed) until the Desk has per-person time zones.

## STATUS 23 Nov 2026 01:2x PKT (honest)
P1-P12 written in sql/AD4b.sql and PASSED the selftest on three scratch databases (fresh order AD1..AD8, new AD8, upgrade DB with 11 old rows). P13 (8 parallel sessions, 64 links, no gap, chain true) PASSED. P14 PASSED (second run changes nothing, CHECK 21/21 on all three).
Rust doors (health, verify, seal, proof) written, compiled, 51 tests pass; NOT yet called on his server. Not built: the screen (1j), the signed outside copy (limit 1).
Found while testing: AD8 left two trigger functions executable by PUBLIC (AD3 CHECK caught it); fixed in AD8.sql.
Design note: automatic seal runs at most once a minute and only when a lookup or the health door runs, so a burst of lookups inside one minute is sealed by the next maintenance run (parallel test: 64 links, 0 checkpoints right after the burst, by design).

## UPDATE 23 Nov 2026 01:3x PKT: honest limit 1 is now CLOSED IN CODE (his order 01:18)
P15 Outside copy: audit.rs signs each checkpoint with the Desk key and writes one file per checkpoint to /var/lib/anexomail-desk-audit AND /mnt/anexomail-box/desk-audit (his existing sshfs Storage Box mount, no new password or key); every run compares ALL older files with the database (TAMPER = ledger line, high alert, exit 3); `anexomail-desk audit-verify <folder>` checks signatures and chain with NO database. Timer every 10 minutes, heartbeat door fadm_lookup_tick so a quiet day's last links are sealed too.
Tested: the real compiled binary against a scratch PostgreSQL (6 files, rerun 0 new, tamper exit 3 with ledger line and alert), 7 pure tests, 1 PostgreSQL test, unit file through systemd-analyze. NOT yet run on his server (installer step 8/8 of desk-install).
Rule added by him: docs/claude/AUDIT-BEFORE-INSTALL-LAW-23NOV.md.
