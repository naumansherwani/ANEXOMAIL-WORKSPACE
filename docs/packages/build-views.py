#!/usr/bin/env python3
"""features.tsv (SINGLE source) -> FEATURE-CATALOG.md + <pkg>/INCLUDES.md.
Har feature EK jagah, sabse neeche wale package par; upar wale inherit karte hain. Mix nahi.
Run: python3 docs/packages/build-views.py"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ORD = ["basic", "pro", "business", "business_pro", "enterprise"]
NAME = {"basic": "Basic £40", "pro": "Pro £105", "business": "Business £360",
        "business_pro": "Business Pro £2,850", "enterprise": "Enterprise £18,500"}
LIMITS = [
    ("Users cap", "5", "20", "60", "570", "unlimited"),
    ("Mailboxes", "3", "10", "-", "-", "-"),
    ("Shared storage", "15GB", "300GB", "1.5TB", "10TB", "15TB"),
    ("Attachment", "25MB", "35MB", "45MB", "60MB", "100MB"),
    ("Company domains", "1", "3", "-", "-", "-"),
    ("Booking links", "1", "3", "20", "unlimited", "unlimited"),
    ("Trusted devices", "2", "4", "10", "50", "100"),
    ("Support response", "72h", "48h", "-", "-", "priority"),
    ("Pipelines (PROPOSED)", "-", "1", "5", "unlimited", "unlimited"),
    ("Custom fields (PROPOSED)", "-", "5", "25", "unlimited", "unlimited"),
    ("Web forms (PROPOSED)", "-", "1", "10", "unlimited", "unlimited"),
    ("Workflow rules (PROPOSED)", "-", "-", "10", "unlimited", "unlimited"),
    ("Group video (PROPOSED)", "-", "1:1", "8", "40", "60"),
    ("ANEXOChat file", "-", "-", "2GB", "5GB", "7GB"),
]

rows = []
for l in open(os.path.join(HERE, "features.tsv"), encoding="utf-8"):
    if not l.strip() or l.startswith("#"):
        continue
    r = l.rstrip("\n").split("\t")
    rows.append(r + [""] * (7 - len(r)))
ids = [r[0] for r in rows]
assert len(ids) == len(set(ids)), "duplicate id"

out = [
    "# FEATURE CATALOG — poori website, har feature EK package par (auto-generated; EDIT NAHI: features.tsv badlo phir build-views.py chalao)\n",
    "Qaida: feature sirf **starts_at** wale package par likha hai; upar ke packages ko inherit milta hai. Mix/duplicate nahi. "
    "CODE = gate code mein enforce; PROPOSED = CEO assignment (founder approve baqi); TODO-VERIFY = code gate check baqi.\n",
    "## Matrix\n",
    "| ID | Area | Feature | Basic | Pro | Business | Biz Pro | Enterprise | Status |",
    "|---|---|---|---|---|---|---|---|---|",
]
for r in rows:
    s = r[3]
    if s in ORD:
        i = ORD.index(s)
        cells = ["Y" if j >= i else "-" for j in range(5)]
    else:
        cells = [s, "", "", "", ""]
    out.append(f"| {r[0]} | {r[1]} | {r[2]} | " + " | ".join(cells) + f" | {r[4]} |")
out += ["\n## LIMITS (har package ka apna number)\n",
        "| Limit | Basic | Pro | Business | Biz Pro | Enterprise |", "|---|---|---|---|---|---|"]
out += ["| " + " | ".join(l) + " |" for l in LIMITS]
open(os.path.join(HERE, "FEATURE-CATALOG.md"), "w", encoding="utf-8").write("\n".join(out) + "\n")

for p in ORD:
    k = ORD.index(p)
    os.makedirs(os.path.join(HERE, p), exist_ok=True)
    new = [r for r in rows if r[3] == p]
    inh = [r for r in rows if r[3] in ORD and ORD.index(r[3]) < k]
    o = [f"# {NAME[p]} — INCLUDES (auto-generated from features.tsv)\n", f"## NAYA is package par ({len(new)})\n"]
    o += [f"- {r[0]} · {r[2]} [{r[4]}]" for r in new] or ["- (kuch naya nahi)"]
    o += [f"\n## Neeche ke packages se inherit ({len(inh)})\n"] + [f"- {r[0]} · {r[2]}" for r in inh]
    todo = [r for r in new if r[4] in ("GATE-TO-BUILD", "PROPOSED")]
    o += [f"\n## GREEN hone mein BAQI ({len(todo)}) — gate/feature banana baqi\n"] + [f"- {r[0]} · {r[2]} [{r[4]}]" for r in todo]
    o += ["\n## Is package mein NAHI (upar ke packages)\n"] + [
        f"- {r[0]} · {r[2]} → {r[3]}" for r in rows if r[3] in ORD and ORD.index(r[3]) > k]
    o += ["\n## Limits\n"] + [f"- {l[0]}: {l[k + 1]}" for l in LIMITS]
    open(os.path.join(HERE, p, "INCLUDES.md"), "w", encoding="utf-8").write("\n".join(o) + "\n")
from collections import Counter
print(Counter(r[4] for r in rows))
print(len(rows), "features;", sum(1 for r in rows if r[4] == "PROPOSED"), "proposed;",
      sum(1 for r in rows if r[4] == "TODO-VERIFY"), "to verify")
