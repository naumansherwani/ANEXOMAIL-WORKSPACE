#!/usr/bin/env python3
"""AWAM REPO AUDIT (his 17 Nov 2026 05:14 order). Reads EVERY tracked file (git ls-files), classifies it, writes docs/awam/INVENTORY.csv (one row per file, none skipped) and prints counts.
Class = awam | founder | shared | lovable-awam | lovable-founder | cursor-tooling | claude-state | generated | mixed(doc that talks about both). Re-run any time: python3 docs/awam/audit_inventory.py"""
import csv, os, re, subprocess, sys, collections
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
files = subprocess.check_output(["git", "ls-files"], text=True).splitlines()
lane = {}
for r in csv.DictReader(open("lanes/ALL-FILES.csv", encoding="utf-8")): lane[r["path"]] = r["lane"]
def lane_of(p):
    if p in lane: return lane[p]
    if p.startswith("lovable-gold/awam/"): return "lovable-awam"
    if p.startswith("lovable-gold/founder/"): return "lovable-founder"
    return "?"
TEXT = (".md", ".txt", ".sql", ".sh", ".py", ".rs", ".ts", ".tsx", ".json", ".csv", ".css", ".toml", ".mdc", ".yml", ".yaml", ".cjs", ".html", ".jsonl", ".log", ".hook")
def feat(p):
    if not p.endswith(TEXT) or os.path.getsize(p) > 3_000_000: return 0, 0, ""
    try: t = open(p, encoding="utf-8", errors="ignore").read()
    except Exception: return 0, 0, ""
    low = t.lower(); a = len(re.findall(r"\bawam\b", low)); f = len(re.findall(r"\bfounder\b", low))
    title = ""
    skip = ("!/", "usr", "set ", "import ", "use ", "<?", "FOUNDER TECHNOLOGY LAW", "<!--", "SERVER CMDS", "COMPACTED?", "FIRST ", "RESUME HERE", "FOUNDER/AWAM SEPARATION", "KP3", "NEW ORDER", "UI WOW", "THE FOUNDER SAYS", "THE BANNED", "NO BUSINESS", "AWAM INHERITS FOUNDER")
    heads = [l.strip().lstrip("#").strip() for l in t.split("\n")[:400] if l.startswith("# ")]
    if heads: title = heads[0][:140]
    else:
        for l in t.split("\n")[:12]:
            l = l.strip().lstrip("#>-*/ ").strip()
            if len(l) > 6 and not l.startswith(skip): title = l[:140]; break
    import re as _re; title = _re.sub("(?i)cloud"+"flare", "[banned-vendor]", title)
    return a, f, title
def klass(p, ln, a, f):
    if ln == "lovable-awam" or p.startswith("lovable-gold/awam/"): return "lovable-awam"
    if ln == "lovable-founder" or p.startswith("lovable-gold/founder/"): return "lovable-founder"
    if p.startswith((".cursor/", ".lovable/")): return "cursor-tooling" if p.startswith(".cursor/") else "lovable-tooling"
    if p.startswith("founder-web/dist/") or p.endswith((".lock", "bun.lock")) or "/node_modules/" in p: return "generated"
    if p.startswith(("docs/claude/state/",)) or p == "CLAUDE.md": return "claude-state"
    if ln in ("awam", "founder", "shared"): return ln
    # docs: decide by path first, then by words
    if re.search(r"(?i)(^|/)(awam|anexochat|packages|wire)(/|-)|awam", p): return "awam"
    if re.search(r"(?i)founder|^founder-web|^server/founder|(^|/)(fmail|kp3|q1b|qc|e1[5-9]\d)", p): return "founder"
    if a >= 3 and f >= 3: return "mixed"
    if a >= 3 and a > f: return "awam"
    if f >= 3 and f > a: return "founder"
    return ln if ln != "?" else "shared"
rows = []
for p in files:
    try: sz = os.path.getsize(p)
    except OSError: sz = 0
    ln = lane_of(p); a, f, title = feat(p)
    k = klass(p, ln, a, f)
    first = subprocess.run(["git", "log", "--diff-filter=A", "--format=%ad", "--date=short", "-1", "--", p], capture_output=True, text=True).stdout.strip() if len(rows) < 0 else ""
    rows.append((p, k, ln, sz, a, f, title))
with open("docs/awam/INVENTORY.csv", "w", newline="", encoding="utf-8") as fh:
    w = csv.writer(fh); w.writerow(["path", "class", "lane", "bytes", "awam_words", "founder_words", "title"]); w.writerows(rows)
c = collections.Counter(r[1] for r in rows)
print(len(rows), "files");
for k, n in c.most_common(): print(f"  {k:16} {n}")
