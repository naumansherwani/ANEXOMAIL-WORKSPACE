#!/usr/bin/env python3
"""Rules gate (founder 28 Oct 2026): run before every commit. A FAIL means: do not commit. It checks only what a machine can check;
judgment rules (is the UI good?) stay with the founder's eyes. Usage: python3 docs/cursor-work/server/rules-gate.py [--staged]"""
import re, subprocess, sys, os

os.chdir(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip())


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


staged = [f for f in sh("git", "diff", "--cached", "--name-only").splitlines() if f]
if "--staged" not in sys.argv and not staged:
    staged = [f for f in sh("git", "diff", "--name-only", "HEAD").splitlines() if f]
if "--all" in sys.argv:  # audit the whole founder tree, not just a commit
    staged = [f for f in sh("git", "ls-files", "founder-web/src", "server/founder/src").splitlines() if f]
fails, warns = [], []


def fail(rule, msg):
    fails.append(f"FAIL [{rule}] {msg}")


def warn(rule, msg):
    warns.append(f"warn [{rule}] {msg}")


code = [f for f in staged if re.match(r"(founder-web/src|server/founder/src)/.*\.(jsx?|css|rs)$", f) and os.path.exists(f)]

# Rule 69 NO MOCK: no placeholder / fake-data markers in founder code
MOCK = re.compile(r"lorem ipsum|\bmock(ed)?\b|fake[ _-]?data|dummy|sample data|placeholder data|TODO|FIXME|john doe|jane doe", re.I)
for f in code:
    for n, l in enumerate(open(f, errors="ignore"), 1):
        s = l.strip()
        if MOCK.search(l) and "NO MOCK" not in l and "Rule 69" not in l and not s.startswith(("//", "/*", "*")):
            fail("69 NO MOCK", f"{f}:{n}: {s[:90]}")

# Rule 67: UI text is English. Roman-Urdu words inside string literals / JSX text of UI files
URDU = re.compile(r"\b(nahi|hai|hain|kero|karo|abhi|aap|mera|kyun|kab|bhai|bana|haan|jaldi|shuru)\b", re.I)
for f in [c for c in code if c.startswith("founder-web/src") and c.endswith(".jsx")]:
    for n, l in enumerate(open(f, errors="ignore"), 1):
        if l.strip().startswith(("//", "/*", "*")):
            continue
        for a, b in re.findall(r'"([^"]{6,})"|>([^<>{}]{6,})<', l):
            t = a or b
            if URDU.search(t) and " " in t:
                fail("67 UI English", f"{f}:{n}: {t[:80]}")

# Rule 24: the founder's order + status are recorded with the work; the pull command is updated with the work
ALL = "--all" in sys.argv
big = [] if ALL else [f for f in staged if re.match(r"(founder-web/src|server/founder/src|docs/cursor-work/sql)/", f)]
if big and "docs/cursor-work/founder/founder-commands.md" not in staged:
    fail("24 commands", "code changed but founder-commands.md (verbatim order + status) not updated in this commit")
if big and "docs/cursor-work/DONE-DO-NOT-REPEAT.md" not in staged:
    fail("ledger", "code changed but DONE-DO-NOT-REPEAT.md not updated")
srv = [] if ALL else [f for f in staged if re.match(r"(founder-web/src|founder-web/dist|server/founder/src|docs/cursor-work/sql)/", f)]
if srv and "docs/claude/founder/PULL-COMMANDS.md" not in staged:
    fail("24 pull command", "server-affecting change but PULL-COMMANDS.md not updated")
pc = "docs/claude/founder/PULL-COMMANDS.md"
if os.path.exists(pc):
    t = open(pc).read()
    i = t.rfind("ABHI PENDING")
    if i >= 0:
        n = len(re.findall(r"^\s*\d+\.\s", t[i:], re.M))
        if n > 2:
            warn("24 one-two points", f"latest ABHI PENDING block has {n} numbered steps (Rule 24: 1-2 at a time)")

# Rule 61: UI stack gaps must stay written down; forbidden runtimes never appear
doc = "docs/claude/FOUNDER-UI-DESIGN-28OCT.md"
if os.path.exists(doc):
    d = open(doc).read()
    for need in ("TanStack Router", "Tailwind"):
        if need not in d:
            fail("61 stack", f"{doc} no longer lists the Rule 61 gap for {need}")
pk = "founder-web/package.json"
if os.path.exists(pk):
    pj = open(pk).read()
    for bad in ('"bun"', '"express"', '"next"', "jquery", "redux"):
        if bad in pj:
            fail("61 stack", f"{pk} contains {bad} (founder UI stack is fixed by Rule 61)")
for f in staged:
    if f.startswith("server/founder/") and f.endswith((".ts", ".js")) and "/tests/" not in f:
        fail("61 no Bun/Node", "founder server code must be Rust: " + f)

# FC18/FC20/FC22: a founder change never edits user-side files
for f in staged:
    if re.match(r"(src/(routes|components|lib)|server/routes)/", f):
        warn("FC18/FC22", f"user-side file touched: {f} (founder work must not edit user files)")

# Deploy manifest must be clean
v = subprocess.run([sys.executable, "docs/cursor-work/server/manifest-verify.py"], capture_output=True, text=True).stdout.strip().splitlines()
if not v or not v[-1].endswith(" 0 bad"):
    fail("manifest", "manifest-verify is not 0 bad: " + (v[-1] if v else "no output"))

for w in warns:
    print(w)
for x in fails:
    print(x)
print(f"rules-gate: {len(fails)} fail, {len(warns)} warn, {len(staged)} staged file(s)")
sys.exit(1 if fails else 0)
