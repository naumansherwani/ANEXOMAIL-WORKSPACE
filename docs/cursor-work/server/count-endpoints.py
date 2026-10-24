#!/usr/bin/env python3
"""Bun endpoints vs client Rust-first (rpcOrRest) count. Usage: python3 docs/cursor-work/server/count-endpoints.py  (run from repo root)
Writes docs/claude/ENDPOINT-MIGRATION-24OCT.csv and the numbers table of docs/claude/MIGRATION-LEDGER-24OCT.md (between the 'Kul hisaab' and 'File-wise' headings)."""
import re, glob, os, csv, collections, json
idx = open('server/index.ts').read()
imp = {}
for m in re.finditer(r'import\s+(\w+)\s+from\s*["\']\./routes/([^"\']+)["\']', idx):
    imp[m.group(1)] = (os.path.basename(m.group(2)), 'default')
for m in re.finditer(r'import\s*\{([^}]*)\}\s*from\s*["\']\./routes/([^"\']+)["\']', idx):
    for part in m.group(1).split(','):
        a = part.strip().split(' as ')
        if a[0]: imp[a[-1].strip()] = (os.path.basename(m.group(2)), a[0].strip())
mounts = collections.defaultdict(list)
for pre, name in re.findall(r'app\.use\(\s*["`\'](/[^"`\']*)["`\']\s*,\s*(?:[A-Za-z_]+\s*,\s*)*([A-Za-z_]+)\s*\)', idx):
    mounts[name].append(pre)
norm = lambda p: re.sub(r'(:\w+|\$\{[^}]*\})', '*', p.split('?')[0]).rstrip('/')
eps = []
for f in sorted(glob.glob('server/routes/*.ts')):
    if f.endswith('.test.ts'): continue
    base = os.path.basename(f); s = open(f).read()
    for m in re.finditer(r'\b(\w+)\.(get|post|put|patch|delete)\(\s*(["`\'])(/[^"`\']*)\3', s):
        var, meth, _, path = m.groups()
        pres = mounts.get(var) or [p for n, (fl, o) in imp.items() if fl == base[:-3] and o in (var, 'default') for p in mounts.get(n, [])] or ['/api']
        eps.append((base, meth.upper(), pres[0].rstrip('/') + path, path))
cl = collections.defaultdict(set)
for f in glob.glob('src/**/*.ts*', recursive=True):
    s = open(f).read()
    for m in re.finditer(r'rpcOrRest[^(]*\(\s*["`\']([\w.]+)["`\']\s*,\s*\{\s*path:\s*([`"\'])(/api/[^`"\']*)\2', s):
        cl[norm(m.group(3))].add(m.group(1))
rows = []
for base, meth, full, local in eps:
    n = norm(full); hit = None
    for p, procs in cl.items():
        if p == n or (p.endswith(norm(local)) and norm(local).count('/') >= 2):  # exact mounted path, or a specific (2+ segment) local path
            hit = sorted(procs)[0]; break
    rows.append((base, meth, full, hit))
by = collections.OrderedDict()
for b, m, f, h in rows: by.setdefault(b, []).append((m, f, h))
with open('docs/claude/ENDPOINT-MIGRATION-24OCT.csv', 'w', newline='') as fh:
    w = csv.writer(fh); w.writerow(['bun_file', 'method', 'path', 'client_rust_first_proc', 'status'])
    for b, l in by.items():
        for m, f, h in l: w.writerow([b, m, f, h or '', 'RUST-FIRST (Bun fallback)' if h else 'BUN-ONLY or client wiring not proven'])
tot = len(rows); mig = sum(1 for r in rows if r[3])
procs = set()
for f in glob.glob('server/rust/*_glue.rs'):
    m = re.search(r'fn owns\(.*?\n\}', open(f).read(), re.S)
    if m: procs |= set(re.findall(r'"([a-z0-9_]+(?:\.[a-z0-9_]+)+)"', m.group(0)))
procs |= set(re.findall(r'^\s*"([a-z0-9_]+(?:\.[a-z0-9_]+)+)"\s*(?:\||=>)', open('server/rust/main.rs').read(), re.M))
L = ["## Kul hisaab (script: docs/cursor-work/server/count-endpoints.py)", "| Cheez | Ginti |", "|---|---|",
     f"| Bun REST endpoints (server/routes) | {tot} |", f"| Client Rust-first (`rpcOrRest`, Bun sirf fallback) | {mig} |",
     f"| Baqi (Bun-only ya client wiring saabit nahi) | {tot-mig} |", f"| Rust procs repo mein | {len(procs)} |", "",
     "## File-wise (Bun file: kul / Rust-first / baqi)", "| Bun file | Kul | Rust-first | Baqi |", "|---|---|---|---|"]
for b, l in sorted(by.items(), key=lambda x: -len(x[1])):
    t = len(l); m = sum(1 for x in l if x[2]); L.append(f"| {b} | {t} | {m} | {t-m} |")
p = 'docs/claude/MIGRATION-LEDGER-24OCT.md'; s = open(p).read()
a = s.index('## Kul hisaab'); b = s.index('## Rust procs prefix-wise')
open(p, 'w').write(s[:a] + "\n".join(L) + "\n\n" + s[b:])
print(f"endpoints {tot}, rust-first {mig}, remaining {tot-mig}, rust procs {len(procs)}")
