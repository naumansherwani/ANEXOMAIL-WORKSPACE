#!/usr/bin/env python3
# ANEXOMAIL — cron mein bina "\" ke "%" = naya line (man 5 crontab). `date -u +%FT%TZ` wali lines isi se "/bin/sh: Syntax error: end of file
# unexpected" deti thin aur job kabhi chalti hi nahi thi (har minute root ko error mail). Ye har cron line ke command hisse mein "%" -> "\%" karta hai.
# Usage: cron_pct_fix.py <file> <user_field: 0|1>   (1 = /etc/crontab, /etc/cron.d/* — 6th field user hai; 0 = `crontab -l` wala)
# Output: badli lines (pehle/baad) + har badli line ka command `sh -n` se syntax check. Exit 0 = theek/kuch nahi; 3 = badla; 4 = syntax phir bhi kharab.
import re, subprocess, sys
path, has_user = sys.argv[1], sys.argv[2] == "1"
src = open(path).read().split("\n"); out = []; changed = 0; bad = 0
ENV = re.compile(r'^\s*[A-Za-z_][A-Za-z0-9_]*\s*=')
for line in src:
    s = line.strip()
    if not s or s.startswith("#") or ENV.match(line):
        out.append(line); continue
    if s.startswith("@"):
        parts = line.split(None, 2 if has_user else 1); n = 2 if has_user else 1
    else:
        parts = line.split(None, 6 if has_user else 5); n = 6 if has_user else 5
    if len(parts) <= n:
        out.append(line); continue
    cmd = parts[n]; head = line[: len(line) - len(cmd)]
    fixed = re.sub(r'(?<!\\)%', r'\\%', cmd)
    real = fixed.replace("\\%", "%")
    ok = subprocess.run(["sh", "-n", "-c", real], capture_output=True).returncode == 0
    if fixed != cmd:
        changed += 1
        print("   - " + line[:200]); print("   + " + (head + fixed)[:200]); print("     sh -n: " + ("OK" if ok else "ABHI BHI KHARAB"))
    if not ok: bad += 1
    out.append(head + fixed)
if changed:
    open(path, "w").write("\n".join(out))
sys.exit(4 if bad else (3 if changed else 0))
