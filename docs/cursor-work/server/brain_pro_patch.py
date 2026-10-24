#!/usr/bin/env python3
"""Brain (Bun fallback) Pro mail fixes: apply verified hunks to the LIVE routes files (anchor-based, idempotent).
usage: brain_pro_patch.py HUNKS.json LIVE_ROUTES_DIR OUT_DIR   -> prints "same" or "changed: a,b" ; exit 3 if an anchor is missing."""
import json, os, sys
hunks = json.load(open(sys.argv[1])); live = sys.argv[2]; out = sys.argv[3]
changed = []
for name, hs in hunks.items():
    s = open(os.path.join(live, name)).read()
    t = s
    for old, new in hs:
        if new in t:
            continue
        if t.count(old) != 1:
            print("MISSING anchor in %s: %r" % (name, old[:90])); sys.exit(3)
        t = t.replace(old, new, 1)
    open(os.path.join(out, name), "w").write(t)
    if t != s: changed.append(name)
print("changed: " + ",".join(changed) if changed else "same")
