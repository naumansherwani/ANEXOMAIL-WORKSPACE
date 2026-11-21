#!/usr/bin/env python3
"""ADMIN DESK TWO PLACES (his 21 Nov 2026 09:59, in anger): the Admin Desk folder lives INSIDE the Claude docs folder (CANONICAL: docs/claude/admin-desk/) and ONE COPY stays at the repo root (admin-desk/, 'main'),
because his server installers and the gates fetch admin-desk/... from origin/main. Edit ONLY the canonical one; `sync` makes the root copy identical; `check` (used by rules-gate) FAILS the commit if the two differ.
  python3 docs/cursor-work/server/desk-copy-sync.py sync | check"""
import filecmp, os, shutil, sys
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
A, B = os.path.join(ROOT, "docs/claude/admin-desk"), os.path.join(ROOT, "admin-desk")
SKIP = {"target", "__pycache__"}
def files(base):
    out = set()
    for dp, dn, fn in os.walk(base):
        dn[:] = [d for d in dn if d not in SKIP]
        out |= {os.path.relpath(os.path.join(dp, f), base) for f in fn}
    return out
def diff():
    a, b = files(A), files(B); d = [f"only in canonical (not in the root copy): {x}" for x in sorted(a - b)] + [f"only in the root copy (not canonical): {x}" for x in sorted(b - a)]
    d += [f"differs: {x}" for x in sorted(a & b) if not filecmp.cmp(os.path.join(A, x), os.path.join(B, x), shallow=False)]
    return d
def sync():
    a, b = files(A), files(B)
    for x in a:
        os.makedirs(os.path.dirname(os.path.join(B, x)) or B, exist_ok=True); shutil.copy2(os.path.join(A, x), os.path.join(B, x))
    for x in b - a: os.remove(os.path.join(B, x))
if __name__ == "__main__":
    m = sys.argv[1] if len(sys.argv) > 1 else "check"
    if not os.path.isdir(A): sys.exit("FAIL: docs/claude/admin-desk/ (canonical) is missing")
    if m == "sync": sync(); print("admin-desk root copy synced from docs/claude/admin-desk"); sys.exit(0)
    d = diff()
    for x in d[:12]: print(x)
    sys.exit(1 if d else 0)
