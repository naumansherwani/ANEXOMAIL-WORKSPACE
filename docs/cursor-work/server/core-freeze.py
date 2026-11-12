#!/usr/bin/env python3
"""Core freeze check (founder 13 Nov 2026). Verifies the awam mail/calendar/attachment files still match docs/claude/CORE-FREEZE.json.
   exit 1 + list when a frozen file changed and is not named in docs/claude/CORE-UNFREEZE-OK.txt. --refreeze rewrites the hashes (only after his word)."""
import hashlib, json, os, sys
FZ = "docs/claude/CORE-FREEZE.json"; OK = "docs/claude/CORE-UNFREEZE-OK.txt"
d = json.load(open(FZ)); allow = set(l.split()[0] for l in open(OK) if l.strip() and not l.startswith("#")) if os.path.exists(OK) else set()
h = lambda f: hashlib.sha256(open(f, "rb").read()).hexdigest() if os.path.exists(f) else "MISSING"
if "--refreeze" in sys.argv:
    d["files"] = {f: h(f) for f in d["files"] if os.path.exists(f)}; json.dump(d, open(FZ, "w"), indent=1); print("refrozen", len(d["files"])); sys.exit(0)
bad = [f for f, x in d["files"].items() if h(f) != x and f not in allow]
for f in bad: print("FROZEN CHANGED:", f)
print("core-freeze:", len(d["files"]), "files,", len(bad), "changed"); sys.exit(1 if bad else 0)
