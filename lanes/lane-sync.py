#!/usr/bin/env python3
"""Rule 73 (founder 3 Nov 2026 08:33 PKT): every tracked file belongs to exactly ONE lane: founder | awam | shared | lovable | docs.
  python3 lanes/lane-sync.py            regenerate lanes/*.txt + lanes/ALL-FILES.csv and refresh lovable-gold/ (copies, never moves)
  python3 lanes/lane-sync.py --check    exit 1 if the lists are stale, lovable-gold/ differs from its manifest, or a lane imports across (used by rules-gate)
Nothing is moved or deleted: live files stay where the builds need them; lovable-gold/ is a frozen COPY of the Lovable-era code."""
import csv, hashlib, os, re, shutil, subprocess, sys

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip(); os.chdir(ROOT)
GOLD = "lovable-gold"
SHARED_RUST = {"server/rust/merkle_core.rs", "server/rust/jwt_core.rs", "server/rust/checkpoint_core.rs", "server/rust/anchor_core.rs"}


def tracked():
    return [f for f in subprocess.check_output(["git", "ls-files"], text=True).split("\n") if f and not f.startswith(GOLD + "/") and not f.startswith("lanes/")]


def read(p):
    try: return open(p, errors="ignore").read()
    except OSError: return ""


def lane(p):
    b = p.split("/")[-1]
    if p.startswith("founder-web/"): return "founder", "founder SPA built output" if p.startswith("founder-web/dist/") else "founder SPA (React-TS)"
    if p.startswith("server/founder/"): return "founder", "founder Rust (axum)"
    if p.startswith(("web-wasm/", "public/kernel/", "src/lib/kernel/")) or p == "scripts/build-kernel.sh": return "shared", "WASM kernel (one kernel, Rule 52)"
    if p in SHARED_RUST or re.match(r"server/rust/(g5\w+|consistency_vectors)\.json$", p): return "shared", "Rust core/vector file read by the founder crate and the kernel"
    if p.startswith(("docs/claude/founder/", "docs/cursor-work/founder/")): return "founder", "founder docs"
    if p.startswith(".lovable/"): return "lovable", "Lovable project files"
    if re.match(r"src/routes/(app\.founder|founder)", p) or p in ("src/components/site/FounderBar.tsx", "src/lib/founder.ts", "src/lib/founder-plan.ts", "src/lib/founder-preview.ts"): return "lovable", "old Lovable-era founder pages on the awam site (cutover T)"
    if p.startswith("server/lib/founder-") or p == "server/routes/founder.ts": return "lovable", "old Bun founder endpoints on the awam server (cutover T)"
    if p.startswith("docs/cursor-work/sql/"):
        if re.search(r"create\s+(or\s+replace\s+)?(table|function|view)\s+(if\s+not\s+exists\s+)?(public\.|app\.)?\"?founder_", read(p), re.I) or "founder" in b.lower(): return "founder", "founder SQL (defines founder_* objects)"
        return "awam", "awam/shared SQL"
    if p.startswith("sql/"): return "awam", "awam SQL (phase files)"
    if p.startswith("src/"): return "awam", "awam site (user side)"
    if p.startswith("anexochat/"): return "awam", "AnexoChat"
    if p.startswith("server/"): return "awam", "awam server (Bun / Rust / deploy)"
    if p.startswith("docs/cursor-work/server/"):
        if "founder" in b: return "founder", "founder deploy tooling"
        if b in ("all-pull.sh", "sql-run.sh", "pull.sh", "rules-gate.py", "manifest-sync.py", "manifest-verify.py", "sql-editor-lint.py"): return "shared", "deploy/gate tooling used by both"
        return "awam", "awam deploy / brain scripts"
    if p.startswith("docs/packages/"): return "awam", "package docs"
    if p.startswith(("docs/", ".cursor/")): return "docs", "docs / memory / rules"
    return "shared", "root config"


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def build():
    rows = sorted((p,) + lane(p) for p in tracked())
    out = {}
    out["ALL-FILES.csv"] = "path,lane,what\n" + "".join(f'{p},{l},"{w}"\n' for p, l, w in rows)
    for ln in ("founder", "awam", "shared", "lovable", "docs"):
        out[f"{ln}.txt"] = "".join(p + "\n" for p, l, _ in rows if l == ln)
    gold = [p for p, l, _ in rows if l == "lovable" and os.path.exists(p)]
    return rows, out, gold


def cross_imports():
    bad = []
    for p in subprocess.check_output(["git", "ls-files", "founder-web/src", "server/founder/src"], text=True).split():
        t = read(p)
        if re.search(r"""from\s+['"](\.\./)+(src|server)/|require\(['"](\.\./)+src/|server/routes/|server/lib/""", t): bad.append(f"{p}: founder code reaches into awam code")
    for p in subprocess.check_output(["git", "ls-files", "src"], text=True).split():
        if p.endswith((".ts", ".tsx")) and re.search(r"""from\s+['"][^'"]*(founder-web|server/founder)""", read(p)): bad.append(f"{p}: awam code imports founder code")
    return bad


def main():
    rows, out, gold = build()
    check = "--check" in sys.argv
    manifest = "".join(f"{sha(p)[:64]}  {p}\n" for p in gold)
    problems = []
    for name, body in out.items():
        fp = f"lanes/{name}"
        if check:
            if read(fp) != body: problems.append(f"lanes/{name} is stale: run python3 lanes/lane-sync.py")
        else:
            open(fp, "w").write(body)
    gm = f"{GOLD}/MANIFEST.sha256"
    if check:
        if read(gm) != manifest: problems.append(f"{GOLD}/MANIFEST.sha256 differs from the live Lovable files (run lane-sync once, and never edit {GOLD}/ by hand)")
        for p in gold:
            q = f"{GOLD}/{p}"
            if not os.path.exists(q) or sha(q) != sha(p): problems.append(f"{q} differs from {p}")
        problems += cross_imports()
        for x in problems: print("FAIL [73 lanes]", x)
        print(f"lane-check: {len(rows)} files in lanes, {len(gold)} Lovable files frozen, {len(problems)} problem(s)")
        sys.exit(1 if problems else 0)
    shutil.rmtree(GOLD, ignore_errors=True)
    for p in gold:
        os.makedirs(os.path.dirname(f"{GOLD}/{p}") or GOLD, exist_ok=True); shutil.copy2(p, f"{GOLD}/{p}")
    open(gm, "w").write(manifest)
    cnt = {l: sum(1 for r in rows if r[1] == l) for l in ("founder", "awam", "shared", "lovable", "docs")}
    open(f"{GOLD}/README.md", "w").write(f"""# lovable-gold: frozen copy of the Lovable-era code (Rule 73)

Founder 3 Nov 2026 08:33 PKT: the Lovable code is gold and must be PRESERVED. This folder holds an exact COPY ({len(gold)} files) of every Lovable-lane file,
with the same relative paths and a sha256 MANIFEST. The live files stay where the awam site and server build from them (nothing was moved or deleted).

* READ-ONLY: never edit anything here by hand. The rules-gate fails if this folder differs from the live Lovable files.
* Refresh only through `python3 lanes/lane-sync.py` (after the live file was changed on purpose).
* Cutover T (removing the old Lovable founder routes) may delete the LIVE copy only after the founder says so; this copy stays.
* Lane lists: `lanes/founder.txt`, `lanes/awam.txt`, `lanes/shared.txt`, `lanes/lovable.txt`, `lanes/docs.txt` (every tracked file is in exactly one).
Counts at generation: {cnt}.
""")
    print("lanes written:", cnt, "| lovable-gold files:", len(gold))


main()
