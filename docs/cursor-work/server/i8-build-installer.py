#!/usr/bin/env python3
"""#8 (domain wizard) installer generator.
git HEAD -> kaam-ki-tree ka farq anchor-edits mein, naye files poore content ke saath;
docs/cursor-work/server/i8-domains-install.mjs likhta hai (sirf web: Rust/Brain/DB mein koi tabdeeli nahi,
kyunki mail.domains.* / mail.addresses.* Rust mein pehle se hain, E15).
Live file se sha nahi, EXACT anchor (har edit ka purana text ek hi baar milna chahiye) gate hai.
routeTree.gen.ts installer mein nahi: web build usay khud dobara banata hai."""
import difflib, json, subprocess, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]
EDITED = [  # (repo path, path inside /opt/anexomail-web/)
    "src/lib/plan-surface.ts",
    "src/components/app/AppShell.tsx",
    "src/components/app/CommandPalette.tsx",
    "src/components/app/dashboard/Panels.tsx",
    "src/components/app/mail/MailRail.tsx",
    "src/lib/workspace-i18n.ts",
    "src/routes/app.admin.addresses.tsx",
]
NEW = [
    "src/lib/domains.ts",
    "src/routes/app.domains.tsx",
]

def head(path):
    return subprocess.check_output(["git", "show", f"HEAD:{path}"], cwd=REPO).decode()

edits = []
for rp in EDITED:
    old_t = head(rp)
    new_t = (REPO / rp).read_text()
    if old_t == new_t:
        print("NO CHANGE", rp); sys.exit(1)
    a = old_t.splitlines(keepends=True)
    b = new_t.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    built = None
    for n in (3, 6, 10, 16, 40):
        groups = list(sm.get_grouped_opcodes(n))
        cur, ok = [], True
        for g in groups:
            i1, i2, j1, j2 = g[0][1], g[-1][2], g[0][3], g[-1][4]
            o = "".join(a[i1:i2]); nw = "".join(b[j1:j2])
            if old_t.count(o) != 1:
                ok = False; break
            cur.append((o, nw))
        if ok:
            built = cur; break
    if built is None:
        print("anchor unique nahi", rp); sys.exit(2)
    for o, nw in built:
        edits.append({"f": rp, "old": o, "new": nw})

newfiles = [{"f": rp, "content": (REPO / rp).read_text()} for rp in NEW]

tpl = (REPO / "docs/cursor-work/server/i8-install.tpl.mjs").read_text()
out = tpl.replace("__EDITS__", json.dumps(edits, ensure_ascii=False)).replace(
    "__NEWFILES__", json.dumps(newfiles, ensure_ascii=False))
dst = REPO / "docs/cursor-work/server/i8-domains-install.mjs"
dst.write_text(out)
print("edits:", len(edits), "new files:", len(newfiles), "->", dst)
