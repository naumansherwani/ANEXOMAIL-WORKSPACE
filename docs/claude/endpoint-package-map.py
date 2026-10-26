#!/usr/bin/env python3
"""Har Bun endpoint (docs/claude/ENDPOINT-MIGRATION-24OCT.csv) aur har Rust proc ko PACKAGE dena (starts_at = sab se chhota package jis se woh shuru hota hai;
upar ke sab packages ko bhi milta hai). Source of truth for rules: docs/claude/PP1-FULL-GATE-TABLE-26OCT.md (#n) + docs/packages/features.tsv + gates live code.
Chalao:  python3 docs/claude/endpoint-package-map.py   -> docs/claude/ENDPOINT-PACKAGE-MAP.csv + docs/claude/ENDPOINT-PACKAGE-MAP-26OCT.md
starts_at: basic | pro | business | business_pro | founder (founder host only, package nahi) | ai_soon (AI plans July 2027) | internal (service-to-service)
Enterprise = HAR cheez jo Business Pro mein hai + poori website latest technology (Rust-only, Bun-free); Enterprise ka koi alag endpoint abhi nahi (ZERO, founder 04:56)."""
import csv, re, glob, collections

B, P, BU, BP, F, AI, INT = 'basic', 'pro', 'business', 'business_pro', 'founder', 'ai_soon', 'internal'
# (file regex, path regex, package, group, basis)  — pehla match jeetta hai
BUN = [
 (r'.', r'/api/internal/|/api/mail/deliver$|/api/storage/internal', INT, 'service-to-service', 'code'),
 (r'.', r'^/api/founder/|/api/revenue|/api/release|^/api/status$|/api/mail/outbox/send$', F, 'founder host only', 'PP1 #39'),
 (r'^(admin|perf|glitch|founder|revenue|billing-support|release|movein)\.ts$', r'.', F, 'founder host only', 'PP1 #39'),
 (r'^ai(-automation|-credits|-studio)?\.ts$', r'.', AI, 'AI plans (coming soon July 2027)', 'PP1 #9'),
 (r'^integrations\.ts$', r'leo-actions', AI, 'Leo AI actions', 'PP1 #9'),
 (r'^chat\.ts$', r'.', BU, 'ANEXOChat + work-layer + video (Bu+)', 'PP1 #23-26'),
 (r'^files\.ts$', r'.', BU, 'File engine (resumable big files; Business+)', 'live storage page'),
 (r'^crm\.ts$', r'/crm/(approvals|audit|permissions|shared|mentions)', BU, 'CRM collab', 'PP1 #19'),
 (r'^crm\.ts$', r'/crm/(evidence|activities)', BP, 'CRM activity timeline + evidence', 'PP1 #20'),
 (r'^crm\.ts$', r'.', P, 'CRM base', 'PP1 #18'),
 (r'^people-import\.ts$', r'/crm/', P, 'CRM base (lead import)', 'PP1 #18'),
 (r'^people-import\.ts$', r'.', B, 'People import', 'PP1 #10'),
 (r'^org\.ts$', r'/org/(graph|break-glass)', BP, 'Org graph + break-glass', 'PP1 #30'),
 (r'^org\.ts$', r'.', BU, 'Org centre (Bu+)', 'PP1 #29'),
 (r'^mail\.ts$', r'/snooze|/assign', P, 'Pro mail tools (snooze, shared-inbox assign)', 'PP1 #7'),
 (r'^mail-compose\.ts$', r'templates|snippets|schedule|follow-up|send-confidence|insights', P, 'Pro mail tools + pre-send scan', 'PP1 #7-8'),
 (r'^handoff\.ts$', r'.', P, 'Cross-device draft handoff', 'PP1 #8'),
 (r'^mail-predict\.ts$', r'.', P, 'Word prediction', 'PP1 #8'),
 (r'^mail(-compose)?\.ts$', r'.', B, 'Mail core', 'PP1 #6'),
 (r'^calendar\.ts$', r'/calendar/(availability|focus)|/events/:id/outcome', P, 'Calendar Pro (availability, focus, goal/outcome)', 'PP1 #3b'),
 (r'^calendar\.ts$', r'/calendar/load', BU, 'Team report / team time', 'PP1 #16'),
 (r'^calendar\.ts$', r'/api/work/', P, 'WORK (tasks, promises, notes)', 'PP1 #15'),
 (r'^calendar\.ts$', r'.', B, 'Calendar core', 'PP1 #1'),
 (r'^analytics\.ts$', r'/api/analytics', P, 'Analytics (thread economics, deep work; response debt Basic)', 'PP1 #21'),
 (r'^security\.ts$', r'/proof', BU, 'DNS/TLS hashed proof export', 'PP1 #32'),
 (r'^security\.ts$', r'.', B, 'Security centre', 'PP1 #31'),
 (r'^settings\.ts$', r'blast-radius|simulate|drift|/schedule|scheduled', BU, 'Settings governance (simulate, blast-radius, drift, scheduled changes)', 'CEO DECISION 26 Oct (Google Workspace: basic admin settings+reports at lowest tier, advanced governance higher)'),
 (r'^(account-deletion|auth|auth-passkey|billing-sync|polar|support|locale|trial|workspace|contacts|dashboard|settings|storage)\.ts$', r'.', B, 'Account / auth / billing / People / dashboard / storage / settings (all plans)', 'PP1 #10,#17,#31,#34'),
 (r'^integrations\.ts$', r'.', B, 'Import old mail / integrations', 'PP1 #12'),
]
def pkg_bun(f, path):
    for fr, pr, pkg, grp, basis in BUN:
        if re.search(fr, f) and re.search(pr, path): return pkg, grp, basis
    return '?', 'UNCLASSIFIED', 'FOUNDER CONFIRM'

PROC = [
 (r'^(founder|founderAnalytics|movein|release|revenue)\.|^kernel\.|^wtrpc', F, 'founder / infra'),
 (r'^(chat|call|file)\.', BU, 'ANEXOChat / calls / files'),
 (r'^team\.', BU, 'Team report / time'),
 (r'^org\.', BU, 'Org centre'),
 (r'^calendar\.(rooms?)', BU, 'Calendar rooms'),
 (r'^calendar\.(availability|focus|rates|files|meta)', P, 'Calendar Pro'),
 (r'^calendar\.load', BU, 'Team load'),
 (r'^(crm|work)\.', P, 'CRM base / WORK'),
 (r'^analytics\.(forecast|leaks|promiseSla|team)', BU, 'Analytics Bu+'),
 (r'^analytics\.(threadEconomics|deepWork)', P, 'Analytics Pro'),
 (r'^analytics\.', B, 'Analytics (response debt)'),
 (r'^mail\.(snooze|assign|templates|snippets|schedule|followup|handoff|confidence|thread\.insights|thread\.note|predict)', P, 'Pro mail tools'),
 (r'^(mail|calendar|booking|caldav|security|auth|account|locale|billing|migration|appeal|people|outbox|dashboard|device|dnsauth|export|attach|evidence|dav|ics)\.', B, 'core / all plans'),
]
def pkg_proc(p):
    for pr, pkg, grp in PROC:
        if re.search(pr, p): return pkg, grp
    return '?', 'UNCLASSIFIED'

rows = list(csv.DictReader(open('docs/claude/ENDPOINT-MIGRATION-24OCT.csv')))
out, cnt = [], collections.defaultdict(lambda: [0, 0, 0])
for r in rows:
    pkg, grp, basis = pkg_bun(r['bun_file'], r['path'])
    rust = bool(r['client_rust_first_proc'])
    out.append([r['bun_file'], r['method'], r['path'], pkg, grp, basis, 'RUST-FIRST' if rust else 'BUN-ONLY', r['client_rust_first_proc']])
    c = cnt[pkg]; c[0] += 1; c[1] += rust; c[2] += (not rust)
with open('docs/claude/ENDPOINT-PACKAGE-MAP.csv', 'w', newline='') as fh:
    w = csv.writer(fh); w.writerow(['bun_file', 'method', 'path', 'starts_at', 'feature_group', 'basis', 'status', 'rust_proc']); w.writerows(out)

procs = set()
for f in glob.glob('server/rust/*_glue.rs'):
    m = re.search(r'fn owns\(.*?\n\}', open(f).read(), re.S)
    if m: procs |= set(re.findall(r'"([a-z0-9_]+(?:\.[a-z0-9_]+)+)"', m.group(0)))
procs |= set(re.findall(r'^\s*"([a-z0-9_]+(?:\.[a-zA-Z0-9_]+)+)"\s*(?:\||=>)', open('server/rust/main.rs').read(), re.M))
pc = collections.defaultdict(list)
for p in sorted(procs): pc[pkg_proc(p)[0]].append(p)

order = [B, P, BU, BP, F, INT, AI, '?']
names = {B: 'BASIC (aur uske upar sab)', P: 'PRO (+ upar)', BU: 'BUSINESS (+ upar)', BP: 'BUSINESS PRO (+ Enterprise)', F: 'FOUNDER host only (package nahi)', INT: 'INTERNAL (service-to-service)', AI: 'AI (coming soon July 2027)', '?': 'UNCLASSIFIED'}
L = ["# ENDPOINT -> PACKAGE MAP — 26 Oct 2026 (founder hukm 22:14: 'repo mein likho kaun si feature/gate/endpoint kis package ki hai, verna website mix ho jaye gi')",
     "Script: `python3 docs/claude/endpoint-package-map.py` (rules upar script mein; source PP1-FULL-GATE-TABLE-26OCT.md + docs/packages/features.tsv). Poori list: `ENDPOINT-PACKAGE-MAP.csv`.",
     "**starts_at** = sab se chhota package jis se endpoint shuru hota hai; us se UPAR ke sab packages ko bhi milta hai. **Enterprise** = Business Pro ki har cheez + POORI website latest technology (Rust-only, Bun-free) — Enterprise ka koi alag endpoint abhi nahi (ZERO, founder 04:56).",
     "**RULE (AGENTS.md):** naya endpoint/gate likhne se pehle is map mein uska starts_at dekho; gate SERVER par (Rust, resolve_plan), UI aaina. Map mein na ho => pehle yahan CSV/rule mein jodo, phir code.", "",
     "## Bun REST endpoints (523) — package-wise", "| Package (starts_at) | Kul | Rust-first (live) | Baaqi (Bun-only) |", "|---|---|---|---|"]
for k in order:
    if k in cnt: L.append(f"| {names[k]} | {cnt[k][0]} | {cnt[k][1]} | {cnt[k][2]} |")
L.append(f"| **Jod** | {len(rows)} | {sum(v[1] for v in cnt.values())} | {sum(v[2] for v in cnt.values())} |")
L += ["", "## Rust procs (jo already latest technology par aa chuke) — package-wise", "| Package (starts_at) | Procs |", "|---|---|"]
for k in order:
    if k in pc: L.append(f"| {names[k]} | {len(pc[k])} |")
L.append(f"| **Jod** | {len(procs)} |")
for k in order:
    if k in pc: L += ["", f"### {names[k]} — Rust procs", ', '.join(f'`{p}`' for p in pc[k])]
L += ["", "## Baaqi (BUN-ONLY) endpoints — package ke hisaab se kaam ki list (file: ginti)"]
for k in order:
    fc = collections.Counter(o[0] for o in out if o[3] == k and o[6] == 'BUN-ONLY')
    if fc: L.append(f"- **{names[k]}**: " + ', '.join(f'{f} {n}' for f, n in fc.most_common()))
L += ["", "## CEO FAISLE (founder hukm 26 Oct 22:20: 'tum karo, user ke mindset se, Zoho/Google Workspace se behtar') — competitor check: Google Workspace compare-business-editions (admin security settings, audit log, usage reports sab SAB SE SASTE tier mein; Vault/eDiscovery aur advanced endpoint sirf Plus mein)",
      "- **Settings**: scoped view, explain, save, history, revert, overview = **Basic** (user apni settings ki history/undo se kabhi mehroom nahi). simulate, blast-radius, drift, scheduled changes = **Business** (admin governance).",
      "- **CRM live**: base + radar + graph = **Pro** (Pro ko behtareen chhota-business CRM). Activity evidence + timeline (sealed) = Business Pro; collab (shared/approvals/audit/permissions) = Business.",
      "- **Analytics**: response debt = Basic; thread economics + deep work = Pro; forecast, attention leaks, promise SLA, team = Business.",
      "- Personal Basic/Pro+/Premium: HOLD (founder), is map mein nahi."]
open('docs/claude/ENDPOINT-PACKAGE-MAP-26OCT.md', 'w').write('\n'.join(L) + '\n')
print('\n'.join(L[5:20]))
print('unclassified bun', cnt['?'][0], 'procs', len(pc['?']), pc['?'][:20])
