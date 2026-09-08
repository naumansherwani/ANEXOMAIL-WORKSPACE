#!/usr/bin/env python3
"""
DUPLICATE HOST CLEANER for /etc/caddy/Caddyfile

Repo ke `server/caddy/*.Caddyfile` blocks `/etc/caddy/sites/*.caddy` se import
hote hain. Agar wahi hostname main Caddyfile mein bhi purana block rakhta ho to
`caddy validate` "duplicate site address" par mar jata hai aur poora reload fail
ho jata hai -> host 000.

Yeh script main Caddyfile se SIRF un host blocks ko hataati hai jo repo-managed
site files mein maujood hain (backup ke saath). Baqi file bilkul waise hi.

Use: python3 strip-dup-hosts.py /etc/caddy/Caddyfile /etc/caddy/sites
"""
import re
import shutil
import sys
import time
from pathlib import Path

main_path = Path(sys.argv[1] if len(sys.argv) > 1 else "/etc/caddy/Caddyfile")
sites_dir = Path(sys.argv[2] if len(sys.argv) > 2 else "/etc/caddy/sites")

managed: set[str] = set()
for f in sorted(sites_dir.glob("*.caddy")):
    for line in f.read_text(encoding="utf-8").split("\n"):
        s = line.strip()
        if s.endswith("{") and not s.startswith("#") and not line.startswith((" ", "\t")):
            head = s[:-1].strip()
            if head and not head.startswith("("):
                for h in head.split(","):
                    h = h.strip()
                    if re.match(r"^[a-z0-9.\-*]+$", h):
                        managed.add(h)

src = main_path.read_text(encoding="utf-8")
lines = src.split("\n")
out: list[str] = []
removed: list[str] = []
i = 0
while i < len(lines):
    line = lines[i]
    s = line.strip()
    is_opener = (
        s.endswith("{")
        and not s.startswith("#")
        and not s.startswith("}")
        and not line.startswith((" ", "\t"))
    )
    if not is_opener:
        out.append(line)
        i += 1
        continue

    head = s[:-1].strip()
    hosts = [h.strip() for h in head.split(",") if h.strip()]
    # block ka end dhoondo
    depth = 0
    end = i
    for j in range(i, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if depth <= 0 and j > i:
            end = j
            break
        end = j

    if hosts and all(h in managed for h in hosts):
        removed.append(head)
        out.append(f"# {head} — repo-managed block (/etc/caddy/sites) mein chala gaya")
    else:
        out.extend(lines[i:end + 1])
    i = end + 1

new = "\n".join(out)
if new != src:
    shutil.copyfile(main_path, f"{main_path}.bak.{int(time.time())}")
    main_path.write_text(new, encoding="utf-8")
    for h in removed:
        print(f">>> duplicate host block hataya: {h}")
else:
    print(">>> main Caddyfile mein koi duplicate host nahi")
