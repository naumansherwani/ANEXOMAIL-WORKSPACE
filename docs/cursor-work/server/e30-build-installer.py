#!/usr/bin/env python3
"""E30 installer generator.
git HEAD (repo) -> kaam-ki-tree ka farq anchor-edits mein badalta hai aur
docs/cursor-work/server/e30-dashboard-install.mjs likhta hai.
Live file se sha nahi, EXACT anchor (har edit ka purana text ek hi baar milna chahiye) gate hai."""
import difflib, json, subprocess, sys, pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]
TARGETS = [
    # (repo path, area, path inside live root)
    ("server/rust/main.rs", "rust", "main.rs"),
    ("server/routes/dashboard.ts", "brain", "routes/dashboard.ts"),
    ("src/lib/dashboard.ts", "web", "src/lib/dashboard.ts"),
    ("src/components/app/dashboard/Panels.tsx", "web", "src/components/app/dashboard/Panels.tsx"),
    ("src/components/app/dashboard/Greeting.tsx", "web", "src/components/app/dashboard/Greeting.tsx"),
    ("src/components/app/AppShell.tsx", "web", "src/components/app/AppShell.tsx"),
    ("src/components/app/mail/MailRail.tsx", "web", "src/components/app/mail/MailRail.tsx"),
    ("src/routes/app.mail.$folder.tsx", "web", "src/routes/app.mail.$folder.tsx"),
]

def head(path):
    return subprocess.check_output(["git", "show", f"HEAD:{path}"], cwd=REPO).decode()

edits = []
for repo_path, area, live in TARGETS:
    old_t = head(repo_path)
    new_t = (REPO / repo_path).read_text()
    if old_t == new_t:
        print("NO CHANGE", repo_path); sys.exit(1)
    a = old_t.splitlines(keepends=True)
    b = new_t.splitlines(keepends=True)
    sm = difflib.SequenceMatcher(None, a, b, autojunk=False)
    for n in (3, 6, 10, 16):
        groups = list(sm.get_grouped_opcodes(n))
        ok = True
        built = []
        for g in groups:
            i1, i2 = g[0][1], g[-1][2]
            j1, j2 = g[0][3], g[-1][4]
            o = "".join(a[i1:i2]); nw = "".join(b[j1:j2])
            if old_t.count(o) != 1:
                ok = False; break
            built.append((o, nw))
        if ok:
            break
    else:
        print("anchor unique nahi", repo_path); sys.exit(2)
    for o, nw in built:
        edits.append({"area": area, "f": live, "old": o, "new": nw})

tpl = (REPO / "docs/cursor-work/server/e30-install.tpl.mjs").read_text()
out = tpl.replace("__EDITS__", json.dumps(edits, ensure_ascii=False))
dst = REPO / "docs/cursor-work/server/e30-dashboard-install.mjs"
dst.write_text(out)
print("edits:", len(edits), "->", dst)
