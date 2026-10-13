#!/usr/bin/env python3
"""
AUTO-PATCH /etc/caddy/Caddyfile  (koi nano, koi manual overwrite)

Har site block jismein `handle /rpc/*` maujood hai (yani Rust primary wala host:
anexomail.com, founderworkspace.anexomail.com, ai.anexomail.com, anexochat...)
usmein yeh ensure karta hai:

  1. handle /file/* { reverse_proxy 127.0.0.1:3200 }   <- Phase 13/14/15 chunk path
  2. handle /wt/*   { reverse_proxy 127.0.0.1:3200 }   <- WebTransport
  3. request_body { max_size 32MB }                    <- 5GB file ke chunks

Idempotent: jo already maujood hai woh dobara add nahi hota.
Baqi poori file bilkul waise hi rehti hai.
"""
import re
import shutil
import sys
import time

PATH = sys.argv[1] if len(sys.argv) > 1 else "/etc/caddy/Caddyfile"

with open(PATH, "r", encoding="utf-8") as f:
    src = f.read()

lines = src.split("\n")
out = []
i = 0
changed = []

def block_end(start):
    """start = index of line that opens a site block ('{' at end). Return index of closing '}'."""
    depth = 0
    for j in range(start, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if depth <= 0 and j > start:
            return j
        if depth == 0 and j == start:
            return j
    return len(lines) - 1

while i < len(lines):
    line = lines[i]
    stripped = line.strip()
    # site block opener: not a comment, not an import, ends with {
    is_opener = (
        stripped.endswith("{")
        and not stripped.startswith("#")
        and not line.startswith("\t")
        and not line.startswith(" ")
        and not stripped.startswith("}")
    )
    if not is_opener:
        out.append(line)
        i += 1
        continue

    end = block_end(i)
    block = lines[i:end + 1]
    body = "\n".join(block)

    APP_HOSTS = (
        "anexomail.com",
        "www.anexomail.com",
        "founderworkspace.anexomail.com",
        "ai.anexomail.com",
        "anexochat.anexomail.com",
        "aicrm.anexomail.com",
        "crm.anexomail.com",

        "api.anexomail.com",
    )
    host_line = stripped[:-1]
    hosts = [h.strip() for h in host_line.split(",") if h.strip()]
    is_app_host = any(h in APP_HOSTS for h in hosts)

    if "handle /rpc/*" in body or is_app_host:
        host = stripped[:-1].strip()
        indent = "\t"
        insert_at = 1  # right after opener

        additions = []
        if not re.search(r"handle\s+/file/\*", body):
            additions += [
                f"{indent}# Phase 13/14/15 — Rust large-file chunk path",
                f"{indent}handle /file/* {{",
                f"{indent}\treverse_proxy 127.0.0.1:3200",
                f"{indent}}}",
            ]
        if not re.search(r"handle\s+/rpc/\*", body):
            additions += [
                f"{indent}handle /rpc/* {{",
                f"{indent}\treverse_proxy 127.0.0.1:3200",
                f"{indent}}}",
            ]
        if not re.search(r"handle\s+/wt/\*", body):
            additions += [
                f"{indent}handle /wt/* {{",
                f"{indent}\treverse_proxy 127.0.0.1:3200",
                f"{indent}}}",
            ]
        if not re.search(r"request_body", body):
            additions += [
                f"{indent}request_body {{",
                f"{indent}\tmax_size 32MB",
                f"{indent}}}",
            ]

        # FOUNDER SURFACE GUARD — /app/founder* sirf founder host par. Awam host
        # (anexomail.com · www · ai.) par edge se hi 404, SSR tak jaata hi nahi.
        PUBLIC_ONLY = ("anexomail.com", "www.anexomail.com", "ai.anexomail.com")
        is_public_host = any(h in PUBLIC_ONLY for h in hosts) and not any(
            h == "founderworkspace.anexomail.com" for h in hosts
        )
        if is_public_host and not re.search(r"handle\s+/app/founder\*", body):
            additions += [
                f"{indent}# founder surface awam host par band (locked)",
                f"{indent}handle /app/founder* {{",
                f'{indent}\trespond "Not found" 404',
                f"{indent}}}",
            ]

        if additions:
            block = block[:insert_at] + additions + block[insert_at:]
            changed.append(host)

    out.extend(block)
    i = end + 1

new = "\n".join(out)

if new != src:
    shutil.copyfile(PATH, f"{PATH}.bak.{int(time.time())}")
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(new)
    for h in changed:
        print(f">>> patched site block: {h}  (+/file/* +/wt/* +request_body)")
else:
    print(">>> main Caddyfile already Phase 13/14/15 ready (no change)")
