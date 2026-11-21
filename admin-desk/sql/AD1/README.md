# AD1: Admin Desk SQL, step 1 (his 21 Nov 2026 09:25: "AD 1 ka folder")

STATUS: FOLDER + PLAN ONLY. The file `AD1.sql` is NOT written yet: his HTTP/3 hard block (gate `_h3_block`, 21 Nov 09:18) refuses any `admin-desk/sql/AD*.sql` until the Desk's own HTTP/3 listener (R3a0-stage2) is in code and proven. This folder is allowed; the SQL file is not, yet.

Rules: Desk series = AD1, AD2 ... (founder and awam keep the E series). SCHEMA-FIRST LAW: before writing, read the previous schema that owns the tables (none yet: AD1 is the first Desk schema; the founder/awam E files are NEVER read from or joined to, DESK ISOLATION LAW). One file per step, one CHECK file per step in `../checks/`. Run only through a Desk runner (`ad-sql-run.sh`, written with AD1), strictly by number.

Planned content of AD1.sql (technology: PostgreSQL with ROW-LEVEL SECURITY, append-only hash-chained ledger, constraints, triggers, selftest):
- role `desk_app` (LOGIN, no BYPASSRLS, rights on `fadm_*` only, no founder/awam table, no public schema writes)
- `fadm_owner` (the Admin Desk owner; password = ARGON2ID hash, set by his command, never in chat)
- `fadm_session` (token audience `desk`, device-bound DBSC key, expiry, revoked)
- `fadm_passkey` (optional passkey credentials, rp_id admindesk.anexomail.com)
- `fadm_mailbox` (Desk mailboxes: resolved@, billing@ and noreply@ send-only, no support@)
- `fadm_ledger` (append-only, SHA-256 hash chain, UPDATE/DELETE blocked by trigger)
- RLS policies on every table, FORCE ROW LEVEL SECURITY, selftest block that fails the run on any gap
- `checks/AD1-check.sql`: read-only CHECK that prints PASS/FAIL per rule
