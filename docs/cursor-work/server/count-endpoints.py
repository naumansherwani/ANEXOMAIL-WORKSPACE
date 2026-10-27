#!/usr/bin/env python3
"""Bun endpoints vs client Rust-first (rpcOrRest) count. Usage: python3 docs/cursor-work/server/count-endpoints.py  (run from repo root)
Writes docs/claude/ENDPOINT-MIGRATION-24OCT.csv and the numbers table of docs/claude/MIGRATION-LEDGER-24OCT.md (between the 'Kul hisaab' and 'File-wise' headings)."""
import re, glob, os, csv, collections, json
idx = open('server/index.ts').read()
imp = {}
for m in re.finditer(r'import\s+(\w+)\s+from\s*["\']\./routes/([^"\']+)["\']', idx):
    imp[m.group(1)] = (os.path.basename(m.group(2)), 'default')
for m in re.finditer(r'import\s+(\w+)\s*,\s*\{([^}]*)\}\s*from\s*["\']\./routes/([^"\']+)["\']', idx):   # 27 Oct: `import X, { Y } from` (security/settings/integrations)
    imp[m.group(1)] = (os.path.basename(m.group(3)), 'default')
    for part in m.group(2).split(','):
        a = part.strip().split(' as ')
        if a[0]: imp[a[-1].strip()] = (os.path.basename(m.group(3)), a[0].strip())
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
        pres = [p for n, (fl, o) in imp.items() if fl == base[:-3] and ((o == 'default' and not var.lower().startswith('founder')) or o == var or (var.lower().startswith('founder') and o.lower().startswith('founder'))) for p in mounts.get(n, [])] or mounts.get(var) or ['/api']   # 27 Oct: import-naam pehle (generic 'router' var galat mount deta tha)
        eps.append((base, meth.upper(), pres[0].rstrip('/') + path, path))
cl = collections.defaultdict(set)
PROCRE = re.compile(r'(?:^|[^\w.])(["`\'])([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)\1\s*,\s*(?:\{\s*path:\s*)?(["`\'])(/api/[^`"\']*)\3')
RUSTP = set()   # Rust ke asli procs: glue owns() + core pro_only()/owns() + main.rs match arms
for f in glob.glob('server/rust/*_glue.rs') + glob.glob('server/rust/*_core.rs'):
    for m in re.finditer(r'pub fn (?:owns|pro_only|procs)\(.*?\n\}', open(f).read(), re.S):
        RUSTP |= set(re.findall(r'"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)"', m.group(0)))
RUSTP |= set(re.findall(r'^\s*"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)"\s*(?:\||=>)', open('server/rust/main.rs').read(), re.M))
for ln in open('server/rust/main.rs').read().splitlines():   # "a.b" | "c.d" => ...  (ek line mein kai proc, '-' wale naam bhi)
    if '=>' in ln and ln.lstrip().startswith('"'):
        RUSTP |= set(re.findall(r'"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_-]+)+)"', ln.split('=>')[0]))
for f in glob.glob('server/rust/*_core.rs') + glob.glob('server/rust/*_glue.rs'):   # match-arm procs (analytics_core need_of)
    RUSTP |= set(re.findall(r'^\s*"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)"\s*(?:\||=>)', open(f).read(), re.M))
for f in glob.glob('server/rust/*_core.rs'):   # PROCS: [..] jaise const arrays (billx/basx/contx)
    for m in re.finditer(r'pub const PROCS: \[&str; \d+\] = \[(.*?)\];', open(f).read(), re.S):
        RUSTP |= set(re.findall(r'"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)"', m.group(1)))
ALLR = set()   # Rust source mein jahan bhi 'a.b' naam likha ho (owns_name() wale modules bhi)
for f in glob.glob('server/rust/*.rs'): ALLR |= set(re.findall(r'"([A-Za-z0-9_]+(?:\.[A-Za-z0-9_-]+)+)"', open(f).read()))
for f in glob.glob('src/**/*.ts*', recursive=True):
    s2 = open(f).read()
    for m in re.finditer(r'rpcOrRest[^(]*\(\s*["`\']([\w.]+)["`\']\s*,\s*\{\s*path:\s*([`"\'])(/api/[^`"\']*)\2', s2):
        if m.group(1) in ALLR: cl[norm(m.group(3))].add(m.group(1))   # 27 Oct: client ka proc naam Rust source mein sach-much ho, warna "Rust-first" jhoota (Bun par girta hai)
    # get<T>("proc", "/api/...") / useCrmMutation<..>("proc", "/api/...") — sirf tab jab proc Rust mein sach-much maujood ho
    for m in PROCRE.finditer(s2):
        if m.group(2) in RUSTP:
            cl[norm(m.group(4))].add(m.group(2))
# Verified 27 Oct 2026: yeh 7 Bun routes ka Rust proc live hai (mailx/crmd/analytics); client ya to template-literal path se bulata hai ya REST variant bulata hi nahi.
ALIAS = {
    ('calendar.ts', 'GET', '/api/calendar/export'): 'calendar.export',
    ('trial.ts', 'GET', '/api/state'): 'account.signup.state',
    ('trial.ts', 'GET', '/api/address'): 'account.signup.address',
    ('trial.ts', 'POST', '/api/start'): 'account.signup.start',
    ('trial.ts', 'POST', '/api/claim'): 'account.signup.claim',
    ('trial.ts', 'POST', '/api/security'): 'account.signup.security',
    ('trial.ts', 'POST', '/api/subscribe'): 'account.signup.activate',
    ('trial.ts', 'GET', '/api/events'): 'account.signup.events',
    ('trial.ts', 'GET', '/api/mail-holds'): 'account.signup.holds',
    ('account-deletion.ts', 'GET', '/api/state'): 'account.delete.state',
    ('account-deletion.ts', 'POST', '/api/request'): 'account.delete.request',
    ('account-deletion.ts', 'POST', '/api/cancel'): 'account.delete.cancel',
    ('calendar.ts', 'GET', '/api/work/tasks'): 'work.tasks',
    ('calendar.ts', 'POST', '/api/work/tasks'): 'work.task.create',
    ('calendar.ts', 'PATCH', '/api/work/tasks/:id'): 'work.task.update',
    ('calendar.ts', 'GET', '/api/work/follow-through'): 'work.followThrough',
    ('calendar.ts', 'GET', '/api/work/notes'): 'work.note',
    ('calendar.ts', 'POST', '/api/work/notes'): 'work.note.save',
    ('calendar.ts', 'POST', '/api/calendar/events/:id/outcome'): 'calendar.outcome.post',
    ('storage.ts', 'POST', '/api/storage/reserve'): 'storage.reserve',
    ('storage.ts', 'POST', '/api/storage/release'): 'storage.release',
    ('support.ts', 'GET', '/api/support/drafts'): 'support.drafts',
    ('support.ts', 'POST', '/api/support/drafts/:id/discard'): 'support.draftDiscard',
    ('dashboard.ts', 'GET', '/api/dashboard/ai-usage'): 'dashboard.ai-usage',
    ('contacts.ts', 'GET', '/api/companies'): 'companies.list',
    ('mail.ts', 'GET', '/api/mail/threads'): 'mail.threads',
    ('mail.ts', 'GET', '/api/mail/search'): 'mail.search',
    ('calendar.ts', 'GET', '/api/calendar/export'): 'calendar.export',
    ('locale.ts', 'GET', '/api/locale/registry'): 'locale.registry',
    ('workspace.ts', 'POST', '/api/workspace/invitations'): 'team.invites.create',
    ('analytics.ts', 'GET', '/api/:report'): 'analytics.responseDebt',
    ('billing-sync.ts', 'GET', '/api/auth/subscription'): 'billing.subscription',
    ('billing-sync.ts', 'GET', '/api/auth/invoices'): 'billing.invoices',
    ('billing-sync.ts', 'POST', '/api/auth/portal'): 'billing.portal',
    ('billing-sync.ts', 'POST', '/api/auth/settle'): 'billing.settle',
    ('billing-sync.ts', 'GET', '/api/auth/state'): 'billing.state',
    ('billing-sync.ts', 'GET', '/api/auth/state-health'): 'billing.stateHealth',
    ('billing-sync.ts', 'POST', '/api/auth/claim-guest'): 'billing.claimGuest',
    ('handoff.ts', 'DELETE', '/api/mail/handoff/:id'): 'mail.handoff.delete',
    ('handoff.ts', 'POST', '/api/mail/devices/seen'): 'mail.device.seen',
    ('mail-compose.ts', 'DELETE', '/api/mail/follow-up/:id'): 'mail.followup.delete',
    ('calendar.ts', 'POST', '/api/work/promises/:id/commit'): 'work.promise.commit',
    ('calendar.ts', 'POST', '/api/work/promises/:id/dismiss'): 'work.promise.dismiss',
    ('crm.ts', 'GET', '/api/crm/insights'): 'crm.insights',
    ('analytics.ts', 'GET', '/api/analytics/:report'): 'analytics.responseDebt',
    ('settings.ts', 'GET', '/api/settings/history'): 'settings.history',   # multi-line get() call
    ('settings.ts', 'GET', '/api/settings/scoped/:scope'): 'settings.list',   # Bun ka duplicate route
}
rows = []
for base, meth, full, local in eps:
    n = norm(full); hit = None
    for p, procs in cl.items():
        if p == n or (p.endswith(norm(local)) and norm(local).count('/') >= 2):  # exact mounted path, or a specific (2+ segment) local path
            hit = sorted(procs)[0]; break
    if not hit:  # Bun route ka Rust jora maujood hai magar client path template-literal/dynamic hai ya route unused (REST kabhi nahi bulata)
        a = ALIAS.get((base, meth, full))
        if a and a in RUSTP: hit = a
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
    if m: procs |= set(re.findall(r'"([A-Za-z0-9_]+(?:\.[a-z0-9_]+)+)"', m.group(0)))
procs |= set(re.findall(r'^\s*"([A-Za-z0-9_]+(?:\.[a-z0-9_]+)+)"\s*(?:\||=>)', open('server/rust/main.rs').read(), re.M))
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
