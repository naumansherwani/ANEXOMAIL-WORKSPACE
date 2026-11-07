#!/usr/bin/env python3
"""Compare Caddy's RUNNING config (saved JSON) with the config adapted from /etc/caddy/Caddyfile. Reads only, changes nothing.
Run: python3 caddy-compare.py [running.json] [adapted.json]   (defaults: /root/caddy-save/*.json)"""
import json, sys
R = sys.argv[1] if len(sys.argv) > 1 else "/root/caddy-save/running.json"
A = sys.argv[2] if len(sys.argv) > 2 else "/root/caddy-save/adapted.json"

def walk(o, key, out):
    if isinstance(o, dict):
        for k, v in o.items():
            if k == key and isinstance(v, list): out.update(x for x in v if isinstance(x, str))
            else: walk(v, key, out)
    elif isinstance(o, list):
        for x in o: walk(x, key, out)

def handlers(o, out):
    if isinstance(o, dict):
        if "handler" in o: out.add(o["handler"])
        for v in o.values(): handlers(v, out)
    elif isinstance(o, list):
        for x in o: handlers(x, out)

try:
    r = json.load(open(R)); a = json.load(open(A))
except Exception as e:
    print("FAIL: cannot read", R, A, e); sys.exit(1)
res = {}
for name, key in (("hosts", "host"), ("ports", "listen"), ("remote_ip ranges", "ranges")):
    x, y = set(), set(); walk(r, key, x); walk(a, key, y)
    res[name] = (x, y)
    print(f"{name}: running={len(x)} backup={len(y)}")
    if name != "remote_ip ranges":
        print("  ONLY in running:", sorted(x - y)); print("  ONLY in backup:", sorted(y - x))
    else:
        print("  ranges only in running:", len(x - y), "| only in backup:", len(y - x))
hr, ha = set(), set(); handlers(r, hr); handlers(a, ha)
print("handler kinds only in running:", sorted(hr - ha), "| only in backup:", sorted(ha - hr))
print("VERDICT:", "backup == running for hosts and ports" if res["hosts"][0] == res["hosts"][1] and res["ports"][0] == res["ports"][1] else "DIFFERENT: see the ONLY lines above")
