#!/usr/bin/env python3
"""CODE BACKUP TOOL (his 22 Nov 2026 06:02, STANDING RULE, docs/claude/CODE-BACKUP-LAW-22NOV.md).
  python3 docs/cursor-work/server/code-backup.py desk [label]   # make a NEW backup of the Admin Desk (append-only: never overwrites an old one)
  python3 docs/cursor-work/server/code-backup.py verify         # check every backup archive against its SHA256SUMS
  python3 docs/cursor-work/server/code-backup.py restore desk <backup-dir>   # prints the exact restore command (never runs it)
A backup = backups/<lane>/<YYYYMMDD-HHMM>-<commit>/ with code.tar.gz + SHA256SUMS + MANIFEST.txt + RESTORE.md. Nothing pulls from backups/ unless HE asks.
Lanes: desk (now) and awam (later, the same tool, a separate lane, never mixed). Secrets are NEVER included (the tool refuses *.env, *.seed, *.pem, *.key)."""
import hashlib, io, os, subprocess, sys, tarfile, time

ROOT = subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True).strip(); os.chdir(ROOT)
LANES = {
    "desk": ["docs/claude/admin-desk", "admin-desk", "founder-web/src/desk", "founder-web/dist-desk", "founder-web/vite.desk.config.ts", "founder-web/desk.html"],
}
SECRET = (".env", ".seed", ".pem", ".key")
def sha(b): return hashlib.sha256(b).hexdigest()
def files(paths):
    out = []
    for p in paths:
        if os.path.isfile(p): out.append(p)
        elif os.path.isdir(p):
            for d, ds, fs in os.walk(p):
                ds[:] = [x for x in ds if x not in ("target", "node_modules", ".git")]
                out += [os.path.join(d, f) for f in fs]
    return sorted(f for f in out if not f.endswith(SECRET))
def make(lane, label):
    paths = LANES[lane]; fl = files(paths)
    commit = subprocess.check_output(["git", "rev-parse", "--short=8", "HEAD"], text=True).strip()
    stamp = time.strftime("%Y%m%d-%H%M"); name = f"{stamp}-{commit}" + (f"-{label}" if label else "")
    d = f"backups/{lane}/{name}"
    if os.path.exists(d): sys.exit(f"REFUSED: {d} exists (backups are append-only)")
    os.makedirs(d)
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz", compresslevel=9) as t:
        for f in fl:
            ti = t.gettarinfo(f); ti.uid = ti.gid = 0; ti.uname = ti.gname = ""; ti.mtime = 0
            t.addfile(ti, open(f, "rb"))
    data = buf.getvalue(); open(f"{d}/code.tar.gz", "wb").write(data)
    man = "\n".join(f"{sha(open(f, 'rb').read())}  {f}" for f in fl) + "\n"
    open(f"{d}/MANIFEST.txt", "w").write(f"# {lane} backup {name}, commit {commit}, {len(fl)} files\n" + man)
    open(f"{d}/SHA256SUMS", "w").write(f"{sha(data)}  code.tar.gz\n{sha(open(f'{d}/MANIFEST.txt','rb').read())}  MANIFEST.txt\n")
    open(f"{d}/RESTORE.md", "w").write(f"""# RESTORE the {lane} lane from {name} (only when the Chairman says so)
1. Verify: `python3 docs/cursor-work/server/code-backup.py verify`
2. Restore (writes over the {lane} lane paths only, nothing else): `tar -xzf {d}/code.tar.gz -C .`
3. `python3 docs/cursor-work/server/desk-copy-sync.py sync` (desk lane), build, run the tests, then commit and push as usual.
Paths in this backup: {', '.join(paths)}.
""")
    print(f"backup written: {d} ({len(fl)} files, {len(data)//1024} KB, sha256 {sha(data)[:16]}...)")
def verify():
    bad = 0; n = 0
    for lane in sorted(x for x in (os.listdir("backups") if os.path.isdir("backups") else []) if os.path.isdir(f"backups/{x}")):
        for b in sorted(x for x in os.listdir(f"backups/{lane}") if os.path.isdir(f"backups/{lane}/{x}")):
            d = f"backups/{lane}/{b}"
            if not os.path.isfile(f"{d}/SHA256SUMS"): continue
            n += 1
            for line in open(f"{d}/SHA256SUMS"):
                h, f = line.split(); ok = os.path.isfile(f"{d}/{f}") and sha(open(f"{d}/{f}", "rb").read()) == h
                if not ok: bad += 1; print("BAD", d, f)
    print(f"backup-verify: {n} backups, {bad} bad"); sys.exit(1 if bad else 0)
if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["desk"]: make("desk", a[1] if len(a) > 1 else "")
    elif a[:1] == ["verify"]: verify()
    elif a[:2] == ["restore", "desk"] and len(a) == 3: print(open(f"{a[2]}/RESTORE.md").read())
    else: sys.exit(__doc__)
