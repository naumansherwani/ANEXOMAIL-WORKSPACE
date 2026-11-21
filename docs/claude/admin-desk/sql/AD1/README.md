# AD1: Admin Desk SQL, step 1 (his 21 Nov 2026 09:25: "AD 1 ka folder")

STATUS 21 Nov 2026 10:30 PKT: `../AD1.sql` is WRITTEN and TESTED on PostgreSQL 16 (run twice = idempotent, selftest passes, 8/8 CHECK rows true, desk_app sees 0 rows without a session and touches 0 public tables). It was unblocked when the Desk HTTP/3 was proven (H3CHECK OK, 09:55). NOT yet run on his server: needs his database name (read-only paste) then `admin-desk/scripts/ad-sql-run.sh <database>`.

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
