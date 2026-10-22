#!/usr/bin/env python3
"""Rule 42: har SQL file server (psql, sql-run.sh) AUR Supabase editor (paste) dono mein chale.
Usage: python3 docs/cursor-work/server/sql-editor-lint.py docs/cursor-work/sql/E63_event_goal.sql [...]
Exit 1 agar koi file editor/psql mein alag chalegi. Checks:
  1. pehli line khali (editor paste pehla character kha sakta hai)
  2. koi psql meta-command nahi (\\set \\echo \\gset \\i ... editor mein syntax error)
  3. CONCURRENTLY / VACUUM / ALTER SYSTEM / CREATE DATABASE nahi (editor transaction mein chalata hai)
  4. nayi file mein apna BEGIN/COMMIT nahi (proofs/ ke bahar) — editor/sql-run khud sambhalte hain
  5. CHECK_*.sql: ek hi SELECT (editor sirf aakhri result dikhata hai)
"""
import re, sys, os

bad = 0
for p in sys.argv[1:]:
    s = open(p, encoding="utf-8").read()
    name = os.path.basename(p)
    errs = []
    if not s.startswith("\n"):
        errs.append("pehli line khali nahi (editor paste pehla char kha sakta hai)")
    # strings/comments hata kar scan
    body = re.sub(r"--[^\n]*", "", s)
    body = re.sub(r"\$([A-Za-z_]*)\$.*?\$\1\$", "''", body, flags=re.S)
    body = re.sub(r"'(?:[^']|'')*'", "''", body)
    for i, line in enumerate(s.split("\n"), 1):
        if re.match(r"\s*\\[A-Za-z!?]", line):
            errs.append(f"line {i}: psql meta-command ({line.strip()[:30]})")
    if re.search(r"\bconcurrently\b|^\s*vacuum\b|\balter\s+system\b|\bcreate\s+database\b", body, re.I | re.M):
        errs.append("transaction mein na chalne wali cheez (CONCURRENTLY/VACUUM/ALTER SYSTEM/CREATE DATABASE)")
    if "/proofs/" not in p.replace("\\", "/") and re.search(r"^\s*(begin|commit|rollback)\s*;", body, re.I | re.M):
        errs.append("apna BEGIN/COMMIT/ROLLBACK (sirf proofs/ mein)")
    if name.startswith("CHECK_"):
        top = [x for x in re.split(r";\s*(?:\n|$)", body) if x.strip()]
        if len(top) != 1:
            errs.append(f"CHECK mein {len(top)} statements — ek hi SELECT chahiye (editor aakhri result dikhata hai)")
    if errs:
        bad += 1
        print(f"FAIL {name}")
        for e in errs:
            print("   -", e)
    else:
        print(f"OK   {name}")
sys.exit(1 if bad else 0)
