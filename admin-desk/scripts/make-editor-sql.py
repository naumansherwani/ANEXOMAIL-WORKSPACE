#!/usr/bin/env python3
"""Builds admin-desk/sql/AD1-editor.sql = a header + AD1.sql + the AD1 CHECK query, for pasting into a SQL EDITOR (his 21 Nov 10:26 word: "main sql editor main run kerun ga").
The hosted editor shows only the LAST statement's result, so the CHECK table comes last: every row must say true. Regenerate after any change of AD1.sql (the Desk gate fails if it is stale)."""
import os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def build():
    a = open(os.path.join(ROOT, "sql/AD1.sql"), encoding="utf-8").read()
    c = open(os.path.join(ROOT, "sql/checks/AD1-check.sql"), encoding="utf-8").read()
    h = ("-- ADMIN DESK AD1 for a SQL EDITOR (paste ALL of this and press Run ONCE). Generated from AD1.sql + checks/AD1-check.sql by scripts/make-editor-sql.py, do not edit by hand.\n"
         "-- It needs NO superuser. It is ONE transaction: any failure rolls EVERYTHING back (nothing half-made). Re-running is safe.\n"
         "-- WHAT YOU MUST SEE AT THE END: a table with 8 rows, every row ok = true. Any false or any error: send me the text, do not run anything else.\n"
         "-- It creates ONLY: schema `desk`, role `desk_app`, five tables fadm_*. It touches no founder and no awam table.\n\n")
    return h + a.rstrip("\n") + "\n\n-- ===== CHECK (read-only): all 8 rows must be true =====\n" + c
if __name__ == "__main__":
    out = os.path.join(ROOT, "sql/AD1-editor.sql")
    if len(sys.argv) > 1 and sys.argv[1] == "check": sys.exit(0 if os.path.exists(out) and open(out, encoding="utf-8").read() == build() else 1)
    open(out, "w", encoding="utf-8").write(build()); print("wrote", out)
