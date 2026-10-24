#!/usr/bin/env python3
"""Brain (Bun fallback) Pro mail fixes: apply verified hunks to the LIVE routes files (anchor-based, idempotent).
usage: brain_pro_patch.py LIVE_ROUTES_DIR OUT_DIR HUNKS1.json [HUNKS2.json ...]
Hunks files are applied in order (each on the result of the previous). A hunk whose NEW text is already there is skipped.
Prints "same" or "changed: a,b"; exit 3 if an anchor is missing."""
import json, os, shutil, sys
live, out = sys.argv[1], sys.argv[2]; files = sys.argv[3:]
cur = {}
def get(name):
    if name not in cur:
        cur[name] = open(os.path.join(live, name)).read()
    return cur[name]
orig = {}
for hf in files:
    for name, hs in json.load(open(hf)).items():
        s = get(name); orig.setdefault(name, s); t = s
        for old, new in hs:
            if new in t:
                continue
            if t.count(old) != 1:
                print("MISSING anchor in %s (%s): %r" % (name, os.path.basename(hf), old[:90])); sys.exit(3)
            t = t.replace(old, new, 1)
        cur[name] = t
for name in ("mail.ts", "mail-compose.ts", "calendar.ts"):
    open(os.path.join(out, name), "w").write(get(name))
changed = [n for n in orig if cur[n] != orig[n]]
print("changed: " + ",".join(changed) if changed else "same")
