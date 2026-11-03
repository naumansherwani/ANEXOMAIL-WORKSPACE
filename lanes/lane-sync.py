#!/usr/bin/env python3
"""Rule 73 (founder 3 Nov 2026 08:33 PKT): every tracked file belongs to exactly ONE lane: founder | awam | shared | docs.
Separately, the Lovable-origin code (the Bun-era website: src/, Bun server, sql/, anexochat/) is FROZEN as a copy in lovable-gold/awam and lovable-gold/founder.
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


FOUNDER_LOVABLE = re.compile(r"src/routes/(app\.founder|founder)|src/components/site/FounderBar\.tsx$|src/lib/founder(-plan|-preview)?\.ts$|server/lib/founder-|server/routes/founder\.ts$")
BUN_DIRS = ("server/accounts/", "server/config/", "server/gates/", "server/i18n/", "server/lib/", "server/mail/", "server/routes/", "server/storage/")


def lovable_side(p):
    """Origin overlay: which Lovable-era (Bun website) code is this? None = built after, by the Rust/founder work."""
    if p.endswith((".pyc",)) or "__pycache__" in p: return None
    if FOUNDER_LOVABLE.search(p): return "founder"
    if p.startswith(("src/", "sql/", "anexochat/")) or p.startswith(BUN_DIRS) or re.match(r"server/[^/]+\.ts$", p): return "awam"
    return None


def lane(p):
    b = p.split("/")[-1]
    if p.startswith("founder-web/"): return "founder", "founder SPA built output" if p.startswith("founder-web/dist/") else "founder SPA (React-TS)"
    if p.startswith("server/founder/"): return "founder", "founder Rust (axum)"
    if p.startswith(("web-wasm/", "public/kernel/", "src/lib/kernel/")) or p == "scripts/build-kernel.sh": return "shared", "WASM kernel (one kernel, Rule 52)"
    if p in SHARED_RUST or re.match(r"server/rust/(g5\w+|consistency_vectors)\.json$", p): return "shared", "Rust core/vector file read by the founder crate and the kernel"
    if p.startswith(("docs/claude/founder/", "docs/cursor-work/founder/")): return "founder", "founder docs"
    if p.startswith(".lovable/"): return "docs", "Lovable project files"
    if lovable_side(p) == "founder": return "founder", "Lovable-era founder page / Bun founder endpoint (migrates to Rust founder crate; live until cutover T)"
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
    for ln in ("founder", "awam", "shared", "docs"):
        out[f"{ln}.txt"] = "".join(p + "\n" for p, l, _ in rows if l == ln)
    gold = [(lovable_side(p), p) for p, l, _ in rows if lovable_side(p) and os.path.exists(p)]
    for side in ("awam", "founder"):
        out[f"lovable-{side}.txt"] = "".join(p + "\n" for sd, p in gold if sd == side)
    return rows, out, gold


def endpoint_split():
    """The Bun->Rust endpoint map split by who the endpoint is for: /api/founder/* = founder, everything else = awam (gates and endpoints for the awam go to the awam)."""
    src = "docs/claude/ENDPOINT-MIGRATION-24OCT.csv"
    if not os.path.exists(src): return {}
    L = read(src).splitlines(); hd, rows = L[0], L[1:]
    f = [r for r in rows if r.split(",")[2].startswith("/api/founder/")]
    a = [r for r in rows if not r.split(",")[2].startswith("/api/founder/")]
    return {"awam/ENDPOINTS-awam.csv": hd + "\n" + "\n".join(a) + "\n", "founder/ENDPOINTS-founder.csv": hd + "\n" + "\n".join(f) + "\n"}


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
    manifest = "".join(f"{sha(p)}  {sd}/{p}\n" for sd, p in gold)
    ep = endpoint_split()
    manifest += "".join(f"{hashlib.sha256(v.encode()).hexdigest()}  {k}\n" for k, v in sorted(ep.items()))
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
        for sd, p in gold:
            q = f"{GOLD}/{sd}/{p}"
            if not os.path.exists(q) or sha(q) != sha(p): problems.append(f"{q} differs from {p}")
        for k, v in ep.items():
            if read(f"{GOLD}/{k}") != v: problems.append(f"{GOLD}/{k} is stale")
        problems += cross_imports()
        for x in problems: print("FAIL [73 lanes]", x)
        print(f"lane-check: {len(rows)} files in lanes, {len(gold)} Lovable files frozen, {len(problems)} problem(s)")
        sys.exit(1 if problems else 0)
    shutil.rmtree(GOLD, ignore_errors=True)
    for sd, p in gold:
        os.makedirs(os.path.dirname(f"{GOLD}/{sd}/{p}"), exist_ok=True); shutil.copy2(p, f"{GOLD}/{sd}/{p}")
    for k, v in ep.items():
        open(f"{GOLD}/{k}", "w").write(v)
    open(gm, "w").write(manifest)
    cnt = {l: sum(1 for r in rows if r[1] == l) for l in ("founder", "awam", "shared", "docs")}
    na, nf = sum(1 for g in gold if g[0] == "awam"), sum(1 for g in gold if g[0] == "founder")
    open(f"{GOLD}/README.md", "w").write(f"""# lovable-gold: the Lovable-era website, frozen, split into AWAM and FOUNDER (Rule 73)

Founder 3 Nov 2026 08:40 PKT: the Lovable (Bun) code is gold. It is preserved here, whole, split by who it is for, so it is in front of our eyes whenever we
polish it and migrate it to the latest technology (Rust). The live files stay where the site and server build from them; this folder is an exact COPY.

* `awam/` ({na} files): the user-side website. `src/` (React site), the Bun server (`server/routes`, `server/gates`, `server/lib`, `server/mail`, `server/accounts`, ...),
  `sql/` phase files, `anexochat/`. Mirrors the repo paths. `awam/ENDPOINTS-awam.csv` = every endpoint that belongs to the awam (gates and endpoints for the awam go to the awam)
  with its Rust status (RUST-FIRST = a Rust twin exists, BUN-ONLY = still only Bun).
* `founder/` ({nf} files): the Lovable-era founder pages (`src/routes/app.founder*`, `founder*.tsx`, `FounderBar`, `src/lib/founder*`) and the Bun founder endpoints
  (`server/routes/founder.ts`, `server/lib/founder-*`). `founder/ENDPOINTS-founder.csv` = the `/api/founder/*` endpoints (some live in route files shared with the awam,
  e.g. admin.ts, analytics.ts: those files sit in `awam/`, the founder rows are in this CSV). They migrate into the Rust founder crate (`server/founder`) on the latest technology.
* `MANIFEST.sha256` = sha256 of every file here. READ-ONLY: the rules-gate fails if this folder differs from the live files or from the manifest.
* Refresh only through `python3 lanes/lane-sync.py`, after a live file was changed on purpose. Cutover T may delete a LIVE file only on the founder's word; the copy here stays.
* The migration plan and counts: `docs/claude/LOVABLE-BUN-MIGRATION-PLAN-03NOV.md`. Lane lists: `lanes/{{founder,awam,shared,docs}}.txt` (every tracked file in exactly one), `lanes/lovable-awam.txt`, `lanes/lovable-founder.txt`.
Counts at generation: {cnt}.
""")
    print("lanes written:", cnt, "| lovable-gold files:", len(gold))


main()
