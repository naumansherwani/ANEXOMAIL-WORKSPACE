# SQL WORLD-CLASS LAW (Chairman Nauman Sherwani, 23 Nov 2026 06:01 PKT, STRICT, EVERY SQL of the whole website)
His word: "agar sql jab bhi aye gate ko bata do, sab jagah locked kero. Duniya ka advance sql likhna hai hamesha, beshak yeh founder side account ka ho ya users/awam side ka. Yeh rule gate walay rule sari website ke liye hain. Web research pehle, phir list rows, ADVANCE-RESEARCH line, CURRENT.md: woh intact rahay, bus us main add kero ke yeh awam aur founder pe bhi apply hoga Claude ke uper."
APPLIES TO: founder (docs/cursor-work/sql E-series), awam/user, Admin Desk (docs/claude/admin-desk/sql AD-series), shared. No folder is outside it.
ORDER OF EVERY SQL (founder, awam AND Desk; the RESEARCH-IN-BLUEPRINT order stays exactly as written in docs/claude/admin-desk/RESEARCH-IN-BLUEPRINT-LAW-23NOV.md, this law adds SQL on top):
1 web research -> 2 points in the phase LIST file -> 3 line ADVANCE-RESEARCH [phase] in the blueprint AND NOW-LIST (Desk) or the founder/awam blueprint -> 4 CURRENT.md contract block (rows all IN CODE) -> 5 READ the older SQL that owns the tables (SQL-SCHEMA-FIRST-LAW-20NOV.md, index.md, E-series / AD-series) -> 6 write the SQL on top, advance level -> 7 selftest + CHECK file -> 8 tests -> 9 his one install line -> 10 my Chrome look -> GREEN.
GATE (rules-gate.py "SQL WORLD-CLASS", runs on every NEW .sql file staged anywhere except lovable-gold, backups, the synced admin-desk copy, CHECK files): first 60 lines must hold
  -- SCHEMA-FIRST: <the older SQL files read>
  -- ADVANCE-RESEARCH: [<phase>] <what the web research gave this SQL>
  -- CHECK-FILE: <path of an existing CHECK file>
and the body must have: a selftest that rolls back (raised + caught custom SQLSTATE, or ROLLBACK); FORCE ROW LEVEL SECURITY for every CREATE TABLE; a fixed SET search_path for SECURITY DEFINER; REVOKE ... FROM PUBLIC for created functions. Negative probe (fails, 5 reasons) and positive probe (passes) tested 23 Nov 06:0x.
Advance level means: constraints, triggers, append-only ledgers with hash chains where history matters, forced RLS, closed lists, selftests, CHECK file, numbers in order (never reuse a number).
Existing SQL files are not touched by the gate; any new file after 23 Nov 2026 06:01 is.
