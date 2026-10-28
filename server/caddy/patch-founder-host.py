#!/usr/bin/env python3
"""
founderworkspace.anexomail.com par NAYA Rust founder jodna (host wahi, founder ka favourite — 28 Oct 2026).
Purana awam-app founder (/app/founder*, /api/*) bilkul nahi chhedta. Sirf teen raaste Rust :3210 par:
  /f   -> /f/ (redirect)
  /f/* -> Rust (prefix hata kar; SPA ke asset relative hain)
  /founder/v1/* -> Rust
Idempotent (marker). Agar host block mein IP allowlist (remote_ip/client_ip/@blocked/abort) mile to KUCH NAHI badalta
(handle allowlist ko bypass kar sakta hai) — block print karke 2 se exit.
usage: patch-founder-host.py /etc/caddy/Caddyfile /etc/caddy/sites
"""
import glob, os, re, shutil, sys, time

HOST = "founderworkspace.anexomail.com"
MARK = "# FOUNDER-NEW (Rust :3210) — repo-managed"
main = sys.argv[1] if len(sys.argv) > 1 else "/etc/caddy/Caddyfile"
sites = sys.argv[2] if len(sys.argv) > 2 else "/etc/caddy/sites"

SNIP = [
    "\t" + MARK,
    "\tredir /f /f/ 308",
    "\thandle_path /f/* {",
    "\t\treverse_proxy 127.0.0.1:3210",
    "\t}",
    "\thandle /founder/v1/* {",
    "\t\treverse_proxy 127.0.0.1:3210",
    "\t}",
]

def find_block(lines):
    """(start,end) of the top-level site block whose address list has HOST, else None."""
    i = 0
    while i < len(lines):
        ln = lines[i]; s = ln.strip()
        if s.endswith("{") and not s.startswith(("#", "}")) and not ln.startswith((" ", "\t")):
            depth = 0; end = None
            for j in range(i, len(lines)):
                depth += lines[j].count("{") - lines[j].count("}")
                if depth <= 0 and j >= i:
                    end = j; break
            hosts = [h.strip() for h in s[:-1].split(",")]
            if HOST in hosts:
                return i, end if end is not None else len(lines) - 1
            i = (end if end is not None else i) + 1
        else:
            i += 1
    return None

cands = [main] + sorted(glob.glob(os.path.join(sites, "*.caddy")))
found = []
for path in cands:
    if not os.path.isfile(path):
        continue
    lines = open(path, encoding="utf-8").read().split("\n")
    b = find_block(lines)
    if b:
        found.append((path, lines, b))

if len(found) != 1:
    print(f"!!! {HOST} ka block {len(found)} jagah mila (1 chahiye) — kuch nahi badla.")
    for p, _, b in found:
        print("   ", p, "lines", b[0] + 1, "-", b[1] + 1)
    sys.exit(3)

path, lines, (a, z) = found[0]
body = "\n".join(lines[a:z + 1])
if MARK in body:
    print(">>> founder host pehle se patched — koi badlav nahi")
    sys.exit(0)
if re.search(r"remote_ip|client_ip|@blocked|abort|not remote", body):
    print("!!! Is host block mein IP allowlist/guard mila — handle usay bypass kar sakta hai, isliye KUCH NAHI badla.")
    print("--- block ---"); print(body); print("--- end ---")
    sys.exit(2)

bak = f"{path}.bak.founder.{int(time.time())}"
shutil.copyfile(path, bak)
new = lines[:a + 1] + SNIP + lines[a + 1:]
open(path, "w", encoding="utf-8").write("\n".join(new))
print(f">>> patched {path} (backup {bak})")
