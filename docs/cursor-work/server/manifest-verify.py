#!/usr/bin/env python3
"""DEPLOY-MANIFEST.txt ki HAR entry ka sha256 (pehle 16 akshar) repo ki file se milao.
Rule 28: push se pehle yeh chalao. Exit 1 = koi entry purani/gum => push MAT karo, pehle manifest-sync.py chalao.
Use:  python3 docs/cursor-work/server/manifest-verify.py
"""
import hashlib, os, re, sys

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
manifest = os.path.join(root, "docs", "cursor-work", "server", "DEPLOY-MANIFEST.txt")
bad = n = 0
for line in open(manifest, encoding="utf-8"):
    line = line.strip()
    if not line or line.startswith("#"):
        continue
    parts = line.split()
    if len(parts) < 2:
        continue
    a, b = parts[0], parts[1]
    sha, path = (a, b) if re.fullmatch(r"[0-9a-f]{16,64}", a) else (b, a)
    full = os.path.join(root, path)
    if not os.path.isfile(full):
        print("GUM    ", path)
        bad += 1
        continue
    n += 1
    if not hashlib.sha256(open(full, "rb").read()).hexdigest().startswith(sha[:16]):
        print("PURANI ", path)
        bad += 1
print(f"manifest-verify: {n} files checked, {bad} bad")
sys.exit(1 if bad else 0)
