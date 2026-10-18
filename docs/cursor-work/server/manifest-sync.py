#!/usr/bin/env python3
"""Keep DEPLOY-MANIFEST.txt in step with the repo (AGENTS.md Rule 1: file badlo to usi commit mein manifest ka sha badlo).

  python3 docs/cursor-work/server/manifest-sync.py            # every changed/new src/ file (git) is added or re-hashed
  python3 docs/cursor-work/server/manifest-sync.py src/a.tsx  # only these
Entries whose file no longer exists are dropped. Format: "<repo path> <first 16 hex of sha256>".
"""
import hashlib, os, subprocess, sys

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"]).decode().strip()
MAN = os.path.join(ROOT, "docs/cursor-work/server/DEPLOY-MANIFEST.txt")


def sha(p):
    return hashlib.sha256(open(os.path.join(ROOT, p), "rb").read()).hexdigest()[:16]


def changed():
    out = subprocess.check_output(["git", "-C", ROOT, "status", "--porcelain", "--", "src"]).decode().splitlines()
    return [l[3:].strip() for l in out if not l.startswith(" D") and not l.startswith("D ")]


want = sys.argv[1:] or changed()
lines = open(MAN).read().splitlines()
head = [l for l in lines if l.startswith("#") or not l.strip()]
rows = {}
order = []
for l in lines:
    if l.startswith("#") or not l.strip():
        continue
    p, h = l.split()[:2]
    rows[p] = h
    order.append(p)
for p in want:
    if not os.path.isfile(os.path.join(ROOT, p)):
        continue
    if p not in rows:
        order.append(p)
    rows[p] = sha(p)
order = [p for p in order if os.path.isfile(os.path.join(ROOT, p))]
open(MAN, "w").write("\n".join(head + [f"{p} {rows[p]}" for p in order]) + "\n")
print(f"manifest: {len(order)} files, {len(want)} touched")
