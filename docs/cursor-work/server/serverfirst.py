#!/usr/bin/env python3
"""SERVER-FIRST law (founder 13 Nov 2026 21:08, for ONE YEAR, automatic, strict).
RULE: before Claude changes ANYTHING that touches the live server surface (ports, listeners, TLS, HTTP/3, QUIC, Caddy, firewall, DNS, installers), Claude first gives him a READ-ONLY command for his server,
he pastes the output, and only then is the change written. The paste is recorded here as a receipt; the commit gate (rules-gate.py, rule "SERVER FIRST") refuses a server-surface change without a fresh receipt.
  serverfirst.py record "<the read-only command I gave him>" <file with his pasted output>   (receipt, valid 6 hours)
  serverfirst.py check <staged file> ...                                                    (exit 1 = refused; used by the gate)
Receipts: docs/claude/state/SERVER-FIRST.jsonl, SHA-256 hash-chained like the Q state ledger. Also H3-ONLY: new server code may never add an http/1.1 or h2 ALPN / serving path.
"""
import hashlib, json, os, re, subprocess, sys, time
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
LED = os.path.join(ROOT, "docs/claude/state/SERVER-FIRST.jsonl"); FRESH = 6 * 3600
SURFACE = [r"^server/founder/src/(main|tls256|h3|front|wt|wtrpc|fproxy|hostproof|dbsc)\.rs$", r"^docs/cursor-work/server/(founder-install|founder-dns-install|founder-dns-firewall|founder-host|geoblock|fmail-intake-postfix|fmail-postfix-pq|fmail-clamd-alerts|fmail-intake-on)\.sh$",
           r"(?i)caddy", r"(?i)ufw|firewall|iptables|nftables", r"(?i)^docs/claude/SERVER-PORTS-RED-LINE"]
def sha(b): return hashlib.sha256(b).hexdigest()
def events(): return [json.loads(l) for l in open(LED, encoding="utf-8")] if os.path.exists(LED) else []
def body(e): return json.dumps({k: e[k] for k in ("seq", "ts", "epoch", "cmd", "out_sha", "out_lines", "prev")}, sort_keys=True, separators=(",", ":")).encode()
def verify():
    prev = "0" * 64
    for i, e in enumerate(events(), 1):
        if e["seq"] != i or e["prev"] != prev or e["hash"] != sha(body(e)): return f"server-first ledger broken at {i}"
        prev = e["hash"]
def record(cmd, path):
    out = open(path, encoding="utf-8", errors="replace").read()
    if len(out.strip().splitlines()) < 2: sys.exit("FAIL: his output is empty or one line; a receipt needs the real paste")
    err = verify()
    if err: sys.exit("FAIL: " + err)
    ev = events(); prev = ev[-1]["hash"] if ev else "0" * 64
    e = {"seq": len(ev) + 1, "ts": time.strftime("%Y-%m-%d %H:%M %z"), "epoch": int(time.time()), "cmd": cmd[:300], "out_sha": sha(out.encode()), "out_lines": len(out.splitlines()), "prev": prev}; e["hash"] = sha(body(e))
    os.makedirs(os.path.dirname(LED), exist_ok=True); open(LED, "a", encoding="utf-8").write(json.dumps(e, sort_keys=True) + "\n"); print("receipt", e["seq"], e["ts"])
def surface(files): return [f for f in files if any(re.search(p, f) for p in SURFACE)]
def h3_only_violations():
    d = subprocess.run(["git", "diff", "--cached", "-U0", "--", "server/founder/src"], capture_output=True, text=True, cwd=ROOT).stdout
    bad = []
    for l in d.splitlines():
        if l.startswith("+") and not l.startswith("+++") and re.search(r'b"http/1\.1"|b"h2"|http2_only|\.http1_only|"http/1\.1"', l) and "H3-ONLY-TEST" not in l and not l.lstrip("+").lstrip().startswith("//"): bad.append(l[:110])
    return bad
def check(files):
    errs = []; s = surface(files)
    if s:
        err = verify(); ev = events()
        if err: errs.append(err)
        elif not ev or time.time() - ev[-1]["epoch"] > FRESH: errs.append("server-surface change (" + ", ".join(s[:3]) + ") without a fresh SERVER-FIRST receipt: give him a read-only command, paste his output, then run: python3 docs/cursor-work/server/serverfirst.py record \"<command>\" <output file>")
    for b in h3_only_violations(): errs.append("H3-ONLY law: new http/1.1 or h2 serving/ALPN line: " + b + "  (tests that must name them carry the marker H3-ONLY-TEST)")
    return errs
if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else ""
    if c == "record" and len(sys.argv) == 4: record(sys.argv[2], sys.argv[3])
    elif c == "check":
        e = check(sys.argv[2:]); print("\n".join(e) if e else "OK"); sys.exit(1 if e else 0)
    else: print(__doc__)
