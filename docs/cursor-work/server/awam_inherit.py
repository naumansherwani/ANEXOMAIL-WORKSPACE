#!/usr/bin/env python3
"""AWAM-INHERIT gate (founder 16 Nov 2026 00:48): the founder mailbox UI is the SAME UI that Business Premium and Business MAX get later (molded for awam). Its files are PRESERVED:
docs/claude/AWAM-INHERIT-MANIFEST.json holds the SHA-256 of every listed file. A listed file may change ONLY together with a manifest update in the same commit (so a change is always deliberate and recorded).
  awam_inherit.py sync     rewrite the manifest from the files on disk (run after a deliberate change)
  awam_inherit.py verify   check disk against the manifest
"""
import hashlib, json, os, subprocess, sys
ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip()
M = os.path.join(ROOT, "docs/claude/AWAM-INHERIT-MANIFEST.json")
FILES = ["founder-web/src/mailbox_pure.ts", "founder-web/src/mailbox_pure.test.ts", "founder-web/src/mailbox_icons.tsx", "founder-web/src/mailbox.css", "founder-web/src/MailBox.tsx", "founder-web/src/mail_pure.ts", "founder-web/src/MailCompose.tsx"]
def h(p): return hashlib.sha256(open(os.path.join(ROOT, p), "rb").read()).hexdigest()
def sync():
    json.dump({"note": "AWAM INHERITS (founder 16 Nov 2026): same mailbox UI for Business Premium + Business MAX; change a file only with this manifest in the same commit", "files": {p: h(p) for p in FILES}}, open(M, "w"), indent=1); open(M, "a").write("\n")
def check(staged):
    out = []
    if not os.path.exists(M): return ["docs/claude/AWAM-INHERIT-MANIFEST.json is missing (python3 docs/cursor-work/server/awam_inherit.py sync)"]
    man = json.load(open(M))["files"]
    for p in FILES:
        if p not in man: out.append(f"{p} is not in the manifest"); continue
        if not os.path.exists(os.path.join(ROOT, p)): out.append(f"{p} is gone: the awam mailbox UI codes are preserved, restore it"); continue
        if h(p) != man[p]: out.append(f"{p} changed but the manifest hash did not: this file is PRESERVED for awam; run awam_inherit.py sync and commit the manifest with it")
    return out
if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "verify"
    if c == "sync": sync(); print("manifest written")
    else:
        e = check([]); print("\n".join(e) or "AWAM-INHERIT OK"); sys.exit(1 if e else 0)
