# SQL SCHEMA-FIRST LAW (founder 20 Nov 2026 20:35 PKT, STRICT, founder AND awam)

Before ANY new SQL file is written, in ANY folder of the repo:
1. READ the previous SQL that owns the tables/functions you will touch (docs/cursor-work/sql/index.md tells which E-file; read the schema it created: tables, columns, constraints, triggers, RLS, the closed action lists of the ledger E167/E185/E194 and the change log E187/E190, door audit E179).
2. PUT that schema in front of you (list tables, columns, functions, closed lists) in your notes.
3. THEN write the new SQL ON TOP of it: reuse the ledger door, the live change log and the door audit; never a parallel copy, never a rename of what exists.
4. A new SQL file is advance level (constraints, triggers, hash-chains, RLS, selftest rolling back, CHECK file), first line empty (lint), next free number from docs/cursor-work/sql/index.md.
Applies to founder and awam alike. Proof that it was done: the new file's header comment says what it was built on (as E196 does).
